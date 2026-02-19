# RAG API Demo - AI Security Platform

## Overview

This document demonstrates the custom RAG (Retrieval-Augmented Generation) API deployed on the AI Security Platform. The RAG API provides REST endpoints for document ingestion and semantic search with LLM-powered answers.

| Component | Technology | Status |
|-----------|------------|--------|
| **API** | FastAPI (Python) | ✅ Running |
| **Vector DB** | Qdrant | ✅ Connected |
| **Embeddings** | Ollama (nomic-embed-text) | ✅ Working |
| **LLM** | Ollama (Mistral 7B) | ✅ Working |
| **Deployment** | ArgoCD (GitOps) | ✅ Synced |

**API URL**: https://rag.ai-platform.localhost

**Swagger UI**: https://rag.ai-platform.localhost/docs (Interactive Demo)

**Qdrant Dashboard**: https://qdrant.ai-platform.localhost/dashboard (Vector DB Explorer)

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         RAG API ARCHITECTURE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  EXTERNAL ACCESS                                                            │
│  ═══════════════                                                            │
│                                                                             │
│  Client (curl/app) ──────▶ Traefik Ingress ──────▶ RAG API Service         │
│                            (TLS termination)       (ClusterIP:8000)         │
│                                                                             │
│  URL: https://rag.ai-platform.localhost                                    │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  KUBERNETES CLUSTER (namespace: ai-inference)                               │
│  ════════════════════════════════════════════                               │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         RAG-API POD                                  │   │
│  │                                                                      │   │
│  │  ┌────────────────────────────────────────────────────────────┐     │   │
│  │  │  Container: python:3.11-slim                                │     │   │
│  │  │                                                             │     │   │
│  │  │  Mounted from ConfigMaps (no Docker build needed!):        │     │   │
│  │  │  ├── /app/rag_api.py      ← FastAPI application            │     │   │
│  │  │  ├── /app/startup.sh      ← pip install + uvicorn start    │     │   │
│  │  │  └── /app/requirements.txt                                  │     │   │
│  │  │                                                             │     │   │
│  │  │  Environment (from ConfigMap + Secret):                    │     │   │
│  │  │  ├── QDRANT_URL=http://qdrant:6333                         │     │   │
│  │  │  ├── OLLAMA_URL=http://ollama:11434                        │     │   │
│  │  │  ├── QDRANT_API_KEY=****** (from Secret)                   │     │   │
│  │  │  └── EMBEDDING_MODEL=nomic-embed-text                      │     │   │
│  │  │                                                             │     │   │
│  │  └────────────────────────────────────────────────────────────┘     │   │
│  │                           │                                          │   │
│  │                           │ Internal HTTP calls                      │   │
│  │                           ▼                                          │   │
│  │  ┌──────────────────────────────────────────────────────────────┐   │   │
│  │  │                                                               │   │   │
│  │  │   ┌─────────────────┐           ┌─────────────────┐          │   │   │
│  │  │   │     OLLAMA      │           │     QDRANT      │          │   │   │
│  │  │   │                 │           │                 │          │   │   │
│  │  │   │  Models:        │           │  Collection:    │          │   │   │
│  │  │   │  • nomic-embed  │           │  "documents"    │          │   │   │
│  │  │   │    (embeddings) │           │                 │          │   │   │
│  │  │   │  • mistral:7b   │           │  Storage:       │          │   │   │
│  │  │   │    (generation) │           │  • Vectors      │          │   │   │
│  │  │   │                 │           │  • Metadata     │          │   │   │
│  │  │   │  Port: 11434    │           │  Port: 6333     │          │   │   │
│  │  │   └─────────────────┘           └─────────────────┘          │   │   │
│  │  │                                                               │   │   │
│  │  └──────────────────────────────────────────────────────────────┘   │   │
│  │                                                                      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/` | Simple health check |
| `GET` | `/health` | Health check with Qdrant status |
| `GET` | `/stats` | Collection statistics |
| `POST` | `/ingest` | Ingest a document |
| `POST` | `/search` | Semantic search (no LLM) |
| `POST` | `/query` | Full RAG (search + LLM answer) |
| `POST` | `/clear` | Clear the collection |

## Query Flow Diagram

```
┌────────────────────────────────────────────────────────────────────────────┐
│                    RAG QUERY FLOW: POST /query                             │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌──────────┐                                                              │
│  │  CLIENT  │                                                              │
│  │          │  POST /query                                                 │
│  │  Request │  {"question": "Quel VectorDB a été choisi?"}                │
│  └────┬─────┘                                                              │
│       │                                                                    │
│       ▼                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │                         STEP 1: EMBEDDING                             │ │
│  │                                                                       │ │
│  │  RAG-API ─────────────────────────────────────────────▶ OLLAMA       │ │
│  │          POST /api/embeddings                                         │ │
│  │          {                                                            │ │
│  │            "model": "nomic-embed-text",                              │ │
│  │            "prompt": "Quel VectorDB a été choisi?"                   │ │
│  │          }                                                            │ │
│  │                                                                       │ │
│  │  RAG-API ◀───────────────────────────────────────────── OLLAMA       │ │
│  │          {                                                            │ │
│  │            "embedding": [0.23, -0.45, 0.12, ..., 0.87]               │ │
│  │          }                     └── 768 dimensions                     │ │
│  │                                                                       │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
│       │                                                                    │
│       ▼                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │                         STEP 2: VECTOR SEARCH                         │ │
│  │                                                                       │ │
│  │  RAG-API ─────────────────────────────────────────────▶ QDRANT       │ │
│  │          POST /collections/documents/points/search                    │ │
│  │          {                                                            │ │
│  │            "vector": [0.23, -0.45, 0.12, ..., 0.87],                 │ │
│  │            "limit": 3                                                 │ │
│  │          }                                                            │ │
│  │                                                                       │ │
│  │  RAG-API ◀───────────────────────────────────────────── QDRANT       │ │
│  │          {                                                            │ │
│  │            "result": [                                                │ │
│  │              {                                                        │ │
│  │                "score": 0.59,                                        │ │
│  │                "payload": {                                          │ │
│  │                  "text": "Qdrant is a vector database...",           │ │
│  │                  "source": "ADR-006-test.md"                         │ │
│  │                }                                                      │ │
│  │              }                                                        │ │
│  │            ]                                                          │ │
│  │          }                                                            │ │
│  │                                                                       │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
│       │                                                                    │
│       ▼                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │                         STEP 3: LLM GENERATION                        │ │
│  │                                                                       │ │
│  │  RAG-API ─────────────────────────────────────────────▶ OLLAMA       │ │
│  │          POST /api/chat                                               │ │
│  │          {                                                            │ │
│  │            "model": "mistral:7b",                                    │ │
│  │            "messages": [                                              │ │
│  │              {                                                        │ │
│  │                "role": "system",                                     │ │
│  │                "content": "Answer based on the context..."           │ │
│  │              },                                                       │ │
│  │              {                                                        │ │
│  │                "role": "user",                                       │ │
│  │                "content": "Context:\n[Source 1]...\n\nQuestion:..."  │ │
│  │              }                                                        │ │
│  │            ]                                                          │ │
│  │          }                                                            │ │
│  │                                                                       │ │
│  │  RAG-API ◀───────────────────────────────────────────── OLLAMA       │ │
│  │          {                                                            │ │
│  │            "message": {                                              │ │
│  │              "content": "Le vectorDB choisi est Qdrant..."           │ │
│  │            }                                                          │ │
│  │          }                                                            │ │
│  │                                                                       │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
│       │                                                                    │
│       ▼                                                                    │
│  ┌──────────┐                                                              │
│  │  CLIENT  │                                                              │
│  │          │  Response:                                                   │
│  │ Response │  {                                                           │
│  │          │    "answer": "Le vectorDB choisi est Qdrant...",            │
│  │          │    "sources": [{"source": "ADR-006.md", "score": 0.59}]    │
│  │          │  }                                                           │
│  └──────────┘                                                              │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## Interactive Demo (Swagger UI)

FastAPI includes a built-in interactive documentation interface. Access it at:

**URL:** https://rag.ai-platform.localhost/docs

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SWAGGER UI INTERFACE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  RAG API                                                     v1.0.0 │   │
│  │  Retrieval-Augmented Generation API with Qdrant + Ollama            │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                     │   │
│  │  GET    /           Health check                         [Try it]  │   │
│  │  GET    /health     Health check endpoint                [Try it]  │   │
│  │  GET    /stats      Get collection statistics            [Try it]  │   │
│  │  POST   /ingest     Ingest text into vector database     [Try it]  │   │
│  │  POST   /search     Search for relevant chunks           [Try it]  │   │
│  │  POST   /query      Full RAG query: search + generate    [Try it]  │   │
│  │  POST   /clear      Clear the collection                 [Try it]  │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Demo Step 1: Health Check

1. Open https://rag.ai-platform.localhost/docs
2. Click on **GET /health**
3. Click **Try it out**
4. Click **Execute**
5. See the response:

```json
{
  "status": "healthy",
  "qdrant": "connected",
  "documents": 0
}
```

### Demo Step 2: Ingest a Document

1. Click on **POST /ingest**
2. Click **Try it out**
3. Paste in the Request body:

```json
{
  "text": "Qdrant is a vector database chosen for the AI Security Platform. It was selected over Milvus, Chroma, and pgvector for its low memory footprint (200MB), simple operations, and excellent performance for RAG workloads. The OWASP LLM Top 10 includes prompt injection, data leakage, and model denial of service as key security risks.",
  "source": "demo-doc.md",
  "metadata": {"author": "Z3ROX", "type": "ADR"}
}
```

4. Click **Execute**
5. See the response:

```json
{
  "source": "demo-doc.md",
  "chunks": 1,
  "status": "ingested"
}
```

### Demo Step 3: Check Statistics

1. Click on **GET /stats**
2. Click **Try it out** → **Execute**
3. See the response showing `document_count: 1`

### Demo Step 4: RAG Query (Full Pipeline)

1. Click on **POST /query**
2. Click **Try it out**
3. Paste in the Request body:

```json
{
  "question": "What are the OWASP LLM security risks?",
  "top_k": 3
}
```

4. Click **Execute** (wait 30-60 seconds for CPU inference)
5. See the response with answer and sources!

### Demo Step 5: Search Without Generation

1. Click on **POST /search**
2. Click **Try it out**
3. Paste:

```json
{
  "query": "vector database",
  "top_k": 5
}
```

4. Click **Execute**
5. See the raw chunks retrieved from Qdrant (no LLM generation)

---

## Qdrant Dashboard (Vector DB Explorer)

Qdrant provides a built-in dashboard to explore your vector database:

**URL:** https://qdrant.ai-platform.localhost/dashboard

**API Key:** `OXTyYEpyxLszFUxGvIfKrTMhKIuBCZGt`

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         QDRANT DASHBOARD                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Collections                                                         │   │
│  │  ───────────                                                         │   │
│  │                                                                      │   │
│  │  📁 documents                                                        │   │
│  │     ├── Points: 2                                                   │   │
│  │     ├── Vectors: 768 dimensions                                     │   │
│  │     ├── Distance: Cosine                                            │   │
│  │     └── Status: Green (healthy)                                     │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Point Details (click on a point)                                    │   │
│  │  ────────────────────────────────                                    │   │
│  │                                                                      │   │
│  │  ID: 8a9e93be467ace597efe7c76bf545dad                               │   │
│  │                                                                      │   │
│  │  Payload:                                                            │   │
│  │  {                                                                   │   │
│  │    "text": "Qdrant is a vector database chosen for...",             │   │
│  │    "source": "demo-doc.md",                                         │   │
│  │    "chunk_index": 0,                                                │   │
│  │    "author": "Z3ROX"                                                │   │
│  │  }                                                                   │   │
│  │                                                                      │   │
│  │  Vector: [0.023, -0.145, 0.087, ..., 0.234] (768 dims)             │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Exploring Qdrant Dashboard

1. **Open** https://qdrant.ai-platform.localhost/dashboard
2. **Enter API Key** when prompted: `OXTyYEpyxLszFUxGvIfKrTMhKIuBCZGt`
3. **Click on collection** `documents`
4. **View points** (each point = one chunk)
5. **Click a point** to see payload and vector

### What You Can See

| Element | Visible | Description |
|---------|---------|-------------|
| **Collection name** | ✅ | `documents` |
| **Point count** | ✅ | Number of chunks stored |
| **Payload** | ✅ | Text, source, metadata |
| **Vector dimensions** | ✅ | 768 (nomic-embed-text) |
| **Full vector values** | ⚠️ | Available via API (768 floats) |

### View Vectors via API

```bash
# Port-forward if needed
kubectl port-forward -n ai-inference svc/qdrant 6333:6333 &

# Get points with full vectors
curl -H "api-key: OXTyYEpyxLszFUxGvIfKrTMhKIuBCZGt" \
  -X POST http://localhost:6333/collections/documents/points/scroll \
  -H "Content-Type: application/json" \
  -d '{
    "limit": 2,
    "with_payload": true,
    "with_vector": true
  }'
```

Response shows the actual 768-dimensional vectors:
```json
{
  "result": {
    "points": [
      {
        "id": "8a9e93be...",
        "payload": {
          "text": "Qdrant is a vector database...",
          "source": "demo-doc.md"
        },
        "vector": [0.023, -0.145, 0.087, ..., 0.234]
      }
    ]
  }
}
```

---

## Test Results (CLI)

### Test 1: Health Check

**Request:**
```bash
curl -k https://rag.ai-platform.localhost/health
```

**Response:**
```json
{
  "status": "healthy",
  "qdrant": "connected",
  "documents": 0
}
```

**Status:** ✅ PASS

---

### Test 2: Get Statistics

**Request:**
```bash
curl -k https://rag.ai-platform.localhost/stats
```

**Response:**
```json
{
  "collection": "documents",
  "document_count": 0,
  "all_collections": ["documents"],
  "config": {
    "qdrant_url": "http://qdrant.ai-inference.svc.cluster.local:6333",
    "ollama_url": "http://ollama.ai-inference.svc.cluster.local:11434",
    "embedding_model": "nomic-embed-text",
    "llm_model": "mistral:7b-instruct-v0.3-q4_K_M"
  }
}
```

**Status:** ✅ PASS

---

### Test 3: Document Ingestion

**Request:**
```bash
curl -k -X POST https://rag.ai-platform.localhost/ingest \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Qdrant is a vector database chosen for the AI Security Platform. It was selected over Milvus, Chroma, and pgvector for its low memory footprint (200MB), simple operations, and excellent performance for RAG workloads.",
    "source": "ADR-006-test.md"
  }'
```

**Response:**
```json
{
  "source": "ADR-006-test.md",
  "chunks": 1,
  "status": "ingested"
}
```

**What Happened:**
1. Text was chunked (1 chunk for this short text)
2. Chunk was sent to Ollama for embedding (768-dim vector)
3. Vector + metadata stored in Qdrant collection "documents"

**Status:** ✅ PASS

---

### Test 4: RAG Query (Full Pipeline)

**Request:**
```bash
curl -k -X POST https://rag.ai-platform.localhost/query \
  -H "Content-Type: application/json" \
  -d '{"question": "Quel VectorDB a été choisi et pourquoi?"}'
```

**Response:**
```json
{
  "answer": "Le vectorDB choisi est Qdrant. Il l'a été en raison de son faible pied-de-mémoire (200MB), ses opérations simples, et sa performance excellente pour les charges de travail RAG (Recherche Approximative et Classement). [Source 1: ADR-006-test.md]",
  "sources": [
    {
      "source": "ADR-006-test.md",
      "score": 0.5907024,
      "chunk_index": 0
    }
  ],
  "context": "[Source 1: ADR-006-test.md]\nQdrant is a vector database chosen for the AI Security Platform. It was selected over Milvus, Chroma, and pgvector for its low memory footprint (200MB), simple operations, and excellent performance for RAG workloads."
}
```

**Analysis:**
| Field | Value | Meaning |
|-------|-------|---------|
| `answer` | French response | LLM answered in user's language |
| `score` | 0.59 | Cosine similarity (0-1, higher = more relevant) |
| `source` | ADR-006-test.md | Correctly cited the source document |
| `chunk_index` | 0 | First chunk of the document |

**Status:** ✅ PASS

---

## Test Summary

| Test | Endpoint | Status | Response Time |
|------|----------|--------|---------------|
| Health Check | `GET /health` | ✅ PASS | <100ms |
| Statistics | `GET /stats` | ✅ PASS | <100ms |
| Ingestion | `POST /ingest` | ✅ PASS | ~2s (embedding) |
| RAG Query | `POST /query` | ✅ PASS | ~30-60s (CPU inference) |

---

## Deployment Details

### Kubernetes Resources

```bash
$ kubectl get all -n ai-inference -l app=rag-api

NAME                           READY   STATUS    RESTARTS   AGE
pod/rag-api-6f4779c449-2nj7h   1/1     Running   0          10m

NAME              TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)    AGE
service/rag-api   ClusterIP   10.43.87.53   <none>        8000/TCP   25m

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/rag-api   1/1     1            1           25m
```

### ArgoCD Application

```bash
$ kubectl get application rag-api -n argocd

NAME      SYNC STATUS   HEALTH STATUS
rag-api   Synced        Healthy
```

### ConfigMaps

```bash
$ kubectl get configmap -n ai-inference | grep rag

rag-api-code      1      25m   # Contains rag_api.py
rag-api-config    9      25m   # Environment variables
rag-api-script    2      25m   # startup.sh + requirements.txt
```

### Secret

```bash
$ kubectl get secret -n ai-inference | grep rag

rag-api-qdrant-key   Opaque   1      15m   # Qdrant API key
```

---

## No Dockerfile Approach

This deployment demonstrates a **Dockerfile-less** approach for home lab environments without a container registry:

```
Traditional CI/CD:
  Code → Dockerfile → Build → Push Registry → K8s Pull → Run
                              ↑
                        (Not available in home lab!)

Our Approach:
  Code → Git → ArgoCD → ConfigMaps → Pod (public base image)
                              ↓
                        python:3.11-slim + mounted scripts
```

**Benefits:**
- No container registry needed
- Code changes via Git push
- ArgoCD syncs automatically
- Fast iteration

**Trade-offs:**
- Slower pod startup (pip install at runtime)
- Not suitable for production (use proper CI/CD)

---

## Comparison: Open WebUI RAG vs RAG API

| Feature | Open WebUI RAG | RAG API |
|---------|----------------|---------|
| Vector Store | ChromaDB (internal) | Qdrant (external) |
| Access | Web UI only | REST API |
| Visibility | Black box | Full access to vectors |
| Automation | Manual upload | Scriptable |
| Integration | Chat only | Any application |
| Debug | Difficult | Easy (separate endpoints) |

---

## Next Steps

1. **Ingest more documents:**
   ```bash
   for file in docs/adr/*.md; do
     curl -k -X POST https://rag.ai-platform.localhost/ingest \
       -H "Content-Type: application/json" \
       -d "{\"text\": \"$(cat $file | jq -Rs .)\", \"source\": \"$(basename $file)\"}"
   done
   ```

2. **Add authentication** (Keycloak/OAuth2)

3. **Add observability** (Prometheus metrics, Grafana dashboard)

4. **Scale for production** (multiple replicas, GPU inference)

---

## References

- [Qdrant Documentation](https://qdrant.tech/documentation/)
- [Ollama API](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

---

**Date:** 2026-02-02  
**Author:** Z3ROX - AI Security Platform  
**Version:** 1.0.0
