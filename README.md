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
┌─────────────────────────────────────────────────────────────┐
│                    K3d Cluster (32GB)                       │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  ArgoCD  │  │ Keycloak │  │  Ollama  │  │  MLflow  │   │
│  │  GitOps  │  │   IAM    │  │   LLM    │  │  MLOps   │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Qdrant  │  │Guardrails│  │  Rebuff  │  │Prometheus│   │
│  │ VectorDB │  │ AI Safety│  │ Injection│  │Monitoring│   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 📚 Phases

| Phase | Name | Status |
|-------|------|--------|
| 1 | Infrastructure & GitOps | 🔄 In Progress |
| 2 | Storage Layer | 🔲 Not started |
| 3 | IAM & Zero Trust (Keycloak) | 🔲 Not started |
| 4 | K8s Security Baseline | 🔲 Not started |
| 5 | AI Inference (Ollama/vLLM) | 🔲 Not started |
| 6 | RAG Pipeline | 🔲 Not started |
| 7 | AI Security (OWASP LLM Top 10) | 🔲 Not started |
| 8 | MLOps (MLflow) | 🔲 Not started |
| 9 | Training & Fine-tuning | 🔲 Not started |
| 10 | Observability | 🔲 Not started |

## 📋 Architecture Decision Records

See [docs/adr/](docs/adr/) for all architectural decisions.

## 🚀 Quick Start
```bash
# Phase 1: Create cluster with Terraform
cd phases/phase-01/terraform
terraform init
terraform apply

# Bootstrap ArgoCD
cd ../argocd
kubectl apply -f install.yaml
```

## 🔒 Security Coverage (OWASP LLM Top 10)

| Risk | Mitigation | Demo |
|------|------------|------|
| LLM01: Prompt Injection | Rebuff, NeMo Guardrails | ✅ |
| LLM02: Data Leakage | LLM Guard (PII detection) | ✅ |
| LLM03: Training Data Poisoning | Model signing (Cosign) | ✅ |
| LLM04: Model DoS | Rate limiting | ✅ |
| LLM05: Supply Chain | Trivy, SBOM | ✅ |
| LLM06: Permission Issues | Keycloak RBAC | ✅ |
| LLM07: Data Poisoning | Input validation | ✅ |
| LLM08: Excessive Agency | Guardrails AI | ✅ |
| LLM09: Overreliance | Confidence scoring | ✅ |
| LLM10: Model Theft | Network policies, encryption | ✅ |

## 📄 License

MIT
