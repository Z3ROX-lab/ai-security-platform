#!/bin/bash
###############################################################################
# Scenario 1: AI Chat Normal
# Tests: Open WebUI → LLM Guard (PASS) → Ollama Mistral → response
###############################################################################

source "$(dirname "${BASH_SOURCE[0]}")/demo-common.sh"

RUN_DIR="${1:-.}"
SCENARIO_DIR="$RUN_DIR/01-chat"
mkdir -p "$SCENARIO_DIR"

header "🟦 Scenario 1: AI Chat Normal"

# --- Test 1: Pipeline health ---
step "1" "Checking LLM Guard pipeline health"
PIPELINE_LOG=$(kubectl logs -n ai-apps deploy/open-webui-pipelines --tail=10 2>&1)
echo "$PIPELINE_LOG" > "$SCENARIO_DIR/pipeline-status.log"

if echo "$PIPELINE_LOG" | grep -q "LLM Guard"; then
    pass "LLM Guard pipeline loaded"
else
    warn "LLM Guard pipeline may not be loaded"
fi

# --- Test 2: Guardrails API health ---
step "2" "Testing Guardrails API via Traefik"
GR_HEALTH=$($CURL "$GUARDRAILS_URL/health" 2>&1)
echo "$GR_HEALTH" > "$SCENARIO_DIR/guardrails-health.json"

if echo "$GR_HEALTH" | grep -qi "healthy\|ok\|true"; then
    pass "Guardrails API healthy at $GUARDRAILS_URL"
else
    warn "Guardrails API health: $GR_HEALTH"
fi

# --- Test 3: Normal prompt scan (should PASS) ---
step "3" "Scanning normal prompt via Guardrails API"
SCAN_RESULT=$($CURL "$GUARDRAILS_URL/scan/input" \
    -H "Content-Type: application/json" \
    -d '{"prompt":"What are the main security principles for AI systems in production?"}' 2>&1)
echo "$SCAN_RESULT" | python3 -m json.tool > "$SCENARIO_DIR/normal-scan.json" 2>&1
cat "$SCENARIO_DIR/normal-scan.json"

if echo "$SCAN_RESULT" | python3 -c "import sys,json; exit(0 if json.load(sys.stdin).get('is_valid') else 1)" 2>/dev/null; then
    pass "Normal prompt PASSED all scanners"
else
    fail "Normal prompt incorrectly blocked"
fi

# --- Test 4: Open WebUI chat ---
step "4" "Testing chat via Open WebUI"
info "Open: $OPENWEBUI_URL"
info "Send this prompt:"
echo ""
echo -e "    ${BOLD}What are the main security principles for AI systems in production?${NC}"
echo ""
info "Verify: response streams word by word"

# --- Test 5: Pipeline logs ---
step "5" "Pipeline logs (confirm PASS)"
info "In another terminal:"
echo ""
echo "    kubectl logs -n ai-apps deploy/open-webui-pipelines -f"
echo ""
info "Expected: [LLM Guard] User: admin, No injection keywords - PASS"

# --- Test 6: Grafana metrics ---
step "6" "Grafana — Ollama metrics"
info "Open: $GRAFANA_URL"
info "Check: Ollama CPU/Memory, request latency"

# --- Test 7: Resource usage ---
step "7" "Cluster resource usage"
kubectl top pods -n ai-inference 2>&1 | tee "$SCENARIO_DIR/resource-usage.log"
kubectl top pods -n ai-apps 2>&1 | tee -a "$SCENARIO_DIR/resource-usage.log"

# --- Screenshots ---
screenshot_prompt "Open WebUI — normal chat response" "$OPENWEBUI_URL"
screenshot_prompt "Pipeline logs showing PASS" "Terminal"
screenshot_prompt "Grafana — Ollama metrics" "$GRAFANA_URL"

# Save pipeline logs
kubectl logs -n ai-apps deploy/open-webui-pipelines --tail=30 > "$SCENARIO_DIR/pipeline-logs.log" 2>&1

result "Scenario 1 Complete" "$SCENARIO_DIR"
