# Phase 4: Security Baseline

## Status: ✅ Completed

## Overview

Phase 4 establishes the security baseline for the AI Security Platform, implementing enterprise-grade security controls:

| Component | Description | Status |
|-----------|-------------|--------|
| **Network Policies** | Pod-to-pod traffic control | ✅ Configured |
| **RBAC** | Role-based access control | ✅ Configured |
| **Pod Security** | Security contexts & standards | ✅ Applied |
| **Secrets Management** | Secure credential handling | ✅ Implemented |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    SECURITY BASELINE                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                  NETWORK POLICIES                        │   │
│  │                                                          │   │
│  │  • Default deny all ingress/egress                      │   │
│  │  • Explicit allow rules per namespace                   │   │
│  │  • Micro-segmentation                                   │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                       RBAC                               │   │
│  │                                                          │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │   │
│  │  │  platform-  │  │    ai-      │  │   viewer    │     │   │
│  │  │   admin     │  │  engineer   │  │             │     │   │
│  │  │             │  │             │  │             │     │   │
│  │  │ Full access │  │ ai-* only   │  │ Read-only   │     │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                POD SECURITY STANDARDS                    │   │
│  │                                                          │   │
│  │  • runAsNonRoot: true                                   │   │
│  │  • readOnlyRootFilesystem: true                         │   │
│  │  • allowPrivilegeEscalation: false                      │   │
│  │  • capabilities: drop ALL                               │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
phase-04/
├── README.md                    # This file
└── security-baseline-guide.md   # Comprehensive security guide (67KB)
```

## Prerequisites

- Phase 1-3 completed
- Keycloak configured with realm roles
- ArgoCD syncing applications

## Security Controls Summary

### Network Policies

| Policy | Effect |
|--------|--------|
| Default Deny | Block all traffic by default |
| Allow DNS | Permit CoreDNS resolution |
| Allow Ingress | Traffic from Traefik only |
| Allow Keycloak | SSO authentication flows |
| Allow PostgreSQL | Database connections |

### RBAC Mapping (Keycloak → K8s)

| Keycloak Role | ClusterRole | Permissions |
|---------------|-------------|-------------|
| `platform-admin` | cluster-admin | Full cluster access |
| `ai-engineer` | ai-engineer-ns-admin | Edit in ai-apps, ai-inference |
| `viewer` | view | Read-only everywhere |
| `security-auditor` | security-auditor | View + events + logs |

### Pod Security Checklist

| Control | Status | Notes |
|---------|--------|-------|
| Non-root containers | ✅ | All workloads |
| Read-only filesystem | ✅ | Where possible |
| No privilege escalation | ✅ | All pods |
| Dropped capabilities | ✅ | ALL dropped |
| Resource limits | ✅ | CPU/Memory set |

## Guide

| Document | Description |
|----------|-------------|
| [Security Baseline Guide](security-baseline-guide.md) | Comprehensive 67KB security implementation guide |

The guide covers:
- Network Policy implementation
- RBAC configuration
- Pod Security Standards
- Secrets management
- Audit logging
- Compliance mapping (OWASP, NIST, CIS)

## Quick Verification

```bash
# Check Network Policies
kubectl get networkpolicies -A

# Check RBAC
kubectl get clusterroles | grep -E "admin|engineer|viewer|auditor"
kubectl get clusterrolebindings | grep -E "admin|engineer|viewer|auditor"
kubectl get rolebindings -A | grep -E "admin|engineer|viewer|auditor"

# Test RBAC (as ai-engineer)
kubectl auth can-i create pods -n ai-apps --as=ai-engineer
# Expected: yes

kubectl auth can-i create pods -n kube-system --as=ai-engineer
# Expected: no

# Check Pod Security
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: runAsNonRoot={.spec.securityContext.runAsNonRoot}{"\n"}{end}'
```

## Compliance Coverage

| Framework | Controls |
|-----------|----------|
| **OWASP LLM Top 10** | LLM01-LLM10 addressed |
| **NIST CSF** | PR.AC, PR.DS, PR.IP, PR.PT |
| **CIS Kubernetes** | 4.x, 5.x benchmarks |
| **ISO 27001** | A.9, A.13, A.14 |

## Troubleshooting

### Network Policy blocking traffic

```bash
# Check if traffic is allowed
kubectl describe networkpolicy -n <namespace> <policy-name>

# Test connectivity
kubectl exec -it <pod> -- curl -v <target-service>

# Temporarily bypass (DEBUG ONLY)
kubectl delete networkpolicy -n <namespace> <policy-name>
```

### RBAC permission denied

```bash
# Check what user can do
kubectl auth can-i --list --as=<username>

# Check specific permission
kubectl auth can-i get pods -n ai-apps --as=<username>

# Debug with impersonation
kubectl get pods -n ai-apps --as=<username>
```

### Pod failing security context

```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Common error: "container has runAsNonRoot and image will run as root"
# Fix: Add to container spec:
#   securityContext:
#     runAsUser: 1000
#     runAsGroup: 1000
```

## Next Steps

After completing Phase 4:
1. Review security guide thoroughly
2. Test RBAC with different roles
3. Verify network policies
4. Proceed to [Phase 5: AI Inference](../phase-05/README.md)

## Related Documentation

- [Kubernetes Security Guide](../../docs/knowledge-base/kubernetes-security-architecture-guide.md)
- [Keycloak RBAC Mapping](../../docs/knowledge-base/keycloak-kubernetes-rbac-mapping-guide.md)
- [ADR-003: Security Architecture](../../docs/adr/ADR-003-security-architecture.md)
