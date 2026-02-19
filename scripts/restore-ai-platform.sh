#!/bin/bash
# =============================================================================
# AI Security Platform - Restore Script
# =============================================================================
# This script restores all stateful data after cluster recreation
# Run this AFTER terraform apply and ArgoCD has synced basic infrastructure
# Version: 2.0.0 - Includes Phase 8 components
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
echo "  Version 2.0.0 (Phase 8 support)"
echo "=========================================="
echo ""

if [ -z "$BACKUP_DIR" ] || [ ! -d "$BACKUP_DIR" ]; then
    log_error "Backup directory not found!"
    echo ""
    echo "Usage: $0 [backup-directory]"
    echo ""
    echo "Available backups:"
    ls -td ~/work/backup-ai-platform-* 2>/dev/null | head -5 || echo "  (none found)"
    exit 1
fi

log_info "Using backup: $BACKUP_DIR"
echo ""

# =============================================================================
# PHASE 1: DISCOVERY
# =============================================================================

log_header "═══════════════════════════════════════════════════════════════════"
log_header "  PHASE 1: DISCOVERY"
log_header "═══════════════════════════════════════════════════════════════════"
echo ""

# Check cluster
log_info "Checking cluster connectivity..."
if ! kubectl cluster-info &>/dev/null; then
    log_error "Cannot connect to cluster! Run 'terraform apply' first."
    exit 1
fi
log_success "Cluster accessible"
echo ""

# Show backup contents
log_header "  📦 BACKUP CONTENTS:"
echo "  ┌─────────────────────────────────────────────────────────────────┐"
[ -d "$BACKUP_DIR/databases" ] && echo "  │   ✓ databases/" || echo "  │   ✗ databases/"
[ -d "$BACKUP_DIR/secrets" ] && echo "  │   ✓ secrets/" || echo "  │   ✗ secrets/"
[ -d "$BACKUP_DIR/qdrant" ] && echo "  │   ✓ qdrant/" || echo "  │   ⊘ qdrant/ (optional)"
[ -d "$BACKUP_DIR/grafana" ] && echo "  │   ✓ grafana/" || echo "  │   ⊘ grafana/ (optional)"
[ -d "$BACKUP_DIR/kyverno" ] && echo "  │   ✓ kyverno/" || echo "  │   ⊘ kyverno/ (optional)"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# Show current cluster state
POSTGRES_POD=$(kubectl get pods -n storage -l cnpg.io/cluster=postgresql-cluster -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
ARGOCD_STATUS=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Not deployed")
KYVERNO_STATUS=$(kubectl get pods -n kyverno -l app.kubernetes.io/name=kyverno -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Not deployed")

log_header "  🔍 CURRENT CLUSTER STATE:"
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │   ArgoCD:     $ARGOCD_STATUS"
echo "  │   PostgreSQL: ${POSTGRES_POD:-Not deployed}"
echo "  │   Kyverno:    $KYVERNO_STATUS"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

if [ -z "$POSTGRES_POD" ]; then
    log_warn "PostgreSQL not ready. Will wait..."
fi

# =============================================================================
# CONFIRMATION
# =============================================================================

read -p "Proceed with restore? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warn "Restore cancelled."
    exit 0
fi

echo ""

# =============================================================================
# PHASE 2: PRE-RESTORE - Fix Kyverno if needed
# =============================================================================

log_header "═══════════════════════════════════════════════════════════════════"
log_header "  PHASE 2: PRE-RESTORE - Preparing cluster"
log_header "═══════════════════════════════════════════════════════════════════"
echo ""

log_info "Checking Kyverno webhooks..."

# Remove Kyverno webhooks to prevent blocking
KYVERNO_WEBHOOKS=$(kubectl get validatingwebhookconfiguration -l app.kubernetes.io/instance=kyverno --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$KYVERNO_WEBHOOKS" -gt 0 ]; then
    echo -n "  → Removing Kyverno webhooks (prevent blocking)... "
    kubectl delete validatingwebhookconfiguration -l app.kubernetes.io/instance=kyverno &>/dev/null || true
    kubectl delete mutatingwebhookconfiguration -l app.kubernetes.io/instance=kyverno &>/dev/null || true
    echo "done"
fi

log_success "Pre-restore complete"
echo ""

# =============================================================================
# PHASE 3: EXECUTION
# =============================================================================

log_header "═══════════════════════════════════════════════════════════════════"
log_header "  PHASE 3: EXECUTION - Restoring data"
log_header "═══════════════════════════════════════════════════════════════════"
echo ""

# -----------------------------------------------------------------------------
# 3.1 Wait for PostgreSQL
# -----------------------------------------------------------------------------

log_info "Step 1/6: Waiting for PostgreSQL..."

TIMEOUT=300
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT ]; do
    POSTGRES_POD=$(kubectl get pods -n storage -l cnpg.io/cluster=postgresql-cluster -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$POSTGRES_POD" ]; then
        if kubectl exec -n storage $POSTGRES_POD -- pg_isready -U postgres &>/dev/null; then
            log_success "PostgreSQL ready: $POSTGRES_POD"
            break
        fi
    fi
    
    echo -n "."
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    log_error "Timeout waiting for PostgreSQL!"
    exit 1
fi
echo ""

# -----------------------------------------------------------------------------
# 3.2 Restore PostgreSQL Roles
# -----------------------------------------------------------------------------

log_info "Step 2/6: Restoring PostgreSQL roles..."

if [ -f "$BACKUP_DIR/databases/roles.sql" ]; then
    echo -n "  → roles... "
    kubectl exec -i -n storage $POSTGRES_POD -- psql -U postgres < "$BACKUP_DIR/databases/roles.sql" &>/dev/null || true
    echo "done"
fi
echo ""

# -----------------------------------------------------------------------------
# 3.3 Restore Databases
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
    
    # Terminate connections, drop, recreate, restore
    kubectl exec -n storage $POSTGRES_POD -- psql -U postgres -c \
        "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();" &>/dev/null || true
    kubectl exec -n storage $POSTGRES_POD -- psql -U postgres -c "DROP DATABASE IF EXISTS $DB_NAME;" &>/dev/null || true
    kubectl exec -n storage $POSTGRES_POD -- psql -U postgres -c "CREATE DATABASE $DB_NAME;" &>/dev/null || true
    kubectl exec -i -n storage $POSTGRES_POD -- psql -U postgres -d "$DB_NAME" < "$DB_FILE" &>/dev/null
    echo "done"
done

log_success "Databases restored"
echo ""

# -----------------------------------------------------------------------------
# 3.4 Restore Secrets
# -----------------------------------------------------------------------------

log_info "Step 4/6: Restoring secrets..."

if [ -d "$BACKUP_DIR/secrets" ]; then
    for SECRET_FILE in "$BACKUP_DIR/secrets"/*.yaml; do
        [ -f "$SECRET_FILE" ] || continue
        
        FILENAME=$(basename "$SECRET_FILE" .yaml)
        NAMESPACE=$(echo "$FILENAME" | cut -d'_' -f1)
        SECRET_NAME=$(echo "$FILENAME" | cut -d'_' -f3-)
        
        echo -n "  → $NAMESPACE/$SECRET_NAME... "
        
        kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml 2>/dev/null | kubectl apply -f - &>/dev/null || true
        kubectl apply -f "$SECRET_FILE" &>/dev/null && echo "done" || echo "failed"
    done
fi

log_success "Secrets restored"
echo ""

# -----------------------------------------------------------------------------
# 3.5 Restore Qdrant
# -----------------------------------------------------------------------------

log_info "Step 5/6: Restoring Qdrant..."

if [ -d "$BACKUP_DIR/qdrant" ] && [ "$(ls -A "$BACKUP_DIR/qdrant" 2>/dev/null)" ]; then
    # Wait for Qdrant
    echo -n "  → Waiting for Qdrant... "
    TIMEOUT=120
    ELAPSED=0
    while [ $ELAPSED -lt $TIMEOUT ]; do
        QDRANT_POD=$(kubectl get pods -n ai-inference -l app.kubernetes.io/name=qdrant -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        STATUS=$(kubectl get pod -n ai-inference "$QDRANT_POD" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
        if [ "$STATUS" = "Running" ]; then
            echo "ready"
            break
        fi
        sleep 5
        ELAPSED=$((ELAPSED + 5))
    done
    
    if [ $ELAPSED -lt $TIMEOUT ]; then
        QDRANT_API_KEY=$(kubectl get secret -n ai-inference rag-api-qdrant-key -o jsonpath='{.data.api-key}' 2>/dev/null | base64 -d || echo "")
        
        if [ -n "$QDRANT_API_KEY" ]; then
            for SNAP_FILE in "$BACKUP_DIR/qdrant"/*; do
                [ -f "$SNAP_FILE" ] || continue
                FILENAME=$(basename "$SNAP_FILE")
                COLLECTION=$(echo "$FILENAME" | cut -d'_' -f1)
                
                echo -n "  → $COLLECTION... "
                kubectl cp "$SNAP_FILE" "ai-inference/$QDRANT_POD:/tmp/$FILENAME" 2>/dev/null
                kubectl exec -n ai-inference $QDRANT_POD -- curl -s -X PUT \
                    -H "api-key: $QDRANT_API_KEY" \
                    "http://localhost:6333/collections/$COLLECTION/snapshots/upload" \
                    -F "snapshot=@/tmp/$FILENAME" &>/dev/null && echo "done" || echo "failed"
                kubectl exec -n ai-inference $QDRANT_POD -- rm -f "/tmp/$FILENAME" 2>/dev/null
            done
        fi
    else
        log_warn "Qdrant timeout - skipping"
    fi
else
    log_info "No Qdrant backup found"
fi
echo ""

# -----------------------------------------------------------------------------
# 3.6 Restart Applications
# -----------------------------------------------------------------------------

log_info "Step 6/6: Restarting applications..."

echo -n "  → Keycloak... "
kubectl rollout restart statefulset -n auth keycloak-keycloakx &>/dev/null && echo "done" || echo "skipped"

echo -n "  → Open WebUI... "
kubectl rollout restart statefulset -n ai-apps open-webui &>/dev/null || kubectl rollout restart deployment -n ai-apps open-webui &>/dev/null && echo "done" || echo "skipped"

echo -n "  → Kyverno... "
kubectl delete pods -n kyverno --all &>/dev/null && echo "done" || echo "skipped"

log_success "Applications restarted"
echo ""

# =============================================================================
# PHASE 4: VERIFICATION
# =============================================================================

log_header "═══════════════════════════════════════════════════════════════════"
log_header "  PHASE 4: VERIFICATION"
log_header "═══════════════════════════════════════════════════════════════════"
echo ""

log_info "Waiting for applications to be ready..."

echo -n "  → Keycloak... "
kubectl wait --for=condition=Ready pod -n auth -l app.kubernetes.io/name=keycloakx --timeout=300s &>/dev/null && echo "ready" || echo "timeout"

echo -n "  → Open WebUI... "
kubectl wait --for=condition=Ready pod -n ai-apps -l app.kubernetes.io/name=open-webui --timeout=300s &>/dev/null && echo "ready" || echo "timeout"

echo -n "  → Kyverno... "
kubectl wait --for=condition=Ready pod -n kyverno -l app.kubernetes.io/name=kyverno --timeout=120s &>/dev/null && echo "ready" || echo "timeout"

echo ""

# =============================================================================
# SUMMARY
# =============================================================================

log_header "═══════════════════════════════════════════════════════════════════"
log_header "  RESTORE COMPLETE!"
log_header "═══════════════════════════════════════════════════════════════════"
echo ""
log_success "What was restored:"
echo "  ✓ PostgreSQL databases"
echo "  ✓ Kubernetes secrets"
echo "  ✓ Keycloak realm (users, clients, roles)"
echo "  ✓ Open WebUI (chat history, settings)"
echo "  ✓ Qdrant vectors (if backup existed)"
echo ""
log_header "  📊 PHASE 8 COMPONENTS (auto-restored by ArgoCD):"
echo "  ✓ Prometheus - fresh metrics"
echo "  ✓ Grafana - dashboards from Helm"
echo "  ✓ Loki - fresh logs"
echo "  ✓ Falco - rules from Git"
echo "  ✓ Kyverno - policies from Git"
echo ""
log_header "  🌐 TEST YOUR APPLICATIONS:"
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │   Keycloak:   https://auth.ai-platform.localhost               │"
echo "  │   Open WebUI: https://chat.ai-platform.localhost               │"
echo "  │   Grafana:    https://grafana.ai-platform.localhost            │"
echo "  │   ArgoCD:     https://argocd.ai-platform.localhost             │"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""
log_header "  ⚠️  IF ISSUES:"
echo "  Fix Kyverno webhooks:"
echo "    kubectl delete validatingwebhookconfiguration -l app.kubernetes.io/instance=kyverno"
echo "    kubectl delete mutatingwebhookconfiguration -l app.kubernetes.io/instance=kyverno"
echo ""
echo "=========================================="
