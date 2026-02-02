# Traefik Ingress Routing Guide

> **Objectif** : Comprendre comment le routing HTTP fonctionne dans l'AI Security Platform avec Traefik et les Ingress Kubernetes.

---

## Table des Matières

1. [Vue d'ensemble](#1-vue-densemble)
2. [Concepts Clés](#2-concepts-clés)
3. [Flow GitOps Complet](#3-flow-gitops-complet)
4. [Configuration des Virtual Hosts](#4-configuration-des-virtual-hosts)
5. [TLS et Certificats](#5-tls-et-certificats)
6. [Middlewares Traefik](#6-middlewares-traefik)
7. [Debugging et Troubleshooting](#7-debugging-et-troubleshooting)
8. [Notre Configuration Lab](#8-notre-configuration-lab)

---

## 1. Vue d'ensemble

### 1.1 Le problème à résoudre

Dans Kubernetes, les applications tournent dans des Pods avec des IPs internes non accessibles depuis l'extérieur. Comment exposer plusieurs applications sur un seul point d'entrée ?

```
SANS Ingress Controller:
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ ???
       ▼
┌─────────────────────────────────────┐
│          KUBERNETES CLUSTER          │
│                                      │
│  Pod A (10.42.0.15)  ← Comment      │
│  Pod B (10.42.0.23)    y accéder ?  │
│  Pod C (10.42.0.47)                 │
│                                      │
└─────────────────────────────────────┘
```

```
AVEC Ingress Controller (Traefik):
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ https://app.example.com
       ▼
┌─────────────────────────────────────────────────────────┐
│                   KUBERNETES CLUSTER                     │
│                                                          │
│   ┌─────────────────────────────────────────────────┐   │
│   │               TRAEFIK (Ingress)                  │   │
│   │                                                  │   │
│   │   app.example.com  ──────► Service A ──► Pod A  │   │
│   │   api.example.com  ──────► Service B ──► Pod B  │   │
│   │   admin.example.com ─────► Service C ──► Pod C  │   │
│   │                                                  │   │
│   └─────────────────────────────────────────────────┘   │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### 1.2 Composants impliqués

| Composant | Rôle |
|-----------|------|
| **Traefik** | Ingress Controller - reçoit le trafic et route |
| **Ingress Resource** | Configuration déclarative des routes |
| **Service** | Abstraction réseau vers les Pods |
| **Pod** | Container applicatif |
| **cert-manager** | Génère les certificats TLS |

---

## 2. Concepts Clés

### 2.1 Ingress Resource

**Définition** : Objet Kubernetes qui décrit comment router le trafic HTTP/HTTPS vers les Services.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  namespace: my-namespace
spec:
  ingressClassName: traefik        # Quel Ingress Controller utiliser
  rules:
    - host: app.example.com        # Virtual host
      http:
        paths:
          - path: /                # Path matching
            pathType: Prefix
            backend:
              service:
                name: my-service   # Service cible
                port:
                  number: 80
```

### 2.2 Ingress Controller

**Définition** : Composant qui lit les Ingress resources et configure le reverse proxy.

```
┌─────────────────────────────────────────────────────────────┐
│                    INGRESS CONTROLLER                        │
│                        (Traefik)                             │
│                                                              │
│   1. WATCH: Surveille l'API K8s pour les Ingress           │
│                         │                                    │
│                         ▼                                    │
│   2. PARSE: Lit les règles (host, path, service)           │
│                         │                                    │
│                         ▼                                    │
│   3. CONFIGURE: Met à jour sa config interne               │
│                         │                                    │
│                         ▼                                    │
│   4. ROUTE: Dirige le trafic selon les règles              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 2.3 Virtual Host

**Définition** : Technique permettant d'héberger plusieurs sites sur une seule IP, différenciés par le nom de domaine.

```
Requête HTTP:
GET / HTTP/1.1
Host: auth.ai-platform.localhost  ← Traefik lit ce header
```

Traefik matche le header `Host` avec la règle `host:` de l'Ingress.

### 2.4 Path Matching

| PathType | Comportement |
|----------|--------------|
| `Prefix` | `/api` matche `/api`, `/api/`, `/api/users` |
| `Exact` | `/api` matche UNIQUEMENT `/api` |
| `ImplementationSpecific` | Dépend de l'Ingress Controller |

---

## 3. Flow GitOps Complet

### 3.1 De Git jusqu'au trafic

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           GITOPS FLOW                                    │
└─────────────────────────────────────────────────────────────────────────┘

ÉTAPE 1: Développeur définit la config
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  argocd/applications/auth/keycloak/values.yaml
  ┌─────────────────────────────────────────┐
  │ ingress:                                │
  │   enabled: true                         │
  │   host: auth.ai-platform.localhost  ◄───┼── TU DÉFINIS LE NOM ICI
  │   tls: true                             │
  └─────────────────────────────────────────┘
                    │
                    ▼ git commit && git push
                    
ÉTAPE 2: Git Repository (Source of Truth)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  GitHub/GitLab
  ┌─────────────────────────────────────────┐
  │ main branch                             │
  │ └── argocd/applications/auth/keycloak/  │
  └─────────────────────────────────────────┘
                    │
                    ▼ ArgoCD sync (poll ou webhook)
                    
ÉTAPE 3: ArgoCD rend le Helm Chart
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ArgoCD
  ┌─────────────────────────────────────────┐
  │ 1. Clone le repo                        │
  │ 2. helm template keycloak -f values.yaml│
  │ 3. Génère les manifests K8s             │
  │    - Deployment                         │
  │    - Service                            │
  │    - Ingress  ◄───────────────────────────── INGRESS GÉNÉRÉ
  │    - etc.                               │
  └─────────────────────────────────────────┘
                    │
                    ▼ kubectl apply
                    
ÉTAPE 4: Kubernetes crée les ressources
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Kubernetes API
  ┌─────────────────────────────────────────┐
  │ kubectl get ingress -n auth             │
  │                                         │
  │ NAME       HOST                         │
  │ keycloak   auth.ai-platform.localhost   │
  └─────────────────────────────────────────┘
                    │
                    ▼ Traefik WATCH
                    
ÉTAPE 5: Traefik détecte et configure
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Traefik
  ┌─────────────────────────────────────────┐
  │ Nouvelle route détectée !               │
  │                                         │
  │ Router: keycloak-auth@kubernetes        │
  │ Rule: Host(`auth.ai-platform.localhost`)│
  │ Service: keycloak-keycloakx-http        │
  │ TLS: keycloak-tls                       │
  └─────────────────────────────────────────┘
                    │
                    ▼ HOT RELOAD (pas de restart)
                    
ÉTAPE 6: Trafic routé
━━━━━━━━━━━━━━━━━━━━━

  Browser
  ┌─────────────────────────────────────────┐
  │ https://auth.ai-platform.localhost      │
  │            │                            │
  │            ▼                            │
  │ /etc/hosts: 127.0.0.1 auth.ai-plat...  │
  │            │                            │
  │            ▼                            │
  │ K3d LoadBalancer (:443)                 │
  │            │                            │
  │            ▼                            │
  │ Traefik (match Host header)             │
  │            │                            │
  │            ▼                            │
  │ Service keycloak → Pod Keycloak         │
  └─────────────────────────────────────────┘
```

### 3.2 Qui fait quoi ?

| Acteur | Responsabilité |
|--------|----------------|
| **Développeur** | Définit le hostname dans values.yaml |
| **Git** | Stocke la configuration (source of truth) |
| **ArgoCD** | Rend Helm → manifests, applique dans K8s |
| **Kubernetes** | Stocke l'Ingress resource |
| **Traefik** | Lit l'Ingress, configure les routes |
| **cert-manager** | Génère le certificat TLS |
| **/etc/hosts** | Résolution DNS locale |

---

## 4. Configuration des Virtual Hosts

### 4.1 Définir un nouveau virtual host

**Méthode 1 : Via Helm values (recommandé)**

```yaml
# values.yaml de l'application
ingress:
  enabled: true
  class: traefik
  annotations:
    cert-manager.io/cluster-issuer: ai-platform-ca-issuer
  host: myapp.ai-platform.localhost    # ← Ton hostname
  tls: true
```

**Méthode 2 : Ingress manifest direct**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  namespace: myapp-namespace
  annotations:
    cert-manager.io/cluster-issuer: ai-platform-ca-issuer
spec:
  ingressClassName: traefik
  rules:
    - host: myapp.ai-platform.localhost
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: myapp-service
                port:
                  number: 8080
  tls:
    - hosts:
        - myapp.ai-platform.localhost
      secretName: myapp-tls
```

### 4.2 Ajouter la résolution DNS locale

```bash
# Sur ton laptop, ajoute dans /etc/hosts
sudo nano /etc/hosts

# Ajouter la ligne
127.0.0.1  myapp.ai-platform.localhost
```

### 4.3 Multiple paths sur un même host

```yaml
spec:
  rules:
    - host: api.ai-platform.localhost
      http:
        paths:
          - path: /auth
            pathType: Prefix
            backend:
              service:
                name: auth-service
                port:
                  number: 80
          - path: /users
            pathType: Prefix
            backend:
              service:
                name: users-service
                port:
                  number: 80
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-service
                port:
                  number: 80
```

**Ordre important** : Les paths plus spécifiques doivent être listés en premier !

---

## 5. TLS et Certificats

### 5.1 Flow TLS avec cert-manager

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        TLS CERTIFICATE FLOW                              │
└─────────────────────────────────────────────────────────────────────────┘

1. Ingress créé avec annotation cert-manager
   ┌─────────────────────────────────────────┐
   │ annotations:                            │
   │   cert-manager.io/cluster-issuer: ...   │
   │ tls:                                    │
   │   - secretName: myapp-tls               │
   └─────────────────────────────────────────┘
                    │
                    ▼ cert-manager WATCH
                    
2. cert-manager détecte et crée Certificate
   ┌─────────────────────────────────────────┐
   │ kind: Certificate                       │
   │ spec:                                   │
   │   secretName: myapp-tls                 │
   │   issuerRef: ai-platform-ca-issuer      │
   │   dnsNames:                             │
   │     - myapp.ai-platform.localhost       │
   └─────────────────────────────────────────┘
                    │
                    ▼
                    
3. cert-manager génère le certificat
   ┌─────────────────────────────────────────┐
   │ kind: Secret                            │
   │ name: myapp-tls                         │
   │ data:                                   │
   │   tls.crt: <certificate>                │
   │   tls.key: <private key>                │
   └─────────────────────────────────────────┘
                    │
                    ▼ Traefik lit le Secret
                    
4. Traefik utilise le certificat
   ┌─────────────────────────────────────────┐
   │ TLS termination pour                    │
   │ myapp.ai-platform.localhost             │
   └─────────────────────────────────────────┘
```

### 5.2 Vérifier les certificats

```bash
# Lister les certificats
kubectl get certificates -A

# Détail d'un certificat
kubectl describe certificate -n auth keycloak-tls

# Vérifier le secret TLS
kubectl get secret -n auth keycloak-tls -o yaml
```

### 5.3 Troubleshooting TLS

| Problème | Cause | Solution |
|----------|-------|----------|
| Certificate not ready | ClusterIssuer manquant | Créer le ClusterIssuer |
| Secret not found | cert-manager n'a pas créé | Vérifier logs cert-manager |
| Browser warning | Self-signed CA | Ajouter CA au trust store |

---

## 6. Middlewares Traefik

### 6.1 Qu'est-ce qu'un Middleware ?

Traitement intermédiaire appliqué aux requêtes AVANT d'atteindre le backend.

```
Client → Traefik → [Middleware 1] → [Middleware 2] → Backend
                   (rate limit)     (add headers)
```

### 6.2 Middlewares utiles

#### Security Headers

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: security-headers
  namespace: default
spec:
  headers:
    frameDeny: true                    # X-Frame-Options: DENY
    contentTypeNosniff: true           # X-Content-Type-Options: nosniff
    browserXssFilter: true             # X-XSS-Protection: 1; mode=block
    referrerPolicy: "strict-origin-when-cross-origin"
    customResponseHeaders:
      X-Powered-By: ""                 # Remove server info
```

#### Rate Limiting

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: rate-limit
spec:
  rateLimit:
    average: 100                       # 100 req/s average
    burst: 200                         # Allow burst up to 200
```

#### Basic Auth

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: basic-auth
spec:
  basicAuth:
    secret: auth-secret                # Secret with htpasswd
```

#### Strip Prefix

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: strip-api
spec:
  stripPrefix:
    prefixes:
      - /api                           # /api/users → /users
```

### 6.3 Appliquer un Middleware

**Via IngressRoute (CRD Traefik)** :

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: myapp
spec:
  routes:
    - match: Host(`myapp.ai-platform.localhost`)
      kind: Rule
      middlewares:                      # ← Appliquer ici
        - name: security-headers
        - name: rate-limit
      services:
        - name: myapp-service
          port: 80
```

**Via annotations Ingress** :

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: default-security-headers@kubernetescrd
```

---

## 7. Debugging et Troubleshooting

### 7.1 Commandes essentielles

```bash
# Voir tous les Ingress
kubectl get ingress -A

# Détail d'un Ingress
kubectl describe ingress -n auth keycloak-keycloakx

# Voir les Services
kubectl get svc -A

# Logs Traefik
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik -f

# Vérifier les endpoints (pods derrière un service)
kubectl get endpoints -n auth keycloak-keycloakx-http
```

### 7.2 Dashboard Traefik

```bash
# Port-forward vers le dashboard
kubectl port-forward -n kube-system svc/traefik 9000:9000

# Ouvrir http://localhost:9000/dashboard/
```

Le dashboard montre :
- Routers actifs
- Services backend
- Middlewares
- Métriques

### 7.3 Problèmes courants

#### 404 Not Found

```bash
# 1. Vérifier que l'Ingress existe
kubectl get ingress -A | grep myapp

# 2. Vérifier le hostname dans /etc/hosts
cat /etc/hosts | grep myapp

# 3. Vérifier que le Host header est correct
curl -v https://myapp.ai-platform.localhost 2>&1 | grep "Host:"
```

#### 503 Service Unavailable

```bash
# 1. Vérifier que le Service existe
kubectl get svc -n myapp-namespace

# 2. Vérifier que les Pods tournent
kubectl get pods -n myapp-namespace

# 3. Vérifier les endpoints
kubectl get endpoints -n myapp-namespace myapp-service

# Si endpoints vide → les pods ne sont pas ready ou le selector est mauvais
```

#### 502 Bad Gateway

```bash
# 1. Vérifier les logs du Pod backend
kubectl logs -n myapp-namespace -l app=myapp

# 2. Vérifier que le port est correct
kubectl get svc myapp-service -o yaml | grep -A5 ports
```

#### Certificat invalide

```bash
# 1. Vérifier le Certificate
kubectl get certificate -n myapp-namespace

# 2. Vérifier que le Secret existe
kubectl get secret -n myapp-namespace myapp-tls

# 3. Vérifier les logs cert-manager
kubectl logs -n cert-manager -l app=cert-manager
```

### 7.4 Test avec curl

```bash
# Test basique
curl -k https://auth.ai-platform.localhost

# Avec verbose (voir TLS, headers)
curl -kv https://auth.ai-platform.localhost

# Forcer un Host header spécifique
curl -k -H "Host: auth.ai-platform.localhost" https://127.0.0.1

# Voir les headers de réponse
curl -kI https://auth.ai-platform.localhost
```

---

## 8. Notre Configuration Lab

### 8.1 Virtual Hosts actifs

| Hostname | Namespace | Application | Service |
|----------|-----------|-------------|---------|
| `auth.ai-platform.localhost` | auth | Keycloak | keycloak-keycloakx-http:80 |
| `chat.ai-platform.localhost` | ai-apps | Open WebUI | open-webui:8080 |
| `argocd.ai-platform.localhost` | argocd | ArgoCD | argocd-server:443 |

### 8.2 /etc/hosts

```bash
# /etc/hosts sur le laptop
127.0.0.1  auth.ai-platform.localhost
127.0.0.1  chat.ai-platform.localhost
127.0.0.1  argocd.ai-platform.localhost
```

### 8.3 Voir la config

```bash
# Tous les Ingress
kubectl get ingress -A -o wide

# Exemple de sortie
NAMESPACE   NAME                  CLASS     HOSTS                           ADDRESS      PORTS     AGE
argocd      argocd-server         traefik   argocd.ai-platform.localhost    172.20.0.6   80, 443   3d
auth        keycloak-keycloakx    traefik   auth.ai-platform.localhost      172.20.0.6   80, 443   3d
ai-apps     open-webui            traefik   chat.ai-platform.localhost      172.20.0.6   80, 443   2d
```

### 8.4 Ajouter un nouveau service

**Checklist** :

1. [ ] Créer le Deployment et Service
2. [ ] Ajouter `ingress` dans values.yaml avec le hostname
3. [ ] Commit et push vers Git
4. [ ] ArgoCD sync automatique
5. [ ] Ajouter le hostname dans `/etc/hosts`
6. [ ] Tester avec `curl -k https://newapp.ai-platform.localhost`

---

## Ressources

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [K3s Networking](https://docs.k3s.io/networking)

---

*Guide maintenu par l'équipe AI Security Platform - Janvier 2026*
