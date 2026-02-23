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
RESULT=$($CURL "$GUARDRAILS_URL/scan/input" \
    -H "Content-Type: application/json" \
    -d '{"prompt":"My AWS access key is AKIA1234567890ABCDEF and secret is wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"}' 2>&1)

echo "$RESULT" | python3 -m json.tool > "$SCENARIO_DIR/aws-key-scan.json" 2>&1
cat "$SCENARIO_DIR/aws-key-scan.json"

SECRETS_VALID=$(echo "$RESULT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for s in d.get('scanners',[]):
    if s['name']=='Secrets':
        print(s['is_valid'])
        break
else:
    print('N/A')
" 2>/dev/null)

if [[ "$SECRETS_VALID" == "False" ]]; then
    pass "AWS API key DETECTED by Secrets scanner"
elif [[ "$SECRETS_VALID" == "N/A" ]]; then
    warn "Secrets scanner not found in response"
else
    warn "AWS API key not detected"
fi

# --- Test 2: GitHub Token ---
step "2" "Testing GitHub token detection"
RESULT=$($CURL "$GUARDRAILS_URL/scan/input" \
    -H "Content-Type: application/json" \
    -d '{"prompt":"Here is my GitHub token: ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef12"}' 2>&1)

echo "$RESULT" | python3 -m json.tool > "$SCENARIO_DIR/github-token-scan.json" 2>&1

SECRETS_VALID=$(echo "$RESULT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for s in d.get('scanners',[]):
    if s['name']=='Secrets':
        print(s['is_valid'])
        break
else:
    print('N/A')
" 2>/dev/null)

if [[ "$SECRETS_VALID" == "False" ]]; then
    pass "GitHub token DETECTED"
else
    warn "GitHub token not detected (valid=$SECRETS_VALID)"
fi

# --- Test 3: Connection string ---
step "3" "Testing database connection string"
RESULT=$($CURL "$GUARDRAILS_URL/scan/input" \
    -H "Content-Type: application/json" \
    -d '{"prompt":"The connection string is postgresql://admin:secret@db.internal:5432/prod"}' 2>&1)

echo "$RESULT" | python3 -m json.tool > "$SCENARIO_DIR/connstring-scan.json" 2>&1
cat "$SCENARIO_DIR/connstring-scan.json"

# --- Test 4: Clean prompt (no secrets) ---
step "4" "Testing clean prompt (should pass)"
RESULT=$($CURL "$GUARDRAILS_URL/scan/input" \
    -H "Content-Type: application/json" \
    -d '{"prompt":"How do I configure network policies in Kubernetes?"}' 2>&1)

SECRETS_VALID=$(echo "$RESULT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for s in d.get('scanners',[]):
    if s['name']=='Secrets':
        print(s['is_valid'])
        break
else:
    print('True')
" 2>/dev/null)

if [[ "$SECRETS_VALID" == "True" ]]; then
    pass "Clean prompt passed Secrets scanner (no false positive)"
else
    fail "False positive on clean prompt"
fi

# --- Test 5: Open WebUI ---
step "5" "Testing via Open WebUI"
info "Open: $OPENWEBUI_URL"
info "Send:"
echo ""
echo -e "    ${BOLD}${YELLOW}My AWS key is AKIA1234567890ABCDEF and secret is wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY${NC}"
echo ""
info "Expected: Secret detection warning"

# --- Screenshots ---
screenshot_prompt "Open WebUI — secrets detection" "$OPENWEBUI_URL"
screenshot_prompt "Guardrails API — secrets scan result" "Terminal"

result "Scenario 4 Complete" "$SCENARIO_DIR"
