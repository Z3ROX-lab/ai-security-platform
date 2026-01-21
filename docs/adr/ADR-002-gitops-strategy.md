# ADR-002: GitOps Strategy

## Status
**Accepted**

## Date
2025-01-20

## Context

We need to define how applications will be deployed and managed on the Kubernetes cluster. The goal is to follow enterprise best practices and demonstrate production-ready patterns.

### Requirements
- Declarative configuration (Git as source of truth)
- Automated synchronization
- Audit trail for all changes
- Support for Helm charts and Kustomize
- Web UI for visualization

### Options Considered

| Option | Description |
|--------|-------------|
| **ArgoCD** | Declarative GitOps for Kubernetes |
| **Flux** | CNCF GitOps toolkit |
| **Jenkins + kubectl** | Traditional CI/CD pipeline |
| **Rancher Fleet** | Rancher's GitOps solution |

## Decision

**We chose ArgoCD** for the following reasons:

### Comparison Matrix

| Criteria | ArgoCD | Flux | Jenkins | Fleet |
|----------|--------|------|---------|-------|
| Web UI | ✅ Excellent | ⚠️ Basic | ✅ Good | ✅ Good |
| Learning curve | Medium | Medium | High | Low |
| Market adoption | ~45% | ~30% | ~20% | ~5% |
| Helm support | ✅ Native | ✅ Native | ⚠️ Plugin | ✅ Native |
| Multi-cluster | ✅ Yes | ✅ Yes | ⚠️ Complex | ✅ Yes |
| RBAC | ✅ Granular | ✅ Good | ✅ Good | ✅ Good |
| App-of-Apps | ✅ Native | ⚠️ Kustomize | ❌ No | ✅ Yes |

### Key Factors

1. **Industry Standard**: ArgoCD has the highest market adoption for GitOps, making skills directly transferable to enterprise roles.

2. **Excellent UI**: The web interface provides clear visualization of application state, sync status, and resource hierarchy—valuable for demos and troubleshooting.

3. **App-of-Apps Pattern**: Native support for managing multiple applications through a single root application, enabling clean organization by phase.

4. **Helm + Kustomize**: Supports both packaging approaches without additional tooling.

5. **RBAC Integration**: Can integrate with Keycloak for SSO, aligning with Phase 3 (IAM).

## Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                     GitHub Repository                        │
│                  (ai-security-platform)                      │
└─────────────────────────┬───────────────────────────────────┘
                          │ webhook / poll
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                        ArgoCD                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                   Root App                           │   │
│  │              (App-of-Apps Pattern)                   │   │
│  └───────────┬──────────┬──────────┬──────────┬────────┘   │
│              ▼          ▼          ▼          ▼            │
│  ┌─────────────┐ ┌──────────┐ ┌─────────┐ ┌──────────┐    │
│  │Infrastructure│ │ Security │ │   AI    │ │   MLOps  │    │
│  │   App       │ │   App    │ │   App   │ │   App    │    │
│  └─────────────┘ └──────────┘ └─────────┘ └──────────┘    │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    K3d Cluster                               │
│  Keycloak │ Ollama │ MLflow │ Prometheus │ Guardrails │ ... │
└─────────────────────────────────────────────────────────────┘
```

## Deployment Strategy

### What Terraform Manages
- K3d cluster creation
- Initial ArgoCD bootstrap (install only)

### What ArgoCD Manages (Everything Else)
- All applications (Keycloak, Ollama, MLflow, etc.)
- All configurations
- All secrets (via Sealed Secrets)

### Sync Flow
1. Developer pushes to GitHub
2. ArgoCD detects change (webhook or poll)
3. ArgoCD compares desired state (Git) vs actual state (cluster)
4. ArgoCD applies changes automatically (or manual sync)
5. Status visible in ArgoCD UI

## Consequences

### Positive
- Complete audit trail in Git history
- Declarative, reproducible deployments
- Self-healing (ArgoCD re-applies if drift detected)
- Visual overview of entire platform
- Easy rollback (revert Git commit)

### Negative
- Additional component to manage (ArgoCD itself)
- Learning curve for ArgoCD-specific concepts
- Initial setup complexity (App-of-Apps)

### Mitigation
- ArgoCD is lightweight (~512MB RAM)
- Extensive documentation available
- Skills directly applicable in enterprise

## References
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [ArgoCD + Keycloak SSO](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/keycloak/)
