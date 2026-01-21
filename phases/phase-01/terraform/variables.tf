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
