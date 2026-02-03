#!/usr/bin/env python3
"""
RAG API Service with Qdrant + Ollama + Guardrails

A FastAPI-based RAG service for the AI Security Platform.
Deployed in Kubernetes via ArgoCD.

Features:
- Vector search with Qdrant
- LLM generation with Ollama
- Input/Output scanning with Guardrails API (LLM Guard)

Author: Z3ROX - AI Security Platform
"""

import os
import hashlib
import logging
from typing import List, Optional
from dataclasses import dataclass
import requests

# FastAPI imports
try:
    from fastapi import FastAPI, HTTPException
    from fastapi.responses import JSONResponse
    from pydantic import BaseModel
    FASTAPI_AVAILABLE = True
except ImportError:
    FASTAPI_AVAILABLE = False

# Configure logging
logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
logger = logging.getLogger(__name__)

# =============================================================================
# Configuration
# =============================================================================

@dataclass
class Config:
    """RAG Configuration from environment"""
    # Qdrant
    qdrant_url: str = os.getenv("QDRANT_URL", "http://qdrant.ai-inference.svc.cluster.local:6333")
    qdrant_api_key: str = os.getenv("QDRANT_API_KEY", "")
    collection_name: str = os.getenv("QDRANT_COLLECTION", "documents")
    
    # Ollama
    ollama_url: str = os.getenv("OLLAMA_URL", "http://ollama.ai-inference.svc.cluster.local:11434")
    embedding_model: str = os.getenv("EMBEDDING_MODEL", "nomic-embed-text")
    llm_model: str = os.getenv("LLM_MODEL", "mistral:7b-instruct-v0.3-q4_K_M")
    
    # RAG settings
    chunk_size: int = int(os.getenv("CHUNK_SIZE", "1000"))
    chunk_overlap: int = int(os.getenv("CHUNK_OVERLAP", "100"))
    top_k: int = int(os.getenv("TOP_K", "3"))
    vector_size: int = 768  # nomic-embed-text
    
    # Guardrails
    guardrails_url: str = os.getenv("GUARDRAILS_URL", "http://guardrails-api.ai-inference.svc.cluster.local:8000")
    guardrails_enabled: bool = os.getenv("GUARDRAILS_ENABLED", "true").lower() == "true"


config = Config()


# =============================================================================
# Guardrails Client
# =============================================================================

class GuardrailsClient:
    """Client for Guardrails API (LLM Guard)"""
    
    def __init__(self, base_url: str, enabled: bool = True):
        self.base_url = base_url.rstrip("/")
        self.enabled = enabled
        self._available = None
    
    def is_available(self) -> bool:
        """Check if Guardrails API is available"""
        if not self.enabled:
            return False
        
        if self._available is None:
            try:
                response = requests.get(f"{self.base_url}/health", timeout=5)
                self._available = response.status_code == 200
            except:
                self._available = False
        
        return self._available
    
    def scan_input(self, prompt: str) -> dict:
        """
        Scan input prompt for security issues.
        
        Returns:
            dict with keys: is_valid, sanitized, risk_score, scanners, blocked_reason
        """
        if not self.enabled:
            return {"is_valid": True, "sanitized": prompt, "risk_score": 0, "guardrails": "disabled"}
        
        try:
            response = requests.post(
                f"{self.base_url}/scan/input",
                json={"prompt": prompt},
                timeout=30
            )
            response.raise_for_status()
            result = response.json()
            
            # Add blocked reason if invalid
            if not result.get("is_valid", True):
                blocked_scanners = [s["name"] for s in result.get("scanners", []) if not s.get("is_valid", True)]
                result["blocked_reason"] = f"Blocked by: {', '.join(blocked_scanners)}"
            
            return result
            
        except requests.exceptions.RequestException as e:
            logger.warning(f"Guardrails input scan failed: {e}")
            # Fail open if guardrails unavailable (configurable)
            return {"is_valid": True, "sanitized": prompt, "risk_score": 0, "error": str(e)}
    
    def scan_output(self, prompt: str, output: str) -> dict:
        """
        Scan LLM output for security issues (PII, etc).
        
        Returns:
            dict with keys: is_valid, sanitized, risk_score, scanners
        """
        if not self.enabled:
            return {"is_valid": True, "sanitized": output, "risk_score": 0, "guardrails": "disabled"}
        
        try:
            response = requests.post(
                f"{self.base_url}/scan/output",
                json={"prompt": prompt, "output": output},
                timeout=30
            )
            response.raise_for_status()
            return response.json()
            
        except requests.exceptions.RequestException as e:
            logger.warning(f"Guardrails output scan failed: {e}")
            return {"is_valid": True, "sanitized": output, "risk_score": 0, "error": str(e)}


# =============================================================================
# Ollama Client
# =============================================================================

class OllamaClient:
    """Client for Ollama API"""
    
    def __init__(self, base_url: str):
        self.base_url = base_url.rstrip("/")
    
    def embed(self, text: str, model: str = None) -> List[float]:
        """Generate embedding for text"""
        model = model or config.embedding_model
        response = requests.post(
            f"{self.base_url}/api/embeddings",
            json={"model": model, "prompt": text},
            timeout=60
        )
        response.raise_for_status()
        return response.json()["embedding"]
    
    def embed_batch(self, texts: List[str], model: str = None) -> List[List[float]]:
        """Generate embeddings for multiple texts"""
        return [self.embed(text, model) for text in texts]
    
    def chat(self, prompt: str, system: str = None, model: str = None) -> str:
        """Generate chat response"""
        model = model or config.llm_model
        messages = []
        if system:
            messages.append({"role": "system", "content": system})
        messages.append({"role": "user", "content": prompt})
        
        response = requests.post(
            f"{self.base_url}/api/chat",
            json={"model": model, "messages": messages, "stream": False},
            timeout=300
        )
        response.raise_for_status()
        return response.json()["message"]["content"]


# =============================================================================
# Qdrant Client
# =============================================================================

class QdrantClient:
    """Simple Qdrant REST API client"""
    
    def __init__(self, url: str, api_key: str = None):
        self.url = url.rstrip("/")
        self.headers = {"Content-Type": "application/json"}
        if api_key:
            self.headers["api-key"] = api_key
    
    def _request(self, method: str, path: str, data: dict = None) -> dict:
        response = requests.request(
            method,
            f"{self.url}{path}",
            headers=self.headers,
            json=data,
            timeout=30
        )
        response.raise_for_status()
        return response.json()
    
    def collection_exists(self, name: str) -> bool:
        try:
            self._request("GET", f"/collections/{name}")
            return True
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 404:
                return False
            raise
    
    def create_collection(self, name: str, vector_size: int):
        self._request("PUT", f"/collections/{name}", {
            "vectors": {"size": vector_size, "distance": "Cosine"}
        })
    
    def delete_collection(self, name: str):
        self._request("DELETE", f"/collections/{name}")
    
    def upsert_points(self, name: str, points: List[dict]):
        self._request("PUT", f"/collections/{name}/points", {"points": points})
    
    def search(self, name: str, vector: List[float], limit: int = 5) -> List[dict]:
        result = self._request("POST", f"/collections/{name}/points/search", {
            "vector": vector, "limit": limit, "with_payload": True
        })
        return result.get("result", [])
    
    def count(self, name: str) -> int:
        result = self._request("POST", f"/collections/{name}/points/count", {"exact": True})
        return result.get("result", {}).get("count", 0)
    
    def get_collections(self) -> List[str]:
        result = self._request("GET", "/collections")
        return [c["name"] for c in result.get("result", {}).get("collections", [])]


# =============================================================================
# Text Processing
# =============================================================================

def chunk_text(text: str, chunk_size: int = 1000, overlap: int = 100) -> List[str]:
    """Split text into overlapping chunks"""
    chunks = []
    start = 0
    text_len = len(text)
    
    while start < text_len:
        end = start + chunk_size
        chunk = text[start:end]
        
        if end < text_len:
            last_period = chunk.rfind(". ")
            last_newline = chunk.rfind("\n")
            break_point = max(last_period, last_newline)
            if break_point > chunk_size // 2:
                chunk = text[start:start + break_point + 1]
                end = start + break_point + 1
        
        chunks.append(chunk.strip())
        start = end - overlap
    
    return [c for c in chunks if c]


def generate_id(text: str, source: str) -> str:
    content = f"{source}:{text[:100]}"
    return hashlib.md5(content.encode()).hexdigest()


# =============================================================================
# RAG Pipeline with Guardrails
# =============================================================================

class RAGPipeline:
    """RAG Pipeline using Qdrant + Ollama + Guardrails"""
    
    def __init__(self):
        self.ollama = OllamaClient(config.ollama_url)
        self.qdrant = QdrantClient(config.qdrant_url, config.qdrant_api_key)
        self.guardrails = GuardrailsClient(config.guardrails_url, config.guardrails_enabled)
        self._ensure_collection()
    
    def _ensure_collection(self):
        if not self.qdrant.collection_exists(config.collection_name):
            self.qdrant.create_collection(config.collection_name, config.vector_size)
    
    def ingest_text(self, text: str, source: str, metadata: dict = None) -> dict:
        """Ingest text into the vector database"""
        chunks = chunk_text(text, config.chunk_size, config.chunk_overlap)
        embeddings = self.ollama.embed_batch(chunks)
        
        points = []
        for i, (chunk, embedding) in enumerate(zip(chunks, embeddings)):
            point_id = generate_id(chunk, source)
            payload = {
                "text": chunk,
                "source": source,
                "chunk_index": i,
                **(metadata or {})
            }
            points.append({"id": point_id, "vector": embedding, "payload": payload})
        
        self.qdrant.upsert_points(config.collection_name, points)
        
        return {"source": source, "chunks": len(points), "status": "ingested"}
    
    def search(self, query: str, top_k: int = None) -> List[dict]:
        """Search for relevant chunks"""
        top_k = top_k or config.top_k
        query_embedding = self.ollama.embed(query)
        return self.qdrant.search(config.collection_name, query_embedding, limit=top_k)
    
    def query(self, question: str, top_k: int = None) -> dict:
        """
        Full RAG query with Guardrails protection:
        1. Scan input for prompt injection / toxicity
        2. If blocked, return error
        3. Search Qdrant for context
        4. Generate answer with Ollama
        5. Scan output for PII leakage
        6. Return sanitized response
        """
        
        # =====================================================================
        # STEP 1: INPUT GUARDRAILS
        # =====================================================================
        input_scan = self.guardrails.scan_input(question)
        
        if not input_scan.get("is_valid", True):
            logger.warning(f"Query blocked by guardrails: {input_scan.get('blocked_reason', 'unknown')}")
            return {
                "answer": None,
                "blocked": True,
                "blocked_reason": input_scan.get("blocked_reason", "Query blocked by security guardrails"),
                "guardrails": {
                    "input_scan": input_scan,
                    "output_scan": None
                },
                "sources": [],
                "context": ""
            }
        
        # =====================================================================
        # STEP 2: RAG SEARCH (Qdrant)
        # =====================================================================
        results = self.search(question, top_k)
        
        if not results:
            return {
                "answer": "I couldn't find any relevant information.",
                "blocked": False,
                "sources": [],
                "context": "",
                "guardrails": {
                    "input_scan": input_scan,
                    "output_scan": None
                }
            }
        
        # Build context from search results
        context_parts = []
        sources = []
        for i, result in enumerate(results):
            payload = result.get("payload", {})
            text = payload.get("text", "")
            source = payload.get("source", "unknown")
            score = result.get("score", 0)
            
            context_parts.append(f"[Source {i+1}: {source}]\n{text}")
            sources.append({"source": source, "score": score, "chunk_index": payload.get("chunk_index", 0)})
        
        context = "\n\n".join(context_parts)
        
        # =====================================================================
        # STEP 3: LLM GENERATION (Ollama)
        # =====================================================================
        system_prompt = """You are a helpful assistant that answers questions based on the provided context.
Use ONLY the information from the context to answer. If the context doesn't contain enough information, say so.
Always cite the source when providing information."""

        user_prompt = f"""Context:
{context}

Question: {question}

Answer based on the context above:"""

        raw_answer = self.ollama.chat(user_prompt, system=system_prompt)
        
        # =====================================================================
        # STEP 4: OUTPUT GUARDRAILS (PII Redaction)
        # =====================================================================
        output_scan = self.guardrails.scan_output(question, raw_answer)
        
        # Use sanitized output (PII redacted) if available
        final_answer = output_scan.get("sanitized", raw_answer)
        
        # Check if output was blocked (not just redacted)
        output_blocked = not output_scan.get("is_valid", True) and output_scan.get("risk_score", 0) > 0.9
        
        return {
            "answer": final_answer,
            "blocked": output_blocked,
            "sources": sources,
            "context": context,
            "guardrails": {
                "input_scan": {
                    "is_valid": input_scan.get("is_valid"),
                    "risk_score": input_scan.get("risk_score"),
                    "latency_ms": input_scan.get("latency_ms")
                },
                "output_scan": {
                    "is_valid": output_scan.get("is_valid"),
                    "risk_score": output_scan.get("risk_score"),
                    "latency_ms": output_scan.get("latency_ms"),
                    "pii_redacted": output_scan.get("sanitized") != raw_answer
                }
            }
        }
    
    def stats(self) -> dict:
        """Get collection statistics"""
        count = self.qdrant.count(config.collection_name)
        collections = self.qdrant.get_collections()
        guardrails_available = self.guardrails.is_available()
        
        return {
            "collection": config.collection_name,
            "document_count": count,
            "all_collections": collections,
            "guardrails": {
                "enabled": config.guardrails_enabled,
                "available": guardrails_available,
                "url": config.guardrails_url
            },
            "config": {
                "qdrant_url": config.qdrant_url,
                "ollama_url": config.ollama_url,
                "embedding_model": config.embedding_model,
                "llm_model": config.llm_model
            }
        }
    
    def clear(self):
        """Clear the collection"""
        if self.qdrant.collection_exists(config.collection_name):
            self.qdrant.delete_collection(config.collection_name)
        self._ensure_collection()
        return {"status": "cleared", "collection": config.collection_name}


# =============================================================================
# FastAPI Application
# =============================================================================

if FASTAPI_AVAILABLE:
    app = FastAPI(
        title="RAG API",
        description="Retrieval-Augmented Generation API with Qdrant + Ollama + Guardrails",
        version="2.0.0"
    )
    
    # Pydantic models
    class IngestRequest(BaseModel):
        text: str
        source: str
        metadata: Optional[dict] = None
    
    class QueryRequest(BaseModel):
        question: str
        top_k: Optional[int] = 3
    
    class SearchRequest(BaseModel):
        query: str
        top_k: Optional[int] = 5
    
    # Initialize RAG pipeline (lazy loading)
    _rag: Optional[RAGPipeline] = None
    
    def get_rag() -> RAGPipeline:
        global _rag
        if _rag is None:
            _rag = RAGPipeline()
        return _rag
    
    @app.get("/")
    def root():
        """Health check"""
        return {"status": "ok", "service": "rag-api", "version": "2.0.0", "guardrails": config.guardrails_enabled}
    
    @app.get("/health")
    def health():
        """Health check endpoint"""
        try:
            rag = get_rag()
            stats = rag.stats()
            return {
                "status": "healthy",
                "qdrant": "connected",
                "documents": stats["document_count"],
                "guardrails": stats["guardrails"]
            }
        except Exception as e:
            return JSONResponse(status_code=503, content={"status": "unhealthy", "error": str(e)})
    
    @app.get("/stats")
    def stats():
        """Get collection statistics"""
        try:
            return get_rag().stats()
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    
    @app.post("/ingest")
    def ingest(request: IngestRequest):
        """Ingest text into the vector database"""
        try:
            return get_rag().ingest_text(request.text, request.source, request.metadata)
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    
    @app.post("/search")
    def search(request: SearchRequest):
        """Search for relevant chunks"""
        try:
            results = get_rag().search(request.query, request.top_k)
            return {"results": results, "count": len(results)}
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    
    @app.post("/query")
    def query(request: QueryRequest):
        """
        Full RAG query with Guardrails protection.
        
        Flow:
        1. Input scan (prompt injection, toxicity)
        2. Vector search (Qdrant)
        3. LLM generation (Ollama)
        4. Output scan (PII redaction)
        
        Response includes guardrails metadata showing what was scanned/blocked.
        """
        try:
            return get_rag().query(request.question, request.top_k)
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    
    @app.post("/clear")
    def clear():
        """Clear the collection"""
        try:
            return get_rag().clear()
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))


# =============================================================================
# CLI for testing
# =============================================================================

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "serve":
        if not FASTAPI_AVAILABLE:
            print("FastAPI not installed. Run: pip install fastapi uvicorn")
            sys.exit(1)
        import uvicorn
        port = int(os.getenv("PORT", "8000"))
        uvicorn.run(app, host="0.0.0.0", port=port)
    else:
        # CLI mode
        rag = RAGPipeline()
        
        if len(sys.argv) < 2:
            print("Usage: python rag_api.py [serve|stats|query <question>|ingest <file>]")
            sys.exit(1)
        
        cmd = sys.argv[1]
        
        if cmd == "stats":
            import json
            print(json.dumps(rag.stats(), indent=2))
        
        elif cmd == "query" and len(sys.argv) > 2:
            question = " ".join(sys.argv[2:])
            result = rag.query(question)
            
            if result.get("blocked"):
                print(f"\n🚫 Query BLOCKED: {result.get('blocked_reason')}")
            else:
                print(f"\n📝 Answer:\n{result['answer']}")
                print(f"\n📚 Sources:")
                for src in result["sources"]:
                    print(f"   - {src['source']} (score: {src['score']:.3f})")
            
            if result.get("guardrails"):
                print(f"\n🛡️ Guardrails:")
                print(f"   Input scan: {result['guardrails'].get('input_scan', {})}")
                print(f"   Output scan: {result['guardrails'].get('output_scan', {})}")
        
        elif cmd == "ingest" and len(sys.argv) > 2:
            for filepath in sys.argv[2:]:
                with open(filepath, "r") as f:
                    text = f.read()
                result = rag.ingest_text(text, os.path.basename(filepath))
                print(f"✅ {result['source']}: {result['chunks']} chunks")
        
        else:
            print("Unknown command")
            sys.exit(1)
