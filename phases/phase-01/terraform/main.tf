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
  }
}

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------

provider "k3d" {}

# -----------------------------------------------------------------------------
# K3d Cluster
# -----------------------------------------------------------------------------

resource "k3d_cluster" "ai_platform" {
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
