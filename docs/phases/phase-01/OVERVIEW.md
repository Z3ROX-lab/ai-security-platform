# Phase 1: Infrastructure & GitOps Foundation

## 🎯 Objectives

By the end of this phase, you will have:
- A running K3d Kubernetes cluster created with Terraform
- ArgoCD installed and accessible via web UI
- A GitOps foundation ready to deploy all subsequent phases

## 🏗️ Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                      Your Machine (a6)                       │
│                        Windows 11                            │
│                          32GB RAM                            │
├─────────────────────────────────────────────────────────────┤
│                         WSL2 Ubuntu                          │
├─────────────────────────────────────────────────────────────┤
│                       Docker Desktop                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ┌─────────────────────────────────────────────────────┐  │
│   │              K3d Cluster (Terraform)                 │  │
│   │                                                      │  │
│   │   ┌─────────────────────────────────────────────┐   │  │
│   │   │              Control Plane                   │   │  │
│   │   │  • API Server                               │   │  │
│   │   │  • Scheduler                                │   │  │
│   │   │  • Controller Manager                       │   │  │
│   │   │  • etcd (SQLite in K3s)                    │   │  │
│   │   └─────────────────────────────────────────────┘   │  │
│   │                                                      │  │
│   │   ┌─────────────────────────────────────────────┐   │  │
│   │   │              ArgoCD (GitOps)                 │   │  │
│   │   │  • Application Controller                   │   │  │
│   │   │  • Repo Server                              │   │  │
│   │   │  • API Server                               │   │  │
│   │   │  • Web UI (:8080)                          │   │  │
│   │   └─────────────────────────────────────────────┘   │  │
│   │                                                      │  │
│   └─────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 📦 Components

| Component | Purpose | Resource Usage |
|-----------|---------|----------------|
| K3d | Kubernetes cluster in Docker | ~500MB RAM |
| ArgoCD | GitOps continuous deployment | ~512MB RAM |
| **Total Phase 1** | | **~1GB RAM** |

## 🔧 Tools Used

| Tool | Version | Purpose |
|------|---------|---------|
| Terraform | >= 1.0 | Infrastructure as Code |
| K3d | >= 5.0 | Local Kubernetes |
| kubectl | >= 1.28 | Kubernetes CLI |
| Helm | >= 3.0 | Package manager |

## 📋 Prerequisites

- [x] Windows 11 with WSL2
- [x] Ubuntu installed in WSL2
- [x] Docker Desktop with WSL2 backend
- [x] Terraform installed
- [x] k3d installed
- [x] kubectl installed
- [x] Helm installed
- [x] GitHub repository created

## 🚀 What You'll Learn

1. **Terraform for Kubernetes**
   - Using the K3d Terraform provider
   - Managing cluster lifecycle as code
   - Terraform state management

2. **K3d Cluster Management**
   - Cluster creation and configuration
   - Port mapping for external access
   - Local container registry

3. **ArgoCD Fundamentals**
   - Installation and initial setup
   - Web UI navigation
   - Application sync concepts

## ⏱️ Estimated Time

| Task | Duration |
|------|----------|
| Terraform cluster creation | 15 min |
| ArgoCD installation | 15 min |
| Verification & exploration | 30 min |
| **Total** | **~1 hour** |

## ✅ Success Criteria

- [ ] `kubectl get nodes` shows cluster ready
- [ ] ArgoCD UI accessible at https://localhost:8080
- [ ] Can login to ArgoCD with admin credentials
- [ ] Cluster persists after Docker restart

## 📁 Files Structure
```
phases/phase-01/
├── terraform/
│   ├── main.tf           # K3d cluster definition
│   ├── variables.tf      # Configurable parameters
│   └── outputs.tf        # Cluster information
├── argocd/
│   └── install.yaml      # ArgoCD installation
└── scripts/
    └── bootstrap.sh      # Automated setup script
```

## ➡️ Next Phase

Once Phase 1 is complete, proceed to [Phase 2: Storage Layer](../phase-02/OVERVIEW.md) to set up persistent storage for databases and AI models.
