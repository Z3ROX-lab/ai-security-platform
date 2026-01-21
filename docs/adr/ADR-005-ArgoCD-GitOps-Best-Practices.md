# ADR-005: ArgoCD GitOps Best Practices

## Status
**Accepted**

## Date
2025-01-21

## Context

The AI Security Platform uses ArgoCD for GitOps-based continuous deployment. We need to establish clear guidelines and best practices to ensure consistency, maintainability, and security across all deployments.

This ADR was created after identifying an anti-pattern: generating/copying Kubernetes manifests into our repository instead of referencing official Helm charts.

## Decision

We adopt the following ArgoCD GitOps best practices for the AI Security Platform.

---

## Principle 1: Use Official Helm Charts (Never Copy Manifests)

### Rule
**Always reference official Helm charts via ArgoCD Applications. Never copy or generate manifests into your repository.**

### Why
| Approach | Problem |
|----------|---------|
| ❌ Copy manifests | Stale versions, no upstream fixes, maintenance burden |
| ❌ Generate manifests | Same issues + drift from source of truth |
| ✅ Reference Helm chart | Always current, community-maintained, security patches |

### Implementation

```yaml
# ✅ CORRECT: Reference official Helm chart
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: longhorn
  namespace: argocd
spec:
  source:
    repoURL: https://charts.longhorn.io      # Official Helm repo
    chart: longhorn                           # Chart name
    targetRevision: 1.7.2                     # Pinned version
    helm:
      valuesObject:                           # Or valueFiles pointing to your repo
        defaultSettings:
          backupTarget: s3://backup@us-east-1/
```

```yaml
# ❌ WRONG: Manifests in your repo
spec:
  source:
    repoURL: https://github.com/myorg/my-repo
    path: apps/longhorn/manifests             # Don't do this
```

### What Goes in Your Repository

| In Your Repo | Not in Your Repo |
|--------------|------------------|
| `application.yaml` (ArgoCD Application) | Helm chart source |
| `values.yaml` (your customizations) | Generated manifests |
| Environment-specific overrides | Default configurations |

---

## Principle 2: Repository Structure

### Standard Structure

```
ai-security-platform/
├── argocd/
│   ├── applications/           # ArgoCD Application definitions
│   │   ├── root-app.yaml       # App-of-apps root
│   │   ├── infrastructure/
│   │   │   ├── longhorn.yaml
│   │   │   ├── seaweedfs.yaml
│   │   │   └── postgresql.yaml
│   │   ├── security/
│   │   │   ├── keycloak.yaml
│   │   │   └── kyverno.yaml
│   │   └── ai/
│   │       ├── ollama.yaml
│   │       └── mlflow.yaml
│   └── projects/               # ArgoCD Projects (RBAC)
│       ├── infrastructure.yaml
│       ├── security.yaml
│       └── ai.yaml
│
├── values/                     # Helm values (your customizations only)
│   ├── longhorn/
│   │   ├── values.yaml         # Base values
│   │   └── values-prod.yaml    # Environment override
│   ├── keycloak/
│   │   └── values.yaml
│   └── ...
│
└── docs/
    └── adr/                    # Architecture Decision Records
```

### Key Points

- **`argocd/applications/`**: Contains only ArgoCD Application CRDs
- **`values/`**: Contains only your custom Helm values
- **No manifests directory**: We don't store generated/copied K8s manifests

---

## Principle 3: App-of-Apps Pattern

### Why
Manage all applications from a single root application for:
- Single point of deployment
- Consistent sync across related apps
- Easier disaster recovery

### Implementation

```yaml
# argocd/applications/root-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/Z3ROX-lab/ai-security-platform
    targetRevision: main
    path: argocd/applications    # Points to all Application YAMLs
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Hierarchy

```
root-app
├── infrastructure/
│   ├── longhorn
│   ├── seaweedfs
│   └── postgresql
├── security/
│   ├── keycloak
│   ├── kyverno
│   └── sealed-secrets
└── ai/
    ├── ollama
    └── mlflow
```

---

## Principle 4: Version Pinning

### Rule
**Always pin to specific versions. Never use `latest`, `main`, or `HEAD`.**

### Why
| Tag | Risk |
|-----|------|
| `latest` | Unpredictable changes, breaking updates |
| `main` / `HEAD` | Same issue for Git refs |
| `1.7.2` ✅ | Reproducible, auditable, rollback-friendly |

### Implementation

```yaml
# ✅ CORRECT: Pinned version
spec:
  source:
    chart: longhorn
    targetRevision: 1.7.2       # Specific version

# ❌ WRONG: Floating tags
spec:
  source:
    targetRevision: latest      # Never do this
    targetRevision: main        # Never do this
```

### Version Update Process

1. Monitor upstream releases (GitHub Watch, RSS, Renovate)
2. Test new version in dev/staging
3. Update `targetRevision` in Git
4. ArgoCD syncs automatically
5. Rollback = revert Git commit

---

## Principle 5: Sync Policies

### Decision Matrix

| Component Type | Sync Policy | Prune | Self-Heal |
|----------------|-------------|-------|-----------|
| Infrastructure (Longhorn, CNI) | **Manual** | No | No |
| Stateful (PostgreSQL, Keycloak) | **Manual** | No | Yes |
| Stateless (Apps, APIs) | **Automated** | Yes | Yes |
| Security (Kyverno, Falco) | **Manual** | No | Yes |

### Implementation

```yaml
# Infrastructure: Manual sync (careful changes)
syncPolicy: {}  # Empty = manual

# Stateless apps: Full automation
syncPolicy:
  automated:
    prune: true       # Remove resources deleted from Git
    selfHeal: true    # Revert manual kubectl changes
  syncOptions:
    - CreateNamespace=true
```

### Sync Options Reference

| Option | Use Case |
|--------|----------|
| `CreateNamespace=true` | Auto-create target namespace |
| `PruneLast=true` | Delete resources after others are healthy |
| `ApplyOutOfSyncOnly=true` | Only apply changed resources (faster) |
| `ServerSideApply=true` | Handle large CRDs, avoid conflicts |

---

## Principle 6: Secret Management

### Rule
**Never commit secrets to Git. Use Sealed Secrets or External Secrets Operator.**

### Options

| Solution | Use Case | Our Choice |
|----------|----------|------------|
| **Sealed Secrets** | Simple, self-contained | ✅ Phase 1-3 |
| **External Secrets** | Vault/cloud integration | Phase 4+ |
| Plain Secrets in Git | Never | ❌ |

### Sealed Secrets Workflow

```bash
# 1. Create secret locally
kubectl create secret generic db-creds \
  --from-literal=password=mypass \
  --dry-run=client -o yaml > secret.yaml

# 2. Seal it (encrypts with cluster's public key)
kubeseal --format yaml < secret.yaml > sealed-secret.yaml

# 3. Commit sealed-secret.yaml to Git (safe!)
git add sealed-secret.yaml && git commit -m "Add DB credentials"

# 4. ArgoCD deploys SealedSecret → controller decrypts → creates Secret
```

### Values with Secrets

```yaml
# values/keycloak/values.yaml
# ❌ WRONG: Hardcoded secret
adminPassword: "supersecret123"

# ✅ CORRECT: Reference existing secret
existingSecret: keycloak-admin-creds
existingSecretKey: password
```

---

## Principle 7: Naming Conventions

### Applications

| Pattern | Example |
|---------|---------|
| `{component}` | `longhorn`, `keycloak` |
| `{component}-{env}` | `keycloak-prod` (multi-env) |

### Namespaces

| Pattern | Example |
|---------|---------|
| `{function}` | `storage`, `security`, `ai-inference` |
| `{component}` | `keycloak`, `argocd` (for dedicated namespaces) |

### ArgoCD Projects

| Project | Purpose |
|---------|---------|
| `infrastructure` | Storage, networking, cluster services |
| `security` | IAM, policies, scanning |
| `ai` | Inference, MLOps, RAG |
| `observability` | Monitoring, logging, tracing |

---

## Principle 8: Health Checks and Hooks

### Custom Health Checks

```yaml
# For CRDs that ArgoCD doesn't understand natively
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  ignoreDifferences:
    - group: longhorn.io
      kind: Engine
      jsonPointers:
        - /status
```

### Sync Hooks

| Hook | Use Case |
|------|----------|
| `PreSync` | DB migrations, backups |
| `PostSync` | Smoke tests, notifications |
| `SyncFail` | Alerting, rollback triggers |

```yaml
# Example: Run DB migration before sync
apiVersion: batch/v1
kind: Job
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
```

---

## Principle 9: Multi-Source Applications (ArgoCD 2.6+)

### When to Use
When you need values from your repo + chart from external repo.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: keycloak
spec:
  sources:
    # Source 1: Official Helm chart
    - repoURL: https://charts.bitnami.com/bitnami
      chart: keycloak
      targetRevision: 24.0.0
      helm:
        valueFiles:
          - $values/values/keycloak/values.yaml  # Reference to source 2
    # Source 2: Your values repo
    - repoURL: https://github.com/Z3ROX-lab/ai-security-platform
      targetRevision: main
      ref: values                                 # Named reference
```

---

## Summary: Quick Reference

| Do ✅ | Don't ❌ |
|-------|---------|
| Reference official Helm charts | Copy/generate manifests |
| Pin specific versions | Use `latest` or `main` |
| Store only `values.yaml` in repo | Store full chart in repo |
| Use Sealed Secrets for credentials | Commit plain secrets |
| Use App-of-Apps pattern | Deploy apps individually |
| Manual sync for stateful/infra | Auto-sync everything blindly |

---

## Consequences

### Positive
- Smaller repository (only customizations)
- Always up-to-date with upstream security patches
- Clear separation: "what we customize" vs "what we use"
- Easier auditing and compliance
- Faster onboarding for new team members

### Negative
- Dependency on external Helm repos (mitigated by ChartMuseum mirror if needed)
- Need to monitor upstream for breaking changes
- Slightly more complex initial setup

### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| External repo unavailable | Cache charts in local registry / ChartMuseum |
| Breaking changes in chart | Pin versions, test before updating |
| Helm values schema changes | Read release notes, use `helm diff` |

---

## References

- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [ArgoCD Application Specification](https://argo-cd.readthedocs.io/en/stable/user-guide/application-specification/)
- [Helm Charts Best Practices](https://helm.sh/docs/chart_best_practices/)
- [GitOps Principles](https://opengitops.dev/)
- [Sealed Secrets](https://sealed-secrets.netlify.app/)
- [App-of-Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)