# K3d Troubleshooting Guide

## Overview

K3d est un wrapper léger pour exécuter K3s (Kubernetes léger) dans Docker. Bien que pratique pour le développement local, il présente certaines limitations et problèmes courants, notamment après un reboot du système hôte.

---

## Problèmes courants et solutions

### Problème 1 : Réseau cross-node cassé après reboot

**Symptômes :**
- `Bad Gateway` sur les ingress
- Pods sur différents nœuds ne peuvent plus communiquer
- `wget: can't connect to remote host: Connection refused` entre nœuds
- Les pods sur le même nœud fonctionnent, mais pas cross-node

**Diagnostic :**
```bash
# Vérifier sur quels nœuds sont les pods
kubectl get pods -o wide -n traefik
kubectl get pods -o wide -n argocd

# Tester la connectivité cross-node
kubectl exec -it -n traefik deploy/traefik -- wget -qO- --timeout=5 http://<POD_IP_AUTRE_NODE>:8080
```

**Cause :**
Les bridges réseau Docker se désynchronisent après un reboot du laptop/PC. K3d utilise des réseaux Docker pour connecter les nœuds du cluster, et ces connexions peuvent être corrompues.

**Solution :**
```bash
# Redémarrer le cluster K3d
k3d cluster stop ai-security-platform
k3d cluster start ai-security-platform

# Attendre que tous les pods soient Running
kubectl get pods -A -w
```

---

### Problème 2 : Pods en CrashLoopBackOff après reboot

**Symptômes :**
```
NAMESPACE   NAME          READY   STATUS             RESTARTS   AGE
ai-apps     open-webui-0  0/1     CrashLoopBackOff   3          2m
```

**Cause :**
- Volumes pas encore montés
- Dépendances (DB, services) pas encore prêtes
- Réseau pas encore initialisé

**Solution :**
```bash
# Attendre 2-3 minutes que tout se stabilise
kubectl get pods -A -w

# Si un pod reste bloqué, le redémarrer
kubectl delete pod <pod-name> -n <namespace>
```

---

### Problème 3 : DNS interne ne résout plus

**Symptômes :**
```bash
kubectl exec -it <pod> -- nslookup kubernetes.default
# Timeout ou erreur
```

**Cause :**
CoreDNS cache corrompu ou pod pas redémarré correctement.

**Solution :**
```bash
kubectl rollout restart deployment coredns -n kube-system
kubectl get pods -n kube-system -l k8s-app=kube-dns -w
```

---

### Problème 4 : Ingress retourne 404

**Symptômes :**
```bash
curl -k https://myapp.ai-platform.localhost
# 404 page not found
```

**Cause :**
- Traefik pas encore synchronisé avec les ingress
- IngressClass manquant

**Diagnostic :**
```bash
kubectl get ingress -A
kubectl logs -n traefik deploy/traefik --tail=20
```

**Solution :**
```bash
kubectl rollout restart deployment traefik -n traefik
```

---

### Problème 5 : Certificats TLS invalides

**Symptômes :**
```
curl: (60) SSL certificate problem: unable to get local issuer certificate
```

**Cause :**
cert-manager n'a pas encore généré les certificats ou le CA n'est pas installé.

**Solution :**
```bash
# Vérifier les certificats
kubectl get certificates -A
kubectl get secrets -A | grep tls

# Forcer le renouvellement
kubectl delete certificate <cert-name> -n <namespace>
```

---

## Procédure de démarrage après reboot

Exécuter cette séquence après chaque reboot du laptop :

```bash
#!/bin/bash
# ~/scripts/start-k3d.sh

echo "🔄 Redémarrage du cluster K3d..."
k3d cluster stop ai-security-platform
k3d cluster start ai-security-platform

echo "⏳ Attente de la stabilisation des pods..."
sleep 30

echo "📊 Vérification de l'état des pods..."
kubectl get pods -A | grep -v Running

echo "🔍 Test des endpoints..."
curl -sk https://argocd.ai-platform.localhost > /dev/null && echo "✅ ArgoCD OK" || echo "❌ ArgoCD KO"
curl -sk https://chat.ai-platform.localhost > /dev/null && echo "✅ Open WebUI OK" || echo "❌ Open WebUI KO"
curl -sk https://auth.ai-platform.localhost > /dev/null && echo "✅ Keycloak OK" || echo "❌ Keycloak KO"

echo "✅ Cluster prêt!"
```

```bash
chmod +x ~/scripts/start-k3d.sh
```

---

## Architecture réseau K3d

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         DOCKER HOST (Laptop)                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    DOCKER NETWORK (k3d-ai-security-platform)     │   │
│  │                                                                  │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │   │
│  │  │   server-0  │  │   agent-0   │  │   agent-1   │             │   │
│  │  │  (master)   │  │  (worker)   │  │  (worker)   │             │   │
│  │  │             │  │             │  │             │             │   │
│  │  │ 10.42.2.x   │  │ 10.42.0.x   │  │ 10.42.1.x   │             │   │
│  │  │             │  │             │  │             │             │   │
│  │  │ • Traefik   │  │ • Pods...   │  │ • ArgoCD    │             │   │
│  │  │ • Open WebUI│  │             │  │ • Keycloak  │             │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘             │   │
│  │         │                │                │                     │   │
│  │         └────────────────┼────────────────┘                     │   │
│  │                          │                                      │   │
│  │              Flannel VXLAN (overlay network)                    │   │
│  │                                                                  │   │
│  │  ⚠️ Cette couche peut se corrompre après un reboot Docker      │   │
│  │                                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  Port mappings:                                                         │
│  • localhost:443 → Traefik (HTTPS)                                     │
│  • localhost:80  → Traefik (HTTP)                                      │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Alternatives pour éviter les problèmes

### Option 1 : Cluster single-node

```bash
# Pas de problème cross-node si un seul nœud
k3d cluster create ai-platform \
  --servers 1 \
  --agents 0 \
  --port "443:443@loadbalancer" \
  --port "80:80@loadbalancer"
```

**Avantages :** Pas de problème réseau cross-node
**Inconvénients :** Ne simule pas un vrai cluster multi-nœud

### Option 2 : Kind (Kubernetes in Docker)

```bash
# Alternative à K3d
kind create cluster --config kind-config.yaml
```

Kind utilise une approche différente pour le réseau et peut être plus stable.

### Option 3 : Minikube avec driver Docker

```bash
minikube start --driver=docker --nodes=3
```

### Option 4 : VM dédiée (plus stable)

Utiliser une VM Linux (Multipass, VirtualBox, WSL2 avec systemd) pour héberger K3s natif au lieu de K3d.

---

## Commandes de diagnostic utiles

```bash
# État du cluster K3d
k3d cluster list

# Logs des nœuds Docker
docker logs k3d-ai-security-platform-server-0
docker logs k3d-ai-security-platform-agent-0

# Vérifier le réseau Docker
docker network inspect k3d-ai-security-platform

# Vérifier la connectivité entre nœuds
kubectl get nodes -o wide
kubectl run test --rm -it --image=busybox -- ping <NODE_IP>

# Vérifier les événements récents
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Vérifier les resources
kubectl top nodes
kubectl top pods -A
```

---

## Limitations connues de K3d

| Limitation | Impact | Workaround |
|------------|--------|------------|
| Réseau instable après reboot | Pods cross-node ne communiquent plus | Restart cluster |
| Pas de LoadBalancer natif | Services LoadBalancer en pending | Utiliser svclb (inclus) |
| Volumes éphémères par défaut | Données perdues si cluster supprimé | Monter des volumes persistants |
| Ressources limitées | OOMKilled fréquents | Augmenter limits Docker |
| Pas de vrai HA | Single point of failure | Acceptable pour home lab |

---

## Références

- [K3d Documentation](https://k3d.io/)
- [K3d GitHub Issues](https://github.com/k3d-io/k3d/issues)
- [K3s Networking](https://docs.k3s.io/networking)
- [Flannel CNI](https://github.com/flannel-io/flannel)
