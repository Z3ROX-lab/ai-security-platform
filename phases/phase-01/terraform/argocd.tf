# =============================================================================
# AI Security Platform - Phase 1: Infrastructure
# ArgoCD Installation
# =============================================================================

# -----------------------------------------------------------------------------
# ArgoCD Installation via kubectl
# -----------------------------------------------------------------------------

resource "null_resource" "argocd_install" {
  depends_on = [null_resource.wait_for_cluster]

  triggers = {
    cluster_name = var.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Installing ArgoCD..."
      
      # Create namespace
      kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
      
      # Install ArgoCD
      kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
      
      # Wait for ArgoCD to be ready
      echo "Waiting for ArgoCD pods to be ready..."
      kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
      
      echo "ArgoCD installed successfully!"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete namespace argocd --ignore-not-found || true"
  }
}

# -----------------------------------------------------------------------------
# Get ArgoCD Admin Password
# -----------------------------------------------------------------------------

resource "null_resource" "argocd_password" {
  depends_on = [null_resource.argocd_install]

  provisioner "local-exec" {
    command = <<-EOT
      echo ""
      echo "=============================================="
      echo "ArgoCD Admin Credentials"
      echo "=============================================="
      echo "Username: admin"
      echo -n "Password: "
      kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
      echo ""
      echo "=============================================="
      echo ""
      echo "To access ArgoCD UI:"
      echo "  kubectl port-forward svc/argocd-server -n argocd 9090:443"
      echo "  Open: https://localhost:9090"
      echo ""
    EOT
  }
}

# -----------------------------------------------------------------------------
# Deploy Root App (App-of-Apps pattern)
# -----------------------------------------------------------------------------

resource "null_resource" "argocd_root_app" {
  depends_on = [null_resource.argocd_password]

  triggers = {
    cluster_name = var.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Deploying ArgoCD root-app..."
      
      # Wait a bit for ArgoCD to be fully ready
      sleep 10
      
      # Apply root-app from the repository
      # Note: root-app.yaml is outside applications/ to avoid self-detection
      kubectl apply -f ${path.module}/../../../argocd/root-app.yaml
      
      echo "Root-app deployed! ArgoCD will now manage all applications in argocd/applications/"
    EOT
  }
}
