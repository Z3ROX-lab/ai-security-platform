"""
title: LLM Guard Filter Pipeline
author: Z3ROX
version: 2.0
license: MIT
description: Calls Guardrails API for prompt injection detection and PII filtering
"""

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

    def __init__(self):
        self.type = "filter"
        self.id = "llmguard_filter"
        self.name = "LLM Guard Security Filter"
        self.valves = self.Valves()

    async def on_startup(self):
        print(f"[LLM Guard] Started - URL: {self.valves.guardrails_url}")

    async def on_shutdown(self):
        print("[LLM Guard] Shutdown")

    async def inlet(self, body: dict, user: Optional[dict] = None) -> dict:
        """Filter incoming messages - check for prompt injection"""
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
            
            user_name = user.get("name", "unknown") if user else "unknown"
            print(f"[LLM Guard] User: {user_name}, Valid: {is_valid}, Risk: {risk_score}")
            
            if not is_valid and self.valves.block_on_detection:
                scanners = result.get("scanners", [])
                triggered = [s["name"] for s in scanners if not s.get("is_valid", True)]
                reason = ", ".join(triggered) if triggered else "Security violation"
                raise Exception(f"🛡️ Message blocked by LLM Guard: {reason}")
                
        except requests.exceptions.RequestException as e:
            print(f"[LLM Guard] Warning - API unreachable: {e}")
        
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
        
        # Get original prompt for context
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
            print(f"[LLM Guard] Warning - API unreachable: {e}")
        
        return body
