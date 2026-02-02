# Qdrant Deployment Guide

## Overview

Qdrant is a vector database for the RAG (Retrieval-Augmented Generation) pipeline, enabling semantic search over document embeddings.

| Attribute | Value |
|-----------|-------|
| **License** | Apache 2.0 |
| **REST API** | https://qdrant.ai-platform.localhost |
| **gRPC** | qdrant.ai-inference.svc:6334 (internal) |
| **Namespace** | ai-inference |
| **Helm Chart** | qdrant/qdrant |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         RAG PIPELINE                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐    │
│  │   Document   │     │  Embedding   │     │   Qdrant     │    │
│  │   (PDF/MD)   │────▶│    Model     │────▶│  VectorDB    │    │
│  │              │     │  (MiniLM)    │     │              │    │
│  └──────────────┘     └──────────────┘     └──────┬───────┘    │
│                                                    │            │
│  ┌──────────────┐     ┌──────────────┐            │            │
│  │    User      │     │   Ollama     │◀───────────┘            │
│  │   Question   │────▶│    LLM       │  (relevant context)     │
│  │              │     │              │                          │
│  └──────────────┘     └──────────────┘                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### How It Works

1. **Document Ingestion**
   - Documents are split into chunks (~512 tokens)
   - Each chunk is converted to a vector (embedding)
   - Vectors are stored in Qdrant with metadata

2. **Query Flow**
   - User question is converted to a vector
   - Qdrant finds similar vectors (semantic search)
   - Top results are sent to LLM as context
   - LLM generates answer using the context

## Prerequisites

### 1. DNS Configuration

Add to `/etc/hosts`:
```
127.0.0.1 qdrant.ai-platform.localhost
```

### 2. Verify Cluster

```bash
# Check ai-inference namespace exists
kubectl get namespace ai-inference

# Check Ollama is running
kubectl get pods -n ai-inference
```

## Deployment

### Step 1: Create Directory Structure

```bash
mkdir -p ~/work/ai-security-platform/argocd/applications/ai/qdrant
```

### Step 2: Copy Files

```bash
cp ~/Downloads/qdrant-application.yaml \
   ~/work/ai-security-platform/argocd/applications/ai/qdrant/application.yaml

cp ~/Downloads/qdrant-values.yaml \
   ~/work/ai-security-platform/argocd/applications/ai/qdrant/values.yaml
```

### Step 3: Create API Key Secret (Optional but Recommended)

```bash
# Generate a random API key
API_KEY=$(openssl rand -hex 32)

# Create secret
kubectl create secret generic qdrant-api-key \
  --from-literal=api-key=$API_KEY \
  -n ai-inference

# Save the key securely
echo "Qdrant API Key: $API_KEY"
```

### Step 4: Commit and Push

```bash
cd ~/work/ai-security-platform

git add argocd/applications/ai/qdrant/
git commit -m "feat(phase-06): add Qdrant vector database for RAG"
git push
```

### Step 5: Verify Deployment

```bash
# Watch pod creation
kubectl get pods -n ai-inference -w

# Check ArgoCD application
kubectl get application qdrant -n argocd

# Verify ingress
kubectl get ingress -n ai-inference
```

## Usage

### REST API

#### Health Check

```bash
curl -k https://qdrant.ai-platform.localhost/healthz
```

#### List Collections

```bash
curl -k https://qdrant.ai-platform.localhost/collections
```

#### Create Collection

```bash
curl -k -X PUT https://qdrant.ai-platform.localhost/collections/documents \
  -H "Content-Type: application/json" \
  -d '{
    "vectors": {
      "size": 384,
      "distance": "Cosine"
    }
  }'
```

**Note**: Vector size 384 matches `all-MiniLM-L6-v2` embedding model.

#### Insert Vectors

```bash
curl -k -X PUT https://qdrant.ai-platform.localhost/collections/documents/points \
  -H "Content-Type: application/json" \
  -d '{
    "points": [
      {
        "id": 1,
        "vector": [0.1, 0.2, 0.3, ...],
        "payload": {
          "text": "Kubernetes is a container orchestration platform",
          "source": "docs/k8s.md",
          "chunk_id": 1
        }
      }
    ]
  }'
```

#### Search

```bash
curl -k -X POST https://qdrant.ai-platform.localhost/collections/documents/points/search \
  -H "Content-Type: application/json" \
  -d '{
    "vector": [0.1, 0.2, 0.3, ...],
    "limit": 5,
    "with_payload": true
  }'
```

### Python Client

```python
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct

# Connect to Qdrant
client = QdrantClient(
    url="https://qdrant.ai-platform.localhost",
    api_key="your-api-key",  # If authentication enabled
    https=True,
    verify=False  # Self-signed cert
)

# Create collection
client.create_collection(
    collection_name="documents",
    vectors_config=VectorParams(
        size=384,  # all-MiniLM-L6-v2 dimensions
        distance=Distance.COSINE
    )
)

# Insert vectors
client.upsert(
    collection_name="documents",
    points=[
        PointStruct(
            id=1,
            vector=[0.1, 0.2, 0.3, ...],  # 384 dimensions
            payload={
                "text": "Kubernetes is a container orchestration platform",
                "source": "docs/k8s.md"
            }
        )
    ]
)

# Search
results = client.search(
    collection_name="documents",
    query_vector=[0.1, 0.2, 0.3, ...],
    limit=5
)

for result in results:
    print(f"Score: {result.score}, Text: {result.payload['text']}")
```

### With Sentence Transformers

```python
from sentence_transformers import SentenceTransformer
from qdrant_client import QdrantClient
from qdrant_client.models import PointStruct

# Load embedding model
model = SentenceTransformer('all-MiniLM-L6-v2')

# Connect to Qdrant
client = QdrantClient(
    url="https://qdrant.ai-platform.localhost",
    https=True,
    verify=False
)

# Embed and store documents
documents = [
    "Kubernetes manages containerized applications",
    "Docker is a container runtime",
    "Helm is a package manager for Kubernetes"
]

embeddings = model.encode(documents)

points = [
    PointStruct(
        id=i,
        vector=embedding.tolist(),
        payload={"text": doc}
    )
    for i, (doc, embedding) in enumerate(zip(documents, embeddings))
]

client.upsert(collection_name="documents", points=points)

# Search
query = "How to deploy containers?"
query_vector = model.encode(query).tolist()

results = client.search(
    collection_name="documents",
    query_vector=query_vector,
    limit=3
)

for result in results:
    print(f"Score: {result.score:.3f} - {result.payload['text']}")
```

### With LangChain

```python
from langchain_community.vectorstores import Qdrant
from langchain_community.embeddings import HuggingFaceEmbeddings
from langchain.text_splitter import RecursiveCharacterTextSplitter

# Initialize embeddings
embeddings = HuggingFaceEmbeddings(
    model_name="all-MiniLM-L6-v2"
)

# Create vector store
vectorstore = Qdrant.from_documents(
    documents=docs,  # LangChain Document objects
    embedding=embeddings,
    url="https://qdrant.ai-platform.localhost",
    collection_name="documents",
    prefer_grpc=False,
    https=True,
    verify=False
)

# Search
results = vectorstore.similarity_search(
    query="How to deploy on Kubernetes?",
    k=5
)

for doc in results:
    print(doc.page_content)
```

## Collection Strategy

As per ADR-006, create separate collections for isolation:

| Collection | Use Case | Classification |
|------------|----------|----------------|
| `documents_general` | General knowledge base | Public |
| `documents_security` | Security policies | Internal |
| `documents_code` | Code documentation | Internal |
| `documents_incidents` | Incident reports | Confidential |

```bash
# Create collections
for collection in documents_general documents_security documents_code documents_incidents; do
  curl -k -X PUT "https://qdrant.ai-platform.localhost/collections/$collection" \
    -H "Content-Type: application/json" \
    -d '{
      "vectors": {
        "size": 384,
        "distance": "Cosine"
      }
    }'
done
```

## Monitoring

### Metrics Endpoint

```bash
# Prometheus metrics
curl -k https://qdrant.ai-platform.localhost/metrics
```

### Collection Info

```bash
# Get collection details
curl -k https://qdrant.ai-platform.localhost/collections/documents

# Response includes:
# - vectors_count: Number of vectors stored
# - points_count: Number of points
# - segments_count: Number of storage segments
# - status: green/yellow/red
```

### Telemetry

```bash
curl -k https://qdrant.ai-platform.localhost/telemetry
```

## Troubleshooting

### Pod Not Starting

```bash
# Check events
kubectl describe pod -n ai-inference -l app.kubernetes.io/name=qdrant

# Check logs
kubectl logs -n ai-inference -l app.kubernetes.io/name=qdrant
```

### PVC Pending

```bash
# Check PVC status
kubectl get pvc -n ai-inference

# Check storage class
kubectl get storageclass
```

### Connection Refused

```bash
# Check service
kubectl get svc -n ai-inference qdrant

# Port-forward for direct test
kubectl port-forward -n ai-inference svc/qdrant 6333:6333

# Test
curl http://localhost:6333/healthz
```

### Ingress Not Working

```bash
# Check ingress
kubectl describe ingress -n ai-inference qdrant

# Check certificate
kubectl get certificate -n ai-inference

# Check Traefik logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik
```

### API Key Issues

```bash
# If using API key, include in requests:
curl -k -H "api-key: your-api-key" \
  https://qdrant.ai-platform.localhost/collections

# Check secret exists
kubectl get secret -n ai-inference qdrant-api-key
```

## Backup and Restore

### Create Snapshot

```bash
# Snapshot a collection
curl -k -X POST \
  https://qdrant.ai-platform.localhost/collections/documents/snapshots
```

### List Snapshots

```bash
curl -k https://qdrant.ai-platform.localhost/collections/documents/snapshots
```

### Restore from Snapshot

```bash
# Download snapshot
curl -k -O \
  https://qdrant.ai-platform.localhost/collections/documents/snapshots/<snapshot-name>

# Restore (requires restart with snapshot file)
```

## Cleanup

To remove Qdrant:

```bash
# Delete ArgoCD application
kubectl delete application -n argocd qdrant

# Delete PVC (data will be lost!)
kubectl delete pvc -n ai-inference -l app.kubernetes.io/name=qdrant

# Delete secret
kubectl delete secret -n ai-inference qdrant-api-key
```

## Next Steps

After deploying Qdrant:

1. **Create collections** for your use cases
2. **Deploy embedding model** (all-MiniLM-L6-v2 via Ollama or separate service)
3. **Build ingestion pipeline** to populate vectors
4. **Integrate with Open WebUI** or custom RAG application

## References

- [Qdrant Documentation](https://qdrant.tech/documentation/)
- [Qdrant Python Client](https://github.com/qdrant/qdrant-client)
- [Qdrant Helm Chart](https://github.com/qdrant/qdrant-helm)
- [Sentence Transformers](https://www.sbert.net/)
- [LangChain Qdrant Integration](https://python.langchain.com/docs/integrations/vectorstores/qdrant)
- [ADR-006: VectorDB Strategy](../../docs/adr/ADR-006-VectorDB-Strategy.md)
- [ADR-007: Embedding Strategy](../../docs/adr/ADR-007-embedding-strategy.md)
