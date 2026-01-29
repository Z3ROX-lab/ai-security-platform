# ADR-013: Container Network Interface (CNI) Strategy

## Status
**Accepted**

## Date
2025-01-29

## Context

L'AI Security Platform doit fonctionner dans plusieurs environnements :
- **Home lab** : K3d sur laptop (32GB RAM, ressources limitées)
- **Production** : OpenShift/Kubernetes on-premise (GTT, données sensibles C4-C5)

Le choix du CNI (Container Network Interface) impacte :
- La performance réseau entre pods
- Les capacités de sécurité (NetworkPolicies)
- La consommation de ressources
- L'observabilité du trafic
- La complexité opérationnelle

---

## Options évaluées

### Option 1: Flannel

| Aspect | Évaluation |
|--------|------------|
| **Description** | CNI simple utilisant VXLAN overlay |
| **Mainteneur** | Flannel-io (CNCF) |
| **Licence** | Apache 2.0 |

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         FLANNEL ARCHITECTURE                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Node 1                              Node 2                             │
│  ┌──────────────────────┐           ┌──────────────────────┐           │
│  │  Pod A     Pod B     │           │  Pod C     Pod D     │           │
│  │  10.42.0.2 10.42.0.3 │           │  10.42.1.2 10.42.1.3 │           │
│  │       │         │    │           │       │         │    │           │
│  │       └────┬────┘    │           │       └────┬────┘    │           │
│  │            │         │           │            │         │           │
│  │      ┌─────┴─────┐   │           │      ┌─────┴─────┐   │           │
│  │      │  cni0     │   │           │      │  cni0     │   │           │
│  │      │ (bridge)  │   │           │      │ (bridge)  │   │           │
│  │      └─────┬─────┘   │           │      └─────┬─────┘   │           │
│  │            │         │           │            │         │           │
│  │      ┌─────┴─────┐   │           │      ┌─────┴─────┐   │           │
│  │      │ flannel.1 │   │           │      │ flannel.1 │   │           │
│  │      │  (VXLAN)  │   │           │      │  (VXLAN)  │   │           │
│  │      └─────┬─────┘   │           │      └─────┬─────┘   │           │
│  └────────────┼─────────┘           └────────────┼─────────┘           │
│               │                                  │                      │
│               └──────────── UDP 8472 ────────────┘                      │
│                        (VXLAN tunnel)                                   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

**Avantages :**
- ✅ Ultra simple à déployer et opérer
- ✅ Très léger (~50MB RAM)
- ✅ Stable et mature (depuis 2014)
- ✅ Défaut de K3s, bien intégré
- ✅ Facile à débugger

**Inconvénients :**
- ❌ Pas de NetworkPolicy native (besoin de Kube-router)
- ❌ Overhead VXLAN (~10-15% latence)
- ❌ Pas de chiffrement natif
- ❌ Pas d'observabilité avancée
- ❌ Fonctionnalités limitées

---

### Option 2: Calico

| Aspect | Évaluation |
|--------|------------|
| **Description** | CNI enterprise avec NetworkPolicy avancée |
| **Mainteneur** | Tigera |
| **Licence** | Apache 2.0 |

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CALICO ARCHITECTURE                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     CALICO COMPONENTS                            │   │
│  │                                                                  │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │   │
│  │  │ Felix       │  │ BIRD        │  │ confd       │             │   │
│  │  │ (agent)     │  │ (BGP)       │  │ (config)    │             │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘             │   │
│  │        │                │                │                      │   │
│  │        └────────────────┼────────────────┘                      │   │
│  │                         │                                        │   │
│  │                  ┌──────┴──────┐                                │   │
│  │                  │  Datastore  │                                │   │
│  │                  │ (etcd/kube) │                                │   │
│  │                  └─────────────┘                                │   │
│  │                                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  Modes réseau:                                                          │
│  • IPIP (overlay) - fonctionne partout                                 │
│  • VXLAN - compatible avec Flannel                                     │
│  • BGP (native) - meilleure performance, requiert config réseau        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

**Avantages :**
- ✅ NetworkPolicy native complète (L3/L4)
- ✅ Performance BGP (routage natif)
- ✅ Chiffrement WireGuard disponible
- ✅ Bien documenté, large adoption
- ✅ Support enterprise (Tigera)

**Inconvénients :**
- ⚠️ Plus gourmand en ressources (~200MB RAM)
- ⚠️ BGP peut être complexe à configurer
- ❌ Pas de NetworkPolicy L7 (version open source)
- ❌ Observabilité limitée sans Calico Enterprise

---

### Option 3: Cilium ⭐ RECOMMANDÉ PRODUCTION

| Aspect | Évaluation |
|--------|------------|
| **Description** | CNI moderne basé sur eBPF |
| **Mainteneur** | Isovalent (acquis par Cisco 2024) |
| **Licence** | Apache 2.0 |
| **Status** | CNCF Graduated (2024) |

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CILIUM ARCHITECTURE                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                        CILIUM STACK                              │   │
│  │                                                                  │   │
│  │  ┌─────────────────────────────────────────────────────────┐   │   │
│  │  │                    HUBBLE (Observability)                │   │   │
│  │  │  • Flow visibility    • Service map    • Metrics        │   │   │
│  │  └─────────────────────────────────────────────────────────┘   │   │
│  │                              │                                  │   │
│  │  ┌─────────────────────────────────────────────────────────┐   │   │
│  │  │                 CILIUM AGENT (per node)                  │   │   │
│  │  │                                                          │   │   │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │   │   │
│  │  │  │ L3/L4 Policy │  │ L7 Policy    │  │ Encryption   │  │   │   │
│  │  │  │ (Network)    │  │ (HTTP/gRPC)  │  │ (WireGuard)  │  │   │   │
│  │  │  └──────────────┘  └──────────────┘  └──────────────┘  │   │   │
│  │  │                          │                               │   │   │
│  │  │  ┌──────────────────────────────────────────────────┐  │   │   │
│  │  │  │              eBPF DATAPATH                        │  │   │   │
│  │  │  │   • XDP (ingress)     • TC (egress)              │  │   │   │
│  │  │  │   • Socket hooks      • Kernel bypass            │  │   │   │
│  │  │  └──────────────────────────────────────────────────┘  │   │   │
│  │  │                                                          │   │   │
│  │  └─────────────────────────────────────────────────────────┘   │   │
│  │                                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  eBPF = Extended Berkeley Packet Filter                                 │
│  Exécute du code dans le kernel Linux sans modules                      │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

**Avantages :**
- ✅ Performance eBPF (bypass kernel network stack)
- ✅ NetworkPolicy L3/L4 ET L7 (HTTP, gRPC, Kafka)
- ✅ Chiffrement transparent (WireGuard)
- ✅ Observabilité native (Hubble)
- ✅ Service Mesh intégré (sans sidecar)
- ✅ CNCF Graduated, très actif
- ✅ Remplace kube-proxy (performance)

**Inconvénients :**
- ⚠️ Gourmand en ressources (~500MB RAM)
- ⚠️ Requiert kernel Linux 4.19+ (5.10+ recommandé)
- ⚠️ Courbe d'apprentissage
- ⚠️ Plus complexe à débugger

---

### Option 4: Canal (Flannel + Calico)

| Aspect | Évaluation |
|--------|------------|
| **Description** | Flannel pour le réseau + Calico pour les policies |

**Avantages :**
- ✅ Simplicité Flannel + NetworkPolicy Calico
- ✅ Bon compromis

**Inconvénients :**
- ⚠️ Deux composants à gérer
- ❌ Pas les avantages performance de Calico BGP

---

### Option 5: Weave Net

| Aspect | Évaluation |
|--------|------------|
| **Description** | CNI mesh avec chiffrement intégré |

**Avantages :**
- ✅ Chiffrement automatique
- ✅ Multi-cloud friendly
- ✅ Simple

**Inconvénients :**
- ⚠️ Performance moyenne
- ⚠️ Projet moins actif
- ❌ Weaveworks a fermé (2024)

---

## Matrice de décision

| Critère | Poids | Flannel | Calico | Cilium | Canal | Weave |
|---------|-------|---------|--------|--------|-------|-------|
| Performance | 15% | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| NetworkPolicy L3/L4 | 20% | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| NetworkPolicy L7 | 15% | ⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐ |
| Chiffrement | 15% | ⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Observabilité | 10% | ⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| Ressources (légèreté) | 15% | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| Simplicité | 10% | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Score pondéré** | | **2.85** | **3.65** | **4.20** | **3.50** | **3.10** |

---

## Decision

### Home Lab : Flannel (K3s défaut)

```yaml
# K3s utilise Flannel par défaut
# Pas de configuration nécessaire
```

**Justification :**
1. Ressources limitées (32GB partagés avec Ollama)
2. Simplicité de debugging
3. K3s inclut Kube-router pour NetworkPolicies
4. Suffisant pour apprendre et prototyper

### Production Enterprise (GTT) : Cilium

```yaml
# Installation Cilium sur OpenShift/Kubernetes
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --version 1.15.0 \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set encryption.enabled=true \
  --set encryption.type=wireguard \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true
```

**Justification :**
1. **Sécurité** : NetworkPolicy L7 pour contrôler HTTP/gRPC
2. **Chiffrement** : WireGuard transparent entre pods
3. **Conformité** : Audit via Hubble pour C4-C5
4. **Performance** : eBPF bypass pour les workloads AI
5. **Observabilité** : Visibilité complète du trafic

---

## Architecture par environnement

### Home Lab (K3d + Flannel)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    HOME LAB - K3D + FLANNEL                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                         K3s Cluster                                │ │
│  │                                                                    │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │ │
│  │  │   Node 1    │  │   Node 2    │  │   Node 3    │              │ │
│  │  │  (server)   │  │  (agent)    │  │  (agent)    │              │ │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘              │ │
│  │         │                │                │                       │ │
│  │         └────────────────┼────────────────┘                       │ │
│  │                          │                                        │ │
│  │                   ┌──────┴──────┐                                │ │
│  │                   │   Flannel   │                                │ │
│  │                   │   (VXLAN)   │                                │ │
│  │                   └──────┬──────┘                                │ │
│  │                          │                                        │ │
│  │                   ┌──────┴──────┐                                │ │
│  │                   │ Kube-router │                                │ │
│  │                   │ (NetPolicy) │                                │ │
│  │                   └─────────────┘                                │ │
│  │                                                                    │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  RAM CNI: ~50MB                                                         │
│  NetworkPolicy: L3/L4 via Kube-router                                  │
│  Chiffrement: Non (acceptable pour lab local)                          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Production (OpenShift + Cilium)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                 PRODUCTION GTT - OPENSHIFT + CILIUM                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                      OpenShift Cluster                             │ │
│  │                                                                    │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │ │
│  │  │  Master 1   │  │  Master 2   │  │  Master 3   │              │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘              │ │
│  │                                                                    │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │ │
│  │  │  Worker 1   │  │  Worker 2   │  │  Worker 3   │  (+ GPU)     │ │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘              │ │
│  │         │                │                │                       │ │
│  │         └────────────────┼────────────────┘                       │ │
│  │                          │                                        │ │
│  │  ┌───────────────────────┴───────────────────────┐              │ │
│  │  │                    CILIUM                      │              │ │
│  │  │                                                │              │ │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐    │              │ │
│  │  │  │  eBPF    │  │ WireGuard│  │  Hubble  │    │              │ │
│  │  │  │ Datapath │  │ Encrypt  │  │ Observe  │    │              │ │
│  │  │  └──────────┘  └──────────┘  └──────────┘    │              │ │
│  │  │                                                │              │ │
│  │  │  NetworkPolicy: L3/L4/L7                      │              │ │
│  │  │  Service Mesh: Sidecar-less                   │              │ │
│  │  │  kube-proxy: Replaced by eBPF                 │              │ │
│  │  │                                                │              │ │
│  │  └────────────────────────────────────────────────┘              │ │
│  │                                                                    │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  RAM CNI: ~500MB (acceptable sur nodes 128GB+)                         │
│  NetworkPolicy: L3/L4/L7 (HTTP headers, paths)                         │
│  Chiffrement: WireGuard transparent                                    │
│  Observabilité: Hubble + Prometheus metrics                            │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Exemples de NetworkPolicy par CNI

### Flannel + Kube-router (L3/L4)

```yaml
# Bloque par IP/Port - fonctionne avec Flannel/Kube-router
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-postgresql
  namespace: storage
spec:
  podSelector:
    matchLabels:
      app: postgresql
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ai-apps
      ports:
        - port: 5432
          protocol: TCP
```

### Cilium (L7 - HTTP)

```yaml
# Bloque par path HTTP - uniquement Cilium
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-api-readonly
  namespace: ai-apps
spec:
  endpointSelector:
    matchLabels:
      app: api-server
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: frontend
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
          rules:
            http:
              - method: "GET"
                path: "/api/v1/models"
              - method: "GET"
                path: "/api/v1/health"
```

### Cilium (L7 - gRPC)

```yaml
# Bloque par service gRPC - uniquement Cilium
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-inference-grpc
spec:
  endpointSelector:
    matchLabels:
      app: vllm
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: open-webui
      toPorts:
        - ports:
            - port: "8001"
              protocol: TCP
          rules:
            http:  # gRPC over HTTP/2
              - method: "POST"
                path: "/inference.InferenceService/Generate"
```

---

## Migration Flannel → Cilium

Pour une migration future du home lab vers Cilium :

```bash
# 1. Installer Cilium CLI
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz
tar xzvf cilium-linux-amd64.tar.gz
sudo mv cilium /usr/local/bin/

# 2. Installer Cilium (remplace Flannel)
cilium install --version 1.15.0

# 3. Activer Hubble
cilium hubble enable --ui

# 4. Vérifier
cilium status
cilium connectivity test
```

---

## Conséquences

### Positives

- ✅ Home lab léger et fonctionnel avec Flannel
- ✅ Production sécurisée avec Cilium
- ✅ Compétences transférables (NetworkPolicy standard)
- ✅ Observabilité production via Hubble
- ✅ Chiffrement transparent en production

### Négatives

- ⚠️ Pas de chiffrement dans le home lab
- ⚠️ Pas de NetworkPolicy L7 dans le home lab
- ⚠️ Différence d'architecture entre envs

### Mitigations

| Risque | Mitigation |
|--------|------------|
| Différences env | NetworkPolicies L3/L4 standard fonctionnent partout |
| Pas de chiffrement lab | Acceptable pour données non-sensibles |
| Complexité Cilium | Formation, documentation, Hubble UI |

---

## Références

- [Flannel Documentation](https://github.com/flannel-io/flannel)
- [Calico Documentation](https://docs.tigera.io/calico/latest/about/)
- [Cilium Documentation](https://docs.cilium.io/)
- [Cilium vs Calico Benchmark](https://cilium.io/blog/2021/05/11/cni-benchmark/)
- [K3s Networking](https://docs.k3s.io/networking)
- [eBPF Introduction](https://ebpf.io/)
- [Hubble Observability](https://docs.cilium.io/en/stable/gettingstarted/hubble/)
- [ADR-004: Storage Strategy](./ADR-004-storage-strategy.md)
