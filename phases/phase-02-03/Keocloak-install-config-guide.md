# Keycloak Installation & Configuration Guide

## Overview

Keycloak is the IAM (Identity and Access Management) solution for the AI Security Platform, providing:
- OIDC/OAuth2 authentication
- Single Sign-On (SSO)
- Role-Based Access Control (RBAC)
- User federation and identity brokering

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      KEYCLOAK ARCHITECTURE                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  EXTERNAL ACCESS                                                         │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  https://auth.ai-platform.localhost                                 │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                │                                         │
│                                ▼                                         │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                         TRAEFIK                                     │ │
│  │                   (TLS termination)                                 │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                │                                         │
│                                ▼                                         │
│  NAMESPACE: auth                                                         │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                        KEYCLOAK                                     │ │
│  │                                                                      │ │
│  │  ┌──────────────────┐    ┌──────────────────┐                      │ │
│  │  │   Admin Console  │    │   User Login     │                      │ │
│  │  │   /admin         │    │   /realms/{name} │                      │ │
│  │  └──────────────────┘    └──────────────────┘                      │ │
│  │                                                                      │ │
│  │  Image: quay.io/keycloak/keycloak:26.x (Quarkus-based)            │ │
│  │  Port: 8080                                                         │ │
│  │  Resources: 512Mi-768Mi RAM                                        │ │
│  │                                                                      │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                │                                         │
│                                ▼                                         │
│  NAMESPACE: storage                                                      │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                     POSTGRESQL (CNPG)                               │ │
│  │                                                                      │ │
│  │  Database: keycloak                                                 │ │
│  │  User: keycloak                                                     │ │
│  │  Service: postgresql-cluster-rw.storage.svc:5432                   │ │
│  │                                                                      │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

Before installing Keycloak, ensure:

| Component | Status | Verification |
|-----------|--------|--------------|
| PostgreSQL (CNPG) | ✅ Running | `kubectl get pods -n storage` |
| Traefik | ✅ Running | `kubectl get pods -n traefik` |
| Database `keycloak` | ✅ Created | `kubectl exec -it postgresql-cluster-1 -n storage -- psql -U postgres -c "\l"` |

---

## Step 1: Create Database User

The database was created by `postInitSQL` in PostgreSQL values. Now create a dedicated user:

```bash
kubectl exec -it postgresql-cluster-1 -n storage -- psql -U postgres -c \
  "CREATE USER keycloak WITH PASSWORD 'keycloak-secret-pwd'; \
   GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak; \
   ALTER DATABASE keycloak OWNER TO keycloak;"
```

Verify:
```bash
kubectl exec -it postgresql-cluster-1 -n storage -- psql -U postgres -c "\du"
```

---

## Step 2: Create Kubernetes Namespace and Secret

```bash
# Create namespace
kubectl create namespace auth

# Create secret for database credentials
kubectl create secret generic keycloak-db-secret -n auth \
  --from-literal=username=keycloak \
  --from-literal=password=keycloak-secret-pwd

# Verify
kubectl get secret -n auth
```

---

## Step 3: Helm Chart Selection

### Why Codecentric keycloakx?

| Chart | Status | Image | Recommendation |
|-------|--------|-------|----------------|
| **Bitnami** | Paid since Aug 2025 | bitnami/keycloak (outdated) | ❌ Avoid |
| **Codecentric keycloakx** | Active, maintained | quay.io/keycloak/keycloak (official) | ✅ **Selected** |
| **Keycloak Operator** | Official | Official | Complex for home lab |

### Add Helm Repository

```bash
helm repo add codecentric https://codecentric.github.io/helm-charts
helm repo update

# Check available versions
helm search repo codecentric/keycloakx --versions | head -5
```

### Explore Chart Values

```bash
# View all available options
helm show values codecentric/keycloakx > /tmp/keycloakx-values.yaml

# Key sections to review
grep -A 30 "database:" /tmp/keycloakx-values.yaml
grep -A 20 "ingress:" /tmp/keycloakx-values.yaml
grep -A 10 "resources:" /tmp/keycloakx-values.yaml
```

---

## Step 4: Create ArgoCD Application

### Directory Structure

```
argocd/applications/auth/keycloak/
├── application.yaml    # ArgoCD Application manifest
└── values.yaml         # Helm values overrides
```

### application.yaml

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: keycloak
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  sources:
    - repoURL: https://codecentric.github.io/helm-charts
      chart: keycloakx
      targetRevision: 7.1.7
      helm:
        valueFiles:
          - $values/argocd/applications/auth/keycloak/values.yaml
    - repoURL: https://github.com/Z3ROX-lab/ai-security-platform
      targetRevision: master
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: auth
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

### values.yaml

```yaml
# Keycloak values for AI Security Platform (Home Lab)
# Chart: codecentric/keycloakx 7.1.7

# Single replica for home lab
replicas: 1

# Database configuration (external PostgreSQL via CNPG)
database:
  vendor: postgres
  hostname: postgresql-cluster-rw.storage.svc
  port: 5432
  database: keycloak
  username: keycloak
  existingSecret: keycloak-db-secret
  existingSecretKey: password

# Proxy settings (Traefik handles TLS termination)
proxy:
  enabled: true
  mode: edge

# HTTP settings
http:
  relativePath: "/"

# Health & metrics
health:
  enabled: true
metrics:
  enabled: true

# Ingress via Traefik
ingress:
  enabled: true
  ingressClassName: traefik
  rules:
    - host: auth.ai-platform.localhost
      paths:
        - path: /
          pathType: Prefix

# Resources for home lab
resources:
  requests:
    cpu: "250m"
    memory: "512Mi"
  limits:
    cpu: "1000m"
    memory: "768Mi"

# Admin credentials (change in production!)
extraEnv: |
  - name: KEYCLOAK_ADMIN
    value: admin
  - name: KEYCLOAK_ADMIN_PASSWORD
    value: admin123
  - name: KC_HOSTNAME
    value: auth.ai-platform.localhost
  - name: KC_HOSTNAME_STRICT
    value: "false"
  - name: KC_HTTP_ENABLED
    value: "true"
```

### Key Configuration Explained

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `database.vendor` | postgres | Database type |
| `database.hostname` | postgresql-cluster-rw.storage.svc | CNPG primary service |
| `database.existingSecret` | keycloak-db-secret | K8s secret with credentials |
| `proxy.mode` | edge | Traefik terminates TLS |
| `http.relativePath` | "/" | No /auth prefix (Keycloak 26+) |
| `ingress.ingressClassName` | traefik | Use Traefik ingress controller |

---

## Step 5: Deploy via GitOps

```bash
# Create directory
mkdir -p argocd/applications/auth/keycloak

# Create files (application.yaml and values.yaml as above)

# Commit and push
git add argocd/applications/auth/keycloak/
git commit -m "feat: add Keycloak IAM with external PostgreSQL"
git push

# Refresh root-app to detect new application
kubectl patch application root-app -n argocd --type merge \
  -p '{"metadata": {"annotations": {"argocd.argoproj.io/refresh": "hard"}}}'

# Watch deployment
kubectl get pods -n auth -w
```

---

## Step 6: Configure Local DNS

Add to your hosts file:

**Linux/Mac:** `/etc/hosts`
**Windows (WSL2):** `/etc/hosts` in WSL AND `C:\Windows\System32\drivers\etc\hosts`

```
127.0.0.1 auth.ai-platform.localhost
127.0.0.1 chat.ai-platform.localhost
127.0.0.1 argocd.ai-platform.localhost
```

---

## Step 7: Verify Deployment

### Check Pods

```bash
kubectl get pods -n auth
```

Expected:
```
NAME                        READY   STATUS    RESTARTS   AGE
keycloak-0                  1/1     Running   0          2m
```

### Check Logs

```bash
kubectl logs -n auth -l app.kubernetes.io/name=keycloakx -f
```

Look for:
```
Keycloak 26.x.x on JVM (powered by Quarkus)
...
Listening on: http://0.0.0.0:8080
```

### Test Access

```bash
curl -v http://auth.ai-platform.localhost 2>&1 | head -30
```

---

## Step 8: Access Admin Console

1. Open browser: **http://auth.ai-platform.localhost**
2. Click **Administration Console**
3. Login:
   - **Username:** admin
   - **Password:** admin123

---

## Step 9: Initial Keycloak Configuration

### 9.1 Create AI Platform Realm

1. Hover over **master** (top-left dropdown)
2. Click **Create Realm**
3. Enter:
   - **Realm name:** `ai-platform`
4. Click **Create**

### 9.2 Create Roles

Navigate to **Realm roles** → **Create role**

| Role | Description |
|------|-------------|
| `platform-admin` | Full platform access |
| `ai-engineer` | AI/ML operations, model management |
| `security-auditor` | Read-only security dashboards |
| `viewer` | Read-only access |

### 9.3 Create OIDC Clients

#### Client: ArgoCD

Navigate to **Clients** → **Create client**

| Field | Value |
|-------|-------|
| Client type | OpenID Connect |
| Client ID | `argocd` |
| Name | ArgoCD |
| Root URL | `https://argocd.ai-platform.localhost` |
| Valid redirect URIs | `https://argocd.ai-platform.localhost/auth/callback` |
| Web origins | `https://argocd.ai-platform.localhost` |

Enable: **Client authentication** = ON

Save and go to **Credentials** tab to copy the client secret.

#### Client: Open WebUI

| Field | Value |
|-------|-------|
| Client type | OpenID Connect |
| Client ID | `open-webui` |
| Name | Open WebUI |
| Root URL | `https://chat.ai-platform.localhost` |
| Valid redirect URIs | `https://chat.ai-platform.localhost/*` |
| Web origins | `https://chat.ai-platform.localhost` |

#### Client: Grafana

| Field | Value |
|-------|-------|
| Client type | OpenID Connect |
| Client ID | `grafana` |
| Name | Grafana |
| Root URL | `https://grafana.ai-platform.localhost` |
| Valid redirect URIs | `https://grafana.ai-platform.localhost/login/generic_oauth` |

### 9.4 Create Test User

Navigate to **Users** → **Create user**

| Field | Value |
|-------|-------|
| Username | `testuser` |
| Email | `test@ai-platform.local` |
| Email verified | ON |
| First name | Test |
| Last name | User |

After creation:
1. Go to **Credentials** tab
2. Click **Set password**
3. Enter password, turn OFF **Temporary**

Then assign roles:
1. Go to **Role mapping** tab
2. Click **Assign role**
3. Select `ai-engineer`

---

## Troubleshooting

### Keycloak won't start

```bash
# Check logs
kubectl logs -n auth -l app.kubernetes.io/name=keycloakx --tail=100

# Common issues:
# - Database connection failed → verify secret, hostname
# - Port already in use → check for conflicts
```

### Database connection failed

```bash
# Verify secret exists
kubectl get secret keycloak-db-secret -n auth -o yaml

# Test DB connection from Keycloak pod
kubectl exec -it keycloak-0 -n auth -- /bin/bash
# Inside pod:
# psql -h postgresql-cluster-rw.storage.svc -U keycloak -d keycloak

# Or test from PostgreSQL pod
kubectl exec -it postgresql-cluster-1 -n storage -- \
  psql -U keycloak -d keycloak -c "SELECT 1"
```

### Ingress not working

```bash
# Check ingress resource created
kubectl get ingress -n auth

# Check Traefik logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik --tail=50

# Verify hosts file has entry
cat /etc/hosts | grep auth
```

### Admin login fails

```bash
# Verify admin credentials in env
kubectl get pods -n auth -o yaml | grep -A 2 "KEYCLOAK_ADMIN"

# Reset admin password (restart pod after changing env)
kubectl rollout restart statefulset keycloak -n auth
```

---

## Useful Commands

```bash
# Get Keycloak pod status
kubectl get pods -n auth

# View logs
kubectl logs -n auth keycloak-0 -f

# Restart Keycloak
kubectl rollout restart statefulset keycloak -n auth

# Port-forward (alternative to ingress)
kubectl port-forward -n auth svc/keycloak-http 8080:80

# Get all Keycloak resources
kubectl get all -n auth

# Describe pod for events
kubectl describe pod keycloak-0 -n auth
```

---

## Security Considerations

### For Production

| Current (Home Lab) | Production Recommendation |
|--------------------|---------------------------|
| Admin password in values.yaml | Use Sealed Secrets or External Secrets |
| HTTP enabled | HTTPS only with valid certificates |
| Single replica | 2+ replicas with HA |
| No backup | Regular Realm exports + DB backups |

### OIDC Best Practices

1. **Short token lifetimes** - Access tokens: 5 minutes, Refresh tokens: 30 minutes
2. **Require PKCE** - For public clients (SPAs, mobile apps)
3. **Strict redirect URIs** - No wildcards in production
4. **Enable brute force protection** - Realm settings → Security defenses

---

## Next Steps

After Keycloak is running:
- [ ] Create `ai-platform` realm
- [ ] Configure OIDC clients (ArgoCD, Grafana, Open WebUI)
- [ ] Setup roles and test users
- [ ] Integrate ArgoCD with Keycloak OIDC
- [ ] Phase 4: Kubernetes Security Baseline
