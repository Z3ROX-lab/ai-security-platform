# ADR-003: IAM Strategy

## Status
**Accepted** - Updated 2026-01-23

## Date
2025-01-21 (Updated 2026-01-23)

## Context

The AI Security Platform requires Identity and Access Management (IAM) to:
- Authenticate users across all platform components
- Implement Role-Based Access Control (RBAC)
- Provide Single Sign-On (SSO)
- Integrate with Kubernetes RBAC

### Options Considered

| Option | Description |
|--------|-------------|
| **Keycloak** | Open source IAM, Red Hat backed |
| **Authentik** | Modern open source IAM |
| **Dex** | Lightweight OIDC provider |
| **Authelia** | Authentication server |

## Decision

**We chose Keycloak** for the following reasons:

### Comparison Matrix

| Criteria | Keycloak | Authentik | Dex | Authelia |
|----------|----------|-----------|-----|----------|
| OIDC/OAuth2 | ✅ Full | ✅ Full | ✅ OIDC only | ⚠️ Limited |
| Admin UI | ✅ Excellent | ✅ Good | ❌ None | ⚠️ Basic |
| LDAP/AD Federation | ✅ Native | ✅ Native | ⚠️ Connectors | ❌ No |
| Fine-grained RBAC | ✅ Excellent | ✅ Good | ❌ Basic | ❌ Basic |
| Enterprise adoption | ✅ High | ⚠️ Growing | ⚠️ Medium | ⚠️ Medium |
| High availability | ✅ Native | ✅ Native | ✅ Stateless | ✅ Stateless |

### Key Factors

1. **Enterprise Standard**: Keycloak is the de facto open source IAM in enterprise. Skills directly transferable.

2. **Complete Feature Set**: OIDC, SAML, LDAP federation, fine-grained RBAC, audit logging — all native.

3. **Red Hat Backing**: Based on Red Hat SSO, ensuring long-term support.

4. **Head of Platform Alignment**: Matches IAM skill requirements for platform engineering roles.

## Helm Chart Decision (Updated 2026-01-23)

### Charts Evaluated

| Chart | Maintainer | Status | Image |
|-------|------------|--------|-------|
| **Bitnami** | Broadcom | ⚠️ Paid since Aug 2025 | `bitnami/keycloak` (legacy) |
| **Codecentric keycloakx** | Codecentric | ✅ Active, open source | `quay.io/keycloak/keycloak` |
| **Keycloak Operator** | Keycloak project | ✅ Official | `quay.io/keycloak/keycloak` |

### Why NOT Bitnami

Since August 2025, Bitnami (Broadcom) has:
- Moved free images to `bitnamilegacy/*` with **no security patches**
- Required paid subscription for updated images
- Known HA issues with Infinispan clustering (GitHub #12332)

**Risk**: Using legacy images in a security-focused platform is unacceptable.

### Why Codecentric keycloakx

| Criteria | Assessment |
|----------|------------|
| **Active maintenance** | ✅ Regular updates |
| **Official image** | ✅ Uses `quay.io/keycloak/keycloak` |
| **External DB support** | ✅ Easy CNPG integration |
| **HA support** | ✅ Proven in production |
| **Community** | ✅ Widely used, good docs |
| **Quarkus-based** | ✅ Modern, lightweight |

### Why NOT Keycloak Operator (for now)

- More complex for initial setup
- CRD-driven approach adds learning curve
- Overkill for home lab with single cluster
- Can migrate later if needed

### Final Decision

**Codecentric keycloakx** chart with:
- Official Keycloak image from `quay.io/keycloak/keycloak`
- External PostgreSQL via CNPG (already deployed)
- Single replica for home lab (scale later if needed)

## Architecture

### Resource Allocation (Home Lab Optimized)

| Config | Value | Rationale |
|--------|-------|-----------|
| Replicas | 1 | Save RAM for LLM workloads |
| Memory Request | 512Mi | Minimum for stable operation |
| Memory Limit | 768Mi | Cap to preserve resources |
| CPU Request | 250m | Reasonable baseline |
| CPU Limit | 1000m | Allow burst |

**Note**: Can scale to 2 replicas later. HA is available but not critical for home lab.

### Database: PostgreSQL via CNPG

| Aspect | Configuration |
|--------|---------------|
| Database | `keycloak` |
| User | `keycloak` |
| Host | `postgresql-cluster-rw.storage.svc` |
| Connection | Internal K8s service |

**Why CNPG?**
- Already deployed in Phase 2
- HA with automatic failover
- No additional components needed

### RBAC Model

#### Realm Roles (Platform-wide, K8s RBAC mapping)

| Role | Description | K8s Mapping |
|------|-------------|-------------|
| `platform-admin` | Full platform access | cluster-admin |
| `ai-engineer` | ML tools access | Custom ClusterRole |
| `security-auditor` | Security dashboards | view + security |
| `viewer` | Read-only | view |

#### Client Roles (Application-specific)

| Client | Roles | Purpose |
|--------|-------|---------|
| `argocd` | admin, readonly | ArgoCD permissions |
| `grafana` | Admin, Editor, Viewer | Grafana permissions |
| `open-webui` | admin, user | Chat access |

#### Groups

| Group | Realm Roles | Members |
|-------|-------------|---------|
| `platform-team` | platform-admin | DevOps, Platform Engineers |
| `data-scientists` | ai-engineer | ML Engineers |
| `security-team` | security-auditor | Security Engineers |

### Integration Patterns

#### Pattern 1: Native OIDC
```
User → App → Keycloak → App (with JWT)
```

Apps: ArgoCD, Grafana (built-in OIDC support)

#### Pattern 2: OAuth2-Proxy
```
User → OAuth2-Proxy → Keycloak → OAuth2-Proxy → App
```

Apps: Open WebUI, MLflow (no native OIDC)

### Network Architecture

```
                    ┌─────────────────┐
                    │     Traefik     │
                    │  (Ingress)      │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
    ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
    │  Keycloak   │  │   ArgoCD    │  │   Grafana   │
    │  /auth      │  │   /argocd   │  │   /grafana  │
    └──────┬──────┘  └─────────────┘  └─────────────┘
           │
           ▼
    ┌─────────────┐
    │ PostgreSQL  │
    │   (CNPG)    │
    └─────────────┘
```

## Implementation

### Phase 3A: Prerequisites
1. ✅ Deploy PostgreSQL (CNPG) - Done in Phase 2
2. Deploy Traefik (Ingress Controller)
3. Create Keycloak database in CNPG

### Phase 3B: Keycloak Deployment
1. Deploy Keycloak via Codecentric keycloakx chart
2. Configure external PostgreSQL
3. Setup Ingress (`auth.ai-platform.localhost`)
4. Create `ai-platform` realm
5. Configure roles and groups

### Phase 3C: Integrations
1. ArgoCD OIDC
2. Grafana OIDC (Phase 8)
3. OAuth2-Proxy for other apps

## Consequences

### Positive
- Enterprise-grade IAM
- Single Sign-On across platform
- Fine-grained RBAC
- Audit trail for compliance
- Transferable skills
- No vendor lock-in (official images)
- Future-proof (active maintenance)

### Negative
- Additional component (~768MB RAM)
- Learning curve for advanced features

### Risks Mitigated
- ❌ Bitnami licensing risk → ✅ Using Codecentric with official images
- ❌ Legacy image security → ✅ Using `quay.io/keycloak/keycloak`
- ❌ RAM constraints → ✅ Single replica, optimized limits

## References

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Codecentric Helm Charts](https://github.com/codecentric/helm-charts)
- [Keycloak Official Image](https://quay.io/repository/keycloak/keycloak)
- [OIDC Specification](https://openid.net/specs/openid-connect-core-1_0.html)
- [Bitnami License Change Discussion](https://github.com/keycloak/keycloak/discussions/42170)
