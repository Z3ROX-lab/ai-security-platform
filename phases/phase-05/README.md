# Phase 5: AI Inference

## Status: ✅ Completed

## Overview

Phase 5 deploys the AI inference layer, enabling local LLM capabilities:

| Component | Description | Status |
|-----------|-------------|--------|
| **Ollama** | Local LLM inference engine | ✅ Deployed |
| **Open WebUI** | ChatGPT-like interface | ✅ Deployed |
| **SSO Integration** | Keycloak authentication | ✅ Configured |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     AI INFERENCE LAYER                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                     OPEN WEBUI                           │   │
│  │           https://chat.ai-platform.localhost             │   │
│  │                                                          │   │
│  │  • ChatGPT-like interface                               │   │
│  │  • Multi-model support                                  │   │
│  │  • Conversation history                                 │   │
│  │  • Document upload (RAG ready)                          │   │
│  │  • Keycloak SSO authentication                          │   │
│  │                                                          │   │
│  └──────────────────────────┬──────────────────────────────┘   │
│                              │ API                              │
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                       OLLAMA                             │   │
│  │           http://ollama.ai-inference.svc:11434           │   │
│  │                                                          │   │
│  │  • Local LLM inference                                  │   │
│  │  • GPU acceleration (if available)                      │   │
│  │  • Multiple models:                                     │   │
│  │    - llama3.2 (3B, 7B)                                  │   │
│  │    - mistral (7B)                                       │   │
│  │    - codellama (7B)                                     │   │
│  │    - nomic-embed-text                                   │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    POSTGRESQL                            │   │
│  │             (Open WebUI Database)                        │   │
│  │                                                          │   │
│  │  • Conversation history                                 │   │
│  │  • User preferences                                     │   │
│  │  • Document metadata                                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
phase-05/
├── README.md              # This file
├── PROJECT-STATUS.md      # Current project status
└── ollama-llm-guide.md    # Comprehensive Ollama guide (50KB)
```

## Prerequisites

- Phase 1-4 completed
- Keycloak realm `ai-platform` configured
- DNS entries:
  ```
  127.0.0.1 chat.ai-platform.localhost
  ```

## Components

| Component | Namespace | Storage | Purpose |
|-----------|-----------|---------|---------|
| Ollama | ai-inference | 20Gi | LLM engine |
| Open WebUI | ai-apps | 5Gi | Chat interface |

## Access

| Service | URL | Auth |
|---------|-----|------|
| Open WebUI | https://chat.ai-platform.localhost | Keycloak SSO |

## Guides

| Document | Description |
|----------|-------------|
| [Project Status](PROJECT-STATUS.md) | Overall project progress |
| [Ollama LLM Guide](ollama-llm-guide.md) | Comprehensive Ollama guide (50KB) |

## Quick Start

### 1. Verify Deployment

```bash
# Check Ollama
kubectl get pods -n ai-inference
# Expected: ollama-xxx Running

# Check Open WebUI
kubectl get pods -n ai-apps
# Expected: open-webui-xxx Running

# Check ingress
kubectl get ingress -n ai-apps
```

### 2. Access Open WebUI

1. Open: https://chat.ai-platform.localhost
2. Click "Sign in with Keycloak"
3. Login with your Keycloak user (e.g., zerotrust)

### 3. Download Models

Via Open WebUI:
1. Go to Settings → Models
2. Search and download models

Via CLI:
```bash
kubectl exec -n ai-inference deployment/ollama -- ollama pull llama3.2
kubectl exec -n ai-inference deployment/ollama -- ollama pull mistral
kubectl exec -n ai-inference deployment/ollama -- ollama pull codellama
```

### 4. Start Chatting!

Select a model and start a conversation.

## Recommended Models

| Model | Size | RAM | Use Case |
|-------|------|-----|----------|
| `llama3.2:3b` | ~2GB | 4GB | Fast general chat |
| `llama3.2:7b` | ~4GB | 8GB | Better quality |
| `mistral:7b` | ~4GB | 8GB | General purpose |
| `codellama:7b` | ~4GB | 8GB | Code generation |
| `nomic-embed-text` | ~300MB | 1GB | Embeddings for RAG |

## Verification

```bash
# Test Ollama API
kubectl exec -n ai-inference deployment/ollama -- ollama list

# Test Open WebUI health
curl -k https://chat.ai-platform.localhost/health

# Check SSO configuration
kubectl get secret -n ai-apps openwebui-oidc-secret
```

## Troubleshooting

### Models not loading

```bash
# Check Ollama logs
kubectl logs -n ai-inference deployment/ollama

# Check disk space
kubectl exec -n ai-inference deployment/ollama -- df -h /root/.ollama

# Pull model manually
kubectl exec -n ai-inference deployment/ollama -- ollama pull llama3.2:3b
```

### SSO not working

```bash
# Check Open WebUI logs
kubectl logs -n ai-apps -l app.kubernetes.io/name=open-webui

# Verify Keycloak client
curl -k https://auth.ai-platform.localhost/realms/ai-platform/.well-known/openid-configuration

# Check OIDC secret
kubectl get secret -n ai-apps openwebui-oidc-secret -o yaml
```

### Slow inference

```bash
# Check resources
kubectl top pods -n ai-inference

# Use smaller model
kubectl exec -n ai-inference deployment/ollama -- ollama pull llama3.2:3b

# Check if model is loaded
kubectl exec -n ai-inference deployment/ollama -- ollama list
```

### Open WebUI can't connect to Ollama

```bash
# Test internal DNS
kubectl exec -n ai-apps -l app.kubernetes.io/name=open-webui -- \
  curl -s http://ollama.ai-inference.svc:11434/api/tags

# Check OLLAMA_BASE_URL env var
kubectl get deployment -n ai-apps open-webui -o yaml | grep OLLAMA
```

## Resource Usage

| Component | CPU | Memory | Notes |
|-----------|-----|--------|-------|
| Ollama (idle) | ~100m | ~500Mi | Before loading model |
| Ollama (7B model) | ~1000m | ~6Gi | During inference |
| Open WebUI | ~100m | ~256Mi | Normal usage |

## Next Steps

After completing Phase 5:
1. Download recommended models
2. Test chat functionality
3. Explore RAG capabilities
4. Proceed to [Phase 6: AI Data Layer](../phase-06/README.md)

## Related Documentation

- [ADR-008: LLM Inference Strategy](../../docs/adr/ADR-008-llm-inference-strategy.md)
- [ADR-010: AI Chat Interface](../../docs/adr/ADR-010-ai-chat-interface.md)
- [ADR-012: Sovereign LLM Strategy](../../docs/adr/ADR-012-sovereign-llm-strategy.md)
- [Keycloak Expert Guide](../../docs/knowledge-base/keycloak-expert-guide.md)
