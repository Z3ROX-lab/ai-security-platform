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
    
    Note: Longhorn not available on WSL2/Docker Desktop (shared mount limitation)
    
    Next steps:
    1. Verify cluster: kubectl get nodes
    2. Verify storage: kubectl get storageclass
    3. Verify ArgoCD: kubectl get pods -n argocd
    4. Verify apps: kubectl get applications -n argocd
    5. Port-forward ArgoCD: kubectl port-forward svc/argocd-server -n argocd 9090:443
    6. Open ArgoCD UI: https://localhost:9090
    7. Sync applications in ArgoCD UI
    ${var.oidc_enabled ? "\n    OIDC Authentication (after Keycloak is deployed):" : ""}
    ${var.oidc_enabled ? "    - Install kubelogin: kubectl krew install oidc-login" : ""}
    ${var.oidc_enabled ? "    - Setup: kubectl oidc-login setup --oidc-issuer-url=${var.oidc_issuer_url} --oidc-client-id=${var.oidc_client_id}" : ""}
    ${var.oidc_enabled ? "\n    Note: OIDC errors in API Server logs are NORMAL until Keycloak is running." : ""}
    
  EOT
}
