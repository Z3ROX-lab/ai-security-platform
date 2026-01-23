# =============================================================================
# AI Security Platform - Phase 1: Infrastructure
# K3d Cluster Configuration
# =============================================================================

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    k3d = {
      source  = "pvotal-tech/k3d"
      version = "~> 0.0.7"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------

provider "k3d" {}
provider "null" {}

# -----------------------------------------------------------------------------
# Local Setup for Longhorn
# -----------------------------------------------------------------------------

resource "null_resource" "longhorn_directory" {
  provisioner "local-exec" {
    command = "mkdir -p /tmp/k3d-longhorn"
  }
}

# -----------------------------------------------------------------------------
# K3d Cluster
# -----------------------------------------------------------------------------

resource "k3d_cluster" "ai_platform" {
  depends_on = [null_resource.longhorn_directory]

  name    = var.cluster_name
  servers = var.servers
  agents  = var.agents

  image = var.k3s_image

  # ---------------------------------------------------------------------------
  # Port Mappings
  # ---------------------------------------------------------------------------
  
  # HTTPS (for ArgoCD, Keycloak, etc.)
  port {
    host_port      = 443
    container_port = 443
    node_filters   = ["loadbalancer"]
  }

  # HTTP
  port {
    host_port      = 80
    container_port = 80
    node_filters   = ["loadbalancer"]
  }

  # ArgoCD (dedicated port)
  port {
    host_port      = 8080
    container_port = 8080
    node_filters   = ["loadbalancer"]
  }

  # ---------------------------------------------------------------------------
  # Volumes for Longhorn Storage
  # ---------------------------------------------------------------------------

  volume {
    source      = "/tmp/k3d-longhorn"
    destination = "/var/lib/longhorn"
    node_filters = ["server:*", "agent:*"]
  }

  # ---------------------------------------------------------------------------
  # K3d Configuration
  # ---------------------------------------------------------------------------

  k3d {
    disable_load_balancer = false
    disable_image_volume  = false
  }

  # ---------------------------------------------------------------------------
  # Kubeconfig
  # ---------------------------------------------------------------------------

  kubeconfig {
    update_default_kubeconfig = true
    switch_current_context    = true
  }

  # ---------------------------------------------------------------------------
  # K3s Configuration
  # ---------------------------------------------------------------------------

  k3s {
    extra_args {
      arg          = "--disable=traefik"
      node_filters = ["server:*"]
    }
  }

  # ---------------------------------------------------------------------------
  # Local Registry (for custom images)
  # ---------------------------------------------------------------------------

  registries {
    create {
      name      = var.registry_name
      host_port = var.registry_port
    }
  }
}
