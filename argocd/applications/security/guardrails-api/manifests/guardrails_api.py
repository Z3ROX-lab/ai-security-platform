#!/usr/bin/env python3
"""
Guardrails API - AI Security Platform (Phase 7a)

Lightweight LLM Guard service with essential scanners.
Based on protectai/llm-guard but optimized for low RAM usage.

Author: Z3ROX - AI Security Platform
"""

import os
import time
import logging
from typing import List, Optional
from dataclasses import dataclass, field

# FastAPI
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel

# Configure logging
logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
logger = logging.getLogger(__name__)

# =============================================================================
# Configuration
# =============================================================================

@dataclass
class Config:
    """Guardrails configuration"""
    # Thresholds
    prompt_injection_threshold: float = float(os.getenv("PROMPT_INJECTION_THRESHOLD", "0.5"))
    toxicity_threshold: float = float(os.getenv("TOXICITY_THRESHOLD", "0.7"))
    
    # Features
    enable_prompt_injection: bool = os.getenv("ENABLE_PROMPT_INJECTION", "true").lower() == "true"
    enable_toxicity: bool = os.getenv("ENABLE_TOXICITY", "true").lower() == "true"
    enable_pii: bool = os.getenv("ENABLE_PII", "true").lower() == "true"
    enable_secrets: bool = os.getenv("ENABLE_SECRETS", "true").lower() == "true"
    
    # Auth
    auth_token: str = os.getenv("AUTH_TOKEN", "")


config = Config()


# =============================================================================
# Lazy Loading of Scanners (reduces startup memory)
# =============================================================================

_input_scanners = None
_output_scanners = None


def get_input_scanners():
    """Lazy load input scanners"""
    global _input_scanners
    
    if _input_scanners is None:
        logger.info("Loading input scanners...")
        from llm_guard.input_scanners import PromptInjection, Toxicity, Secrets
        
        scanners = []
        
        if config.enable_prompt_injection:
            logger.info("  Loading PromptInjection scanner...")
            scanners.append(PromptInjection(threshold=config.prompt_injection_threshold))
        
        if config.enable_toxicity:
            logger.info("  Loading Toxicity scanner...")
            scanners.append(Toxicity(threshold=config.toxicity_threshold))
        
        if config.enable_secrets:
            logger.info("  Loading Secrets scanner...")
            scanners.append(Secrets())
        
        _input_scanners = scanners
        logger.info(f"Loaded {len(scanners)} input scanners")
    
    return _input_scanners


def get_output_scanners():
    """Lazy load output scanners"""
    global _output_scanners
    
    if _output_scanners is None:
        logger.info("Loading output scanners...")
        from llm_guard.output_scanners import Sensitive, NoRefusal
        
        scanners = []
        
        if config.enable_pii:
            logger.info("  Loading Sensitive (PII) scanner...")
            scanners.append(Sensitive(redact=True))
        
        scanners.append(NoRefusal())
        
        _output_scanners = scanners
        logger.info(f"Loaded {len(scanners)} output scanners")
    
    return _output_scanners


# =============================================================================
# FastAPI Application
# =============================================================================

app = FastAPI(
    title="Guardrails API",
    description="LLM Guardrails for AI Security Platform (Phase 7a)",
    version="1.0.0"
)


# Pydantic models
class ScanInputRequest(BaseModel):
    prompt: str


class ScanOutputRequest(BaseModel):
    prompt: str
    output: str


class ScanResult(BaseModel):
    is_valid: bool
    sanitized: str
    risk_score: float
    scanners: List[dict]
    latency_ms: float


class HealthResponse(BaseModel):
    status: str
    scanners_loaded: bool
    input_scanners: int
    output_scanners: int


# =============================================================================
# Endpoints
# =============================================================================

@app.get("/")
def root():
    """Health check"""
    return {"status": "ok", "service": "guardrails-api"}


@app.get("/health", response_model=HealthResponse)
def health():
    """Detailed health check"""
    return HealthResponse(
        status="healthy",
        scanners_loaded=_input_scanners is not None,
        input_scanners=len(_input_scanners) if _input_scanners else 0,
        output_scanners=len(_output_scanners) if _output_scanners else 0
    )


@app.post("/scan/input", response_model=ScanResult)
def scan_input(request: ScanInputRequest):
    """
    Scan input prompt for security issues.
    
    Checks:
    - Prompt injection attempts
    - Toxicity
    - Secrets (API keys, passwords)
    """
    start_time = time.time()
    
    try:
        from llm_guard import scan_prompt
        
        scanners = get_input_scanners()
        sanitized, results_valid, results_score = scan_prompt(scanners, request.prompt)
        
        # Build scanner results
        scanner_results = []
        for i, scanner in enumerate(scanners):
            scanner_name = scanner.__class__.__name__
            is_valid = results_valid[scanner_name] if isinstance(results_valid, dict) else True
            score = results_score[scanner_name] if isinstance(results_score, dict) else 0.0
            
            scanner_results.append({
                "name": scanner_name,
                "is_valid": is_valid,
                "risk_score": score
            })
        
        # Overall validity
        is_valid = all(r["is_valid"] for r in scanner_results)
        max_risk = max((r["risk_score"] for r in scanner_results), default=0.0)
        
        latency = (time.time() - start_time) * 1000
        
        logger.info(f"Input scan: valid={is_valid}, risk={max_risk:.2f}, latency={latency:.0f}ms")
        
        return ScanResult(
            is_valid=is_valid,
            sanitized=sanitized,
            risk_score=max_risk,
            scanners=scanner_results,
            latency_ms=latency
        )
        
    except Exception as e:
        logger.error(f"Input scan error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/scan/output", response_model=ScanResult)
def scan_output(request: ScanOutputRequest):
    """
    Scan LLM output for security issues.
    
    Checks:
    - PII leakage (redacts sensitive info)
    - Refusal detection
    """
    start_time = time.time()
    
    try:
        from llm_guard import scan_output as llm_scan_output
        
        scanners = get_output_scanners()
        sanitized, results_valid, results_score = llm_scan_output(
            scanners, request.prompt, request.output
        )
        
        # Build scanner results
        scanner_results = []
        for scanner in scanners:
            scanner_name = scanner.__class__.__name__
            is_valid = results_valid.get(scanner_name, True) if isinstance(results_valid, dict) else True
            score = results_score.get(scanner_name, 0.0) if isinstance(results_score, dict) else 0.0
            
            scanner_results.append({
                "name": scanner_name,
                "is_valid": is_valid,
                "risk_score": score
            })
        
        # Overall validity
        is_valid = all(r["is_valid"] for r in scanner_results)
        max_risk = max((r["risk_score"] for r in scanner_results), default=0.0)
        
        latency = (time.time() - start_time) * 1000
        
        logger.info(f"Output scan: valid={is_valid}, risk={max_risk:.2f}, latency={latency:.0f}ms")
        
        return ScanResult(
            is_valid=is_valid,
            sanitized=sanitized,
            risk_score=max_risk,
            scanners=scanner_results,
            latency_ms=latency
        )
        
    except Exception as e:
        logger.error(f"Output scan error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/scan/full")
def scan_full(prompt: str, output: str):
    """
    Full pipeline scan: input + output.
    Use this for complete RAG pipeline protection.
    """
    input_result = scan_input(ScanInputRequest(prompt=prompt))
    
    if not input_result.is_valid:
        return {
            "allowed": False,
            "stage": "input",
            "input_scan": input_result,
            "output_scan": None
        }
    
    output_result = scan_output(ScanOutputRequest(prompt=prompt, output=output))
    
    return {
        "allowed": output_result.is_valid,
        "stage": "output" if not output_result.is_valid else "complete",
        "input_scan": input_result,
        "output_scan": output_result
    }


@app.get("/scanners")
def list_scanners():
    """List available scanners and their status"""
    return {
        "input_scanners": {
            "PromptInjection": {
                "enabled": config.enable_prompt_injection,
                "threshold": config.prompt_injection_threshold,
                "description": "Detects prompt injection attempts"
            },
            "Toxicity": {
                "enabled": config.enable_toxicity,
                "threshold": config.toxicity_threshold,
                "description": "Detects toxic or harmful language"
            },
            "Secrets": {
                "enabled": config.enable_secrets,
                "description": "Detects API keys, passwords, tokens"
            }
        },
        "output_scanners": {
            "Sensitive": {
                "enabled": config.enable_pii,
                "description": "Detects and redacts PII (names, emails, SSN, etc.)"
            },
            "NoRefusal": {
                "enabled": True,
                "description": "Detects if LLM refused to answer"
            }
        }
    }


@app.post("/warmup")
def warmup():
    """Pre-load all scanners (call on startup for faster first request)"""
    start = time.time()
    
    input_scanners = get_input_scanners()
    output_scanners = get_output_scanners()
    
    latency = (time.time() - start) * 1000
    
    return {
        "status": "warmed_up",
        "input_scanners": len(input_scanners),
        "output_scanners": len(output_scanners),
        "latency_ms": latency
    }


# =============================================================================
# Main
# =============================================================================

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run(app, host="0.0.0.0", port=port)
