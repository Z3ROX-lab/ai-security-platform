#!/bin/bash
# =============================================================================
# AI Security Platform - Complete Backup Script
# =============================================================================
# This script backs up all stateful data before cluster recreation
# Run this BEFORE terraform destroy
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
    echo "  │   ⚠ JSON export will be attempted (optional)"
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
        # Get collections via API
        COLLECTIONS=$(kubectl exec -n ai-inference $QDRANT_POD -- curl -s -H "api-key: $QDRANT_API_KEY" http://localhost:6333/collections 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4 || echo "")
        if [ -n "$COLLECTIONS" ]; then
            echo "  │   Pod: $QDRANT_POD"
            echo "  │   ├── Collections:"
            for COLL in $COLLECTIONS; do
                echo "  │   │   ✓ $COLL"
            done
        else
            echo "  │   Pod: $QDRANT_POD"
            echo "  │   ├── Collections: (none found or API error)"
        fi
    else
        echo "  │   Pod: $QDRANT_POD"
        echo "  │   ├── Collections: (no API key found)"
    fi
    echo "  │   └── Snapshot will be created"
else
    echo "  │   ✗ Qdrant pod not found (will skip)"
fi
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# -----------------------------------------------------------------------------
# 1.5 What will NOT be backed up
# -----------------------------------------------------------------------------

log_header "  ⚠️  WILL NOT BE BACKED UP:"
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │   ✗ Ollama models (~20GB) - will re-download on first use"
echo "  │   ✗ TLS certificates - will be regenerated by cert-manager"
echo "  │   ✗ ArgoCD admin password - will be regenerated"
echo "  │   ✗ Kubernetes resources - managed by ArgoCD/GitOps"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# -----------------------------------------------------------------------------
# 1.5 Backup destination
# -----------------------------------------------------------------------------

log_header "  📁 BACKUP DESTINATION:"
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │   $BACKUP_DIR"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# =============================================================================
# CONFIRMATION
# =============================================================================

log_header "═══════════════════════════════════════════════════════════════════"
echo ""
read -p "Proceed with backup? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warn "Backup cancelled by user."
    exit 0
fi

echo ""

# =============================================================================
# PHASE 2: EXECUTION - Perform the backup
# =============================================================================

log_header "═══════════════════════════════════════════════════════════════════"
log_header "  PHASE 2: EXECUTION - Performing backup"
log_header "═══════════════════════════════════════════════════════════════════"
echo ""

mkdir -p "$BACKUP_DIR/databases"
mkdir -p "$BACKUP_DIR/secrets"

# -----------------------------------------------------------------------------
# 2.1 Backup PostgreSQL Databases
# -----------------------------------------------------------------------------

log_info "Step 1/5: Backing up PostgreSQL databases..."

DATABASES=$(kubectl exec -n storage $POSTGRES_POD -- psql -U postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';" 2>/dev/null | tr -d ' ' | grep -v '^$')

for DB in $DATABASES; do
    echo -n "  → $DB... "
    kubectl exec -n storage $POSTGRES_POD -- pg_dump -U postgres "$DB" > "$BACKUP_DIR/databases/${DB}.sql" 2>/dev/null
    SIZE=$(ls -lh "$BACKUP_DIR/databases/${DB}.sql" | awk '{print $5}')
    echo "done ($SIZE)"
done

echo -n "  → PostgreSQL roles... "
kubectl exec -n storage $POSTGRES_POD -- pg_dumpall -U postgres --roles-only > "$BACKUP_DIR/databases/roles.sql" 2>/dev/null
echo "done"

log_success "PostgreSQL backup complete"
echo ""

# -----------------------------------------------------------------------------
# 2.2 Backup Secrets
# -----------------------------------------------------------------------------

log_info "Step 2/5: Backing up secrets..."

backup_secret() {
    local namespace=$1
    local name=$2
    local output="$BACKUP_DIR/secrets/${namespace}__${name}.yaml"
    
    echo -n "  → $namespace/$name... "
    
    if kubectl get secret -n "$namespace" "$name" &>/dev/null; then
        kubectl get secret -n "$namespace" "$name" -o yaml | \
            grep -v "resourceVersion:" | \
            grep -v "uid:" | \
            grep -v "creationTimestamp:" | \
            grep -v "selfLink:" | \
            grep -v "managedFields:" | \
            grep -v "kubectl.kubernetes.io" | \
            grep -v "last-applied-configuration" > "$output"
        echo "done"
    else
        echo "skipped (not found)"
    fi
}

for SECRET_SPEC in "${SECRETS_TO_BACKUP[@]}"; do
    NAMESPACE=$(echo "$SECRET_SPEC" | cut -d':' -f1)
    SECRET_NAME=$(echo "$SECRET_SPEC" | cut -d':' -f2)
    backup_secret "$NAMESPACE" "$SECRET_NAME"
done

log_success "Secrets backup complete"
echo ""

# -----------------------------------------------------------------------------
# 2.3 Backup Keycloak Realm (optional)
# -----------------------------------------------------------------------------

log_info "Step 3/5: Exporting Keycloak realm (optional)..."

if [ -n "$KEYCLOAK_POD" ]; then
    mkdir -p "$BACKUP_DIR/keycloak-realm"
    echo -n "  → Attempting Keycloak CLI export... "
    
    if kubectl exec -n auth $KEYCLOAK_POD -- /opt/keycloak/bin/kc.sh export \
        --dir /tmp/export \
        --realm ai-platform \
        --users realm_file 2>/dev/null; then
        kubectl cp auth/$KEYCLOAK_POD:/tmp/export/. "$BACKUP_DIR/keycloak-realm/" 2>/dev/null
        echo "done"
        log_success "Keycloak realm exported"
    else
        echo "failed (DB backup is sufficient)"
        log_warn "Keycloak CLI export failed - using database backup"
    fi
else
    log_warn "Keycloak pod not found - using database backup only"
fi
echo ""

# -----------------------------------------------------------------------------
# 2.4 Backup Qdrant Vector Database
# -----------------------------------------------------------------------------

log_info "Step 4/5: Backing up Qdrant vector database..."

if [ -n "$QDRANT_POD" ]; then
    mkdir -p "$BACKUP_DIR/qdrant"
    QDRANT_API_KEY=$(kubectl get secret -n ai-inference rag-api-qdrant-key -o jsonpath='{.data.api-key}' 2>/dev/null | base64 -d || echo "")
    
    if [ -n "$QDRANT_API_KEY" ]; then
        # Get list of collections
        COLLECTIONS=$(kubectl exec -n ai-inference $QDRANT_POD -- curl -s -H "api-key: $QDRANT_API_KEY" http://localhost:6333/collections 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4 || echo "")
        
        for COLL in $COLLECTIONS; do
            echo -n "  → Creating snapshot for collection '$COLL'... "
            
            # Create snapshot via API
            SNAPSHOT_RESULT=$(kubectl exec -n ai-inference $QDRANT_POD -- curl -s -X POST \
                -H "api-key: $QDRANT_API_KEY" \
                "http://localhost:6333/collections/$COLL/snapshots" 2>/dev/null)
            
            SNAPSHOT_NAME=$(echo "$SNAPSHOT_RESULT" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)
            
            if [ -n "$SNAPSHOT_NAME" ]; then
                # Download snapshot
                kubectl exec -n ai-inference $QDRANT_POD -- curl -s \
                    -H "api-key: $QDRANT_API_KEY" \
                    "http://localhost:6333/collections/$COLL/snapshots/$SNAPSHOT_NAME" \
                    -o "/tmp/$SNAPSHOT_NAME" 2>/dev/null
                
                # Copy to backup dir
                kubectl cp "ai-inference/$QDRANT_POD:/tmp/$SNAPSHOT_NAME" "$BACKUP_DIR/qdrant/${COLL}_${SNAPSHOT_NAME}" 2>/dev/null
                
                # Cleanup
                kubectl exec -n ai-inference $QDRANT_POD -- rm -f "/tmp/$SNAPSHOT_NAME" 2>/dev/null
                
                SIZE=$(ls -lh "$BACKUP_DIR/qdrant/${COLL}_${SNAPSHOT_NAME}" 2>/dev/null | awk '{print $5}' || echo "unknown")
                echo "done ($SIZE)"
            else
                echo "failed (snapshot creation error)"
            fi
        done
        
        if [ -z "$COLLECTIONS" ]; then
            echo "  → No collections found (empty database)"
        fi
        
        log_success "Qdrant backup complete"
    else
        log_warn "Qdrant API key not found - skipping backup"
    fi
else
    log_warn "Qdrant pod not found - skipping backup"
fi
echo ""

# -----------------------------------------------------------------------------
# 2.5 Document current state
# -----------------------------------------------------------------------------

log_info "Step 5/5: Documenting current state..."

echo -n "  → Cluster info... "
kubectl cluster-info > "$BACKUP_DIR/cluster-info.txt" 2>&1 && echo "done" || echo "failed"

echo -n "  → Nodes... "
kubectl get nodes -o wide > "$BACKUP_DIR/nodes.txt" 2>&1 && echo "done" || echo "failed"

echo -n "  → ArgoCD applications... "
kubectl get applications -n argocd -o wide > "$BACKUP_DIR/argocd-apps.txt" 2>&1 && echo "done" || echo "failed"

echo -n "  → PVCs... "
kubectl get pvc -A > "$BACKUP_DIR/pvcs.txt" 2>&1 && echo "done" || echo "failed"

echo -n "  → Ingresses... "
kubectl get ingress -A > "$BACKUP_DIR/ingresses.txt" 2>&1 && echo "done" || echo "failed"

echo -n "  → Services... "
kubectl get svc -A > "$BACKUP_DIR/services.txt" 2>&1 && echo "done" || echo "failed"

log_success "State documented"
echo ""

# -----------------------------------------------------------------------------
# Create README
# -----------------------------------------------------------------------------

cat > "$BACKUP_DIR/README.md" << EOF
# AI Security Platform Backup
**Created:** $(date)
**Host:** $(hostname)

## Contents
- \`databases/\` - PostgreSQL database dumps
- \`secrets/\` - Kubernetes secrets (credentials)
- \`keycloak-realm/\` - Keycloak realm export (if available)
- \`*.txt\` - Cluster state documentation

## Restore Procedure
1. Run \`terraform apply\` to create new cluster
2. Wait for ArgoCD to sync basic infrastructure (~10 min)
3. Run \`./scripts/restore-ai-platform.sh $BACKUP_DIR\`

## Important Notes
- TLS certificates will be regenerated (browser warning expected)
- Ollama models will need to be re-downloaded (~20GB)
- ArgoCD admin password will be new (see terraform output)
EOF

# Save backup path for restore script
echo "$BACKUP_DIR" > "$HOME/.last-ai-platform-backup"

# =============================================================================
# PHASE 3: SUMMARY
# =============================================================================

echo ""
log_header "═══════════════════════════════════════════════════════════════════"
log_header "  PHASE 3: SUMMARY"
log_header "═══════════════════════════════════════════════════════════════════"
echo ""

log_header "  📦 BACKUP COMPLETE!"
echo ""
echo "  Location: $BACKUP_DIR"
echo ""

log_header "  Databases backed up:"
ls -lh "$BACKUP_DIR/databases/" | tail -n +2 | while read -r line; do
    echo "    $line"
done

echo ""
log_header "  Secrets backed up:"
ls -lh "$BACKUP_DIR/secrets/" 2>/dev/null | tail -n +2 | while read -r line; do
    echo "    $line"
done

echo ""
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
echo "  Total backup size: $TOTAL_SIZE"

echo ""
log_header "═══════════════════════════════════════════════════════════════════"
log_header "  NEXT STEPS"
log_header "═══════════════════════════════════════════════════════════════════"
echo ""
echo "  1. Update Terraform files with OIDC configuration"
echo "     cd ~/work/ai-security-platform/phases/phase-01/terraform"
echo ""
echo "  2. Destroy current cluster"
echo "     terraform destroy -auto-approve"
echo ""
echo "  3. Recreate cluster with OIDC"
echo "     terraform init -upgrade"
echo "     terraform apply -auto-approve"
echo ""
echo "  4. Wait for ArgoCD to sync (~10 minutes)"
echo "     watch kubectl get applications -n argocd"
echo ""
echo "  5. Restore backup"
echo "     ~/work/ai-security-platform/scripts/restore-ai-platform.sh"
echo ""
echo "=========================================="
