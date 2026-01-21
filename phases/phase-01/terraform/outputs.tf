# =============================================================================
# AI Security Platform - Phase 1: Infrastructure
# Terraform Outputs
# =============================================================================

output "cluster_name" {
  description = "Name of the K3d cluster"
  value       = k3d_cluster.ai_platform.name
}

output "servers" {
  description = "Number of server nodes"
  value       = k3d_cluster.ai_platform.servers
}

output "agents" {
  description = "Number of agent nodes"
  value       = k3d_cluster.ai_platform.agents
}

output "registry_url" {
  description = "URL of the local container registry"
  value       = "${var.registry_name}:${var.registry_port}"
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig"
  value       = "k3d kubeconfig get ${k3d_cluster.ai_platform.name}"
}

output "next_steps" {
  description = "Next steps after cluster creation"
  value       = <<-EOT
    
    ✅ Cluster created successfully!
    
    Next steps:
    1. Verify cluster: kubectl get nodes
    2. Install ArgoCD: kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    3. Get ArgoCD password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
    4. Access ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443
    
  EOT
}
