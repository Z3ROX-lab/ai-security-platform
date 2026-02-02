# Phase 6: AI Data Layer

## Overview

Phase 6 deploys the data infrastructure required for AI/ML workloads:

| Component | Purpose | Status |
|-----------|---------|--------|
| **SeaweedFS** | S3-compatible object storage | ✅ Completed |
| **Qdrant** | Vector database for RAG | ✅ Completed |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      AI DATA LAYER                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────┐    ┌─────────────────────────┐    │
│  │       SEAWEEDFS         │    │         QDRANT          │    │
│  │    (Object Storage)     │    │      (Vector DB)        │    │
│  │                         │    │                         │    │
│  │  • ML model artifacts   │    │  • Document embeddings  │    │
│  │  • Training datasets    │    │  • Semantic search      │    │
│  │  • RAG documents        │    │  • RAG retrieval        │    │
│  │  • Backup archives      │    │  • Similarity matching  │    │
│  │                         │    │                         │    │
│  │  S3 API: :8333          │    │  REST: :6333            │    │
│  │  Filer UI: :8888        │    │  gRPC: :6334            │    │
│  └─────────────────────────┘    └─────────────────────────┘    │
│                                                                 │
│  RAG PIPELINE                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                                                          │   │
│  │  Option A: Open WebUI (built-in ChromaDB)               │   │
│  │  Option B: Custom RAG (Qdrant + Python script)          │   │
│  │                                                          │   │
│  │  Document → Chunks → Embedding → Vector DB → LLM        │   │
│  │                       (nomic-embed-text)    (Mistral)   │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  URLs:                                                          │
│  • https://seaweedfs.ai-platform.localhost (Filer UI)          │
│  • https://s3.ai-platform.localhost (S3 API)                   │
│  • https://qdrant.ai-platform.localhost (Vector DB API)        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Why SeaweedFS over MinIO?

MinIO entered **maintenance mode in December 2025**:
- No new features or enhancements
- No pull requests accepted
- Docker images pulled from Docker Hub
- Users directed to paid MinIO AIStor ($96K/year minimum)

SeaweedFS is the recommended alternative:
- ✅ Apache 2.0 license (permissive)
- ✅ Actively maintained
- ✅ Low resource footprint (~500MB RAM)
- ✅ S3-compatible API
- ✅ Simple single-node deployment

See [ADR-004: Storage Strategy](../../docs/adr/ADR-004-storage-strategy.md) for details.

## Prerequisites

Before starting Phase 6, ensure you have completed:

- [x] Phase 1: Infrastructure (K3d, ArgoCD)
- [x] Phase 2-3: Security (Keycloak, PostgreSQL)
- [x] Phase 4: Security Baseline
- [x] Phase 5: AI Inference (Ollama, Open WebUI)

### ⚠️ PodSecurity Requirement

SeaweedFS uses `hostPath` volumes for logs, requiring the `storage` namespace to be `privileged`:

```bash
# Verify current labels
kubectl get namespace storage --show-labels | grep pod-security

# If restricted, update security-baseline manifests:
# argocd/applications/security/security-baseline/manifests/namespaces.yaml
```

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: storage
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
```

## Deployment Order

1. **SeaweedFS** - Object storage (this phase)
2. **Qdrant** - Vector database (next)

## Guides

| Guide | Description |
|-------|-------------|
| [SeaweedFS Guide](seaweedfs-guide.md) | Deploy S3-compatible object storage |
| [Qdrant Guide](qdrant-guide.md) | Deploy vector database for RAG |
| [Open WebUI RAG Guide](openwebui-rag-guide.md) | Built-in RAG with ChromaDB |
| [Custom RAG with Qdrant](qdrant-rag-guide.md) | Python RAG pipeline with Qdrant |

## Resource Requirements

| Component | CPU Request | Memory Request | Storage |
|-----------|-------------|----------------|---------|
| SeaweedFS Master | 100m | 128Mi | 1Gi |
| SeaweedFS Volume | 100m | 256Mi | 10Gi |
| SeaweedFS Filer | 100m | 256Mi | 2Gi |
| SeaweedFS Admin | 50m | 64Mi | - |
| Qdrant | 100m | 256Mi | 5Gi |
| **Total** | ~550m | ~1.0Gi | ~18Gi |

## Quick Start

### 1. Add DNS entries

```bash
# Add to /etc/hosts (or Windows hosts file)
127.0.0.1 seaweedfs.ai-platform.localhost
127.0.0.1 s3.ai-platform.localhost
127.0.0.1 qdrant.ai-platform.localhost
```

### 2. Deploy SeaweedFS

```bash
# ArgoCD will auto-sync, or manually apply:
kubectl apply -f argocd/applications/storage/seaweedfs/application.yaml

# Watch deployment
kubectl get pods -n storage -w
```

### 3. Verify

```bash
# Check pods
kubectl get pods -n storage

# Check ingress
kubectl get ingress -n storage

# Test S3 API
curl -k https://s3.ai-platform.localhost
```

### 4. Create Buckets

Open https://seaweedfs.ai-platform.localhost and click **New Folder** to create:

| Bucket | Purpose |
|--------|---------|
| `mlflow-artifacts` | MLflow model artifacts |
| `datasets` | Training datasets |
| `backups` | PostgreSQL backups |
| `rag-documents` | Documents for RAG |

### 5. Access UIs

- **Filer UI**: https://seaweedfs.ai-platform.localhost
- **S3 API**: https://s3.ai-platform.localhost

### 6. Deploy Qdrant

```bash
# ArgoCD will auto-sync, or manually apply:
kubectl apply -f argocd/applications/ai/qdrant/application.yaml

# Watch deployment
kubectl get pods -n ai-inference -w
```

### 7. Verify Qdrant

```bash
# Check pods
kubectl get pods -n ai-inference -l app.kubernetes.io/name=qdrant

# Check ingress
kubectl get ingress -n ai-inference

# Test API
curl -k https://qdrant.ai-platform.localhost/healthz
```

### 8. Access All UIs

| Service | URL |
|---------|-----|
| SeaweedFS Filer | https://seaweedfs.ai-platform.localhost |
| SeaweedFS S3 | https://s3.ai-platform.localhost |
| Qdrant | https://qdrant.ai-platform.localhost/dashboard |

## Use Cases

### MLflow Artifact Storage

```python
# MLflow configuration
export MLFLOW_S3_ENDPOINT_URL=https://s3.ai-platform.localhost
export AWS_ACCESS_KEY_ID=admin
export AWS_SECRET_ACCESS_KEY=admin-secret
```

### RAG Document Storage

```python
import boto3

s3 = boto3.client(
    's3',
    endpoint_url='https://s3.ai-platform.localhost',
    aws_access_key_id='admin',
    aws_secret_access_key='admin-secret',
    verify=False  # Self-signed cert
)

# Upload document
s3.upload_file('document.pdf', 'rag-documents', 'document.pdf')
```

### Backup Storage

```bash
# Backup PostgreSQL to SeaweedFS
pg_dump -U postgres dbname | \
  aws s3 cp - s3://backups/postgres/$(date +%Y%m%d).sql \
  --endpoint-url https://s3.ai-platform.localhost
```

## Troubleshooting

### PodSecurity violation

If pods fail to start with error:
```
violates PodSecurity "restricted:latest": hostPath volumes
```

**Solution**: Set namespace to privileged:

```bash
kubectl label namespace storage \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/warn=privileged \
  pod-security.kubernetes.io/audit=privileged \
  --overwrite

# Force pod recreation
kubectl delete statefulset -n storage seaweedfs-master seaweedfs-filer
```

### Pods not starting

```bash
# Check events
kubectl describe pod -n storage seaweedfs-master-0

# Check logs
kubectl logs -n storage seaweedfs-master-0
```

### S3 API errors

```bash
# Test with curl
curl -k https://s3.ai-platform.localhost

# Check filer logs
kubectl logs -n storage seaweedfs-filer-0
```

### Storage issues

```bash
# Check PVCs
kubectl get pvc -n storage

# Check storage class
kubectl get storageclass
```

## Next Steps

After completing Phase 6:

1. ✅ **SeaweedFS buckets** created (mlflow-artifacts, datasets, backups, rag-documents)
2. ✅ **Embedding model** deployed (nomic-embed-text via Ollama)
3. ✅ **Open WebUI RAG** configured (built-in ChromaDB)
4. ✅ **Custom RAG script** available (rag_pipeline.py with Qdrant)

**Choose your next phase:**
- **Phase 7**: NeMo Guardrails (AI Safety)
- **Phase 8**: Observability (Prometheus, Grafana, Loki, Falco)

## RAG Options Comparison

| Feature | Open WebUI RAG | Custom Qdrant RAG |
|---------|----------------|-------------------|
| **Vector Store** | ChromaDB (internal) | Qdrant (external) |
| **Setup** | Built-in, zero config | Python script |
| **Access** | UI only | API + CLI |
| **Visibility** | Black box | Full access to vectors |
| **Best For** | Quick start | Portfolio, Production |

See guides:
- [Open WebUI RAG Guide](openwebui-rag-guide.md)
- [Custom RAG with Qdrant](qdrant-rag-guide.md)
