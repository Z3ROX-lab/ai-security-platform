# 🔍 Trivy Operator — Commandes kubectl

## Les CRDs disponibles

```bash
# Lister tous les types de rapports Trivy
kubectl get crd | grep trivy
```

| CRD | Description |
|-----|-------------|
| `vulnerabilityreports` | CVEs dans les images des pods |
| `configauditreports` | Misconfigurations Kubernetes |
| `exposedsecretreports` | Secrets exposés dans les images |
| `rbacassessmentreports` | Problèmes RBAC |
| `infraassessmentreports` | Problèmes d'infrastructure |
| `clustercompliancereports` | Conformité NSA/CISA, PSS |

---

## VulnerabilityReports — CVEs dans les images

```bash
# Lister tous les rapports (tous namespaces)
kubectl get vulnerabilityreports -A

# Lister dans un namespace
kubectl get vulnerabilityreports -n ai-inference

# Résumé d'un rapport (counts par sévérité)
kubectl describe vulnerabilityreport <nom> -n <namespace> | head -20

# Voir uniquement les CRITICAL
kubectl describe vulnerabilityreport replicaset-ollama-866b778f54-ollama -n ai-inference \
  | grep -A5 "Severity:.*CRITICAL"

# Voir CRITICAL + HIGH
kubectl describe vulnerabilityreport replicaset-ollama-866b778f54-ollama -n ai-inference \
  | grep -A6 -E "Severity:\s+(CRITICAL|HIGH)"

# Output JSON complet (pour parser les CVE IDs)
kubectl get vulnerabilityreport replicaset-ollama-866b778f54-ollama \
  -n ai-inference -o json \
  | jq '.report.vulnerabilities[] | select(.severity=="CRITICAL") | {id: .vulnerabilityID, title: .title, pkg: .resource, fixed: .fixedVersion}'

# Toutes les CRITICAL de tous les namespaces
for r in $(kubectl get vulnerabilityreports -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}'); do
  ns=$(echo $r | cut -d/ -f1)
  name=$(echo $r | cut -d/ -f2)
  count=$(kubectl get vulnerabilityreport $name -n $ns -o jsonpath='{.report.summary.criticalCount}')
  if [ "$count" -gt "0" ] 2>/dev/null; then
    echo "🔴 CRITICAL=$count  $ns/$name"
  fi
done
```

---

## ConfigAuditReports — Misconfigurations

```bash
# Lister tous les rapports de config
kubectl get configauditreports -A

# Voir les FAIL (misconfigs détectées)
kubectl describe configauditreport statefulset-qdrant -n ai-inference \
  | grep -A4 "Success:.*false"

# Voir uniquement HIGH et CRITICAL
kubectl describe configauditreport statefulset-qdrant -n ai-inference \
  | grep -B1 -A4 -E "Severity:\s+(HIGH|CRITICAL)"

# Output JSON — extraire les checks échoués
kubectl get configauditreport statefulset-qdrant -n ai-inference -o json \
  | jq '.report.checks[] | select(.success==false) | {id: .checkID, title: .title, severity: .severity}'
```

---

## ExposedSecretReports — Secrets exposés

```bash
# Lister les rapports de secrets
kubectl get exposedsecretreports -A

# Voir les secrets trouvés
kubectl describe exposedsecretreport <nom> -n <namespace>

# JSON
kubectl get exposedsecretreport <nom> -n <namespace> -o json \
  | jq '.report.secrets[]'
```

---

## RBACAssessmentReports

```bash
# Lister
kubectl get rbacassessmentreports -A

# Voir les problèmes RBAC détectés
kubectl get rbacassessmentreport <nom> -n <namespace> -o json \
  | jq '.report.checks[] | select(.success==false) | {title: .title, severity: .severity}'
```

---

## ClusterComplianceReports — Conformité

```bash
# Lister les rapports de conformité cluster-wide
kubectl get clustercompliancereports

# Résumé conformité NSA/CISA
kubectl describe clustercompliancereport nsa

# Résumé conformité CIS Kubernetes
kubectl describe clustercompliancereport cis
```

---

## Commandes utiles — Vue d'ensemble rapide

```bash
# Résumé global de toutes les vulnérabilités
kubectl get vulnerabilityreports -A -o json | jq '
  [.items[] | {
    namespace: .metadata.namespace,
    image: .report.artifact.repository,
    tag: .report.artifact.tag,
    critical: .report.summary.criticalCount,
    high: .report.summary.highCount,
    medium: .report.summary.mediumCount
  }] | sort_by(-.critical, -.high)'

# Top 5 images les plus vulnérables
kubectl get vulnerabilityreports -A -o json | jq '
  [.items[] | {
    image: "\(.report.artifact.repository):\(.report.artifact.tag)",
    critical: .report.summary.criticalCount,
    high: .report.summary.highCount
  }] | sort_by(-.critical) | .[0:5]'

# Tous les CVE CRITICAL de toute la plateforme
kubectl get vulnerabilityreports -A -o json | jq '
  .items[] | .report.vulnerabilities[] 
  | select(.severity=="CRITICAL") 
  | {id: .vulnerabilityID, title: .title, pkg: .resource}'
```

---

## Grafana — Dashboard Trivy

Le dashboard **"Trivy Vulnerability Scanner"** est disponible dans Grafana :
- `http://localhost:3000` → Dashboards → Search "trivy"
- Montre : pie chart par sévérité, counts par image
- Les métriques Prometheus Trivy (`trivy_image_vulnerabilities`) ne sont pas activées par défaut dans cette config

Pour activer les métriques Prometheus dans les values Trivy :
```yaml
# argocd/applications/security/trivy-operator/values.yaml
trivy:
  ignoreUnfixed: false
serviceMonitor:
  enabled: true    # ← activer pour exposer métriques à Prometheus
```

---

## Astuce — Surveiller en continu

```bash
# Watch les nouveaux rapports en temps réel
kubectl get vulnerabilityreports -A -w

# Alerter sur les nouvelles CRITICAL
watch -n 60 "kubectl get vulnerabilityreports -A -o json | \
  jq '[.items[].report.summary.criticalCount] | add'"
```
