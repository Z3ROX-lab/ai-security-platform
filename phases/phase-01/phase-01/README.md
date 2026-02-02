# Phase 1: Infrastructure

## Status: ✅ Completed

## Overview

Phase 1 establishes the foundational infrastructure for the AI Security Platform:

| Component | Description | Status |
|-----------|-------------|--------|
| **K3d** | Lightweight Kubernetes cluster | ✅ Deployed |
| **Terraform** | Infrastructure as Code | ✅ Configured |
| **ArgoCD** | GitOps continuous delivery | ✅ Deployed |
| **Traefik** | Ingress controller | ✅ Deployed |
| **cert-manager** | TLS certificate management | ✅ Deployed |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    INFRASTRUCTURE LAYER                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                      K3D CLUSTER                         │   │
│  │              ai-security-platform                        │   │
│  │                                                          │   │
│  │   ┌─────────┐  ┌─────────┐  ┌─────────┐                │   │
│  │   │ Server  │  │ Agent 1 │  │ Agent 2 │                │   │
│  │   │ (CP)    │  │ (Worker)│  │ (Worker)│                │   │
│  │   └─────────┘  └─────────┘  └─────────┘                │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   ARGOCD     │  │   TRAEFIK    │  │ CERT-MANAGER │         │
│  │   GitOps     │  │   Ingress    │  │     TLS      │         │
│  │   :9090      │  │   :443/:80   │  │              │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              LOCAL CONTAINER REGISTRY                    │   │
│  │              registry.localhost:5000                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
phase-01/
├── README.md                 # This file
├── argocd/                   # ArgoCD bootstrap configs
├── scripts/
│   └── bootstrap.sh          # Initial cluster setup script
└── terraform/
    ├── main.tf               # K3d cluster + OIDC config
    ├── argocd.tf             # ArgoCD installation
    ├── variables.tf          # Terraform variables
    ├── outputs.tf            # Terraform outputs
    └── terraform.tfvars      # Configuration values
```

## Prerequisites

- Docker Desktop or Docker Engine
- kubectl
- Terraform >= 1.0
- Helm 3.x
- 32GB RAM recommended (16GB minimum)

## Quick Start

### Option A: Terraform (Recommended)

```bash
cd phases/phase-01/terraform

# Initialize
terraform init

# Deploy
terraform apply -auto-approve

# Verify
kubectl get nodes
kubectl get pods -n argocd
```

### Option B: Bootstrap Script

```bash
cd phases/phase-01/scripts
./bootstrap.sh
```

## Verification

```bash
# Check nodes
kubectl get nodes
# Expected: 1 server + 2 agents

# Check ArgoCD
kubectl get pods -n argocd
# Expected: All pods Running

# Check Traefik
kubectl get pods -n traefik
# Expected: traefik pod Running

# Check cert-manager
kubectl get pods -n cert-manager
# Expected: All pods Running

# Get ArgoCD password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

## Access

| Service | URL | Credentials |
|---------|-----|-------------|
| ArgoCD | https://localhost:9090 (port-forward) | admin / (see above) |
| Traefik Dashboard | http://localhost:8080 | - |

```bash
# Port-forward ArgoCD
kubectl port-forward svc/argocd-server -n argocd 9090:443
```

## Configuration

### OIDC Support (Optional)

The Terraform configuration includes OIDC flags for Keycloak SSO integration with kubectl:

```hcl
# terraform.tfvars
oidc_enabled    = true
oidc_issuer_url = "https://auth.ai-platform.localhost/realms/ai-platform"
oidc_client_id  = "kubernetes"
```

This enables:
- kubectl authentication via Keycloak tokens
- RBAC based on Keycloak roles
- Centralized user management

### Cluster Sizing

```hcl
# terraform.tfvars
servers = 1   # Control plane nodes
agents  = 2   # Worker nodes

# Adjust based on RAM:
# 32GB → servers=1, agents=2 (recommended)
# 16GB → servers=1, agents=1 (minimal)
```

## Troubleshooting

### Cluster won't start

```bash
# Check Docker
docker ps

# Check K3d
k3d cluster list

# Delete and recreate
k3d cluster delete ai-security-platform
terraform apply -auto-approve
```

### ArgoCD not accessible

```bash
# Check pods
kubectl get pods -n argocd

# Check logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

### Terraform state issues

```bash
# Reset state
rm -rf .terraform terraform.tfstate*
terraform init
terraform apply -auto-approve
```

## Next Steps

After completing Phase 1:
1. Verify all components are running
2. Access ArgoCD UI
3. Proceed to [Phase 2-3: Security & IAM](../phase-02-03/README.md)

## Related Documentation

- [ADR-001: K3d for Local Development](../../docs/adr/ADR-001-k3d-local-development.md)
- [ADR-002: ArgoCD GitOps](../../docs/adr/ADR-002-argocd-gitops.md)
- [ADR-005: ArgoCD Best Practices](../../docs/adr/ADR-005-ArgoCD-GitOps-Best-Practices.md)
- [GitOps Guide](../../docs/knowledge-base/GitOps%20Guide%20-%20AI%20Security%20Platform.md)
