# 🛡️ AI Security Platform

Enterprise-grade AI/ML platform with comprehensive security coverage, built on Kubernetes with GitOps practices.

## 🎯 Project Goals

- Demonstrate end-to-end AI platform security (OWASP LLM Top 10)
- Implement MLOps best practices with security-first approach
- Showcase hands-on Kubernetes, GitOps, and IAM expertise
- Document sovereign LLM deployment strategies for enterprise

## 👤 Author

**Stéphane (Z3ROX)** - Lead SecOps/Cloud Security Architect

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        K3d Cluster (32GB RAM)                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  INGRESS                                                                │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                         Traefik ✅                               │   │
│  │  chat.ai-platform.localhost | auth.ai-platform.localhost         │   │
│  │  argocd.ai-platform.localhost                                    │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  APPLICATIONS                                                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ Open     │  │ Keycloak │  │  Ollama  │  │  Qdrant  │              │
│  │ WebUI ✅ │  │ IAM ✅   │  │ LLM ✅   │  │ VectorDB │              │
│  │ (Chat)   │  │  (SSO)   │  │(Mistral) │  │          │              │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘              │
│                                                                         │
│  AI SECURITY                                                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                             │
│  │  Sealed  │  │  Network │  │  NeMo    │                             │
│  │ Secrets  │  │ Policies │  │Guardrails│                             │
│  │    ✅    │  │    ✅    │  │          │                             │
│  └──────────┘  └──────────┘  └──────────┘                             │
│                                                                         │
│  DATA & STORAGE                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                             │
│  │SeaweedFS │  │PostgreSQL│  │ Local-   │                             │
│  │   (S3)   │  │ (CNPG)✅ │  │ Path ✅  │                             │
│  │          │  │          │  │          │                             │
│  └──────────┘  └──────────┘  └──────────┘                             │
│                                                                         │
│  PLATFORM                                                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                             │
│  │  ArgoCD  │  │  cert-   │  │ Pod Sec  │                             │
│  │ GitOps ✅│  │manager ✅│  │ Stds ✅  │                             │
│  └──────────┘  └──────────┘  └──────────┘                             │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## 📚 Phases

| Phase | Name | Components | Status |
|-------|------|------------|--------|
| 1 | Infrastructure & GitOps | K3d, Terraform, ArgoCD, cert-manager | ✅ Done |
| 2 | Storage Layer | PostgreSQL (CNPG), local-path | ✅ Done |
| 3 | IAM & Ingress | Traefik, Keycloak | ✅ Done |
| 4 | K8s Security Baseline | NetworkPolicies, PSS, Sealed Secrets | ✅ Done |
| 5 | AI Inference | Ollama, Mistral 7B | ✅ Done |
| 6 | RAG Pipeline | Qdrant, SeaweedFS, Embedding Service | 🔲 Next |
| 7 | AI Guardrails | NeMo Guardrails | 🔲 Planned |
| 8 | Observability | Prometheus, Grafana | 🔲 Planned |
| 9 | MLOps | MLflow | 🔲 Planned |
| 10 | Demo Application | Open WebUI + Keycloak SSO | ✅ Done |

## 🚀 Current Deployment Status

```bash
$ kubectl get applications -n argocd
NAME                  SYNC STATUS   HEALTH STATUS
root-app              Synced        Healthy
cnpg-operator         Synced        Healthy
postgresql            Synced        Healthy
traefik               Synced        Healthy
keycloak              Synced        Healthy
cert-manager          Synced        Healthy
security-baseline     Synced        Healthy
ollama                Synced        Healthy
open-webui            Synced        Healthy
sealed-secrets        Synced        Healthy
```

### Access URLs (Home Lab)

| Service | URL | Credentials |
|---------|-----|-------------|
| **ArgoCD** | https://argocd.ai-platform.localhost | admin / (see install) |
| **Keycloak** | https://auth.ai-platform.localhost | admin / admin123 |
| **Open WebUI** | https://chat.ai-platform.localhost | via Keycloak SSO |

> **Note:** Self-signed certificates - accept browser warning to proceed.

### Keycloak Configuration

| Item | Value |
|------|-------|
| Realm | `ai-platform` |
| Roles | platform-admin, ai-engineer, security-auditor, viewer |
| Clients | argocd, open-webui |
| SSO | OIDC integration with Open WebUI |

## 📋 Architecture Decision Records

All architectural decisions are documented in [docs/adr/](docs/adr/):

| ADR | Title | Status |
|-----|-------|--------|
| [ADR-001](docs/adr/ADR-001-kubernetes-distribution.md) | Kubernetes Distribution (K3d) | ✅ Implemented |
| [ADR-002](docs/adr/ADR-002-gitops-strategy.md) | GitOps Strategy (ArgoCD) | ✅ Implemented |
| [ADR-003](docs/adr/ADR-003-iam-strategy.md) | IAM Strategy (Keycloak) | ✅ Implemented |
| [ADR-004](docs/adr/ADR-004-storage-strategy.md) | Storage Strategy (CNPG, local-path) | ✅ Implemented |
| [ADR-005](docs/adr/ADR-005-ArgoCD-GitOps-Best-Practices.md) | ArgoCD GitOps Best Practices | ✅ Implemented |
| [ADR-006](docs/adr/ADR-006-VectorDB-Strategy.md) | VectorDB Strategy (Qdrant) | 📋 Planned |
| [ADR-007](docs/adr/ADR-007-embedding-strategy.md) | Embedding Strategy | 📋 Planned |
| [ADR-008](docs/adr/ADR-008-llm-inference-strategy.md) | LLM Inference Strategy (Ollama) | ✅ Implemented |
| [ADR-009](docs/adr/ADR-009-ai-guardrails-strategy.md) | AI Guardrails Strategy (NeMo) | 📋 Planned |
| [ADR-010](docs/adr/ADR-010-ai-chat-interface.md) | AI Chat Interface (Open WebUI) | ✅ Implemented |
| [ADR-011](docs/adr/ADR-011-llm-application-framework.md) | LLM Application Framework (LangChain) | ✅ Accepted |
| [ADR-012](docs/adr/ADR-012-sovereign-llm-strategy.md) | Sovereign LLM Strategy (vLLM, Mistral) | ✅ Accepted |
| [ADR-013](docs/adr/ADR-013-cni-strategy.md) | CNI Strategy (Flannel/Cilium) | ✅ Accepted |

## 🔒 Security Coverage (OWASP LLM Top 10)

| Risk | Mitigation | Phase | Status |
|------|------------|-------|--------|
| LLM01: Prompt Injection | NeMo Guardrails | 7 | 🔲 Planned |
| LLM02: Insecure Output | NeMo output rails | 7 | 🔲 Planned |
| LLM03: Training Data Poisoning | Model pinning, trusted sources (Ollama) | 5 | ✅ Done |
| LLM04: Model DoS | K8s resource limits, requests/limits | 4,5 | ✅ Done |
| LLM05: Supply Chain | Pinned versions, ArgoCD, Sealed Secrets | 1,4 | ✅ Done |
| LLM06: Sensitive Info Disclosure | NeMo PII rails | 7 | 🔲 Planned |
| LLM07: Insecure Plugin | No plugins in MVP | - | ✅ N/A |
| LLM08: Excessive Agency | NeMo action rails | 7 | 🔲 Planned |
| LLM09: Overreliance | Disclaimer in responses | 7 | 🔲 Planned |
| LLM10: Model Theft | NetworkPolicies, namespace isolation | 4 | ✅ Done |

## 🛠️ Tech Stack

| Category | Technology | Status |
|----------|------------|--------|
| **Kubernetes** | K3d (local), Terraform | ✅ Running |
| **GitOps** | ArgoCD | ✅ Running |
| **Database** | PostgreSQL (CloudNativePG) | ✅ Running |
| **IAM** | Keycloak + OIDC | ✅ Running |
| **Ingress** | Traefik | ✅ Running |
| **TLS** | cert-manager (internal CA) | ✅ Running |
| **Secrets** | Sealed Secrets (Bitnami) | ✅ Running |
| **LLM** | Ollama + Mistral 7B | ✅ Running |
| **Chat UI** | Open WebUI | ✅ Running |
| **CNI** | Flannel (K3s default) | ✅ Running |
| **VectorDB** | Qdrant | 🔲 Planned |
| **Object Storage** | SeaweedFS | 🔲 Planned |
| **Guardrails** | NeMo Guardrails | 🔲 Planned |
| **Observability** | Prometheus, Grafana | 🔲 Planned |

## 📁 Repository Structure

```
ai-security-platform/
├── argocd/
│   ├── root-app.yaml                    # App-of-Apps entry point
│   └── applications/
│       ├── storage/
│       │   ├── cnpg-operator/           # CloudNativePG Operator
│       │   ├── postgresql/              # PostgreSQL Cluster
│       │   └── openwebui-db-init/       # Database initialization
│       ├── infrastructure/
│       │   └── traefik/                 # Ingress Controller
│       ├── auth/
│       │   └── keycloak/                # IAM
│       ├── security/
│       │   ├── security-baseline/       # NetworkPolicies, PSS
│       │   └── sealed-secrets/          # Secrets management
│       ├── ai-inference/
│       │   └── ollama/                  # LLM serving
│       └── ai-apps/
│           └── open-webui/              # Chat interface
├── docs/
│   ├── adr/                             # Architecture Decision Records
│   └── knowledge-base/                  # Guides and deep-dives
├── phases/
│   ├── phase-01/                        # Infrastructure
│   ├── phase-02-03/                     # Storage, Auth
│   ├── phase-04/                        # Security baseline
│   └── phase-05/                        # AI inference
└── README.md
```

## 📖 Knowledge Base

### Guides
- [Phase 1 Guide](phases/phase-01/step-by-step-guide.md) - K3d, Terraform, ArgoCD
- [Phase 2-3 Guide](phases/phase-02-03/step-by-step-guide.md) - PostgreSQL, Traefik, Keycloak
- [Phase 4 Guide](phases/phase-04/security-baseline-guide.md) - Security baseline
- [Phase 5 Guide](phases/phase-05/ollama-llm-guide.md) - Ollama deployment

### Deep Dives
- [CNPG & PostgreSQL Guide](docs/knowledge-base/cnpg-postgresql-guide.md)
- [Helm & ArgoCD Integration](docs/knowledge-base/helm-argocd-guide.md)
- [GitOps Guide](docs/knowledge-base/GitOps%20Guide%20-%20AI%20Security%20Platform.md)
- [Kubernetes Security Architecture](docs/knowledge-base/kubernetes-security-architecture-guide.md)
- [Sealed Secrets Guide](docs/knowledge-base/sealed-secrets-guide.md)
- [LangChain Guide](docs/knowledge-base/langchain-guide.md)
- [K3d Troubleshooting](docs/knowledge-base/k3d-troubleshooting-guide.md)

## 🚀 Quick Start

### Prerequisites

- Docker Desktop with WSL2
- Terraform
- kubectl
- Helm

### Installation

```bash
# Clone the repository
git clone https://github.com/youruser/ai-security-platform.git
cd ai-security-platform

# Phase 1: Create K3d cluster with Terraform
cd phases/phase-01/terraform
terraform init
terraform apply

# Get kubeconfig
export KUBECONFIG=$(terraform output -raw kubeconfig_path)

# Bootstrap ArgoCD (root-app deploys everything)
kubectl apply -f ../../../argocd/root-app.yaml

# Wait for all apps to sync
watch kubectl get applications -n argocd

# Access ArgoCD UI
# Open https://argocd.ai-platform.localhost
# Username: admin
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Configure Local DNS (Windows + WSL2)

Add to `C:\Windows\System32\drivers\etc\hosts`:
```
127.0.0.1 auth.ai-platform.localhost
127.0.0.1 chat.ai-platform.localhost
127.0.0.1 argocd.ai-platform.localhost
```

### After Laptop Reboot

```bash
# K3d network may break after reboot - restart the cluster
k3d cluster stop ai-security-platform
k3d cluster start ai-security-platform

# Wait for pods
kubectl get pods -A -w
```

## 🏢 Enterprise Considerations (Sovereign LLM)

This platform demonstrates patterns for enterprise deployment with data sovereignty requirements:

| Aspect | Home Lab | Enterprise (GTT) |
|--------|----------|------------------|
| **LLM** | Ollama + Mistral 7B | vLLM + Mixtral 8x7B |
| **Inference** | CPU/Light GPU | NVIDIA A100/H100 |
| **CNI** | Flannel | Cilium (eBPF, L7 policies) |
| **Secrets** | Sealed Secrets | HashiCorp Vault |
| **Storage** | local-path | Longhorn / Ceph |
| **Compliance** | N/A | RGPD, SecNumCloud, C4-C5 |

See [ADR-012](docs/adr/ADR-012-sovereign-llm-strategy.md) for detailed sovereign LLM strategy.

## 📄 License

MIT
