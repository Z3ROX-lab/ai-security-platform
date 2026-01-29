# =============================================================================
# AI Security Platform - Phase 1: Infrastructure
# K3d Cluster Configuration with OIDC Support
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
# K3d Cluster via CLI (with OIDC for Keycloak SSO)
# -----------------------------------------------------------------------------

resource "null_resource" "k3d_cluster" {
  # Trigger recreation if these change
  triggers = {
    cluster_name      = var.cluster_name
    servers           = var.servers
    agents            = var.agents
    k3s_image         = var.k3s_image
    registry_name     = var.registry_name
    registry_port     = var.registry_port
    oidc_enabled      = var.oidc_enabled
    oidc_issuer_url   = var.oidc_issuer_url
    oidc_client_id    = var.oidc_client_id
  }

  # Create cluster
  provisioner "local-exec" {
    command = <<-EOT
      # Create K3d cluster with OIDC support
      k3d cluster create ${var.cluster_name} \
        --servers ${var.servers} \
        --agents ${var.agents} \
        --image ${var.k3s_image} \
        --port "443:443@loadbalancer" \
        --port "80:80@loadbalancer" \
        --port "8080:8080@loadbalancer" \
        --k3s-arg "--disable=traefik@server:0" \
        ${var.oidc_enabled ? "--k3s-arg=\"--kube-apiserver-arg=oidc-issuer-url=${var.oidc_issuer_url}@server:0\"" : ""} \
        ${var.oidc_enabled ? "--k3s-arg=\"--kube-apiserver-arg=oidc-client-id=${var.oidc_client_id}@server:0\"" : ""} \
        ${var.oidc_enabled ? "--k3s-arg=\"--kube-apiserver-arg=oidc-username-claim=${var.oidc_username_claim}@server:0\"" : ""} \
        ${var.oidc_enabled ? "--k3s-arg=\"--kube-apiserver-arg=oidc-groups-claim=${var.oidc_groups_claim}@server:0\"" : ""} \
        ${var.oidc_enabled ? "--k3s-arg=\"--kube-apiserver-arg=oidc-username-prefix=-@server:0\"" : ""} \
        ${var.oidc_enabled ? "--k3s-arg=\"--kube-apiserver-arg=oidc-groups-prefix=@server:0\"" : ""} \
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
      echo "Note: Longhorn not available on WSL2/Docker Desktop (shared mount limitation)"
      ${var.oidc_enabled ? "echo \"\"" : ""}
      ${var.oidc_enabled ? "echo \"OIDC Configuration:\"" : ""}
      ${var.oidc_enabled ? "echo \"  Issuer: ${var.oidc_issuer_url}\"" : ""}
      ${var.oidc_enabled ? "echo \"  Client ID: ${var.oidc_client_id}\"" : ""}
      ${var.oidc_enabled ? "echo \"  Groups Claim: ${var.oidc_groups_claim}\"" : ""}
      ${var.oidc_enabled ? "echo \"\"" : ""}
      ${var.oidc_enabled ? "echo \"NOTE: OIDC errors in logs are NORMAL until Keycloak is deployed.\"" : ""}
      ${var.oidc_enabled ? "echo \"      kubectl with certificate auth works immediately.\"" : ""}
    EOT
  }
}
