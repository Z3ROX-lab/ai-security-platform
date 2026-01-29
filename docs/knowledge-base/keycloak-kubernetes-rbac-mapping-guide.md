# Keycloak to Kubernetes RBAC Mapping Guide

> **Objectif** : Comprendre comment mapper les Realm Roles Keycloak vers le RBAC Kubernetes pour un SSO complet jusqu'au cluster.

---

## Table des Matières

1. [Vue d'ensemble](#1-vue-densemble)
2. [Concepts RBAC Kubernetes](#2-concepts-rbac-kubernetes)
3. [Concepts Keycloak](#3-concepts-keycloak)
4. [Architecture du Mapping](#4-architecture-du-mapping)
5. [Configuration Keycloak](#5-configuration-keycloak)
6. [Configuration Kubernetes](#6-configuration-kubernetes)
7. [Patterns de Mapping](#7-patterns-de-mapping)
8. [ClusterRoleBinding vs RoleBinding](#8-clusterrolebinding-vs-rolebinding)
9. [Implémentation Lab](#9-implémentation-lab)
10. [kubectl avec OIDC](#10-kubectl-avec-oidc)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Vue d'ensemble

### 1.1 Le problème

Par défaut, Kubernetes et Keycloak sont deux systèmes isolés :

```
┌─────────────────────┐          ┌─────────────────────┐
│      KEYCLOAK       │          │     KUBERNETES      │
│                     │          │                     │
│  Users:             │    ???   │  RBAC:              │
│  • alice            │ ──────── │  • cluster-admin    │
│  • bob              │  Comment │  • edit             │
│                     │  lier ?  │  • view             │
│  Realm Roles:       │          │                     │
│  • platform-admin   │          │  Qui peut faire     │
│  • ai-engineer      │          │  quoi ?             │
│                     │          │                     │
└─────────────────────┘          └─────────────────────┘
```

### 1.2 La solution : OIDC + RBAC Mapping

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         SSO COMPLET                                      │
└─────────────────────────────────────────────────────────────────────────┘

1. User se connecte via Keycloak
2. Keycloak émet un token JWT avec les Realm Roles
3. K8s API Server valide le token via OIDC
4. K8s extrait les roles du token comme "groups"
5. K8s RBAC autorise selon les ClusterRoleBindings/RoleBindings

┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  User    │     │ Keycloak │     │  K8s API │     │   RBAC   │
│ kubectl  │     │   IdP    │     │  Server  │     │  Engine  │
└────┬─────┘     └────┬─────┘     └────┬─────┘     └────┬─────┘
     │                │                │                │
     │ 1. Login       │                │                │
     │───────────────▶│                │                │
     │                │                │                │
     │ 2. JWT Token   │                │                │
     │   (avec roles) │                │                │
     │◀───────────────│                │                │
     │                │                │                │
     │ 3. kubectl get pods (Bearer token)              │
     │────────────────────────────────▶│                │
     │                │                │                │
     │                │ 4. Validate    │                │
     │                │    token       │                │
     │                │◀───────────────│                │
     │                │                │                │
     │                │                │ 5. Extract     │
     │                │                │    groups      │
     │                │                │───────────────▶│
     │                │                │                │
     │                │                │ 6. Check       │
     │                │                │    bindings    │
     │                │                │◀───────────────│
     │                │                │                │
     │ 7. Response (allowed/denied)    │                │
     │◀────────────────────────────────│                │
```

### 1.3 Ce que TU dois configurer

| Côté | Configuration | Responsable |
|------|---------------|-------------|
| **Keycloak** | Realm Roles + Mapper pour inclure dans token | Toi |
| **K8s API Server** | Flags OIDC pour valider tokens | Toi |
| **K8s RBAC** | ClusterRoleBindings / RoleBindings | Toi |

**Important** : Le mapping n'est PAS automatique. C'est toi qui crées les bindings !

---

## 2. Concepts RBAC Kubernetes

### 2.1 Les 4 objets RBAC

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         K8S RBAC OBJECTS                                 │
└─────────────────────────────────────────────────────────────────────────┘

DÉFINISSENT LES PERMISSIONS              ASSIGNENT LES PERMISSIONS
═══════════════════════════              ═════════════════════════

┌─────────────────────┐                  ┌─────────────────────┐
│     ClusterRole     │                  │ ClusterRoleBinding  │
│                     │                  │                     │
│ Scope: Cluster-wide │◀────────────────▶│ Lie un ClusterRole  │
│                     │                  │ à des users/groups  │
│ Définit des règles  │                  │ pour TOUT le cluster│
│ (verbs sur resources)                  │                     │
└─────────────────────┘                  └─────────────────────┘

┌─────────────────────┐                  ┌─────────────────────┐
│        Role         │                  │     RoleBinding     │
│                     │                  │                     │
│ Scope: 1 namespace  │◀────────────────▶│ Lie un Role (ou     │
│                     │                  │ ClusterRole) à des  │
│ Définit des règles  │                  │ users/groups pour   │
│ dans CE namespace   │                  │ UN namespace        │
└─────────────────────┘                  └─────────────────────┘
```

### 2.2 ClusterRole vs Role

| Aspect | ClusterRole | Role |
|--------|-------------|------|
| **Scope définition** | Cluster-wide | Un namespace |
| **Peut définir** | Toutes ressources + cluster-scoped | Ressources du namespace |
| **Ressources cluster-scoped** | ✅ Nodes, PV, Namespaces | ❌ Non |
| **Réutilisable** | ✅ Via ClusterRoleBinding OU RoleBinding | ❌ Seulement RoleBinding |

### 2.3 ClusterRoles built-in

| ClusterRole | Permissions |
|-------------|-------------|
| `cluster-admin` | Tout (god mode) |
| `admin` | Tout dans un namespace (pas RBAC) |
| `edit` | Read/write workloads (pas RBAC, pas secrets) |
| `view` | Read-only (pas secrets) |

### 2.4 Anatomie d'un ClusterRole

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-reader
rules:
  - apiGroups: [""]              # "" = core API (pods, services, etc.)
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
    
  - apiGroups: ["apps"]          # apps API (deployments, etc.)
    resources: ["deployments"]
    verbs: ["get", "list"]
```

**Verbs disponibles** : `get`, `list`, `watch`, `create`, `update`, `patch`, `delete`, `deletecollection`

### 2.5 ClusterRoleBinding vs RoleBinding

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SCOPE DES BINDINGS                                    │
└─────────────────────────────────────────────────────────────────────────┘

ClusterRoleBinding                         RoleBinding
══════════════════                         ═══════════

Donne accès à TOUS                         Donne accès à UN SEUL
les namespaces                             namespace

┌─────────────────────────┐                ┌─────────────────────────┐
│  ClusterRoleBinding     │                │     RoleBinding         │
│  name: global-viewers   │                │  name: team-a-edit      │
│                         │                │  namespace: project-a   │
│  subjects:              │                │                         │
│    - Group: viewer      │                │  subjects:              │
│                         │                │    - Group: team-a      │
│  roleRef:               │                │                         │
│    ClusterRole: view    │                │  roleRef:               │
└───────────┬─────────────┘                │    ClusterRole: edit    │
            │                              └───────────┬─────────────┘
            ▼                                          ▼
┌─────────────────────────┐                ┌─────────────────────────┐
│ Accès lecture à:        │                │ Accès edit à:           │
│ • default          ✅   │                │ • project-a        ✅   │
│ • kube-system      ✅   │                │ • project-b        ❌   │
│ • ai-apps          ✅   │                │ • ai-apps          ❌   │
│ • auth             ✅   │                │                         │
│ • storage          ✅   │                │                         │
│ • (tous)           ✅   │                │                         │
└─────────────────────────┘                └─────────────────────────┘
```

---

## 3. Concepts Keycloak

### 3.1 Realm Roles vs Client Roles

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         REALM: ai-platform                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   REALM ROLES (globaux au realm)                                        │
│   ══════════════════════════════                                        │
│   → Utilisés pour le mapping K8s RBAC                                   │
│   → Visibles par TOUTES les applications                                │
│                                                                          │
│   ├── platform-admin     (admin cluster)                                │
│   ├── ai-engineer        (accès ML tools)                               │
│   ├── security-auditor   (lecture sécurité)                             │
│   └── viewer             (lecture seule)                                │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   CLIENT ROLES (spécifiques à une app)                                  │
│   ════════════════════════════════════                                  │
│   → Utilisés pour les permissions DANS l'application                    │
│   → NON utilisés pour K8s RBAC                                          │
│                                                                          │
│   Client: grafana              Client: argocd                           │
│   ├── Admin                    ├── admin                                │
│   ├── Editor                   └── readonly                             │
│   └── Viewer                                                            │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Token JWT avec Realm Roles

Quand un user s'authentifie, Keycloak émet un token contenant ses roles :

```json
{
  "iss": "https://auth.ai-platform.localhost/realms/ai-platform",
  "sub": "f23a4567-e89b-12d3-a456-426614174000",
  "preferred_username": "alice",
  "email": "alice@example.com",
  
  "realm_access": {
    "roles": [
      "platform-admin",
      "ai-engineer"
    ]
  },
  
  "resource_access": {
    "grafana": {
      "roles": ["Admin"]
    }
  }
}
```

### 3.3 Le problème : format du claim

Par défaut, les realm roles sont dans `realm_access.roles` (objet imbriqué).

K8s attend un claim **simple** (array à la racine).

**Solution** : Créer un **mapper** pour exposer les roles dans un claim `groups`.

---

## 4. Architecture du Mapping

### 4.1 Flow complet

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      OIDC + RBAC MAPPING FLOW                            │
└─────────────────────────────────────────────────────────────────────────┘

KEYCLOAK                          K8S API SERVER                 K8S RBAC
════════                          ══════════════                 ════════

┌──────────────────┐              
│ Realm Roles:     │              
│ • platform-admin │              
│ • ai-engineer    │              
└────────┬─────────┘              
         │                        
         │ Mapper: "groups"       
         ▼                        
┌──────────────────┐              ┌──────────────────┐
│ Token JWT:       │              │ OIDC Config:     │
│                  │   ────────▶  │                  │
│ "groups": [      │   Validate   │ --oidc-issuer    │
│   "platform-admin"              │ --oidc-client-id │
│   "ai-engineer"  │              │ --oidc-groups-   │
│ ]                │              │   claim=groups   │
└──────────────────┘              └────────┬─────────┘
                                           │
                                           │ Extrait groups
                                           ▼
                                  ┌──────────────────┐
                                  │ User "alice"     │
                                  │ Groups:          │
                                  │ • platform-admin │
                                  │ • ai-engineer    │
                                  └────────┬─────────┘
                                           │
                                           │ Check RBAC
                                           ▼
                                  ┌──────────────────┐      ┌──────────────┐
                                  │ClusterRoleBinding│      │ ClusterRole  │
                                  │                  │      │              │
                                  │subjects:         │─────▶│cluster-admin │
                                  │ Group:           │      │              │
                                  │  platform-admin  │      │ (full access)│
                                  └──────────────────┘      └──────────────┘
```

### 4.2 Ce qui est automatique vs manuel

| Étape | Automatique ? | Qui le fait ? |
|-------|---------------|---------------|
| User login → Token JWT | ✅ Auto | Keycloak |
| Roles dans le token | ⚠️ Besoin mapper | Toi (config Keycloak) |
| Token validation | ✅ Auto | K8s API Server (si configuré) |
| Extraction des groups | ✅ Auto | K8s API Server |
| Vérification RBAC | ✅ Auto | K8s RBAC engine |
| Mapping Group → ClusterRole | ❌ Manuel | Toi (ClusterRoleBinding) |

---

## 5. Configuration Keycloak

### 5.1 Créer le client "kubernetes"

1. **Keycloak Admin** → Realm `ai-platform` → **Clients** → **Create client**

2. **General Settings** :
   - Client ID: `kubernetes`
   - Client Protocol: `openid-connect`

3. **Capability Config** :
   - Client authentication: `OFF` (public client)
   - Authorization: `OFF`

4. **Login Settings** :
   - Valid redirect URIs: `http://localhost:8000/*` (pour kubectl)

### 5.2 Créer le mapper pour les groups

Le mapper transforme `realm_access.roles` en un claim `groups` simple.

1. **Client: kubernetes** → **Client scopes** → **kubernetes-dedicated**

2. **Mappers** → **Create mapper**

3. **Configuration** :

| Champ | Valeur |
|-------|--------|
| Name | `realm-roles-to-groups` |
| Mapper Type | `User Realm Role` |
| Token Claim Name | `groups` |
| Claim JSON Type | `String` |
| Add to ID token | `ON` |
| Add to access token | `ON` |
| Add to userinfo | `ON` |
| Multivalued | `ON` |

### 5.3 Vérifier le token

Test avec curl :

```bash
# Get token
TOKEN=$(curl -s -X POST \
  "https://auth.ai-platform.localhost/realms/ai-platform/protocol/openid-connect/token" \
  -d "grant_type=password" \
  -d "client_id=kubernetes" \
  -d "username=alice" \
  -d "password=password" \
  | jq -r '.access_token')

# Decode (partie payload)
echo $TOKEN | cut -d. -f2 | base64 -d | jq .
```

**Résultat attendu** :

```json
{
  "sub": "...",
  "preferred_username": "alice",
  "groups": [
    "platform-admin",
    "ai-engineer"
  ]
}
```

---

## 6. Configuration Kubernetes

### 6.1 K3s/K3d OIDC Configuration

**Option A : K3d au moment de la création**

```bash
k3d cluster create ai-security-platform \
  --k3s-arg "--kube-apiserver-arg=oidc-issuer-url=https://auth.ai-platform.localhost/realms/ai-platform@server:0" \
  --k3s-arg "--kube-apiserver-arg=oidc-client-id=kubernetes@server:0" \
  --k3s-arg "--kube-apiserver-arg=oidc-username-claim=preferred_username@server:0" \
  --k3s-arg "--kube-apiserver-arg=oidc-groups-claim=groups@server:0" \
  --k3s-arg "--kube-apiserver-arg=oidc-ca-file=/etc/ssl/certs/ca-certificates.crt@server:0"
```

**Option B : Modifier un cluster K3s existant**

```yaml
# /etc/rancher/k3s/config.yaml
kube-apiserver-arg:
  - "oidc-issuer-url=https://auth.ai-platform.localhost/realms/ai-platform"
  - "oidc-client-id=kubernetes"
  - "oidc-username-claim=preferred_username"
  - "oidc-groups-claim=groups"
  - "oidc-ca-file=/path/to/keycloak-ca.crt"
```

Puis restart : `sudo systemctl restart k3s`

### 6.2 Paramètres OIDC expliqués

| Paramètre | Description | Exemple |
|-----------|-------------|---------|
| `oidc-issuer-url` | URL du realm Keycloak | `https://auth.../realms/ai-platform` |
| `oidc-client-id` | Client ID dans Keycloak | `kubernetes` |
| `oidc-username-claim` | Claim pour le username | `preferred_username` |
| `oidc-groups-claim` | Claim pour les groups (roles) | `groups` |
| `oidc-ca-file` | CA certificate si self-signed | `/path/to/ca.crt` |

### 6.3 Créer les ClusterRoleBindings

```yaml
# rbac/keycloak-rbac.yaml

---
# Platform Admins - Full cluster access
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: keycloak-platform-admins
subjects:
  - kind: Group
    name: "platform-admin"           # ← Realm role Keycloak
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin                # ← K8s ClusterRole
  apiGroup: rbac.authorization.k8s.io

---
# Viewers - Read-only cluster-wide
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: keycloak-viewers
subjects:
  - kind: Group
    name: "viewer"
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io

---
# Security Auditors - View + audit logs
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: keycloak-security-auditors
subjects:
  - kind: Group
    name: "security-auditor"
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
```

### 6.4 Créer les RoleBindings (namespace-scoped)

```yaml
# rbac/ai-engineer-rolebindings.yaml

---
# AI Engineers - Edit in ai-apps namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: keycloak-ai-engineers
  namespace: ai-apps                 # ← Limité à ce namespace
subjects:
  - kind: Group
    name: "ai-engineer"
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole                  # Peut référencer un ClusterRole
  name: edit                         # mais limité au namespace
  apiGroup: rbac.authorization.k8s.io

---
# AI Engineers - Edit in ai-inference namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: keycloak-ai-engineers
  namespace: ai-inference
subjects:
  - kind: Group
    name: "ai-engineer"
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: rbac.authorization.k8s.io

---
# AI Engineers - View only in storage namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: keycloak-ai-engineers-view
  namespace: storage
subjects:
  - kind: Group
    name: "ai-engineer"
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: view                         # Seulement lecture ici
  apiGroup: rbac.authorization.k8s.io
```

---

## 7. Patterns de Mapping

### 7.1 Pattern 1 : Admin global

**Use case** : Platform team avec accès complet.

```yaml
Keycloak Realm Role: platform-admin
          │
          ▼
ClusterRoleBinding ──────► ClusterRole: cluster-admin
          │
          ▼
Accès: TOUT le cluster (god mode)
```

### 7.2 Pattern 2 : Viewer global

**Use case** : Stakeholders, support, pour voir sans modifier.

```yaml
Keycloak Realm Role: viewer
          │
          ▼
ClusterRoleBinding ──────► ClusterRole: view
          │
          ▼
Accès: Lecture sur TOUT le cluster
```

### 7.3 Pattern 3 : Team avec namespaces dédiés

**Use case** : Équipe ML avec accès limité à leurs namespaces.

```yaml
Keycloak Realm Role: ai-engineer
          │
          ├──► RoleBinding (ai-apps) ──────► ClusterRole: edit
          │
          ├──► RoleBinding (ai-inference) ─► ClusterRole: edit
          │
          └──► RoleBinding (storage) ──────► ClusterRole: view
          
Accès: Edit dans ai-apps et ai-inference, View dans storage
       AUCUN accès aux autres namespaces
```

### 7.4 Pattern 4 : Accès lecture global + écriture limitée

**Use case** : Dev qui peut voir partout mais modifier que son projet.

```yaml
Keycloak Realm Role: developer
          │
          ├──► ClusterRoleBinding ─────────► ClusterRole: view (global)
          │
          └──► RoleBinding (my-project) ───► ClusterRole: edit
          
Accès: Lecture partout, Edit seulement dans my-project
```

### 7.5 Pattern 5 : Custom ClusterRole

**Use case** : Auditeur sécurité avec accès aux events et logs.

```yaml
# Custom ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: security-auditor
rules:
  # Lecture basique
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps"]
    verbs: ["get", "list", "watch"]
  # Events
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["get", "list", "watch"]
  # Logs
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get", "list"]
  # Network Policies
  - apiGroups: ["networking.k8s.io"]
    resources: ["networkpolicies"]
    verbs: ["get", "list", "watch"]
  # Pod Security
  - apiGroups: ["policy"]
    resources: ["podsecuritypolicies"]
    verbs: ["get", "list", "watch"]

---
# Binding
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: keycloak-security-auditors
subjects:
  - kind: Group
    name: "security-auditor"
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: security-auditor
  apiGroup: rbac.authorization.k8s.io
```

---

## 8. ClusterRoleBinding vs RoleBinding

### 8.1 Règle de décision

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    DECISION TREE                                         │
└─────────────────────────────────────────────────────────────────────────┘

L'utilisateur/groupe doit avoir accès à...

         TOUS les namespaces ?
                │
        ┌───────┴───────┐
        │               │
       OUI             NON
        │               │
        ▼               ▼
ClusterRoleBinding    CERTAINS namespaces ?
                            │
                    ┌───────┴───────┐
                    │               │
                   OUI             NON
                    │               │
                    ▼               ▼
              RoleBinding      Pas d'accès
            (un par namespace)
```

### 8.2 Tableau récapitulatif

| Question | Réponse | Type de Binding |
|----------|---------|-----------------|
| Accès à tous les namespaces ? | Oui | **ClusterRoleBinding** |
| Accès à certains namespaces ? | Oui | **RoleBinding** (un par NS) |
| Accès à des ressources cluster-scoped ? | Oui | **ClusterRoleBinding** |
| Lecture globale + écriture limitée ? | Les deux | **ClusterRoleBinding** (view) + **RoleBinding** (edit) |

### 8.3 Ressources cluster-scoped

Ces ressources n'existent pas dans un namespace, donc **nécessitent ClusterRoleBinding** :

| Ressource | Description |
|-----------|-------------|
| `nodes` | Nœuds du cluster |
| `namespaces` | Namespaces eux-mêmes |
| `persistentvolumes` | Volumes (pas les claims) |
| `clusterroles` | Rôles cluster-wide |
| `clusterrolebindings` | Bindings cluster-wide |
| `storageclasses` | Classes de stockage |
| `ingressclasses` | Classes d'Ingress |

---

## 9. Implémentation Lab

### 9.1 Notre mapping prévu

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    AI SECURITY PLATFORM - RBAC MAPPING                   │
└─────────────────────────────────────────────────────────────────────────┘

Keycloak Realm Role     Binding Type              K8s Access
═══════════════════     ════════════              ══════════

platform-admin ──────► ClusterRoleBinding ──────► cluster-admin
                       (cluster-wide)             (full access)

viewer ──────────────► ClusterRoleBinding ──────► view
                       (cluster-wide)             (read-only all)

security-auditor ────► ClusterRoleBinding ──────► security-auditor (custom)
                       (cluster-wide)             (view + events + logs)

ai-engineer ─────────► RoleBinding (ai-apps) ───► edit
                       RoleBinding (ai-inference) edit
                       RoleBinding (storage) ────► view
                       (namespace-scoped)
```

### 9.2 Fichiers à créer

```
argocd/applications/security/keycloak-rbac/
├── application.yaml
└── manifests/
    ├── clusterroles.yaml           # Custom ClusterRoles
    ├── clusterrolebindings.yaml    # Global bindings
    └── rolebindings.yaml           # Namespace-scoped bindings
```

### 9.3 Status d'implémentation

| Composant | Status |
|-----------|--------|
| Realm Roles créés (Keycloak) | ✅ Done |
| Client `kubernetes` créé | 🔲 À faire |
| Mapper `groups` configuré | 🔲 À faire |
| K3d OIDC config | 🔲 À faire |
| ClusterRoleBindings | 🔲 À faire |
| RoleBindings | 🔲 À faire |
| Test kubectl OIDC | 🔲 À faire |

---

## 10. kubectl avec OIDC

### 10.1 Configurer kubeconfig

```yaml
# ~/.kube/config
apiVersion: v1
kind: Config
clusters:
  - name: ai-security-platform
    cluster:
      server: https://kubernetes.default.svc
      certificate-authority: /path/to/ca.crt
contexts:
  - name: ai-platform-oidc
    context:
      cluster: ai-security-platform
      user: oidc-user
current-context: ai-platform-oidc
users:
  - name: oidc-user
    user:
      exec:
        apiVersion: client.authentication.k8s.io/v1beta1
        command: kubectl
        args:
          - oidc-login
          - get-token
          - --oidc-issuer-url=https://auth.ai-platform.localhost/realms/ai-platform
          - --oidc-client-id=kubernetes
```

### 10.2 Utiliser kubelogin

```bash
# Installer kubelogin
kubectl krew install oidc-login

# Login (ouvre le navigateur)
kubectl oidc-login setup \
  --oidc-issuer-url=https://auth.ai-platform.localhost/realms/ai-platform \
  --oidc-client-id=kubernetes

# Utiliser kubectl normalement
kubectl get pods  # Utilise automatiquement le token OIDC
```

### 10.3 Vérifier son identité

```bash
# Qui suis-je ?
kubectl auth whoami

# Exemple output:
# Username: alice
# Groups:
# - platform-admin
# - ai-engineer
# - system:authenticated

# Puis-je faire X ?
kubectl auth can-i get pods
kubectl auth can-i delete deployments -n ai-apps
kubectl auth can-i create namespaces
```

---

## 11. Troubleshooting

### 11.1 Vérifier le token

```bash
# Décoder le token
kubectl oidc-login get-token \
  --oidc-issuer-url=https://auth.ai-platform.localhost/realms/ai-platform \
  --oidc-client-id=kubernetes \
  | jq -R 'split(".") | .[1] | @base64d | fromjson'
```

Vérifie que `groups` contient bien les realm roles.

### 11.2 Logs API Server

```bash
# K3s
sudo journalctl -u k3s -f | grep -i oidc

# Chercher les erreurs d'authentification
sudo journalctl -u k3s | grep -i "authentication"
```

### 11.3 Erreurs courantes

| Erreur | Cause | Solution |
|--------|-------|----------|
| `Unauthorized` | Token invalide ou expiré | Re-login, vérifier issuer URL |
| `Forbidden` | RBAC refuse | Vérifier ClusterRoleBinding |
| `could not verify signature` | CA certificate manquant | Ajouter `--oidc-ca-file` |
| `groups claim not found` | Mapper Keycloak manquant | Créer le mapper `groups` |

### 11.4 Debug RBAC

```bash
# Voir tous les bindings
kubectl get clusterrolebindings -o wide | grep keycloak
kubectl get rolebindings -A -o wide | grep keycloak

# Détail d'un binding
kubectl describe clusterrolebinding keycloak-platform-admins

# Tester les permissions
kubectl auth can-i --list --as-group=platform-admin
```

---

## Résumé

1. **Realm Roles Keycloak** = Groupes d'utilisateurs pour K8s
2. **Le mapping n'est PAS automatique** - Tu crées les bindings
3. **ClusterRoleBinding** = Accès cluster-wide
4. **RoleBinding** = Accès à UN namespace
5. **Mapper Keycloak** nécessaire pour exposer les roles dans le token

---

## Ressources

- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Kubernetes OIDC Authentication](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [kubelogin](https://github.com/int128/kubelogin)

---

*Guide maintenu par l'équipe AI Security Platform - Janvier 2026*
