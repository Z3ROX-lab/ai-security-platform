# Custom RAG with Qdrant Guide

## Overview

This guide covers building a custom RAG (Retrieval-Augmented Generation) pipeline using Qdrant as the vector database. Unlike Open WebUI's built-in RAG (which uses ChromaDB internally), this approach gives you full control over the pipeline and stores vectors in Qdrant.

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Vector Store** | Qdrant | Store and search embeddings |
| **Embedding** | Ollama (nomic-embed-text) | Convert text to vectors |
| **LLM** | Ollama (Mistral 7B) | Generate responses |
| **Documents** | SeaweedFS (optional) | Store source documents |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      CUSTOM RAG PIPELINE WITH QDRANT                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  INDEXATION                                                                 │
│  ══════════                                                                 │
│                                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                  │
│  │  SeaweedFS   │    │   Chunking   │    │   Ollama     │                  │
│  │  (S3 Docs)   │───▶│  1000 chars  │───▶│   nomic-     │                  │
│  │              │    │  100 overlap │    │ embed-text   │                  │
│  │  PDF/MD/TXT  │    │              │    │  768 dims    │                  │
│  └──────────────┘    └──────────────┘    └──────┬───────┘                  │
│                                                  │                          │
│                                                  ▼                          │
│                                          ┌──────────────┐                  │
│                                          │   QDRANT     │                  │
│                                          │              │                  │
│                                          │  Vectors +   │                  │
│                                          │  Metadata    │                  │
│                                          │              │                  │
│                                          │  Collection: │                  │
│                                          │  "documents" │                  │
│                                          └──────────────┘                  │
│                                                                             │
│  QUERY                                                                      │
│  ═════                                                                      │
│                                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                  │
│  │   Question   │    │   Ollama     │    │   QDRANT     │                  │
│  │              │───▶│   nomic-     │───▶│   Search     │                  │
│  │  "What is    │    │ embed-text   │    │              │                  │
│  │   Qdrant?"   │    │              │    │  Top K = 3   │                  │
│  └──────────────┘    └──────────────┘    └──────┬───────┘                  │
│                                                  │                          │
│                                                  ▼                          │
│                                          ┌──────────────┐                  │
│                                          │  Retrieved   │                  │
│                                          │   Chunks     │                  │
│                                          │  (context)   │                  │
│                                          └──────┬───────┘                  │
│                                                  │                          │
│                                                  ▼                          │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                         OLLAMA (Mistral 7B)                          │  │
│  │                                                                      │  │
│  │  System: "Answer based on the provided context..."                  │  │
│  │  Context: [Retrieved chunks from Qdrant]                            │  │
│  │  Question: "What is Qdrant?"                                        │  │
│  │                                                                      │  │
│  │  Response: "Qdrant is a vector database chosen for..."              │  │
│  │                                                                      │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Comparison: Open WebUI RAG vs Custom Qdrant RAG

| Aspect | Open WebUI RAG | Custom Qdrant RAG |
|--------|----------------|-------------------|
| **Vector Store** | ChromaDB (internal) | Qdrant (external) |
| **Setup** | Built-in, zero config | Requires deployment |
| **Flexibility** | Limited | Full control |
| **API Access** | UI only | REST API + CLI |
| **Scalability** | Single instance | Distributed |
| **Visibility** | Black box | Full access to vectors |
| **Use Case** | Quick start | Production, Portfolio |

## Prerequisites

### 1. Verify Qdrant is Running

```bash
kubectl get pods -n ai-inference -l app.kubernetes.io/name=qdrant
# Expected: qdrant-0   1/1   Running
```

### 2. Get Qdrant API Key

```bash
# The API key is in the pod's config
kubectl exec -n ai-inference qdrant-0 -- cat /qdrant/config/local.yaml

# Or use the key directly (from previous verification)
export QDRANT_API_KEY="pdTVBDB7wW4y5TEPkzwkdLviaxtoijCx"
```

### 3. Verify Ollama Models

```bash
kubectl exec -n ai-inference deployment/ollama -- ollama list
# Should show:
# nomic-embed-text:latest (for embeddings)
# mistral:7b-instruct-v0.3-q4_K_M (for generation)
```

## Quick Start (Local Testing)

### Step 1: Port-Forward Services

```bash
# Terminal 1: Qdrant
kubectl port-forward -n ai-inference svc/qdrant 6333:6333

# Terminal 2: Ollama
kubectl port-forward -n ai-inference svc/ollama 11434:11434
```

### Step 2: Set Environment Variables

```bash
export QDRANT_URL="http://localhost:6333"
export QDRANT_API_KEY="pdTVBDB7wW4y5TEPkzwkdLviaxtoijCx"
export OLLAMA_URL="http://localhost:11434"
export QDRANT_COLLECTION="documents"
```

### Step 3: Install Dependencies

```bash
pip install requests python-dotenv
```

### Step 4: Download RAG Script

```bash
# Copy from the outputs or download
cp ~/Downloads/rag_pipeline.py ./
chmod +x rag_pipeline.py
```

### Step 5: Ingest Documents

```bash
# Ingest ADR files
python rag_pipeline.py ingest ~/work/ai-security-platform/docs/adr/*.md

# Check stats
python rag_pipeline.py stats
```

### Step 6: Query

```bash
# Single query
python rag_pipeline.py query "What VectorDB was chosen and why?"

# Interactive mode
python rag_pipeline.py interactive
```

## CLI Reference

### Ingest Documents

```bash
# Single file
python rag_pipeline.py ingest document.md

# Multiple files
python rag_pipeline.py ingest *.md

# Directory (with glob)
python rag_pipeline.py ingest docs/*.pdf docs/*.md
```

### Query (with generation)

```bash
# Basic query
python rag_pipeline.py query "What is the embedding strategy?"

# With custom top-k
python rag_pipeline.py query -k 5 "Compare Qdrant vs Milvus"
```

### Search (without generation)

```bash
# Search only (see retrieved chunks)
python rag_pipeline.py search "vector database"

# More results
python rag_pipeline.py search -k 10 "kubernetes security"
```

### Collection Management

```bash
# Show stats
python rag_pipeline.py stats

# Clear collection (with confirmation)
python rag_pipeline.py clear
```

### Interactive Mode

```bash
python rag_pipeline.py interactive

# Example session:
# You: What is the OWASP LLM Top 10?
# Assistant: Based on the documentation...
# You: quit
```

## API Usage (Python)

### Basic Usage

```python
from rag_pipeline import RAGPipeline, Config

# Configure
import os
os.environ["QDRANT_URL"] = "http://localhost:6333"
os.environ["QDRANT_API_KEY"] = "your-api-key"
os.environ["OLLAMA_URL"] = "http://localhost:11434"

# Initialize
rag = RAGPipeline()

# Ingest
rag.ingest_file("document.md")
rag.ingest_text("Some text content", source="manual-entry")

# Query
result = rag.query("What is Qdrant?")
print(result["answer"])
print(result["sources"])

# Search only
chunks = rag.search("vector database", top_k=5)
for chunk in chunks:
    print(chunk["payload"]["text"])
```

### Custom Configuration

```python
from rag_pipeline import RAGPipeline, config

# Modify config
config.chunk_size = 500
config.chunk_overlap = 50
config.top_k = 5
config.collection_name = "my-documents"

# Initialize with custom config
rag = RAGPipeline()
```

## Verify Vectors in Qdrant

### Via CLI

```bash
# List collections
curl -H "api-key: $QDRANT_API_KEY" http://localhost:6333/collections

# Count vectors
curl -H "api-key: $QDRANT_API_KEY" \
  -X POST http://localhost:6333/collections/documents/points/count \
  -H "Content-Type: application/json" \
  -d '{"exact": true}'

# Get sample points
curl -H "api-key: $QDRANT_API_KEY" \
  -X POST http://localhost:6333/collections/documents/points/scroll \
  -H "Content-Type: application/json" \
  -d '{"limit": 2, "with_payload": true, "with_vector": false}'
```

### Via Qdrant Dashboard

Qdrant has a built-in dashboard at: http://localhost:6333/dashboard

Features:
- View collections
- Browse points
- Run searches
- Check cluster status

## Kubernetes Deployment (Production)

### ConfigMap

```yaml
# rag-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: rag-config
  namespace: ai-inference
data:
  QDRANT_URL: "http://qdrant.ai-inference.svc.cluster.local:6333"
  OLLAMA_URL: "http://ollama.ai-inference.svc.cluster.local:11434"
  QDRANT_COLLECTION: "documents"
  EMBEDDING_MODEL: "nomic-embed-text"
  LLM_MODEL: "mistral:7b-instruct-v0.3-q4_K_M"
  CHUNK_SIZE: "1000"
  CHUNK_OVERLAP: "100"
  TOP_K: "3"
```

### Job (for batch ingestion)

```yaml
# rag-ingest-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: rag-ingest
  namespace: ai-inference
spec:
  template:
    spec:
      containers:
      - name: rag-ingest
        image: python:3.11-slim
        command: ["python", "/app/rag_pipeline.py", "ingest", "/docs/*.md"]
        envFrom:
        - configMapRef:
            name: rag-config
        - secretRef:
            name: qdrant-apikey
        volumeMounts:
        - name: docs
          mountPath: /docs
        - name: script
          mountPath: /app
      volumes:
      - name: docs
        persistentVolumeClaim:
          claimName: documents-pvc
      - name: script
        configMap:
          name: rag-script
      restartPolicy: Never
```

### Service (for API access)

```yaml
# rag-api.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rag-api
  namespace: ai-inference
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rag-api
  template:
    metadata:
      labels:
        app: rag-api
    spec:
      containers:
      - name: rag-api
        image: your-registry/rag-pipeline:latest
        args: ["serve"]  # Would need FastAPI wrapper
        ports:
        - containerPort: 8000
        envFrom:
        - configMapRef:
            name: rag-config
        - secretRef:
            name: qdrant-apikey
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: rag-api
  namespace: ai-inference
spec:
  selector:
    app: rag-api
  ports:
  - port: 8000
    targetPort: 8000
```

## Integration with SeaweedFS

Store documents in SeaweedFS and ingest into Qdrant:

```python
import boto3
from rag_pipeline import RAGPipeline

# S3 client for SeaweedFS
s3 = boto3.client(
    's3',
    endpoint_url='https://s3.ai-platform.localhost',
    aws_access_key_id='admin',
    aws_secret_access_key='admin-secret',
    verify=False  # Self-signed cert
)

# List documents
bucket = 'rag-documents'
objects = s3.list_objects_v2(Bucket=bucket)

# Initialize RAG
rag = RAGPipeline()

# Ingest each document
for obj in objects.get('Contents', []):
    key = obj['Key']
    response = s3.get_object(Bucket=bucket, Key=key)
    content = response['Body'].read().decode('utf-8')
    
    rag.ingest_text(content, source=key, metadata={
        "bucket": bucket,
        "s3_key": key,
        "size": obj['Size']
    })
```

## Troubleshooting

### Connection Refused

```bash
# Check services are running
kubectl get pods -n ai-inference

# Check port-forward is active
ps aux | grep port-forward

# Test connectivity
curl http://localhost:6333/collections
curl http://localhost:11434/api/tags
```

### Invalid API Key

```bash
# Get the actual API key from the pod
kubectl exec -n ai-inference qdrant-0 -- cat /qdrant/config/local.yaml

# The key shown should be used (not the one in the Secret which may differ)
```

### Embedding Timeout

```bash
# Check Ollama logs
kubectl logs -n ai-inference deployment/ollama --tail=50

# Test embedding directly
curl -X POST http://localhost:11434/api/embeddings \
  -d '{"model": "nomic-embed-text", "prompt": "test"}'
```

### Empty Search Results

```bash
# Check collection has documents
python rag_pipeline.py stats

# If empty, ingest documents first
python rag_pipeline.py ingest your-docs/*.md
```

## Performance Tuning

### Chunk Size

| Chunk Size | Pros | Cons |
|------------|------|------|
| 500 chars | More precise retrieval | More chunks, slower |
| 1000 chars | Balanced | Default |
| 2000 chars | Faster, less chunks | Less precise |

### Top K

| Top K | Use Case |
|-------|----------|
| 1-2 | Simple factual questions |
| 3-5 | General questions (default) |
| 5-10 | Complex multi-topic questions |

### Batch Size

For large ingestion, modify the script to batch embeddings:

```python
def embed_batch(texts, batch_size=10):
    results = []
    for i in range(0, len(texts), batch_size):
        batch = texts[i:i+batch_size]
        results.extend([embed(t) for t in batch])
    return results
```

## Security Considerations

| Risk | Mitigation |
|------|------------|
| API Key exposure | Use Kubernetes Secrets, rotate regularly |
| Prompt injection | Validate/sanitize user input |
| Data leakage | Use collection isolation by tenant |
| Network access | NetworkPolicies limit pod communication |

## Next Steps

1. **Add FastAPI wrapper** for REST API access
2. **Integrate with Open WebUI** as external RAG source
3. **Add authentication** (OAuth2/Keycloak)
4. **Deploy to Kubernetes** with ArgoCD
5. **Add monitoring** (Prometheus metrics)

## References

- [Qdrant Documentation](https://qdrant.tech/documentation/)
- [Qdrant REST API](https://qdrant.github.io/qdrant/redoc/index.html)
- [Ollama API](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [RAG Best Practices](https://www.pinecone.io/learn/retrieval-augmented-generation/)
- [Open WebUI RAG Guide](openwebui-rag-guide.md)
