#!/bin/bash
###############################################################################
# Scenario 4: Secrets Detection
# Tests: LLM Guard Secrets scanner detects API keys, passwords, tokens
###############################################################################

source "$(dirname "${BASH_SOURCE[0]}")/demo-common.sh"

RUN_DIR="${1:-.}"
SCENARIO_DIR="$RUN_DIR/04-secrets"
mkdir -p "$SCENARIO_DIR"

header "🟨 Scenario 4: Secrets Detection"

# --- Test 1: AWS API Key ---
step "1" "Testing AWS API key detection"
RESULT=$(kubectl exec -n ai-inference deploy/guardrails-api -- \
    wget -q -O- --post-data='{"prompt":"My AWS access key is AKIA1234567890ABCDEF and secret is wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"}' \
    --header='Content-Type: application/json' \
    http://localhost:8000/scan/input 2>&1)

echo "$RESULT" | python3 -m json.tool > "$SCENARIO_DIR/aws-key-scan.json" 2>&1
cat "$SCENARIO_DIR/aws-key-scan.json"

SECRETS_VALID=$(echo "$RESULT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for s in d.get('scanners',[]):
    if s['name']=='Secrets':
        print(s['is_valid'])
        break
" 2>/dev/null)

if [[ "$SECRETS_VALID" == "False" ]]; then
    pass "AWS API key DETECTED"
else
    warn "AWS API key not detected by Secrets scanner"
fi

# --- Test 2: GitHub Token ---
step "2" "Testing GitHub token detection"
RESULT=$(kubectl exec -n ai-inference deploy/guardrails-api -- \
    wget -q -O- --post-data='{"prompt":"Here is my GitHub token: ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef12"}' \
    --header='Content-Type: application/json' \
    http://localhost:8000/scan/input 2>&1)

echo "$RESULT" | python3 -m json.tool > "$SCENARIO_DIR/github-token-scan.json" 2>&1

SECRETS_VALID=$(echo "$RESULT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for s in d.get('scanners',[]):
    if s['name']=='Secrets':
        print(s['is_valid'])
        break
" 2>/dev/null)

if [[ "$SECRETS_VALID" == "False" ]]; then
    pass "GitHub token DETECTED"
else
    warn "GitHub token not detected"
fi

# --- Test 3: Generic password ---
step "3" "Testing password in prompt"
RESULT=$(kubectl exec -n ai-inference deploy/guardrails-api -- \
    wget -q -O- --post-data='{"prompt":"The database password is P@ssw0rd123! and the connection string is postgresql://admin:secret@db.internal:5432/prod"}' \
    --header='Content-Type: application/json' \
    http://localhost:8000/scan/input 2>&1)

echo "$RESULT" | python3 -m json.tool > "$SCENARIO_DIR/password-scan.json" 2>&1
cat "$SCENARIO_DIR/password-scan.json"

# --- Test 4: Clean prompt (no secrets) ---
step "4" "Testing clean prompt (no secrets — should pass)"
RESULT=$(kubectl exec -n ai-inference deploy/guardrails-api -- \
    wget -q -O- --post-data='{"prompt":"How do I configure network policies in Kubernetes?"}' \
    --header='Content-Type: application/json' \
    http://localhost:8000/scan/input 2>&1)

SECRETS_VALID=$(echo "$RESULT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for s in d.get('scanners',[]):
    if s['name']=='Secrets':
        print(s['is_valid'])
        break
" 2>/dev/null)

if [[ "$SECRETS_VALID" == "True" ]]; then
    pass "Clean prompt passed Secrets scanner"
else
    fail "False positive on clean prompt"
fi

# --- Test 5: Open WebUI test ---
step "5" "Testing via Open WebUI"
info "Open WebUI: https://chat.ai-platform.localhost"
info "Send this prompt:"
echo ""
echo -e "    ${BOLD}${YELLOW}My AWS access key is AKIA1234567890ABCDEF and secret is wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY${NC}"
echo ""
info "Expected: Secret detection warning or blocked message"

# --- Screenshots ---
screenshot_prompt "Open WebUI — secrets detection" "https://chat.ai-platform.localhost"
screenshot_prompt "Guardrails API — secrets scan result" "Terminal"

result "Scenario 4 Complete" "$SCENARIO_DIR"
