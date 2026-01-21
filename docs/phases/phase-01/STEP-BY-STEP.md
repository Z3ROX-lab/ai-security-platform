# Phase 1: Step-by-Step Guide

## Step 1: Verify Prerequisites

Before starting, confirm all tools are installed:
```bash
# Run these commands and verify versions
docker --version          # Docker version 24+
terraform --version       # Terraform v1.0+
k3d --version            # k3d version v5.0+
kubectl version --client  # Client Version: v1.28+
helm version             # v3.0+
```

Expected output: All commands return version numbers without errors.

---

## Step 2: Understand the Terraform Configuration

### 2.1 Main Configuration (main.tf)

The main.tf file defines:
- **Terraform providers**: K3d provider to manage the cluster
- **K3d cluster resource**: The actual Kubernetes cluster
- **Configuration options**: Ports, registry, K3s arguments

Key concepts:
```hcl
# Provider tells Terraform HOW to create resources
provider "k3d" {}

# Resource defines WHAT to create
resource "k3d_cluster" "ai_platform" {
  name    = "ai-security-platform"  # Cluster name
  servers = 1                        # Control plane nodes
  agents  = 2                        # Worker nodes
}
```

### 2.2 Variables (variables.tf)

Variables make configuration reusable:
```hcl
variable "cluster_name" {
  default = "ai-security-platform"
}
```

### 2.3 Outputs (outputs.tf)

Outputs display useful information after creation:
```hcl
output "cluster_name" {
  value = k3d_cluster.ai_platform.name
}
```

---

## Step 3: Create the Cluster with Terraform

### 3.1 Navigate to Terraform directory
```bash
cd ~/work/ai-security-platform/phases/phase-01/terraform
```

### 3.2 Initialize Terraform
```bash
terraform init
```

**What happens:**
- Downloads the K3d provider
- Creates `.terraform/` directory
- Creates `.terraform.lock.hcl` (lock file)

**Expected output:**
```
Terraform has been successfully initialized!
```

### 3.3 Preview the changes
```bash
terraform plan
```

**What happens:**
- Shows what Terraform WILL create
- No actual changes made yet

**Expected output:**
```
Plan: 1 to add, 0 to change, 0 to destroy.
```

### 3.4 Create the cluster
```bash
terraform apply
```

- Type `yes` when prompted
- Wait ~20-30 seconds

**Expected output:**
```
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

cluster_name = "ai-security-platform"
```

### 3.5 Verify the cluster
```bash
# Check K3d sees the cluster
k3d cluster list

# Check kubectl can connect
kubectl get nodes

# Check system pods are running
kubectl get pods -A
```

**Expected output:**
```
NAME                    STATUS   ROLES                  AGE
k3d-ai-security-platform-server-0   Ready    control-plane,master   1m
k3d-ai-security-platform-agent-0    Ready    <none>                 1m
k3d-ai-security-platform-agent-1    Ready    <none>                 1m
```

---

## Step 4: Install ArgoCD

### 4.1 Create ArgoCD namespace
```bash
kubectl create namespace argocd
```

### 4.2 Install ArgoCD
```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**What happens:**
- Deploys ArgoCD components (server, repo-server, controller, etc.)
- Creates services, deployments, configmaps

### 4.3 Wait for ArgoCD to be ready
```bash
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

Or watch the pods:
```bash
kubectl get pods -n argocd -w
```

Press `Ctrl+C` when all pods show `Running` status.

### 4.4 Get ArgoCD admin password
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

**Save this password!** You'll need it to login.

### 4.5 Access ArgoCD UI

Option A: Port-forward (simple)
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then open: https://localhost:8080

Option B: Keep port-forward running in background
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
```

### 4.6 Login to ArgoCD

- **URL**: https://localhost:8080
- **Username**: `admin`
- **Password**: (from step 4.4)

Accept the self-signed certificate warning.

---

## Step 5: Explore ArgoCD UI

### 5.1 Dashboard Overview

The main dashboard shows:
- **Applications**: List of deployed apps (empty for now)
- **Sync Status**: Whether apps match Git
- **Health Status**: Whether apps are running correctly

### 5.2 Settings

Click the gear icon to see:
- **Clusters**: Your K3d cluster (in-cluster)
- **Repositories**: Git repos ArgoCD can access
- **Projects**: Logical grouping of applications

### 5.3 User Info

Click the user icon to see:
- Current user (admin)
- Logout option

---

## Step 6: Verify Everything Works

### 6.1 Cluster health check
```bash
# All nodes ready?
kubectl get nodes

# All system pods running?
kubectl get pods -A

# ArgoCD pods running?
kubectl get pods -n argocd
```

### 6.2 ArgoCD CLI (optional but useful)
```bash
# Install ArgoCD CLI
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Login via CLI
argocd login localhost:8080 --insecure --username admin --password <your-password>

# Check cluster connection
argocd cluster list
```

---

## Step 7: Commit Your Progress
```bash
cd ~/work/ai-security-platform

# Check what we've created
git status

# Add all files
git add .

# Commit
git commit -m "Phase 1: Infrastructure foundation with K3d and ArgoCD

- Terraform configuration for K3d cluster
- ArgoCD installation manifests
- Documentation and ADRs"

# Push to GitHub
git push origin main
```

---

## 🎉 Phase 1 Complete!

### What you've accomplished:
- ✅ K3d cluster running with Terraform IaC
- ✅ ArgoCD installed and accessible
- ✅ GitOps foundation ready
- ✅ All documentation committed

### Skills demonstrated:
- Infrastructure as Code (Terraform)
- Kubernetes cluster management
- GitOps tooling (ArgoCD)
- Version control practices

### Next steps:
- Phase 2: Storage Layer (PostgreSQL, MinIO)
- Then: Phase 3: IAM with Keycloak

---

## 🔧 Troubleshooting

### Problem: Terraform init fails
```bash
# Check internet connectivity
curl -I https://registry.terraform.io

# Clear and retry
rm -rf .terraform
terraform init
```

### Problem: Cluster creation fails
```bash
# Check Docker is running
docker ps

# Check for existing clusters
k3d cluster list

# Delete if exists and retry
k3d cluster delete ai-security-platform
terraform apply
```

### Problem: kubectl can't connect
```bash
# Check kubeconfig
kubectl config current-context

# Should show: k3d-ai-security-platform
# If not, K3d should have set it automatically. Try:
k3d kubeconfig merge ai-security-platform --kubeconfig-switch-context
```

### Problem: ArgoCD UI not accessible
```bash
# Check pods are running
kubectl get pods -n argocd

# Check service exists
kubectl get svc -n argocd

# Restart port-forward
pkill -f "port-forward.*argocd"
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Problem: Can't get ArgoCD password
```bash
# Check secret exists
kubectl get secrets -n argocd

# If argocd-initial-admin-secret doesn't exist, ArgoCD may have issues
kubectl describe deployment argocd-server -n argocd
```
