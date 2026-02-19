# Phase 8: Observability & Security Monitoring

## Overview

Phase 8 implements comprehensive observability and runtime security for the AI Security Platform.

| Component | Purpose | Status |
|-----------|---------|--------|
| **Prometheus** | Metrics collection & alerting | ✅ |
| **Grafana** | Dashboards & visualization | ✅ |
| **Alertmanager** | Alert routing & notifications | ✅ |
| **Loki** | Log aggregation | ✅ |
| **Promtail** | Log collection (DaemonSet) | ✅ |
| **Falco** | Runtime security monitoring | ✅ |
| **Kyverno** | Policy enforcement | ✅ |
| **Langfuse** | LLM Observability | ⏸️ Deferred |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                   OBSERVABILITY & SECURITY STACK                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                           GRAFANA                                    │   │
│  │                https://grafana.ai-platform.localhost                 │   │
│  │     Dashboards    │    Explore    │    Alerting                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│         ▲                    ▲                    ▲                         │
│         │                    │                    │                         │
│  ┌──────┴─────┐       ┌──────┴─────┐       ┌──────┴─────┐                  │
│  │ Prometheus │       │    Loki    │       │Alertmanager│                  │
│  │  Metrics   │       │    Logs    │       │   Alerts   │                  │
│  └──────┬─────┘       └──────┬─────┘       └────────────┘                  │
│         │                    │                                              │
│  ┌──────┴─────┐       ┌──────┴─────┐                                       │
│  │   Scrape   │       │  Promtail  │                                       │
│  │  Targets   │       │ DaemonSet  │                                       │
│  └────────────┘       └────────────┘                                       │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      SECURITY LAYER                                  │   │
│  │                                                                      │   │
│  │  ┌──────────────────────────┐  ┌──────────────────────────┐        │   │
│  │  │          FALCO           │  │         KYVERNO          │        │   │
│  │  │   Runtime Security       │  │    Policy Engine         │        │   │
│  │  │                          │  │                          │        │   │
│  │  │ • Syscall monitoring     │  │ • Admission control      │        │   │
│  │  │ • Threat detection       │  │ • Resource validation    │        │   │
│  │  │ • Container anomalies    │  │ • Image verification     │        │   │
│  │  │ • OWASP LLM10           │  │ • OWASP LLM04, LLM05     │        │   │
│  │  └──────────────────────────┘  └──────────────────────────┘        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| **Grafana** | https://grafana.ai-platform.localhost | admin / admin123! |
| **Prometheus** | https://prometheus.ai-platform.localhost | - |
| **Alertmanager** | https://alertmanager.ai-platform.localhost | - |

## Quick Start

### Vérifier le déploiement

```bash
# Observability
kubectl get pods -n observability

# Security
kubectl get pods -n falco
kubectl get pods -n kyverno

# Kyverno policies
kubectl get clusterpolicy
```

### Tester les endpoints

```bash
# Grafana
curl -sk https://grafana.ai-platform.localhost/api/health

# Prometheus
curl -sk https://prometheus.ai-platform.localhost/-/healthy

# Alertmanager
curl -sk https://alertmanager.ai-platform.localhost/-/healthy
```

## Kyverno Policies

6 policies actives pour sécuriser les workloads AI :

| Policy | Action | OWASP | Description |
|--------|--------|-------|-------------|
| `require-resource-limits` | Audit | LLM04 | Prevent DoS via resource exhaustion |
| `disallow-privileged-containers` | **Enforce** | - | Block privileged containers |
| `require-non-root` | Audit | - | Require non-root user |
| `disallow-latest-tag` | Audit | LLM05 | Enforce version pinning |
| `add-network-policy-labels` | Mutate | - | Auto-label for NetworkPolicies |
| `require-probes` | Audit | - | Require health probes |

### Namespace Exclusions

System namespaces are excluded from restrictive policies to ensure cluster stability:

```yaml
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
```

**Rationale**: System components need privileges to function. Application workloads (ai-apps, ai-inference, auth) remain protected. See [ADR-018: Kyverno Policy Strategy](../../docs/adr/ADR-018-kyverno-policy-strategy.md).

### Test Kyverno - Privileged Container (BLOCKED)

```bash
$ kubectl run test-priv --image=nginx:1.25 -n ai-inference --dry-run=server -- --privileged

Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
resource Pod/ai-inference/test-priv was blocked due to the following policies

disallow-privileged-containers:
  deny-privileged: 'validation error: Privileged containers are not allowed.'
```

✅ **BLOCKED** - Kyverno prevents privileged containers!

### View Policy Reports

```bash
# Violations per namespace
kubectl get policyreport -A

# Details
kubectl describe policyreport -n ai-inference
```

## Falco Runtime Security

Falco monitors syscalls and container behavior for threats.

### Custom Rules for AI Platform

| Rule | Priority | Trigger |
|------|----------|---------|
| Shell in AI Container | NOTICE | Shell spawned in ai-inference/ai-apps |
| Secret File Access | NOTICE | Access to /var/run/secrets |
| Suspicious Model Access | WARNING | Unauthorized model file access |

### View Falco Logs

```bash
# All Falco events
kubectl logs -n falco -l app.kubernetes.io/name=falco -c falco --tail=50

# Via Loki in Grafana
{namespace="falco"} | json
```

> **Note:** Falco syscall detection may be limited in WSL2/K3d environments due to eBPF restrictions. Full functionality available on bare-metal or cloud Kubernetes.

## Langfuse LLM Observability (Deferred)

Langfuse was planned for LLM-specific observability but is deferred due to RAM constraints.

### What Langfuse Would Add

| Feature | Benefit |
|---------|---------|
| LLM Traces | Track prompts, completions, tokens |
| Cost Tracking | Monitor API spend |
| Prompt Management | Version control for prompts |
| Evaluations | Score LLM outputs |

### Architecture (Prepared)

```
┌──────────────────────────────────────────────────────────┐
│                    LANGFUSE v3                           │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   │
│  │PostgreSQL│ │SeaweedFS │ │ClickHouse│ │  Redis   │   │
│  │(existing)│ │(existing)│ │  (new)   │ │  (new)   │   │
│  │  ~0Gi    │ │  ~0Gi    │ │ ~1.5Gi   │ │ ~256Mi   │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘   │
│                                                          │
│  Total new RAM required: ~3.5Gi                         │
│  Current available: ~500Mi                               │
│  Status: DEFERRED                                        │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

See [Langfuse Architecture](../../docs/langfuse-architecture.md) for deployment details when resources allow.

## Container Registry Strategy

Currently using K3d built-in registry. Harbor considered for future:

| Feature | K3d Registry | Harbor |
|---------|--------------|--------|
| RAM Usage | ~50Mi | ~2-4Gi |
| Vuln Scanning | ❌ | ✅ Trivy |
| Web UI | ❌ | ✅ |
| Image Signing | Via Cosign | Built-in |

See [ADR-017: Container Registry Strategy](../../docs/adr/ADR-017-container-registry-strategy.md).

## OWASP LLM Coverage

| OWASP | Threat | Mitigation |
|-------|--------|------------|
| LLM04 | Model DoS | Kyverno: require-resource-limits |
| LLM05 | Supply Chain | Kyverno: disallow-latest-tag + Cosign |
| LLM10 | Model Theft | Falco: detect exfiltration attempts |

## PromQL Examples

```promql
# CPU by namespace
sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace)

# Memory of AI components (MB)
container_memory_working_set_bytes{namespace=~"ai-inference|ai-apps"} / 1024 / 1024

# Pods running
count(kube_pod_status_phase{phase="Running"}) by (namespace)

# Kyverno policy violations
kyverno_policy_results_total{rule_result="fail"}
```

## LogQL Examples

```logql
# Logs from AI apps
{namespace="ai-apps"}

# Guardrails activity
{namespace="ai-apps"} |= "LLM Guard"

# Blocked prompt injections
{namespace="ai-apps"} |= "Valid: false"

# Errors only
{namespace="ai-inference"} |= "error"

# Falco alerts
{namespace="falco"} | json
```

## Troubleshooting

### Kyverno Webhook Deadlock

If Kyverno crashes and blocks all pod creation:

```bash
# Remove webhooks
kubectl delete validatingwebhookconfiguration -l app.kubernetes.io/instance=kyverno
kubectl delete mutatingwebhookconfiguration -l app.kubernetes.io/instance=kyverno

# Restart blocked deployments
kubectl rollout restart deployment <name> -n <namespace>

# Restart Kyverno
kubectl delete pods -n kyverno --all
```

### Falco UI Not Starting

Falcosidekick-UI may crash in WSL2/K3d. Disable if problematic:

```bash
kubectl scale deployment -n falco falco-falcosidekick-ui --replicas=0
```

Falco alerts remain visible in Grafana + Loki.

### ArgoCD Server Missing

```bash
# Check if Kyverno is blocking
kubectl get events -n argocd --sort-by='.lastTimestamp' | grep -i policy

# Force creation
kubectl delete rs -n argocd -l app.kubernetes.io/name=argocd-server
kubectl get pods -n argocd -w
```

See [Troubleshooting Guide](../../docs/troubleshooting-guide.md) for complete solutions.

## Resource Usage

| Component | RAM Request | RAM Limit |
|-----------|-------------|-----------|
| Prometheus | 512Mi | 1Gi |
| Grafana | 128Mi | 256Mi |
| Alertmanager | 64Mi | 128Mi |
| Loki | 256Mi | 512Mi |
| Promtail (x3) | 64Mi | 128Mi |
| Falco (x3) | 256Mi | 512Mi |
| Kyverno | ~400Mi | ~800Mi |
| **Total** | **~2.5Gi** | **~4.5Gi** |

## Documentation

| Document | Description |
|----------|-------------|
| [Configuration Guide](configuration-guide.md) | Prometheus, Grafana, Loki, Falco, Kyverno config |
| [Demo Guide](demo-guide.md) | 12 démos avec tests complets |
| [Cosign + Kyverno Guide](cosign-kyverno-guide.md) | Image signature verification |
| [Troubleshooting Guide](../../docs/troubleshooting-guide.md) | Common issues and solutions |
| [Langfuse Architecture](../../docs/langfuse-architecture.md) | LLM observability (deferred) |

## ADR References

| ADR | Title |
|-----|-------|
| [ADR-016](../../docs/adr/ADR-016-observability-security-monitoring-strategy.md) | Observability and Security Monitoring Strategy |
| [ADR-017](../../docs/adr/ADR-017-container-registry-strategy.md) | Container Registry Strategy |
| [ADR-018](../../docs/adr/ADR-018-kyverno-policy-strategy.md) | Kyverno Policy Strategy |

## Files

```
ai-security-platform/
├── argocd/
│   └── applications/
│       ├── observability/
│       │   ├── kube-prometheus-stack/
│       │   ├── loki/
│       │   ├── promtail/
│       │   └── falco/
│       └── security/
│           ├── kyverno/
│           └── kyverno-policies/
├── docs/
│   ├── adr/
│   │   ├── ADR-016-observability-security-monitoring-strategy.md
│   │   ├── ADR-017-container-registry-strategy.md
│   │   └── ADR-018-kyverno-policy-strategy.md
│   ├── langfuse-architecture.md
│   └── troubleshooting-guide.md
└── phases/
    └── phase-08/
        ├── README.md
        ├── configuration-guide.md
        ├── demo-guide.md
        └── cosign-kyverno-guide.md
```

---

**Date:** 2026-02-19
**Author:** Z3ROX - AI Security Platform
**Version:** 2.1.0
