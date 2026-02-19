# ADR-018: Kyverno Policy Strategy and Namespace Exclusions

## Status
**Accepted** - February 2026

## Context

The AI Security Platform uses Kyverno for policy enforcement. During deployment, we encountered issues where Kyverno policies blocked system components, causing cluster instability.

### Problem Statement

```
┌─────────────────────────────────────────────────────────────────┐
│                    THE KYVERNO DEADLOCK                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Kyverno crashes                                               │
│        │                                                        │
│        ▼                                                        │
│   Webhooks still active (pointing to dead service)             │
│        │                                                        │
│        ▼                                                        │
│   All pod creation blocked                                      │
│        │                                                        │
│        ▼                                                        │
│   ArgoCD can't sync                                            │
│        │                                                        │
│        ▼                                                        │
│   Kyverno can't restart ◄─────────────────────────────┘        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Symptoms Observed
- `argocd-server` pod stuck in `Pending` or not created
- Error: `admission webhook "mutate.kyverno.svc-fail" denied the request`
- Error: `no endpoints available for service "kyverno-svc"`
- System pods blocked by `disallow-privileged-containers` policy

## Decision

1. **Exclude system namespaces** from restrictive policies
2. **Keep policies in Enforce mode** for application workloads
3. **Document emergency procedures** for webhook deadlocks

## Rationale

### Namespace Classification

| Category | Namespaces | Policy Mode |
|----------|------------|-------------|
| **System** | kube-system, argocd, kyverno, traefik, cert-manager, cnpg-system | Excluded |
| **Infrastructure** | observability, storage, falco | Excluded |
| **Application** | ai-apps, ai-inference, auth | Enforced |

### Why Exclude System Namespaces?

1. **System components need privileges**: Falco, CNI plugins, monitoring agents
2. **Managed by admins**: Not user workloads
3. **Circular dependency**: Kyverno can't validate itself
4. **ArgoCD bootstrapping**: Needs to run before policies are applied

### Why Keep Enforce for Applications?

1. **Real security value**: Protect actual workloads
2. **Demo/portfolio**: Shows production-ready security
3. **OWASP coverage**: LLM04 (DoS), LLM05 (Supply Chain)

## Implementation

### Updated Policy Configuration

```yaml
# argocd/applications/security/kyverno-policies/manifests/policies.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged-containers
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: deny-privileged
      match:
        any:
        - resources:
            kinds:
              - Pod
      exclude:
        any:
        - resources:
            namespaces:
              - kube-system
              - argocd
              - kyverno
              - cert-manager
              - traefik
              - falco
              - cnpg-system
              - observability
              - storage
      validate:
        message: "Privileged containers are not allowed"
        pattern:
          spec:
            containers:
              - securityContext:
                  privileged: "!true"
```

### Emergency Recovery Procedure

When Kyverno causes a deadlock:

```bash
# 1. Remove webhooks
kubectl delete validatingwebhookconfiguration -l app.kubernetes.io/instance=kyverno
kubectl delete mutatingwebhookconfiguration -l app.kubernetes.io/instance=kyverno

# 2. Restart blocked deployments
kubectl rollout restart deployment <blocked-deployment> -n <namespace>

# 3. Wait for pods to start
kubectl get pods -n <namespace> -w

# 4. Restart Kyverno (it will recreate webhooks with correct policies)
kubectl delete pods -n kyverno --all
```

### Webhook Failure Policy

For additional safety, webhooks can be configured with `failurePolicy: Ignore`:

```bash
# Make Kyverno non-blocking if it crashes
kubectl get mutatingwebhookconfiguration kyverno-resource-mutating-webhook-cfg -o yaml | \
  sed 's/failurePolicy: Fail/failurePolicy: Ignore/' | \
  kubectl apply -f -
```

**Note**: This is a trade-off - security vs availability. Use `Ignore` only if cluster stability is critical.

## Policy Summary

| Policy | Action | Scope | OWASP |
|--------|--------|-------|-------|
| `disallow-privileged-containers` | Enforce | ai-apps, ai-inference, auth | - |
| `require-resource-limits` | Audit | ai-apps, ai-inference | LLM04 |
| `require-non-root` | Audit | ai-apps, ai-inference | - |
| `disallow-latest-tag` | Audit | ai-apps, ai-inference | LLM05 |
| `add-network-policy-labels` | Mutate | ai-apps, ai-inference | - |
| `require-probes` | Audit | ai-apps, ai-inference | - |

## Consequences

### Positive
- Cluster stability improved
- ArgoCD can always sync
- Clear separation: system vs application security
- Emergency procedures documented

### Negative
- System namespaces not validated by Kyverno
- Requires trust in system component images

### Mitigations
- System components come from trusted sources (official Helm charts)
- Cosign verification can be added for system images
- Falco monitors runtime behavior in all namespaces

## Monitoring

### Grafana Dashboard Queries

```promql
# Policy violations
sum(increase(kyverno_policy_results_total{rule_result="fail"}[1h])) by (policy_name)

# Admission requests
sum(rate(kyverno_admission_requests_total[5m])) by (resource_namespace)
```

### Alerts

```yaml
- alert: KyvernoWebhookDown
  expr: kyverno_controller_reconcile_total == 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Kyverno webhooks may be blocking cluster operations"
```

## References

- [Kyverno Documentation](https://kyverno.io/docs/)
- [Kubernetes Admission Controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)
- ADR-005: Supply Chain Security
- ADR-016: Security Monitoring with Falco
