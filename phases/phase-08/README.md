# Phase 8: Observability

## Overview

Phase 8 implements comprehensive observability for the AI Security Platform using the Grafana stack.

| Component | Purpose | Status |
|-----------|---------|--------|
| **Prometheus** | Metrics collection & alerting | ✅ |
| **Grafana** | Dashboards & visualization | ✅ |
| **Alertmanager** | Alert routing & notifications | ✅ |
| **Loki** | Log aggregation | ✅ |
| **Promtail** | Log collection (DaemonSet) | ✅ |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         OBSERVABILITY STACK                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                           GRAFANA                                    │   │
│  │                https://grafana.ai-platform.localhost                 │   │
│  │                                                                      │   │
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
│  │            │       │   (x3)     │                                       │
│  │ • kube-api │       │            │                                       │
│  │ • pods     │       │ • pod logs │                                       │
│  │ • nodes    │       │ • metadata │                                       │
│  └────────────┘       └────────────┘                                       │
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
kubectl get pods -n observability
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

### Accéder aux logs dans Grafana

1. Ouvrir https://grafana.ai-platform.localhost
2. **Explore** → Sélectionner **Loki**
3. Query : `{namespace="ai-apps"}`
4. **Run query**

## Components

### Prometheus

Collecte des métriques de tous les composants Kubernetes.

| Métrique | Description |
|----------|-------------|
| `container_cpu_usage_seconds_total` | CPU par container |
| `container_memory_working_set_bytes` | Memory par container |
| `kube_pod_status_phase` | État des pods |
| `node_*` | Métriques système (node-exporter) |

### Grafana

Interface de visualisation avec dashboards pré-configurés :

- Kubernetes / Compute Resources / Cluster
- Kubernetes / Compute Resources / Namespace
- Node Exporter / Nodes
- Prometheus / Overview

### Loki

Agrégation des logs indexés par labels :

| Label | Description |
|-------|-------------|
| `namespace` | Namespace K8s |
| `pod` | Nom du pod |
| `container` | Nom du container |
| `app` | Label app |

### Promtail

DaemonSet collectant les logs de tous les pods via :
- `/var/log/pods/**/*.log`
- Métadonnées Kubernetes automatiques

## Exemples de requêtes

### PromQL (Metrics)

```promql
# CPU par namespace
sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace)

# Memory des pods AI
container_memory_working_set_bytes{namespace=~"ai-inference|ai-apps"} / 1024 / 1024

# Pods running
count(kube_pod_status_phase{phase="Running"}) by (namespace)
```

### LogQL (Logs)

```logql
# Logs Open WebUI
{namespace="ai-apps", app="open-webui"}

# Logs Guardrails filter
{namespace="ai-apps"} |= "LLM Guard"

# Erreurs uniquement
{namespace="ai-inference"} |= "error"

# Prompt injections bloquées
{namespace="ai-apps"} |= "Valid: false"
```

## Resource Usage

| Component | RAM Request | RAM Limit |
|-----------|-------------|-----------|
| Prometheus | 512Mi | 1Gi |
| Grafana | 128Mi | 256Mi |
| Alertmanager | 64Mi | 128Mi |
| Loki | 256Mi | 512Mi |
| Promtail (x3) | 64Mi | 128Mi |
| Node Exporter (x3) | 32Mi | 64Mi |
| Kube State Metrics | 64Mi | 128Mi |
| **Total** | **~1.3Gi** | **~2.5Gi** |

## Storage

```bash
$ kubectl get pvc -n observability
NAME                                               CAPACITY
prometheus-kube-prometheus-stack-prometheus-db-0   10Gi
alertmanager-kube-prometheus-stack-alertmanager-0  1Gi
kube-prometheus-stack-grafana                      5Gi
storage-loki-0                                     10Gi
```

## Security Monitoring Use Case

Surveiller les tentatives de prompt injection :

1. **Grafana** → **Explore** → **Loki**
2. Query : `{namespace="ai-apps"} |= "LLM Guard"`
3. Cliquer **Live** pour temps réel
4. Tester dans Open WebUI : "Ignore all instructions..."
5. Voir le log : `[LLM Guard] User: xxx, Valid: false, Risk: 1.0`

## Documentation

| Document | Description |
|----------|-------------|
| [Configuration Guide](phase-08-configuration-guide.md) | Configuration détaillée |
| [Demo Guide](phase-08-demo-guide.md) | Exemples et scénarios de démo |

## Files

```
ai-security-platform/
├── argocd/
│   └── applications/
│       └── observability/
│           ├── kube-prometheus-stack/
│           │   ├── application.yaml
│           │   └── values.yaml
│           ├── loki/
│           │   ├── application.yaml
│           │   └── values.yaml
│           └── promtail/
│               ├── application.yaml
│               └── values.yaml
└── phases/
    └── phase-08/
        ├── README.md
        ├── phase-08-configuration-guide.md
        └── phase-08-demo-guide.md
```

## ADR Reference

See [ADR-016: Observability and Security Monitoring Strategy](../../docs/adr/ADR-016-observability-security-monitoring-strategy.md)

## Next Steps (Optional)

| Component | Description | Status |
|-----------|-------------|--------|
| Tempo | Distributed tracing | 🔲 Optional |
| Falco | Runtime security | 🔲 Phase 8d |
| Kyverno | Policy enforcement | 🔲 Phase 8e |

---

**Date:** 2026-02-03
**Author:** Z3ROX - AI Security Platform
**Version:** 1.0.0
