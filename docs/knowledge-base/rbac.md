# 🔐 Kubernetes RBAC & ServiceAccounts — Knowledge Base

## Overview

This document covers Kubernetes RBAC (Role-Based Access Control) end-to-end, from the moment a request enters the cluster to the final authorization decision. It complements the NetworkPolicies knowledge base (Phase 4).

**Scope:** API Server authentication, RBAC authorization model, ServiceAccounts, practical patterns, and real examples from the AI Security Platform.

---

# Part 1: Request Lifecycle — From Entry to Authorization

## The Three Stages of Every Request

Every request to the Kubernetes API server passes through three sequential stages. If any stage rejects the request, it stops there.

```
┌─────────────────────────────────────────────────────────────────────────┐
│              KUBERNETES API SERVER — REQUEST LIFECYCLE                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   REQUEST                                                                │
│   (kubectl / pod / CI/CD)                                               │
│          │                                                               │
│          ▼                                                               │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  STAGE 1 — AUTHENTICATION                                         │  │
│  │                                                                   │  │
│  │  "Who are you?"                                                   │  │
│  │                                                                   │  │
│  │  Methods:                                                         │  │
│  │    - X.509 client certificate  (kubectl, kubeconfig)             │  │
│  │    - Bearer token (ServiceAccount JWT)                           │  │
│  │    - OIDC token (Keycloak, Azure AD, Google)                     │  │
│  │    - Webhook token                                               │  │
│  │                                                                   │  │
│  │  Result: Identity (username, groups, extra attributes)           │  │
│  │  If FAIL → 401 Unauthorized                                      │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│          │                                                               │
│          ▼ identity                                                      │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  STAGE 2 — AUTHORIZATION (RBAC)                                   │  │
│  │                                                                   │  │
│  │  "What are you allowed to do?"                                   │  │
│  │                                                                   │  │
│  │  Checks: Roles + RoleBindings / ClusterRoles + ClusterRoleBindings│  │
│  │                                                                   │  │
│  │  Question: Can <subject> do <verb> on <resource> in <namespace>? │  │
│  │                                                                   │  │
│  │  If FAIL → 403 Forbidden                                         │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│          │                                                               │
│          ▼ authorized                                                    │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  STAGE 3 — ADMISSION CONTROL                                      │  │
│  │                                                                   │  │
│  │  "Is the object valid and policy-compliant?"                     │  │
│  │                                                                   │  │
│  │  Controllers:                                                     │  │
│  │    - MutatingAdmissionWebhook  (Kyverno mutate, Istio sidecar)   │  │
│  │    - ValidatingAdmissionWebhook (Kyverno validate, OPA Gatekeeper)│  │
│  │    - PodSecurity (PSS enforcement — Phase 4)                     │  │
│  │    - ResourceQuota, LimitRanger                                  │  │
│  │                                                                   │  │
│  │  If FAIL → 403 / 422 (policy violation)                          │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│          │                                                               │
│          ▼ admitted                                                      │
│   etcd (persisted) → Controller → Scheduler → kubelet                   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Two Categories of Identities

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        WHO CAN AUTHENTICATE?                             │
├──────────────────────────────────┬──────────────────────────────────────┤
│       HUMAN USERS                │       MACHINES / WORKLOADS           │
├──────────────────────────────────┼──────────────────────────────────────┤
│                                  │                                       │
│  kubectl (developer/admin)       │  Pods inside the cluster             │
│  CI/CD pipelines (GitHub Actions)│  Controllers (ArgoCD, CNPG)          │
│  Monitoring tools (external)     │  Operators                           │
│                                  │  Jobs / CronJobs                     │
│  Auth method:                    │                                       │
│    X.509 cert in kubeconfig      │  Auth method:                        │
│    OIDC token (Keycloak)         │    ServiceAccount JWT token          │
│    Cloud IAM (AWS, Azure, GCP)   │    (auto-mounted in pod filesystem)  │
│                                  │                                       │
│  Managed: OUTSIDE Kubernetes     │  Managed: INSIDE Kubernetes          │
│           (Keycloak, AD, IAM)    │           (ServiceAccount objects)   │
│                                  │                                       │
└──────────────────────────────────┴──────────────────────────────────────┘
```

> **Key insight:** Kubernetes does NOT manage user accounts natively. Human users are always authenticated via an external system (certs, OIDC, cloud IAM). Only ServiceAccounts are Kubernetes-native objects.

---

# Part 2: ServiceAccounts

## What is a ServiceAccount?

A ServiceAccount is a Kubernetes-native identity for workloads (pods, jobs, controllers) running inside the cluster.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       SERVICEACCOUNT ANATOMY                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  apiVersion: v1                                                          │
│  kind: ServiceAccount                                                    │
│  metadata:                                                               │
│    name: my-app                          ← Identity name                 │
│    namespace: ai-apps                    ← Scoped to namespace           │
│  automountServiceAccountToken: false     ← Security best practice       │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  What Kubernetes creates automatically:                          │    │
│  │                                                                  │    │
│  │  Secret (K8s < 1.24):                                            │    │
│  │    my-app-token-xxxxx                                            │    │
│  │    Contains: JWT token + CA cert                                 │    │
│  │                                                                  │    │
│  │  Projected Volume (K8s >= 1.24):                                 │    │
│  │    /var/run/secrets/kubernetes.io/serviceaccount/token           │    │
│  │    /var/run/secrets/kubernetes.io/serviceaccount/ca.crt          │    │
│  │    /var/run/secrets/kubernetes.io/serviceaccount/namespace       │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## ServiceAccount Token in a Pod

When a pod runs, the SA token is auto-mounted (unless disabled). The pod uses it to authenticate against the API server.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                 HOW A POD USES ITS SERVICEACCOUNT                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  POD (ai-apps/rag-api)                                                   │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                                                                  │    │
│  │  Filesystem (auto-mounted):                                      │    │
│  │  /var/run/secrets/kubernetes.io/serviceaccount/                  │    │
│  │    ├── token     ← JWT: {"sub":"system:serviceaccount:ai-apps:   │    │
│  │    │                      rag-api", "iss":"kubernetes/..."}      │    │
│  │    ├── ca.crt    ← API server CA certificate                    │    │
│  │    └── namespace ← "ai-apps"                                    │    │
│  │                                                                  │    │
│  │  Environment (implicit):                                         │    │
│  │    KUBERNETES_SERVICE_HOST=10.43.0.1                             │    │
│  │    KUBERNETES_SERVICE_PORT=443                                   │    │
│  │                                                                  │    │
│  │  API Call:                                                       │    │
│  │    curl -k https://10.43.0.1:443/api/v1/namespaces/ai-apps/pods │    │
│  │         -H "Authorization: Bearer $(cat .../token)"             │    │
│  │                                                                  │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                         │                                                │
│                         ▼ JWT token                                      │
│  API SERVER: "token subject = system:serviceaccount:ai-apps:rag-api"    │
│  → RBAC check: can rag-api do GET pods in ai-apps? → YES / NO           │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Default ServiceAccount — The Hidden Risk

Every namespace has a `default` ServiceAccount. If no SA is specified, pods use it automatically.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    DEFAULT SERVICEACCOUNT RISK                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ❌ BAD — Pod uses default SA (implicit)                                │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ spec:                                                            │    │
│  │   containers:                                                    │    │
│  │     - name: my-app                                               │    │
│  │       image: my-app:1.0                                          │    │
│  │  # No serviceAccountName → uses "default" SA                    │    │
│  │  # Token auto-mounted → attacker can use it if pod is compromised│    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ✅ GOOD — Explicit SA + disable automount if API access not needed     │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ spec:                                                            │    │
│  │   serviceAccountName: rag-api                 ← explicit        │    │
│  │   automountServiceAccountToken: false         ← no token if     │    │
│  │   containers:                                    unnecessary    │    │
│  │     - name: rag-api                                              │    │
│  │       image: rag-api:1.0                                         │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  RULE: Disable automount on the SA itself as default:                   │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ apiVersion: v1                                                   │    │
│  │ kind: ServiceAccount                                             │    │
│  │ metadata:                                                        │    │
│  │   name: rag-api                                                  │    │
│  │   namespace: ai-apps                                             │    │
│  │ automountServiceAccountToken: false  ← secure by default        │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Then re-enable only where needed:                                      │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ spec:                                                            │    │
│  │   serviceAccountName: rag-api                                    │    │
│  │   automountServiceAccountToken: true  ← explicit opt-in         │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

# Part 3: RBAC Model

## The Four RBAC Objects

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        RBAC BUILDING BLOCKS                              │
├──────────────────────┬──────────────────────────────────────────────────┤
│  OBJECT              │  PURPOSE                                         │
├──────────────────────┼──────────────────────────────────────────────────┤
│  Role                │  Defines permissions — NAMESPACED               │
│  ClusterRole         │  Defines permissions — CLUSTER-WIDE             │
├──────────────────────┼──────────────────────────────────────────────────┤
│  RoleBinding         │  Grants a Role to a subject — NAMESPACED        │
│  ClusterRoleBinding  │  Grants a ClusterRole to a subject — CLUSTER    │
└──────────────────────┴──────────────────────────────────────────────────┘

The formula:
  Subject (who) + RoleBinding (glue) + Role (what) = Access (where)
```

## Scope Matrix

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     ROLE + BINDING COMBINATIONS                          │
├────────────────────────┬────────────────────────┬───────────────────────┤
│  Role type             │  Binding type          │  Access granted       │
├────────────────────────┼────────────────────────┼───────────────────────┤
│  Role                  │  RoleBinding           │  Namespace only       │
│  (namespaced)          │  (same namespace)      │                       │
├────────────────────────┼────────────────────────┼───────────────────────┤
│  ClusterRole           │  RoleBinding           │  Namespace only       │
│  (cluster-wide def)    │  (in one namespace)    │  (reuse definition)   │
├────────────────────────┼────────────────────────┼───────────────────────┤
│  ClusterRole           │  ClusterRoleBinding    │  ALL namespaces       │
│  (cluster-wide)        │  (cluster-wide)        │  + cluster resources  │
└────────────────────────┴────────────────────────┴───────────────────────┘

⚠️  IMPORTANT:
  A ClusterRole + RoleBinding = namespace-scoped (NOT cluster-wide)
  A ClusterRole + ClusterRoleBinding = truly cluster-wide
```

## Role Anatomy — Verbs and Resources

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         ROLE STRUCTURE                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  apiVersion: rbac.authorization.k8s.io/v1                               │
│  kind: Role                                                              │
│  metadata:                                                               │
│    name: pod-reader                                                      │
│    namespace: ai-apps                                                    │
│  rules:                                                                  │
│    - apiGroups: [""]          ← "" = core API (pods, services, secrets) │
│      resources: ["pods"]      ← resource type                           │
│      verbs: ["get","list","watch"]  ← allowed actions                   │
│    - apiGroups: ["apps"]      ← named group                             │
│      resources: ["deployments"]                                          │
│      verbs: ["get","list"]                                               │
│    - apiGroups: ["postgresql.cnpg.io"]  ← CRD group                    │
│      resources: ["clusters"]                                             │
│      resourceNames: ["postgresql-cluster"]  ← specific instance only    │
│      verbs: ["get","list","watch","patch","update"]                      │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│  COMMON VERBS                                                            │
│                                                                          │
│  Read:    get, list, watch                                               │
│  Write:   create, update, patch, delete                                 │
│  Special: exec (kubectl exec), portforward, proxy                       │
│           escalate (grant higher privileges — very dangerous)            │
│           bind (attach ClusterRole)                                     │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│  COMMON API GROUPS                                                       │
│                                                                          │
│  ""                          → core (pods, nodes, services, secrets,    │
│                                      configmaps, namespaces, events)    │
│  "apps"                      → deployments, statefulsets, daemonsets    │
│  "batch"                     → jobs, cronjobs                           │
│  "rbac.authorization.k8s.io" → roles, rolebindings, clusterroles       │
│  "networking.k8s.io"         → networkpolicies, ingresses               │
│  "policy"                    → poddisruptionbudgets                     │
│  "argoproj.io"               → applications (ArgoCD CRDs)              │
│  "postgresql.cnpg.io"        → clusters, backups (CNPG CRDs)           │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## RoleBinding Anatomy

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: rag-api-binding
  namespace: ai-apps
subjects:                              # WHO gets access
  - kind: ServiceAccount              # Pod identity
    name: rag-api
    namespace: ai-apps
  - kind: User                        # Human user
    name: stephane@company.com
    apiGroup: rbac.authorization.k8s.io
  - kind: Group                       # Group of users
    name: ai-engineers
    apiGroup: rbac.authorization.k8s.io
roleRef:                               # WHAT access
  kind: Role                          # or ClusterRole
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

---

# Part 4: RBAC in the AI Security Platform

## Platform-Wide RBAC Map

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                   AI SECURITY PLATFORM — RBAC OVERVIEW                           │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  HUMAN USERS (via Keycloak OIDC)                                                │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │                                                                          │   │
│  │  zerotrust (admin)     Keycloak group: cluster-admins                   │   │
│  │       │                → ClusterRoleBinding → cluster-admin (builtin)   │   │
│  │       │                                                                  │   │
│  │  ai-engineers (team)   Keycloak group: ai-engineers                     │   │
│  │       │                → RoleBinding (ai-apps) → view (builtin)         │   │
│  │       │                  (see: keycloak-rbac application in ArgoCD)     │   │
│  │                                                                          │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│  WORKLOAD SERVICEACCOUNTS                                                        │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │                                                                          │   │
│  │  argocd          SA: argocd-application-controller                      │   │
│  │  (argocd ns)       → ClusterRoleBinding → cluster-admin                 │   │
│  │                      (ArgoCD needs to deploy anything, anywhere)        │   │
│  │                                                                          │   │
│  │  postgresql-cluster  SA: postgresql-cluster                             │   │
│  │  (storage ns)        → RoleBinding (storage) → Role: postgresql-cluster │   │
│  │                         get/watch: clusters.cnpg.io, secrets, configmaps│   │
│  │                         patch: clusters.cnpg.io/status                  │   │
│  │                                                                          │   │
│  │  cnpg-operator   SA: cnpg-operator-cloudnative-pg                      │   │
│  │  (cnpg-system)     → ClusterRoleBinding: cnpg-operator-cloudnative-pg  │   │
│  │                      (manage all postgresql CRDs cluster-wide)          │   │
│  │                                                                          │   │
│  │  kyverno         SA: kyverno                                            │   │
│  │  (kyverno ns)      → ClusterRoleBinding: kyverno                       │   │
│  │                      (needs to watch/patch all resources for policies)  │   │
│  │                                                                          │   │
│  │  falco            SA: falco                                             │   │
│  │  (falco ns)        → ClusterRoleBinding (read nodes, pods, namespaces)  │   │
│  │                                                                          │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Deep Dive: CNPG ServiceAccount (Real Example from Platform)

We saw this in action during the PostgreSQL NetworkPolicy debugging session. Here is the full RBAC chain:

```
┌─────────────────────────────────────────────────────────────────────────┐
│             CNPG POSTGRESQL-CLUSTER — RBAC CHAIN                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. ServiceAccount (auto-created by CNPG operator)                      │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  kind: ServiceAccount                                            │    │
│  │  name: postgresql-cluster                                        │    │
│  │  namespace: storage                                              │    │
│  │  labels:                                                         │    │
│  │    app.kubernetes.io/managed-by: cloudnative-pg                  │    │
│  │    cnpg.io/cluster: postgresql-cluster                           │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                              │                                           │
│                              ▼                                           │
│  2. Role (namespaced, auto-created by CNPG operator)                    │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  kind: Role                                                      │    │
│  │  name: postgresql-cluster                                        │    │
│  │  namespace: storage                                              │    │
│  │  rules:                                                          │    │
│  │    - clusters.postgresql.cnpg.io → get, list, watch             │    │
│  │    - clusters.postgresql.cnpg.io/status → get, patch, update    │    │
│  │    - secrets (ca, server, replication, superuser, app) → get    │    │
│  │    - configmaps → get, watch                                     │    │
│  │    - events → create, patch                                      │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                              │                                           │
│                              ▼                                           │
│  3. RoleBinding (auto-created by CNPG operator)                         │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  kind: RoleBinding                                               │    │
│  │  name: postgresql-cluster                                        │    │
│  │  namespace: storage                                              │    │
│  │  subjects:                                                       │    │
│  │    - kind: ServiceAccount                                        │    │
│  │      name: postgresql-cluster                                    │    │
│  │      namespace: storage                                          │    │
│  │  roleRef:                                                        │    │
│  │    kind: Role                                                    │    │
│  │    name: postgresql-cluster                                      │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                              │                                           │
│                              ▼                                           │
│  4. Result: postgresql-cluster SA can ONLY access:                      │
│     - Its own cluster config (storage namespace)                        │
│     - Its own secrets (CA, TLS, superuser credentials)                  │
│     - Create events                                                      │
│     ❌ Cannot access other namespaces                                   │
│     ❌ Cannot access other clusters' resources                          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Keycloak + ArgoCD: Human User RBAC (OIDC Bridge)

```
┌─────────────────────────────────────────────────────────────────────────┐
│              HUMAN USER RBAC — KEYCLOAK → KUBERNETES FLOW               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. User logs in via Keycloak                                            │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Keycloak realm: ai-platform                                     │    │
│  │  User: stephane  →  Groups: ["cluster-admins", "ai-engineers"]  │    │
│  │                                                                  │    │
│  │  OIDC token includes:                                            │    │
│  │    {                                                             │    │
│  │      "sub": "stephane",                                          │    │
│  │      "groups": ["cluster-admins", "ai-engineers"],               │    │
│  │      "email": "stephane@ai-platform.local"                      │    │
│  │    }                                                             │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                              │                                           │
│                              ▼ OIDC token                               │
│  2. K3s API server validates token against Keycloak                     │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  kube-apiserver flags:                                           │    │
│  │    --oidc-issuer-url=https://auth.ai-platform.localhost/...      │    │
│  │    --oidc-client-id=kubernetes                                   │    │
│  │    --oidc-username-claim=preferred_username                      │    │
│  │    --oidc-groups-claim=groups                                    │    │
│  │                                                                  │    │
│  │  Identity extracted:                                             │    │
│  │    username: "stephane"                                          │    │
│  │    groups: ["cluster-admins", "ai-engineers"]                    │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                              │                                           │
│                              ▼ identity                                  │
│  3. RBAC check (keycloak-rbac application)                              │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  ClusterRoleBinding: keycloak-cluster-admin                      │    │
│  │    subjects: Group "cluster-admins"                              │    │
│  │    roleRef: ClusterRole "cluster-admin"                          │    │
│  │    → Full cluster access                                         │    │
│  │                                                                  │    │
│  │  RoleBinding: keycloak-ai-engineers-view (ns: ai-apps)           │    │
│  │    subjects: Group "ai-engineers"                                │    │
│  │    roleRef: ClusterRole "view"                                   │    │
│  │    → Read-only on ai-apps namespace                              │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

# Part 5: Built-in Roles

Kubernetes ships with several useful default ClusterRoles. Prefer these over custom roles when they fit.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     BUILT-IN CLUSTERROLES                                │
├──────────────────────┬──────────────────────────────────────────────────┤
│  Name                │  Permissions                                     │
├──────────────────────┼──────────────────────────────────────────────────┤
│  cluster-admin       │  EVERYTHING — use only for admins/ArgoCD        │
│  admin               │  Most things in a namespace (no quota/PSP edit) │
│  edit                │  Read + write most resources (no roles/bindings) │
│  view                │  Read-only on most namespace resources           │
│  system:auth-delegator│ Delegate authentication — for auth webhooks    │
│  system:node         │  Used by kubelets — don't assign to workloads   │
└──────────────────────┴──────────────────────────────────────────────────┘

Tip: Use "view" for monitoring tools, dashboards, and read-only CI/CD.
     Use "edit" for deployment tools that don't manage RBAC.
     Never use "cluster-admin" for application workloads.
```

---

# Part 6: Principle of Least Privilege

## The RBAC Design Ladder

```
┌─────────────────────────────────────────────────────────────────────────┐
│                  RBAC LEAST PRIVILEGE LADDER                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  🔴 WORST                                                                │
│  cluster-admin ClusterRoleBinding for a workload SA                     │
│  "Give it all permissions, it works"                                     │
│                                                                          │
│  🟠 BAD                                                                  │
│  Broad ClusterRole with many verbs on many resources                    │
│  No resourceNames restrictions                                           │
│                                                                          │
│  🟡 OK                                                                   │
│  Custom Role (namespaced), multiple resources, no resourceNames         │
│                                                                          │
│  🟢 GOOD                                                                 │
│  Custom Role, minimal verbs (get+watch only if write not needed)        │
│  resourceNames to restrict to specific object instances                 │
│                                                                          │
│  🟢 BEST                                                                 │
│  automountServiceAccountToken: false on SA                              │
│  Custom Role with minimal verbs + resourceNames                         │
│  NetworkPolicy to restrict egress to API server                         │
│  Audit logs to detect unexpected API calls                               │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Practical Design Pattern for Workloads

```yaml
# Step 1: ServiceAccount (no auto-mount by default)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: rag-api
  namespace: ai-apps
automountServiceAccountToken: false

---
# Step 2: Role (minimal permissions only)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: rag-api
  namespace: ai-apps
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["rag-api-config"]   # Only this configmap
    verbs: ["get", "watch"]
  - apiGroups: [""]
    resources: ["secrets"]
    resourceNames: ["rag-api-credentials"]  # Only this secret
    verbs: ["get"]

---
# Step 3: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: rag-api
  namespace: ai-apps
subjects:
  - kind: ServiceAccount
    name: rag-api
    namespace: ai-apps
roleRef:
  kind: Role
  name: rag-api
  apiGroup: rbac.authorization.k8s.io

---
# Step 4: Pod — opt-in to token only when needed
spec:
  serviceAccountName: rag-api
  automountServiceAccountToken: true   # explicit opt-in
```

---

# Part 7: RBAC + NetworkPolicy — Combined Defense

RBAC and NetworkPolicies are complementary, not alternatives. A workload needs to pass **both** to successfully call the API server.

```
┌─────────────────────────────────────────────────────────────────────────┐
│               COMBINED DEFENSE: NETWORK + RBAC                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Without NetworkPolicy:  Pod can REACH API server but RBAC rejects      │
│  Without RBAC:           Pod can REACH API server but request DENIED    │
│  With both:              Pod can only reach API if it needs to,          │
│                          and only do what it's authorized to do          │
│                                                                          │
│  ┌──────────────┐   NetworkPolicy    ┌──────────────┐                  │
│  │     Pod      │ ─────────────────► │  API Server  │                  │
│  │  (storage ns)│   port 443 to      │              │                  │
│  │              │   kube-system      │  RBAC check  │                  │
│  └──────────────┘                   └──────────────┘                  │
│        │                                    │                           │
│        │ SA token                           │ Role: postgresql-cluster  │
│        │ (postgresql-cluster)               │ get clusters.cnpg.io     │
│        └────────────────────────────────────┘                           │
│                                                                          │
│  🛡️  Layer 1 (NetworkPolicy): Can the pod reach the API server at all? │
│  🛡️  Layer 2 (RBAC): Is the SA authorized to do this specific action?  │
│                                                                          │
│  Lesson from our debugging session:                                     │
│  NetworkPolicy was too restrictive → CNPG pod couldn't reach API       │
│  → CrashLoopBackOff even though RBAC was correctly configured           │
│  → Both layers must be correct for the system to work                   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

# Part 8: Verification & Debugging Commands

## Check What a Subject Can Do

```bash
# Can SA rag-api get pods in ai-apps?
kubectl auth can-i get pods \
  --as=system:serviceaccount:ai-apps:rag-api \
  -n ai-apps

# Can SA postgresql-cluster get its cluster CRD?
kubectl auth can-i get clusters.postgresql.cnpg.io \
  --as=system:serviceaccount:storage:postgresql-cluster \
  -n storage

# Full list of what an SA can do in a namespace
kubectl auth can-i --list \
  --as=system:serviceaccount:storage:postgresql-cluster \
  -n storage

# Can a Keycloak group member do something?
kubectl auth can-i get pods \
  --as=stephane \
  --as-group=cluster-admins \
  -n ai-apps
```

## Audit — Who Has Access to What

```bash
# List all RoleBindings in a namespace
kubectl get rolebindings -n ai-apps -o wide

# List all ClusterRoleBindings
kubectl get clusterrolebindings -o wide | grep -v "system:"

# Who has access to secrets in storage namespace?
kubectl get rolebindings,clusterrolebindings -A -o json | \
  jq '.items[] | select(.rules[]?.resources[]? == "secrets")'

# List all ServiceAccounts
kubectl get serviceaccounts -A

# Describe a specific RoleBinding
kubectl describe rolebinding postgresql-cluster -n storage
```

## Debug API Server Audit Logs (K3s)

```bash
# K3s audit logs (if audit policy configured)
kubectl logs -n kube-system -l component=kube-apiserver | \
  grep '"verb":"create"' | grep '"resource":"pods"'

# Check RBAC-related events
kubectl get events -A | grep -i "forbidden\|unauthorized\|rbac"

# Test RBAC before deploying (dry-run)
kubectl auth can-i create deployments \
  --as=system:serviceaccount:ai-apps:rag-api \
  -n ai-apps
```

---

# Part 9: RBAC for Operators — Pattern Reference

Operators (CNPG, Kyverno, Falco, ArgoCD) typically require elevated permissions. Here is the standard pattern they follow:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    OPERATOR RBAC PATTERN                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. SA in operator namespace                                             │
│     ServiceAccount: cnpg-operator-cloudnative-pg (cnpg-system)         │
│                                                                          │
│  2. ClusterRole with CRD management permissions                         │
│     ClusterRole: cnpg-operator-cloudnative-pg                           │
│       - clusters.postgresql.cnpg.io → full CRUD                        │
│       - pods, services, secrets → get/list/watch/create/delete          │
│       - events → create/patch                                            │
│                                                                          │
│  3. ClusterRoleBinding (cluster-wide because operator manages all NSes) │
│     ClusterRoleBinding: cnpg-operator-cloudnative-pg                    │
│       SA: cnpg-operator-cloudnative-pg → ClusterRole above              │
│                                                                          │
│  4. Each managed instance gets its own minimal Role                     │
│     Role: postgresql-cluster (storage ns)                               │
│       Only the permissions the cluster pod itself needs at runtime      │
│                                                                          │
│  Kyverno: same pattern but needs admission webhook + watch ALL pods     │
│  Falco: reads pods/nodes/namespaces — read-only ClusterRole             │
│  ArgoCD: cluster-admin (needs to deploy anything anywhere)              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

# Part 10: Common Mistakes & How to Fix Them

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     COMMON RBAC MISTAKES                                 │
├──────────────────────────────────┬──────────────────────────────────────┤
│  MISTAKE                         │  FIX                                │
├──────────────────────────────────┼──────────────────────────────────────┤
│  SA has no RBAC but pod uses     │  Add Role + RoleBinding for the SA  │
│  API → 403 errors in logs        │  or disable automount if not needed  │
├──────────────────────────────────┼──────────────────────────────────────┤
│  NetworkPolicy blocks API server │  Add egress to kube-system port 443 │
│  → pod crashes at startup        │  (not ipBlock — Flannel limitation)  │
│  (our CNPG incident)             │                                      │
├──────────────────────────────────┼──────────────────────────────────────┤
│  ClusterRoleBinding on workload  │  Replace with Role + RoleBinding     │
│  SA for namespace tasks          │  scoped to the namespace             │
├──────────────────────────────────┼──────────────────────────────────────┤
│  Pods using "default" SA         │  Create dedicated SA per workload    │
│  and auto-mounting token         │  automountServiceAccountToken: false │
├──────────────────────────────────┼──────────────────────────────────────┤
│  OIDC group not mapped           │  Check Keycloak group claim in token │
│  → user has no permissions       │  Verify --oidc-groups-claim flag     │
│                                  │  kubectl auth can-i --list --as=user │
├──────────────────────────────────┼──────────────────────────────────────┤
│  Role allows "secrets" broadly   │  Use resourceNames to restrict to    │
│  → potential credential access   │  specific secret names only          │
└──────────────────────────────────┴──────────────────────────────────────┘
```

---

# Summary

## RBAC Objects Quick Reference

| Need | Object |
|------|--------|
| Pod needs API access | ServiceAccount + Role + RoleBinding |
| Admin needs cluster access | ClusterRole + ClusterRoleBinding |
| Dev team read-only on namespace | Built-in "view" + RoleBinding |
| Operator managing CRDs cluster-wide | ClusterRole + ClusterRoleBinding |
| Reuse ClusterRole for one namespace | ClusterRole + RoleBinding (namespaced) |

## Security Checklist

```
✅  Each workload has its own dedicated ServiceAccount
✅  automountServiceAccountToken: false by default on SAs
✅  Roles are namespaced (Role) unless cluster-wide access is required
✅  resourceNames used to restrict access to specific object instances
✅  No workload SA has cluster-admin
✅  NetworkPolicy allows egress to kube-system:443 when API access needed
✅  kubectl auth can-i used to verify before deploying
✅  OIDC group claims mapped to ClusterRoleBindings for human users
✅  Audit logs enabled to detect unexpected API calls
```

## Files in This Platform

| File | Purpose |
|------|---------|
| `argocd/applications/security/keycloak-rbac/` | OIDC group → K8s RBAC mapping |
| `argocd/applications/security/security-baseline/manifests/` | NetworkPolicies (interacts with RBAC) |
| CNPG auto-created | Role + RoleBinding for `postgresql-cluster` SA |
| ArgoCD auto-created | ClusterRoleBinding for `argocd-application-controller` SA |

---

*Companion document: `phases/phase-04/README.md` — NetworkPolicies & Pod Security Standards*
