# =============================================================================
# AI Security Platform - Phase 1: Infrastructure
# Terraform Outputs
# =============================================================================

output "cluster_name" {
  description = "Name of the K3d cluster"
  value       = var.cluster_name
}

output "servers" {
  description = "Number of server nodes"
  value       = var.servers
}

output "agents" {
  description = "Number of agent nodes"
  value       = var.agents
}

output "registry_url" {
  description = "URL of the local container registry"
  value       = "${var.registry_name}:${var.registry_port}"
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig"
  value       = "k3d kubeconfig get ${var.cluster_name}"
}

output "storage_class" {
  description = "Default storage class"
  value       = "local-path"
}

# -----------------------------------------------------------------------------
# OIDC Outputs
# -----------------------------------------------------------------------------

output "oidc_enabled" {
  description = "Whether OIDC is enabled for kubectl authentication"
  value       = var.oidc_enabled
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL (Keycloak realm)"
  value       = var.oidc_enabled ? var.oidc_issuer_url : "N/A - OIDC disabled"
}

output "oidc_client_id" {
  description = "OIDC client ID"
  value       = var.oidc_enabled ? var.oidc_client_id : "N/A - OIDC disabled"
}

# -----------------------------------------------------------------------------
# ArgoCD Outputs
# -----------------------------------------------------------------------------

output "argocd_url" {
  description = "ArgoCD UI URL (after port-forward)"
  value       = "https://localhost:9090"
}

output "argocd_username" {
  description = "ArgoCD admin username"
  value       = "admin"
}

output "argocd_password_command" {
  description = "Command to get ArgoCD admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "argocd_port_forward" {
  description = "Command to port-forward ArgoCD"
  value       = "kubectl port-forward svc/argocd-server -n argocd 9090:443"
}

# -----------------------------------------------------------------------------
# Application URLs (after ArgoCD sync)
# -----------------------------------------------------------------------------

output "application_urls" {
  description = "Application URLs (add to /etc/hosts: 127.0.0.1 *.ai-platform.localhost)"
  value = {
    # Core
    argocd      = "https://localhost:9090 (port-forward)"
    keycloak    = "https://auth.ai-platform.localhost"
    
    # AI Applications
    open_webui  = "https://chat.ai-platform.localhost"
    
    # Storage
    seaweedfs_ui = "https://seaweedfs.ai-platform.localhost"
    seaweedfs_s3 = "https://s3.ai-platform.localhost"
    
    # AI Data Layer
    qdrant_api       = "https://qdrant.ai-platform.localhost"
    qdrant_dashboard = "https://qdrant.ai-platform.localhost/dashboard"
    rag_api          = "https://rag.ai-platform.localhost"
    rag_swagger_ui   = "https://rag.ai-platform.localhost/docs"
  }
}

output "hosts_file_entries" {
  description = "Add these entries to /etc/hosts"
  value       = <<-EOT
    # AI Security Platform
    127.0.0.1 auth.ai-platform.localhost
    127.0.0.1 chat.ai-platform.localhost
    127.0.0.1 seaweedfs.ai-platform.localhost
    127.0.0.1 s3.ai-platform.localhost
    127.0.0.1 qdrant.ai-platform.localhost
    127.0.0.1 rag.ai-platform.localhost
  EOT
}

# -----------------------------------------------------------------------------
# Next Steps
# -----------------------------------------------------------------------------

output "next_steps" {
  description = "Next steps after cluster creation"
  value       = <<-EOT
    
    ✅ Cluster, ArgoCD, and root-app installed successfully!
    
    Cluster: ${var.cluster_name}
    Storage: local-path (K3d default)
    OIDC: ${var.oidc_enabled ? "Enabled" : "Disabled"}
    ${var.oidc_enabled ? "OIDC Issuer: ${var.oidc_issuer_url}" : ""}
    
    ═══════════════════════════════════════════════════════════════
    STEP 1: Add hosts entries
    ═══════════════════════════════════════════════════════════════
    
    echo "127.0.0.1 auth.ai-platform.localhost chat.ai-platform.localhost" | sudo tee -a /etc/hosts
    echo "127.0.0.1 seaweedfs.ai-platform.localhost s3.ai-platform.localhost" | sudo tee -a /etc/hosts
    echo "127.0.0.1 qdrant.ai-platform.localhost rag.ai-platform.localhost" | sudo tee -a /etc/hosts
    
    ═══════════════════════════════════════════════════════════════
    STEP 2: Verify deployment
    ═══════════════════════════════════════════════════════════════
    
    kubectl get nodes
    kubectl get applications -n argocd
    kubectl get pods -A
    
    ═══════════════════════════════════════════════════════════════
    STEP 3: Access applications
    ═══════════════════════════════════════════════════════════════
    
    ArgoCD:         kubectl port-forward svc/argocd-server -n argocd 9090:443
                    https://localhost:9090
    
    Keycloak:       https://auth.ai-platform.localhost
    Open WebUI:     https://chat.ai-platform.localhost
    SeaweedFS:      https://seaweedfs.ai-platform.localhost
    Qdrant:         https://qdrant.ai-platform.localhost/dashboard
    RAG API:        https://rag.ai-platform.localhost/docs
    
    ${var.oidc_enabled ? "═══════════════════════════════════════════════════════════════" : ""}
    ${var.oidc_enabled ? "OIDC Authentication (after Keycloak is deployed)" : ""}
    ${var.oidc_enabled ? "═══════════════════════════════════════════════════════════════" : ""}
    ${var.oidc_enabled ? "" : ""}
    ${var.oidc_enabled ? "kubectl krew install oidc-login" : ""}
    ${var.oidc_enabled ? "kubectl oidc-login setup --oidc-issuer-url=${var.oidc_issuer_url} --oidc-client-id=${var.oidc_client_id}" : ""}
    ${var.oidc_enabled ? "" : ""}
    ${var.oidc_enabled ? "Note: OIDC errors in API Server logs are NORMAL until Keycloak is running." : ""}
    
  EOT
}
