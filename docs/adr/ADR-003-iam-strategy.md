# ADR-003: IAM Strategy

## Status
**Accepted**

## Date
2025-01-21

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

## Architecture

### Database: PostgreSQL vs H2

| Aspect | H2 (Embedded) | PostgreSQL |
|--------|---------------|------------|
| **Type** | In-memory Java DB | External relational DB |
| **Multi-instance** | ❌ Single only | ✅ Shared across replicas |
| **High Availability** | ❌ Impossible | ✅ Replication |
| **Production** | ❌ Never | ✅ Required |

**Decision**: PostgreSQL mandatory for production.

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

### High Availability
```
         ┌─────────────┐
         │   Traefik   │
         └──────┬──────┘
                │
       ┌────────┴────────┐
       ▼                 ▼
┌────────────┐    ┌────────────┐
│ Keycloak 1 │◀──▶│ Keycloak 2 │
└─────┬──────┘    └──────┬─────┘
      │    Infinispan    │
      └────────┬─────────┘
               ▼
        ┌────────────┐
        │ PostgreSQL │
        └────────────┘
```

## Implementation

### Phase 3A: Core Setup
1. Deploy PostgreSQL
2. Deploy Keycloak (Helm via ArgoCD)
3. Create `ai-platform` realm
4. Configure roles and groups

### Phase 3B: Integrations
1. ArgoCD OIDC
2. Grafana OIDC
3. OAuth2-Proxy for other apps

## Consequences

### Positive
- Enterprise-grade IAM
- Single Sign-On across platform
- Fine-grained RBAC
- Audit trail for compliance
- Transferable skills

### Negative
- Additional component (~1GB RAM)
- Learning curve for advanced features

### Mitigation
- Comprehensive documentation
- Step-by-step guides
- Knowledge base with deep dive

## References

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [OIDC Specification](https://openid.net/specs/openid-connect-core-1_0.html)
- [OAuth2-Proxy](https://oauth2-proxy.github.io/oauth2-proxy/)
