# AI Security Platform — Demo Showcase

> **Stack:** K3d · ArgoCD · Keycloak · Open WebUI · Ollama (Mistral 7B) · LLM Guard · RAG API · Qdrant · Falco · Kyverno · Trivy · Prometheus · Grafana · Loki

This document demonstrates the AI Security Platform covering **6 OWASP LLM Top 10** risk categories through real-world scenarios.

---

## OWASP LLM Top 10 Coverage

| OWASP | Risk | Mitigation | Scenario |
|-------|------|-----------|---------|
| LLM01 | Prompt Injection | LLM Guard Pipeline | [Scenario 3](#scenario-3--prompt-injection-attack) |
| LLM04 | Model DoS | Kyverno Resource Limits | [Scenario 5b](#scenario-5b--kyverno-policy-enforcement) |
| LLM05 | Supply Chain Vulnerabilities | Trivy Operator | [Scenario 5a](#scenario-5a--trivy-vulnerability-scanning) |
| LLM06 | Sensitive Information Disclosure | RAG + Guardrails API | [Scenario 2](#scenario-2--rag-document-qa) |
| LLM08 | Excessive Agency | Keycloak OIDC + RBAC | [Scenario 6](#scenario-6--sso--gitops-compliance) |
| LLM10 | Model Theft | Falco Runtime Detection | [Scenario 4](#scenario-4--falco-runtime-security) |

---

## Architecture

```
User → Traefik Ingress → Open WebUI
                              ↓
                    LLM Guard Pipeline (Prompt Injection Detection)
                              ↓
                    RAG Context Pipeline (Qdrant Vector DB)
                              ↓
                    Ollama (Mistral 7B) ← Guardrails API
                    
Security Layer:
  Keycloak OIDC → AuthN/AuthZ
  Kyverno → Policy Enforcement
  Falco → Runtime Detection
  Trivy → Supply Chain Scanning
  NetworkPolicies → Network Segmentation
  Sealed Secrets → Secrets Management
  
Observability:
  Prometheus + Grafana → Metrics
  Loki + Promtail → Logs
  ArgoCD → GitOps
```

---

## Scenario 1 — AI Chat Normal

> **Demonstrates:** End-to-end AI chat with security pipeline active.
> All requests pass through LLM Guard before reaching Mistral.

### Open WebUI — Mistral 7B Response

![Open WebUI Chat Response](screenshots/01-openwebui-chat-response.png)

*Mistral 7B responding to a Zero Trust Architecture query via Open WebUI. The model `mistral:7b-instruct-v0.3-q4_K_M` is loaded through Ollama running in the `ai-inference` namespace.*

---

### Grafana — AI Inference Namespace Metrics

![Grafana Ollama Metrics](screenshots/02-grafana-ollama-metrics.png)

*Container memory usage for the `ai-inference` namespace showing Ollama (~6GB for Mistral 7B), Guardrails API, Qdrant, and RAG API. Metrics collected by Prometheus via kube-state-metrics.*

---

### LLM Guard Pipeline — PASS Logs

![LLM Guard Pipeline Logs](screenshots/03-pipeline-logs-llmguard-pass.png)

*Pipeline logs showing both pipelines loaded (`rag_context_pipeline` + `llmguard_filter_pipeline`) and a legitimate request passing the LLM Guard security scan: `No injection keywords — PASS`.*

---

## Scenario 2 — RAG Document Q&A

> **Demonstrates:** OWASP LLM06 — Sensitive Information Disclosure mitigation.
> Documents are processed through the RAG pipeline with Guardrails API validation.

### Open WebUI — RAG Response with Source Citation

![RAG Response](screenshots/01-openwebui-rag-response.png)

*Mistral answering a question about a specific uploaded document (`DEMO-TEST-v2.md`, 28.7KB). The response includes a source citation confirming the RAG pipeline retrieved context from the document.*

---

### RAG API — Swagger Interface

![RAG API Swagger](screenshots/02-rag-api-swagger.png)

*RAG API v2.0 (OAS 3.1) exposing endpoints: `/health`, `/stats`, `/ingest`, `/search`, `/query`, `/clear`. The API connects to Qdrant for vector storage and Guardrails API for output validation.*

---

## Scenario 3 — Prompt Injection Attack

> **Demonstrates:** OWASP LLM01 — Prompt Injection detection and blocking.
> LLM Guard pipeline intercepts malicious prompts before they reach the model.

### LLM Guard — Attack Blocked

![LLM Guard Blocked](screenshots/01-llmguard-blocked.png)

*A DAN (Do Anything Now) jailbreak attempt is blocked by the LLM Guard pipeline. The response `🛡️ Security scan unavailable - suspicious content blocked` is returned instead of forwarding the request to Mistral.*

---

### LLM Guard — Detection Logs

![LLM Guard Logs Blocked](screenshots/02-llmguard-logs-blocked.png)

*Pipeline logs showing the keyword detection engine identifying injection patterns:*
- `\bignore\b.*\binstructions?\b`
- `\bsystem\s*prompt\b`
- `\byou\s*are\s*now\b`
- `\bDAN\b`
- `\bdo\s*anything\s*now\b`
- `\breveal\b.*\b(prompt|instructions|config)\b`

*Previous legitimate requests show `No injection keywords — PASS` confirming the pipeline is active for all requests.*

---

## Scenario 4 — Falco Runtime Security

> **Demonstrates:** OWASP LLM10 — Model Theft detection.
> Falco monitors syscalls in real-time and alerts on suspicious file access patterns.

### Falco — Suspicious Activity Triggered

![Falco Alert Triggered](screenshots/01-falco-alert-triggered.png)

*An `kubectl exec` command into the `rag-api` pod triggers Falco's runtime detection. The command reads `/etc/passwd` which is a common reconnaissance technique.*

---

### Falco — Warning Logs (Terminal)

![Falco Logs Terminal](screenshots/02-falco-logs-terminal.png)

*Falco Warning logs showing `Suspicious Access to Model Files` detections with OWASP tags: `["OWASP-LLM10", "ai-security", "model-theft"]`. Multiple alerts fired for access to transformer model files (`xglm`, `xlm`, `xlm_roberta`, `zamba2`).*

---

### Falco — Grafana Loki Integration

![Falco Grafana Loki](screenshots/03-falco-grafana-loki.png)

*Falco logs aggregated in Grafana via Loki datasource. Query: `{namespace="falco"} |= "Warning"`. Over **1.14 million log entries** processed showing continuous runtime monitoring. The `Warning` keyword is highlighted in each alert entry.*

---

## Scenario 5a — Trivy Vulnerability Scanning

> **Demonstrates:** OWASP LLM05 — Supply Chain Vulnerabilities.
> Trivy Operator automatically scans all container images and Kubernetes configurations.

### Trivy — All Images Scanned

![Trivy Vulnerability Reports](screenshots/01-trivy-vulnerability-reports.png)

*`kubectl get vulnerabilityreports -A` showing all platform images scanned by Trivy:*
- `open-webui:0.6.7`
- `keycloak:26.5.1`
- `ollama:0.3.4`
- `python:3.11-slim` (RAG API + Guardrails API)
- `qdrant:v1.10.1`

*`kubectl get configauditreports -A` showing Kubernetes configuration audits for all services.*

---

### Trivy — Ollama CVE Detail

![Trivy Vuln Detail Ollama](screenshots/02-trivy-vuln-detail-ollama.png)

*Vulnerability report for `ollama:0.3.4`: **2 Critical, 9 High, 80 Medium** CVEs detected.*

*Notable CVEs:*
- `CVE-2025-68973` (HIGH) — GnuPG: Information disclosure and arbitrary code execution via out-of-bounds write. Fixed in 2.2.27-3ubuntu2.3
- `CVE-2025-30258` (MEDIUM) — GnuPG: DoS via malicious subkey
- `CVE-2025-0395` (MEDIUM) — glibc: buffer overflow in assert()

---

### Trivy — Config Audit Report

![Trivy Config Audit](screenshots/03-trivy-config-audit.png)

*Configuration audit for `qdrant` StatefulSet detecting security misconfigurations:*
- `Can elevate its own privileges` (MEDIUM)
- `Runs as root user` (MEDIUM)
- `Root file system is not read-only` (HIGH)
- `Container images from public registries used` (MEDIUM)

*These findings inform the Kyverno policy roadmap.*

---

### Trivy — Grafana Dashboard

![Trivy Grafana Dashboard](screenshots/04-trivy-grafana-dashboard.png)

*Trivy Vulnerability Scanner dashboard in Grafana showing vulnerabilities by severity (pie chart) and per image breakdown:*
- `qdrant/qdrant`: **6 Critical + 62 High**
- `ollama/ollama`: **2 Critical + 9 High**
- `library/python:3.11-slim`: **0 Critical + 6 High**

---

## Scenario 5b — Kyverno Policy Enforcement

> **Demonstrates:** OWASP LLM04 — Model DoS prevention via resource limits enforcement.
> Kyverno policies enforce security baseline across all AI workloads.

### Kyverno — Privileged Pod (Audit Mode)

![Kyverno Pod Created Audit](screenshots/01-kyverno-pod-created-audit.png)

*A privileged pod is submitted to the `ai-apps` namespace. In **Audit mode**, Kyverno allows the creation but records the violation. In Enforce mode, the admission webhook would reject the pod with a `403 Forbidden` error.*

> **Note:** Kyverno is currently in Audit mode to allow gradual compliance remediation. Migration to Enforce mode is planned namespace by namespace starting with `ai-apps`.

---

### Kyverno — Policy Reports Overview

![Kyverno Policy Reports](screenshots/02-kyverno-policyreports.png)

*`kubectl get policyreports -A` showing policy compliance status for all resources. Each row shows `PASS/FAIL/WARN` counts per Pod/ReplicaSet/StatefulSet across all namespaces.*

---

### Kyverno — Violation Details

![Kyverno Violations Detail](screenshots/03-kyverno-violations-detail.png)

*Detailed policy violations detected by Kyverno on the test pod:*

| Policy | Rule | Severity | Message |
|--------|------|----------|---------|
| `disallow-privileged-containers` | `autogen-deny-privileged` | HIGH | Privileged containers are not allowed |
| `require-non-root` | `autogen-check-non-root` | MEDIUM | Containers should run as non-root user |
| `require-probes` | `autogen-check-readiness-probe` | MEDIUM | Readiness probe is required for AI workloads |
| `require-resource-limits` | `autogen-check-resource-limits` | MEDIUM | Resource limits required (OWASP LLM04) |

---

## Scenario 6 — SSO & GitOps Compliance

> **Demonstrates:** OWASP LLM08 — Excessive Agency prevention via identity management.
> Keycloak OIDC enforces authentication. ArgoCD ensures GitOps-driven deployments.

### Open WebUI — SSO Login Page

![Open WebUI SSO Login](screenshots/01-openwebui-sso-login.png)

*Open WebUI login page offering both local authentication and **"Continue with Keycloak"** SSO. OIDC integration ensures all users authenticate through the centralized identity provider.*

---

### Keycloak — OIDC Redirect

![Keycloak OIDC Redirect](screenshots/02-keycloak-oidc-redirect.png)

*Keycloak `ai-platform` realm login page after OIDC redirect from Open WebUI. The URL confirms the full OIDC flow: `response_type=code&client_id=open-webui&redirect_uri=https://chat.ai-platform.localhost`. Microsoft Entra ID federation is available as an additional identity provider.*

---

### Keycloak — OIDC Clients

![Keycloak Realm Clients](screenshots/03-keycloak-realm-clients.png)

*Keycloak Admin Console showing all OIDC clients in the `ai-platform` realm:*

| Client | Description | Home URL |
|--------|-------------|----------|
| `open-webui` | AI Chat Interface | https://chat.ai-platform.localhost |
| `kubernetes` | K8s API RBAC bridge | — |
| `argocd` | GitOps platform | https://localhost:8080 |
| `broker` | Identity federation | — |

*The `kubernetes` client enables Keycloak groups to map directly to Kubernetes RBAC ClusterRoleBindings.*

---

### ArgoCD — GitOps Applications (Page 1/5)

![ArgoCD Applications Page 1](screenshots/04-argocd-applications-p1.png)

*ArgoCD managing the full platform via GitOps. All applications sync from `https://github.com/Z3ROX-lab/ai-security-platform`. Visible: `cert-manager`, `cert-manager-config`, `cnpg-operator`, `coredns-config`, `falco`, `guardrails-api`.*

---

### ArgoCD — GitOps Applications (Page 2/5)

![ArgoCD Applications Page 2](screenshots/05-argocd-applications-p2.png)

*`keycloak` (Progressing/Synced), `keycloak-rbac` (Healthy/Synced), `kube-prometheus-stack` (Degraded/Synced), `kyverno` (Healthy/OutOfSync — Helm chart drift).*

---

### ArgoCD — GitOps Applications (Page 3/5)

![ArgoCD Applications Page 3](screenshots/06-argocd-applications-p3.png)

*`kyverno-policies`, `loki`, `ollama` (Healthy/Synced), `open-webui` (Progressing/OutOfSync — PVC resize conflict), `openwebui-db-init`, `postgresql` (Healthy/Synced).*

---

### ArgoCD — GitOps Applications (Page 4/5)

![ArgoCD Applications Page 4](screenshots/07-argocd-applications-p4.png)

*`promtail`, `qdrant` (Healthy/OutOfSync — Helm drift), `rag-api` (Healthy/Synced), `root-app` (Healthy/OutOfSync — App of Apps pattern).*

---

### ArgoCD — GitOps Applications (Page 5/5)

![ArgoCD Applications Page 5](screenshots/08-argocd-applications-p5.png)

*`sealed-secrets`, `seaweedfs`, `security-baseline` (NetworkPolicies + PSS), `traefik`, `trivy-operator` — all Healthy/Synced.*

**Total: 25 applications** managed via GitOps — **21 Healthy/Synced**, 4 with minor drift.

---

### Prometheus — Alerting Rules

![Prometheus Alerts](screenshots/09-prometheus-alerts.png)

*Prometheus alerting rules for `alertmanager.rules` — all **8 rules INACTIVE** confirming a healthy cluster state. Rules configured: `AlertmanagerFailedReload`, `AlertmanagerMembersInconsistent`, `AlertmanagerClusterDown`, `AlertmanagerClusterCrashlooping`, etc.*

---

## Summary

| Component | Status | Version |
|-----------|--------|---------|
| K3d (K3s) | ✅ Running | v1.29.0 |
| ArgoCD | ✅ Running | v3.2.6 |
| Keycloak | ✅ Running | 26.5.1 |
| Open WebUI | ✅ Running | 0.6.7 |
| Ollama + Mistral 7B | ✅ Running | 0.3.4 |
| LLM Guard Pipeline | ✅ Running | v3.0 hybrid |
| RAG API + Qdrant | ✅ Running | 2.0.0 |
| Guardrails API | ✅ Running | — |
| Falco | ✅ Running | 4.18.0 |
| Kyverno | ✅ Running (Audit) | 3.3.4 |
| Trivy Operator | ✅ Running | 0.24.1 |
| Prometheus + Grafana | ✅ Running | 67.4.0 |
| Loki + Promtail | ✅ Running | 6.23.0 |
| Traefik | ✅ Running | 38.0.0 |
| cert-manager | ✅ Running | v1.17.2 |
| Sealed Secrets | ✅ Running | 2.14.2 |
| CNPG (PostgreSQL) | ✅ Running | 0.27.0 |
| SeaweedFS | ✅ Running | 4.0.407 |

---

*Generated: March 2026 — AI Security Platform Phase 8*
