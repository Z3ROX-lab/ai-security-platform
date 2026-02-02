# ADR-006: VectorDB Strategy

## Status
**Accepted**

## Date
2025-01-21

## Context

The AI Security Platform requires a vector database for the RAG (Retrieval-Augmented Generation) pipeline. Vector databases store document embeddings and enable semantic search to find relevant context for LLM responses.

### What is a VectorDB?

```
Traditional DB:  "Find documents WHERE title = 'contract'"     → Exact match
Vector DB:       "Find documents SIMILAR TO 'contract terms'"  → Semantic match
```

### Why We Need It

| Component | Role in RAG Pipeline |
|-----------|---------------------|
| **Embedding Model** | Converts text → vectors (arrays of numbers) |
| **VectorDB** | Stores vectors + enables similarity search |
| **LLM** | Generates answers using retrieved context |

### Requirements

| Requirement | Priority | Notes |
|-------------|----------|-------|
| Low memory footprint | Must have | RAM needed for Ollama (8-10GB) |
| Kubernetes native | Must have | Helm chart, StatefulSet |
| Simple to operate | Must have | Home lab, single operator |
| Collection isolation | Must have | Separate data by use case |
| API key authentication | Must have | Secure access |
| Production-viable | Should have | Skills transferable to enterprise |
| Active community | Should have | Support, updates |
| Open source | Must have | No vendor lock-in |

---

## Options Considered

### Option 1: Qdrant

| Aspect | Details |
|--------|---------|
| **Description** | Purpose-built vector database, Rust-based |
| **License** | Apache 2.0 |
| **Memory** | ~200-300MB base |
| **Helm Chart** | ✅ Official `qdrant/qdrant` |

#### Pros
- ✅ Very low memory footprint (critical for home lab)
- ✅ Simple API, excellent documentation
- ✅ Native collection isolation
- ✅ API key authentication per collection
- ✅ Rust = fast and memory-safe
- ✅ Active development, growing community
- ✅ Cloud offering exists (skills transferable)

#### Cons
- ⚠️ Smaller ecosystem than Milvus
- ⚠️ Less advanced RBAC than Milvus (no user/role model)
- ⚠️ Newer project (2021)

---

### Option 2: Milvus

| Aspect | Details |
|--------|---------|
| **Description** | Enterprise-grade vector database, CNCF project |
| **License** | Apache 2.0 |
| **Memory** | ~1-2GB minimum (with dependencies) |
| **Helm Chart** | ✅ Official `milvus-io/milvus` |

#### Pros
- ✅ CNCF project, enterprise adoption
- ✅ Advanced RBAC (users, roles, privileges)
- ✅ Scales to billions of vectors
- ✅ Multiple index types (IVF, HNSW, DiskANN)
- ✅ Hybrid search (vector + scalar filtering)

#### Cons
- ❌ Heavy: requires etcd, MinIO, Pulsar (or standalone mode ~1GB+)
- ❌ Complex architecture for home lab
- ❌ Overkill for our scale
- ❌ Steeper learning curve

---

### Option 3: Chroma

| Aspect | Details |
|--------|---------|
| **Description** | Developer-friendly embedding database |
| **License** | Apache 2.0 |
| **Memory** | ~150MB |
| **Helm Chart** | ❌ No official chart |

#### Pros
- ✅ Extremely simple API
- ✅ Great for prototyping
- ✅ Python-native

#### Cons
- ❌ No official Helm chart
- ❌ Limited production features
- ❌ No built-in authentication
- ❌ Not designed for Kubernetes

---

### Option 4: Weaviate

| Aspect | Details |
|--------|---------|
| **Description** | AI-native vector database with modules |
| **License** | BSD-3-Clause |
| **Memory** | ~500MB-1GB |
| **Helm Chart** | ✅ Official |

#### Pros
- ✅ Built-in vectorization modules
- ✅ GraphQL API
- ✅ Multi-tenancy support

#### Cons
- ⚠️ Higher memory than Qdrant
- ⚠️ Module system adds complexity
- ⚠️ Less straightforward than Qdrant

---

### Option 5: pgvector (PostgreSQL extension)

| Aspect | Details |
|--------|---------|
| **Description** | Vector similarity search for PostgreSQL |
| **License** | PostgreSQL License |
| **Memory** | Included in PostgreSQL |
| **Helm Chart** | Via Bitnami PostgreSQL + extension |

#### Pros
- ✅ No additional database to manage
- ✅ SQL interface (familiar)
- ✅ ACID transactions with vectors

#### Cons
- ❌ Performance at scale (not purpose-built)
- ❌ Limited index types
- ❌ Missing vector-specific features
- ❌ Doesn't teach dedicated VectorDB concepts

---

## Decision

**We choose Qdrant** for the AI Security Platform.

### Decision Matrix

| Criteria | Weight | Qdrant | Milvus | Chroma | Weaviate | pgvector |
|----------|--------|--------|--------|--------|----------|----------|
| Memory footprint | 30% | ⭐⭐⭐ | ⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| K8s native (Helm) | 20% | ⭐⭐⭐ | ⭐⭐⭐ | ⭐ | ⭐⭐⭐ | ⭐⭐ |
| Simplicity | 20% | ⭐⭐⭐ | ⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| Security features | 15% | ⭐⭐ | ⭐⭐⭐ | ⭐ | ⭐⭐ | ⭐⭐ |
| Production-ready | 15% | ⭐⭐⭐ | ⭐⭐⭐ | ⭐ | ⭐⭐⭐ | ⭐⭐ |
| **Total** | | **2.85** | 2.0 | 2.0 | 2.35 | 2.35 |

### Why Qdrant Wins

1. **Memory**: ~200MB vs 1GB+ for Milvus — critical when Ollama needs 8-10GB
2. **Simplicity**: Single binary, no dependencies (etcd, MinIO, Pulsar)
3. **Good enough security**: API keys + collection isolation covers our needs
4. **Learning value**: Concepts transfer to any VectorDB

---

## Architecture

### Deployment Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Namespace: ai-inference                       │
│                                                                  │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐    │
│  │   Ollama     │     │  Embedding   │     │   Qdrant     │    │
│  │   (LLM)      │     │   Model      │     │  (VectorDB)  │    │
│  │              │     │              │     │              │    │
│  │  Port: 11434 │     │  Port: 8080  │     │  Port: 6333  │    │
│  │  ~8GB RAM    │     │  ~1GB RAM    │     │  ~300MB RAM  │    │
│  └──────────────┘     └──────────────┘     └──────────────┘    │
│         ▲                    │                    ▲             │
│         │                    │                    │             │
│         │                    ▼                    │             │
│  ┌──────┴────────────────────────────────────────┴──────┐      │
│  │                    RAG API Service                    │      │
│  │                                                       │      │
│  │  1. Receive question                                  │      │
│  │  2. Generate embedding (via Embedding Model)          │      │
│  │  3. Search similar vectors (via Qdrant)               │      │
│  │  4. Generate answer with context (via Ollama)         │      │
│  │                                                       │      │
│  └───────────────────────────────────────────────────────┘      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Collection Strategy

Each use case gets its own collection for isolation:

```
Qdrant Instance
├── Collection: documents_general
│   ├── Metadata: { source: "wiki", classification: "public" }
│   └── Use: General knowledge base
│
├── Collection: documents_security
│   ├── Metadata: { source: "policies", classification: "internal" }
│   └── Use: Security policies, procedures
│
├── Collection: documents_code
│   ├── Metadata: { source: "github", classification: "internal" }
│   └── Use: Code documentation, READMEs
│
└── Collection: documents_incidents
    ├── Metadata: { source: "jira", classification: "confidential" }
    └── Use: Incident reports, post-mortems
```

### Security Model

```
┌─────────────────────────────────────────────────────────────────┐
│                     QDRANT SECURITY                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  API Key Authentication                                          │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                                                          │    │
│  │  api_key_admin    → All collections (RW)                │    │
│  │  api_key_rag_app  → documents_* collections (RO)        │    │
│  │  api_key_ingestion → documents_* collections (RW)       │    │
│  │                                                          │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  Network Policies                                                │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                                                          │    │
│  │  Ingress:                                                │    │
│  │  • Allow from: RAG API (port 6333)                      │    │
│  │  • Allow from: Ingestion Job (port 6333)                │    │
│  │  • Deny all other                                        │    │
│  │                                                          │    │
│  │  Egress:                                                 │    │
│  │  • Allow to: DNS (port 53)                              │    │
│  │  • Deny all other                                        │    │
│  │                                                          │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation

### Phase 6 Deployment Steps

| Step | Description |
|------|-------------|
| 6.1 | Deploy Qdrant via ArgoCD (official Helm chart) |
| 6.2 | Configure API key authentication |
| 6.3 | Create initial collections |
| 6.4 | Deploy embedding model (all-MiniLM-L6-v2 or similar) |
| 6.5 | Build RAG API service |
| 6.6 | Test end-to-end pipeline |

### ArgoCD Application

```yaml
# argocd/applications/ai/qdrant.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: qdrant
  namespace: argocd
spec:
  project: ai
  source:
    repoURL: https://qdrant.github.io/qdrant-helm
    chart: qdrant
    targetRevision: 0.10.1  # Pin version
    helm:
      valuesObject:
        replicaCount: 1
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        persistence:
          size: 5Gi
        apiKey: true  # Enable API key auth
        config:
          storage:
            storage_path: /qdrant/storage
  destination:
    server: https://kubernetes.default.svc
    namespace: ai-inference
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

### Custom Values

```yaml
# values/qdrant/values.yaml

replicaCount: 1

resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"

persistence:
  enabled: true
  size: 5Gi
  storageClass: longhorn  # Use Longhorn from Phase 2

# Enable API key authentication
apiKey: true

# Qdrant configuration
config:
  log_level: INFO
  storage:
    storage_path: /qdrant/storage
    snapshots_path: /qdrant/snapshots
  service:
    grpc_port: 6334
    http_port: 6333
```

---

## RAG Pipeline Architecture

### Document Ingestion Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Document   │     │   Chunking   │     │  Embedding   │     │   Qdrant     │
│   Source     │────▶│   Service    │────▶│   Model      │────▶│   Storage    │
│              │     │              │     │              │     │              │
│  • PDF       │     │  • Split     │     │  • MiniLM    │     │  • Vector    │
│  • Markdown  │     │  • 512 tokens│     │  • 384 dims  │     │  • Metadata  │
│  • HTML      │     │  • Overlap   │     │              │     │  • Payload   │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
```

### Query Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│    User      │     │  Embedding   │     │   Qdrant     │     │   Ollama     │
│   Question   │────▶│   Model      │────▶│   Search     │────▶│   LLM        │
│              │     │              │     │              │     │              │
│  "How to     │     │  [0.2, -0.4  │     │  Top 5       │     │  Generate    │
│   deploy X?" │     │   0.8, ...]  │     │  similar     │     │  answer      │
│              │     │              │     │  chunks      │     │  with context│
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
```

---

## Embedding Model Choice

| Model | Dimensions | Size | Quality | Speed |
|-------|------------|------|---------|-------|
| **all-MiniLM-L6-v2** | 384 | 80MB | Good | ⚡ Fast |
| all-mpnet-base-v2 | 768 | 420MB | Better | Medium |
| e5-large-v2 | 1024 | 1.3GB | Best | Slow |

**Decision**: Start with `all-MiniLM-L6-v2` for home lab (good balance), upgrade if needed.

---

## Migration Path to Enterprise

| Home Lab | Enterprise | Migration Effort |
|----------|------------|------------------|
| Qdrant (single node) | Qdrant Cloud or Milvus | Low (API similar) |
| API key auth | OIDC + RBAC | Medium |
| 1 collection per use case | Multi-tenant with namespaces | Medium |
| Local storage | Distributed storage | Handled by platform |

---

## OWASP LLM Top 10 Coverage

| Risk | How Qdrant Helps |
|------|------------------|
| **LLM01: Prompt Injection** | Metadata filtering limits context scope |
| **LLM02: Insecure Output** | Not directly (handled by guardrails) |
| **LLM06: Sensitive Info Disclosure** | Collection isolation + API keys |
| **LLM08: Excessive Agency** | Limit collections accessible per API key |
| **LLM10: Model Theft** | Not applicable (stores vectors, not models) |

---

## Consequences

### Positive
- Low memory footprint leaves resources for LLM
- Simple to deploy and operate
- Collection isolation provides good security baseline
- Concepts transferable to enterprise VectorDBs
- Active community and development

### Negative
- Less advanced RBAC than Milvus (no user/role model)
- Smaller ecosystem and fewer integrations
- May need to migrate for very large scale

### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Qdrant doesn't scale | Unlikely at our scale; migrate to Milvus if needed |
| API key leaked | Rotate keys, use Sealed Secrets, short-lived tokens |
| Data loss | Longhorn snapshots + Qdrant snapshots |

---

## References

- [Qdrant Documentation](https://qdrant.tech/documentation/)
- [Qdrant Helm Chart](https://github.com/qdrant/qdrant-helm)
- [Qdrant Security](https://qdrant.tech/documentation/guides/security/)
- [Sentence Transformers](https://www.sbert.net/)
- [RAG Best Practices](https://www.pinecone.io/learn/retrieval-augmented-generation/)
- [OWASP LLM Top 10](https://owasp.org/www-project-top-10-for-large-language-model-applications/)