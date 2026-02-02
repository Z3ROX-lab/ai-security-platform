# ADR-014: Keycloak & IAM Protocols - Deep Dive

## Status
**Accepted** - Updated 2026-01-29

## Date
2025-01-21 (Updated 2026-01-29)

---

## Executive Summary

Cette ADR définit la stratégie IAM complète pour l'AI Security Platform, couvrant :
- Choix de Keycloak comme Identity Provider
- Architecture et configuration
- Protocoles supportés (OIDC, SAML, OAuth2, WebAuthn/FIDO2)
- Intégrations applicatives
- Modèle RBAC

---

## 1. Context

### 1.1 Besoins

L'AI Security Platform nécessite une solution IAM pour :

| Besoin | Criticité | Description |
|--------|-----------|-------------|
| **Authentification centralisée** | Critique | Un seul point d'authentification pour toutes les apps |
| **Single Sign-On (SSO)** | Haute | Une seule connexion pour accéder à tout |
| **RBAC** | Critique | Contrôle d'accès basé sur les rôles |
| **Audit trail** | Haute | Traçabilité des accès |
| **MFA support** | Moyenne | Authentification multi-facteurs |
| **Passwordless** | Basse | Support FIDO2/WebAuthn (futur) |
| **Federation** | Moyenne | Intégration IdP externes (futur) |

### 1.2 Contraintes

| Contrainte | Impact |
|------------|--------|
| **Home lab resources** | RAM limitée (~32GB total) |
| **Skills transférables** | Solution enterprise-standard |
| **Open source** | Pas de coût de licence |
| **Kubernetes native** | Déploiement Helm/GitOps |

---

## 2. Options Évaluées

### 2.1 Matrice de comparaison

| Critère | Keycloak | Authentik | Dex | Authelia | Okta/Auth0 |
|---------|----------|-----------|-----|----------|------------|
| **Open Source** | ✅ | ✅ | ✅ | ✅ | ❌ SaaS |
| **OIDC complet** | ✅ | ✅ | ✅ | ⚠️ Limité | ✅ |
| **SAML 2.0** | ✅ | ✅ | ❌ | ❌ | ✅ |
| **LDAP/AD** | ✅ Native | ✅ | ⚠️ Connecteurs | ❌ | ✅ |
| **WebAuthn/FIDO2** | ✅ | ✅ | ❌ | ✅ | ✅ |
| **Admin UI** | ✅ Excellente | ✅ Moderne | ❌ Aucune | ⚠️ Basique | ✅ |
| **Fine-grained RBAC** | ✅ | ✅ | ❌ Basique | ❌ | ✅ |
| **HA native** | ✅ Infinispan | ✅ | ✅ Stateless | ✅ | ✅ |
| **RAM footprint** | ~768MB | ~512MB | ~128MB | ~256MB | N/A |
| **Enterprise adoption** | ✅ Très haute | ⚠️ Croissante | ⚠️ Moyenne | ⚠️ Moyenne | ✅ |
| **Support Red Hat** | ✅ RHSSO | ❌ | ❌ | ❌ | ✅ Commercial |
| **Documentation** | ✅ Complète | ✅ Bonne | ⚠️ Basique | ✅ Bonne | ✅ |

### 2.2 Analyse détaillée

#### Keycloak
**Forces** :
- Feature-complete : OIDC, SAML, LDAP, MFA, WebAuthn
- Standard enterprise (base de Red Hat SSO)
- Admin UI puissante
- Communauté massive
- Skills directement transférables en entreprise

**Faiblesses** :
- Consommation RAM plus élevée
- Complexité pour configs avancées

#### Authentik
**Forces** :
- UI moderne et intuitive
- Python-based (facilite les customisations)
- Croissance rapide

**Faiblesses** :
- Moins mature que Keycloak
- Moins adopté en enterprise
- Documentation moins complète

#### Dex
**Forces** :
- Très léger
- Kubernetes-native
- Parfait pour OIDC simple

**Faiblesses** :
- Pas d'UI admin
- Fonctionnalités limitées
- Pas de SAML

---

## 3. Décision

### 3.1 Choix principal

**Keycloak** est sélectionné comme Identity Provider pour :

1. **Complétude fonctionnelle** : Tous les protocoles nécessaires (OIDC, SAML, WebAuthn)
2. **Standard enterprise** : Skills transférables, reconnu par les recruteurs
3. **Pérennité** : Backing Red Hat, communauté active
4. **Alignement carrière** : Head of Platform Engineering requiert souvent expertise Keycloak/RHSSO

### 3.2 Choix du Helm Chart

#### Charts évalués

| Chart | Maintainer | Status | Image |
|-------|------------|--------|-------|
| **Bitnami** | Broadcom | ⚠️ Payant depuis Août 2025 | `bitnami/keycloak` |
| **Codecentric keycloakx** | Codecentric | ✅ Actif, open source | `quay.io/keycloak/keycloak` |
| **Keycloak Operator** | Keycloak project | ✅ Officiel | `quay.io/keycloak/keycloak` |

#### Décision : Codecentric keycloakx

**Raisons** :
- ✅ Maintenance active
- ✅ Image officielle Keycloak (pas Bitnami)
- ✅ Support PostgreSQL externe
- ✅ HA éprouvé en production
- ✅ Quarkus-based (moderne, léger)
- ❌ Bitnami : licensing payant depuis 2025, images legacy non patchées
- ❌ Operator : overhead pour home lab

---

## 4. Architecture

### 4.1 Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         AI SECURITY PLATFORM                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   INGRESS (Traefik)                                                     │
│   └── auth.ai-platform.localhost → Keycloak                            │
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                        KEYCLOAK                                  │  │
│   │                                                                  │  │
│   │   Realm: ai-platform                                            │  │
│   │   ├── Users (zerotrust, testuser, ...)                         │  │
│   │   ├── Groups (platform-team, data-scientists, ...)             │  │
│   │   ├── Realm Roles (platform-admin, ai-engineer, ...)           │  │
│   │   └── Clients                                                   │  │
│   │       ├── open-webui (OIDC, confidential)                      │  │
│   │       ├── argocd (OIDC, confidential)                          │  │
│   │       └── grafana (OIDC, confidential)                         │  │
│   │                                                                  │  │
│   │   Protocols supportés:                                          │  │
│   │   ├── OpenID Connect (OIDC)                                    │  │
│   │   ├── OAuth 2.0                                                 │  │
│   │   ├── SAML 2.0                                                  │  │
│   │   └── WebAuthn / FIDO2                                         │  │
│   │                                                                  │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│                              │                                          │
│                              ▼                                          │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                     PostgreSQL (CNPG)                            │  │
│   │                   Database: keycloak                             │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Flux d'authentification

```
┌──────────┐     ┌──────────────┐     ┌──────────┐     ┌──────────┐
│  User    │     │  Application │     │ Keycloak │     │   API    │
│ Browser  │     │ (Open WebUI) │     │   IdP    │     │ (Ollama) │
└────┬─────┘     └──────┬───────┘     └────┬─────┘     └────┬─────┘
     │                  │                  │                │
     │ 1. Access app    │                  │                │
     │─────────────────▶│                  │                │
     │                  │                  │                │
     │ 2. Redirect      │                  │                │
     │◀─────────────────│                  │                │
     │                  │                  │                │
     │ 3. OIDC Auth Request               │                │
     │───────────────────────────────────▶│                │
     │                  │                  │                │
     │ 4. Login Form    │                  │                │
     │◀───────────────────────────────────│                │
     │                  │                  │                │
     │ 5. Credentials (+ MFA si activé)   │                │
     │───────────────────────────────────▶│                │
     │                  │                  │                │
     │ 6. Auth Code     │                  │                │
     │◀───────────────────────────────────│                │
     │─────────────────▶│                  │                │
     │                  │                  │                │
     │                  │ 7. Exchange code │                │
     │                  │─────────────────▶│                │
     │                  │                  │                │
     │                  │ 8. ID + Access Token              │
     │                  │◀─────────────────│                │
     │                  │                  │                │
     │                  │ 9. Validate token                 │
     │                  │    (JWKS)        │                │
     │                  │                  │                │
     │ 10. Session      │                  │                │
     │◀─────────────────│                  │                │
     │                  │                  │                │
     │ 11. Use app      │                  │                │
     │─────────────────▶│                  │                │
     │                  │                  │                │
     │                  │ 12. API call (Bearer token)       │
     │                  │─────────────────────────────────▶│
     │                  │                  │                │
     │                  │ 13. Response     │                │
     │                  │◀─────────────────────────────────│
     │                  │                  │                │
     │ 14. Data         │                  │                │
     │◀─────────────────│                  │                │
```

---

## 5. Protocoles IAM

### 5.1 Protocoles supportés

| Protocole | Version | Usage dans le lab | Status |
|-----------|---------|-------------------|--------|
| **OpenID Connect** | 1.0 | Primary pour toutes les apps | ✅ Actif |
| **OAuth 2.0** | 2.0 / 2.1 | Sous-jacent à OIDC | ✅ Actif |
| **SAML** | 2.0 | Disponible pour legacy | 🔲 Configuré |
| **WebAuthn/FIDO2** | Level 2 | Passwordless future | 🔲 Planifié |

### 5.2 OAuth 2.0 Grants configurés

| Grant Type | Usage | Activé |
|------------|-------|--------|
| **Authorization Code** | Web apps avec backend | ✅ |
| **Authorization Code + PKCE** | SPA, mobile apps | ✅ |
| **Client Credentials** | Machine-to-machine | ✅ |
| **Refresh Token** | Renouvellement tokens | ✅ |
| **Resource Owner Password** | Legacy (déprécié) | ❌ Désactivé |

### 5.3 Scopes OIDC configurés

| Scope | Claims inclus | Usage |
|-------|---------------|-------|
| `openid` | `sub` | Obligatoire OIDC |
| `profile` | `name`, `preferred_username`, etc. | Infos profil |
| `email` | `email`, `email_verified` | Email user |
| `roles` | `realm_access`, `resource_access` | Rôles pour RBAC |
| `groups` | `groups` | Groupes user |

### 5.4 Configuration OIDC type (client)

```yaml
Client Settings:
  Client ID: open-webui
  Client Protocol: openid-connect
  Access Type: confidential
  
  Valid Redirect URIs:
    - https://chat.ai-platform.localhost/*
  
  Web Origins:
    - https://chat.ai-platform.localhost
  
  Client Scopes:
    Default: openid, profile, email, roles
    Optional: groups

Token Settings:
  Access Token Lifespan: 5 minutes
  Refresh Token Lifespan: 30 minutes
  
Mappers (Default Client Scopes):
  - realm roles
  - client roles  
  - audience
  - groups (si nécessaire)
```

---

## 6. Modèle RBAC

### 6.1 Realm Roles

| Role | Description | Permissions | K8s RBAC Mapping |
|------|-------------|-------------|------------------|
| `platform-admin` | Administrateur plateforme | Full access all apps | `cluster-admin` |
| `ai-engineer` | Ingénieur ML/AI | Outils ML, inference | Custom ClusterRole |
| `security-auditor` | Auditeur sécurité | Lecture logs, dashboards | `view` + audit |
| `viewer` | Utilisateur lecture seule | Read-only everywhere | `view` |

### 6.2 Client Roles

#### Client: open-webui

| Role | Permissions |
|------|-------------|
| `admin` | Configuration, gestion users |
| `user` | Utilisation chat |

#### Client: argocd

| Role | Permissions |
|------|-------------|
| `admin` | Full ArgoCD admin |
| `readonly` | Voir applications |

#### Client: grafana (Phase 8)

| Role | Permissions |
|------|-------------|
| `Admin` | Configuration Grafana |
| `Editor` | Créer/modifier dashboards |
| `Viewer` | Voir dashboards |

### 6.3 Groups

| Group | Realm Roles assignés | Description |
|-------|---------------------|-------------|
| `platform-team` | `platform-admin` | Équipe plateforme |
| `data-scientists` | `ai-engineer` | Data scientists |
| `security-team` | `security-auditor` | Équipe sécurité |
| `stakeholders` | `viewer` | Parties prenantes |

### 6.4 Mapping Roles → Applications

```
User: alice
├── Member of: platform-team
│   └── Inherits: platform-admin (realm role)
│
└── Effective permissions:
    ├── Open WebUI: admin
    ├── ArgoCD: admin  
    ├── Grafana: Admin
    └── K8s: cluster-admin
```

---

## 7. Configuration Technique

### 7.1 Resource Allocation (Home Lab)

| Resource | Request | Limit | Rationale |
|----------|---------|-------|-----------|
| **Replicas** | 1 | 1 | Save RAM for LLMs |
| **Memory** | 512Mi | 768Mi | Minimum stable |
| **CPU** | 250m | 1000m | Allow burst |

**Note** : Scalable à 2+ replicas si besoin HA.

### 7.2 Database

| Paramètre | Valeur |
|-----------|--------|
| **Type** | PostgreSQL |
| **Provider** | CloudNativePG (CNPG) |
| **Database** | `keycloak` |
| **User** | `keycloak` |
| **Host** | `postgresql-cluster-rw.storage.svc` |
| **HA** | 3 replicas avec failover automatique |

### 7.3 Network

| Paramètre | Valeur |
|-----------|--------|
| **Ingress** | Traefik |
| **URL externe** | `https://auth.ai-platform.localhost` |
| **URL interne** | `http://keycloak-keycloakx-http.auth.svc` |
| **TLS** | cert-manager (self-signed CA) |
| **NetworkPolicy** | Restrictive (PostgreSQL, ingress only) |

### 7.4 Helm Values (Résumé)

```yaml
# argocd/applications/auth/keycloak/values.yaml
replicas: 1

image:
  repository: quay.io/keycloak/keycloak
  tag: "26.0"

command:
  - "/opt/keycloak/bin/kc.sh"
  - "start"
  - "--http-enabled=true"
  - "--hostname-strict=false"
  - "--proxy-headers=xforwarded"

extraEnv: |
  - name: KC_DB
    value: postgres
  - name: KC_DB_URL_HOST
    value: postgresql-cluster-rw.storage.svc
  - name: KC_DB_URL_DATABASE
    value: keycloak
  - name: KC_DB_USERNAME
    valueFrom:
      secretKeyRef:
        name: keycloak-db-secret
        key: username
  - name: KC_DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: keycloak-db-secret
        key: password

ingress:
  enabled: true
  ingressClassName: traefik
  rules:
    - host: auth.ai-platform.localhost
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - auth.ai-platform.localhost
      secretName: keycloak-tls

resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "768Mi"
    cpu: "1000m"
```

---

## 8. Intégrations Applicatives

### 8.1 Open WebUI (✅ Implémenté)

| Paramètre | Valeur |
|-----------|--------|
| **Protocol** | OIDC |
| **Client ID** | `open-webui` |
| **Client Type** | Confidential |
| **Auto signup** | Enabled |
| **Default role** | `user` |

**Configuration** :
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

### 8.2 ArgoCD (✅ Configuré)

| Paramètre | Valeur |
|-----------|--------|
| **Protocol** | OIDC |
| **Client ID** | `argocd` |
| **RBAC mapping** | Via groups claim |

### 8.3 Grafana (🔲 Phase 8)

| Paramètre | Valeur |
|-----------|--------|
| **Protocol** | OIDC |
| **Client ID** | `grafana` |
| **Role mapping** | `Admin`, `Editor`, `Viewer` |

---

## 9. Sécurité

### 9.1 Mesures implémentées

| Mesure | Status | Configuration |
|--------|--------|---------------|
| **TLS everywhere** | ✅ | cert-manager |
| **Password policy** | ✅ | 12 chars, complexity |
| **Brute force protection** | ✅ | 5 failures, 1min wait |
| **Session timeout** | ✅ | 30min idle, 10h max |
| **Secrets management** | ✅ | Sealed Secrets |
| **NetworkPolicy** | ✅ | Restrictive |
| **Pod Security Standards** | ✅ | Restricted |

### 9.2 Password Policy

```
Minimum Length: 12
Digits: 1 minimum
Upper Case: 1 minimum
Special Characters: 1 minimum
Not Username: Enabled
Password History: 5
```

### 9.3 Session Configuration

```
SSO Session Idle: 30 minutes
SSO Session Max: 10 hours
Access Token Lifespan: 5 minutes
Refresh Token Lifespan: 30 minutes
```

---

## 10. Opérations

### 10.1 Troubleshooting CoreDNS

**Problème** : Les pods ne résolvent pas `auth.ai-platform.localhost`

**Solution** : Patch CoreDNS (persisté via GitOps)

```yaml
# argocd/applications/infrastructure/coredns-config/manifests/coredns-custom.yaml
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

### 10.2 Commandes utiles

```bash
# Logs Keycloak
kubectl logs -n auth keycloak-keycloakx-0 -f

# Events de login
# Keycloak Admin → Realm → Events → Login Events

# Test OIDC discovery
curl -k https://auth.ai-platform.localhost/realms/ai-platform/.well-known/openid-configuration | jq .

# Vérifier token
curl -X POST https://auth.ai-platform.localhost/realms/ai-platform/protocol/openid-connect/token/introspect \
  -d "token=<access_token>" \
  -d "client_id=open-webui" \
  -d "client_secret=<secret>"
```

### 10.3 Backup & Recovery

| Élément | Backup method |
|---------|---------------|
| **Database** | PostgreSQL CNPG backup (WAL + snapshots) |
| **Realm config** | Export JSON via Admin UI ou API |
| **Secrets** | Sealed Secrets dans Git |

---

## 11. Roadmap

### Phase actuelle (✅ Complété)

- [x] Keycloak déployé (Codecentric chart)
- [x] Realm `ai-platform` configuré
- [x] Intégration Open WebUI (OIDC)
- [x] Auto-activation users SSO
- [x] CoreDNS persisté

### Prochaines phases

| Phase | Tâche | Priorité |
|-------|-------|----------|
| **Phase 6** | Intégration Qdrant (si auth nécessaire) | Moyenne |
| **Phase 7** | NeMo Guardrails auth | Moyenne |
| **Phase 8** | Grafana OIDC | Haute |
| **Phase 8** | Prometheus auth | Moyenne |
| **Future** | WebAuthn/FIDO2 passwordless | Basse |
| **Future** | LDAP federation (si lab AD) | Basse |

---

## 12. Conséquences

### Positives

- ✅ SSO unifié pour toute la plateforme
- ✅ RBAC centralisé et cohérent
- ✅ Audit trail complet
- ✅ Skills enterprise transférables
- ✅ Flexibilité protocoles (OIDC, SAML, WebAuthn)
- ✅ Zero vendor lock-in

### Négatives

- ⚠️ Composant supplémentaire (~768MB RAM)
- ⚠️ Complexité pour configurations avancées
- ⚠️ Courbe d'apprentissage initiale

### Risques mitigés

| Risque | Mitigation |
|--------|------------|
| Bitnami licensing | → Codecentric + image officielle |
| Legacy images | → `quay.io/keycloak/keycloak` |
| RAM contraints | → Single replica, limits optimisés |
| DNS resolution K8s | → CoreDNS config persistée |

---

## 13. Références

### Documentation officielle
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Keycloak Admin Guide](https://www.keycloak.org/docs/latest/server_admin/)
- [Codecentric Helm Charts](https://github.com/codecentric/helm-charts)

### Spécifications
- [OAuth 2.0 (RFC 6749)](https://tools.ietf.org/html/rfc6749)
- [OAuth 2.1 (Draft)](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1)
- [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html)
- [SAML 2.0](http://docs.oasis-open.org/security/saml/v2.0/)
- [WebAuthn Level 2](https://www.w3.org/TR/webauthn-2/)
- [FIDO2 Specifications](https://fidoalliance.org/specifications/)

### Outils
- [JWT.io](https://jwt.io/) - Decode/verify JWT
- [OIDC Debugger](https://oidcdebugger.com/) - Test OIDC flows

---

## Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2025-01-21 | 1.0 | Initial decision |
| 2026-01-23 | 1.1 | Helm chart decision (Codecentric) |
| 2026-01-29 | 2.0 | Full protocol documentation, Open WebUI integration, CoreDNS fix |

---

*ADR maintenue par l'équipe AI Security Platform*
