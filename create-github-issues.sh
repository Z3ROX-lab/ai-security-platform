#!/bin/bash
# Script to create GitHub issues for AI Security Platform
# Requires: gh cli (https://cli.github.com/)
# Usage: ./create-github-issues.sh

set -e

REPO="Z3ROX-lab/ai-security-platform"

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) not installed. Install with:"
    echo "   sudo apt install gh  # Ubuntu"
    echo "   brew install gh      # Mac"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated. Run: gh auth login"
    exit 1
fi

echo "🚀 Creating GitHub issues for $REPO..."
echo ""

# Function to create issue
create_issue() {
    local title="$1"
    local body="$2"
    local labels="$3"
    
    echo "📝 Creating: $title"
    gh issue create --repo "$REPO" --title "$title" --body "$body" --label "$labels" || echo "⚠️ Failed to create: $title"
    sleep 1  # Rate limiting
}

# =============================================================================
# Create Labels first
# =============================================================================
echo "🏷️ Creating labels..."

gh label create "priority:high" --repo "$REPO" --color "d73a4a" --description "High priority" 2>/dev/null || true
gh label create "priority:medium" --repo "$REPO" --color "fbca04" --description "Medium priority" 2>/dev/null || true
gh label create "priority:low" --repo "$REPO" --color "0e8a16" --description "Low priority" 2>/dev/null || true
gh label create "owasp" --repo "$REPO" --color "d93f0b" --description "OWASP LLM Top 10" 2>/dev/null || true
gh label create "observability" --repo "$REPO" --color "1d76db" --description "Monitoring and observability" 2>/dev/null || true
gh label create "mlops" --repo "$REPO" --color "5319e7" --description "MLOps features" 2>/dev/null || true
gh label create "auth" --repo "$REPO" --color "0052cc" --description "Authentication and authorization" 2>/dev/null || true
gh label create "security" --repo "$REPO" --color "b60205" --description "Security improvements" 2>/dev/null || true
gh label create "supply-chain" --repo "$REPO" --color "c2e0c6" --description "Supply chain security" 2>/dev/null || true
gh label create "technical-debt" --repo "$REPO" --color "fef2c0" --description "Technical debt cleanup" 2>/dev/null || true
gh label create "known-limitation" --repo "$REPO" --color "e4e669" --description "Known limitation" 2>/dev/null || true
gh label create "network" --repo "$REPO" --color "006b75" --description "Networking" 2>/dev/null || true

echo ""
echo "📋 Creating issues..."
echo ""

# =============================================================================
# ENHANCEMENTS
# =============================================================================

create_issue \
    "Add Langfuse LLM Observability" \
    "## Description
Add Langfuse v3 for LLM-specific observability (traces, tokens, latency, costs).

## Tasks
- [ ] Deploy Langfuse via Helm chart
- [ ] Configure external PostgreSQL (CNPG)
- [ ] Configure external S3 (SeaweedFS)
- [ ] Deploy ClickHouse + Redis (via chart)
- [ ] Integrate with Open WebUI
- [ ] Add Ingress with TLS
- [ ] Create documentation

## References
- ADR-016 Observability Strategy
- https://langfuse.com/docs" \
    "enhancement,observability,priority:high"

create_issue \
    "Add MLflow for MLOps (Phase 9)" \
    "## Description
Implement Phase 9 with MLflow for experiment tracking and model registry.

## Tasks
- [ ] Deploy MLflow Tracking Server via Helm
- [ ] Connect to PostgreSQL backend (existing CNPG)
- [ ] Connect to SeaweedFS S3 for artifacts
- [ ] Configure Ingress with TLS
- [ ] Create demo notebook
- [ ] Documentation

## Estimated effort
~2-3 hours (dependencies already exist)" \
    "enhancement,mlops,priority:medium"

create_issue \
    "Configure Grafana with Keycloak OIDC" \
    "## Description
Currently Grafana uses local admin/password. Should use Keycloak SSO like Open WebUI.

## Tasks
- [ ] Create Grafana client in Keycloak realm
- [ ] Configure OIDC in Grafana values.yaml
- [ ] Map Keycloak roles to Grafana roles (Admin, Editor, Viewer)
- [ ] Test SSO login
- [ ] Update documentation

## Current state
- Grafana: admin / admin123!
- Should be: Keycloak SSO" \
    "enhancement,auth,priority:medium"

create_issue \
    "Configure ArgoCD with Keycloak OIDC" \
    "## Description
ArgoCD uses local admin secret. Should integrate with Keycloak for centralized authentication.

## Tasks
- [ ] Create ArgoCD client in Keycloak realm
- [ ] Configure OIDC in argocd-cm ConfigMap
- [ ] Map Keycloak groups to ArgoCD RBAC
- [ ] Test SSO login
- [ ] Update documentation" \
    "enhancement,auth,priority:medium"

create_issue \
    "Add NeMo Guardrails for OWASP LLM08 (Excessive Agency)" \
    "## Description
Implement NeMo Guardrails for 'Excessive Agency' protection (OWASP LLM08).

## Current OWASP coverage
- LLM01-07: ✅ Covered
- LLM08: ❌ Not covered
- LLM09-10: ✅ Covered

## Tasks
- [ ] Deploy NeMo Guardrails
- [ ] Configure action rails (limit what LLM can do)
- [ ] Integrate with existing guardrails pipeline
- [ ] Test and document" \
    "enhancement,security,owasp"

create_issue \
    "Add Tempo for Distributed Tracing" \
    "## Description
Add Grafana Tempo for distributed tracing across services.

## Tasks
- [ ] Deploy Tempo via Helm chart
- [ ] Configure Grafana datasource
- [ ] Instrument applications with OpenTelemetry
- [ ] Create trace dashboards
- [ ] Document

## Priority
Low - nice to have for complete observability stack" \
    "enhancement,observability,priority:low"

create_issue \
    "Implement Cosign Image Signing in CI/CD" \
    "## Description
Activate Cosign image signing and Kyverno verification policies for supply chain security (OWASP LLM05).

## Tasks
- [ ] Generate Cosign key pair
- [ ] Create GitHub Actions workflow for image signing
- [ ] Store public key in cluster
- [ ] Activate Kyverno signature verification policies
- [ ] Document the process

## References
- Kyverno Cosign policies already created (inactive)
- cosign-kyverno-guide.md" \
    "enhancement,security,supply-chain"

create_issue \
    "Add custom Grafana dashboards for AI Platform" \
    "## Description
Create custom Grafana dashboards specific to AI/LLM workloads.

## Dashboards to create
- [ ] LLM Request Latency (Ollama response times)
- [ ] Guardrails Blocked Requests (prompt injections blocked)
- [ ] RAG Pipeline Performance (Qdrant queries)
- [ ] Token Usage (when Langfuse integrated)
- [ ] AI Platform Overview (combined view)" \
    "enhancement,observability"

create_issue \
    "Implement Alertmanager notifications (Slack/Email)" \
    "## Description
Configure Alertmanager to send notifications to external channels.

## Tasks
- [ ] Configure Slack webhook receiver
- [ ] Create alert routing rules
- [ ] Add custom alerts for AI components
- [ ] Test notification flow
- [ ] Document configuration

## Priority
Low - useful for production, not critical for demo" \
    "enhancement,observability,priority:low"

create_issue \
    "Enable Kubernetes OIDC authentication with Keycloak" \
    "## Description
Enable kubectl authentication via Keycloak OIDC. Manifests already prepared but not activated.

## Tasks
- [ ] Recreate K3d cluster with OIDC flags (Terraform prepared)
- [ ] Configure kubelogin plugin
- [ ] Test RBAC with Keycloak groups
- [ ] Update documentation

## References
- RBAC manifests in argocd/applications/auth/keycloak/rbac/
- Terraform OIDC config prepared" \
    "enhancement,auth,priority:low"

# =============================================================================
# BUGS / LIMITATIONS
# =============================================================================

create_issue \
    "Falco syscall detection limited in WSL2/K3d environment" \
    "## Description
Falco syscall detection doesn't work fully in WSL2/K3d due to eBPF restrictions.

## Symptoms
- Shell detection rules don't trigger
- Some syscall-based rules inactive

## Root cause
WSL2 kernel and K3d virtualization limit eBPF capabilities.

## Workaround
Falco will work properly on:
- Bare-metal Kubernetes
- Cloud Kubernetes (EKS, GKE, AKS)
- VMs with full kernel access

## Status
Won't fix - environment limitation, not a bug" \
    "known-limitation"

create_issue \
    "Self-signed certificates require browser exception" \
    "## Description
All services use self-signed certificates from internal CA. Browsers require manual security exception.

## Affected URLs
- All *.ai-platform.localhost URLs

## Solutions
- [ ] Document how to import CA certificate into browser/system
- [ ] Or use Let's Encrypt for public demo (requires real domain)

## Current workaround
Click 'Advanced' > 'Proceed' in browser warning" \
    "known-limitation,documentation"

# =============================================================================
# DOCUMENTATION
# =============================================================================

create_issue \
    "Export architecture diagram as PNG for README" \
    "## Description
The Mermaid diagram in ARCHITECTURE.md may not render correctly in all contexts. Add PNG export.

## Tasks
- [ ] Open docs/diagrams/ai-security-platform-architecture.drawio
- [ ] Export as PNG (high resolution)
- [ ] Save to docs/diagrams/architecture.png
- [ ] Update README to embed PNG image

## Tools
- draw.io desktop or https://app.diagrams.net" \
    "documentation,priority:high"

create_issue \
    "Create video demo for YouTube/Portfolio" \
    "## Description
Create a video demonstration of the platform for portfolio presentation.

## Suggested sections
1. [ ] Architecture overview (2 min)
2. [ ] GitOps deployment with ArgoCD (2 min)
3. [ ] Keycloak SSO login flow (1 min)
4. [ ] Chat with LLM via Open WebUI (2 min)
5. [ ] Prompt injection blocked by guardrails (2 min)
6. [ ] Monitoring with Grafana/Prometheus (2 min)
7. [ ] Kyverno policy enforcement demo (1 min)
8. [ ] Conclusion and architecture recap (1 min)

## Total: ~15 minutes" \
    "documentation,priority:medium"

create_issue \
    "Add comprehensive troubleshooting guide" \
    "## Description
Create troubleshooting guide based on issues encountered during development.

## Sections to cover
- [ ] K3d network issues after laptop reboot
- [ ] Pod OOMKilled solutions
- [ ] DNS resolution problems (CoreDNS)
- [ ] Certificate issues (cert-manager)
- [ ] ArgoCD sync failures
- [ ] Keycloak SSO issues
- [ ] Qdrant API key problems" \
    "documentation"

create_issue \
    "Create single-page quick start guide" \
    "## Description
Create a quick start guide for someone cloning the repo for the first time.

## Content
- [ ] Prerequisites checklist (Docker, Terraform, kubectl, Helm)
- [ ] Clone and setup commands (one-liners)
- [ ] /etc/hosts configuration
- [ ] Verification steps
- [ ] First login instructions (ArgoCD, Keycloak, Open WebUI)
- [ ] Common issues and fixes" \
    "documentation,priority:high"

create_issue \
    "Document backup and restore procedures" \
    "## Description
Create user-facing documentation for backup/restore.

## Existing
- backup-restore.sh script exists

## Tasks
- [ ] Create docs/backup-restore.md
- [ ] Document what is backed up
- [ ] Add restore verification steps
- [ ] Test restore on fresh cluster
- [ ] Add to main README" \
    "documentation,priority:medium"

# =============================================================================
# SECURITY
# =============================================================================

create_issue \
    "Move hardcoded passwords to Sealed Secrets" \
    "## Description
Several components have passwords directly in values.yaml. Should use Sealed Secrets for security.

## Components to fix
- [ ] Grafana admin password (admin123!)
- [ ] Langfuse secrets (salt, nextauth, encryption)
- [ ] ClickHouse password
- [ ] Redis password
- [ ] Qdrant API key

## Process
1. Create Kubernetes Secret
2. Seal with kubeseal
3. Reference in values.yaml via existingSecret" \
    "security,technical-debt,priority:high"

create_issue \
    "Enable Kyverno policies in Enforce mode" \
    "## Description
Most Kyverno policies are in Audit mode. Evaluate and enable Enforce for production readiness.

## Current state
| Policy | Mode |
|--------|------|
| disallow-privileged-containers | Enforce ✅ |
| require-resource-limits | Audit |
| require-non-root | Audit |
| disallow-latest-tag | Audit |
| require-probes | Audit |

## Tasks
- [ ] Review impact of each policy
- [ ] Enable Enforce mode progressively
- [ ] Document exceptions if needed" \
    "security,priority:medium"

create_issue \
    "Add OWASP LLM09 (Overreliance) mitigation" \
    "## Description
Add disclaimer in LLM responses about AI limitations (OWASP LLM09).

## Options
1. Configure system prompt in Open WebUI
2. Add pipeline filter to append disclaimer
3. Both

## Tasks
- [ ] Choose approach
- [ ] Implement
- [ ] Document" \
    "security,owasp,priority:low"

create_issue \
    "Add NetworkPolicies for Langfuse namespace" \
    "## Description
When Langfuse is deployed, add NetworkPolicies for isolation.

## Policies needed
- [ ] Default deny ingress
- [ ] Allow from Traefik (ingress)
- [ ] Allow to PostgreSQL
- [ ] Allow to SeaweedFS S3
- [ ] Allow internal (ClickHouse, Redis)" \
    "security,network"

# =============================================================================
# TECHNICAL DEBT
# =============================================================================

create_issue \
    "Optimize Ollama model loading time" \
    "## Description
Ollama loads model on first request, causing latency (~30s). Consider preloading.

## Options
1. Add init container to make dummy request
2. Use keep_alive setting to prevent unloading
3. Both

## Tasks
- [ ] Evaluate options
- [ ] Implement
- [ ] Measure improvement" \
    "technical-debt,priority:low"

create_issue \
    "Add ResourceQuota per namespace" \
    "## Description
Add ResourceQuota objects to limit total resources per namespace and prevent runaway consumption.

## Namespaces
- [ ] ai-inference (most critical - LLM)
- [ ] ai-apps
- [ ] observability
- [ ] langfuse" \
    "technical-debt,priority:low"

create_issue \
    "Evaluate migration to Cilium CNI" \
    "## Description
Currently using Flannel (K3d default). Cilium offers better network policies, observability, and eBPF features.

## Benefits
- L7 network policies
- Better observability (Hubble)
- Service mesh capabilities
- eBPF-based (no iptables)

## References
- ADR-013 CNI Strategy

## Priority
Low - Flannel works fine for home lab" \
    "enhancement,network,priority:low"

# =============================================================================
# MONITORING
# =============================================================================

create_issue \
    "Create PrometheusRules for AI components" \
    "## Description
Create custom alerting rules for AI-specific metrics.

## Alerts to create
- [ ] High guardrails block rate (>50% in 5min)
- [ ] LLM response latency > 30s
- [ ] Qdrant memory usage > 80%
- [ ] Ollama OOM risk (memory > 90%)
- [ ] RAG API errors > 10/min" \
    "observability,priority:medium"

create_issue \
    "Add ServiceMonitor for RAG API metrics" \
    "## Description
RAG API should expose Prometheus metrics and be scraped.

## Tasks
- [ ] Add /metrics endpoint to FastAPI (prometheus-fastapi-instrumentator)
- [ ] Create ServiceMonitor resource
- [ ] Add Grafana dashboard panel
- [ ] Document" \
    "observability"

=============================================================================
# DONE
# =============================================================================

echo ""
echo "✅ All issues created!"
echo ""
echo "View issues at: https://github.com/$REPO/issues"
