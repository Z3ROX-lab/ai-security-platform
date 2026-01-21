# ADR-001: Kubernetes Distribution

## Status
**Accepted**

## Date
2025-01-20

## Context

We need to select a Kubernetes distribution for the AI Security Platform home lab. The platform will run on a Windows 11 machine with 32GB RAM using WSL2 and Docker Desktop.

### Requirements
- Must run on WSL2 + Docker Desktop
- Must support multi-node simulation
- Must be lightweight (preserve RAM for AI workloads)
- Must be production-like for learning purposes
- Must have Terraform provider for IaC

### Options Considered

| Option | Description |
|--------|-------------|
| **K3d** | K3s in Docker - lightweight, Rancher-backed |
| **Kind** | Kubernetes in Docker - vanilla kubeadm |
| **Minikube** | VM-based local Kubernetes |
| **OKD/CRC** | OpenShift local - CodeReady Containers |

## Decision

**We chose K3d** for the following reasons:

### Comparison Matrix

| Criteria | K3d | Kind | Minikube | OKD/CRC |
|----------|-----|------|----------|---------|
| Startup time | ~20s ⚡ | ~45s | ~90s | ~10min |
| RAM (idle, 3 nodes) | ~1.2GB | ~1.8GB | ~2.5GB | ~16GB |
| WSL2 + Docker | ✅ Native | ✅ Good | ⚠️ Complex | ⚠️ Heavy |
| Terraform provider | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No |
| CNCF Certified | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| Built-in LoadBalancer | ✅ Yes | ❌ No | ❌ No | ✅ Yes |
| Built-in Registry | ✅ Yes | ❌ Manual | ❌ Manual | ✅ Yes |

### Key Factors

1. **RAM Efficiency**: With 32GB total and AI workloads (Ollama ~8-10GB), every GB matters. K3d is the most lightweight option.

2. **Fast Iteration**: 20-second startup enables rapid rebuild during learning. Kind at 45s adds friction.

3. **Built-in Features**: K3d includes ServiceLB and local registry out of the box, reducing configuration overhead.

4. **Terraform Support**: The `pvotal-tech/k3d` provider enables Infrastructure as Code, matching enterprise patterns.

5. **Production Parity**: While based on K3s (not kubeadm), all Kubernetes concepts (Pods, Services, RBAC, NetworkPolicies) are identical.

## Consequences

### Positive
- Maximum RAM available for AI workloads
- Fast cluster recreation during development
- Simple local registry for custom images
- IaC with Terraform from day one

### Negative
- K3s differs slightly from vanilla Kubernetes (uses containerd, SQLite by default)
- Less exposure to kubeadm-based clusters (EKS, AKS, GKE)

### Mitigation
- Document K3s-specific behaviors
- Use standard Kubernetes APIs wherever possible
- Enterprise experience (Nokia, GTT) already covers OpenShift/vanilla K8s

## References
- [K3d Documentation](https://k3d.io/)
- [K3d Terraform Provider](https://registry.terraform.io/providers/pvotal-tech/k3d/latest)
- [K3s vs K8s](https://docs.k3s.io/)
