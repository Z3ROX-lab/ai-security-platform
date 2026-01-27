# Sealed Secrets Guide

## Overview

Sealed Secrets permet de stocker des secrets chiffrés dans Git en toute sécurité. C'est la solution recommandée pour GitOps.

| Aspect | Détails |
|--------|---------|
| **Projet** | Bitnami Sealed Secrets |
| **Licence** | Apache 2.0 |
| **Composants** | Controller (cluster) + kubeseal (CLI) |

---

## Part 1: Le Problème

### Secrets Kubernetes = Base64 (PAS chiffré!)

```yaml
# ❌ DANGER - Ce secret peut être décodé par n'importe qui
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
type: Opaque
data:
  password: cGFzc3dvcmQxMjM=   # base64 de "password123"
```

```bash
# N'importe qui peut décoder:
echo "cGFzc3dvcmQxMjM=" | base64 -d
# Output: password123
```

**Si tu commit ça dans Git** → Tes secrets sont exposés à tous ceux qui ont accès au repo!

---

## Part 2: La Solution - Sealed Secrets

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SEALED SECRETS ARCHITECTURE                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  DÉVELOPPEUR (local)                 KUBERNETES CLUSTER                 │
│  ═══════════════════                 ══════════════════                  │
│                                                                          │
│  ┌──────────────────┐               ┌──────────────────────────────┐   │
│  │                  │               │  Sealed Secrets Controller   │   │
│  │  1. Crée Secret  │               │                              │   │
│  │     (plain)      │               │  • Génère key pair           │   │
│  │                  │               │  • Stocke clé privée         │   │
│  └────────┬─────────┘               │  • Expose clé publique       │   │
│           │                         │                              │   │
│           ▼                         └──────────────────────────────┘   │
│  ┌──────────────────┐                           │                       │
│  │                  │                           │                       │
│  │  2. kubeseal     │◄──────────────────────────┘                       │
│  │     (CLI)        │     Récupère clé publique                        │
│  │                  │                                                   │
│  └────────┬─────────┘                                                   │
│           │                                                             │
│           │ Chiffre avec clé publique                                  │
│           ▼                                                             │
│  ┌──────────────────┐                                                   │
│  │                  │                                                   │
│  │  3. SealedSecret │                                                   │
│  │     (chiffré)    │                                                   │
│  │                  │                                                   │
│  └────────┬─────────┘                                                   │
│           │                                                             │
│           │ Commit + Push to Git                                       │
│           ▼                                                             │
│  ┌──────────────────┐               ┌──────────────────────────────┐   │
│  │                  │               │                              │   │
│  │  4. Git Repo     │──── ArgoCD ──▶│  5. SealedSecret déployé    │   │
│  │                  │    syncs      │                              │   │
│  └──────────────────┘               └──────────────┬───────────────┘   │
│                                                    │                    │
│                                                    │ Controller         │
│                                                    │ déchiffre          │
│                                                    ▼                    │
│                                     ┌──────────────────────────────┐   │
│                                     │                              │   │
│                                     │  6. Secret (plain)          │   │
│                                     │     créé automatiquement     │   │
│                                     │                              │   │
│                                     └──────────────────────────────┘   │
│                                                    │                    │
│                                                    │ Utilisé par       │
│                                                    ▼                    │
│                                     ┌──────────────────────────────┐   │
│                                     │                              │   │
│                                     │  7. Pods (Open WebUI, etc.) │   │
│                                     │                              │   │
│                                     └──────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Secret vs SealedSecret

```yaml
# ❌ Secret (JAMAIS dans Git)
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
data:
  password: cGFzc3dvcmQxMjM=    # Décodable!

---

# ✅ SealedSecret (SAFE dans Git)
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: my-secret
spec:
  encryptedData:
    password: AgB4j2k8... (très long string chiffré) ...X9Yz==
    # Impossible à déchiffrer sans la clé privée du cluster!
```

---

## Part 3: Installation

### Step 1: Déployer le Controller via ArgoCD

```yaml
# argocd/applications/security/sealed-secrets/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sealed-secrets
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://bitnami-labs.github.io/sealed-secrets
    chart: sealed-secrets
    targetRevision: 2.14.2
    helm:
      parameters:
        - name: fullnameOverride
          value: sealed-secrets-controller
  destination:
    server: https://kubernetes.default.svc
    namespace: kube-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Step 2: Installer kubeseal CLI

```bash
# Télécharger kubeseal
KUBESEAL_VERSION="0.24.5"
wget "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"

# Extraire et installer
tar -xvzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# Vérifier
kubeseal --version
```

### Step 3: Récupérer la clé publique (optionnel, pour offline)

```bash
# kubeseal peut récupérer la clé automatiquement si connecté au cluster
# Mais tu peux aussi la sauvegarder:
kubeseal --fetch-cert > sealed-secrets-cert.pem
```

---

## Part 4: Utilisation

### Workflow complet

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CRÉATION D'UN SEALED SECRET                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ÉTAPE 1: Créer un Secret normal (en mémoire, pas de fichier!)         │
│  ═════════════════════════════════════════════════════════════          │
│                                                                          │
│  kubectl create secret generic my-secret \                              │
│    --namespace my-namespace \                                           │
│    --from-literal=password=SuperSecret123 \                             │
│    --dry-run=client \                                                   │
│    -o yaml                                                              │
│                                                                          │
│  Note: --dry-run=client = ne crée PAS le secret, juste le YAML         │
│                                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  ÉTAPE 2: Piper vers kubeseal                                          │
│  ═══════════════════════════                                             │
│                                                                          │
│  kubectl create secret generic my-secret \                              │
│    --namespace my-namespace \                                           │
│    --from-literal=password=SuperSecret123 \                             │
│    --dry-run=client \                                                   │
│    -o yaml | kubeseal -o yaml > my-sealedsecret.yaml                   │
│                                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  ÉTAPE 3: Commit le SealedSecret                                       │
│  ═══════════════════════════════                                         │
│                                                                          │
│  git add my-sealedsecret.yaml                                          │
│  git commit -m "feat: add sealed secret for my-app"                    │
│  git push                                                               │
│                                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  ÉTAPE 4: ArgoCD déploie → Controller déchiffre → Secret créé          │
│  ══════════════════════════════════════════════════════════             │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Exemple concret: Secret pour Open WebUI

```bash
# 1. Créer et sceller le secret DB
kubectl create secret generic openwebui-db-secret \
  --namespace ai-apps \
  --from-literal=password=openwebui123 \
  --dry-run=client \
  -o yaml | kubeseal -o yaml > argocd/applications/ai-apps/open-webui/manifests/sealed-secret.yaml

# 2. Vérifier le contenu (c'est chiffré!)
cat argocd/applications/ai-apps/open-webui/manifests/sealed-secret.yaml

# 3. Commit
git add argocd/applications/ai-apps/open-webui/manifests/sealed-secret.yaml
git commit -m "feat: add sealed secret for openwebui database"
git push
```

### Exemple concret: Secret pour init-db job

```bash
# Créer un secret avec le password postgres superuser
kubectl create secret generic postgres-init-creds \
  --namespace ai-apps \
  --from-literal=password=Iy7UHwZRYJS7oKQrkldC9qwfkevQ3txd8Bb2orezpaGQfcXon2Iner0g2kST2BRj \
  --dry-run=client \
  -o yaml | kubeseal -o yaml > argocd/applications/ai-apps/open-webui/manifests/sealed-postgres-secret.yaml
```

---

## Part 5: Options de Scoping

### Scope = Qui peut utiliser le secret

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SEALED SECRET SCOPES                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  STRICT (default)                                                       │
│  ════════════════                                                        │
│  • Secret lié à un namespace ET un nom spécifique                       │
│  • Plus sécurisé                                                        │
│  • Erreur si tu changes le nom ou namespace                             │
│                                                                          │
│  kubeseal --scope strict                                                │
│                                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  NAMESPACE-WIDE                                                         │
│  ══════════════                                                          │
│  • Secret utilisable par n'importe quel nom dans le namespace          │
│  • Utile si tu veux renommer le secret                                  │
│                                                                          │
│  kubeseal --scope namespace-wide                                        │
│                                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  CLUSTER-WIDE                                                           │
│  ═════════════                                                           │
│  • Secret utilisable n'importe où dans le cluster                       │
│  • Moins sécurisé mais plus flexible                                    │
│                                                                          │
│  kubeseal --scope cluster-wide                                          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Exemples

```bash
# Strict (default) - recommandé
kubectl create secret generic my-secret \
  --namespace production \
  --from-literal=api-key=xxx \
  --dry-run=client -o yaml | kubeseal -o yaml

# Namespace-wide
kubectl create secret generic my-secret \
  --namespace production \
  --from-literal=api-key=xxx \
  --dry-run=client -o yaml | kubeseal --scope namespace-wide -o yaml

# Cluster-wide (à éviter si possible)
kubectl create secret generic my-secret \
  --from-literal=api-key=xxx \
  --dry-run=client -o yaml | kubeseal --scope cluster-wide -o yaml
```

---

## Part 6: Rotation des clés

### Pourquoi?

La clé privée du controller est critique. Si elle est compromise, tous les SealedSecrets peuvent être déchiffrés.

### Rotation automatique

```yaml
# Dans les values du Helm chart
keyrenewperiod: "720h"   # Nouvelle clé tous les 30 jours
```

### Rotation manuelle

```bash
# 1. Générer nouvelle clé
kubectl -n kube-system delete secret -l sealedsecrets.bitnami.com/sealed-secrets-key

# 2. Redémarrer le controller
kubectl -n kube-system rollout restart deployment sealed-secrets-controller

# 3. Re-sceller tous les secrets avec la nouvelle clé
kubeseal --re-encrypt < old-sealed.yaml > new-sealed.yaml
```

---

## Part 7: Backup et Disaster Recovery

### CRITIQUE: Sauvegarder la clé privée!

```bash
# Exporter la clé privée (GARDER EN SÉCURITÉ!)
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o yaml > sealed-secrets-master-key.yaml

# Stocker dans un endroit sûr:
# - Password manager (1Password, Bitwarden)
# - Vault
# - Coffre-fort physique
# ❌ PAS dans Git!
```

### Restaurer après disaster

```bash
# 1. Installer Sealed Secrets controller
# 2. Restaurer la clé
kubectl apply -f sealed-secrets-master-key.yaml
# 3. Redémarrer controller
kubectl -n kube-system rollout restart deployment sealed-secrets-controller
# 4. Tous les SealedSecrets fonctionnent à nouveau!
```

---

## Part 8: Troubleshooting

### Le Secret n'est pas créé

```bash
# Vérifier le SealedSecret
kubectl get sealedsecret -n my-namespace

# Vérifier les logs du controller
kubectl logs -n kube-system deployment/sealed-secrets-controller

# Erreur commune: mauvais namespace ou nom (scope strict)
```

### "Error: cannot fetch certificate"

```bash
# Le controller n'est pas accessible
kubectl get pods -n kube-system | grep sealed

# Si pas running, vérifier:
kubectl describe pod -n kube-system -l app.kubernetes.io/name=sealed-secrets
```

### Mettre à jour un secret existant

```bash
# Recréer et resceller (pas d'update in-place)
kubectl create secret generic my-secret \
  --namespace my-namespace \
  --from-literal=password=NEW_PASSWORD \
  --dry-run=client \
  -o yaml | kubeseal -o yaml > updated-sealed-secret.yaml

# Commit et push
git add updated-sealed-secret.yaml
git commit -m "update: rotate my-secret password"
git push
```

---

## Part 9: Best Practices

### ✅ Do

| Practice | Pourquoi |
|----------|----------|
| Utiliser `--dry-run=client` | Ne jamais créer le secret plain |
| Sauvegarder la master key | Disaster recovery |
| Utiliser scope strict | Plus sécurisé |
| Un SealedSecret par secret | Facilite la gestion |
| Rotation régulière | Limite l'impact d'une fuite |

### ❌ Don't

| Practice | Pourquoi |
|----------|----------|
| Commit des Secrets plain | Exposés dans Git |
| Partager la clé privée | Compromet tout |
| Utiliser cluster-wide scope | Trop permissif |
| Ignorer les erreurs du controller | Secrets non créés |

---

## Part 10: Intégration avec ArgoCD

### Structure recommandée

```
argocd/applications/my-app/
├── application.yaml
├── values.yaml
└── manifests/
    ├── sealed-secret.yaml     # ✅ SealedSecret (safe)
    └── configmap.yaml         # ConfigMap (non sensible)
```

### Dans ArgoCD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
spec:
  sources:
    - repoURL: https://charts.example.com
      chart: my-app
      helm:
        valueFiles:
          - $values/argocd/applications/my-app/values.yaml
    - repoURL: https://github.com/myorg/my-repo
      ref: values
    - repoURL: https://github.com/myorg/my-repo
      path: argocd/applications/my-app/manifests   # Inclut SealedSecrets
```

---

## Commandes Quick Reference

| Action | Commande |
|--------|----------|
| Installer kubeseal | `wget ... && sudo install kubeseal /usr/local/bin/` |
| Créer SealedSecret | `kubectl create secret ... --dry-run=client -o yaml \| kubeseal -o yaml` |
| Récupérer cert | `kubeseal --fetch-cert > cert.pem` |
| Utiliser cert offline | `kubeseal --cert cert.pem -o yaml` |
| Vérifier controller | `kubectl logs -n kube-system deployment/sealed-secrets-controller` |
| Lister SealedSecrets | `kubectl get sealedsecrets -A` |
| Backup master key | `kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml` |

---

## Références

- [Sealed Secrets GitHub](https://github.com/bitnami-labs/sealed-secrets)
- [Sealed Secrets Helm Chart](https://github.com/bitnami-labs/sealed-secrets/tree/main/helm/sealed-secrets)
- [kubeseal CLI Releases](https://github.com/bitnami-labs/sealed-secrets/releases)
- [ArgoCD + Sealed Secrets](https://argo-cd.readthedocs.io/en/stable/operator-manual/secret-management/)
