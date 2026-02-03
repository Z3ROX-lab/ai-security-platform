# Phase 8: Observability - Demo Guide

## Overview

Ce guide fournit des exemples de requêtes et scénarios de démonstration pour la stack observability.

## URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| **Grafana** | https://grafana.ai-platform.localhost | admin / admin123! |
| **Prometheus** | https://prometheus.ai-platform.localhost | - |
| **Alertmanager** | https://alertmanager.ai-platform.localhost | - |

---

## Démo 1: Métriques Cluster (Prometheus)

### Objectif
Visualiser les métriques du cluster Kubernetes.

### Via Grafana Dashboard

1. Ouvrir https://grafana.ai-platform.localhost
2. **Dashboards** → Chercher "Kubernetes / Compute Resources / Cluster"
3. Observer : CPU, Memory, Network par namespace

### Via Prometheus directement

1. Ouvrir https://prometheus.ai-platform.localhost
2. **Graph** → Entrer une requête

### Exemples de requêtes PromQL

#### CPU Usage par namespace

```promql
sum(rate(container_cpu_usage_seconds_total{namespace!=""}[5m])) by (namespace)
```

#### Memory Usage par namespace

```promql
sum(container_memory_working_set_bytes{namespace!=""}) by (namespace) / 1024 / 1024 / 1024
```

#### Pods Running par namespace

```promql
count(kube_pod_status_phase{phase="Running"}) by (namespace)
```

#### CPU Usage des LLM components

```promql
sum(rate(container_cpu_usage_seconds_total{namespace=~"ai-inference|ai-apps"}[5m])) by (pod)
```

#### Memory des Guardrails

```promql
container_memory_working_set_bytes{namespace="ai-inference", pod=~"guardrails.*"} / 1024 / 1024
```

---

## Démo 2: Logs Application (Loki)

### Objectif
Explorer les logs des applications AI.

### Via Grafana Explore

1. Ouvrir https://grafana.ai-platform.localhost
2. **Explore** (icône compas)
3. Sélectionner **Loki** en haut
4. Entrer une requête LogQL

### Exemples de requêtes LogQL

#### Logs Open WebUI

```logql
{namespace="ai-apps", app="open-webui"}
```

#### Logs Pipelines (Guardrails filter)

```logql
{namespace="ai-apps", pod=~"open-webui-pipelines.*"}
```

#### Logs LLM Guard avec filtrage

```logql
{namespace="ai-apps"} |= "LLM Guard"
```

#### Logs Guardrails API

```logql
{namespace="ai-inference", app="guardrails-api"}
```

#### Logs Ollama (LLM)

```logql
{namespace="ai-inference", app="ollama"}
```

#### Logs RAG API

```logql
{namespace="ai-inference", app="rag-api"}
```

#### Erreurs uniquement

```logql
{namespace="ai-inference"} |= "error" or |= "Error" or |= "ERROR"
```

#### Logs avec JSON parsing

```logql
{namespace="ai-inference", app="rag-api"} | json | line_format "{{.level}} {{.message}}"
```

#### Rate de logs par pod

```logql
sum(rate({namespace="ai-apps"}[5m])) by (pod)
```

---

## Démo 3: Monitoring LLM en temps réel

### Objectif
Surveiller les performances du LLM pendant une requête.

### Setup

Terminal 1 - Watch logs :
```bash
kubectl logs -n ai-apps deployment/open-webui-pipelines -f | grep "LLM Guard"
```

Terminal 2 - Watch metrics :
```bash
watch kubectl top pods -n ai-inference
```

### Test

1. Ouvrir https://chat.ai-platform.localhost
2. Envoyer : "What is Kubernetes?"
3. Observer les logs et métriques

### Dans Grafana

1. **Explore** → **Loki**
2. Query : `{namespace="ai-apps"} |= "LLM Guard"`
3. Cliquer **Live** (en haut à droite)
4. Envoyer des messages dans le chat
5. Voir les logs en temps réel

---

## Démo 4: Prometheus - Métriques & Alertes

### Objectif
Explorer Prometheus UI, tester des requêtes et comprendre les alertes.

### 4.1 Explorer Prometheus UI

1. Ouvrir https://prometheus.ai-platform.localhost
2. Les onglets principaux :
   - **Graph** : Exécuter des requêtes PromQL
   - **Alerts** : Voir les règles d'alertes et leur état
   - **Status > Targets** : Voir ce que Prometheus scrape
   - **Status > Configuration** : Config active

### 4.2 Vérifier les Targets

1. https://prometheus.ai-platform.localhost/targets
2. Tous les endpoints doivent être **UP** (vert)
3. Si un target est **DOWN** (rouge) → problème de scraping

| Target | Description |
|--------|-------------|
| `kubernetes-apiservers` | API Kubernetes |
| `kubernetes-nodes` | Métriques kubelet |
| `kubernetes-pods` | Pods avec annotations prometheus |
| `node-exporter` | Métriques système (CPU, RAM, Disk) |
| `kube-state-metrics` | État des objets K8s |

### 4.3 Tester des requêtes PromQL

1. https://prometheus.ai-platform.localhost/graph
2. Entrer une requête → **Execute** → Voir résultat (Table ou Graph)

#### Requêtes de base

```promql
# Nombre de pods running par namespace
count(kube_pod_status_phase{phase="Running"}) by (namespace)

# Usage CPU total du cluster (%)
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Usage mémoire par node (GB)
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / 1024 / 1024 / 1024

# Pods en restart (dernière heure)
increase(kube_pod_container_status_restarts_total[1h]) > 0
```

#### Requêtes AI Platform spécifiques

```promql
# CPU des composants AI
sum(rate(container_cpu_usage_seconds_total{namespace=~"ai-inference|ai-apps"}[5m])) by (pod)

# Mémoire Ollama (MB)
container_memory_working_set_bytes{namespace="ai-inference", pod=~"ollama.*"} / 1024 / 1024

# Mémoire Guardrails (MB)
container_memory_working_set_bytes{namespace="ai-inference", pod=~"guardrails.*"} / 1024 / 1024

# Pods not ready
kube_pod_status_ready{condition="false"}
```

### 4.4 Comprendre les états d'alertes

1. https://prometheus.ai-platform.localhost/alerts
2. Les 3 états possibles :

| État | Couleur | Signification |
|------|---------|---------------|
| **Inactive** | 🟢 Vert | Condition non remplie, tout va bien |
| **Pending** | 🟡 Jaune | Condition remplie, attente de confirmation (for: duration) |
| **Firing** | 🔴 Rouge | Alerte confirmée, envoyée à Alertmanager |

### 4.5 Alertes pré-configurées importantes

| Alerte | Sévérité | Description |
|--------|----------|-------------|
| **Watchdog** | info | Toujours "Firing" - prouve que le système fonctionne |
| **KubePodCrashLooping** | warning | Pod restart en boucle |
| **KubePodNotReady** | warning | Pod non prêt > 15min |
| **KubeDeploymentReplicasMismatch** | warning | Replicas attendus ≠ réels |
| **NodeFilesystemSpaceFillingUp** | warning | Disque > 80% |
| **NodeMemoryHighUtilization** | warning | RAM > 90% |
| **PrometheusTargetMissing** | warning | Target de scraping down |

### 4.6 Requêtes pour voir les alertes

```promql
# Toutes les alertes qui "fire"
ALERTS{alertstate="firing"}

# Alertes pending
ALERTS{alertstate="pending"}

# Alertes par sévérité
ALERTS{severity="critical"}
ALERTS{severity="warning"}

# Alertes d'un namespace spécifique
ALERTS{namespace="ai-inference"}
```

---

## Démo 5: Alertmanager - Gestion des alertes

### Objectif
Comprendre Alertmanager et tester le système d'alertes.

### 5.1 Explorer Alertmanager UI

1. Ouvrir https://alertmanager.ai-platform.localhost
2. Les sections :
   - **Alerts** : Alertes actives reçues de Prometheus
   - **Silences** : Alertes mises en silence
   - **Status** : Configuration et état

### 5.2 Architecture des alertes

```
┌────────────┐     Alerte      ┌──────────────┐     Notification
│ Prometheus │ ──────────────► │ Alertmanager │ ──────────────────►
│            │                 │              │
│ • Détecte  │                 │ • Groupe     │    • Email
│ • Évalue   │                 │ • Déduplique │    • Slack
│ • Envoie   │                 │ • Route      │    • PagerDuty
└────────────┘                 └──────────────┘    • Webhook
```

### 5.3 Vérifier les alertes actives

```bash
# Via curl (JSON)
curl -sk https://alertmanager.ai-platform.localhost/api/v2/alerts | jq .

# Alertes actives (noms seulement)
curl -sk https://alertmanager.ai-platform.localhost/api/v2/alerts | jq '.[].labels.alertname'

# Compter les alertes
curl -sk https://alertmanager.ai-platform.localhost/api/v2/alerts | jq 'length'
```

### 5.4 Test 1 : Envoyer une alerte manuelle

```bash
# Créer une alerte de test
curl -sk -X POST https://alertmanager.ai-platform.localhost/api/v2/alerts \
  -H "Content-Type: application/json" \
  -d '[{
    "labels": {
      "alertname": "TestAlert",
      "severity": "warning",
      "namespace": "demo",
      "service": "test-service"
    },
    "annotations": {
      "summary": "Ceci est une alerte de test",
      "description": "Test manuel de Alertmanager"
    },
    "generatorURL": "https://prometheus.ai-platform.localhost"
  }]'

# Vérifier dans UI : https://alertmanager.ai-platform.localhost
# L'alerte "TestAlert" devrait apparaître

# Vérifier via API
curl -sk https://alertmanager.ai-platform.localhost/api/v2/alerts | jq '.[] | select(.labels.alertname=="TestAlert")'
```

### 5.5 Test 2 : Déclencher une vraie alerte Kubernetes

```bash
# STEP 1: Scale down un deployment
kubectl scale deployment -n ai-apps open-webui-pipelines --replicas=0

echo "Attendre 2-5 minutes pour que l'alerte se déclenche..."
echo "Observer: https://prometheus.ai-platform.localhost/alerts"
echo "          → KubeDeploymentReplicasMismatch devrait passer en Pending puis Firing"

# STEP 2: Vérifier dans Prometheus (après 2 min)
# https://prometheus.ai-platform.localhost/alerts
# Chercher: KubeDeploymentReplicasMismatch → état "Pending" ou "Firing"

# STEP 3: Vérifier dans Alertmanager (après 5 min)
# https://alertmanager.ai-platform.localhost
# L'alerte devrait apparaître

# STEP 4: RESTAURER !
kubectl scale deployment -n ai-apps open-webui-pipelines --replicas=1

# STEP 5: Observer l'alerte disparaître
# Dans Prometheus: état revient à "Inactive"
# Dans Alertmanager: alerte résolue
```

### 5.6 Test 3 : Simuler un pod crash

```bash
# Tuer un pod pour simuler un crash
kubectl delete pod -n ai-apps -l app.kubernetes.io/name=promtail --force

# Observer:
# - Le pod restart automatiquement (DaemonSet)
# - Si assez de restarts → alerte KubePodCrashLooping
```

### 5.7 Créer un Silence (ignorer une alerte)

1. https://alertmanager.ai-platform.localhost
2. Cliquer sur une alerte
3. **Silence** → Définir durée
4. L'alerte est masquée pendant cette durée

Via API :
```bash
# Créer un silence pour TestAlert (2 heures)
curl -sk -X POST https://alertmanager.ai-platform.localhost/api/v2/silences \
  -H "Content-Type: application/json" \
  -d '{
    "matchers": [{"name": "alertname", "value": "TestAlert", "isRegex": false}],
    "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%S.000Z)'",
    "endsAt": "'$(date -u -d '+2 hours' +%Y-%m-%dT%H:%M:%S.000Z)'",
    "createdBy": "admin",
    "comment": "Test silence"
  }'
```

### 5.8 Vérifier la configuration

```bash
# Status Alertmanager
curl -sk https://alertmanager.ai-platform.localhost/api/v2/status | jq .

# Configuration active
curl -sk https://alertmanager.ai-platform.localhost/api/v2/status | jq '.config.original'
```

### 5.9 Receivers (notifications) - Non configuré en home lab

En production, on configurerait des receivers :

```yaml
# Exemple de configuration (values.yaml)
alertmanager:
  config:
    receivers:
      - name: 'slack'
        slack_configs:
          - api_url: 'https://hooks.slack.com/services/XXX'
            channel: '#alerts'
      - name: 'email'
        email_configs:
          - to: 'team@company.com'
    route:
      receiver: 'slack'
      group_by: ['alertname', 'namespace']
```

---

## Démo 6: Workflow complet - Incident simulé

### Objectif
Simuler un incident et utiliser toute la stack pour diagnostiquer.

### Scénario : Service RAG API down

```bash
# STEP 1: Provoquer l'incident
kubectl scale deployment -n ai-inference rag-api --replicas=0

# STEP 2: Observer dans Prometheus (2-5 min)
# https://prometheus.ai-platform.localhost/alerts
# → KubeDeploymentReplicasMismatch passe en "Pending" puis "Firing"

# STEP 3: Observer dans Alertmanager
# https://alertmanager.ai-platform.localhost
# → L'alerte apparaît

# STEP 4: Diagnostiquer dans Grafana
# Dashboards → Kubernetes / Compute Resources / Namespace (Pods)
# Sélectionner namespace: ai-inference
# → Voir que rag-api n'a plus de pods

# STEP 5: Voir les logs dans Loki
# Explore → Loki
# Query: {namespace="ai-inference", app="rag-api"}
# → Voir les derniers logs avant l'arrêt

# STEP 6: Résoudre
kubectl scale deployment -n ai-inference rag-api --replicas=1

# STEP 7: Vérifier la résolution
# Prometheus: alerte revient à "Inactive"
# Alertmanager: alerte marquée "Resolved"
# Grafana: pod réapparaît dans le dashboard
```

---

## Démo 7: Dashboard Kubernetes

### Objectif
Explorer les dashboards pré-installés.

### Dashboards recommandés

| Dashboard | Utilisation |
|-----------|-------------|
| Kubernetes / Compute Resources / Cluster | Vue globale |
| Kubernetes / Compute Resources / Namespace (Pods) | Détail par namespace |
| Kubernetes / Compute Resources / Node (Pods) | Détail par node |
| Node Exporter / Nodes | Métriques système (CPU, RAM, Disk) |
| CoreDNS | DNS metrics |

### Navigation

1. **Dashboards** → **Browse**
2. Filtrer par "Kubernetes" ou "Node"
3. Sélectionner le namespace en haut (dropdown)

---

## Démo 8: Corrélation Logs/Metrics

### Objectif
Corréler les métriques et logs pour diagnostiquer un problème.

### Scénario : Latence élevée sur RAG API

1. **Grafana** → **Explore**
2. Split view (bouton "Split")
3. Gauche : **Prometheus** - `histogram_quantile(0.99, rate(http_request_duration_seconds_bucket{namespace="ai-inference"}[5m]))`
4. Droite : **Loki** - `{namespace="ai-inference", app="rag-api"}`
5. Synchroniser le time range
6. Identifier les pics de latence et corréler avec les logs

---

## Démo 9: Security Monitoring (Guardrails)

### Objectif
Visualiser les tentatives de prompt injection bloquées.

### Query Loki - Blocked requests

```logql
{namespace="ai-apps", pod=~"open-webui-pipelines.*"} |= "Valid: false"
```

### Query Loki - All guardrails activity

```logql
{namespace="ai-apps"} |= "LLM Guard" | pattern "<_> User: <user>, Valid: <valid>, Risk: <risk>"
```

### Dashboard custom (à créer)

1. **Dashboards** → **New** → **New Dashboard**
2. **Add visualization**
3. Data source : Loki
4. Query : `count_over_time({namespace="ai-apps"} |= "Valid: false" [1h])`
5. Title : "Blocked Prompt Injections"

---

## Résumé des URLs de test

| Service | URL | Ce qu'on peut vérifier |
|---------|-----|------------------------|
| **Prometheus** | https://prometheus.ai-platform.localhost | Métriques, Alertes, Targets |
| **Prometheus /alerts** | https://prometheus.ai-platform.localhost/alerts | État des règles d'alertes |
| **Prometheus /targets** | https://prometheus.ai-platform.localhost/targets | Sources de métriques |
| **Alertmanager** | https://alertmanager.ai-platform.localhost | Alertes actives, Silences |
| **Grafana** | https://grafana.ai-platform.localhost | Dashboards, Explore |

---

## Démo 10: Falco - Runtime Security

### Objectif
Détecter les menaces runtime avec Falco.

### 10.1 Vérifier le déploiement

```bash
# Pods Falco (DaemonSet)
kubectl get pods -n falco

# Logs Falco
kubectl logs -n falco -l app.kubernetes.io/name=falco -f
```

### 10.2 Voir les alertes Falco dans Grafana/Loki

```logql
{namespace="falco"} | json | line_format "{{.priority}} {{.rule}} {{.output}}"
```

### 10.3 Test 1: Shell dans un container AI

```bash
# Exécuter un shell dans un pod AI (déclenche une alerte)
kubectl exec -it -n ai-inference deploy/rag-api -- /bin/sh -c "whoami"

# Vérifier les logs Falco
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=20 | grep -i shell
```

Alerte attendue:
```json
{
  "priority": "Notice",
  "rule": "Shell in AI Container",
  "output": "Shell spawned in AI container (user=root shell=sh container=rag-api namespace=ai-inference)"
}
```

### 10.4 Test 2: Accès aux secrets

```bash
# Lire un fichier secret (déclenche une alerte)
kubectl exec -it -n ai-inference deploy/rag-api -- cat /var/run/secrets/kubernetes.io/serviceaccount/token

# Vérifier
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=10 | grep -i secret
```

### 10.5 Test 3: Tentative d'exfiltration (simulée)

```bash
# Simuler une connexion externe depuis un pod AI
kubectl exec -it -n ai-inference deploy/rag-api -- curl -s https://example.com --max-time 5 || true

# Vérifier les alertes réseau
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=10 | grep -i network
```

### 10.6 Falcosidekick UI

Si activé, accéder à la UI:
```bash
kubectl port-forward -n falco svc/falco-falcosidekick-ui 2802:2802
# Ouvrir http://localhost:2802
```

---

## Démo 11: Kyverno - Policy Enforcement

### Objectif
Tester les politiques d'admission Kyverno.

### 11.1 Vérifier le déploiement

```bash
# Pods Kyverno
kubectl get pods -n kyverno

# Policies installées
kubectl get clusterpolicy

# Détails d'une policy
kubectl describe clusterpolicy require-resource-limits
```

### 11.2 Voir les Policy Reports

```bash
# Rapports par namespace
kubectl get policyreport -A

# Détails des violations
kubectl describe policyreport -n ai-inference
```

### 11.3 Test 1: Pod sans resource limits (VIOLATION)

```bash
# Créer un pod sans limits
cat <<EOF | kubectl apply -f - --dry-run=server
apiVersion: v1
kind: Pod
metadata:
  name: test-no-limits
  namespace: ai-inference
spec:
  containers:
  - name: test
    image: nginx:latest
EOF

# Résultat (mode Audit): Warning affiché
# Résultat (mode Enforce): Rejeté
```

### 11.4 Test 2: Container privileged (BLOQUÉ)

```bash
# Tenter de créer un container privileged
cat <<EOF | kubectl apply -f - --dry-run=server
apiVersion: v1
kind: Pod
metadata:
  name: test-privileged
  namespace: ai-inference
spec:
  containers:
  - name: test
    image: nginx:1.25
    securityContext:
      privileged: true
EOF

# Résultat: Error - Privileged containers are not allowed
```

### 11.5 Test 3: Image avec tag :latest (VIOLATION)

```bash
# Créer un pod avec :latest
cat <<EOF | kubectl apply -f - --dry-run=server
apiVersion: v1
kind: Pod
metadata:
  name: test-latest
  namespace: ai-inference
spec:
  containers:
  - name: test
    image: nginx:latest
    resources:
      limits:
        memory: "128Mi"
        cpu: "100m"
EOF

# Résultat (mode Audit): Warning - Using ':latest' tag is not allowed
```

### 11.6 Test 4: Pod conforme (ACCEPTÉ)

```bash
# Créer un pod conforme à toutes les policies
cat <<EOF | kubectl apply -f - --dry-run=server
apiVersion: v1
kind: Pod
metadata:
  name: test-compliant
  namespace: ai-inference
spec:
  containers:
  - name: test
    image: nginx:1.25
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
    readinessProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 10
EOF

# Résultat: Pod créé sans warnings ✅
```

### 11.7 Metrics Kyverno dans Prometheus

```promql
# Policies appliquées
kyverno_policy_results_total

# Violations par policy
kyverno_policy_results_total{rule_result="fail"}

# Admissions bloquées
kyverno_admission_requests_total{resource_request_operation="CREATE", success="false"}
```

---

## Démo 12: Cosign - Image Signature Verification

### Objectif
Démontrer la vérification des signatures d'images.

### 12.1 Installer Cosign

```bash
# Linux
curl -sSL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 -o /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign

# Vérifier
cosign version
```

### 12.2 Générer une paire de clés

```bash
# Créer répertoire
mkdir -p ~/.cosign && cd ~/.cosign

# Générer les clés
cosign generate-key-pair

# Fichiers créés:
# - cosign.key (privée - GARDER SECRÈTE)
# - cosign.pub (publique - à distribuer)
```

### 12.3 Signer une image

```bash
# Build et push une image de test
docker build -t ghcr.io/z3rox-lab/demo-app:v1.0.0 .
docker push ghcr.io/z3rox-lab/demo-app:v1.0.0

# Signer
cosign sign --key ~/.cosign/cosign.key ghcr.io/z3rox-lab/demo-app:v1.0.0

# Vérifier
cosign verify --key ~/.cosign/cosign.pub ghcr.io/z3rox-lab/demo-app:v1.0.0
```

### 12.4 Voir l'arbre de signatures

```bash
cosign tree ghcr.io/z3rox-lab/demo-app:v1.0.0

# Résultat:
# 📦 ghcr.io/z3rox-lab/demo-app:v1.0.0
# └── 🔐 Signatures
#     └── sha256:abc123...
```

### 12.5 Test Kyverno - Image non signée (BLOQUÉE)

```bash
# Déployer une image non signée (policy en Enforce)
kubectl run unsigned-app \
  --image=ghcr.io/z3rox-lab/unsigned-app:v1.0.0 \
  -n ai-inference

# Résultat attendu:
# Error: image signature verification failed for ghcr.io/z3rox-lab/unsigned-app:v1.0.0
```

### 12.6 Test Kyverno - Image signée (ACCEPTÉE)

```bash
# Déployer une image signée
kubectl run signed-app \
  --image=ghcr.io/z3rox-lab/demo-app:v1.0.0 \
  -n ai-inference

# Résultat: Pod créé ✅
```

### 12.7 Signature Keyless (OIDC)

```bash
# Signer avec authentification OIDC (ouvre navigateur)
COSIGN_EXPERIMENTAL=1 cosign sign ghcr.io/z3rox-lab/demo-app:v2.0.0

# Vérifier avec identité
cosign verify \
  --certificate-identity "your-email@example.com" \
  --certificate-oidc-issuer "https://accounts.google.com" \
  ghcr.io/z3rox-lab/demo-app:v2.0.0
```

---

## Commandes utiles

### Vérifier l'état de la stack

```bash
# Pods
kubectl get pods -n observability

# PVCs
kubectl get pvc -n observability

# Services
kubectl get svc -n observability
```

### Logs des composants

```bash
# Prometheus
kubectl logs -n observability prometheus-kube-prometheus-stack-prometheus-0 -c prometheus

# Grafana
kubectl logs -n observability -l app.kubernetes.io/name=grafana

# Loki
kubectl logs -n observability loki-0

# Promtail
kubectl logs -n observability -l app.kubernetes.io/name=promtail
```

### Métriques rapides

```bash
# CPU/Memory des pods
kubectl top pods -A --sort-by=memory | head -20

# Nodes
kubectl top nodes
```

### Test endpoints

```bash
# Prometheus
curl -sk https://prometheus.ai-platform.localhost/-/healthy

# Grafana
curl -sk https://grafana.ai-platform.localhost/api/health

# Alertmanager
curl -sk https://alertmanager.ai-platform.localhost/-/healthy

# Loki
curl -s http://localhost:3100/ready  # depuis un pod
```

---

## Script de démo

```bash
#!/bin/bash
# demo-observability.sh

echo "=== Observability Demo ==="
echo ""

echo "1. Cluster Status"
kubectl top nodes
echo ""

echo "2. Pod Resources (top 10 by memory)"
kubectl top pods -A --sort-by=memory | head -11
echo ""

echo "3. Prometheus Targets"
curl -sk https://prometheus.ai-platform.localhost/api/v1/targets | jq '.data.activeTargets | length'
echo " active targets"
echo ""

echo "4. Loki Status"
kubectl exec -n observability loki-0 -- wget -qO- http://localhost:3100/ready
echo ""

echo "5. Recent Guardrails Activity (last 10)"
kubectl logs -n ai-apps deployment/open-webui-pipelines --tail=50 | grep "LLM Guard" | tail -10
echo ""

echo "=== Demo URLs ==="
echo "Grafana:      https://grafana.ai-platform.localhost"
echo "Prometheus:   https://prometheus.ai-platform.localhost"
echo "Alertmanager: https://alertmanager.ai-platform.localhost"
```

---

## Talking Points pour vidéo

### Introduction (30s)
> "Voyons maintenant comment monitorer notre plateforme AI avec Prometheus et Grafana."

### Métriques (1min)
> "Prometheus collecte les métriques de tous les composants. Ici on voit l'utilisation CPU et mémoire par namespace. Notre LLM Ollama utilise environ 4GB de RAM."

### Logs (1min)
> "Loki centralise tous les logs. Je peux filtrer par namespace, application, ou chercher du texte. Ici je vois les logs du filtre LLM Guard qui bloque les prompt injections."

### Corrélation (30s)
> "Le split view permet de corréler métriques et logs. Si je vois un pic de latence, je peux immédiatement voir les logs correspondants."

### Conclusion (30s)
> "Cette stack observability est légère - environ 2GB de RAM - mais fournit une visibilité complète sur la plateforme."

---

**Date:** 2026-02-03
**Author:** Z3ROX - AI Security Platform
**Version:** 1.0.0
