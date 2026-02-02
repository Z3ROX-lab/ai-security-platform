# Helm Charts & ArgoCD Integration Guide

## Overview

This document explains how Helm charts work with ArgoCD in the AI Security Platform, including the pattern for customizing deployments while leveraging official charts.

## How Helm Charts Work

### The Helm Ecosystem

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         HELM CHART STRUCTURE                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Official Chart Repository (maintained by vendor)                        │
│  Example: https://traefik.github.io/charts                              │
│                                                                          │
│  chart-name/                                                             │
│  ├── Chart.yaml           ← Chart metadata (name, version, description) │
│  ├── values.yaml          ← DEFAULT values (all options documented)     │
│  ├── templates/           ← Kubernetes manifest templates               │
│  │   ├── deployment.yaml  ← Uses Go templating {{ .Values.xxx }}       │
│  │   ├── service.yaml                                                   │
│  │   ├── configmap.yaml                                                 │
│  │   ├── serviceaccount.yaml                                            │
│  │   ├── _helpers.tpl     ← Reusable template functions                │
│  │   └── NOTES.txt        ← Post-install instructions                  │
│  ├── charts/              ← Sub-charts (dependencies)                   │
│  └── README.md            ← Documentation                               │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Values Override Pattern

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         VALUES MERGE PROCESS                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  STEP 1: Chart's default values.yaml                                    │
│  ┌─────────────────────────────────┐                                    │
│  │ replicas: 1                     │                                    │
│  │ image:                          │                                    │
│  │   repository: traefik           │                                    │
│  │   tag: v3.0.0                   │                                    │
│  │ resources:                      │                                    │
│  │   requests:                     │                                    │
│  │     memory: 50Mi                │  ← Vendor defaults                 │
│  │     cpu: 100m                   │                                    │
│  │   limits:                       │                                    │
│  │     memory: 300Mi               │                                    │
│  │     cpu: 1000m                  │                                    │
│  └─────────────────────────────────┘                                    │
│                    │                                                     │
│                    ▼                                                     │
│  STEP 2: Your custom values.yaml (OVERRIDES ONLY)                       │
│  ┌─────────────────────────────────┐                                    │
│  │ resources:                      │                                    │
│  │   requests:                     │  ← You only specify what           │
│  │     memory: 128Mi               │    you want to CHANGE              │
│  │   limits:                       │                                    │
│  │     memory: 256Mi               │                                    │
│  └─────────────────────────────────┘                                    │
│                    │                                                     │
│                    ▼                                                     │
│  STEP 3: Merged result (Helm/ArgoCD combines them)                      │
│  ┌─────────────────────────────────┐                                    │
│  │ replicas: 1           ← default │                                    │
│  │ image:                          │                                    │
│  │   repository: traefik ← default │                                    │
│  │   tag: v3.0.0         ← default │                                    │
│  │ resources:                      │                                    │
│  │   requests:                     │                                    │
│  │     memory: 128Mi     ← yours   │                                    │
│  │     cpu: 100m         ← default │                                    │
│  │   limits:                       │                                    │
│  │     memory: 256Mi     ← yours   │                                    │
│  │     cpu: 1000m        ← default │                                    │
│  └─────────────────────────────────┘                                    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Our Project Structure

### What We Create vs What Exists

| File | Who Creates | Where | Purpose |
|------|-------------|-------|---------|
| Chart templates | Vendor (Traefik, Bitnami, etc.) | Their Helm repo | Generic K8s manifests |
| Default values.yaml | Vendor | Their Helm repo | All options with defaults |
| **application.yaml** | **Us** | Our repo | Tells ArgoCD which chart to use |
| **values.yaml** | **Us** | Our repo | Our customizations only |

### Directory Structure

```
ai-security-platform/
└── argocd/
    └── applications/
        ├── storage/
        │   ├── cnpg-operator/
        │   │   ├── application.yaml    ← ArgoCD Application manifest
        │   │   └── values.yaml         ← Our overrides
        │   └── postgresql/
        │       ├── application.yaml
        │       └── values.yaml
        ├── infrastructure/
        │   └── traefik/
        │       ├── application.yaml
        │       └── values.yaml
        └── auth/
            └── keycloak/
                ├── application.yaml
                └── values.yaml
```

## ArgoCD Application with Helm

### Multi-Source Pattern (Our Approach)

We use ArgoCD's multi-source feature to:
1. Fetch the Helm chart from the official repo
2. Fetch our values.yaml from our Git repo

```yaml
# application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: traefik
  namespace: argocd
spec:
  project: default
  sources:
    # Source 1: Official Helm chart
    - repoURL: https://traefik.github.io/charts    # Vendor's Helm repo
      chart: traefik                                # Chart name
      targetRevision: 38.0.0                        # Chart version (pin it!)
      helm:
        valueFiles:
          - $values/argocd/applications/infrastructure/traefik/values.yaml
    
    # Source 2: Our values from Git
    - repoURL: https://github.com/Z3ROX-lab/ai-security-platform
      targetRevision: master
      ref: values                                   # Reference name for $values
  
  destination:
    server: https://kubernetes.default.svc
    namespace: traefik
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

### How $values Reference Works

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     MULTI-SOURCE VALUE REFERENCE                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  sources:                                                                │
│    - repoURL: https://traefik.github.io/charts   ◄── Chart source       │
│      chart: traefik                                                      │
│      helm:                                                               │
│        valueFiles:                                                       │
│          - $values/argocd/.../values.yaml        ◄── References below   │
│                  │                                                       │
│    - repoURL: https://github.com/YOU/your-repo   ◄── Values source      │
│      ref: values  ◄──────────────────────────────────┘                  │
│           │                                                              │
│           └── This "ref: values" creates the $values variable           │
│               pointing to the root of this Git repo                     │
│                                                                          │
│  Result: ArgoCD fetches values.yaml from YOUR repo and applies it       │
│          to the Helm chart from the VENDOR repo                         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Workflow: Adding a New Component

### Step 1: Find the Official Chart

```bash
# Search for charts
helm search hub traefik

# Add the repo
helm repo add traefik https://traefik.github.io/charts
helm repo update

# List available versions
helm search repo traefik/traefik --versions | head -10
```

### Step 2: Explore Default Values

```bash
# Show ALL available options (can be long!)
helm show values traefik/traefik

# Save to file for reference
helm show values traefik/traefik > traefik-default-values.yaml

# Search for specific options
helm show values traefik/traefik | grep -A 10 "resources:"
```

### Step 3: Create Your Overrides

```bash
mkdir -p argocd/applications/infrastructure/traefik

# Create values.yaml with ONLY what you want to change
cat > argocd/applications/infrastructure/traefik/values.yaml << 'EOF'
# Traefik values - AI Security Platform
# Only overrides, not all options

deployment:
  replicas: 1

resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "256Mi"
EOF
```

### Step 4: Create ArgoCD Application

```bash
cat > argocd/applications/infrastructure/traefik/application.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: traefik
  namespace: argocd
spec:
  project: default
  sources:
    - repoURL: https://traefik.github.io/charts
      chart: traefik
      targetRevision: 38.0.0    # Always pin version!
      helm:
        valueFiles:
          - $values/argocd/applications/infrastructure/traefik/values.yaml
    - repoURL: https://github.com/Z3ROX-lab/ai-security-platform
      targetRevision: master
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: traefik
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
```

### Step 5: Register in root-app

Add the new application path to your `root-app.yaml` so ArgoCD discovers it.

### Step 6: Commit and Sync

```bash
git add argocd/applications/infrastructure/traefik/
git commit -m "feat: add Traefik ingress controller"
git push

# ArgoCD will auto-sync or manually sync
```

## Common Helm Commands

### Exploring Charts

```bash
# Add a Helm repo
helm repo add <name> <url>
helm repo update

# Search for charts
helm search repo <keyword>
helm search repo traefik

# Show chart info
helm show chart <repo>/<chart>
helm show readme <repo>/<chart>
helm show values <repo>/<chart>

# List installed releases
helm list -A
```

### Testing Locally (Without Installing)

```bash
# Render templates locally to see what will be created
helm template my-release traefik/traefik -f values.yaml

# Dry-run install
helm install my-release traefik/traefik -f values.yaml --dry-run

# Validate against cluster
helm install my-release traefik/traefik -f values.yaml --dry-run --debug
```

### Direct Install (Not GitOps)

```bash
# Install (we don't use this - we use ArgoCD instead)
helm install traefik traefik/traefik -n traefik --create-namespace -f values.yaml

# Upgrade
helm upgrade traefik traefik/traefik -n traefik -f values.yaml

# Uninstall
helm uninstall traefik -n traefik
```

## Best Practices

### 1. Always Pin Versions

```yaml
# Good - pinned version
targetRevision: 38.0.0

# Bad - unpredictable
targetRevision: latest
targetRevision: "*"
```

### 2. Minimal Values Override

```yaml
# Good - only what you need
resources:
  limits:
    memory: "256Mi"

# Bad - copying entire default values.yaml
# (makes upgrades painful, hides what you actually customized)
```

### 3. Document Your Overrides

```yaml
# values.yaml
# Traefik Ingress Controller - AI Security Platform
# 
# Overrides from default chart values:
# - Reduced replicas for home lab
# - Adjusted resources for memory constraints
# - Enabled dashboard for debugging
#
# Reference: helm show values traefik/traefik

deployment:
  replicas: 1  # Default: 1, but explicit for clarity

resources:
  requests:
    memory: "128Mi"  # Default: 50Mi, increased for stability
```

### 4. Use ServerSideApply for CRDs

```yaml
syncOptions:
  - ServerSideApply=true  # Required for large CRDs (avoids annotation size limit)
```

### 5. Check Chart Changelog Before Upgrading

```bash
# Before upgrading targetRevision
# 1. Check release notes
# 2. Compare values between versions
helm show values traefik/traefik --version 37.0.0 > old.yaml
helm show values traefik/traefik --version 38.0.0 > new.yaml
diff old.yaml new.yaml
```

## Troubleshooting

### "Values file not found"

```
Error: values file "$values/argocd/.../values.yaml" not found
```

**Cause**: The `ref: values` source is missing or path is wrong.

**Fix**: Ensure the second source has `ref: values` and path is correct relative to repo root.

### "Chart not found"

```
Error: chart "traefik" not found in repository
```

**Cause**: Wrong repo URL or chart name.

**Fix**: 
```bash
helm repo add traefik https://traefik.github.io/charts
helm search repo traefik
```

### Values Not Applied

**Cause**: YAML indentation error or wrong structure.

**Fix**: Validate your values.yaml:
```bash
# Check syntax
yamllint values.yaml

# Test merge locally
helm template test traefik/traefik -f values.yaml | head -50
```

## Quick Reference

### Finding Official Helm Repos

| Project | Helm Repo URL |
|---------|---------------|
| Traefik | `https://traefik.github.io/charts` |
| CloudNativePG | `https://cloudnative-pg.github.io/charts` |
| Keycloak (Codecentric) | `https://codecentric.github.io/helm-charts` |
| Qdrant | `https://qdrant.github.io/qdrant-helm` |
| Ollama | `https://otwld.github.io/ollama-helm` |
| Open WebUI | `https://helm.openwebui.com` |
| Prometheus/Grafana | `https://prometheus-community.github.io/helm-charts` |
| Bitnami (legacy) | `https://charts.bitnami.com/bitnami` |

### Our Application Pattern

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <component-name>
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  sources:
    - repoURL: <helm-repo-url>
      chart: <chart-name>
      targetRevision: <version>
      helm:
        valueFiles:
          - $values/argocd/applications/<category>/<component>/values.yaml
    - repoURL: https://github.com/Z3ROX-lab/ai-security-platform
      targetRevision: master
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: <target-namespace>
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

## References

- [Helm Documentation](https://helm.sh/docs/)
- [ArgoCD Helm Integration](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/)
- [ArgoCD Multiple Sources](https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/)
- [Artifact Hub (Chart Discovery)](https://artifacthub.io/)
