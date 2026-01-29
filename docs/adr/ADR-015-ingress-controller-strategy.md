# ADR-015: Ingress Controller Strategy

## Status
**Accepted** - 2026-01-29

## Date
2026-01-29

---

## Executive Summary

Cette ADR documente le choix de **Traefik** comme Ingress Controller pour l'AI Security Platform, comparé aux alternatives HAProxy, Nginx, et autres.

---

## 1. Context

### 1.1 Besoin

L'AI Security Platform nécessite un Ingress Controller pour :

| Besoin | Description |
|--------|-------------|
| **Routing HTTP/HTTPS** | Router le trafic vers les services internes |
| **TLS Termination** | Gérer les certificats SSL/TLS |
| **Virtual Hosts** | Plusieurs apps sur un seul point d'entrée |
| **Load Balancing** | Distribuer le trafic |
| **Intégration K8s** | Natif Kubernetes Ingress API |

### 1.2 Contraintes

| Contrainte | Impact |
|------------|--------|
| **Home lab** | Ressources limitées |
| **K3d/K3s** | Compatibilité requise |
| **GitOps** | Configuration déclarative |
| **TLS automatique** | Intégration cert-manager |
| **Simplicité** | Maintenance minimale |

---

## 2. Options Évaluées

### 2.1 Candidats

| Solution | Type | Maintainer |
|----------|------|------------|
| **Traefik** | Cloud-native proxy | Traefik Labs |
| **Nginx Ingress** | Web server based | Kubernetes community / F5 |
| **HAProxy Ingress** | Load balancer based | HAProxy Technologies |
| **Contour** | Envoy-based | VMware |
| **Kong** | API Gateway | Kong Inc |
| **Istio Gateway** | Service Mesh | Google/IBM |

### 2.2 Matrice de Comparaison

| Critère | Traefik | Nginx | HAProxy | Contour | Kong |
|---------|---------|-------|---------|---------|------|
| **K8s Native** | ✅ Excellent | ✅ Bon | ✅ Bon | ✅ Excellent | ⚠️ Moyen |
| **Auto-discovery** | ✅ Natif | ❌ Reload | ❌ Reload | ✅ Natif | ⚠️ Partiel |
| **Config dynamique** | ✅ Hot reload | ⚠️ Reload requis | ⚠️ Reload requis | ✅ Hot reload | ✅ Hot reload |
| **Dashboard** | ✅ Intégré | ❌ Non | ❌ Non | ❌ Non | ✅ Payant |
| **Let's Encrypt** | ✅ Natif | ⚠️ Via cert-manager | ⚠️ Via cert-manager | ⚠️ Via cert-manager | ⚠️ Via cert-manager |
| **Middlewares** | ✅ Riche | ⚠️ Annotations | ⚠️ Limité | ✅ HTTPProxy CRD | ✅ Plugins |
| **RAM footprint** | ~50MB | ~100MB | ~30MB | ~100MB | ~200MB |
| **K3s default** | ✅ Oui | ❌ Non | ❌ Non | ❌ Non | ❌ Non |
| **Learning curve** | Facile | Moyen | Moyen | Moyen | Complexe |
| **Enterprise support** | ✅ Traefik EE | ✅ F5 | ✅ HAProxy EE | ✅ VMware | ✅ Kong EE |

### 2.3 Analyse Détaillée

#### Traefik

**Forces** :
- ✅ **Cloud-native** : Conçu pour K8s/Docker dès le départ
- ✅ **Auto-discovery** : Détecte automatiquement les nouveaux services
- ✅ **Hot reload** : Pas de downtime lors des changements
- ✅ **Dashboard intégré** : Visualisation des routes en temps réel
- ✅ **Let's Encrypt natif** : ACME intégré (alternative à cert-manager)
- ✅ **Middlewares** : Auth, rate-limit, headers, etc. déclaratifs
- ✅ **K3s default** : Pré-installé, zéro config
- ✅ **IngressRoute CRD** : Plus puissant que Ingress standard

**Faiblesses** :
- ⚠️ Moins de features avancées L4 que HAProxy
- ⚠️ Documentation parfois dispersée

#### Nginx Ingress Controller

**Forces** :
- ✅ **Nginx battle-tested** : Serveur web le plus utilisé
- ✅ **Performance** : Excellent pour le contenu statique
- ✅ **Communauté massive** : Beaucoup de ressources
- ✅ **Annotations riches** : Configuration fine

**Faiblesses** :
- ❌ **Reload requis** : Génère nginx.conf et reload
- ❌ **Pas de dashboard** : Monitoring externe requis
- ❌ **Deux versions** : kubernetes/ingress-nginx vs nginxinc/kubernetes-ingress (confusion)

#### HAProxy Ingress

**Forces** :
- ✅ **Performance L4/L7** : Excellent load balancer
- ✅ **Battle-tested** : Utilisé par GitHub, Stack Overflow, etc.
- ✅ **Features avancées** : Rate limiting, circuit breaker
- ✅ **Léger** : ~30MB RAM

**Faiblesses** :
- ❌ **Config reload** : Pas de hot reload natif K8s
- ❌ **Moins K8s-native** : Adaptation d'un LB traditionnel
- ❌ **Complexité** : Config HAProxy classique requise pour features avancées

#### Contour (Envoy-based)

**Forces** :
- ✅ **Envoy proxy** : Moderne, performant
- ✅ **HTTPProxy CRD** : Plus puissant qu'Ingress
- ✅ **Hot reload** : Via xDS API d'Envoy

**Faiblesses** :
- ⚠️ **Overhead** : Deux composants (Contour + Envoy)
- ⚠️ **Learning curve** : HTTPProxy CRD spécifique

---

## 3. Décision

### 3.1 Choix : Traefik

**Traefik** est sélectionné comme Ingress Controller pour :

1. **K3s Default** : Pré-installé dans K3s/K3d, zéro effort de déploiement
2. **Cloud-Native** : Conçu pour Kubernetes, auto-discovery natif
3. **Hot Reload** : Changements sans downtime
4. **Dashboard** : Visibilité immédiate sur les routes
5. **Simplicité** : Configuration déclarative, GitOps-friendly
6. **Middlewares** : Auth, headers, rate-limit sans composants externes

### 3.2 Pourquoi pas les autres ?

| Alternative | Raison du rejet |
|-------------|-----------------|
| **Nginx** | Reload requis, pas de dashboard, deux versions confuses |
| **HAProxy** | Moins K8s-native, complexité config pour notre use case |
| **Contour** | Overhead (2 composants), pas de valeur ajoutée pour home lab |
| **Kong** | Trop complexe, orienté API Gateway enterprise |

---

## 4. Architecture

### 4.1 Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                    │
│                           (ou localhost)                                 │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 ▼ :443 / :80
┌─────────────────────────────────────────────────────────────────────────┐
│                         K3D LOAD BALANCER                                │
│                    (ports mappés vers host)                              │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                             TRAEFIK                                      │
│                     (Ingress Controller)                                 │
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                      ENTRYPOINTS                                 │   │
│   │   web (:80) ──────► Redirect HTTPS                              │   │
│   │   websecure (:443) ──────► TLS Termination                      │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                 │                                        │
│                                 ▼                                        │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                        ROUTERS                                   │   │
│   │   (générés depuis Ingress resources)                            │   │
│   │                                                                  │   │
│   │   Host(`auth.ai-platform.localhost`)    ──► keycloak-svc        │   │
│   │   Host(`chat.ai-platform.localhost`)    ──► open-webui-svc      │   │
│   │   Host(`argocd.ai-platform.localhost`)  ──► argocd-server       │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                 │                                        │
│                                 ▼                                        │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                      MIDDLEWARES                                 │   │
│   │   (optionnel, via annotations ou IngressRoute)                  │   │
│   │                                                                  │   │
│   │   - Headers (security headers)                                  │   │
│   │   - RateLimit                                                   │   │
│   │   - BasicAuth / ForwardAuth                                     │   │
│   │   - StripPrefix                                                 │   │
│   │   - Compress                                                    │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          SERVICES (Backend)                              │
│                                                                          │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                 │
│   │   Keycloak   │  │  Open WebUI  │  │    ArgoCD    │                 │
│   │  (ns: auth)  │  │(ns: ai-apps) │  │ (ns: argocd) │                 │
│   └──────────────┘  └──────────────┘  └──────────────┘                 │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Flow de routing

```
1. Requête arrive: https://auth.ai-platform.localhost/admin

2. Traefik reçoit sur entrypoint websecure (:443)

3. TLS termination (certificat depuis Secret keycloak-tls)

4. Router matching:
   - Check Host header: "auth.ai-platform.localhost" ✓
   - Check Path: "/" (Prefix) ✓
   - Route trouvée !

5. Middlewares appliqués (si configurés)

6. Forward vers Service: keycloak-keycloakx-http:80

7. Service load-balance vers Pod(s) Keycloak

8. Réponse retourne par le même chemin
```

### 4.3 Comment Traefik découvre les routes

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         KUBERNETES API                                   │
│                                                                          │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐        │
│   │    Ingress     │  │  IngressRoute   │  │    Service      │        │
│   │   (standard)    │  │  (Traefik CRD)  │  │                 │        │
│   └────────┬────────┘  └────────┬────────┘  └────────┬────────┘        │
│            │                    │                    │                  │
│            └────────────────────┼────────────────────┘                  │
│                                 │                                        │
│                                 ▼ WATCH                                  │
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                         TRAEFIK                                  │   │
│   │                                                                  │   │
│   │   Provider: KubernetesCRD + KubernetesIngress                   │   │
│   │                                                                  │   │
│   │   1. Watch API pour Ingress/IngressRoute                        │   │
│   │   2. Détecte création/modification/suppression                  │   │
│   │   3. Met à jour config interne (hot reload)                     │   │
│   │   4. Route le trafic selon nouvelle config                      │   │
│   │                                                                  │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Configuration

### 5.1 Traefik dans K3s (pré-installé)

K3s installe Traefik automatiquement. Configuration via HelmChartConfig :

```yaml
# /var/lib/rancher/k3s/server/manifests/traefik-config.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    dashboard:
      enabled: true
    logs:
      general:
        level: INFO
    ports:
      websecure:
        tls:
          enabled: true
```

### 5.2 Ingress Resource (Standard K8s)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak
  namespace: auth
  annotations:
    cert-manager.io/cluster-issuer: ai-platform-ca-issuer
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: traefik
  rules:
    - host: auth.ai-platform.localhost    # ← Virtual host
      http:
        paths:
          - path: /                        # ← Path matching
            pathType: Prefix
            backend:
              service:
                name: keycloak-keycloakx-http  # ← Target service
                port:
                  number: 80
  tls:
    - hosts:
        - auth.ai-platform.localhost
      secretName: keycloak-tls             # ← Cert from cert-manager
```

### 5.3 IngressRoute (Traefik CRD - Plus puissant)

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: keycloak
  namespace: auth
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`auth.ai-platform.localhost`)
      kind: Rule
      services:
        - name: keycloak-keycloakx-http
          port: 80
      middlewares:
        - name: security-headers
  tls:
    secretName: keycloak-tls
```

### 5.4 Middleware Example

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: security-headers
  namespace: auth
spec:
  headers:
    frameDeny: true
    contentTypeNosniff: true
    browserXssFilter: true
    referrerPolicy: "strict-origin-when-cross-origin"
    customResponseHeaders:
      X-Powered-By: ""
```

---

## 6. Notre Configuration Lab

### 6.1 Virtual Hosts configurés

| Host | Namespace | Service | Port |
|------|-----------|---------|------|
| `auth.ai-platform.localhost` | auth | keycloak-keycloakx-http | 80 |
| `chat.ai-platform.localhost` | ai-apps | open-webui | 8080 |
| `argocd.ai-platform.localhost` | argocd | argocd-server | 443 |

### 6.2 Résolution DNS locale

```bash
# /etc/hosts (laptop)
127.0.0.1  auth.ai-platform.localhost
127.0.0.1  chat.ai-platform.localhost
127.0.0.1  argocd.ai-platform.localhost
```

### 6.3 TLS

| Composant | Configuration |
|-----------|---------------|
| **cert-manager** | ClusterIssuer `ai-platform-ca-issuer` |
| **Certificats** | Auto-générés via annotations Ingress |
| **Storage** | Secrets K8s (`keycloak-tls`, etc.) |

---

## 7. Opérations

### 7.1 Commandes utiles

```bash
# Voir les Ingress
kubectl get ingress -A

# Détail d'un Ingress
kubectl describe ingress -n auth keycloak-keycloakx

# Logs Traefik
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik -f

# Dashboard Traefik (si activé)
kubectl port-forward -n kube-system svc/traefik 9000:9000
# → http://localhost:9000/dashboard/
```

### 7.2 Troubleshooting

| Symptôme | Cause probable | Solution |
|----------|---------------|----------|
| 404 Not Found | Host non matché | Vérifier `/etc/hosts` et Ingress host |
| 503 Service Unavailable | Pod backend down | `kubectl get pods -n <namespace>` |
| Certificate error | TLS secret manquant | Vérifier cert-manager et secret |
| Bad Gateway | Service port incorrect | Vérifier le port du Service |

---

## 8. Alternatives Futures

### 8.1 Migration vers Gateway API

Kubernetes **Gateway API** est le successeur d'Ingress :

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: keycloak
spec:
  parentRefs:
    - name: main-gateway
  hostnames:
    - "auth.ai-platform.localhost"
  rules:
    - backendRefs:
        - name: keycloak-keycloakx-http
          port: 80
```

**Avantages** :
- Plus expressif qu'Ingress
- Séparation des responsabilités (Gateway vs Route)
- Support natif Traefik

**Timeline** : À considérer quand Gateway API sera GA stable.

---

## 9. Conséquences

### Positives

- ✅ Zero effort déploiement (K3s default)
- ✅ Hot reload sans downtime
- ✅ Dashboard pour debugging
- ✅ Middlewares déclaratifs
- ✅ Excellent support Let's Encrypt / cert-manager
- ✅ GitOps-friendly (Ingress = YAML dans Git)

### Négatives

- ⚠️ Features L4 moins avancées que HAProxy
- ⚠️ Spécifique à l'écosystème Traefik pour CRDs

### Risques mitigés

| Risque | Mitigation |
|--------|------------|
| Vendor lock-in CRDs | Utiliser Ingress standard quand possible |
| Performance | Suffisant pour home lab, scalable si besoin |

---

## 10. Références

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [K3s Networking](https://docs.k3s.io/networking)
- [cert-manager](https://cert-manager.io/docs/)

---

*ADR maintenue par l'équipe AI Security Platform*
