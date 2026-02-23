#!/bin/bash
###############################################################################
# Scenario 1: AI Chat Normal
# Tests: Open WebUI → LLM Guard (PASS) → Ollama Mistral → streaming response
###############################################################################

source "$(dirname "${BASH_SOURCE[0]}")/demo-common.sh"

RUN_DIR="${1:-.}"
SCENARIO_DIR="$RUN_DIR/01-chat"
mkdir -p "$SCENARIO_DIR"

header "🟦 Scenario 1: AI Chat Normal"

# --- Test 1: Verify pipeline is healthy ---
step "1" "Checking pipeline health"
PIPELINE_POD=$(get_pod "ai-apps" "pipelines")
PIPELINE_LOG=$(kubectl logs -n ai-apps "$PIPELINE_POD" --tail=5 2>&1)
echo "$PIPELINE_LOG" | tee "$SCENARIO_DIR/pipeline-status.log"

if echo "$PIPELINE_LOG" | grep -q "LLM Guard.*Started"; then
    pass "LLM Guard pipeline loaded"
else
    warn "LLM Guard pipeline may not be loaded"
fi

# --- Test 2: Direct Ollama test ---
step "2" "Testing Ollama direct response"
OLLAMA_SVC="http://ollama.ai-inference.svc:11434"
OLLAMA_RESULT=$(kubectl exec -n ai-inference deploy/ollama -- sh -c \
    "wget -q -O- --post-data='{\"model\":\"mistral:7b-instruct-v0.3-q4_K_M\",\"prompt\":\"What is Kubernetes in one sentence?\",\"stream\":false}' \
    --header='Content-Type: application/json' http://localhost:11434/api/generate" 2>&1)

if echo "$OLLAMA_RESULT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
dur=d.get('total_duration',0)/1e9
tokens=d.get('eval_count',0)
speed=tokens/(d.get('eval_duration',1)/1e9) if d.get('eval_duration',0) > 0 else 0
print(f'Duration: {dur:.1f}s | Tokens: {tokens} | Speed: {speed:.1f} t/s')
print(f'Response: {d.get(\"response\",\"\")[:200]}')
" > "$SCENARIO_DIR/ollama-direct.log" 2>&1; then
    cat "$SCENARIO_DIR/ollama-direct.log"
    pass "Ollama responding"
else
    echo "$OLLAMA_RESULT" > "$SCENARIO_DIR/ollama-direct.log"
    warn "Ollama test failed — check logs"
fi

# --- Test 3: Test via Open WebUI API ---
step "3" "Testing full chain via Open WebUI"
info "Open WebUI: https://chat.ai-platform.localhost"
info "Send this prompt in Open WebUI:"
echo ""
echo -e "    ${BOLD}What are the main security principles for AI systems in production?${NC}"
echo ""
info "Verify: response streams word by word"

# --- Test 4: Check pipeline logs ---
step "4" "Pipeline logs (should show PASS)"
info "Watch pipeline logs during the test:"
echo ""
echo "    kubectl logs -n ai-apps deploy/open-webui-pipelines -f"
echo ""
info "Expected: [LLM Guard] User: admin, No injection keywords - PASS"

# --- Test 5: Grafana metrics ---
step "5" "Grafana — Ollama metrics"
info "Open Grafana: https://grafana.ai-platform.localhost"
info "Check dashboards for Ollama CPU/Memory usage"

# --- Screenshots ---
screenshot_prompt "Open WebUI — normal chat response" "https://chat.ai-platform.localhost"
screenshot_prompt "Pipeline logs showing PASS" "Terminal"
screenshot_prompt "Grafana — Ollama metrics" "https://grafana.ai-platform.localhost"

# --- Save pipeline state ---
kubectl logs -n ai-apps deploy/open-webui-pipelines --tail=30 > "$SCENARIO_DIR/pipeline-logs.log" 2>&1
kubectl top pods -n ai-inference > "$SCENARIO_DIR/resource-usage.log" 2>&1

result "Scenario 1 Complete" "$SCENARIO_DIR"
