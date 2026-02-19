# Trivy Operator - Vulnerability Scanning

## Overview

Trivy Operator scans container images for vulnerabilities and generates Kubernetes-native reports.

## OWASP LLM Coverage

| OWASP | Threat | Trivy Contribution |
|-------|--------|-------------------|
| **LLM05** | Supply Chain Vulnerabilities | ✅ Scans images for CVEs |

Combined with Kyverno (version pinning) and Cosign (signatures), provides comprehensive supply chain security.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    TRIVY OPERATOR                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐     ┌─────────────────┐                   │
│  │  Trivy Operator │────▶│  Scan Jobs      │                   │
│  │  (Controller)   │     │  (Per Image)    │                   │
│  └────────┬────────┘     └────────┬────────┘                   │
│           │                       │                             │
│           │    Creates            │    Scans                    │
│           ▼                       ▼                             │
│  ┌─────────────────┐     ┌─────────────────┐                   │
│  │ Vulnerability   │     │  Trivy DB       │                   │
│  │ Reports (CRD)   │     │  (CVE Database) │                   │
│  └────────┬────────┘     └─────────────────┘                   │
│           │                                                     │
│           │    Metrics                                          │
│           ▼                                                     │
│  ┌─────────────────┐                                           │
│  │  Prometheus     │──────▶ Grafana Dashboard                  │
│  │  ServiceMonitor │                                           │
│  └─────────────────┘                                           │
│                                                                 │
│  SCANNED NAMESPACES: ai-inference, ai-apps, auth               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Installation

Files are deployed via ArgoCD:

```
argocd/applications/security/trivy-operator/
├── application.yaml    # ArgoCD Application
└── values.yaml         # Helm values
```

## Usage

### View Vulnerability Reports

```bash
# List all reports
kubectl get vulnerabilityreports -A

# View specific report
kubectl describe vulnerabilityreport -n ai-inference <report-name>

# Summary per namespace
kubectl get vulnerabilityreports -n ai-inference -o wide
```

### Query by Severity

```bash
# Critical vulnerabilities only
kubectl get vulnerabilityreports -A -o json | \
  jq '.items[] | select(.report.summary.criticalCount > 0) | {name: .metadata.name, critical: .report.summary.criticalCount}'
```

### Prometheus Metrics

```promql
# Total vulnerabilities by severity
sum(trivy_image_vulnerabilities) by (severity)

# Critical vulnerabilities per namespace
sum(trivy_image_vulnerabilities{severity="Critical"}) by (namespace)

# Images with vulnerabilities
count(trivy_image_vulnerabilities > 0) by (image_repository)
```

### Grafana Dashboard

Import dashboard ID: **17813** (Trivy Operator Dashboard)

Or use these panels:

```promql
# Vulnerability trend
sum(increase(trivy_image_vulnerabilities[24h])) by (severity)

# Top vulnerable images
topk(10, sum(trivy_image_vulnerabilities) by (image_repository))
```

## Configuration

### Scanned Namespaces

Only AI workload namespaces are scanned:

```yaml
targetNamespaces: "ai-inference,ai-apps,auth"
excludeNamespaces: "kube-system,argocd,kyverno,..."
```

### Severity Levels

```yaml
trivy:
  severity: CRITICAL,HIGH,MEDIUM
  ignoreUnfixed: true  # Skip vulnerabilities without fixes
```

### Resource Limits

```yaml
trivy:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

## Integration with Kyverno

Block images with critical vulnerabilities:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: block-critical-vulnerabilities
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-vulnerabilities
      match:
        any:
        - resources:
            kinds:
              - Pod
            namespaces:
              - ai-inference
              - ai-apps
      validate:
        message: "Image has critical vulnerabilities. Check VulnerabilityReport."
        deny:
          conditions:
            any:
            - key: "{{ images.*.vulnerabilities[?severity=='Critical'] | length(@) }}"
              operator: GreaterThan
              value: 0
```

> **Note:** This policy requires Kyverno to read VulnerabilityReports. Consider as future enhancement.

## Demo Scenario

```bash
# 1. Check Trivy Operator is running
kubectl get pods -n trivy-system

# 2. List vulnerability reports
kubectl get vulnerabilityreports -n ai-inference

# 3. View details of a report
kubectl describe vulnerabilityreport -n ai-inference ollama-ollama-...

# 4. Check Prometheus metrics
curl -s http://prometheus.observability.svc:9090/api/v1/query?query=trivy_image_vulnerabilities | jq
```

## Troubleshooting

### Scans not running

```bash
# Check operator logs
kubectl logs -n trivy-system -l app.kubernetes.io/name=trivy-operator

# Check for pending scan jobs
kubectl get jobs -n trivy-system
```

### High memory usage

Reduce concurrent scans:

```yaml
operator:
  scanJobsConcurrentLimit: 1
```

### Old reports

Reports are updated when pods restart. Force rescan:

```bash
# Delete old reports to trigger rescan
kubectl delete vulnerabilityreports -n ai-inference --all
```

## Resource Usage

| Component | CPU Request | Memory Request |
|-----------|-------------|----------------|
| Operator | 100m | 256Mi |
| Scan Job (per image) | 100m | 256Mi |
| **Total (idle)** | ~100m | ~256Mi |

## References

- [Trivy Operator Docs](https://aquasecurity.github.io/trivy-operator/)
- [Trivy Vulnerability Database](https://github.com/aquasecurity/trivy-db)
- [Grafana Dashboard](https://grafana.com/grafana/dashboards/17813)
