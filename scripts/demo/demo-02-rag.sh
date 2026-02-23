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

# --- Test 1: Verify Qdrant is running ---
step "1" "Checking Qdrant status"
QDRANT_COLLECTIONS=$(kubectl exec -n ai-inference deploy/qdrant -- \
    wget -q -O- http://localhost:6333/collections 2>&1 || echo '{"error":"unreachable"}')
echo "$QDRANT_COLLECTIONS" | python3 -m json.tool > "$SCENARIO_DIR/qdrant-collections.json" 2>&1
cat "$SCENARIO_DIR/qdrant-collections.json"

if echo "$QDRANT_COLLECTIONS" | grep -q '"ok"'; then
    pass "Qdrant is healthy"
else
    warn "Qdrant may have issues"
fi

# --- Test 2: Upload a test document ---
step "2" "Uploading test security policy document"

# Create a test document
cat > /tmp/ai-security-policy.txt << 'POLICY'
AI Security Policy - AI Platform v1.0

1. ACCESS CONTROL
All AI model access must be authenticated via Keycloak OIDC.
Users must have a valid clearance level to access specific RAG collections.
Service accounts must use short-lived tokens with minimum required permissions.

2. PROMPT SECURITY
All user prompts must pass through LLM Guard security filter before reaching the model.
Prompt injection detection is mandatory for all production deployments.
Secrets and PII must be detected and blocked at the input layer.

3. MODEL SECURITY
AI models must be stored in isolated namespaces with network policies.
Model files must not be accessible from non-inference containers.
Falco runtime monitoring must be active on all AI workload nodes.

4. DATA PROTECTION
RAG documents must be classified (C1-C5) before ingestion into Qdrant.
Vector embeddings must be stored with access controls matching document classification.
No sensitive data (PII, credentials) may be included in RAG context without redaction.

5. MONITORING
All AI interactions must be logged and forwarded to Loki for audit.
Prometheus must collect inference latency, token usage, and error rates.
Grafana dashboards must be maintained for real-time security visibility.
POLICY

info "Test document created: AI Security Policy"

# Upload via RAG API
RAG_UPLOAD=$(kubectl exec -n ai-inference deploy/qdrant -- \
    wget -q -O- --post-data="{\"collection\":\"ai-security-docs\",\"document\":\"$(cat /tmp/ai-security-policy.txt | sed 's/"/\\"/g' | tr '\n' ' ')\"}" \
    --header='Content-Type: application/json' \
    http://rag-api.ai-inference.svc.cluster.local:8000/ingest 2>&1 || echo "Upload via API")
echo "$RAG_UPLOAD" > "$SCENARIO_DIR/rag-upload.log"
info "Document upload attempted — check RAG API logs"

# --- Test 3: Query via Open WebUI ---
step "3" "Testing RAG query"
info "Open WebUI: https://chat.ai-platform.localhost"
info "Send this prompt:"
echo ""
echo -e "    ${BOLD}What does the AI security policy say about prompt security?${NC}"
echo ""
info "Expected: Answer references the security policy with source attribution"
info "Look for: 'Sources:' section at the bottom of the response"

# --- Test 4: Check RAG Pipeline logs ---
step "4" "RAG Pipeline logs"
info "Watch logs during the query:"
echo ""
echo "    kubectl logs -n ai-apps deploy/open-webui-pipelines -f"
echo ""
info "Expected: [RAG Pipeline] Found X relevant chunks"

# --- Test 5: Qdrant collection details ---
step "5" "Qdrant collection details"
kubectl exec -n ai-inference deploy/qdrant -- \
    wget -q -O- http://localhost:6333/collections 2>&1 | \
    python3 -m json.tool > "$SCENARIO_DIR/qdrant-final.json" 2>&1
cat "$SCENARIO_DIR/qdrant-final.json"

# --- Screenshots ---
screenshot_prompt "Open WebUI — RAG response with sources" "https://chat.ai-platform.localhost"
screenshot_prompt "Pipeline logs showing RAG context retrieval" "Terminal"

# Save logs
kubectl logs -n ai-apps deploy/open-webui-pipelines --tail=30 > "$SCENARIO_DIR/pipeline-logs.log" 2>&1

result "Scenario 2 Complete" "$SCENARIO_DIR"
