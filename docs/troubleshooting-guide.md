# AI Security Platform - Troubleshooting Guide

## Overview

This guide covers common issues encountered during platform operation and their solutions.

---

## 1. Kyverno Webhook Deadlock

### Symptoms
- Pods stuck in `Pending` state
- Error: `admission webhook "mutate.kyverno.svc-fail" denied the request`
- Error: `no endpoints available for service "kyverno-svc"`
- ArgoCD can't sync any applications

### Root Cause
Kyverno crashed but its webhooks are still active, blocking all pod creation.

### Solution

```bash
# Step 1: Remove webhooks
kubectl delete validatingwebhookconfiguration -l app.kubernetes.io/instance=kyverno
kubectl delete mutatingwebhookconfiguration -l app.kubernetes.io/instance=kyverno

# Step 2: Restart blocked deployments
kubectl rollout restart deployment <name> -n <namespace>

# Step 3: Restart Kyverno
kubectl delete pods -n kyverno --all

# Step 4: Verify
kubectl get pods -n kyverno -w
```

### Prevention
Ensure system namespaces are excluded from restrictive policies:

```yaml
exclude:
  any:
  - resources:
      namespaces:
        - kube-system
        - argocd
        - kyverno
        - cert-manager
        - traefik
        - falco
        - cnpg-system
        - observability
        - storage
```

---

## 2. ArgoCD Server Not Starting

### Symptoms
- `argocd-server` pod doesn't exist
- Deployment shows `0/1` replicas
- `kubectl get deployment argocd-server -n argocd` shows AVAILABLE = 0

### Diagnosis

```bash
# Check deployment status
kubectl describe deployment argocd-server -n argocd | tail -20

# Look for PolicyViolation events
kubectl get events -n argocd --sort-by='.lastTimestamp' | grep -i policy
```

### Solution

```bash
# If Kyverno is blocking
kubectl delete validatingwebhookconfiguration kyverno-resource-validating-webhook-cfg
kubectl delete mutatingwebhookconfiguration kyverno-resource-mutating-webhook-cfg

# Force pod recreation
kubectl delete rs -n argocd -l app.kubernetes.io/name=argocd-server
kubectl get pods -n argocd -w
```

---

## 3. Traefik Can't Reach API Server

### Symptoms
- `404 page not found` for all ingresses
- Traefik logs show: `dial tcp 10.43.0.1:443: connect: connection refused`

### Diagnosis

```bash
kubectl logs -n traefik deploy/traefik --tail=20
```

### Solution

```bash
# Restart the cluster
k3d cluster stop ai-security-platform
k3d cluster start ai-security-platform

# Wait for all pods
kubectl get pods -A -w
```

---

## 4. DNS Resolution Issues

### Symptoms
- ArgoCD can't reach GitHub: `lookup github.com: server misbehaving`
- Services can't resolve internal names

### Solution

```bash
# Restart CoreDNS
kubectl rollout restart deployment coredns -n kube-system

# Wait 30 seconds, then test
kubectl run test-dns --rm -it --image=busybox -- nslookup github.com
```

---

## 5. RAM Exhaustion

### Symptoms
- WSL2/Ubuntu crashes
- `free -h` shows < 500Mi available
- Pods in `OOMKilled` or `CrashLoopBackOff`

### Diagnosis

```bash
free -h
kubectl top nodes
kubectl top pods -A --sort-by=memory | head -20
```

### Immediate Actions

```bash
# Scale down non-essential services
kubectl scale deployment falco-falcosidekick-ui -n falco --replicas=0
kubectl scale deployment -n kyverno --all --replicas=0

# Delete failed pods
kubectl delete pods -A --field-selector=status.phase=Failed
```

### Prevention
Create `C:\Users\<username>\.wslconfig`:

```ini
[wsl2]
memory=16GB
processors=4
swap=4GB
```

Then restart WSL:
```powershell
wsl --shutdown
```

---

## 6. Docker Disk Full

### Symptoms
- `No space left on device` errors
- Docker images won't pull
- Windows C:\ drive nearly full

### Diagnosis

```bash
docker system df
```

### Solution

```bash
# Remove unused volumes
docker volume prune -f

# Remove unused images
docker image prune -a -f

# Compact vhdx (Windows PowerShell)
wsl --shutdown
# Open diskpart
select vdisk file="C:\Users\<user>\AppData\Local\Docker\wsl\data\ext4.vhdx"
compact vdisk
detach vdisk
```

---

## 7. Falcosidekick-UI Crash Loop

### Symptoms
- `falco-falcosidekick-ui` pods in `Init:Error` or `CrashLoopBackOff`

### Root Cause
Redis dependency or certificate issues in WSL2/K3d environment.

### Solution

```bash
# Disable UI (optional - core Falco still works)
kubectl scale deployment -n falco falco-falcosidekick-ui --replicas=0
```

Falco alerts are still visible in:
- Grafana + Loki dashboards
- `kubectl logs -n falco -l app.kubernetes.io/name=falco`

---

## 8. Application Stuck in "Unknown" or "OutOfSync"

### Diagnosis

```bash
kubectl get applications -n argocd
kubectl describe application <name> -n argocd | tail -30
```

### Solution

```bash
# Force refresh
kubectl patch application <name> -n argocd --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Force sync
kubectl patch application <name> -n argocd --type merge \
  -p '{"operation":{"sync":{"prune":true}}}'

# Or via CLI
argocd app sync <name> --force
```

---

## 9. Certificate Issues

### Symptoms
- `x509: certificate signed by unknown authority`
- TLS handshake failures

### Solution

```bash
# Check cert-manager
kubectl get pods -n cert-manager
kubectl get certificates -A
kubectl get clusterissuers

# Renew certificate
kubectl delete certificate <name> -n <namespace>
# cert-manager will auto-recreate
```

---

## 10. Quick Health Check

Run this to get a full status:

```bash
#!/bin/bash
echo "=== Cluster Health ==="
kubectl get nodes
echo ""
echo "=== RAM Usage ==="
free -h
echo ""
echo "=== ArgoCD Apps ==="
kubectl get applications -n argocd
echo ""
echo "=== Failed Pods ==="
kubectl get pods -A | grep -v Running | grep -v Completed
echo ""
echo "=== Recent Events ==="
kubectl get events -A --sort-by='.lastTimestamp' | tail -10
```

---

## Emergency Recovery

If the cluster is completely broken:

```bash
# 1. Stop cluster
k3d cluster stop ai-security-platform

# 2. Start fresh
k3d cluster start ai-security-platform

# 3. Wait for system pods
sleep 60
kubectl get pods -n kube-system

# 4. Remove Kyverno webhooks (preventive)
kubectl delete validatingwebhookconfiguration -l app.kubernetes.io/instance=kyverno
kubectl delete mutatingwebhookconfiguration -l app.kubernetes.io/instance=kyverno

# 5. Check ArgoCD
kubectl get pods -n argocd
```

---

## Contact & Resources

- [Kyverno Troubleshooting](https://kyverno.io/docs/troubleshooting/)
- [ArgoCD Troubleshooting](https://argo-cd.readthedocs.io/en/stable/operator-manual/troubleshooting/)
- [K3d Issues](https://github.com/k3d-io/k3d/issues)
