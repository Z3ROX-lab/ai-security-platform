#!/bin/bash
###############################################################################
# Scenario 6: Compliance & Auth
# Tests: Keycloak OIDC, Trivy vulnerability scans, Prometheus/Alertmanager
###############################################################################

source "$(dirname "${BASH_SOURCE[0]}")/demo-common.sh"

RUN_DIR="${1:-.}"
SCENARIO_DIR="$RUN_DIR/06-compliance"
mkdir -p "$SCENARIO_DIR"

header "🔵 Scenario 6: Compliance & Auth"

# =========================================================================
# PART A: Keycloak OIDC
# =========================================================================

step "1" "Keycloak — OIDC login flow"
info "Keycloak admin: https://auth.ai-platform.localhost"

# Check Keycloak health
KC_STATUS=$(kubectl exec -n auth deploy/keycloak-keycloakx -- \
    curl -sk https://localhost:8443/health/ready 2>&1 || echo '{"status":"unknown"}')
echo "$KC_STATUS" > "$SCENARIO_DIR/keycloak-health.json"

if echo "$KC_STATUS" | grep -qi "UP\|ready"; then
    pass "Keycloak is healthy"
else
    warn "Keycloak health check inconclusive"
fi

# Get realm info
step "2" "Keycloak — realm & client configuration"
info "Demonstrate in Keycloak admin console:"
info "  1. Open https://auth.ai-platform.localhost/admin"
info "  2. Show 'ai-platform' realm"
info "  3. Show 'open-webui' client configuration"
info "  4. Show OIDC endpoints"
info "  5. Show user management"

# Get OIDC config
OIDC_CONFIG=$(kubectl exec -n auth deploy/keycloak-keycloakx -- \
    curl -sk https://localhost:8443/realms/ai-platform/.well-known/openid-configuration 2>&1 || echo "{}")
echo "$OIDC_CONFIG" | python3 -m json.tool > "$SCENARIO_DIR/oidc-config.json" 2>&1

if echo "$OIDC_CONFIG" | grep -q "authorization_endpoint"; then
    pass "OIDC configuration available"
    info "Issuer: $(echo "$OIDC_CONFIG" | python3 -c "import sys,json; print(json.load(sys.stdin).get('issuer','N/A'))" 2>/dev/null)"
else
    warn "OIDC config not available — check Keycloak realm"
fi

# =========================================================================
# PART B: Trivy — Vulnerability Scanning
# =========================================================================

step "3" "Trivy — scanning AI container images"

# Check Trivy operator
TRIVY_STATUS=$(kubectl get deploy -n trivy-system trivy-operator -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ "$TRIVY_STATUS" == "1" ]]; then
    pass "Trivy Operator is running"
else
    warn "Trivy Operator status: $TRIVY_STATUS"
fi

# Get vulnerability reports for AI namespaces
step "4" "Trivy — vulnerability reports"

for ns in ai-inference ai-apps; do
    echo -e "\n  ${CYAN}Namespace: $ns${NC}"
    kubectl get vulnerabilityreports -n "$ns" -o custom-columns=\
'IMAGE:.report.registry.server/.report.artifact.repository,CRITICAL:.report.summary.criticalCount,HIGH:.report.summary.highCount,MEDIUM:.report.summary.mediumCount,LOW:.report.summary.lowCount' \
    2>/dev/null | tee -a "$SCENARIO_DIR/trivy-vulns-$ns.log" || echo "  No reports yet"
done

# Detailed report for Ollama
step "5" "Trivy — detailed Ollama image scan"
kubectl get vulnerabilityreports -n ai-inference -o json 2>/dev/null | \
    python3 -c "
import sys,json
d=json.load(sys.stdin)
for item in d.get('items',[]):
    repo = item.get('report',{}).get('artifact',{}).get('repository','unknown')
    summary = item.get('report',{}).get('summary',{})
    print(f'Image: {repo}')
    print(f'  Critical: {summary.get(\"criticalCount\",0)}')
    print(f'  High:     {summary.get(\"highCount\",0)}')
    print(f'  Medium:   {summary.get(\"mediumCount\",0)}')
    print(f'  Low:      {summary.get(\"lowCount\",0)}')
    print()
" 2>/dev/null | tee "$SCENARIO_DIR/trivy-detailed.log"

# =========================================================================
# PART C: Prometheus & Alertmanager
# =========================================================================

step "6" "Prometheus — targets & alerts"
info "Prometheus: https://prometheus.ai-platform.localhost"

# Check Prometheus targets
PROM_TARGETS=$(kubectl exec -n observability prometheus-kube-prometheus-stack-prometheus-0 -- \
    wget -q -O- http://localhost:9090/api/v1/targets 2>&1 | \
    python3 -c "
import sys,json
d=json.load(sys.stdin)
active = [t for t in d.get('data',{}).get('activeTargets',[]) if t.get('health')=='up']
total = len(d.get('data',{}).get('activeTargets',[]))
print(f'Targets: {len(active)}/{total} UP')
for t in active[:10]:
    print(f'  ✓ {t.get(\"labels\",{}).get(\"job\",\"?\")}')
" 2>/dev/null)

echo "$PROM_TARGETS" | tee "$SCENARIO_DIR/prometheus-targets.log"

# Check alerts
step "7" "Prometheus — active alerts"
PROM_ALERTS=$(kubectl exec -n observability prometheus-kube-prometheus-stack-prometheus-0 -- \
    wget -q -O- http://localhost:9090/api/v1/alerts 2>&1 | \
    python3 -c "
import sys,json
d=json.load(sys.stdin)
alerts = d.get('data',{}).get('alerts',[])
firing = [a for a in alerts if a.get('state')=='firing']
print(f'Total alerts: {len(alerts)}, Firing: {len(firing)}')
for a in firing[:10]:
    name = a.get('labels',{}).get('alertname','?')
    severity = a.get('labels',{}).get('severity','?')
    print(f'  🔴 {name} ({severity})')
" 2>/dev/null)

echo "$PROM_ALERTS" | tee "$SCENARIO_DIR/prometheus-alerts.log"

# Alertmanager
step "8" "Alertmanager — status"
info "Alertmanager: https://alertmanager.ai-platform.localhost"

AM_STATUS=$(kubectl exec -n observability alertmanager-kube-prometheus-stack-alertmanager-0 -- \
    wget -q -O- http://localhost:9093/api/v2/status 2>&1 | \
    python3 -c "
import sys,json
d=json.load(sys.stdin)
print(f'Cluster status: {d.get(\"cluster\",{}).get(\"status\",\"?\")}')
print(f'Uptime: {d.get(\"uptime\",\"?\")}')
" 2>/dev/null)

echo "$AM_STATUS" | tee "$SCENARIO_DIR/alertmanager-status.log"

# --- Screenshots ---
screenshot_prompt "Keycloak — SSO login page" "https://auth.ai-platform.localhost"
screenshot_prompt "Keycloak — admin console (realm, clients)" "https://auth.ai-platform.localhost/admin"
screenshot_prompt "Trivy — vulnerability reports" "Terminal"
screenshot_prompt "Prometheus — targets" "https://prometheus.ai-platform.localhost/targets"
screenshot_prompt "Prometheus — alerts" "https://prometheus.ai-platform.localhost/alerts"
screenshot_prompt "Alertmanager" "https://alertmanager.ai-platform.localhost"

result "Scenario 6 Complete" "$SCENARIO_DIR"
