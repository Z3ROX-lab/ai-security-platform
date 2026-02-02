# Open WebUI RAG Guide

## Overview

Open WebUI includes a built-in RAG (Retrieval-Augmented Generation) system using ChromaDB as the internal vector store. This guide covers configuration, document management, and usage.

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Vector Store** | ChromaDB (internal) | Store document embeddings |
| **Embedding Model** | nomic-embed-text (Ollama) | Convert text to vectors |
| **LLM** | Mistral 7B (Ollama) | Generate responses |
| **UI** | Open WebUI | Document upload & chat |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      OPEN WEBUI RAG PIPELINE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  INDEXATION (once per document)                                             │
│  ══════════════════════════════                                             │
│                                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                  │
│  │   Document   │    │   Ollama     │    │   ChromaDB   │                  │
│  │  (PDF/MD)    │───▶│   nomic-     │───▶│  (internal)  │                  │
│  │              │    │ embed-text   │    │              │                  │
│  │  Upload UI   │    │  Embedding   │    │  Vectors +   │                  │
│  │              │    │              │    │  Metadata    │                  │
│  └──────────────┘    └──────────────┘    └──────────────┘                  │
│                                                                             │
│  QUERY (each question)                                                      │
│  ═════════════════════                                                      │
│                                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                  │
│  │   Question   │    │   Ollama     │    │   ChromaDB   │                  │
│  │              │───▶│   nomic-     │───▶│   Semantic   │                  │
│  │  "What is    │    │ embed-text   │    │    Search    │                  │
│  │   Qdrant?"   │    │              │    │              │                  │
│  └──────────────┘    └──────────────┘    └──────┬───────┘                  │
│                                                  │                          │
│                                                  ▼                          │
│                                          ┌──────────────┐                  │
│                                          │  Top K Chunks│                  │
│                                          │  (relevant)  │                  │
│                                          └──────┬───────┘                  │
│                                                  │                          │
│                                                  ▼                          │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                         OLLAMA (Mistral 7B)                          │  │
│  │                                                                      │  │
│  │  System: "Use the following context to answer the question..."      │  │
│  │  Context: [Top K chunks from ChromaDB]                              │  │
│  │  Question: "What is Qdrant?"                                        │  │
│  │                                                                      │  │
│  │  Response: "Based on the documentation, Qdrant is a vector         │  │
│  │            database chosen for the RAG pipeline because..."         │  │
│  │                                                                      │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

### 1. Embedding Model

Download the embedding model in Ollama:

```bash
kubectl exec -it -n ai-inference deployment/ollama -- ollama pull nomic-embed-text

# Verify
kubectl exec -it -n ai-inference deployment/ollama -- ollama list
```

Expected output:
```
NAME                            ID              SIZE    MODIFIED
nomic-embed-text:latest         0a109f422b47    274 MB  ...
mistral:7b-instruct-v0.3-q4_K_M 6577803aa9a0    4.4 GB  ...
```

### 2. Available Embedding Models

| Model | Size | Dimensions | Quality | Speed |
|-------|------|------------|---------|-------|
| **nomic-embed-text** | 274 MB | 768 | Good | ⚡ Fast |
| mxbai-embed-large | 670 MB | 1024 | Better | Medium |
| all-minilm | 46 MB | 384 | Basic | ⚡⚡ Fastest |

## Configuration

### Step 1: Access Admin Settings

1. Open https://chat.ai-platform.localhost
2. Sign in via Keycloak
3. Go to **Admin Panel** → **Settings** → **Documents**

### Step 2: Configure Embedding

| Setting | Value |
|---------|-------|
| **Embedding Model Engine** | Ollama |
| **Ollama API URL** | `http://ollama.ai-inference.svc.cluster.local:11434` |
| **Embedding Model** | `nomic-embed-text:latest` |

### Step 3: Configure Chunking

| Setting | Recommended | Description |
|---------|-------------|-------------|
| **Content Extraction Engine** | Default | Text extraction method |
| **Chunk Size** | 1000 | Characters per chunk |
| **Chunk Overlap** | 100 | Overlap between chunks |
| **Text Splitter** | Default (Character) | Split method |

### Step 4: Configure Retrieval

| Setting | Recommended | Description |
|---------|-------------|-------------|
| **Top K** | 3-5 | Number of chunks to retrieve |
| **Full Context Mode** | Off | Include all chunks (slow) |
| **Hybrid Search** | Off | Combine semantic + keyword |

### Step 5: Save

Click **Save** at the bottom of the page.

## Document Management

### Create a Knowledge Base

1. Go to **Workspace** → **Knowledge**
2. Click **+ Create Knowledge**
3. Fill in:
   - **Name**: `AI Platform Docs`
   - **Description**: `Architecture Decision Records and documentation`
   - **Visibility**: Private or Public

### Upload Documents

Supported formats:
- **Text**: `.txt`, `.md`, `.csv`, `.json`
- **Documents**: `.pdf`, `.docx`, `.doc`
- **Code**: `.py`, `.js`, `.yaml`, `.yml`

Upload methods:
1. **Drag and drop** files into the knowledge base
2. Click **+** to browse and select files

### Document Processing

When you upload a document:

```
Upload → Extract Text → Chunk → Embed → Store in ChromaDB
  │          │            │        │           │
  │          │            │        │           └─ Vectors + metadata
  │          │            │        └─ nomic-embed-text (768 dims)
  │          │            └─ 1000 chars, 100 overlap
  │          └─ PDF/DOCX/MD parser
  └─ file.pdf
```

Processing time depends on:
- Document size
- CPU resources (no GPU = slower)
- Number of chunks

### Verify Documents

After upload, you should see:
- Document name with file size
- Status indicator (processing/ready)

## Using RAG in Chat

### Method 1: Select Knowledge Base

1. Start a **New Chat**
2. Select your model (e.g., `mistral:7b`)
3. Type `#` in the message field
4. Select your knowledge base (e.g., `AI Platform Docs`)
5. Ask your question

Example:
```
#AI Platform Docs What is the VectorDB strategy?
```

### Method 2: Attach Documents

1. Click the **📎** (attach) icon
2. Select specific documents
3. Ask your question

### RAG Response Format

When RAG is active, the LLM receives:

```
### Task:
Respond to the user query using the provided context, 
incorporating inline citations in the format [id] 
**only when the <source> tag includes an explicit id attribute**.

### Context:
<source id="1">
Chunk 1 content from ADR-006...
</source>
<source id="2">
Chunk 2 content from ADR-006...
</source>

### User Query:
What is the VectorDB strategy?
```

## Troubleshooting

### JSON Parse Error

**Symptom**: `SyntaxError: JSON.parse: unexpected character at line 1`

**Solutions**:
1. Restart Open WebUI pod:
   ```bash
   kubectl delete pod -n ai-apps open-webui-0
   kubectl get pods -n ai-apps -w
   ```

2. Check Ollama connection:
   ```bash
   kubectl logs -n ai-apps open-webui-0 --tail=50
   ```

3. Verify Ollama URL in Admin Settings → Documents

### Slow Responses

**Cause**: CPU-only inference (no GPU)

**Expected times**:
| Operation | CPU | GPU |
|-----------|-----|-----|
| Embedding (per doc) | 5-30s | <1s |
| LLM response | 30-120s | 2-5s |

**Mitigation**:
- Use smaller model (`mistral:7b-q4`)
- Reduce Top K (3 instead of 5)
- Use smaller documents

### Documents Not Found

**Check**:
1. Knowledge base is created and has documents
2. Documents show as "ready" (not "processing")
3. You selected the knowledge base with `#`

**Re-index documents**:
1. Go to **Workspace** → **Knowledge**
2. Delete and re-upload problematic documents

### Embedding Model Not Working

**Verify model is loaded**:
```bash
kubectl exec -n ai-inference deployment/ollama -- ollama list
```

**Check Ollama logs**:
```bash
kubectl logs -n ai-inference deployment/ollama --tail=30 | grep -i embed
```

## Best Practices

### Document Organization

| Collection | Use Case | Example Documents |
|------------|----------|-------------------|
| `AI Platform Docs` | Project documentation | ADRs, READMEs, guides |
| `Security Policies` | Security guidelines | OWASP, compliance docs |
| `Code Docs` | Code documentation | API docs, code comments |

### Optimal Chunk Size

| Document Type | Chunk Size | Overlap |
|---------------|------------|---------|
| Technical docs | 1000 | 100 |
| Code files | 500 | 50 |
| Long-form text | 1500 | 150 |

### Query Tips

**Good queries**:
- Specific: "What VectorDB was chosen and why?"
- Contextual: "Compare Qdrant vs Milvus from the ADR"

**Poor queries**:
- Too broad: "Tell me about the project"
- No context: "What is Kubernetes?" (doesn't need RAG)

## Monitoring

### Check Logs

```bash
# Open WebUI logs
kubectl logs -n ai-apps open-webui-0 --tail=50

# Ollama logs (embedding + inference)
kubectl logs -n ai-inference deployment/ollama --tail=50
```

### Verify RAG is Working

In Open WebUI logs, you should see:
```
query_doc:result [['chunk-id-1', 'chunk-id-2', 'chunk-id-3']]
```

This confirms chunks were retrieved from ChromaDB.

## Limitations

| Limitation | Description | Workaround |
|------------|-------------|------------|
| **No external vector DB** | Uses internal ChromaDB | Use custom RAG with Qdrant |
| **No fine-grained access** | All docs in collection shared | Create separate collections |
| **CPU-only slow** | No GPU acceleration | Be patient or add GPU |
| **Limited file types** | Some formats not supported | Convert to PDF/MD |

## Next Steps

For production use cases requiring:
- External vector database (Qdrant)
- Custom retrieval logic
- API access to RAG pipeline

See the [Custom RAG with Qdrant Guide](qdrant-rag-guide.md).

## References

- [Open WebUI Documentation](https://docs.openwebui.com/)
- [Open WebUI RAG Features](https://docs.openwebui.com/features/rag/)
- [Ollama Embedding Models](https://ollama.com/library?q=embed)
- [ChromaDB Documentation](https://docs.trychroma.com/)
