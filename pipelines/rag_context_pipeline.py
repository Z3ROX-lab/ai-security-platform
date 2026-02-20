"""
title: RAG Context Pipeline
author: Z3ROX
version: 1.0
license: MIT
description: Enriches prompts with context from RAG API (Qdrant + Documents)
"""

from typing import List, Optional, Generator, Iterator
from pydantic import BaseModel
import requests
import json


class Pipeline:
    class Valves(BaseModel):
        pipelines: List[str] = ["*"]
        priority: int = 5  # After LLM Guard filter (priority 0)
        rag_api_url: str = "http://rag-api.ai-inference.svc.cluster.local:8000"
        enabled: bool = True
        top_k: int = 3
        min_score: float = 0.5
        include_sources: bool = True
        context_prefix: str = "Utilise le contexte suivant pour répondre à la question. Si le contexte ne contient pas l'information, dis-le clairement.\n\n"

    def __init__(self):
        self.type = "pipe"
        self.id = "rag_context_pipeline"
        self.name = "RAG Context Pipeline"
        self.valves = self.Valves()

    async def on_startup(self):
        print(f"[RAG Pipeline] Started - URL: {self.valves.rag_api_url}")

    async def on_shutdown(self):
        print("[RAG Pipeline] Shutdown")

    def get_rag_context(self, query: str) -> dict:
        """Query RAG API for relevant context"""
        try:
            response = requests.post(
                f"{self.valves.rag_api_url}/search",
                json={
                    "query": query,
                    "top_k": self.valves.top_k
                },
                timeout=30
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                print(f"[RAG Pipeline] Search failed: {response.status_code}")
                return {"results": []}
                
        except requests.exceptions.RequestException as e:
            print(f"[RAG Pipeline] Error: {e}")
            return {"results": []}

    def format_context(self, results: list) -> str:
        """Format RAG results into context string"""
        if not results:
            return ""
        
        context_parts = []
        sources = []
        
        for i, result in enumerate(results, 1):
            score = result.get("score", 0)
            
            # Skip low-score results
            if score < self.valves.min_score:
                continue
                
            content = result.get("content", "")
            metadata = result.get("metadata", {})
            source = metadata.get("source", f"Document {i}")
            
            context_parts.append(f"[{i}] {content}")
            sources.append(f"[{i}] {source} (score: {score:.2f})")
        
        if not context_parts:
            return ""
        
        context = self.valves.context_prefix
        context += "---\nCONTEXTE:\n"
        context += "\n\n".join(context_parts)
        context += "\n---\n"
        
        if self.valves.include_sources:
            context += "\nSources:\n" + "\n".join(sources) + "\n\n"
        
        return context

    def pipe(
        self, 
        user_message: str, 
        model_id: str, 
        messages: List[dict], 
        body: dict
    ) -> Generator[str, None, None]:
        """
        Main pipeline function - enriches messages with RAG context
        """
        if not self.valves.enabled:
            # Pass through to model without RAG
            yield from self._call_ollama(messages, model_id, body)
            return

        print(f"[RAG Pipeline] Processing: {user_message[:50]}...")
        
        # Get RAG context
        rag_response = self.get_rag_context(user_message)
        results = rag_response.get("results", [])
        
        if results:
            # Format context
            context = self.format_context(results)
            
            if context:
                # Enrich the last user message with context
                enriched_messages = messages.copy()
                
                # Find last user message and prepend context
                for i in range(len(enriched_messages) - 1, -1, -1):
                    if enriched_messages[i].get("role") == "user":
                        original_content = enriched_messages[i]["content"]
                        enriched_messages[i]["content"] = f"{context}QUESTION: {original_content}"
                        break
                
                print(f"[RAG Pipeline] Added context from {len(results)} documents")
                yield from self._call_ollama(enriched_messages, model_id, body)
                return
        
        print("[RAG Pipeline] No relevant context found, using direct query")
        yield from self._call_ollama(messages, model_id, body)

    def _call_ollama(
        self, 
        messages: List[dict], 
        model_id: str, 
        body: dict
    ) -> Generator[str, None, None]:
        """Call Ollama API with messages"""
        ollama_url = "http://ollama.ai-inference.svc.cluster.local:11434"
        
        try:
            # Streaming request to Ollama
            response = requests.post(
                f"{ollama_url}/api/chat",
                json={
                    "model": model_id.split(".")[-1] if "." in model_id else model_id,
                    "messages": messages,
                    "stream": True
                },
                stream=True,
                timeout=120
            )
            
            if response.status_code == 200:
                for line in response.iter_lines():
                    if line:
                        try:
                            data = json.loads(line)
                            content = data.get("message", {}).get("content", "")
                            if content:
                                yield content
                        except json.JSONDecodeError:
                            continue
            else:
                yield f"Erreur Ollama: {response.status_code}"
                
        except requests.exceptions.RequestException as e:
            yield f"Erreur de connexion à Ollama: {e}"
