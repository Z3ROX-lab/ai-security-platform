"""
title: LLM Guard Filter Pipeline
author: Z3ROX
version: 3.0
license: MIT
description: Hybrid keyword + ML prompt injection detection and PII filtering
"""

import re
from typing import List, Optional
from pydantic import BaseModel
import requests


class Pipeline:
    class Valves(BaseModel):
        pipelines: List[str] = ["*"]
        priority: int = 0
        guardrails_url: str = "http://guardrails-api.ai-inference.svc.cluster.local:8000"
        enabled: bool = True
        block_on_detection: bool = True

    # Injection keywords - triggers ML scan
    INJECTION_KEYWORDS = [
        r"\bignore\b.*\binstructions?\b",
        r"\bsystem\s*prompt\b",
        r"\byou\s*are\s*now\b",
        r"\bact\s*as\b.*\bno\s*restrict",
        r"\bjailbreak\b",
        r"\bDAN\b",
        r"\bbypass\b.*\b(filter|guard|safe|restrict)",
        r"\bpretend\b.*\b(evil|unrestrict|no\s*rules)",
        r"\bforget\b.*\b(rules|instructions|previous)",
        r"\bdisregard\b.*\b(previous|above|all)",
        r"\boverride\b.*\b(safe|policy|rules)",
        r"\bdo\s*anything\s*now\b",
        r"\brole\s*play\b.*\b(evil|hack|malicious)",
        r"\brepeat\b.*\bsystem\b",
        r"\breveal\b.*\b(prompt|instructions|config)",
    ]

    def __init__(self):
        self.type = "filter"
        self.id = "llmguard_filter"
        self.name = "LLM Guard Security Filter"
        self.valves = self.Valves()
        self._patterns = [re.compile(p, re.IGNORECASE) for p in self.INJECTION_KEYWORDS]

    async def on_startup(self):
        print(f"[LLM Guard] Started v3.0 (hybrid) - URL: {self.valves.guardrails_url}")

    async def on_shutdown(self):
        print("[LLM Guard] Shutdown")

    def _has_injection_keywords(self, text: str) -> list:
        """Check if text contains injection-related keywords"""
        matched = []
        for pattern in self._patterns:
            if pattern.search(text):
                matched.append(pattern.pattern)
        return matched

    async def inlet(self, body: dict, user: Optional[dict] = None) -> dict:
        """Filter incoming messages - hybrid keyword + ML detection"""
        if not self.valves.enabled:
            return body

        messages = body.get("messages", [])
        if not messages:
            return body

        last_message = messages[-1]
        if last_message.get("role") != "user":
            return body

        content = last_message.get("content", "")
        if not content:
            return body

        user_name = user.get("name", "unknown") if user else "unknown"

        # Step 1: Keyword pre-filter
        keyword_matches = self._has_injection_keywords(content)

        if not keyword_matches:
            print(f"[LLM Guard] User: {user_name}, No injection keywords - PASS")
            return body

        print(f"[LLM Guard] User: {user_name}, Keywords detected: {keyword_matches}")

        # Step 2: ML scan only if keywords found
        try:
            response = requests.post(
                f"{self.valves.guardrails_url}/scan/input",
                json={"prompt": content},
                timeout=30
            )
            response.raise_for_status()
            result = response.json()

            is_valid = result.get("is_valid", True)
            risk_score = result.get("risk_score", 0)

            print(f"[LLM Guard] User: {user_name}, ML scan: Valid={is_valid}, Risk={risk_score}")

            if not is_valid and self.valves.block_on_detection:
                scanners = result.get("scanners", [])
                triggered = [s["name"] for s in scanners if not s.get("is_valid", True)]
                reason = ", ".join(triggered) if triggered else "Security violation"
                raise Exception(f"🛡️ Message blocked by LLM Guard: {reason}")

            # ML says valid but keywords matched - log warning
            if is_valid:
                print(f"[LLM Guard] User: {user_name}, Keywords matched but ML passed - allowing")

        except requests.exceptions.RequestException as e:
            # Fail-closed when keywords detected but API unreachable
            print(f"[LLM Guard] WARNING - API unreachable with suspicious keywords: {e}")
            if self.valves.block_on_detection:
                raise Exception("🛡️ Security scan unavailable - suspicious content blocked")

        return body

    async def outlet(self, body: dict, user: Optional[dict] = None) -> dict:
        """Filter outgoing messages - redact PII"""
        if not self.valves.enabled:
            return body

        messages = body.get("messages", [])
        if not messages:
            return body

        last_message = messages[-1]
        if last_message.get("role") != "assistant":
            return body

        content = last_message.get("content", "")
        if not content:
            return body

        prompt = ""
        for msg in reversed(messages[:-1]):
            if msg.get("role") == "user":
                prompt = msg.get("content", "")
                break

        try:
            response = requests.post(
                f"{self.valves.guardrails_url}/scan/output",
                json={"prompt": prompt, "output": content},
                timeout=30
            )
            response.raise_for_status()
            result = response.json()

            sanitized = result.get("sanitized", content)
            if sanitized != content:
                print("[LLM Guard] PII redacted from response")
                messages[-1]["content"] = sanitized
                body["messages"] = messages

        except requests.exceptions.RequestException as e:
            print(f"[LLM Guard] Warning - Output scan failed: {e}")

        return body
