# 🛡️ AI Security Platform

Enterprise-grade AI/ML platform with comprehensive security coverage, built on Kubernetes with GitOps practices.

## 🎯 Project Goals

- Demonstrate end-to-end AI platform security (OWASP LLM Top 10)
- Implement MLOps best practices with security-first approach
- Showcase hands-on Kubernetes, GitOps, and IAM expertise

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
│  │  auth.ai-platform.localhost | chat.ai-platform.localhost         │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  APPLICATIONS                                                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ Open     │  │ Keycloak │  │  Ollama  │  │  MLflow  │              │
│  │ WebUI    │  │   IAM    │  │   LLM    │  │  MLOps   │              │
│  │ (Chat)   │  │  ✅      │  │(Mistral) │  │          │              │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘              │
│                                                                         │
│  AI SECURITY                                                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                             │
│  │  Rebuff  │  │LLM Guard │  │  NeMo    │                             │
│  │ Injection│  │   PII    │  │Guardrails│                             │
│  └──────────┘  └──────────┘  └──────────┘                             │
│                                                                         │
│  DATA & STORAGE                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                             │
│  │  Qdrant  │  │PostgreSQL│  │ Embedding│                             │
│  │ VectorDB │  │  (CNPG)  │  │ Service  │                             │
│  │          │  │  ✅      │  │          │                             │
│  └──────────┘  └──────────┘  └──────────┘                             │
│                                                                         │
│  PLATFORM                                                               │
│  ┌──────────┐  ┌──────────┐                                           │
│  │  ArgoCD  │  │Prometheus│                                           │
│  │  GitOps  │  │ Grafana  │                                           │
│  │  ✅      │  │          │                                           │
│  └──────────┘  └──────────┘                                           │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## 📚 Phases

| Phase | Name | Components | Status |
|-------|------|------------|--------|
| 1 | Infrastructure & GitOps | K3d, Terraform, ArgoCD | ✅ Done |
| 2 | Storage Layer | PostgreSQL (CNPG) | ✅ Done |
| 3 | IAM & Ingress | Traefik, Keycloak | ✅ Done |
| 4 | K8s Security Baseline | NetworkPolicies, PSS, RBAC | 🔲 Planned |
| 5 | AI Inference | Ollama, Mistral 7B | 🔲 Planned |
| 6 | RAG Pipeline | Qdrant, Embedding Service | 🔲 Planned |
| 7 | AI Guardrails | Rebuff, LLM Guard, NeMo | 🔲 Planned |
| 8 | Observability | Prometheus, Grafana | 🔲 Planned |
| 9 | MLOps | MLflow | 🔲 Planned |
| 10 | Demo Application | Open WebUI | 🔲 Planned |

## 🚀 Current Deployment Status

```bash
$ kubectl get applications -n argocd
NAME            SYNC STATUS   HEALTH STATUS
root-app        Synced        Healthy
cnpg-operator   Synced        Healthy
postgresql      Synced        Healthy
traefik         Synced        Healthy
keycloak        Synced        Healthy
```

### Access URLs (Home Lab)

| Service | URL | Credentials |
|---------|-----|-------------|
| **ArgoCD** | https://localhost:8080 | (see install) |
| **Keycloak** | http://auth.ai-platform.localhost | (see install) |

### Keycloak Configuration

| Item | Value |
|------|-------|
| Realm | `ai-platform` |
| Roles | platform-admin, ai-engineer, security-auditor, viewer |
| Clients | argocd, open-webui |
| Test User | testuser / testpassword |

## 📋 Architecture Decision Records

All architectural decisions are documented in [docs/adr/](docs/adr/):

| ADR | Title | Status |
|-----|-------|--------|
| [ADR-001](docs/adr/ADR-001-kubernetes-distribution.md) | Kubernetes Distribution (K3d) | ✅ Implemented |
| [ADR-002](docs/adr/ADR-002-gitops-strategy.md) | GitOps Strategy (ArgoCD) | ✅ Implemented |
| [ADR-003](docs/adr/ADR-003-iam-strategy.md) | IAM Strategy (Keycloak) | ✅ Implemented |
| [ADR-004](docs/adr/ADR-004-storage-strategy.md) | Storage Strategy (CNPG) | ✅ Implemented |
| [ADR-005](docs/adr/ADR-005-ArgoCD-GitOps-Best-Practices.md) | ArgoCD GitOps Best Practices | ✅ Implemented |
| [ADR-006](docs/adr/ADR-006-VectorDB-Strategy.md) | VectorDB Strategy (Qdrant) | 📋 Planned |
| [ADR-007](docs/adr/ADR-007-embedding-strategy.md) | Embedding Strategy | 📋 Planned |
| [ADR-008](docs/adr/ADR-008-llm-inference-strategy.md) | LLM Inference Strategy (Ollama) | 📋 Planned |
| [ADR-009](docs/adr/ADR-009-ai-guardrails-strategy.md) | AI Guardrails Strategy | 📋 Planned |
| [ADR-010](docs/adr/ADR-010-ai-chat-interface.md) | AI Chat Interface (Open WebUI) | 📋 Planned |

## 🚀 Quick Start

### Prerequisites

- Docker Desktop with WSL2
- Terraform
- kubectl
- Helm

### Installation

```bash
# Clone the repository
git clone https://github.com/Z3ROX-lab/ai-security-platform.git
cd ai-security-platform

# Phase 1: Create K3d cluster with Terraform
cd phases/phase-01/terraform
terraform init
terraform apply

# Get kubeconfig
export KUBECONFIG=$(terraform output -raw kubeconfig_path)

# Bootstrap ArgoCD (root-app deploys everything)
kubectl apply -f ../../../argocd/root-app.yaml

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080
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

## 🔒 Security Coverage (OWASP LLM Top 10)

| Risk | Mitigation | Phase | Status |
|------|------------|-------|--------|
| LLM01: Prompt Injection | Rebuff, NeMo Guardrails | 7 | 🔲 Planned |
| LLM02: Insecure Output | LLM Guard output scanners | 7 | 🔲 Planned |
| LLM03: Training Data Poisoning | Model pinning, trusted sources | 5 | 🔲 Planned |
| LLM04: Model DoS | K8s resource limits, rate limiting | 4,5 | 🔲 Planned |
| LLM05: Supply Chain | Pinned versions, ArgoCD | 1 | ✅ Done |
| LLM06: Sensitive Info Disclosure | LLM Guard PII scanner | 7 | 🔲 Planned |
| LLM07: Insecure Plugin | No plugins in MVP | - | ✅ N/A |
| LLM08: Excessive Agency | NeMo action rails | 7 | 🔲 Planned |
| LLM09: Overreliance | Disclaimer in responses | 7 | 🔲 Planned |
| LLM10: Model Theft | NetworkPolicies, no egress | 4 | 🔲 Planned |

## 📁 Repository Structure

```
ai-security-platform/
├── argocd/
│   ├── root-app.yaml                    # App-of-Apps entry point
│   └── applications/
│       ├── storage/
│       │   ├── cnpg-operator/           # CloudNativePG Operator
│       │   └── postgresql/              # PostgreSQL Cluster
│       ├── infrastructure/
│       │   └── traefik/                 # Ingress Controller
│       └── auth/
│           └── keycloak/                # IAM
├── docs/
│   ├── adr/                             # Architecture Decision Records
│   └── knowledge-base/                  # Guides and deep-dives
├── phases/
│   ├── phase-01/
│   │   ├── terraform/                   # K3d cluster provisioning
│   │   └── step-by-step-guide.md
│   └── phase-02-03/
│       ├── step-by-step-guide.md        # PostgreSQL, Traefik, Keycloak
│       └── keycloak-guide.md            # Detailed Keycloak guide
└── README.md
```

## 📖 Knowledge Base

- [Phase 1 Guide](phases/phase-01/step-by-step-guide.md) - K3d, Terraform, ArgoCD
- [Phase 2-3 Guide](phases/phase-02-03/step-by-step-guide.md) - PostgreSQL, Traefik, Keycloak
- [Keycloak Deep Dive](phases/phase-02-03/keycloak-guide.md) - IAM configuration
- [CNPG & PostgreSQL Guide](docs/knowledge-base/cnpg-postgresql-guide.md)
- [Helm & ArgoCD Integration](docs/knowledge-base/helm-argocd-guide.md)
- [GitOps Guide](docs/knowledge-base/GitOps%20Guide%20-%20AI%20Security%20Platform.md)

## 🛠️ Tech Stack

| Category | Technology | Status |
|----------|------------|--------|
| **Kubernetes** | K3d (local), Terraform | ✅ Running |
| **GitOps** | ArgoCD | ✅ Running |
| **Database** | PostgreSQL (CloudNativePG) | ✅ Running |
| **IAM** | Keycloak | ✅ Running |
| **Ingress** | Traefik | ✅ Running |
| **LLM** | Ollama + Mistral 7B | 🔲 Planned |
| **VectorDB** | Qdrant | 🔲 Planned |
| **Guardrails** | Rebuff, LLM Guard, NeMo | 🔲 Planned |
| **Observability** | Prometheus, Grafana | 🔲 Planned |
| **MLOps** | MLflow | 🔲 Planned |

## 📄 License

MIT
