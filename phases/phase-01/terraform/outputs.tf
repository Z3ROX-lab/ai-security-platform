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

output "next_steps" {
  description = "Next steps after cluster creation"
  value       = <<-EOT
    
    ✅ Cluster created successfully!
    
    Storage: local-path (K3d default)
    Note: Longhorn not available on WSL2/Docker Desktop (shared mount limitation)
    
    Next steps:
    1. Verify cluster: kubectl get nodes
    2. Verify storage: kubectl get storageclass
    3. Install ArgoCD: kubectl create namespace argocd && kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    4. Get ArgoCD password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
    5. Port-forward ArgoCD: kubectl port-forward svc/argocd-server -n argocd 9090:443
    
  EOT
}
