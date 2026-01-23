# =============================================================================
# AI Security Platform - Phase 1: Infrastructure
# K3d Cluster Configuration (using k3d CLI for shared volume support)
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
# K3d Cluster via CLI (supports shared volumes for Longhorn)
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
      # Create Longhorn directory
      mkdir -p /tmp/k3d-longhorn
      chmod 777 /tmp/k3d-longhorn

      # Create K3d cluster with shared volume for Longhorn
      k3d cluster create ${var.cluster_name} \
        --servers ${var.servers} \
        --agents ${var.agents} \
        --image ${var.k3s_image} \
        --volume /tmp/k3d-longhorn:/var/lib/longhorn:shared \
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
    EOT
  }
}
