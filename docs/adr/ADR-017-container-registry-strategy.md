# ADR-017: Container Registry Strategy

## Status
**Accepted** - February 2026

## Context

The AI Security Platform needs a container image management strategy that addresses:
- Image storage and caching
- Supply chain security (OWASP LLM05)
- Vulnerability scanning
- Image signing and verification
- Access control

### Current Environment
- K3d cluster with 32GB RAM (15Gi typically used)
- GitOps with ArgoCD
- Kyverno for policy enforcement
- Cosign integration prepared

### Options Evaluated

| Option | Description |
|--------|-------------|
| **A** | K3d built-in registry (current) |
| **B** | Harbor enterprise registry |
| **C** | Docker Hub / External registries only |

## Decision

**Option A: K3d built-in registry** for the current home lab setup, with **Harbor as future enhancement** when resources allow.

## Rationale

### Why K3d Registry Now

| Factor | K3d Registry | Harbor |
|--------|--------------|--------|
| RAM usage | ~50Mi | ~2-4Gi |
| Complexity | None | High (PostgreSQL, Redis, Trivy) |
| Setup time | Automatic with K3d | 1-2 hours |
| Supply chain security | Via Kyverno + Cosign | Built-in |

### Current Supply Chain Security Coverage

Without Harbor, we achieve supply chain security through:

```
┌─────────────────────────────────────────────────────────────────┐
│                    SUPPLY CHAIN SECURITY                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│  │    Kyverno      │    │     Cosign      │    │  K3d Cache  │ │
│  │                 │    │                 │    │             │ │
│  │ • disallow-     │    │ • Image signing │    │ • Local     │ │
│  │   latest-tag    │    │ • Verification  │    │   registry  │ │
│  │ • require-      │    │ • Keyless OIDC  │    │ • Fast pull │ │
│  │   signatures    │    │ • Attestations  │    │             │ │
│  └─────────────────┘    └─────────────────┘    └─────────────┘ │
│                                                                 │
│  Coverage: OWASP LLM05 ✅                                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Harbor Benefits (Future)

When resources allow, Harbor would add:

| Feature | Benefit |
|---------|---------|
| **Trivy scanning** | Automated vulnerability detection before deployment |
| **Web UI** | Visual image management and audit |
| **RBAC** | Fine-grained access control per project/team |
| **Replication** | Mirror images across environments |
| **Notary** | Additional signing mechanism |
| **Audit logs** | Compliance and forensics |

### Harbor Architecture (Future State)

```
┌─────────────────────────────────────────────────────────────────┐
│                         HARBOR                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │  Core    │  │  Portal  │  │  Trivy   │  │  Notary  │       │
│  │  API     │  │  UI      │  │  Scanner │  │  Signing │       │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘       │
│       │             │             │             │              │
│       └─────────────┴──────┬──────┴─────────────┘              │
│                            │                                    │
│                    ┌───────┴───────┐                           │
│                    │               │                            │
│              ┌─────┴─────┐   ┌─────┴─────┐                     │
│              │PostgreSQL │   │   Redis   │                     │
│              │  (CNPG)   │   │  (new)    │                     │
│              └───────────┘   └───────────┘                     │
│                                                                 │
│  Storage: SeaweedFS S3 or PVC                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Resource Requirements

| Component | RAM | Storage |
|-----------|-----|---------|
| Harbor Core | 512Mi | - |
| Harbor Portal | 256Mi | - |
| Harbor JobService | 256Mi | - |
| Trivy | 1Gi | - |
| Redis | 256Mi | 1Gi |
| PostgreSQL | Existing CNPG | 5Gi |
| Image Storage | - | 50-100Gi |
| **Total** | **~2.5Gi** | **~60Gi** |

## Implementation

### Current State (K3d Registry)

```yaml
# K3d cluster created with local registry
k3d cluster create ai-security-platform \
  --registry-create k3d-ai-security-platform-registry:5000
```

Images are cached automatically in the K3d nodes.

### Future State (Harbor)

```bash
# Add Harbor Helm repo
helm repo add harbor https://helm.goharbor.io

# Install with values
helm install harbor harbor/harbor \
  --namespace harbor \
  --create-namespace \
  -f harbor-values.yaml
```

Example values.yaml:
```yaml
expose:
  type: ingress
  ingress:
    hosts:
      core: harbor.ai-platform.localhost
    className: traefik
    
externalURL: https://harbor.ai-platform.localhost

persistence:
  persistentVolumeClaim:
    registry:
      storageClass: local-path
      size: 50Gi

database:
  type: external
  external:
    host: postgresql-rw.storage.svc.cluster.local
    port: 5432
    username: harbor
    password: harbor-password
    database: harbor

trivy:
  enabled: true
  
notary:
  enabled: true
```

### Kyverno Integration with Harbor

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-harbor-images
spec:
  validationFailureAction: Enforce
  rules:
    - name: require-harbor-registry
      match:
        any:
        - resources:
            kinds:
              - Pod
            namespaces:
              - ai-inference
              - ai-apps
      validate:
        message: "Images must come from Harbor registry"
        pattern:
          spec:
            containers:
              - image: "harbor.ai-platform.localhost/*"
```

## Consequences

### Positive
- Minimal resource usage with current setup
- Supply chain security via Kyverno + Cosign
- Clear upgrade path to Harbor when needed
- No additional complexity for home lab

### Negative
- No vulnerability scanning at registry level (currently)
- No web UI for image management
- Manual audit of images used

### Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| No vulnerability scanning | Use `trivy` CLI manually or add Trivy Operator |
| Image sprawl | Kyverno policies enforce image standards |
| No access control | Cluster-level RBAC sufficient for single-user |

## Future Considerations

1. **Add Harbor when**:
   - Moving to cloud (more resources)
   - Multi-team access needed
   - Compliance requires audit logs
   - Automated vulnerability scanning required

2. **Alternative: Trivy Operator**
   - Lighter than Harbor (~500Mi RAM)
   - Scans running workloads
   - Integrates with Prometheus/Grafana

## References

- [Harbor Documentation](https://goharbor.io/docs/)
- [K3d Registry](https://k3d.io/v5.6.0/usage/registries/)
- [Trivy Operator](https://aquasecurity.github.io/trivy-operator/)
- [OWASP LLM05 - Supply Chain Vulnerabilities](https://owasp.org/www-project-llm-security/)
- ADR-005: Supply Chain Security
- GitHub Issue: "Add Harbor container registry"
