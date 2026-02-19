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
| [Configuration Guide](phase-08-configuration-guide.md) | Prometheus, Grafana, Loki, Falco, Kyverno config |
| [Demo Guide](phase-08-demo-guide.md) | 12 démos avec tests complets |
| [Cosign + Kyverno Guide](cosign-kyverno-guide.md) | Image signature verification |

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
└── phases/
    └── phase-08/
        ├── README.md
        ├── phase-08-configuration-guide.md
        ├── phase-08-demo-guide.md
        └── cosign-kyverno-guide.md
```

## ADR Reference

See [ADR-016: Observability and Security Monitoring Strategy](../../docs/adr/ADR-016-observability-security-monitoring-strategy.md)

---

**Date:** 2026-02-03
**Author:** Z3ROX - AI Security Platform
**Version:** 2.0.0
