# CloudNativePG & PostgreSQL Guide

## Overview

This document explains the CloudNativePG (CNPG) architecture used in the AI Security Platform for managing PostgreSQL databases on Kubernetes.

## Architecture Diagram

```mermaid
flowchart TB
    subgraph GitOps
        ROOT[root-app] --> OP[cnpg-operator]
        ROOT --> PG[postgresql]
    end

    subgraph cnpg-system
        CTRL[CNPG Controller]
    end

    subgraph storage
        P1[Pod 1<br/>PRIMARY]
        P2[Pod 2<br/>REPLICA]
        P3[Pod 3<br/>REPLICA]
        P1 -.->|replication| P2
        P1 -.->|replication| P3
    end

    OP -->|deploys| CTRL
    PG -->|creates| CR[Cluster CR]
    CTRL -->|watches & manages| CR
    CR -->|creates| P1
    CR -->|creates| P2
    CR -->|creates| P3
```

## The Operator Pattern Explained

### What is an Operator?

An Operator is a Kubernetes-native way to manage complex stateful applications. It extends Kubernetes with **Custom Resource Definitions (CRDs)** and a **Controller** that automates operational tasks.

| Component | Role |
|-----------|------|
| **CRD** | Defines new resource types (e.g., `Cluster`, `Backup`) |
| **Controller** | Watches CRDs and reconciles desired state with actual state |
| **Custom Resource** | Your declaration of what you want (e.g., "3-node PostgreSQL cluster") |

### Why Use an Operator for PostgreSQL?

Without an Operator, you would need to manually:
- Configure primary/replica replication
- Handle failover when primary crashes
- Manage connection strings
- Perform backups and restores
- Execute rolling updates

The CNPG Operator automates all of this.

## Project Structure

```
argocd/applications/storage/
├── cnpg-operator/
│   ├── application.yaml    # ArgoCD Application for the Operator
│   └── values.yaml         # Helm values (resources, monitoring)
└── postgresql/
    ├── application.yaml    # ArgoCD Application for the PG Cluster
    └── values.yaml         # Cluster config (instances, storage, users)
```

### cnpg-operator/application.yaml

Deploys the CNPG Operator from the official Helm chart:

```yaml
spec:
  sources:
    - repoURL: https://cloudnative-pg.github.io/charts
      chart: cloudnative-pg          # The operator itself
      targetRevision: 0.27.0
```

**Key syncOptions:**
- `ServerSideApply=true` — Required for large CRDs (avoids annotation size limit)

### postgresql/application.yaml

Deploys a PostgreSQL cluster using the CNPG `cluster` Helm chart:

```yaml
spec:
  sources:
    - repoURL: https://cloudnative-pg.github.io/charts
      chart: cluster                 # Creates a Cluster CR
      targetRevision: 0.5.0
```

## How It Works Together

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. YOU: Define desired state in Git                                 │
│    "I want a 3-node PostgreSQL cluster"                            │
│    (postgresql/values.yaml)                                         │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 2. ARGOCD: Syncs manifests to Kubernetes                           │
│    Creates the Cluster Custom Resource                              │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 3. CNPG OPERATOR: Sees the Cluster CR                              │
│    - Creates 3 Pods (1 primary, 2 replicas)                        │
│    - Creates Services (rw, ro, r)                                   │
│    - Creates Secrets (credentials)                                  │
│    - Configures streaming replication                               │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 4. CONTINUOUS RECONCILIATION                                        │
│    Operator watches and reacts:                                     │
│    - Pod crash → Restart and rejoin cluster                        │
│    - Primary failure → Promote replica, reconfigure                │
│    - Config change → Rolling update                                 │
└─────────────────────────────────────────────────────────────────────┘
```

## Services Created by CNPG

| Service | Endpoint | Use Case |
|---------|----------|----------|
| `postgresql-cluster-rw` | Primary only | Write operations (Keycloak, MLflow) |
| `postgresql-cluster-ro` | Replicas only | Read-heavy queries, reporting |
| `postgresql-cluster-r` | All instances | Any read (load balanced) |

### Connection Strings

```bash
# For applications (read-write)
postgresql://app-user:password@postgresql-cluster-rw.storage:5432/app

# For read replicas
postgresql://app-user:password@postgresql-cluster-ro.storage:5432/app
```

## Useful Commands

### Check Cluster Status

```bash
# Cluster health
kubectl get clusters.postgresql.cnpg.io -A

# Pod status
kubectl get pods -n storage -l cnpg.io/cluster=postgresql-cluster

# Which pod is primary?
kubectl get pods -n storage -l cnpg.io/cluster=postgresql-cluster \
  -o jsonpath='{range .items[*]}{.metadata.name}: {.metadata.labels.role}{"\n"}{end}'
```

### Connect to PostgreSQL

```bash
# Get superuser password
kubectl get secret postgresql-cluster-superuser -n storage \
  -o jsonpath='{.data.password}' | base64 -d && echo

# Port-forward and connect
kubectl port-forward -n storage svc/postgresql-cluster-rw 5432:5432

# In another terminal
psql -h localhost -U postgres -d postgres
```

### Test Failover

```bash
# Delete the primary pod
kubectl delete pod postgresql-cluster-1 -n storage

# Watch the operator promote a replica
kubectl get pods -n storage -w

# Check new primary
kubectl get clusters.postgresql.cnpg.io -n storage
```

### View Logs

```bash
# Operator logs
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg

# PostgreSQL logs
kubectl logs -n storage postgresql-cluster-1
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| `OutOfSync` in ArgoCD | Operator modifies resources | Add `ServerSideApply=true` |
| CRD too long error | Annotation size limit | Add `ServerSideApply=true` |
| Pod `CrashLoopBackOff` | Check logs | `kubectl logs -n storage <pod> --previous` |
| Cluster not `Healthy` | Replication issue | Check `kubectl describe cluster -n storage` |

## Integration with Other Services

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Keycloak   │     │   MLflow    │     │  Future AI  │
│  (Phase 3)  │     │  (Phase 9)  │     │  Services   │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │  postgresql-cluster-rw │
              │      (storage ns)      │
              └────────────────────────┘
```

## References

- [CloudNativePG Documentation](https://cloudnative-pg.io/documentation/)
- [CNPG Helm Charts](https://github.com/cloudnative-pg/charts)
- [Kubernetes Operator Pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
