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

output "next_steps" {
  description = "Next steps after cluster creation"
  value       = <<-EOT
    
    ✅ Cluster and ArgoCD installed successfully!
    
    Storage: local-path (K3d default)
    Note: Longhorn not available on WSL2/Docker Desktop (shared mount limitation)
    
    Next steps:
    1. Verify cluster: kubectl get nodes
    2. Verify storage: kubectl get storageclass
    3. Verify ArgoCD: kubectl get pods -n argocd
    4. Port-forward ArgoCD: kubectl port-forward svc/argocd-server -n argocd 9090:443
    5. Open ArgoCD UI: https://localhost:9090
    6. Apply root-app: kubectl apply -f argocd/applications/root-app.yaml
    
  EOT
}
