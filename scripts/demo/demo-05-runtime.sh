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

step "1" "Triggering Falco alert — shell exec into AI pod"
info "Executing shell in Ollama container (Falco should detect this)..."

# Exec into ollama pod to trigger Falco alert
OLLAMA_POD=$(get_pod "ai-inference" "ollama")
kubectl exec -n ai-inference "$OLLAMA_POD" -- sh -c "echo 'Falco trigger test' && whoami && id" \
    > "$SCENARIO_DIR/exec-output.log" 2>&1

pass "Shell exec completed — Falco should have logged an alert"

# --- Test 2: Check Falco logs ---
step "2" "Checking Falco alerts"
info "Waiting 10s for alert propagation..."
sleep 10

# Get Falco logs with shell alerts
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=50 2>&1 | \
    grep -i "shell\|exec\|ai-inference\|ollama\|Notice\|Warning" | \
    tail -20 > "$SCENARIO_DIR/falco-alerts.log" 2>&1

ALERT_COUNT=$(wc -l < "$SCENARIO_DIR/falco-alerts.log")
if [[ $ALERT_COUNT -gt 0 ]]; then
    pass "Falco detected $ALERT_COUNT alerts"
    head -5 "$SCENARIO_DIR/falco-alerts.log"
else
    warn "No Falco alerts found — check Falco rules"
fi

# --- Test 3: Falco alerts in Loki/Grafana ---
step "3" "Falco alerts in Grafana"
info "Open Grafana: https://grafana.ai-platform.localhost"
info "Go to Explore → Loki"
info "Query: {namespace=\"falco\"} |= \"shell\" or {namespace=\"falco\"} |= \"ai-inference\""
info "You should see the shell spawn alert for the Ollama container"

# --- Test 4: Suspicious model access ---
step "4" "Triggering Falco — suspicious model file access"
kubectl exec -n ai-inference "$OLLAMA_POD" -- sh -c \
    "ls /root/.ollama/models/ 2>/dev/null || echo 'Models dir not accessible'" \
    > "$SCENARIO_DIR/model-access.log" 2>&1

info "Model access attempt logged — check Falco for 'Suspicious Access to Model Files'"

# =========================================================================
# PART B: Kyverno — Policy Enforcement
# =========================================================================

step "5" "Testing Kyverno — deploy privileged pod (should be AUDITED)"

# Create a privileged pod spec
cat > /tmp/privileged-test.yaml << 'PRIV'
apiVersion: v1
kind: Pod
metadata:
  name: test-privileged
  namespace: ai-inference
  labels:
    test: kyverno-demo
spec:
  containers:
  - name: test
    image: busybox
    command: ["sleep", "10"]
    securityContext:
      privileged: true
      runAsRoot: true
PRIV

# Apply (should be audited by Kyverno, not blocked since in Audit mode)
kubectl apply -f /tmp/privileged-test.yaml > "$SCENARIO_DIR/privileged-apply.log" 2>&1 || true
cat "$SCENARIO_DIR/privileged-apply.log"

# --- Test 6: Check Kyverno policy reports ---
step "6" "Checking Kyverno policy violations"
sleep 5

# Get policy reports
kubectl get policyreport -n ai-inference -o yaml > "$SCENARIO_DIR/kyverno-policyreport.yaml" 2>&1
kubectl get clusterpolicyreport -o yaml > "$SCENARIO_DIR/kyverno-clusterpolicyreport.yaml" 2>&1

# Check for violations
VIOLATIONS=$(kubectl get policyreport -n ai-inference -o json 2>/dev/null | \
    python3 -c "
import sys,json
d=json.load(sys.stdin)
count=0
for item in d.get('items',[]):
    for r in item.get('results',[]):
        if r.get('result') in ['fail','warn']:
            count+=1
            print(f'  {r.get(\"policy\",\"?\")}: {r.get(\"message\",\"?\")[:80]}')
print(f'Total violations: {count}')
" 2>/dev/null)

echo "$VIOLATIONS" | tee "$SCENARIO_DIR/kyverno-violations.log"

# Get events
kubectl get events -n ai-inference --field-selector reason=PolicyViolation --sort-by='.lastTimestamp' 2>/dev/null | \
    tail -10 > "$SCENARIO_DIR/kyverno-events.log" 2>&1

# --- Test 7: Cleanup ---
step "7" "Cleanup test pod"
kubectl delete pod test-privileged -n ai-inference --ignore-not-found > /dev/null 2>&1
pass "Test pod cleaned up"

# --- Screenshots ---
screenshot_prompt "Grafana — Falco alerts (shell in AI container)" "https://grafana.ai-platform.localhost"
screenshot_prompt "Grafana — Loki query for Falco" "https://grafana.ai-platform.localhost"
screenshot_prompt "Kyverno policy violations" "Terminal"

# Save full Falco logs
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=100 > "$SCENARIO_DIR/falco-full.log" 2>&1

result "Scenario 5 Complete" "$SCENARIO_DIR"
