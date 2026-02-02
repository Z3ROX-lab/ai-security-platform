#!/usr/bin/env python3
"""
Custom RAG Application with Qdrant

This application demonstrates a RAG (Retrieval-Augmented Generation) pipeline using:
- Qdrant: Vector database for storing embeddings
- Ollama: Embedding model (nomic-embed-text) and LLM (mistral)
- SeaweedFS: Optional document storage (S3-compatible)

Author: Z3ROX - AI Security Platform
"""

import os
import json
import hashlib
from typing import List, Optional
from dataclasses import dataclass
import requests


# =============================================================================
# Configuration
# =============================================================================

@dataclass
class Config:
    """RAG Configuration"""
    # Qdrant
    qdrant_url: str = os.getenv("QDRANT_URL", "http://localhost:6333")
    qdrant_api_key: str = os.getenv("QDRANT_API_KEY", "")
    collection_name: str = os.getenv("QDRANT_COLLECTION", "documents")
    
    # Ollama
    ollama_url: str = os.getenv("OLLAMA_URL", "http://localhost:11434")
    embedding_model: str = os.getenv("EMBEDDING_MODEL", "nomic-embed-text")
    llm_model: str = os.getenv("LLM_MODEL", "mistral:7b-instruct-v0.3-q4_K_M")
    
    # RAG parameters
    chunk_size: int = int(os.getenv("CHUNK_SIZE", "1000"))
    chunk_overlap: int = int(os.getenv("CHUNK_OVERLAP", "100"))
    top_k: int = int(os.getenv("TOP_K", "3"))
    
    # Vector dimensions (nomic-embed-text = 768)
    vector_size: int = 768


config = Config()


# =============================================================================
# Ollama Client
# =============================================================================

class OllamaClient:
    """Client for Ollama API (embeddings + chat)"""
    
    def __init__(self, base_url: str):
        self.base_url = base_url.rstrip("/")
    
    def embed(self, text: str, model: str = None) -> List[float]:
        """Generate embedding for text"""
        model = model or config.embedding_model
        response = requests.post(
            f"{self.base_url}/api/embeddings",
            json={"model": model, "prompt": text}
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
            json={"model": model, "messages": messages, "stream": False}
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
        """Make HTTP request to Qdrant"""
        response = requests.request(
            method,
            f"{self.url}{path}",
            headers=self.headers,
            json=data
        )
        response.raise_for_status()
        return response.json()
    
    def collection_exists(self, name: str) -> bool:
        """Check if collection exists"""
        try:
            self._request("GET", f"/collections/{name}")
            return True
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 404:
                return False
            raise
    
    def create_collection(self, name: str, vector_size: int):
        """Create a collection"""
        self._request("PUT", f"/collections/{name}", {
            "vectors": {
                "size": vector_size,
                "distance": "Cosine"
            }
        })
        print(f"✅ Created collection: {name}")
    
    def delete_collection(self, name: str):
        """Delete a collection"""
        self._request("DELETE", f"/collections/{name}")
        print(f"🗑️ Deleted collection: {name}")
    
    def upsert_points(self, name: str, points: List[dict]):
        """Insert or update points"""
        self._request("PUT", f"/collections/{name}/points", {
            "points": points
        })
    
    def search(self, name: str, vector: List[float], limit: int = 5) -> List[dict]:
        """Search for similar vectors"""
        result = self._request("POST", f"/collections/{name}/points/search", {
            "vector": vector,
            "limit": limit,
            "with_payload": True
        })
        return result.get("result", [])
    
    def count(self, name: str) -> int:
        """Count points in collection"""
        result = self._request("POST", f"/collections/{name}/points/count", {
            "exact": True
        })
        return result.get("result", {}).get("count", 0)
    
    def get_collections(self) -> List[str]:
        """List all collections"""
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
        
        # Try to break at sentence boundary
        if end < text_len:
            last_period = chunk.rfind(". ")
            last_newline = chunk.rfind("\n")
            break_point = max(last_period, last_newline)
            if break_point > chunk_size // 2:
                chunk = text[start:start + break_point + 1]
                end = start + break_point + 1
        
        chunks.append(chunk.strip())
        start = end - overlap
    
    return [c for c in chunks if c]  # Remove empty chunks


def generate_id(text: str, source: str) -> str:
    """Generate unique ID for a chunk"""
    content = f"{source}:{text[:100]}"
    return hashlib.md5(content.encode()).hexdigest()


# =============================================================================
# RAG Pipeline
# =============================================================================

class RAGPipeline:
    """RAG Pipeline using Qdrant + Ollama"""
    
    def __init__(self):
        self.ollama = OllamaClient(config.ollama_url)
        self.qdrant = QdrantClient(config.qdrant_url, config.qdrant_api_key)
        self._ensure_collection()
    
    def _ensure_collection(self):
        """Create collection if it doesn't exist"""
        if not self.qdrant.collection_exists(config.collection_name):
            self.qdrant.create_collection(
                config.collection_name,
                config.vector_size
            )
    
    def ingest_text(self, text: str, source: str, metadata: dict = None):
        """Ingest text into the vector database"""
        print(f"📄 Ingesting: {source}")
        
        # Chunk the text
        chunks = chunk_text(text, config.chunk_size, config.chunk_overlap)
        print(f"   → {len(chunks)} chunks")
        
        # Generate embeddings
        print(f"   → Generating embeddings...")
        embeddings = self.ollama.embed_batch(chunks)
        
        # Prepare points
        points = []
        for i, (chunk, embedding) in enumerate(zip(chunks, embeddings)):
            point_id = generate_id(chunk, source)
            payload = {
                "text": chunk,
                "source": source,
                "chunk_index": i,
                **(metadata or {})
            }
            points.append({
                "id": point_id,
                "vector": embedding,
                "payload": payload
            })
        
        # Upsert to Qdrant
        self.qdrant.upsert_points(config.collection_name, points)
        print(f"   → Stored {len(points)} vectors in Qdrant")
    
    def ingest_file(self, filepath: str, metadata: dict = None):
        """Ingest a file into the vector database"""
        with open(filepath, "r", encoding="utf-8") as f:
            text = f.read()
        
        source = os.path.basename(filepath)
        file_metadata = {"filepath": filepath, **(metadata or {})}
        self.ingest_text(text, source, file_metadata)
    
    def search(self, query: str, top_k: int = None) -> List[dict]:
        """Search for relevant chunks"""
        top_k = top_k or config.top_k
        
        # Generate query embedding
        query_embedding = self.ollama.embed(query)
        
        # Search Qdrant
        results = self.qdrant.search(
            config.collection_name,
            query_embedding,
            limit=top_k
        )
        
        return results
    
    def query(self, question: str, top_k: int = None) -> dict:
        """Full RAG query: search + generate"""
        print(f"❓ Question: {question}")
        
        # Search for relevant chunks
        results = self.search(question, top_k)
        
        if not results:
            return {
                "answer": "I couldn't find any relevant information to answer your question.",
                "sources": [],
                "context": ""
            }
        
        # Build context from results
        context_parts = []
        sources = []
        for i, result in enumerate(results):
            payload = result.get("payload", {})
            text = payload.get("text", "")
            source = payload.get("source", "unknown")
            score = result.get("score", 0)
            
            context_parts.append(f"[Source {i+1}: {source}]\n{text}")
            sources.append({
                "source": source,
                "score": score,
                "chunk_index": payload.get("chunk_index", 0)
            })
        
        context = "\n\n".join(context_parts)
        print(f"   → Found {len(results)} relevant chunks")
        
        # Generate answer with LLM
        system_prompt = """You are a helpful assistant that answers questions based on the provided context.
Use ONLY the information from the context to answer. If the context doesn't contain enough information, say so.
Always cite the source when providing information."""

        user_prompt = f"""Context:
{context}

Question: {question}

Answer based on the context above:"""

        print(f"   → Generating answer...")
        answer = self.ollama.chat(user_prompt, system=system_prompt)
        
        return {
            "answer": answer,
            "sources": sources,
            "context": context
        }
    
    def stats(self) -> dict:
        """Get collection statistics"""
        count = self.qdrant.count(config.collection_name)
        collections = self.qdrant.get_collections()
        return {
            "collection": config.collection_name,
            "document_count": count,
            "all_collections": collections
        }
    
    def clear(self):
        """Clear the collection"""
        if self.qdrant.collection_exists(config.collection_name):
            self.qdrant.delete_collection(config.collection_name)
        self._ensure_collection()
        print(f"🗑️ Cleared collection: {config.collection_name}")


# =============================================================================
# CLI Interface
# =============================================================================

def main():
    """CLI interface for RAG pipeline"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Custom RAG with Qdrant")
    subparsers = parser.add_subparsers(dest="command", help="Commands")
    
    # Ingest command
    ingest_parser = subparsers.add_parser("ingest", help="Ingest documents")
    ingest_parser.add_argument("files", nargs="+", help="Files to ingest")
    
    # Query command
    query_parser = subparsers.add_parser("query", help="Query the RAG")
    query_parser.add_argument("question", help="Question to ask")
    query_parser.add_argument("-k", "--top-k", type=int, default=3, help="Number of results")
    
    # Search command
    search_parser = subparsers.add_parser("search", help="Search without generation")
    search_parser.add_argument("query", help="Search query")
    search_parser.add_argument("-k", "--top-k", type=int, default=5, help="Number of results")
    
    # Stats command
    subparsers.add_parser("stats", help="Show collection stats")
    
    # Clear command
    subparsers.add_parser("clear", help="Clear collection")
    
    # Interactive command
    subparsers.add_parser("interactive", help="Interactive chat mode")
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    # Initialize pipeline
    rag = RAGPipeline()
    
    if args.command == "ingest":
        for filepath in args.files:
            if os.path.exists(filepath):
                rag.ingest_file(filepath)
            else:
                print(f"❌ File not found: {filepath}")
    
    elif args.command == "query":
        result = rag.query(args.question, args.top_k)
        print("\n" + "="*60)
        print("📝 Answer:")
        print(result["answer"])
        print("\n📚 Sources:")
        for src in result["sources"]:
            print(f"   - {src['source']} (score: {src['score']:.3f})")
    
    elif args.command == "search":
        results = rag.search(args.query, args.top_k)
        print(f"\n🔍 Found {len(results)} results:\n")
        for i, r in enumerate(results):
            payload = r.get("payload", {})
            print(f"[{i+1}] {payload.get('source', 'unknown')} (score: {r.get('score', 0):.3f})")
            print(f"    {payload.get('text', '')[:200]}...")
            print()
    
    elif args.command == "stats":
        stats = rag.stats()
        print(f"\n📊 Collection: {stats['collection']}")
        print(f"   Documents: {stats['document_count']}")
        print(f"   All collections: {stats['all_collections']}")
    
    elif args.command == "clear":
        confirm = input("⚠️  Are you sure you want to clear the collection? [y/N] ")
        if confirm.lower() == "y":
            rag.clear()
    
    elif args.command == "interactive":
        print("\n🤖 Interactive RAG Chat (type 'quit' to exit)\n")
        while True:
            question = input("You: ").strip()
            if question.lower() in ["quit", "exit", "q"]:
                break
            if not question:
                continue
            
            result = rag.query(question)
            print(f"\nAssistant: {result['answer']}\n")


if __name__ == "__main__":
    main()
