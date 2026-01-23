# =============================================================================
# AI Security Platform - Phase 1: Infrastructure
# K3d Cluster Configuration
# =============================================================================

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------

provider "null" {}

# -----------------------------------------------------------------------------
# K3d Cluster via CLI
# -----------------------------------------------------------------------------

resource "null_resource" "k3d_cluster" {
  # Trigger recreation if these change
  triggers = {
    cluster_name  = var.cluster_name
    servers       = var.servers
    agents        = var.agents
    k3s_image     = var.k3s_image
    registry_name = var.registry_name
    registry_port = var.registry_port
  }

  # Create cluster
  provisioner "local-exec" {
    command = <<-EOT
      # Create K3d cluster
      # Note: Using local-path storage (K3d default) instead of Longhorn
      # Longhorn requires shared mount propagation not supported on WSL2/Docker Desktop
      k3d cluster create ${var.cluster_name} \
        --servers ${var.servers} \
        --agents ${var.agents} \
        --image ${var.k3s_image} \
        --port "443:443@loadbalancer" \
        --port "80:80@loadbalancer" \
        --port "8080:8080@loadbalancer" \
        --k3s-arg "--disable=traefik@server:0" \
        --registry-create ${var.registry_name}:${var.registry_port} \
        --wait

      # Update kubeconfig
      k3d kubeconfig merge ${var.cluster_name} --kubeconfig-switch-context
    EOT
  }

  # Destroy cluster
  provisioner "local-exec" {
    when    = destroy
    command = "k3d cluster delete ${self.triggers.cluster_name} || true"
  }
}

# -----------------------------------------------------------------------------
# Wait for cluster to be ready
# -----------------------------------------------------------------------------

resource "null_resource" "wait_for_cluster" {
  depends_on = [null_resource.k3d_cluster]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for cluster to be ready..."
      kubectl wait --for=condition=Ready nodes --all --timeout=120s
      echo "Cluster is ready!"
      echo ""
      echo "Storage: Using local-path-provisioner (K3d default)"
      echo "Note: Longhorn requires shared mount propagation not available on WSL2/Docker Desktop"
    EOT
  }
}
