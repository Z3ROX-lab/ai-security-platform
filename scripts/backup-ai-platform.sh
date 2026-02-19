#!/bin/bash
# =============================================================================
# AI Security Platform - Complete Backup Script
# =============================================================================
# This script backs up all stateful data before cluster recreation
# Run this BEFORE terraform destroy
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
# Configuration
# -----------------------------------------------------------------------------

BACKUP_DIR="$HOME/work/backup-ai-platform-$(date +%Y%m%d-%H%M%S)"

echo ""
echo "=========================================="
echo "  AI Security Platform - Backup Script"
echo "  Version 2.0.0 (Phase 8 support)"
echo "=========================================="
echo ""

# =============================================================================
# PHASE 1: DISCOVERY - What will be backed up?
# =============================================================================

log_header "═══════════════════════════════════════════════════════════════════"
log_header "  PHASE 1: DISCOVERY - Analyzing what will be backed up"
log_header "═══════════════════════════════════════════════════════════════════"
echo ""

# -----------------------------------------------------------------------------
# 1.1 Discover PostgreSQL
# -----------------------------------------------------------------------------

log_info "Scanning PostgreSQL..."

POSTGRES_POD=$(kubectl get pods -n storage -l cnpg.io/cluster=postgresql-cluster -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$POSTGRES_POD" ]; then
    log_error "PostgreSQL pod not found! Cannot proceed."
    exit 1
fi

# Get databases and their sizes
DATABASES_INFO=$(kubectl exec -n storage $POSTGRES_POD -- psql -U postgres -t -c "
    SELECT datname, pg_size_pretty(pg_database_size(datname)) 
    FROM pg_database 
    WHERE datistemplate = false AND datname != 'postgres'
    ORDER BY pg_database_size(datname) DESC;
" 2>/dev/null | grep -v '^$' || echo "")

echo ""
log_header "  📦 POSTGRESQL DATABASES TO BACKUP:"
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │ Pod: $POSTGRES_POD"
echo "  ├─────────────────────────────────────────────────────────────────┤"
if [ -n "$DATABASES_INFO" ]; then
    echo "$DATABASES_INFO" | while read -r line; do
        DB_NAME=$(echo "$line" | awk -F'|' '{print $1}' | tr -d ' ')
        DB_SIZE=$(echo "$line" | awk -F'|' '{print $2}' | tr -d ' ')
        if [ -n "$DB_NAME" ]; then
            echo "  │   ✓ $DB_NAME ($DB_SIZE)"
        fi
    done
else
    echo "  │   (no databases found)"
fi
echo "  │   ✓ PostgreSQL roles (users/permissions)"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# -----------------------------------------------------------------------------
# 1.2 Discover Secrets
# -----------------------------------------------------------------------------

log_info "Scanning Secrets..."

echo ""
log_header "  🔐 SECRETS TO BACKUP:"
echo "  ┌─────────────────────────────────────────────────────────────────┐"

declare -a SECRETS_TO_BACKUP=(
    "auth:keycloak-db-secret"
    "ai-apps:openwebui-oidc-secret"
    "ai-apps:postgres-superuser-creds"
    "cert-manager:ai-platform-ca-secret"
    "ai-inference:rag-api-qdrant-key"
)

for SECRET_SPEC in "${SECRETS_TO_BACKUP[@]}"; do
    NAMESPACE=$(echo "$SECRET_SPEC" | cut -d':' -f1)
    SECRET_NAME=$(echo "$SECRET_SPEC" | cut -d':' -f2)
    
    if kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" &>/dev/null; then
        echo "  │   ✓ $NAMESPACE/$SECRET_NAME"
    else
        echo "  │   ✗ $NAMESPACE/$SECRET_NAME (NOT FOUND - will skip)"
    fi
done
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# -----------------------------------------------------------------------------
# 1.3 Discover Keycloak
# -----------------------------------------------------------------------------

log_info "Scanning Keycloak..."

KEYCLOAK_POD=$(kubectl get pods -n auth -l app.kubernetes.io/name=keycloakx -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

echo ""
log_header "  👤 KEYCLOAK REALM TO BACKUP:"
echo "  ┌─────────────────────────────────────────────────────────────────┐"
if [ -n "$KEYCLOAK_POD" ]; then
    echo "  │   ✓ Realm: ai-platform (via database dump)"
    echo "  │   ✓ Users, Clients, Roles, Groups, Mappers"
else
    echo "  │   ✗ Keycloak pod not found (will rely on DB backup)"
fi
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# -----------------------------------------------------------------------------
# 1.4 Discover Qdrant Vector Database
# -----------------------------------------------------------------------------

log_info "Scanning Qdrant..."

QDRANT_POD=$(kubectl get pods -n ai-inference -l app.kubernetes.io/name=qdrant -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

echo ""
log_header "  🔢 QDRANT VECTOR DATABASE TO BACKUP:"
echo "  ┌─────────────────────────────────────────────────────────────────┐"
if [ -n "$QDRANT_POD" ]; then
    QDRANT_API_KEY=$(kubectl get secret -n ai-inference rag-api-qdrant-key -o jsonpath='{.data.api-key}' 2>/dev/null | base64 -d || echo "")
    if [ -n "$QDRANT_API_KEY" ]; then
        COLLECTIONS=$(kubectl exec -n ai-inference $QDRANT_POD -- curl -s -H "api-key: $QDRANT_API_KEY" http://localhost:6333/collections 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4 || echo "")
        if [ -n "$COLLECTIONS" ]; then
            echo "  │   Pod: $QDRANT_POD"
            for COLL in $COLLECTIONS; do
                echo "  │   ✓ Collection: $COLL"
            done
        else
            echo "  │   Pod: $QDRANT_POD (no collections)"
        fi
    else
        echo "  │   Pod: $QDRANT_POD (no API key)"
    fi
else
    echo "  │   ✗ Qdrant pod not found"
fi
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# -----------------------------------------------------------------------------
# 1.5 Discover Phase 8: Observability & Security
# -----------------------------------------------------------------------------

log_info "Scanning Phase 8: Observability & Security..."

echo ""
log_header "  📊 PHASE 8 COMPONENTS:"
echo "  ┌─────────────────────────────────────────────────────────────────┐"

# Prometheus
PROM_POD=$(kubectl get pods -n observability -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
[ -n "$PROM_POD" ] && echo "  │   ✓ Prometheus (ephemeral - no backup)" || echo "  │   ✗ Prometheus"

# Grafana
GRAFANA_POD=$(kubectl get pods -n observability -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
[ -n "$GRAFANA_POD" ] && echo "  │   ✓ Grafana (dashboards will be backed up)" || echo "  │   ✗ Grafana"

# Loki
LOKI_POD=$(kubectl get pods -n observability -l app.kubernetes.io/name=loki -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
[ -n "$LOKI_POD" ] && echo "  │   ✓ Loki (ephemeral - no backup)" || echo "  │   ✗ Loki"

# Falco
FALCO_POD=$(kubectl get pods -n falco -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
[ -n "$FALCO_POD" ] && echo "  │   ✓ Falco (config in Git)" || echo "  │   ✗ Falco"

# Kyverno
KYVERNO_POD=$(kubectl get pods -n kyverno -l app.kubernetes.io/name=kyverno -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$KYVERNO_POD" ]; then
    POLICY_COUNT=$(kubectl get clusterpolicy --no-headers 2>/dev/null | wc -l || echo "0")
    echo "  │   ✓ Kyverno ($POLICY_COUNT policies in Git)"
else
    echo "  │   ✗ Kyverno"
fi

echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# -----------------------------------------------------------------------------
# 1.6 What will NOT be backed up
# -----------------------------------------------------------------------------

log_header "  ⚠️  WILL NOT BE BACKED UP (GitOps managed):"
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │   ✗ Ollama models (~20GB) - re-download on first use"
echo "  │   ✗ TLS certificates - regenerated by cert-manager"
echo "  │   ✗ ArgoCD admin password - regenerated"
echo "  │   ✗ Prometheus metrics - ephemeral"
echo "  │   ✗ Loki logs - ephemeral"
echo "  │   ✗ Kyverno policies - in Git"
echo "  │   ✗ Falco rules - in Git"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

log_header "  📁 BACKUP DESTINATION: $BACKUP_DIR"
echo ""

# =============================================================================
# CONFIRMATION
# =============================================================================

read -p "Proceed with backup? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warn "Backup cancelled."
    exit 0
fi

echo ""

# =============================================================================
# PHASE 2: EXECUTION
# =============================================================================

log_header "═══════════════════════════════════════════════════════════════════"
log_header "  PHASE 2: EXECUTION - Performing backup"
log_header "═══════════════════════════════════════════════════════════════════"
echo ""

mkdir -p "$BACKUP_DIR"/{databases,secrets,grafana,kyverno}

# -----------------------------------------------------------------------------
# 2.1 Backup PostgreSQL
# -----------------------------------------------------------------------------

log_info "Step 1/6: Backing up PostgreSQL..."

DATABASES=$(kubectl exec -n storage $POSTGRES_POD -- psql -U postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';" 2>/dev/null | tr -d ' ' | grep -v '^$')

for DB in $DATABASES; do
    echo -n "  → $DB... "
    kubectl exec -n storage $POSTGRES_POD -- pg_dump -U postgres "$DB" > "$BACKUP_DIR/databases/${DB}.sql" 2>/dev/null
    SIZE=$(ls -lh "$BACKUP_DIR/databases/${DB}.sql" | awk '{print $5}')
    echo "done ($SIZE)"
done

echo -n "  → roles... "
kubectl exec -n storage $POSTGRES_POD -- pg_dumpall -U postgres --roles-only > "$BACKUP_DIR/databases/roles.sql" 2>/dev/null
echo "done"

log_success "PostgreSQL backup complete"
echo ""

# -----------------------------------------------------------------------------
# 2.2 Backup Secrets
# -----------------------------------------------------------------------------

log_info "Step 2/6: Backing up secrets..."

for SECRET_SPEC in "${SECRETS_TO_BACKUP[@]}"; do
    NAMESPACE=$(echo "$SECRET_SPEC" | cut -d':' -f1)
    SECRET_NAME=$(echo "$SECRET_SPEC" | cut -d':' -f2)
    
    echo -n "  → $NAMESPACE/$SECRET_NAME... "
    
    if kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" &>/dev/null; then
        kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" -o yaml | \
            grep -v "resourceVersion:\|uid:\|creationTimestamp:\|selfLink:\|managedFields:" \
            > "$BACKUP_DIR/secrets/${NAMESPACE}__${SECRET_NAME}.yaml"
        echo "done"
    else
        echo "skipped"
    fi
done

log_success "Secrets backup complete"
echo ""

# -----------------------------------------------------------------------------
# 2.3 Backup Qdrant
# -----------------------------------------------------------------------------

log_info "Step 3/6: Backing up Qdrant..."

if [ -n "$QDRANT_POD" ] && [ -n "$QDRANT_API_KEY" ]; then
    mkdir -p "$BACKUP_DIR/qdrant"
    
    COLLECTIONS=$(kubectl exec -n ai-inference $QDRANT_POD -- curl -s -H "api-key: $QDRANT_API_KEY" http://localhost:6333/collections 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4 || echo "")
    
    for COLL in $COLLECTIONS; do
        echo -n "  → $COLL... "
        
        SNAPSHOT_RESULT=$(kubectl exec -n ai-inference $QDRANT_POD -- curl -s -X POST \
            -H "api-key: $QDRANT_API_KEY" \
            "http://localhost:6333/collections/$COLL/snapshots" 2>/dev/null)
        
        SNAPSHOT_NAME=$(echo "$SNAPSHOT_RESULT" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)
        
        if [ -n "$SNAPSHOT_NAME" ]; then
            kubectl exec -n ai-inference $QDRANT_POD -- curl -s \
                -H "api-key: $QDRANT_API_KEY" \
                "http://localhost:6333/collections/$COLL/snapshots/$SNAPSHOT_NAME" \
                -o "/tmp/$SNAPSHOT_NAME" 2>/dev/null
            
            kubectl cp "ai-inference/$QDRANT_POD:/tmp/$SNAPSHOT_NAME" "$BACKUP_DIR/qdrant/${COLL}_${SNAPSHOT_NAME}" 2>/dev/null
            kubectl exec -n ai-inference $QDRANT_POD -- rm -f "/tmp/$SNAPSHOT_NAME" 2>/dev/null
            echo "done"
        else
            echo "failed"
        fi
    done
    
    log_success "Qdrant backup complete"
else
    log_warn "Qdrant backup skipped"
fi
echo ""

# -----------------------------------------------------------------------------
# 2.4 Backup Grafana
# -----------------------------------------------------------------------------

log_info "Step 4/6: Backing up Grafana dashboards..."

if [ -n "$GRAFANA_POD" ]; then
    GRAFANA_PASS=$(kubectl get secret -n observability kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d || echo "")
    
    if [ -n "$GRAFANA_PASS" ]; then
        echo -n "  → dashboards... "
        kubectl exec -n observability $GRAFANA_POD -c grafana -- curl -s \
            -u "admin:$GRAFANA_PASS" \
            "http://localhost:3000/api/search?type=dash-db" \
            > "$BACKUP_DIR/grafana/dashboard-list.json" 2>/dev/null
        echo "done"
        
        echo -n "  → datasources... "
        kubectl exec -n observability $GRAFANA_POD -c grafana -- curl -s \
            -u "admin:$GRAFANA_PASS" \
            "http://localhost:3000/api/datasources" \
            > "$BACKUP_DIR/grafana/datasources.json" 2>/dev/null
        echo "done"
        
        log_success "Grafana backup complete"
    else
        log_warn "Grafana credentials not found"
    fi
else
    log_warn "Grafana backup skipped"
fi
echo ""

# -----------------------------------------------------------------------------
# 2.5 Backup Kyverno Reports
# -----------------------------------------------------------------------------

log_info "Step 5/6: Backing up Kyverno reports..."

echo -n "  → cluster policies... "
kubectl get clusterpolicy -o yaml > "$BACKUP_DIR/kyverno/clusterpolicies.yaml" 2>/dev/null && echo "done" || echo "skipped"

echo -n "  → policy reports... "
kubectl get policyreport -A -o yaml > "$BACKUP_DIR/kyverno/policyreports.yaml" 2>/dev/null && echo "done" || echo "skipped"

log_success "Kyverno backup complete"
echo ""

# -----------------------------------------------------------------------------
# 2.6 Document State
# -----------------------------------------------------------------------------

log_info "Step 6/6: Documenting cluster state..."

kubectl get applications -n argocd -o wide > "$BACKUP_DIR/argocd-apps.txt" 2>&1
kubectl get pods -A -o wide > "$BACKUP_DIR/all-pods.txt" 2>&1
kubectl get pvc -A > "$BACKUP_DIR/pvcs.txt" 2>&1
kubectl get ingress -A > "$BACKUP_DIR/ingresses.txt" 2>&1

log_success "State documented"
echo ""

# -----------------------------------------------------------------------------
# Create README
# -----------------------------------------------------------------------------

cat > "$BACKUP_DIR/README.md" << EOF
# AI Security Platform Backup
**Created:** $(date)
**Version:** 2.0.0 (Phase 8 support)

## Contents
- \`databases/\` - PostgreSQL dumps
- \`secrets/\` - Kubernetes secrets
- \`qdrant/\` - Vector database snapshots
- \`grafana/\` - Dashboards and datasources
- \`kyverno/\` - Policy reports

## Phase 8 Notes
- Prometheus/Loki data is ephemeral (not backed up)
- Kyverno policies are in Git (only reports backed up)
- Falco rules are in Git (no backup needed)

## Restore
\`\`\`bash
./scripts/restore-ai-platform.sh $BACKUP_DIR
\`\`\`
EOF

echo "$BACKUP_DIR" > "$HOME/.last-ai-platform-backup"

# =============================================================================
# SUMMARY
# =============================================================================

echo ""
log_header "═══════════════════════════════════════════════════════════════════"
log_header "  BACKUP COMPLETE!"
log_header "═══════════════════════════════════════════════════════════════════"
echo ""
echo "  Location: $BACKUP_DIR"
echo "  Size: $(du -sh "$BACKUP_DIR" | cut -f1)"
echo ""
echo "  Next: terraform destroy && terraform apply && ./scripts/restore-ai-platform.sh"
echo ""
