# =============================================================================
# AI Security Platform - Phase 1: Infrastructure
# Terraform Variables
# =============================================================================

# -----------------------------------------------------------------------------
# Cluster Configuration
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the K3d cluster"
  type        = string
  default     = "ai-security-platform"
}

variable "servers" {
  description = "Number of server (control-plane) nodes"
  type        = number
  default     = 1
}

variable "agents" {
  description = "Number of agent (worker) nodes"
  type        = number
  default     = 2
}

variable "k3s_image" {
  description = "K3s image to use"
  type        = string
  default     = "rancher/k3s:v1.29.0-k3s1"
}

# -----------------------------------------------------------------------------
# Registry Configuration
# -----------------------------------------------------------------------------

variable "registry_name" {
  description = "Name of the local container registry"
  type        = string
  default     = "registry.localhost"
}

variable "registry_port" {
  description = "Port for the local container registry"
  type        = number
  default     = 5000
}

# -----------------------------------------------------------------------------
# OIDC Configuration (Keycloak SSO for kubectl)
# -----------------------------------------------------------------------------

variable "oidc_enabled" {
  description = "Enable OIDC authentication for kubectl (requires Keycloak)"
  type        = bool
  default     = true
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL (Keycloak realm)"
  type        = string
  default     = "https://auth.ai-platform.localhost/realms/ai-platform"
}

variable "oidc_client_id" {
  description = "OIDC client ID registered in Keycloak"
  type        = string
  default     = "kubernetes"
}

variable "oidc_username_claim" {
  description = "JWT claim to use as the username"
  type        = string
  default     = "preferred_username"
}

variable "oidc_groups_claim" {
  description = "JWT claim to use as groups (maps to Keycloak realm roles)"
  type        = string
  default     = "groups"
}
