# Phase 1: Architecture Diagram

## Overview
```mermaid
flowchart TB
    subgraph WINDOWS["💻 Windows 11 (a6 - 32GB RAM)"]
        subgraph WSL2["🐧 WSL2 Ubuntu"]
            subgraph DOCKER["🐳 Docker Desktop"]
                subgraph K3D["☸️ K3d Cluster: ai-security-platform"]
                    
                    subgraph CONTROL["Control Plane"]
                        API[API Server]
                        SCHED[Scheduler]
                        CTRL[Controller Manager]
                        ETCD[(etcd/SQLite)]
                    end
                    
                    subgraph WORKERS["Worker Nodes"]
                        AGENT0[Agent 0]
                        AGENT1[Agent 1]
                    end
                    
                    subgraph ARGOCD_NS["Namespace: argocd"]
                        ARGO_SERVER[ArgoCD Server]
                        ARGO_REPO[Repo Server]
                        ARGO_CTRL[Application Controller]
                    end
                    
                end
            end
            
            TERRAFORM[("Terraform State")]
            KUBECTL[kubectl]
        end
        
        VSCODE[VS Code]
        BROWSER[Browser]
    end
    
    subgraph GITHUB["☁️ GitHub"]
        REPO[(ai-security-platform)]
    end
    
    %% Connections
    VSCODE -->|Edit files| WSL2
    KUBECTL -->|Manage| K3D
    TERRAFORM -->|Create| K3D
    BROWSER -->|":9090"| ARGO_SERVER
    ARGO_CTRL -->|Watch| REPO
    REPO -->|GitOps Sync| ARGO_CTRL
    
    %% Styling
    classDef control fill:#f9f,stroke:#333,stroke-width:2px
    classDef worker fill:#bbf,stroke:#333,stroke-width:2px
    classDef argocd fill:#f96,stroke:#333,stroke-width:2px
    
    class API,SCHED,CTRL,ETCD control
    class AGENT0,AGENT1 worker
    class ARGO_SERVER,ARGO_REPO,ARGO_CTRL argocd
```

## Component Details

| Component | Purpose | Resource |
|-----------|---------|----------|
| **K3d Cluster** | Kubernetes in Docker | ~500MB RAM |
| **Control Plane** | Cluster management | 1 server node |
| **Worker Nodes** | Run workloads | 2 agent nodes |
| **ArgoCD** | GitOps deployment | ~512MB RAM |
| **Local Registry** | Store custom images | registry.localhost:5000 |

## Network Flow
```mermaid
flowchart LR
    subgraph EXTERNAL["External Access"]
        USER[👤 User]
    end
    
    subgraph PORTS["Exposed Ports"]
        P80[":80 HTTP"]
        P443[":443 HTTPS"]
        P9090[":9090 ArgoCD"]
        P5000[":5000 Registry"]
    end
    
    subgraph K3D["K3d Cluster"]
        LB[Load Balancer]
        ARGO[ArgoCD UI]
        REG[Container Registry]
    end
    
    USER --> P80 --> LB
    USER --> P443 --> LB
    USER --> P9090 --> ARGO
    USER --> P5000 --> REG
```

## GitOps Flow
```mermaid
sequenceDiagram
    participant DEV as Developer
    participant GIT as GitHub
    participant ARGO as ArgoCD
    participant K8S as Kubernetes
    
    DEV->>GIT: git push (manifests)
    GIT-->>ARGO: Webhook/Poll
    ARGO->>ARGO: Detect changes
    ARGO->>GIT: Fetch manifests
    ARGO->>K8S: Apply changes
    K8S-->>ARGO: Status update
    ARGO-->>DEV: Sync status (UI)
```

## Terraform Resources
```mermaid
flowchart TD
    TF[Terraform] -->|creates| CLUSTER[k3d_cluster.ai_platform]
    
    CLUSTER -->|includes| SERVER[1 Server Node]
    CLUSTER -->|includes| AGENTS[2 Agent Nodes]
    CLUSTER -->|includes| LB[Load Balancer]
    CLUSTER -->|includes| REGISTRY[Local Registry]
    
    CLUSTER -->|exposes| PORT80[Port 80]
    CLUSTER -->|exposes| PORT443[Port 443]
    CLUSTER -->|exposes| PORT8080[Port 8080]
    CLUSTER -->|exposes| PORT5000[Port 5000]
```

## Current State

| Resource | Status | Access |
|----------|--------|--------|
| K3d Cluster | ✅ Running | `kubectl get nodes` |
| ArgoCD | ✅ Running | https://localhost:9090 |
| GitHub Connection | ✅ Connected | ArgoCD → Settings → Repos |
| Local Registry | ✅ Running | registry.localhost:5000 |

## Next Phase

Phase 2 will add:
- PostgreSQL (database layer)
- MinIO (object storage)
- Deployed via ArgoCD GitOps
