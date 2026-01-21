#!/bin/bash
# =============================================================================
# AI Security Platform - Phase 1: Bootstrap Script
# Automated setup for K3d cluster and ArgoCD
# =============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Pre-flight Checks
# -----------------------------------------------------------------------------

echo ""
echo "=========================================="
echo "  AI Security Platform - Phase 1 Setup"
echo "=========================================="
echo ""

log_info "Checking prerequisites..."

check_command docker
check_command terraform
check_command k3d
check_command kubectl
check_command helm

log_success "All prerequisites installed!"

# Check Docker is running
if ! docker info &> /dev/null; then
    log_error "Docker is not running. Please start Docker Desktop."
    exit 1
fi

log_success "Docker is running!"

# -----------------------------------------------------------------------------
# Step 1: Terraform - Create K3d Cluster
# -----------------------------------------------------------------------------

echo ""
log_info "Step 1: Creating K3d cluster with Terraform..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

cd "$TERRAFORM_DIR"

# Initialize Terraform
log_info "Running terraform init..."
terraform init

# Apply Terraform
log_info "Running terraform apply..."
terraform apply -auto-approve

log_success "K3d cluster created!"

# -----------------------------------------------------------------------------
# Step 2: Verify Cluster
# -----------------------------------------------------------------------------

echo ""
log_info "Step 2: Verifying cluster..."
echo ""

# Wait for nodes to be ready
log_info "Waiting for nodes to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

log_success "All nodes are ready!"

kubectl get nodes

# -----------------------------------------------------------------------------
# Step 3: Install ArgoCD
# -----------------------------------------------------------------------------

echo ""
log_info "Step 3: Installing ArgoCD..."
echo ""

# Create namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
log_info "Applying ArgoCD manifests..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
log_info "Waiting for ArgoCD to be ready (this may take 2-3 minutes)..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

log_success "ArgoCD installed!"

# -----------------------------------------------------------------------------
# Step 4: Get ArgoCD Credentials
# -----------------------------------------------------------------------------

echo ""
log_info "Step 4: Retrieving ArgoCD credentials..."
echo ""

# Wait for secret to be created
sleep 5

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

echo ""
echo "=========================================="
echo "  🎉 Phase 1 Setup Complete!"
echo "=========================================="
echo ""
echo "Cluster Information:"
echo "  - Name: ai-security-platform"
echo "  - Nodes: $(kubectl get nodes --no-headers | wc -l)"
echo "  - Registry: registry.localhost:5000"
echo ""
echo "ArgoCD Access:"
echo "  - URL: https://localhost:8080"
echo "  - Username: admin"
echo "  - Password: $ARGOCD_PASSWORD"
echo ""
echo "Next steps:"
echo "  1. Start port-forward:"
echo "     kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "  2. Open in browser:"
echo "     https://localhost:8080"
echo ""
echo "  3. Login with credentials above"
echo ""
echo "=========================================="
