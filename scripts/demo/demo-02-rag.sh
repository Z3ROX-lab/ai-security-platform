#!/bin/bash
###############################################################################
# Scenario 2: RAG Document Q&A
# Tests: Document upload → Qdrant → RAG Pipeline → contextual answer
###############################################################################

source "$(dirname "${BASH_SOURCE[0]}")/demo-common.sh"

RUN_DIR="${1:-.}"
SCENARIO_DIR="$RUN_DIR/02-rag"
mkdir -p "$SCENARIO_DIR"

header "🟩 Scenario 2: RAG Document Q&A"

# --- Test 1: Qdrant health ---
step "1" "Checking Qdrant via Traefik"
QDRANT_HEALTH=$($CURL "$QDRANT_URL/healthz" 2>&1)
echo "$QDRANT_HEALTH" > "$SCENARIO_DIR/qdrant-health.log"

if echo "$QDRANT_HEALTH" | grep -qi "ok\|true"; then
    pass "Qdrant healthy at $QDRANT_URL"
else
    warn "Qdrant health: $QDRANT_HEALTH"
fi

# --- Test 2: List Qdrant collections ---
step "2" "Listing Qdrant collections"
COLLECTIONS=$($CURL "$QDRANT_URL/collections" 2>&1)
echo "$COLLECTIONS" | python3 -m json.tool > "$SCENARIO_DIR/qdrant-collections.json" 2>&1
cat "$SCENARIO_DIR/qdrant-collections.json"

COLL_COUNT=$(echo "$COLLECTIONS" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('result',{}).get('collections',[])))" 2>/dev/null)
pass "Qdrant has $COLL_COUNT collection(s)"

# --- Test 3: RAG API health ---
step "3" "Checking RAG API via Traefik"
RAG_HEALTH=$($CURL "$RAG_URL/" 2>&1)
echo "$RAG_HEALTH" > "$SCENARIO_DIR/rag-health.log"
info "RAG API response: $(echo "$RAG_HEALTH" | head -1)"

# --- Test 4: Upload test document ---
step "4" "Uploading test security policy"
info "In Open WebUI: use Documents feature to upload a file"
info "Or via RAG API:"

# Create test doc
cat > /tmp/ai-security-policy.md << 'POLICY'
# AI Security Policy v1.0

## Access Control
All AI model access must be authenticated via Keycloak OIDC.
Service accounts must use short-lived tokens with minimum permissions.

## Prompt Security
All user prompts must pass through LLM Guard security filter.
Prompt injection detection is mandatory for production deployments.
Secrets and PII must be detected and blocked at the input layer.

## Model Security
AI models must be stored in isolated namespaces with network policies.
Falco runtime monitoring must be active on all AI workload nodes.

## Data Protection
RAG documents must be classified (C1-C5) before ingestion.
Vector embeddings must be stored with access controls matching classification.

## Monitoring
All AI interactions must be logged and forwarded to Loki.
Prometheus must collect inference latency, token usage, and error rates.
POLICY

info "Test document ready: /tmp/ai-security-policy.md"

# --- Test 5: Query via Open WebUI ---
step "5" "Testing RAG query via Open WebUI"
info "Open: $OPENWEBUI_URL"
info "Make sure the RAG pipeline is active, then ask:"
echo ""
echo -e "    ${BOLD}What does the security policy say about prompt security?${NC}"
echo ""
info "Expected: Answer references the policy with source chunks"
info "Look for: context from the uploaded document in the response"

# --- Test 6: Pipeline logs ---
step "6" "RAG Pipeline logs"
info "In another terminal:"
echo ""
echo "    kubectl logs -n ai-apps deploy/open-webui-pipelines -f"
echo ""
info "Expected: [RAG Pipeline] Found X relevant chunks from Qdrant"

# --- Screenshots ---
screenshot_prompt "Open WebUI — RAG response with sources" "$OPENWEBUI_URL"
screenshot_prompt "Pipeline logs — RAG context retrieval" "Terminal"
screenshot_prompt "Qdrant collections" "$QDRANT_URL/dashboard"

# Save logs
kubectl logs -n ai-apps deploy/open-webui-pipelines --tail=30 > "$SCENARIO_DIR/pipeline-logs.log" 2>&1

result "Scenario 2 Complete" "$SCENARIO_DIR"
