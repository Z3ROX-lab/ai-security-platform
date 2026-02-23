#!/bin/bash
###############################################################################
# Scenario 5: Runtime Security
# Tests: Falco shell detection + Kyverno policy enforcement
###############################################################################

source "$(dirname "${BASH_SOURCE[0]}")/demo-common.sh"

RUN_DIR="${1:-.}"
SCENARIO_DIR="$RUN_DIR/05-runtime"
mkdir -p "$SCENARIO_DIR"

header "🟪 Scenario 5: Runtime Security"

# =========================================================================
# PART A: Falco — Runtime Threat Detection
# =========================================================================

step "1" "Triggering Falco — shell exec into Ollama pod"
OLLAMA_POD=$(get_pod "ai-inference" "ollama")
info "Exec into: $OLLAMA_POD"

kubectl exec -n ai-inference "$OLLAMA_POD" -- sh -c "echo 'Falco trigger test' && whoami && id" \
    > "$SCENARIO_DIR/exec-output.log" 2>&1
cat "$SCENARIO_DIR/exec-output.log"
pass "Shell exec completed — Falco alert triggered"

# --- Test 2: Check Falco logs ---
step "2" "Checking Falco alerts (waiting 10s for propagation)"
sleep 10

kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=100 2>&1 | \
    grep -i "shell\|exec\|terminal\|ai-inference\|ollama\|Notice\|Warning" | \
    tail -20 > "$SCENARIO_DIR/falco-alerts.log" 2>&1

ALERT_COUNT=$(wc -l < "$SCENARIO_DIR/falco-alerts.log")
if [[ $ALERT_COUNT -gt 0 ]]; then
    pass "Falco detected $ALERT_COUNT alert(s)"
    head -5 "$SCENARIO_DIR/falco-alerts.log"
else
    warn "No Falco alerts found in pod logs — check Grafana/Loki"
fi

# --- Test 3: Falco via Grafana/Loki ---
step "3" "Falco alerts in Grafana"
info "Open: $GRAFANA_URL"
info "Go to: Explore → Loki"
info "Query:"
echo ""
echo "    {namespace=\"falco\"} |= \"ai-inference\""
echo "    {app=\"falco\"} |= \"shell\""
echo ""
info "You should see shell spawn alerts for the Ollama container"

# --- Test 4: Second trigger — exec into pipelines pod ---
step "4" "Triggering Falco — exec into Pipelines pod"
PIPELINE_POD=$(get_pod "ai-apps" "pipelines")
info "Exec into: $PIPELINE_POD"

kubectl exec -n ai-apps "$PIPELINE_POD" -- sh -c "cat /etc/passwd | head -3" \
    > "$SCENARIO_DIR/exec-pipelines.log" 2>&1
cat "$SCENARIO_DIR/exec-pipelines.log"
pass "Sensitive file read — Falco should detect"

# =========================================================================
# PART B: Kyverno — Policy Enforcement
# =========================================================================

step "5" "Testing Kyverno — deploy privileged pod"
info "Kyverno is in AUDIT mode — pod will be created but violation logged"

cat > /tmp/privileged-test.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: test-privileged-demo
  namespace: ai-inference
  labels:
    test: kyverno-demo
spec:
  containers:
  - name: test
    image: busybox:latest
    command: ["sleep", "30"]
    securityContext:
      privileged: true
EOF

kubectl apply -f /tmp/privileged-test.yaml > "$SCENARIO_DIR/privileged-apply.log" 2>&1 || true
cat "$SCENARIO_DIR/privileged-apply.log"

# --- Test 6: Kyverno policy reports ---
step "6" "Checking Kyverno policy reports"
sleep 5

# Policy reports
kubectl get policyreport -A -o wide 2>&1 | tee "$SCENARIO_DIR/kyverno-policyreports.log"

# Look for violations
kubectl get policyreport -n ai-inference -o json 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
count=0
for item in d.get('items',[]):
    for r in item.get('results',[]):
        if r.get('result') in ['fail','warn']:
            count+=1
            print(f'  ⚠️  {r.get(\"policy\",\"?\")}: {r.get(\"message\",\"?\")[:100]}')
if count == 0:
    print('  No violations found in policy reports')
else:
    print(f'\n  Total violations: {count}')
" 2>/dev/null | tee "$SCENARIO_DIR/kyverno-violations.log"

# Events
kubectl get events -n ai-inference --sort-by='.lastTimestamp' 2>/dev/null | \
    grep -i "kyver\|policy\|violat" | tail -10 > "$SCENARIO_DIR/kyverno-events.log" 2>&1

# --- Test 7: Cleanup ---
step "7" "Cleanup"
kubectl delete pod test-privileged-demo -n ai-inference --ignore-not-found > /dev/null 2>&1
pass "Test pod cleaned up"

# --- Screenshots ---
screenshot_prompt "Grafana — Falco alerts dashboard" "$GRAFANA_URL"
screenshot_prompt "Grafana — Loki query for Falco events" "$GRAFANA_URL"
screenshot_prompt "Kyverno policy violations" "Terminal"

# Save full logs
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=100 > "$SCENARIO_DIR/falco-full.log" 2>&1

result "Scenario 5 Complete" "$SCENARIO_DIR"
