# GitOps Guide - AI Security Platform

## Vue d'ensemble

Ce projet utilise **ArgoCD** pour le déploiement GitOps. Ce guide explique notre structure, nos conventions et comment ajouter de nouveaux composants.

---

## Concepts clés

### Qu'est-ce que GitOps ?

```
Git = Source of Truth
         │
         ▼
      ArgoCD ──── Observe ────► Git Repo
         │
         │ Sync
         ▼
     Kubernetes
```

**Principe** : L'état désiré du cluster est décrit dans Git. ArgoCD synchronise automatiquement le cluster avec Git.

---

### Helm Chart vs ArgoCD Application

| Concept | Qui le fournit | C'est quoi |
|---------|----------------|------------|
| **Helm Chart** | Mainteneur officiel (Bitnami, Longhorn...) | Templates K8s + valeurs par défaut |
| **ArgoCD Application** | **Nous** | CRD qui dit à ArgoCD "déploie ce chart" |
| **values.yaml** | **Nous** | Nos customisations par-dessus les defaults |

#### Pourquoi créer `application.yaml` nous-mêmes ?

Le Helm chart ne sait pas qu'ArgoCD existe. C'est nous qui faisons le lien :

```
Helm Chart officiel     →  Fournit les templates K8s (pods, services, etc.)
application.yaml        →  On le crée pour dire à ArgoCD "utilise ce chart"
values.yaml             →  On le crée pour customiser le chart
```

#### Alternatives à `application.yaml` (non recommandées)

| Méthode | Comment | GitOps ? |
|---------|---------|----------|
| UI ArgoCD | Clic "New App" | ❌ Non déclaratif |
| CLI | `argocd app create ...` | ❌ Non déclaratif |
| **Fichier YAML** | `application.yaml` dans Git | ✅ **GitOps** |

---

## Structure du repository

```
ai-security-platform/
│
├── argocd/
│   └── applications/
│       ├── storage/                    # Phase 2
│       │   ├── longhorn/
│       │   │   ├── application.yaml    # ArgoCD Application (pointe vers chart)
│       │   │   └── values.yaml         # Nos customisations
│       │   ├── seaweedfs/
│       │   │   ├── application.yaml
│       │   │   └── values.yaml
│       │   └── postgresql/
│       │       ├── application.yaml
│       │       └── values.yaml
│       │
│       ├── security/                   # Phase 3-4
│       │   ├── keycloak/
│       │   └── kyverno/
│       │
│       └── ai/                         # Phase 5-7
│           ├── ollama/
│           ├── qdrant/
│           └── guardrails/
│
├── docs/
│   └── adr/                            # Architecture Decision Records
│       ├── ADR-001-k3d.md
│       ├── ADR-002-argocd.md
│       └── ...
│
└── infrastructure/
    └── terraform/                      # Cluster provisioning (Phase 1)
```

### Conventions de nommage

| Élément | Convention | Exemple |
|---------|------------|---------|
| Dossier composant | Nom du composant en minuscules | `longhorn/`, `keycloak/` |
| Application ArgoCD | `application.yaml` | Toujours ce nom |
| Values | `values.yaml` | Toujours ce nom |
| Namespace | Par fonction ou composant | `storage`, `ai-inference` |

---

## Flux GitOps détaillé

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              NOTRE GIT REPO                                  │
│                                                                              │
│   argocd/applications/storage/longhorn/                                     │
│   ├── application.yaml ─────────────┐                                       │
│   │   "repoURL: https://charts.longhorn.io"                                │
│   │   "chart: longhorn"              │                                      │
│   │   "targetRevision: 1.7.2"        │                                      │
│   │                                  │                                      │
│   └── values.yaml                    │                                      │
│       "defaultReplicaCount: 1"       │                                      │
│       "resources.limits.memory: 512Mi"                                      │
│                                      │                                      │
└──────────────────────────────────────┼──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                                ARGOCD                                        │
│                                                                              │
│   1. Lit application.yaml depuis notre repo                                 │
│   2. Télécharge le Helm chart depuis charts.longhorn.io                     │
│   3. Applique nos values.yaml par-dessus les defaults                       │
│   4. Génère les manifests K8s finaux                                        │
│   5. Déploie sur le cluster                                                  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         HELM REPO OFFICIEL                                   │
│                      https://charts.longhorn.io                              │
│                                                                              │
│   Chart Longhorn v1.7.2                                                     │
│   ├── templates/          ← Templates K8s (Deployment, Service, etc.)       │
│   ├── values.yaml         ← Valeurs par défaut                              │
│   └── Chart.yaml          ← Metadata du chart                               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              KUBERNETES                                      │
│                                                                              │
│   Namespace: longhorn-system                                                │
│   ├── Deployment longhorn-manager                                           │
│   ├── DaemonSet longhorn-driver                                             │
│   ├── Service longhorn-ui                                                   │
│   └── ...                                                                    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Bonnes pratiques (ADR-005)

### ✅ À faire

| Pratique | Pourquoi |
|----------|----------|
| Référencer les Helm charts officiels | Toujours à jour, patches de sécurité |
| Stocker uniquement `values.yaml` | Petit fichier, facile à maintenir |
| Pinner les versions (`targetRevision: 1.7.2`) | Reproductible, pas de surprise |
| Sync manuel pour infra critique | Évite les accidents |
| Utiliser Sealed Secrets pour les credentials | Sécurité |

### ❌ À ne pas faire

| Anti-pattern | Pourquoi c'est mauvais |
|--------------|------------------------|
| Copier les templates Helm dans le repo | Divergence avec upstream, maintenance |
| Générer les manifests et les commiter | Même problème |
| Utiliser `latest` ou `main` comme version | Non reproductible |
| Mettre des secrets en clair dans Git | Fuite de données |
| Sync auto sur les bases de données | Risque de perte de données |

---

## Comment ajouter un nouveau composant

### Étape 1 : Créer la structure

```bash
mkdir -p argocd/applications/{category}/{component}
# Exemple:
mkdir -p argocd/applications/ai/ollama
```

### Étape 2 : Trouver le Helm chart officiel

```bash
# Chercher sur Artifact Hub
# https://artifacthub.io/

# Ou via Helm CLI
helm search hub ollama
```

### Étape 3 : Créer `application.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {component}              # Ex: ollama
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  sources:
    # Source 1: Helm chart officiel
    - repoURL: {helm-repo-url}   # Ex: https://otwld.github.io/ollama-helm
      chart: {chart-name}        # Ex: ollama
      targetRevision: {version}  # Ex: 0.52.0 (TOUJOURS pinner!)
      helm:
        valueFiles:
          - $values/argocd/applications/{category}/{component}/values.yaml
    # Source 2: Nos values
    - repoURL: https://github.com/Z3ROX-lab/ai-security-platform
      targetRevision: main
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: {target-namespace}  # Ex: ai-inference
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

### Étape 4 : Créer `values.yaml`

```yaml
# {Component} values for AI Security Platform
# Uniquement nos customisations - les defaults viennent du chart

# Exemple de customisations courantes:
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"

persistence:
  enabled: true
  size: 5Gi
  storageClass: longhorn
```

### Étape 5 : Commit et push

```bash
git add argocd/applications/{category}/{component}/
git commit -m "feat: Add {component} ArgoCD application"
git push
```

### Étape 6 : Sync dans ArgoCD

```bash
# Option 1: CLI
argocd app sync {component}

# Option 2: UI
# Aller dans ArgoCD UI → Applications → {component} → Sync
```

---

## Gestion des versions

### Trouver la dernière version d'un chart

```bash
# Ajouter le repo Helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Lister les versions
helm search repo bitnami/postgresql --versions | head -10
```

### Mettre à jour un composant

1. **Tester en local** (optionnel)
   ```bash
   helm template postgresql bitnami/postgresql --version 16.2.1 -f values.yaml
   ```

2. **Mettre à jour `application.yaml`**
   ```yaml
   targetRevision: 16.2.2  # Nouvelle version
   ```

3. **Commit et push**
   ```bash
   git commit -am "chore: Upgrade postgresql to 16.2.2"
   git push
   ```

4. **Sync dans ArgoCD**

---

## Gestion des secrets

### Ne JAMAIS faire

```yaml
# ❌ DANGER: Secret en clair dans Git
auth:
  password: "mon-super-password"
```

### Utiliser Sealed Secrets

```bash
# 1. Créer le secret
kubectl create secret generic db-creds \
  --from-literal=password=mon-password \
  --dry-run=client -o yaml > secret.yaml

# 2. Chiffrer avec kubeseal
kubeseal --format yaml < secret.yaml > sealed-secret.yaml

# 3. Commiter sealed-secret.yaml (chiffré, safe)
git add sealed-secret.yaml
git commit -m "feat: Add DB credentials (sealed)"
```

### Référencer dans values.yaml

```yaml
# ✅ Référence au secret existant
auth:
  existingSecret: db-creds
  secretKeys:
    passwordKey: password
```

---

## Commandes utiles

### ArgoCD CLI

```bash
# Login
argocd login localhost:9090 --insecure

# Lister les apps
argocd app list

# Sync une app
argocd app sync longhorn

# Voir le status
argocd app get longhorn

# Voir les logs de sync
argocd app logs longhorn

# Diff (voir ce qui va changer)
argocd app diff longhorn
```

### Debugging

```bash
# Voir les events ArgoCD
kubectl get events -n argocd --sort-by='.lastTimestamp'

# Logs ArgoCD application controller
kubectl logs -n argocd deployment/argocd-application-controller

# Tester le rendu Helm
helm template longhorn longhorn/longhorn \
  --version 1.7.2 \
  -f argocd/applications/storage/longhorn/values.yaml
```

---

## Checklist nouveau composant

- [ ] Chart officiel trouvé sur Artifact Hub
- [ ] Version pinnée (pas `latest`)
- [ ] `application.yaml` créé
- [ ] `values.yaml` avec nos customisations
- [ ] Namespace défini
- [ ] Secrets via Sealed Secrets (pas en clair)
- [ ] Testé avec `helm template` (optionnel)
- [ ] Commité et pushé
- [ ] Sync dans ArgoCD
- [ ] Vérifié que les pods sont Running

---

## Références

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [Artifact Hub](https://artifacthub.io/)
- [Sealed Secrets](https://sealed-secrets.netlify.app/)
- [ADR-005: ArgoCD Best Practices](./adr/ADR-005-argocd-gitops-best-practices.md)