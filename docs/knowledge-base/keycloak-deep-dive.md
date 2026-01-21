# Keycloak - Deep Dive Technique

> Ce document couvre les concepts clés Keycloak pour une plateforme AI Security.

---

## 1. Architecture Keycloak

### 1.1 Composants principaux
```
┌─────────────────────────────────────────────────────────────┐
│                      KEYCLOAK                                │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Realm     │  │   Realm     │  │   Realm     │         │
│  │  "master"   │  │"ai-platform"│  │  "autre"    │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│                          │                                   │
│         ┌────────────────┼────────────────┐                 │
│         ▼                ▼                ▼                 │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐            │
│   │  Users   │    │  Clients │    │  Roles   │            │
│   │  Groups  │    │  (apps)  │    │  Mappers │            │
│   └──────────┘    └──────────┘    └──────────┘            │
├─────────────────────────────────────────────────────────────┤
│                      PostgreSQL                              │
│              (persistance des données)                       │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Pourquoi PostgreSQL et pas H2 ?

| Critère | H2 (embedded) | PostgreSQL |
|---------|---------------|------------|
| **Type** | Base embarquée Java | Base relationnelle externe |
| **Persistance** | Mémoire ou fichier local | Disque avec réplication |
| **Multi-instance** | ❌ Impossible | ✅ Clustering natif |
| **Haute dispo** | ❌ Non | ✅ Patroni, streaming replication |
| **Backups** | ❌ Manuel, risqué | ✅ pg_dump, PITR |
| **Production** | ❌ Jamais | ✅ Recommandé |

**Règle** : H2 pour dev local rapide, PostgreSQL pour tout le reste.

---

## 2. Concepts IAM

### 2.1 Realm

**Définition** : Espace isolé contenant users, clients, roles, groups.

**Analogie** : Un realm = un tenant. Isolation complète entre realms.

**Notre lab** :
- `master` : Realm admin Keycloak (ne pas toucher)
- `ai-platform` : Notre realm applicatif

### 2.2 Client

**Définition** : Application qui délègue l'authentification à Keycloak.

**Types de clients** :

| Type | Usage | Exemple |
|------|-------|---------|
| **Confidential** | Backend avec secret | ArgoCD, Grafana |
| **Public** | Frontend sans secret | SPA, mobile app |
| **Bearer-only** | API qui valide des tokens | REST API |

**Notre lab** :
- `argocd` : Confidential, OIDC
- `grafana` : Confidential, OIDC
- `open-webui` : Confidential, OIDC

### 2.3 Realm Roles vs Client Roles

| Aspect | Realm Roles | Client Roles |
|--------|-------------|--------------|
| **Scope** | Global au realm | Spécifique à un client |
| **Visibilité** | Toutes les applications | Une seule application |
| **Usage typique** | Rôles métier transverses | Permissions fines dans l'app |
| **K8s RBAC** | ✅ Mappable vers ClusterRoles | Rarement utilisé |

**Notre lab** :
```
Realm Roles (ai-platform)
├── platform-admin    → Accès complet (K8s admin)
├── ai-engineer       → Accès aux outils ML
├── security-auditor  → Lecture logs, dashboards
└── viewer            → Lecture seule globale

Client Roles (grafana)
├── Admin             → Config Grafana
├── Editor            → Créer dashboards
└── Viewer            → Voir dashboards

Client Roles (argocd)
├── admin             → Tout ArgoCD
└── readonly          → Voir les apps
```

### 2.4 Groups

**Définition** : Regroupement d'utilisateurs pour assigner des rôles en masse.

**Notre lab** :
```
Groups
├── platform-team     → Realm Role: platform-admin
├── data-scientists   → Realm Role: ai-engineer
├── security-team     → Realm Role: security-auditor
└── stakeholders      → Realm Role: viewer
```

### 2.5 Mappers

**Définition** : Transforment les données utilisateur en claims dans le token JWT.

**Types importants** :

| Mapper | Fonction |
|--------|----------|
| **Realm Role Mapper** | Inclut les realm roles dans le token |
| **Client Role Mapper** | Inclut les client roles dans le token |
| **Group Membership** | Inclut les groupes dans le token |
| **User Attribute** | Inclut des attributs custom |

**Pourquoi c'est important** : Sans mapper, les rôles ne sont pas dans le token → l'application ne peut pas faire de RBAC.

---

## 3. Intégration OIDC

### 3.1 Flow OpenID Connect
```
┌──────────┐     ┌──────────┐     ┌──────────┐
│   User   │     │   App    │     │ Keycloak │
└────┬─────┘     └────┬─────┘     └────┬─────┘
     │                │                │
     │ 1. Accès app   │                │
     │───────────────▶│                │
     │                │                │
     │ 2. Redirect    │                │
     │◀───────────────│                │
     │                                 │
     │ 3. Login Keycloak               │
     │────────────────────────────────▶│
     │                                 │
     │ 4. Auth Code                    │
     │◀────────────────────────────────│
     │                │                │
     │ 5. Code        │                │
     │───────────────▶│                │
     │                │ 6. Exchange    │
     │                │───────────────▶│
     │                │                │
     │                │ 7. Tokens      │
     │                │◀───────────────│
     │                │                │
     │ 8. Logged in   │                │
     │◀───────────────│                │
```

### 3.2 Configuration OIDC — Checklist

Pour chaque application :

1. **Dans Keycloak** :
   - [ ] Créer Client (type: OpenID Connect)
   - [ ] Client ID : `mon-app`
   - [ ] Access Type : `confidential`
   - [ ] Valid Redirect URIs : `https://mon-app.example.com/*`
   - [ ] Générer Client Secret
   - [ ] Configurer Mappers si besoin

2. **Dans l'application** :
   - [ ] OIDC Discovery URL : `https://keycloak/realms/ai-platform/.well-known/openid-configuration`
   - [ ] Client ID : `mon-app`
   - [ ] Client Secret : (depuis Keycloak)
   - [ ] Scopes : `openid profile email roles`

### 3.3 Endpoints importants

| Endpoint | URL | Usage |
|----------|-----|-------|
| Discovery | `/realms/{realm}/.well-known/openid-configuration` | Auto-configuration |
| Authorization | `/realms/{realm}/protocol/openid-connect/auth` | Début du login |
| Token | `/realms/{realm}/protocol/openid-connect/token` | Échange code → token |
| UserInfo | `/realms/{realm}/protocol/openid-connect/userinfo` | Infos utilisateur |
| Logout | `/realms/{realm}/protocol/openid-connect/logout` | Déconnexion |

---

## 4. Haute Disponibilité

### 4.1 Architecture HA
```
                    ┌─────────────┐
                    │   Traefik   │
                    │ (Ingress)   │
                    └──────┬──────┘
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
      ┌──────────────┐         ┌──────────────┐
      │  Keycloak 1  │◀───────▶│  Keycloak 2  │
      │  (replica)   │ Infini- │  (replica)   │
      └──────┬───────┘  span   └──────┬───────┘
             │                        │
             └───────────┬────────────┘
                         ▼
               ┌──────────────────┐
               │   PostgreSQL     │
               │   (shared DB)    │
               └──────────────────┘
```

### 4.2 Composants HA

| Composant | Rôle | Notre lab |
|-----------|------|-----------|
| **Load Balancer** | Distribue le trafic | Traefik |
| **Multiple replicas** | Redondance | 2 pods Keycloak |
| **Session clustering** | Sessions partagées | Infinispan (intégré) |
| **Database HA** | Persistance fiable | PostgreSQL |

---

## 5. Troubleshooting

### 5.1 Login échoue — Checklist

1. **Vérifier Events** : Keycloak Admin → Realm → Events → Login Events
2. **Codes d'erreur courants** :
   - `invalid_grant` : Code expiré ou déjà utilisé
   - `invalid_client` : Client ID ou secret incorrect
   - `invalid_redirect_uri` : URI non autorisée

### 5.2 Commandes utiles
```bash
# Logs Keycloak
kubectl logs -n keycloak deployment/keycloak -f

# Vérifier les pods
kubectl get pods -n keycloak

# Accéder à la console admin
kubectl port-forward svc/keycloak 8443:443 -n keycloak
```

---

## 6. Implémentation dans notre Lab

| Composant | Détail |
|-----------|--------|
| Keycloak | 2 replicas, Helm chart Bitnami |
| PostgreSQL | 1 instance, PVC persistant |
| Realm | `ai-platform` |
| Clients | argocd, grafana, open-webui, mlflow |
| Realm Roles | platform-admin, ai-engineer, security-auditor, viewer |
| Groups | platform-team, data-scientists, security-team |
