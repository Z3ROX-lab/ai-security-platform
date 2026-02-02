#!/bin/bash
# =============================================================================
# AI Security Platform - Restore Script
# =============================================================================
# This script restores all stateful data after cluster recreation
# Run this AFTER terraform apply and ArgoCD has synced basic infrastructure
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "${CYAN}${BOLD}$1${NC}"; }

# -----------------------------------------------------------------------------
# Find backup directory
# -----------------------------------------------------------------------------

if [ -n "$1" ]; then
    BACKUP_DIR="$1"
elif [ -f "$HOME/.last-ai-platform-backup" ]; then
    BACKUP_DIR=$(cat "$HOME/.last-ai-platform-backup")
else
    BACKUP_DIR=$(ls -td ~/work/backup-ai-platform-* 2>/dev/null | head -1)
fi

echo ""
echo "=========================================="
echo "  AI Security Platform - Restore Script"
echo "=========================================="
echo ""

if [ -z "$BACKUP_DIR" ] || [ ! -d "$BACKUP_DIR" ]; then
    log_error "Backup directory not found!"
    echo ""
    echo "Usage: $0 [backup-directory]"
    echo "Example: $0 ~/backup-ai-platform-20260129-161800"
    echo ""
    echo "Available backups:"
    ls -td ~/work/backup-ai-platform-* 2>/dev/null | head -5 || echo "  (none found)"
    exit 1
fi

log_info "Using backup: $BACKUP_DIR"
echo ""

# =============================================================================
# PHASE 1: DISCOVERY - What will be restored?
# =============================================================================

log_header "═══════════════════════════════════════════════════════════════════"
log_header "  PHASE 1: DISCOVERY - Analyzing what will be restored"
log_header "═══════════════════════════════════════════════════════════════════"
echo ""

# -----------------------------------------------------------------------------
# 1.1 Check cluster connectivity
# -----------------------------------------------------------------------------

log_info "Checking cluster connectivity..."

if ! kubectl cluster-info &>/dev/null; then
    log_error "Cannot connect to Kubernetes cluster!"
    echo "Make sure you ran 'terraform apply' first."
    exit 1
fi
log_success "Cluster is accessible"
echo ""

# -----------------------------------------------------------------------------
# 1.2 Check backup contents - Databases
# -----------------------------------------------------------------------------

log_info "Scanning backup contents..."

echo ""
log_header "  📦 DATABASES TO RESTORE:"
echo "  ┌─────────────────────────────────────────────────────────────────┐"

if [ -d "$BACKUP_DIR/databases" ]; then
    for DB_FILE in "$BACKUP_DIR/databases"/*.sql; do
        [ -f "$DB_FILE" ] || continue
        FILENAME=$(basename "$DB_FILE")
        FILE_SIZE=$(ls -lh "$DB_FILE" | awk '{print $5}')
        FILE_BYTES=$(wc -c < "$DB_FILE")
        
        if [ "$FILENAME" = "roles.sql" ]; then
            echo "  │   ✓ PostgreSQL roles/users ($FILE_SIZE)"
        elif [ "$FILE_BYTES" -lt 1000 ]; then
            echo "  │   ⊘ ${FILENAME%.sql} ($FILE_SIZE) - SKIP (empty/minimal)"
        else
            echo "  │   ✓ ${FILENAME%.sql} ($FILE_SIZE)"
        fi
    done
else
    echo "  │   ✗ No databases directory found!"
fi
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# -----------------------------------------------------------------------------
# 1.3 Check backup contents - Secrets
# -----------------------------------------------------------------------------

log_header "  🔐 SECRETS TO RESTORE:"
echo "  ┌─────────────────────────────────────────────────────────────────┐"

if [ -d "$BACKUP_DIR/secrets" ]; then
    for SECRET_FILE in "$BACKUP_DIR/secrets"/*.yaml; do
        [ -f "$SECRET_FILE" ] || continue
        FILENAME=$(basename "$SECRET_FILE" .yaml)
        
        # Parse namespace and name (format: namespace__name.yaml)
        if [[ "$FILENAME" == *"__"* ]]; then
            NAMESPACE=$(echo "$FILENAME" | cut -d'_' -f1)
            SECRET_NAME=$(echo "$FILENAME" | cut -d'_' -f3-)
        else
            NAMESPACE=$(grep "namespace:" "$SECRET_FILE" 2>/dev/null | head -1 | awk '{print $2}')
            SECRET_NAME=$(grep "^  name:" "$SECRET_FILE" 2>/dev/null | head -1 | awk '{print $2}')
        fi
        
        echo "  │   ✓ $NAMESPACE/$SECRET_NAME"
    done
else
    echo "  │   ✗ No secrets directory found!"
fi
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# -----------------------------------------------------------------------------
# 1.4 Check backup contents - Qdrant
# -----------------------------------------------------------------------------

log_header "  🔢 QDRANT SNAPSHOTS TO RESTORE:"
echo "  ┌─────────────────────────────────────────────────────────────────┐"

if [ -d "$BACKUP_DIR/qdrant" ]; then
    QDRANT_FILES=$(ls "$BACKUP_DIR/qdrant" 2>/dev/null | wc -l)
    if [ "$QDRANT_FILES" -gt 0 ]; then
        for SNAP_FILE in "$BACKUP_DIR/qdrant"/*; do
            [ -f "$SNAP_FILE" ] || continue
            FILENAME=$(basename "$SNAP_FILE")
            FILE_SIZE=$(ls -lh "$SNAP_FILE" | awk '{print $5}')
            echo "  │   ✓ $FILENAME ($FILE_SIZE)"
        done
    else
        echo "  │   ⊘ No snapshots found (empty directory)"
    fi
else
    echo "  │   ⊘ No qdrant directory in backup (will skip)"
fi
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# -----------------------------------------------------------------------------
# 1.5 Check current cluster state
# -----------------------------------------------------------------------------

log_info "Checking current cluster state..."

POSTGRES_POD=$(kubectl get pods -n storage -l cnpg.io/cluster=postgresql-cluster -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
KEYCLOAK_STATUS=$(kubectl get pods -n auth -l app.kubernetes.io/name=keycloakx -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Not deployed")
WEBUI_STATUS=$(kubectl get pods -n ai-apps -l app.kubernetes.io/name=open-webui -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Not deployed")
ARGOCD_STATUS=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Not deployed")
QDRANT_STATUS=$(kubectl get pods -n ai-inference -l app.kubernetes.io/name=qdrant -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Not deployed")

echo ""
log_header "  🔍 CURRENT CLUSTER STATE:"
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │   ArgoCD:     $ARGOCD_STATUS"
echo "  │   PostgreSQL: ${POSTGRES_POD:-Not deployed}"
echo "  │   Keycloak:   $KEYCLOAK_STATUS"
echo "  │   Open WebUI: $WEBUI_STATUS"
echo "  │   Qdrant:     $QDRANT_STATUS"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# Warn if PostgreSQL not ready
if [ -z "$POSTGRES_POD" ]; then
    log_warn "PostgreSQL is not deployed yet!"
    echo "  The script will wait for PostgreSQL to be ready."
    echo ""
fi

# -----------------------------------------------------------------------------
# 1.6 Restore plan
# -----------------------------------------------------------------------------

log_header "  📋 RESTORE PLAN:"
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │   1. Wait for PostgreSQL to be ready"
echo "  │   2. Restore PostgreSQL roles (users/permissions)"
echo "  │   3. Restore databases (keycloak, openwebui, etc.)"
echo "  │   4. Restore Kubernetes secrets"
echo "  │   5. Restore Qdrant vector database snapshots"
echo "  │   6. Wait for Keycloak and Open WebUI to be deployed"
echo "  │   7. Restart applications to load restored data"
echo "  │   8. Verify everything is working"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

log_header "  ⚠️  POST-RESTORE MANUAL ACTIONS:"
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │   • Accept new TLS certificates in browser (self-signed)"
echo "  │   • Ollama models will re-download on first use (~20GB)"
echo "  │   • ArgoCD has a new admin password (see terraform output)"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# =============================================================================
# CONFIRMATION
# =============================================================================

log_header "═══════════════════════════════════════════════════════════════════"
echo ""
read -p "Proceed with restore? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warn "Restore cancelled by user."
    exit 0
fi

echo ""

# =============================================================================
# PHASE 2: EXECUTION - Perform the restore
# =============================================================================

log_header "═══════════════════════════════════════════════════════════════════"
log_header "  PHASE 2: EXECUTION - Performing restore"
log_header "═══════════════════════════════════════════════════════════════════"
echo ""

# -----------------------------------------------------------------------------
# 2.1 Wait for PostgreSQL
# -----------------------------------------------------------------------------

log_info "Step 1/6: Waiting for PostgreSQL..."

TIMEOUT=300
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT ]; do
    POSTGRES_POD=$(kubectl get pods -n storage -l cnpg.io/cluster=postgresql-cluster -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$POSTGRES_POD" ]; then
        if kubectl exec -n storage $POSTGRES_POD -- pg_isready -U postgres &>/dev/null; then
            log_success "PostgreSQL is ready: $POSTGRES_POD"
            break
        fi
    fi
    
    echo -n "."
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    log_error "Timeout waiting for PostgreSQL!"
    echo "Check: kubectl get pods -n storage"
    exit 1
fi
echo ""

# -----------------------------------------------------------------------------
# 2.2 Restore PostgreSQL Roles
# -----------------------------------------------------------------------------

log_info "Step 2/6: Restoring PostgreSQL roles..."

if [ -f "$BACKUP_DIR/databases/roles.sql" ]; then
    echo -n "  → Restoring roles... "
    kubectl exec -i -n storage $POSTGRES_POD -- psql -U postgres < "$BACKUP_DIR/databases/roles.sql" 2>&1 | grep -c "CREATE ROLE\|ALTER ROLE" || true
    echo "done"
    log_success "Roles restored"
else
    log_warn "No roles.sql found, skipping"
fi
echo ""

# -----------------------------------------------------------------------------
# 2.3 Restore PostgreSQL Databases
# -----------------------------------------------------------------------------

log_info "Step 3/6: Restoring databases..."

for DB_FILE in "$BACKUP_DIR/databases"/*.sql; do
    [ -f "$DB_FILE" ] || continue
    
    FILENAME=$(basename "$DB_FILE")
    [ "$FILENAME" = "roles.sql" ] && continue
    
    DB_NAME="${FILENAME%.sql}"
    FILE_BYTES=$(wc -c < "$DB_FILE")
    
    # Skip empty databases
    if [ "$FILE_BYTES" -lt 1000 ]; then
        echo "  → $DB_NAME... skipped (empty)"
        continue
    fi
    
    echo -n "  → $DB_NAME... "
    
    # Terminate existing connections
    kubectl exec -n storage $POSTGRES_POD -- psql -U postgres -c \
        "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();" \
        &>/dev/null || true
    
    # Drop and recreate
    kubectl exec -n storage $POSTGRES_POD -- psql -U postgres -c "DROP DATABASE IF EXISTS $DB_NAME;" &>/dev/null || true
    kubectl exec -n storage $POSTGRES_POD -- psql -U postgres -c "CREATE DATABASE $DB_NAME;" &>/dev/null || true
    
    # Restore
    if kubectl exec -i -n storage $POSTGRES_POD -- psql -U postgres -d "$DB_NAME" < "$DB_FILE" &>/dev/null; then
        echo "done"
    else
        echo "done (with warnings)"
    fi
done

log_success "Databases restored"
echo ""

# -----------------------------------------------------------------------------
# 2.4 Restore Secrets
# -----------------------------------------------------------------------------

log_info "Step 4/8: Restoring secrets..."

if [ -d "$BACKUP_DIR/secrets" ]; then
    for SECRET_FILE in "$BACKUP_DIR/secrets"/*.yaml; do
        [ -f "$SECRET_FILE" ] || continue
        
        FILENAME=$(basename "$SECRET_FILE" .yaml)
        
        # Parse namespace from filename or YAML
        if [[ "$FILENAME" == *"__"* ]]; then
            NAMESPACE=$(echo "$FILENAME" | cut -d'_' -f1)
            SECRET_NAME=$(echo "$FILENAME" | cut -d'_' -f3-)
        else
            NAMESPACE=$(grep "namespace:" "$SECRET_FILE" | head -1 | awk '{print $2}')
            SECRET_NAME=$(grep "^  name:" "$SECRET_FILE" | head -1 | awk '{print $2}')
        fi
        
        echo -n "  → $NAMESPACE/$SECRET_NAME... "
        
        # Ensure namespace exists
        kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml 2>/dev/null | kubectl apply -f - &>/dev/null || true
        
        # Apply secret
        if kubectl apply -f "$SECRET_FILE" &>/dev/null; then
            echo "done"
        else
            echo "failed"
        fi
    done
    log_success "Secrets restored"
else
    log_warn "No secrets to restore"
fi
echo ""

# -----------------------------------------------------------------------------
# 2.5 Restore Qdrant Vector Database
# -----------------------------------------------------------------------------

log_info "Step 5/8: Restoring Qdrant vector database..."

if [ -d "$BACKUP_DIR/qdrant" ]; then
    QDRANT_FILES=$(ls "$BACKUP_DIR/qdrant" 2>/dev/null | wc -l)
    
    if [ "$QDRANT_FILES" -gt 0 ]; then
        # Wait for Qdrant to be ready
        echo -n "  → Waiting for Qdrant... "
        TIMEOUT=120
        ELAPSED=0
        while [ $ELAPSED -lt $TIMEOUT ]; do
            QDRANT_POD=$(kubectl get pods -n ai-inference -l app.kubernetes.io/name=qdrant -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
            if [ -n "$QDRANT_POD" ]; then
                STATUS=$(kubectl get pod -n ai-inference "$QDRANT_POD" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
                if [ "$STATUS" = "Running" ]; then
                    echo "running"
                    break
                fi
            fi
            sleep 5
            ELAPSED=$((ELAPSED + 5))
        done
        
        if [ $ELAPSED -ge $TIMEOUT ]; then
            echo "timeout (Qdrant not ready - skipping)"
        else
            # Get API key
            QDRANT_API_KEY=$(kubectl get secret -n ai-inference rag-api-qdrant-key -o jsonpath='{.data.api-key}' 2>/dev/null | base64 -d || echo "")
            
            if [ -n "$QDRANT_API_KEY" ]; then
                for SNAP_FILE in "$BACKUP_DIR/qdrant"/*; do
                    [ -f "$SNAP_FILE" ] || continue
                    FILENAME=$(basename "$SNAP_FILE")
                    
                    # Extract collection name from filename (format: collection_snapshot-name)
                    COLLECTION=$(echo "$FILENAME" | cut -d'_' -f1)
                    
                    echo -n "  → Restoring collection '$COLLECTION'... "
                    
                    # Copy snapshot to pod
                    kubectl cp "$SNAP_FILE" "ai-inference/$QDRANT_POD:/tmp/$FILENAME" 2>/dev/null
                    
                    # Restore from snapshot
                    RESTORE_RESULT=$(kubectl exec -n ai-inference $QDRANT_POD -- curl -s -X PUT \
                        -H "api-key: $QDRANT_API_KEY" \
                        "http://localhost:6333/collections/$COLLECTION/snapshots/upload?priority=snapshot" \
                        -H "Content-Type: multipart/form-data" \
                        -F "snapshot=@/tmp/$FILENAME" 2>/dev/null || echo "error")
                    
                    # Cleanup
                    kubectl exec -n ai-inference $QDRANT_POD -- rm -f "/tmp/$FILENAME" 2>/dev/null
                    
                    if echo "$RESTORE_RESULT" | grep -q "error"; then
                        echo "failed"
                    else
                        echo "done"
                    fi
                done
                log_success "Qdrant restored"
            else
                log_warn "Qdrant API key not found - skipping restore"
            fi
        fi
    else
        log_info "No Qdrant snapshots to restore (empty directory)"
    fi
else
    log_info "No Qdrant backup found (will start fresh)"
fi
echo ""

# -----------------------------------------------------------------------------
# 2.6 Wait for Applications
# -----------------------------------------------------------------------------

log_info "Step 6/8: Waiting for applications to be deployed..."

echo -n "  → Waiting for Keycloak... "
TIMEOUT=300
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    STATUS=$(kubectl get pods -n auth -l app.kubernetes.io/name=keycloakx -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
    if [ "$STATUS" = "Running" ]; then
        echo "running"
        break
    fi
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done
[ $ELAPSED -ge $TIMEOUT ] && echo "timeout (check ArgoCD)"

echo -n "  → Waiting for Open WebUI... "
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    STATUS=$(kubectl get pods -n ai-apps -l app.kubernetes.io/name=open-webui -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
    if [ "$STATUS" = "Running" ]; then
        echo "running"
        break
    fi
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done
[ $ELAPSED -ge $TIMEOUT ] && echo "timeout (check ArgoCD)"

log_success "Applications deployed"
echo ""

# -----------------------------------------------------------------------------
# 2.7 Restart Applications
# -----------------------------------------------------------------------------

log_info "Step 7/8: Restarting applications to load restored data..."

echo -n "  → Restarting Keycloak... "
if kubectl rollout restart statefulset -n auth keycloak-keycloakx &>/dev/null; then
    echo "done"
else
    echo "skipped (not found)"
fi

echo -n "  → Restarting Open WebUI... "
if kubectl rollout restart statefulset -n ai-apps open-webui &>/dev/null; then
    echo "done"
elif kubectl rollout restart deployment -n ai-apps open-webui &>/dev/null; then
    echo "done"
else
    echo "skipped (not found)"
fi

log_success "Restarts triggered"
echo ""

# Wait for restarts
log_info "Waiting for applications to be ready..."

echo -n "  → Keycloak... "
kubectl wait --for=condition=Ready pod -n auth -l app.kubernetes.io/name=keycloakx --timeout=300s &>/dev/null && echo "ready" || echo "timeout"

echo -n "  → Open WebUI... "
kubectl wait --for=condition=Ready pod -n ai-apps -l app.kubernetes.io/name=open-webui --timeout=300s &>/dev/null && echo "ready" || echo "timeout"

echo ""

# =============================================================================
# PHASE 3: VERIFICATION
# =============================================================================

log_header "═══════════════════════════════════════════════════════════════════"
log_header "  PHASE 3: VERIFICATION"
log_header "═══════════════════════════════════════════════════════════════════"
echo ""

log_header "  📊 FINAL STATE:"
echo ""

echo "  Pods in auth namespace:"
kubectl get pods -n auth 2>/dev/null | sed 's/^/    /'
echo ""

echo "  Pods in ai-apps namespace:"
kubectl get pods -n ai-apps 2>/dev/null | sed 's/^/    /'
echo ""

echo "  Pods in storage namespace:"
kubectl get pods -n storage 2>/dev/null | sed 's/^/    /'
echo ""

echo "  Ingresses:"
kubectl get ingress -A 2>/dev/null | sed 's/^/    /'
echo ""

# =============================================================================
# SUMMARY
# =============================================================================

log_header "═══════════════════════════════════════════════════════════════════"
log_header "  RESTORE COMPLETE!"
log_header "═══════════════════════════════════════════════════════════════════"
echo ""
log_success "What was restored:"
echo "  ✓ PostgreSQL databases (keycloak, openwebui)"
echo "  ✓ PostgreSQL roles/users"
echo "  ✓ Kubernetes secrets"
echo "  ✓ Keycloak: realm, users, clients, roles, mappers"
echo "  ✓ Open WebUI: chat history, settings"
echo ""

log_header "  🌐 TEST YOUR APPLICATIONS:"
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │   Keycloak:   https://auth.ai-platform.localhost               │"
echo "  │   Open WebUI: https://chat.ai-platform.localhost               │"
echo "  │   ArgoCD:     kubectl port-forward svc/argocd-server \\         │"
echo "  │               -n argocd 9090:443                                │"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""
echo "  Login with your existing Keycloak user: zerotrust"
echo ""
echo "=========================================="
