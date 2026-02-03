# Phase 8: Observability - Configuration Guide

## Overview

Ce guide documente la configuration de la stack observability pour la plateforme AI Security.

| Composant | Rôle | Port |
|-----------|------|------|
| **Prometheus** | Métriques | 9090 |
| **Grafana** | Dashboards | 3000 |
| **Alertmanager** | Alertes | 9093 |
| **Loki** | Logs | 3100 |
| **Promtail** | Collecteur logs | - |

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
│  │   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │   │
│  │   │  Dashboards  │  │   Explore    │  │   Alerts     │             │   │
│  │   │  Kubernetes  │  │   Logs/Metrics│  │   Rules      │             │   │
│  │   └──────────────┘  └──────────────┘  └──────────────┘             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│         ▲                        ▲                                          │
│         │                        │                                          │
│  ┌──────┴───────┐         ┌──────┴───────┐                                 │
│  │  Prometheus  │         │     Loki     │                                 │
│  │   Metrics    │         │     Logs     │                                 │
│  │              │         │              │                                 │
│  │ prometheus.  │         │ loki.observ- │                                 │
│  │ ai-platform  │         │ ability.svc  │                                 │
│  │ .localhost   │         │ :3100        │                                 │
│  └──────┬───────┘         └──────┬───────┘                                 │
│         │                        │                                          │
│         │                        │                                          │
│  ┌──────┴───────┐         ┌──────┴───────┐                                 │
│  │    Scrape    │         │   Promtail   │                                 │
│  │   Targets    │         │  DaemonSet   │                                 │
│  │              │         │              │                                 │
│  │ • pods       │         │ • /var/log   │                                 │
│  │ • services   │         │ • pod logs   │                                 │
│  │ • endpoints  │         │              │                                 │
│  └──────────────┘         └──────────────┘                                 │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        ALERTMANAGER                                  │   │
│  │              https://alertmanager.ai-platform.localhost              │   │
│  │                                                                      │   │
│  │   Routes → Receivers → Notifications (Email, Slack, etc.)           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Composants déployés

### Namespace: observability

```bash
$ kubectl get pods -n observability
NAME                                                        READY   STATUS
kube-prometheus-stack-operator-xxx                          1/1     Running
kube-prometheus-stack-grafana-xxx                           3/3     Running
kube-prometheus-stack-kube-state-metrics-xxx                1/1     Running
kube-prometheus-stack-prometheus-node-exporter-xxx          1/1     Running  (x3)
prometheus-kube-prometheus-stack-prometheus-0               2/2     Running
alertmanager-kube-prometheus-stack-alertmanager-0           2/2     Running
loki-0                                                      2/2     Running
promtail-xxx                                                1/1     Running  (x3)
```

## Configuration Prometheus

### Fichier: `argocd/applications/observability/kube-prometheus-stack/values.yaml`

```yaml
prometheus:
  prometheusSpec:
    retention: 7d                    # Rétention des métriques
    resources:
      requests:
        memory: "512Mi"
        cpu: "200m"
      limits:
        memory: "1Gi"
        cpu: "500m"
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: local-path
          resources:
            requests:
              storage: 10Gi
    # Scrape all namespaces
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
```

### ServiceMonitors

Les ServiceMonitors définissent ce que Prometheus scrape. Exemple pour ajouter une app :

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: observability
spec:
  selector:
    matchLabels:
      app: my-app
  namespaceSelector:
    matchNames:
      - my-namespace
  endpoints:
    - port: metrics
      interval: 30s
```

### Vérifier les targets

1. Ouvrir https://prometheus.ai-platform.localhost
2. **Status** → **Targets**
3. Tous les endpoints doivent être "UP"

## Configuration Grafana

### Fichier: `argocd/applications/observability/kube-prometheus-stack/values.yaml`

```yaml
grafana:
  adminPassword: "admin123!"         # À changer en production
  
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "200m"

  persistence:
    enabled: true
    storageClassName: local-path
    size: 5Gi

  ingress:
    enabled: true
    ingressClassName: traefik
    hosts:
      - grafana.ai-platform.localhost
```

### Data Sources configurées

| Data Source | URL | Auto |
|-------------|-----|------|
| Prometheus | http://prometheus-operated:9090 | ✅ |
| Loki | http://loki:3100 | Manuel |

### Ajouter Loki manuellement

1. **Connections** → **Data sources** → **Add data source**
2. Sélectionner **Loki**
3. URL : `http://loki:3100`
4. **Save & Test**

### Dashboards pré-installés

Le chart kube-prometheus-stack inclut ~20 dashboards :

| Dashboard | Description |
|-----------|-------------|
| Kubernetes / Compute Resources / Cluster | Vue cluster |
| Kubernetes / Compute Resources / Namespace | Par namespace |
| Kubernetes / Compute Resources / Pod | Par pod |
| Node Exporter / Nodes | Métriques système |
| Prometheus / Overview | Stats Prometheus |

## Configuration Loki

### Fichier: `argocd/applications/observability/loki/values.yaml`

```yaml
deploymentMode: SingleBinary        # Mode simple pour home lab

loki:
  auth_enabled: false               # Pas d'auth (interne)
  
  commonConfig:
    replication_factor: 1
  
  storage:
    type: filesystem                # Stockage local
  
  schemaConfig:
    configs:
      - from: "2024-01-01"
        store: tsdb
        object_store: filesystem
        schema: v13

singleBinary:
  replicas: 1
  persistence:
    enabled: true
    size: 10Gi
    storageClass: local-path
```

### Labels disponibles

Loki indexe les logs par labels (pas full-text) :

| Label | Description |
|-------|-------------|
| `namespace` | Namespace Kubernetes |
| `pod` | Nom du pod |
| `container` | Nom du container |
| `app` | Label app du pod |
| `stream` | stdout / stderr |
| `node_name` | Noeud K8s |

## Configuration Promtail

### Fichier: `argocd/applications/observability/promtail/values.yaml`

```yaml
config:
  clients:
    - url: http://loki.observability.svc:3100/loki/api/v1/push

resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "128Mi"
    cpu: "100m"
```

Promtail est déployé en DaemonSet (1 pod par node) et collecte :
- `/var/log/pods/**/*.log` - Logs des pods
- Métadonnées Kubernetes (labels, annotations)

## Configuration Alertmanager

### Fichier: `argocd/applications/observability/kube-prometheus-stack/values.yaml`

```yaml
alertmanager:
  alertmanagerSpec:
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: local-path
          resources:
            requests:
              storage: 1Gi
```

### Configurer des alertes (exemple Slack)

```yaml
alertmanager:
  config:
    global:
      slack_api_url: 'https://hooks.slack.com/services/XXX'
    route:
      receiver: 'slack'
      group_by: ['alertname', 'namespace']
    receivers:
      - name: 'slack'
        slack_configs:
          - channel: '#alerts'
            send_resolved: true
```

## Stockage

### PVCs créés

```bash
$ kubectl get pvc -n observability
NAME                                               STATUS   CAPACITY
prometheus-kube-prometheus-stack-prometheus-db-0   Bound    10Gi
alertmanager-kube-prometheus-stack-alertmanager-0  Bound    1Gi
kube-prometheus-stack-grafana                      Bound    5Gi
storage-loki-0                                     Bound    10Gi
```

## Réseau

### Services

```bash
$ kubectl get svc -n observability
NAME                                      TYPE        PORT(S)
kube-prometheus-stack-grafana             ClusterIP   80/TCP
prometheus-operated                       ClusterIP   9090/TCP
alertmanager-operated                     ClusterIP   9093/TCP
loki                                      ClusterIP   3100/TCP
```

### Ingress

| Service | URL |
|---------|-----|
| Grafana | https://grafana.ai-platform.localhost |
| Prometheus | https://prometheus.ai-platform.localhost |
| Alertmanager | https://alertmanager.ai-platform.localhost |

## Ressources utilisées

| Composant | RAM Request | RAM Limit |
|-----------|-------------|-----------|
| Prometheus | 512Mi | 1Gi |
| Grafana | 128Mi | 256Mi |
| Alertmanager | 64Mi | 128Mi |
| Loki | 256Mi | 512Mi |
| Promtail (x3) | 64Mi | 128Mi |
| Node Exporter (x3) | 32Mi | 64Mi |
| Kube State Metrics | 64Mi | 128Mi |
| **Total** | ~1.3Gi | ~2.5Gi |

## Troubleshooting

### Prometheus ne scrape pas les pods

```bash
# Vérifier les ServiceMonitors
kubectl get servicemonitors -A

# Vérifier les targets
# https://prometheus.ai-platform.localhost/targets
```

### Loki ne reçoit pas les logs

```bash
# Vérifier Promtail
kubectl logs -n observability -l app.kubernetes.io/name=promtail

# Vérifier Loki
kubectl logs -n observability -l app.kubernetes.io/name=loki
```

### Grafana datasource error

```bash
# Test connectivité
kubectl exec -it -n observability deploy/kube-prometheus-stack-grafana -- \
  curl -s http://loki:3100/ready

kubectl exec -it -n observability deploy/kube-prometheus-stack-grafana -- \
  curl -s http://prometheus-operated:9090/-/healthy
```

---

**Date:** 2026-02-03
**Author:** Z3ROX - AI Security Platform
**Version:** 1.0.0
