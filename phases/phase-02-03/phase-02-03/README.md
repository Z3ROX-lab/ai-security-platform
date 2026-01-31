# Phase 2-3: Security & Identity Management

## Status: ✅ Completed

## Overview

Phase 2-3 establishes the security and identity layer for the AI Security Platform:

| Component | Description | Status |
|-----------|-------------|--------|
| **PostgreSQL** | Cloud-native database (CNPG) | ✅ Deployed |
| **Keycloak** | Identity & Access Management | ✅ Configured |
| **SSO** | Single Sign-On for all apps | ✅ Working |
| **TLS** | HTTPS via cert-manager | ✅ Configured |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   SECURITY & IAM LAYER                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                      KEYCLOAK                            │   │
│  │              https://auth.ai-platform.localhost          │   │
│  │                                                          │   │
│  │  • OAuth 2.0 / OpenID Connect Provider                  │   │
│  │  • Realm: ai-platform                                    │   │
│  │  • SSO for Open WebUI, ArgoCD                           │   │
│  │  • User/Role management                                  │   │
│  │                                                          │   │
│  └──────────────────────────┬──────────────────────────────┘   │
│                              │                                  │
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    POSTGRESQL                            │   │
│  │                  (CNPG Operator)                         │   │
│  │                                                          │   │
│  │  Databases:                                              │   │
│  │  • keycloak  - IAM data                                  │   │
│  │  • openwebui - Chat history                              │   │
│  │  • mlflow    - ML metadata (future)                      │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌────────────────────┐  ┌────────────────────┐               │
│  │   CERT-MANAGER     │  │      TRAEFIK       │               │
│  │   TLS Certs        │  │   Ingress Routes   │               │
│  │   Self-signed CA   │  │   TLS Termination  │               │
│  └────────────────────┘  └────────────────────┘               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
phase-02-03/
├── README.md                         # This file
├── Keocloak-install-config-guide.md  # Keycloak installation guide
├── STEP-BY-STEP-Phase2               # Step-by-step walkthrough
├── keycloak-guide-final              # Complete Keycloak configuration
└── phase-2-3-guide-final             # Comprehensive phase guide
```

## Prerequisites

- Phase 1 completed (K3d cluster, ArgoCD running)
- DNS entries in /etc/hosts:
  ```
  127.0.0.1 auth.ai-platform.localhost
  127.0.0.1 chat.ai-platform.localhost
  ```

## Key Configuration

### Keycloak Realm: ai-platform

| Setting | Value |
|---------|-------|
| Realm | ai-platform |
| Admin Console | https://auth.ai-platform.localhost |
| Token Endpoint | /realms/ai-platform/protocol/openid-connect/token |

### Keycloak Clients

| Client ID | Type | Purpose |
|-----------|------|---------|
| `open-webui` | Confidential | Open WebUI SSO |
| `kubernetes` | Public | kubectl OIDC |
| `argocd` | Confidential | ArgoCD SSO (optional) |

### Realm Roles

| Role | Description | K8s Mapping |
|------|-------------|-------------|
| `platform-admin` | Full access | cluster-admin |
| `ai-engineer` | AI namespaces | edit in ai-* |
| `viewer` | Read-only | view |
| `security-auditor` | Security audit | view + logs |

### Users

| Username | Roles | Notes |
|----------|-------|-------|
| `zerotrust` | platform-admin | Primary admin |

## Guides

| Guide | Description |
|-------|-------------|
| [Keycloak Install Guide](Keocloak-install-config-guide.md) | Initial installation steps |
| [Step-by-Step Phase 2](STEP-BY-STEP-Phase2) | Detailed walkthrough |
| [Keycloak Guide Final](keycloak-guide-final) | Complete configuration |
| [Phase 2-3 Guide](phase-2-3-guide-final) | Comprehensive guide |

## Quick Verification

```bash
# Check PostgreSQL
kubectl get pods -n storage
# Expected: postgresql-cluster-1 Running

# Check Keycloak
kubectl get pods -n auth
# Expected: keycloak-keycloakx-0 Running

# Check certificates
kubectl get certificates -A
# Expected: All Ready=True

# Check ingresses
kubectl get ingress -A
# Expected: auth ingress present

# Test Keycloak endpoint
curl -k https://auth.ai-platform.localhost/realms/ai-platform/.well-known/openid-configuration
```

## Access

| Service | URL | Credentials |
|---------|-----|-------------|
| Keycloak Admin | https://auth.ai-platform.localhost | admin / (from secret) |

Get Keycloak admin password:
```bash
kubectl get secret -n auth keycloak-keycloakx-admin \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

## Troubleshooting

### Keycloak not starting

```bash
# Check pod status
kubectl describe pod -n auth -l app.kubernetes.io/name=keycloakx

# Check PostgreSQL connection
kubectl logs -n auth -l app.kubernetes.io/name=keycloakx | grep -i postgres
```

### Certificate not issued

```bash
# Check certificate status
kubectl describe certificate -n auth

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager
```

### DNS resolution issues

```bash
# Check CoreDNS config
kubectl get configmap -n kube-system coredns-custom -o yaml

# Test from inside cluster
kubectl run -it --rm debug --image=busybox -- nslookup auth.ai-platform.localhost
```

## Next Steps

After completing Phase 2-3:
1. Create Keycloak realm and users
2. Configure SSO clients
3. Test authentication flow
4. Proceed to [Phase 4: Security Baseline](../phase-04/README.md)

## Related Documentation

- [ADR-014: Keycloak IAM Protocols](../../docs/adr/ADR-014-keycloak-iam-protocols-deep-dive.md)
- [ADR-015: Ingress Controller Strategy](../../docs/adr/ADR-015-ingress-controller-strategy.md)
- [Keycloak Expert Guide](../../docs/knowledge-base/keycloak-expert-guide.md)
- [CNPG PostgreSQL Guide](../../docs/knowledge-base/cnpg-postgresql-guide.md)
- [Traefik Routing Guide](../../docs/knowledge-base/traefik-ingress-routing-guide.md)
