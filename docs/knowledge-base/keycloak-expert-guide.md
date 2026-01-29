# Keycloak - Guide Expert Complet

> **Objectif** : Maîtriser Keycloak et tous les protocoles IAM pour devenir expert en Identity & Access Management.
> 
> **Contexte** : AI Security Platform - Home Lab

---

## Table des Matières

1. [Introduction à l'IAM](#1-introduction-à-liam)
2. [Architecture Keycloak](#2-architecture-keycloak)
3. [Concepts Fondamentaux](#3-concepts-fondamentaux)
4. [Protocoles d'Authentification](#4-protocoles-dauthentification)
5. [OAuth 2.0 - Deep Dive](#5-oauth-20---deep-dive)
6. [OpenID Connect (OIDC) - Deep Dive](#6-openid-connect-oidc---deep-dive)
7. [SAML 2.0 - Deep Dive](#7-saml-20---deep-dive)
8. [WebAuthn & FIDO2 - Passwordless](#8-webauthn--fido2---passwordless)
9. [Configuration Avancée](#9-configuration-avancée)
10. [Haute Disponibilité](#10-haute-disponibilité)
11. [Sécurité & Hardening](#11-sécurité--hardening)
12. [Intégration Kubernetes](#12-intégration-kubernetes)
13. [Troubleshooting](#13-troubleshooting)
14. [Implémentation Lab](#14-implémentation-lab)

---

## 1. Introduction à l'IAM

### 1.1 Qu'est-ce que l'IAM ?

**Identity and Access Management (IAM)** est l'ensemble des processus et technologies pour gérer :

| Composant | Question | Exemple |
|-----------|----------|---------|
| **Identification** | Qui êtes-vous ? | Username, email |
| **Authentification** | Prouvez-le ! | Password, MFA, biométrie |
| **Autorisation** | Que pouvez-vous faire ? | Rôles, permissions |
| **Audit** | Qu'avez-vous fait ? | Logs, traces |

### 1.2 Pourquoi un Identity Provider (IdP) ?

**Sans IdP** :
```
┌─────────┐     ┌─────────┐     ┌─────────┐
│  App 1  │     │  App 2  │     │  App 3  │
│ Users DB│     │ Users DB│     │ Users DB│
│ Auth    │     │ Auth    │     │ Auth    │
└─────────┘     └─────────┘     └─────────┘
     ↑               ↑               ↑
     │               │               │
     └───────────────┴───────────────┘
              User gère 3 passwords
              Admin gère 3 bases users
```

**Avec IdP (Keycloak)** :
```
┌─────────┐     ┌─────────┐     ┌─────────┐
│  App 1  │     │  App 2  │     │  App 3  │
│ (OIDC)  │     │ (SAML)  │     │ (OIDC)  │
└────┬────┘     └────┬────┘     └────┬────┘
     │               │               │
     └───────────────┼───────────────┘
                     ▼
              ┌─────────────┐
              │  Keycloak   │
              │  (IdP)      │
              │  Users DB   │
              └─────────────┘
                     ↑
              User: 1 password (SSO)
              Admin: 1 base centralisée
```

### 1.3 Keycloak vs Alternatives

| Solution | Type | Forces | Faiblesses |
|----------|------|--------|------------|
| **Keycloak** | Open Source | Complet, enterprise-ready, Red Hat | RAM, complexité |
| **Authentik** | Open Source | UI moderne, Python | Moins mature |
| **Okta** | SaaS | Zero maintenance | Coût, vendor lock-in |
| **Azure AD** | SaaS | Intégration MS | Coût, complexité |
| **Auth0** | SaaS | Developer-friendly | Coût |
| **Dex** | Open Source | Léger, K8s natif | Fonctionnalités limitées |

**Pourquoi Keycloak pour notre lab** :
- ✅ Open source, pas de coût
- ✅ Feature-complete (OIDC, SAML, LDAP, MFA)
- ✅ Enterprise standard (Red Hat SSO)
- ✅ Skills transférables en entreprise
- ✅ Intégration Kubernetes native

---

## 2. Architecture Keycloak

### 2.1 Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           KEYCLOAK SERVER                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                         REALMS                                    │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │   │
│  │  │   master    │  │ ai-platform │  │   other     │              │   │
│  │  │  (admin)    │  │  (our app)  │  │  (tenant)   │              │   │
│  │  └─────────────┘  └──────┬──────┘  └─────────────┘              │   │
│  └──────────────────────────┼────────────────────────────────────────┘   │
│                             │                                            │
│         ┌───────────────────┼───────────────────┐                       │
│         ▼                   ▼                   ▼                       │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐              │
│  │   USERS     │     │  CLIENTS    │     │   ROLES     │              │
│  │   GROUPS    │     │  (Apps)     │     │  MAPPERS    │              │
│  │  FEDERATION │     │  SCOPES     │     │ PERMISSIONS │              │
│  └─────────────┘     └─────────────┘     └─────────────┘              │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│                         PROVIDERS                                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │  OIDC    │ │  SAML    │ │  LDAP    │ │  Social  │ │  Custom  │    │
│  │ Provider │ │ Provider │ │ Provider │ │ Provider │ │ Provider │    │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘    │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│                         INFINISPAN                                       │
│                    (Distributed Cache)                                   │
│              Sessions, AuthN cache, Tokens                               │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│                         DATABASE                                         │
│                       (PostgreSQL)                                       │
│            Users, Clients, Realms, Events, etc.                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Composants internes

| Composant | Rôle | Technologie |
|-----------|------|-------------|
| **Quarkus** | Runtime applicatif | Java, GraalVM-ready |
| **Infinispan** | Cache distribué | Sessions, tokens, cache |
| **Hibernate** | ORM | Persistance DB |
| **RESTEasy** | API REST | Admin API, endpoints |
| **Undertow** | Web server | HTTP/HTTPS |

### 2.3 Ports et endpoints

| Port | Usage | URL |
|------|-------|-----|
| 8080 | HTTP | `/realms/{realm}/...` |
| 8443 | HTTPS | `/realms/{realm}/...` |
| 9000 | Management | `/health`, `/metrics` |
| 7800 | JGroups | Clustering Infinispan |

---

## 3. Concepts Fondamentaux

### 3.1 Realm

**Définition** : Espace de travail isolé contenant users, clients, roles, groups.

```
┌─────────────────────────────────────────────────────────────┐
│                       KEYCLOAK                               │
│  ┌─────────────────┐  ┌─────────────────┐                   │
│  │  Realm: master  │  │ Realm: ai-platform │                │
│  │                 │  │                    │                │
│  │  • admin users  │  │  • app users       │                │
│  │  • KC config    │  │  • app clients     │                │
│  │                 │  │  • app roles       │                │
│  │  ══════════════ │  │  ══════════════════│                │
│  │   ISOLATION     │  │     ISOLATION      │                │
│  └─────────────────┘  └────────────────────┘                │
│         ↑                      ↑                            │
│         │                      │                            │
│    Ne JAMAIS          Votre realm                           │
│    utiliser           applicatif                            │
│    pour apps                                                │
└─────────────────────────────────────────────────────────────┘
```

**Bonnes pratiques** :
- ✅ Un realm par tenant/environnement
- ✅ Realm `master` uniquement pour admin Keycloak
- ✅ Nommer clairement : `ai-platform`, `prod`, `staging`

**Notre lab** :
- `master` : Admin Keycloak uniquement
- `ai-platform` : Toutes nos applications

### 3.2 Users

**Définition** : Entité pouvant s'authentifier.

**Attributs d'un user** :

| Attribut | Type | Description |
|----------|------|-------------|
| `username` | String | Identifiant unique (login) |
| `email` | String | Adresse email |
| `firstName` | String | Prénom |
| `lastName` | String | Nom |
| `enabled` | Boolean | Compte actif |
| `emailVerified` | Boolean | Email vérifié |
| `attributes` | Map | Attributs custom |
| `credentials` | List | Mots de passe, OTP |
| `requiredActions` | List | Actions requises au login |

**Required Actions courantes** :

| Action | Description |
|--------|-------------|
| `UPDATE_PASSWORD` | Forcer changement password |
| `VERIFY_EMAIL` | Vérifier l'email |
| `CONFIGURE_TOTP` | Configurer MFA |
| `UPDATE_PROFILE` | Compléter le profil |

### 3.3 Groups

**Définition** : Regroupement d'utilisateurs pour assigner des rôles en masse.

```
Groups
├── platform-team
│   ├── User: alice (hérite platform-admin)
│   └── User: bob   (hérite platform-admin)
│
├── data-scientists
│   ├── User: charlie (hérite ai-engineer)
│   └── User: diana   (hérite ai-engineer)
│
└── security-team
    └── User: eve (hérite security-auditor)
```

**Hiérarchie** : Les groupes peuvent être imbriqués, les rôles sont hérités.

```
Groups
└── engineering
    ├── Role: base-access
    ├── frontend-team
    │   └── Role: frontend-deploy
    └── backend-team
        └── Role: backend-deploy

User dans backend-team hérite: base-access + backend-deploy
```

### 3.4 Clients

**Définition** : Application qui délègue l'authentification à Keycloak.

**Types de clients** :

| Type | Access Type | Secret | Use Case |
|------|-------------|--------|----------|
| **Confidential** | `confidential` | ✅ Oui | Backend apps, serveurs |
| **Public** | `public` | ❌ Non | SPA, mobile apps |
| **Bearer-only** | `bearer-only` | N/A | API REST (valide tokens) |

**Paramètres clés d'un client** :

| Paramètre | Description | Exemple |
|-----------|-------------|---------|
| `Client ID` | Identifiant unique | `open-webui` |
| `Client Secret` | Secret pour confidential | `ZKAf...MR3` |
| `Valid Redirect URIs` | URIs de callback autorisées | `https://app.local/*` |
| `Web Origins` | CORS origins | `https://app.local` |
| `Root URL` | URL de base de l'app | `https://app.local` |

**Notre lab** :

| Client | Type | Protocol | Usage |
|--------|------|----------|-------|
| `open-webui` | Confidential | OIDC | Chat UI |
| `argocd` | Confidential | OIDC | GitOps |
| `grafana` | Confidential | OIDC | Monitoring |

### 3.5 Roles

**Deux types de rôles** :

#### Realm Roles (globaux)

```
Realm: ai-platform
└── Realm Roles
    ├── platform-admin    → Accès complet plateforme
    ├── ai-engineer       → Accès outils ML
    ├── security-auditor  → Lecture sécurité
    └── viewer            → Lecture seule
```

**Usage** : Permissions transverses à toutes les applications.

#### Client Roles (spécifiques)

```
Realm: ai-platform
└── Client: grafana
    └── Client Roles
        ├── Admin   → Config Grafana
        ├── Editor  → Créer dashboards
        └── Viewer  → Voir dashboards
```

**Usage** : Permissions spécifiques à une application.

**Mapping Realm → Client** :

```
Realm Role: ai-engineer
    │
    ├──► Client Role (grafana): Editor
    ├──► Client Role (argocd): readonly
    └──► Client Role (open-webui): user
```

### 3.6 Mappers (Protocol Mappers)

**Définition** : Transforment les données utilisateur en claims dans le token.

**Pourquoi c'est crucial** : Sans mapper, les rôles/groupes ne sont PAS dans le token !

**Types de mappers courants** :

| Mapper | Ce qu'il ajoute au token |
|--------|--------------------------|
| `realm roles` | Liste des realm roles |
| `client roles` | Liste des client roles |
| `groups` | Liste des groupes |
| `audience` | Audience (aud claim) |
| `user attribute` | Attribut custom user |
| `hardcoded claim` | Valeur fixe |

**Exemple de token SANS mapper roles** :
```json
{
  "sub": "user-123",
  "email": "alice@example.com",
  "name": "Alice"
  // PAS DE ROLES !
}
```

**Exemple de token AVEC mapper roles** :
```json
{
  "sub": "user-123",
  "email": "alice@example.com",
  "name": "Alice",
  "realm_access": {
    "roles": ["platform-admin", "ai-engineer"]
  },
  "resource_access": {
    "grafana": {
      "roles": ["Admin"]
    }
  }
}
```

### 3.7 Scopes

**Définition** : Définit quelles informations sont incluses dans le token.

**Scopes standards OIDC** :

| Scope | Claims ajoutés |
|-------|----------------|
| `openid` | `sub` (obligatoire pour OIDC) |
| `profile` | `name`, `family_name`, `given_name`, etc. |
| `email` | `email`, `email_verified` |
| `address` | `address` |
| `phone` | `phone_number`, `phone_number_verified` |
| `roles` | `realm_access`, `resource_access` |
| `groups` | `groups` |

**Client Scopes** : Dans Keycloak, les scopes sont configurés comme "Client Scopes" et assignés aux clients.

---

## 4. Protocoles d'Authentification

### 4.1 Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────┐
│                    PROTOCOLES IAM                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐        │
│  │   OAuth 2.0  │   │     OIDC     │   │   SAML 2.0  │        │
│  │              │   │              │   │              │        │
│  │ Autorisation │   │ Auth + ID    │   │ Auth + ID   │        │
│  │   (tokens)   │   │  (OAuth2+)   │   │    (XML)    │        │
│  └──────────────┘   └──────────────┘   └──────────────┘        │
│         │                  │                  │                 │
│         └──────────────────┼──────────────────┘                 │
│                            ▼                                    │
│                   ┌──────────────┐                              │
│                   │   WebAuthn   │                              │
│                   │    FIDO2     │                              │
│                   │              │                              │
│                   │ Passwordless │                              │
│                   └──────────────┘                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 Comparaison des protocoles

| Critère | OAuth 2.0 | OIDC | SAML 2.0 |
|---------|-----------|------|----------|
| **Objectif** | Autorisation | Authentification + ID | Authentification + ID |
| **Format** | JSON | JSON (JWT) | XML |
| **Transport** | REST API | REST API | HTTP POST/Redirect |
| **Token** | Access Token | ID Token + Access Token | Assertion XML |
| **Année** | 2012 | 2014 | 2005 |
| **Usage moderne** | APIs, Mobile | Web apps, SPAs, APIs | Enterprise legacy |
| **Complexité** | Moyenne | Moyenne | Élevée |

### 4.3 Quand utiliser quoi ?

| Situation | Protocole recommandé |
|-----------|---------------------|
| Application web moderne | **OIDC** |
| Single Page Application (SPA) | **OIDC** (avec PKCE) |
| API REST | **OAuth 2.0** |
| Mobile app | **OIDC** (avec PKCE) |
| Enterprise legacy (SAP, etc.) | **SAML 2.0** |
| Fédération entreprise | **SAML 2.0** ou **OIDC** |
| Passwordless / MFA | **WebAuthn/FIDO2** |

---

## 5. OAuth 2.0 - Deep Dive

### 5.1 Qu'est-ce que OAuth 2.0 ?

**OAuth 2.0** est un protocole d'**autorisation** (pas d'authentification !).

**Analogie** : OAuth = Voiturier parking
- Vous donnez une clé limitée (valet key) au voiturier
- Il peut déplacer la voiture mais pas ouvrir le coffre
- Vous gardez le contrôle

**En informatique** :
- L'app reçoit un token avec des permissions limitées
- L'app accède aux ressources sans connaître le mot de passe
- L'utilisateur garde le contrôle (peut révoquer)

### 5.2 Acteurs OAuth 2.0

```
┌─────────────────┐
│ Resource Owner  │  ← L'utilisateur (vous)
└────────┬────────┘
         │ Autorise
         ▼
┌─────────────────┐         ┌─────────────────┐
│     Client      │────────▶│ Authorization   │
│   (l'app)       │◀────────│    Server       │
└────────┬────────┘ Tokens  │  (Keycloak)     │
         │                  └─────────────────┘
         │ Access Token
         ▼
┌─────────────────┐
│ Resource Server │  ← L'API (données)
└─────────────────┘
```

| Acteur | Rôle | Exemple |
|--------|------|---------|
| **Resource Owner** | Propriétaire des données | L'utilisateur |
| **Client** | Application qui veut accéder | Open WebUI |
| **Authorization Server** | Délivre les tokens | Keycloak |
| **Resource Server** | Détient les données | API, Ollama |

### 5.3 Flows OAuth 2.0

#### Authorization Code Flow (recommandé pour web apps)

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│   User   │     │  Client  │     │ Keycloak │     │   API    │
└────┬─────┘     └────┬─────┘     └────┬─────┘     └────┬─────┘
     │                │                │                │
     │ 1. Click login │                │                │
     │───────────────▶│                │                │
     │                │                │                │
     │                │ 2. Redirect    │                │
     │◀───────────────│───────────────▶│                │
     │                │                │                │
     │ 3. Login form  │                │                │
     │◀────────────────────────────────│                │
     │                │                │                │
     │ 4. Credentials │                │                │
     │────────────────────────────────▶│                │
     │                │                │                │
     │ 5. Auth Code (redirect)         │                │
     │◀────────────────────────────────│                │
     │───────────────▶│                │                │
     │                │                │                │
     │                │ 6. Exchange code for tokens     │
     │                │───────────────▶│                │
     │                │                │                │
     │                │ 7. Access + Refresh Token       │
     │                │◀───────────────│                │
     │                │                │                │
     │                │ 8. API call with token          │
     │                │───────────────────────────────▶│
     │                │                │                │
     │                │ 9. Protected data               │
     │                │◀───────────────────────────────│
     │                │                │                │
     │ 10. Show data  │                │                │
     │◀───────────────│                │                │
```

#### Authorization Code + PKCE (pour SPA/Mobile)

**PKCE** (Proof Key for Code Exchange) protège contre l'interception du code.

```
Client génère:
  code_verifier = random_string(43-128 chars)
  code_challenge = BASE64URL(SHA256(code_verifier))

1. Authorization request inclut code_challenge
2. Token request inclut code_verifier
3. Keycloak vérifie: SHA256(code_verifier) == code_challenge
```

**Pourquoi PKCE ?** Les SPA/Mobile ne peuvent pas garder un secret (code visible).

#### Client Credentials Flow (machine-to-machine)

```
┌──────────┐     ┌──────────┐
│  Client  │     │ Keycloak │
│ (daemon) │     │          │
└────┬─────┘     └────┬─────┘
     │                │
     │ 1. client_id + client_secret
     │───────────────▶│
     │                │
     │ 2. Access Token│
     │◀───────────────│
```

**Usage** : Services backend, jobs, scripts automatisés.

#### Resource Owner Password (déprécié)

```
User → Client: username + password
Client → Keycloak: username + password + client_id
Keycloak → Client: tokens
```

**⚠️ NE PAS UTILISER** : L'app voit le mot de passe. Legacy only.

### 5.4 Tokens OAuth 2.0

#### Access Token

| Attribut | Valeur |
|----------|--------|
| **Format** | JWT (souvent) ou opaque |
| **Durée** | Courte (5-15 min) |
| **Usage** | Accéder aux ressources |
| **Contenu** | Permissions, scopes |

#### Refresh Token

| Attribut | Valeur |
|----------|--------|
| **Format** | Opaque string |
| **Durée** | Longue (heures/jours) |
| **Usage** | Obtenir nouveaux access tokens |
| **Stockage** | Sécurisé, backend only |

### 5.5 Scopes OAuth 2.0

Les **scopes** définissent les permissions demandées :

```
GET /authorize?
  response_type=code&
  client_id=my-app&
  scope=read:users write:posts&  ← Scopes demandés
  redirect_uri=...
```

---

## 6. OpenID Connect (OIDC) - Deep Dive

### 6.1 OIDC = OAuth 2.0 + Identité

**OAuth 2.0** : "Tu peux accéder à ces données"
**OIDC** : "Tu peux accéder à ces données ET voici qui est l'utilisateur"

```
┌─────────────────────────────────────────────────────────────┐
│                         OIDC                                 │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    OAuth 2.0                          │  │
│  │        (Authorization Framework)                      │  │
│  └───────────────────────────────────────────────────────┘  │
│                          +                                   │
│  ┌───────────────────────────────────────────────────────┐  │
│  │               Identity Layer                          │  │
│  │     - ID Token (JWT avec infos user)                 │  │
│  │     - UserInfo endpoint                               │  │
│  │     - Standard claims                                 │  │
│  │     - Discovery document                              │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 ID Token

**Le cœur d'OIDC** : Un JWT contenant l'identité de l'utilisateur.

```json
{
  "iss": "https://auth.ai-platform.localhost/realms/ai-platform",
  "sub": "f23a4567-e89b-12d3-a456-426614174000",
  "aud": "open-webui",
  "exp": 1706544000,
  "iat": 1706540400,
  "auth_time": 1706540300,
  "nonce": "abc123",
  "acr": "1",
  "azp": "open-webui",
  "name": "Alice Martin",
  "preferred_username": "alice",
  "email": "alice@example.com",
  "email_verified": true,
  "realm_access": {
    "roles": ["ai-engineer", "viewer"]
  }
}
```

**Claims standards** :

| Claim | Description |
|-------|-------------|
| `iss` | Issuer - qui a émis le token |
| `sub` | Subject - ID unique de l'user |
| `aud` | Audience - pour qui est le token |
| `exp` | Expiration time |
| `iat` | Issued at time |
| `auth_time` | Quand l'user s'est authentifié |
| `nonce` | Protection contre replay attacks |
| `acr` | Authentication Context Class Reference |
| `azp` | Authorized party |

### 6.3 Discovery Document

**URL** : `/.well-known/openid-configuration`

**Notre lab** : `https://auth.ai-platform.localhost/realms/ai-platform/.well-known/openid-configuration`

```json
{
  "issuer": "https://auth.ai-platform.localhost/realms/ai-platform",
  "authorization_endpoint": "https://auth.ai-platform.localhost/realms/ai-platform/protocol/openid-connect/auth",
  "token_endpoint": "https://auth.ai-platform.localhost/realms/ai-platform/protocol/openid-connect/token",
  "userinfo_endpoint": "https://auth.ai-platform.localhost/realms/ai-platform/protocol/openid-connect/userinfo",
  "jwks_uri": "https://auth.ai-platform.localhost/realms/ai-platform/protocol/openid-connect/certs",
  "end_session_endpoint": "https://auth.ai-platform.localhost/realms/ai-platform/protocol/openid-connect/logout",
  "scopes_supported": ["openid", "profile", "email", "roles", "groups"],
  "response_types_supported": ["code", "token", "id_token"],
  "grant_types_supported": ["authorization_code", "refresh_token", "client_credentials"],
  "token_endpoint_auth_methods_supported": ["client_secret_basic", "client_secret_post", "private_key_jwt"]
}
```

**Avantage** : L'app découvre automatiquement tous les endpoints !

### 6.4 Endpoints OIDC

| Endpoint | URL | Usage |
|----------|-----|-------|
| **Authorization** | `/protocol/openid-connect/auth` | Démarrer le login |
| **Token** | `/protocol/openid-connect/token` | Échanger code → tokens |
| **UserInfo** | `/protocol/openid-connect/userinfo` | Infos user (avec access token) |
| **JWKS** | `/protocol/openid-connect/certs` | Clés publiques pour vérifier JWT |
| **Logout** | `/protocol/openid-connect/logout` | Déconnexion |
| **Introspection** | `/protocol/openid-connect/token/introspect` | Valider un token |

### 6.5 OIDC Flow complet

```
┌──────────┐     ┌──────────┐     ┌──────────┐
│   User   │     │ Open     │     │ Keycloak │
│ Browser  │     │ WebUI    │     │          │
└────┬─────┘     └────┬─────┘     └────┬─────┘
     │                │                │
     │ 1. Access /    │                │
     │───────────────▶│                │
     │                │                │
     │ 2. 302 Redirect to Keycloak     │
     │◀───────────────│                │
     │                │                │
     │ 3. GET /auth?client_id=open-webui&scope=openid...
     │────────────────────────────────▶│
     │                │                │
     │ 4. Login page  │                │
     │◀────────────────────────────────│
     │                │                │
     │ 5. POST credentials             │
     │────────────────────────────────▶│
     │                │                │
     │ 6. 302 Redirect with code       │
     │◀────────────────────────────────│
     │                │                │
     │ 7. GET /callback?code=xxx       │
     │───────────────▶│                │
     │                │                │
     │                │ 8. POST /token │
     │                │   code + secret│
     │                │───────────────▶│
     │                │                │
     │                │ 9. ID Token +  │
     │                │    Access Token│
     │                │◀───────────────│
     │                │                │
     │                │ 10. Validate   │
     │                │     ID Token   │
     │                │                │
     │ 11. Set session│                │
     │◀───────────────│                │
     │                │                │
     │ 12. Access app │                │
     │◀───────────────│                │
```

### 6.6 Validation du Token

L'application DOIT valider le token :

1. **Signature** : Vérifier avec la clé publique (JWKS)
2. **Issuer (iss)** : Doit correspondre au Keycloak attendu
3. **Audience (aud)** : Doit contenir le client_id de l'app
4. **Expiration (exp)** : Token non expiré
5. **Nonce** : Correspond à celui envoyé (protection replay)

---

## 7. SAML 2.0 - Deep Dive

### 7.1 Qu'est-ce que SAML ?

**Security Assertion Markup Language** - Standard XML pour échanger des données d'authentification.

**Historique** : Créé en 2005, avant OAuth/OIDC. Très répandu en entreprise.

### 7.2 Acteurs SAML

| Acteur SAML | Équivalent OIDC | Rôle |
|-------------|-----------------|------|
| **Identity Provider (IdP)** | Authorization Server | Authentifie l'user (Keycloak) |
| **Service Provider (SP)** | Client/Relying Party | L'application |
| **Principal** | Resource Owner | L'utilisateur |

### 7.3 Assertion SAML

```xml
<saml:Assertion xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
                ID="_abc123" IssueInstant="2025-01-29T10:00:00Z">
  
  <saml:Issuer>https://auth.ai-platform.localhost/realms/ai-platform</saml:Issuer>
  
  <saml:Subject>
    <saml:NameID Format="urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified">
      alice
    </saml:NameID>
  </saml:Subject>
  
  <saml:Conditions NotBefore="2025-01-29T10:00:00Z" 
                   NotOnOrAfter="2025-01-29T10:05:00Z">
    <saml:AudienceRestriction>
      <saml:Audience>https://my-app.example.com</saml:Audience>
    </saml:AudienceRestriction>
  </saml:Conditions>
  
  <saml:AuthnStatement AuthnInstant="2025-01-29T10:00:00Z">
    <saml:AuthnContext>
      <saml:AuthnContextClassRef>
        urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport
      </saml:AuthnContextClassRef>
    </saml:AuthnContext>
  </saml:AuthnStatement>
  
  <saml:AttributeStatement>
    <saml:Attribute Name="email">
      <saml:AttributeValue>alice@example.com</saml:AttributeValue>
    </saml:Attribute>
    <saml:Attribute Name="roles">
      <saml:AttributeValue>admin</saml:AttributeValue>
      <saml:AttributeValue>user</saml:AttributeValue>
    </saml:Attribute>
  </saml:AttributeStatement>
  
  <ds:Signature>...</ds:Signature>
  
</saml:Assertion>
```

### 7.4 Flows SAML

#### SP-Initiated (le plus courant)

```
┌──────────┐     ┌──────────┐     ┌──────────┐
│   User   │     │    SP    │     │   IdP    │
│          │     │  (App)   │     │(Keycloak)│
└────┬─────┘     └────┬─────┘     └────┬─────┘
     │                │                │
     │ 1. Access app  │                │
     │───────────────▶│                │
     │                │                │
     │ 2. Redirect    │                │
     │◀───────────────│                │
     │                │                │
     │ 3. POST SAMLRequest             │
     │────────────────────────────────▶│
     │                │                │
     │ 4. Login form  │                │
     │◀────────────────────────────────│
     │                │                │
     │ 5. Credentials │                │
     │────────────────────────────────▶│
     │                │                │
     │ 6. POST SAMLResponse (Assertion)│
     │◀────────────────────────────────│
     │───────────────▶│                │
     │                │                │
     │                │ 7. Validate    │
     │                │    Assertion   │
     │                │                │
     │ 8. Access granted               │
     │◀───────────────│                │
```

#### IdP-Initiated

L'utilisateur démarre depuis un portail IdP (ex: intranet).

### 7.5 SAML vs OIDC

| Aspect | SAML 2.0 | OIDC |
|--------|----------|------|
| **Format** | XML | JSON |
| **Taille message** | Gros (XML) | Compact (JWT) |
| **Signature** | XML Signature | JWT Signature |
| **Mobile-friendly** | ❌ Non | ✅ Oui |
| **Implémentation** | Complexe | Simple |
| **Enterprise legacy** | ✅ Très répandu | En adoption |
| **APIs modernes** | ❌ Inadapté | ✅ Natif |

**Règle pragmatique** :
- Application moderne → **OIDC**
- Intégration legacy enterprise (SAP, etc.) → **SAML**

---

## 8. WebAuthn & FIDO2 - Passwordless

### 8.1 Le problème des mots de passe

| Problème | Impact |
|----------|--------|
| Réutilisation | Un breach = tous les comptes compromis |
| Phishing | Users donnent leurs passwords |
| Complexité | Users choisissent passwords faibles |
| Support IT | Reset password = coût |

### 8.2 Solution : FIDO2 / WebAuthn

**FIDO2** = **WebAuthn** (API navigateur) + **CTAP** (protocole authenticator)

```
┌─────────────────────────────────────────────────────────────┐
│                         FIDO2                                │
│  ┌──────────────────────┐  ┌──────────────────────┐        │
│  │      WebAuthn        │  │        CTAP          │        │
│  │   (Web API)          │  │  (Client to Auth)    │        │
│  │                      │  │                      │        │
│  │  navigator.          │  │  USB, NFC, BLE,      │        │
│  │  credentials.        │  │  Platform            │        │
│  │  create() / get()    │  │                      │        │
│  └──────────────────────┘  └──────────────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

### 8.3 Types d'Authenticators

| Type | Exemple | Portabilité |
|------|---------|-------------|
| **Roaming** | YubiKey, Titan Key | ✅ Multi-device |
| **Platform** | TouchID, Windows Hello | ❌ Single device |
| **Passkey** | iCloud Keychain, Google | ✅ Synced |

### 8.4 Flow WebAuthn - Registration

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│   User   │     │ Browser  │     │ Keycloak │     │ Authenti │
│          │     │          │     │          │     │   cator  │
└────┬─────┘     └────┬─────┘     └────┬─────┘     └────┬─────┘
     │                │                │                │
     │ 1. Register    │                │                │
     │───────────────▶│───────────────▶│                │
     │                │                │                │
     │                │ 2. Challenge + options          │
     │                │◀───────────────│                │
     │                │                │                │
     │                │ 3. navigator.credentials.create()
     │                │───────────────────────────────▶│
     │                │                │                │
     │ 4. Touch/Bio   │                │                │
     │◀───────────────────────────────────────────────│
     │────────────────────────────────────────────────▶│
     │                │                │                │
     │                │ 5. Credential (public key)     │
     │                │◀───────────────────────────────│
     │                │                │                │
     │                │ 6. Send credential              │
     │                │───────────────▶│                │
     │                │                │                │
     │                │                │ 7. Store pubkey│
     │                │                │                │
     │                │ 8. Success     │                │
     │◀───────────────│◀───────────────│                │
```

### 8.5 Flow WebAuthn - Authentication

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│   User   │     │ Browser  │     │ Keycloak │     │ Authenti │
│          │     │          │     │          │     │   cator  │
└────┬─────┘     └────┬─────┘     └────┬─────┘     └────┬─────┘
     │                │                │                │
     │ 1. Login       │                │                │
     │───────────────▶│───────────────▶│                │
     │                │                │                │
     │                │ 2. Challenge   │                │
     │                │◀───────────────│                │
     │                │                │                │
     │                │ 3. navigator.credentials.get() │
     │                │───────────────────────────────▶│
     │                │                │                │
     │ 4. Touch/Bio   │                │                │
     │◀───────────────────────────────────────────────│
     │────────────────────────────────────────────────▶│
     │                │                │                │
     │                │ 5. Signed assertion             │
     │                │◀───────────────────────────────│
     │                │                │                │
     │                │ 6. Send assertion               │
     │                │───────────────▶│                │
     │                │                │                │
     │                │                │ 7. Verify sig  │
     │                │                │    with pubkey │
     │                │                │                │
     │                │ 8. Tokens      │                │
     │◀───────────────│◀───────────────│                │
```

### 8.6 Configurer WebAuthn dans Keycloak

1. **Realm Settings** → **Authentication**
2. Créer un nouveau flow ou modifier `browser`
3. Ajouter **WebAuthn Authenticator**
4. Configurer :
   - **User verification** : `required` / `preferred` / `discouraged`
   - **Authenticator attachment** : `platform` / `cross-platform`

### 8.7 Passkeys (FIDO2 synced)

**Passkeys** = WebAuthn credentials synchronisés dans le cloud (Apple, Google, Microsoft).

| Avantage | Description |
|----------|-------------|
| **UX** | Comme un password manager, mais mieux |
| **Phishing-proof** | Lié au domaine |
| **Multi-device** | Synced via iCloud/Google |
| **Recovery** | Via le cloud provider |

---

## 9. Configuration Avancée

### 9.1 Authentication Flows

**Flows par défaut** :

| Flow | Usage |
|------|-------|
| `browser` | Login via navigateur |
| `direct grant` | Resource Owner Password (legacy) |
| `registration` | Inscription |
| `reset credentials` | Reset password |
| `clients` | Auth des clients (service accounts) |

**Customiser un flow** :

```
Browser Flow (custom)
├── Cookie                    [ALTERNATIVE]
├── Identity Provider Redirect [ALTERNATIVE]
└── Forms                      [ALTERNATIVE]
    ├── Username Password Form [REQUIRED]
    └── OTP Form               [CONDITIONAL]
        └── Condition: user has OTP configured
```

### 9.2 Identity Federation

**Connecter des IdP externes** :

```
┌──────────┐     ┌──────────┐     ┌──────────┐
│   User   │     │ Keycloak │     │ External │
│          │     │          │     │   IdP    │
└────┬─────┘     └────┬─────┘     └────┬─────┘
     │                │                │
     │ 1. Login       │                │
     │───────────────▶│                │
     │                │                │
     │ 2. Choose IdP  │                │
     │◀───────────────│                │
     │───────────────▶│                │
     │                │                │
     │                │ 3. Redirect    │
     │◀───────────────│───────────────▶│
     │                │                │
     │ 4. Auth at IdP │                │
     │◀───────────────────────────────▶│
     │                │                │
     │                │ 5. Token/Assertion
     │                │◀───────────────│
     │                │                │
     │                │ 6. Create/link │
     │                │    local user  │
     │                │                │
     │ 7. Logged in   │                │
     │◀───────────────│                │
```

**Types d'IdP supportés** :
- OIDC (Google, Azure AD, Auth0...)
- SAML (ADFS, Okta, enterprise IdPs)
- Social (GitHub, Facebook, Twitter)
- LDAP/Active Directory

### 9.3 User Federation (LDAP/AD)

```
┌──────────────────────────────────────────────────────────┐
│                      Keycloak                             │
│  ┌─────────────┐                    ┌─────────────┐     │
│  │   Realm     │                    │    LDAP     │     │
│  │   Users     │◀═══sync═══════════▶│   Server    │     │
│  │ (local DB)  │                    │ (external)  │     │
│  └─────────────┘                    └─────────────┘     │
└──────────────────────────────────────────────────────────┘
```

**Modes de sync** :

| Mode | Description |
|------|-------------|
| **Import** | Copie users dans Keycloak DB |
| **No import** | Query LDAP à chaque auth |
| **Periodic sync** | Sync planifié |

### 9.4 Mappers avancés

**Script Mapper** (JavaScript) :

```javascript
// Ajouter un claim custom basé sur la logique
var groups = user.getGroups();
var isAdmin = false;

for each (var group in groups) {
    if (group.getName() == 'admin-group') {
        isAdmin = true;
        break;
    }
}

token.setOtherClaims('is_admin', isAdmin);
```

**Hardcoded Claim** :

Ajouter une valeur fixe :
```
Claim name: environment
Claim value: production
```

---

## 10. Haute Disponibilité

### 10.1 Architecture HA

```
                         ┌─────────────┐
                         │ Load Balancer│
                         │  (Traefik)   │
                         └──────┬──────┘
                                │
              ┌─────────────────┼─────────────────┐
              ▼                 ▼                 ▼
       ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
       │ Keycloak 1  │   │ Keycloak 2  │   │ Keycloak 3  │
       │  (pod)      │◀─▶│  (pod)      │◀─▶│  (pod)      │
       └──────┬──────┘   └──────┬──────┘   └──────┬──────┘
              │   Infinispan    │                 │
              │   (JGroups)     │                 │
              └─────────────────┼─────────────────┘
                                │
                         ┌──────┴──────┐
                         │ PostgreSQL  │
                         │  (Primary)  │
                         └──────┬──────┘
                                │
                         ┌──────┴──────┐
                         │ PostgreSQL  │
                         │  (Replica)  │
                         └─────────────┘
```

### 10.2 Infinispan Cache

**Caches distribués** :

| Cache | Contenu | Réplication |
|-------|---------|-------------|
| `sessions` | User sessions | Sync |
| `authenticationSessions` | Auth en cours | Sync |
| `offlineSessions` | Offline tokens | Async |
| `loginFailures` | Brute force protection | Sync |
| `work` | Invalidation cache | Sync |

### 10.3 Sticky Sessions vs Distributed

| Mode | Avantages | Inconvénients |
|------|-----------|---------------|
| **Sticky** | Simple, moins de traffic inter-node | Failover perd la session |
| **Distributed** | Failover transparent | Plus de traffic, complexité |

**Recommandation** : Distributed pour production, Sticky pour dev.

### 10.4 Configuration HA Kubernetes

```yaml
# values.yaml pour Keycloak HA
replicas: 3

extraEnv: |
  - name: KC_CACHE
    value: "ispn"
  - name: KC_CACHE_STACK
    value: "kubernetes"
  - name: JAVA_OPTS_APPEND
    value: "-Djgroups.dns.query=keycloak-headless.auth.svc.cluster.local"

service:
  headless:
    enabled: true  # Requis pour JGroups DNS discovery
```

---

## 11. Sécurité & Hardening

### 11.1 Checklist Sécurité

#### Realm Level

- [ ] Désactiver le realm `master` pour les apps
- [ ] Configurer password policies (longueur, complexité, historique)
- [ ] Activer brute force protection
- [ ] Configurer session timeouts
- [ ] Activer OTP/MFA pour les admins

#### Client Level

- [ ] Utiliser `confidential` pour les backends
- [ ] Restreindre `Valid Redirect URIs` (pas de wildcards larges)
- [ ] Activer PKCE pour les clients publics
- [ ] Configurer des scopes minimaux

#### Network Level

- [ ] TLS partout
- [ ] Network Policies dans K8s
- [ ] Rate limiting sur le load balancer

### 11.2 Password Policies

```
Realm → Authentication → Password Policy

Policies recommandées :
├── Length: 12 minimum
├── Digits: 1 minimum
├── Upper Case: 1 minimum
├── Special Characters: 1 minimum
├── Not Username
├── Password History: 5
└── Hash Algorithm: pbkdf2-sha512
```

### 11.3 Brute Force Protection

```
Realm → Security Defenses → Brute Force Detection

Configuration :
├── Enabled: ON
├── Max Login Failures: 5
├── Wait Increment: 60 seconds
├── Max Wait: 15 minutes
├── Quick Login Check: 1000 ms
└── Failure Reset Time: 12 hours
```

### 11.4 Session Policies

```
Realm → Sessions

Configuration :
├── SSO Session Idle: 30 minutes
├── SSO Session Max: 10 hours
├── Client Session Idle: 5 minutes
├── Client Session Max: 30 minutes
├── Access Token Lifespan: 5 minutes
├── Refresh Token Lifespan: 30 minutes
└── Offline Session Idle: 30 days
```

### 11.5 Token Security

| Paramètre | Recommandation |
|-----------|----------------|
| Access Token Lifespan | 5-15 minutes |
| Refresh Token | Rotation activée |
| ID Token | Audience restriction |
| Token Signature | RS256 minimum (ES256 préféré) |

---

## 12. Intégration Kubernetes

### 12.1 OIDC pour Kubernetes API

```
┌──────────┐     ┌──────────┐     ┌──────────┐
│  kubectl │     │   K8s    │     │ Keycloak │
│  + OIDC  │     │   API    │     │          │
└────┬─────┘     └────┬─────┘     └────┬─────┘
     │                │                │
     │ 1. kubectl with ID token        │
     │───────────────▶│                │
     │                │                │
     │                │ 2. Validate token via JWKS
     │                │───────────────▶│
     │                │                │
     │                │ 3. Public key  │
     │                │◀───────────────│
     │                │                │
     │                │ 4. Extract claims (groups, username)
     │                │                │
     │                │ 5. RBAC check  │
     │                │                │
     │ 6. Response    │                │
     │◀───────────────│                │
```

### 12.2 Mapping Keycloak → K8s RBAC

```yaml
# ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: keycloak-platform-admins
subjects:
- kind: Group
  name: "platform-admin"  # Keycloak realm role
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

### 12.3 Configuration K3d/K3s OIDC

```bash
# k3d cluster create avec OIDC
k3d cluster create my-cluster \
  --k3s-arg "--kube-apiserver-arg=oidc-issuer-url=https://auth.example.com/realms/my-realm@server:0" \
  --k3s-arg "--kube-apiserver-arg=oidc-client-id=kubernetes@server:0" \
  --k3s-arg "--kube-apiserver-arg=oidc-username-claim=preferred_username@server:0" \
  --k3s-arg "--kube-apiserver-arg=oidc-groups-claim=groups@server:0"
```

---

## 13. Troubleshooting

### 13.1 Logs & Events

**Events Keycloak** :
```
Realm → Events → Login Events
Realm → Events → Admin Events
```

**Types d'events** :

| Event | Signification |
|-------|---------------|
| `LOGIN` | Login réussi |
| `LOGIN_ERROR` | Login échoué |
| `LOGOUT` | Déconnexion |
| `CODE_TO_TOKEN` | Échange code → token |
| `CODE_TO_TOKEN_ERROR` | Erreur échange |
| `REFRESH_TOKEN` | Refresh token utilisé |
| `INTROSPECT_TOKEN` | Token introspection |

### 13.2 Erreurs courantes

#### `invalid_grant`

**Causes** :
- Code expiré (default: 60 secondes)
- Code déjà utilisé
- `redirect_uri` différente entre auth et token request

**Solution** : Vérifier les URIs et la latence réseau.

#### `invalid_client`

**Causes** :
- `client_id` incorrect
- `client_secret` incorrect
- Client non activé

**Solution** : Vérifier credentials dans Keycloak.

#### `invalid_redirect_uri`

**Causes** :
- URI non dans `Valid Redirect URIs`
- Protocol mismatch (http vs https)
- Trailing slash différent

**Solution** : Ajouter l'URI exacte dans la config client.

#### `CORS error`

**Causes** :
- `Web Origins` non configuré
- Headers manquants

**Solution** : Ajouter l'origin dans `Web Origins` du client.

### 13.3 Debug avec curl

```bash
# Test discovery endpoint
curl -s https://auth.ai-platform.localhost/realms/ai-platform/.well-known/openid-configuration | jq .

# Get token (client credentials)
curl -X POST https://auth.ai-platform.localhost/realms/ai-platform/protocol/openid-connect/token \
  -d "grant_type=client_credentials" \
  -d "client_id=my-client" \
  -d "client_secret=my-secret"

# Introspect token
curl -X POST https://auth.ai-platform.localhost/realms/ai-platform/protocol/openid-connect/token/introspect \
  -d "token=<access_token>" \
  -d "client_id=my-client" \
  -d "client_secret=my-secret"

# UserInfo
curl -H "Authorization: Bearer <access_token>" \
  https://auth.ai-platform.localhost/realms/ai-platform/protocol/openid-connect/userinfo
```

### 13.4 Décoder un JWT

```bash
# Avec jq
echo "<jwt_token>" | cut -d. -f2 | base64 -d | jq .

# Ou via jwt.io (attention données sensibles!)
```

---

## 14. Implémentation Lab

### 14.1 Récapitulatif de notre configuration

| Composant | Configuration |
|-----------|---------------|
| **Keycloak** | 1 replica, Codecentric chart |
| **Image** | `quay.io/keycloak/keycloak:latest` |
| **Database** | PostgreSQL (CNPG) |
| **Realm** | `ai-platform` |
| **URL** | `https://auth.ai-platform.localhost` |

### 14.2 Clients configurés

| Client | Type | Protocol | Redirect URI |
|--------|------|----------|--------------|
| `open-webui` | Confidential | OIDC | `https://chat.ai-platform.localhost/*` |
| `argocd` | Confidential | OIDC | `https://argocd.ai-platform.localhost/*` |

### 14.3 Realm Roles

| Role | Description | Mapping K8s |
|------|-------------|-------------|
| `platform-admin` | Admin complet | `cluster-admin` |
| `ai-engineer` | Outils ML | Custom ClusterRole |
| `security-auditor` | Audit/lecture | `view` + security |
| `viewer` | Lecture seule | `view` |

### 14.4 Users créés

| Username | Email | Roles | Status |
|----------|-------|-------|--------|
| `admin` | `admin@ai-platform.local` | `platform-admin` | ✅ Active |
| `zerotrust` | `zerotrust@ai-platform.local` | `ai-engineer` | ✅ Active |
| `testuser` | `testuser@example.com` | `viewer` | ✅ Active |

### 14.5 Configuration OIDC Open WebUI

```yaml
extraEnvVars:
  - name: ENABLE_OAUTH_SIGNUP
    value: "true"
  - name: OAUTH_MERGE_ACCOUNTS_BY_EMAIL
    value: "true"
  - name: DEFAULT_USER_ROLE
    value: "user"
  - name: OAUTH_PROVIDER_NAME
    value: "Keycloak"
  - name: OPENID_PROVIDER_URL
    value: "http://keycloak-keycloakx-http.auth.svc/realms/ai-platform/.well-known/openid-configuration"
  - name: OAUTH_CLIENT_ID
    value: "open-webui"
  - name: OAUTH_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: openwebui-oidc-secret
        key: client-secret
  - name: OAUTH_SCOPES
    value: "openid email profile"
  - name: OPENID_REDIRECT_URI
    value: "https://chat.ai-platform.localhost/oauth/oidc/callback"
```

### 14.6 CoreDNS Config

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-custom
  namespace: kube-system
data:
  ai-platform.server: |
    ai-platform.localhost:53 {
      hosts {
        10.43.233.142 auth.ai-platform.localhost
        fallthrough
      }
    }
```

---

## Glossaire

| Terme | Définition |
|-------|------------|
| **IdP** | Identity Provider - service d'authentification |
| **SP** | Service Provider - application cliente |
| **SSO** | Single Sign-On - une seule authentification |
| **MFA/2FA** | Multi-Factor Authentication |
| **JWT** | JSON Web Token |
| **PKCE** | Proof Key for Code Exchange |
| **JWKS** | JSON Web Key Set |
| **Claim** | Assertion dans un token |
| **Scope** | Permission demandée |
| **Grant** | Méthode d'obtention de token |
| **Assertion** | Document signé (SAML) |

---

## Ressources

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [OAuth 2.0 RFC 6749](https://tools.ietf.org/html/rfc6749)
- [OpenID Connect Spec](https://openid.net/specs/openid-connect-core-1_0.html)
- [SAML 2.0 Spec](http://docs.oasis-open.org/security/saml/v2.0/)
- [WebAuthn Spec](https://www.w3.org/TR/webauthn-2/)
- [FIDO Alliance](https://fidoalliance.org/)
- [JWT.io](https://jwt.io/)

---

*Document créé pour AI Security Platform - Janvier 2026*
