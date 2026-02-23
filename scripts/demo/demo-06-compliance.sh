#!/bin/bash
###############################################################################
# Scenario 6: Compliance & Auth
# Tests: Keycloak OIDC, Trivy scans, Prometheus/Alertmanager
###############################################################################

source "$(dirname "${BASH_SOURCE[0]}")/demo-common.sh"

RUN_DIR="${1:-.}"
SCENARIO_DIR="$RUN_DIR/06-compliance"
mkdir -p "$SCENARIO_DIR"

header "🔵 Scenario 6: Compliance & Auth"

# =========================================================================
# PART A: Keycloak OIDC
# =========================================================================

step "1" "Keycloak — health check"
KC_HEALTH=$($CURL "$KEYCLOAK_URL/realms/ai-platform" 2>&1)
echo "$KC_HEALTH" > "$SCENARIO_DIR/keycloak-health.json"

if echo "$KC_HEALTH" | grep -qi "UP\|ready\|ok"; then
    pass "Keycloak healthy at $KEYCLOAK_URL"
else
    warn "Keycloak health: $(echo "$KC_HEALTH" | head -1)"
fi

step "2" "Keycloak — OIDC discovery"
OIDC=$($CURL "$KEYCLOAK_URL/realms/ai-platform/.well-known/openid-configuration" 2>&1)
echo "$OIDC" | python3 -m json.tool > "$SCENARIO_DIR/oidc-config.json" 2>&1

if echo "$OIDC" | grep -q "authorization_endpoint"; then
    ISSUER=$(echo "$OIDC" | python3 -c "import sys,json; print(json.load(sys.stdin).get('issuer','N/A'))" 2>/dev/null)
    pass "OIDC discovery OK — Issuer: $ISSUER"
else
    warn "OIDC config not available — check realm name"
fi

step "3" "Keycloak — admin console"
info "Open: $KEYCLOAK_URL/admin"
info "Show:"
info "  1. 'ai-platform' realm"
info "  2. 'open-webui' client (OIDC settings)"
info "  3. Users and role mappings"
info "  4. Authentication flows"

# =========================================================================
# PART B: Trivy — Vulnerability Scanning
# =========================================================================

step "4" "Trivy Operator status"
TRIVY_READY=$(kubectl get deploy -n trivy-system trivy-operator -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ "$TRIVY_READY" == "1" ]]; then
    pass "Trivy Operator running"
else
    warn "Trivy Operator replicas: $TRIVY_READY"
fi

step "5" "Trivy — vulnerability reports (AI namespaces)"

for ns in ai-inference ai-apps; do
    echo ""
    echo -e "  ${CYAN}━━ Namespace: $ns ━━${NC}"
    kubectl get vulnerabilityreports -n "$ns" -o custom-columns=\
'IMAGE:.report.artifact.repository,TAG:.report.artifact.tag,CRITICAL:.report.summary.criticalCount,HIGH:.report.summary.highCount,MEDIUM:.report.summary.mediumCount,LOW:.report.summary.lowCount' \
    2>/dev/null | tee -a "$SCENARIO_DIR/trivy-$ns.log" || echo "  No vulnerability reports yet"
done

step "6" "Trivy — detailed summary"
kubectl get vulnerabilityreports -A -o json 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
total_c=total_h=total_m=total_l=0
for item in d.get('items',[]):
    ns = item.get('metadata',{}).get('namespace','?')
    repo = item.get('report',{}).get('artifact',{}).get('repository','?')
    tag = item.get('report',{}).get('artifact',{}).get('tag','?')
    s = item.get('report',{}).get('summary',{})
    c,h,m,l = s.get('criticalCount',0), s.get('highCount',0), s.get('mediumCount',0), s.get('lowCount',0)
    total_c+=c; total_h+=h; total_m+=m; total_l+=l
    if c > 0 or h > 0:
        print(f'  ⚠️  {ns}/{repo}:{tag} — C:{c} H:{h} M:{m} L:{l}')
print(f'\n  TOTAL: Critical={total_c} High={total_h} Medium={total_m} Low={total_l}')
" 2>/dev/null | tee "$SCENARIO_DIR/trivy-summary.log"

# =========================================================================
# PART C: Prometheus & Alertmanager
# =========================================================================

step "7" "Prometheus — targets"
TARGETS=$($CURL "$PROMETHEUS_URL/api/v1/targets" 2>&1)
echo "$TARGETS" | python3 -c "
import sys,json
d=json.load(sys.stdin)
targets = d.get('data',{}).get('activeTargets',[])
up = [t for t in targets if t.get('health')=='up']
print(f'  Targets: {len(up)}/{len(targets)} UP')
for t in up[:15]:
    job = t.get('labels',{}).get('job','?')
    print(f'    ✓ {job}')
if len(up) > 15:
    print(f'    ... and {len(up)-15} more')
" 2>/dev/null | tee "$SCENARIO_DIR/prometheus-targets.log"

step "8" "Prometheus — firing alerts"
ALERTS=$($CURL "$PROMETHEUS_URL/api/v1/alerts" 2>&1)
echo "$ALERTS" | python3 -c "
import sys,json
d=json.load(sys.stdin)
alerts = d.get('data',{}).get('alerts',[])
firing = [a for a in alerts if a.get('state')=='firing']
print(f'  Total rules: {len(alerts)}, Firing: {len(firing)}')
for a in firing[:10]:
    name = a.get('labels',{}).get('alertname','?')
    sev = a.get('labels',{}).get('severity','?')
    print(f'    🔴 {name} ({sev})')
if not firing:
    print('    ✅ No firing alerts')
" 2>/dev/null | tee "$SCENARIO_DIR/prometheus-alerts.log"

step "9" "Alertmanager — status"
AM=$($CURL "$ALERTMANAGER_URL/api/v2/status" 2>&1)
echo "$AM" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(f'  Cluster: {d.get(\"cluster\",{}).get(\"status\",\"?\")}')
print(f'  Uptime:  {d.get(\"uptime\",\"?\")}')
print(f'  Version: {d.get(\"versionInfo\",{}).get(\"version\",\"?\")}')
" 2>/dev/null | tee "$SCENARIO_DIR/alertmanager-status.log"

# --- Screenshots ---
screenshot_prompt "Keycloak — SSO login page" "$KEYCLOAK_URL"
screenshot_prompt "Keycloak — admin console" "$KEYCLOAK_URL/admin"
screenshot_prompt "Trivy — vulnerability reports" "Terminal"
screenshot_prompt "Prometheus — targets" "$PROMETHEUS_URL/targets"
screenshot_prompt "Prometheus — alerts" "$PROMETHEUS_URL/alerts"
screenshot_prompt "Alertmanager" "$ALERTMANAGER_URL"

result "Scenario 6 Complete" "$SCENARIO_DIR"
