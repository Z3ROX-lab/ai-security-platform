# Kubernetes Security Architecture Guide

## Overview

Ce guide documente l'architecture de sécurité Kubernetes mise en place sur l'AI Security Platform, avec les leçons apprises et les solutions aux problèmes rencontrés.

| Composant | Rôle |
|-----------|------|
| **NetworkPolicies** | Contrôle du trafic réseau entre pods/namespaces |
| **Pod Security Standards (PSS)** | Restrictions sur ce que les pods peuvent faire |
| **Security Contexts** | Configuration sécurité au niveau pod/container |
| **Sealed Secrets** | Chiffrement des secrets pour GitOps |

---

## Part 1: Vue d'ensemble de l'architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    KUBERNETES SECURITY LAYERS                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  LAYER 4: SECRETS MANAGEMENT                                            │
│  ═══════════════════════════                                             │
│  • Sealed Secrets pour chiffrer les secrets dans Git                    │
│  • Secrets Kubernetes pour les credentials runtime                       │
│                                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  LAYER 3: POD SECURITY STANDARDS (PSS)                                  │
│  ═════════════════════════════════════                                   │
│  • Définit ce qu'un pod peut/ne peut pas faire                          │
│  • Appliqué au niveau namespace                                         │
│  • 3 niveaux: privileged, baseline, restricted                          │
│                                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  LAYER 2: NETWORK POLICIES                                              │
│  ═════════════════════════                                               │
│  • Contrôle qui peut parler à qui                                       │
│  • Ingress (entrant) et Egress (sortant)                                │
│  • Basé sur labels et namespaces                                        │
│                                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  LAYER 1: NAMESPACE ISOLATION                                           │
│  ════════════════════════════                                            │
│  • Séparation logique des workloads                                     │
│  • Base pour les policies                                               │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Notre architecture de namespaces

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    NAMESPACE ARCHITECTURE                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  kube-system          │ Composants Kubernetes (DNS, etc.)               │
│  ─────────────────────┼───────────────────────────────────────────────  │
│  argocd               │ GitOps - ArgoCD                                 │
│  ─────────────────────┼───────────────────────────────────────────────  │
│  cert-manager         │ Gestion des certificats TLS                     │
│  ─────────────────────┼───────────────────────────────────────────────  │
│  traefik              │ Ingress Controller                              │
│  ─────────────────────┼───────────────────────────────────────────────  │
│  storage              │ PostgreSQL (CNPG), jobs d'init DB               │
│  ─────────────────────┼───────────────────────────────────────────────  │
│  auth                 │ Keycloak (IAM)                                  │
│  ─────────────────────┼───────────────────────────────────────────────  │
│  ai-inference         │ Ollama (LLM)                                    │
│  ─────────────────────┼───────────────────────────────────────────────  │
│  ai-apps              │ Open WebUI, futures apps AI                     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Part 2: Network Policies

### Concept de base

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    NETWORK POLICY CONCEPT                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  SANS NetworkPolicy:                                                    │
│  ════════════════════                                                    │
│                                                                          │
│  ┌─────────┐         ┌─────────┐         ┌─────────┐                   │
│  │ Pod A   │ ◄─────► │ Pod B   │ ◄─────► │ Pod C   │                   │
│  └─────────┘         └─────────┘         └─────────┘                   │
│                                                                          │
│  Tous les pods peuvent communiquer entre eux (par défaut)              │
│                                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  AVEC NetworkPolicy:                                                    │
│  ═══════════════════                                                     │
│                                                                          │
│  ┌─────────┐         ┌─────────┐    ✗    ┌─────────┐                   │
│  │ Pod A   │ ◄─────► │ Pod B   │ ◄─────► │ Pod C   │                   │
│  └─────────┘         └─────────┘         └─────────┘                   │
│       │                   ▲                                             │
│       │                   │                                             │
│       └───────────────────┘                                             │
│            Autorisé                                                     │
│                                                                          │
│  Seules les connexions explicitement autorisées passent                │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Structure d'une NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: my-policy
  namespace: target-namespace    # Namespace où s'applique la policy
spec:
  podSelector:                   # Quels pods sont affectés
    matchLabels:
      app: my-app
  
  policyTypes:                   # Types de règles
    - Ingress                    # Trafic entrant
    - Egress                     # Trafic sortant
  
  ingress:                       # Règles pour le trafic entrant
    - from:
        - namespaceSelector:     # Depuis quels namespaces
            matchLabels:
              kubernetes.io/metadata.name: allowed-ns
        - podSelector:           # Depuis quels pods
            matchLabels:
              role: client
      ports:
        - port: 5432
          protocol: TCP
  
  egress:                        # Règles pour le trafic sortant
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - port: 53
          protocol: UDP
```

### Notre NetworkPolicy PostgreSQL

```yaml
# argocd/applications/security/security-baseline/manifests/postgresql-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgresql-policy
  namespace: storage
spec:
  podSelector:
    matchLabels:
      cnpg.io/cluster: postgresql-cluster
  
  policyTypes:
    - Ingress
    - Egress
  
  ingress:
    # Autoriser Keycloak (namespace auth)
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: auth
      ports:
        - port: 5432
          protocol: TCP
    
    # Autoriser Open WebUI (namespace ai-apps)
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ai-apps
      ports:
        - port: 5432
          protocol: TCP
    
    # Autoriser CNPG operator
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: cnpg-system
      ports:
        - port: 5432
          protocol: TCP
        - port: 8000
          protocol: TCP
  
  egress:
    # DNS
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - port: 53
          protocol: UDP
    
    # Réplication entre pods PostgreSQL
    - to:
        - podSelector:
            matchLabels:
              cnpg.io/cluster: postgresql-cluster
      ports:
        - port: 5432
          protocol: TCP
```

### Problèmes rencontrés et solutions

#### Problème 1: Job ne peut pas accéder à PostgreSQL

```
┌─────────────────────────────────────────────────────────────────────────┐
│  PROBLÈME                                                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Namespace: ai-apps              Namespace: storage                     │
│  ┌─────────────────┐             ┌─────────────────┐                   │
│  │ init-db-job     │ ────✗────► │ PostgreSQL      │                   │
│  └─────────────────┘             └─────────────────┘                   │
│                                                                          │
│  Le job dans ai-apps ne peut pas se connecter à PostgreSQL              │
│  Erreur: "Connection refused"                                           │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│  DIAGNOSTIC                                                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. Vérifier les labels du namespace source:                           │
│     kubectl get namespace ai-apps --show-labels                         │
│                                                                          │
│  2. Vérifier la NetworkPolicy:                                          │
│     kubectl get networkpolicy -n storage -o yaml                        │
│                                                                          │
│  3. Tester la connectivité:                                             │
│     kubectl run test --rm -it -n ai-apps --image=busybox -- \          │
│       wget -qO- postgresql-cluster-rw.storage.svc:5432                  │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│  SOLUTION                                                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Option A: Ajouter le namespace dans la NetworkPolicy (si pas fait)    │
│                                                                          │
│  Option B: Déplacer le job dans le namespace storage                   │
│            (ce qu'on a fait - accès direct au secret superuser)         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

**Notre solution** : Déplacer le job d'init DB dans le namespace `storage` :

```yaml
# argocd/applications/storage/openwebui-db-init/manifests/init-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: openwebui-db-init
  namespace: storage          # ← Dans storage, pas ai-apps
spec:
  # ...
```

Avantages :
- Accès direct au secret `postgresql-cluster-superuser`
- Pas besoin de copier le secret cross-namespace
- La NetworkPolicy autorise déjà le trafic intra-namespace

#### Problème 2: Oublier le DNS dans Egress

```yaml
# ❌ MAUVAIS - Pas d'accès DNS
egress:
  - to:
      - podSelector:
          matchLabels:
            app: database
    ports:
      - port: 5432

# ✅ BON - Toujours autoriser DNS
egress:
  # DNS obligatoire!
  - to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: kube-system
    ports:
      - port: 53
        protocol: UDP
  # Puis les autres règles
  - to:
      - podSelector:
          matchLabels:
            app: database
    ports:
      - port: 5432
```

### Labels importants

```bash
# Label automatique sur chaque namespace
kubernetes.io/metadata.name: <namespace-name>

# Vérifier les labels d'un namespace
kubectl get namespace <name> --show-labels

# Les pods héritent des labels définis dans leur spec
kubectl get pods -n <namespace> --show-labels
```

---

## Part 3: Pod Security Standards (PSS)

### Les 3 niveaux

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    POD SECURITY STANDARDS LEVELS                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  PRIVILEGED                                                             │
│  ══════════                                                              │
│  • Aucune restriction                                                   │
│  • Pour les composants système (CNI, storage drivers)                   │
│  • ⚠️ Dangereux - à éviter sauf nécessité                               │
│                                                                          │
│  Namespaces: kube-system                                                │
│                                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  BASELINE                                                               │
│  ════════                                                                │
│  • Restrictions minimales                                               │
│  • Bloque les escalades de privilèges évidentes                         │
│  • Compatible avec la plupart des workloads                             │
│                                                                          │
│  Bloque: hostNetwork, hostPID, hostIPC, privileged containers          │
│                                                                          │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  RESTRICTED (recommandé)                                                │
│  ════════════════════════                                                │
│  • Restrictions maximales                                               │
│  • Suit les best practices de hardening                                 │
│  • Requiert des Security Contexts explicites                            │
│                                                                          │
│  Exige:                                                                 │
│  • runAsNonRoot: true                                                   │
│  • allowPrivilegeEscalation: false                                      │
│  • capabilities.drop: ["ALL"]                                           │
│  • seccompProfile.type: RuntimeDefault                                  │
│                                                                          │
│  Namespaces: storage, auth, ai-apps, ai-inference (notre config)       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Configuration des namespaces

```yaml
# Appliquer PSS via labels sur le namespace
apiVersion: v1
kind: Namespace
metadata:
  name: storage
  labels:
    kubernetes.io/metadata.name: storage
    # Pod Security Standards
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
```

### Modes d'application

| Mode | Comportement |
|------|--------------|
| `enforce` | Rejette les pods non conformes |
| `warn` | Accepte mais affiche un warning |
| `audit` | Accepte et log dans l'audit log |

### Erreur typique PSS

```bash
# Tentative de créer un pod non conforme
$ kubectl run test --image=postgres:16 -n storage

Error from server (Forbidden): pods "test" is forbidden: violates PodSecurity "restricted:latest":
  allowPrivilegeEscalation != false (container "test" must set securityContext.allowPrivilegeEscalation=false),
  unrestricted capabilities (container "test" must set securityContext.capabilities.drop=["ALL"]),
  runAsNonRoot != true (pod or container "test" must set securityContext.runAsNonRoot=true),
  seccompProfile (pod or container "test" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
```

---

## Part 4: Security Contexts

### Template conforme PSS Restricted

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: my-job
spec:
  template:
    spec:
      # Security Context au niveau POD
      securityContext:
        runAsNonRoot: true           # Pas de root
        runAsUser: 999               # UID non-root
        seccompProfile:
          type: RuntimeDefault       # Profil seccomp par défaut
      
      containers:
        - name: my-container
          image: myimage:latest
          
          # Security Context au niveau CONTAINER
          securityContext:
            allowPrivilegeEscalation: false    # Pas d'escalade
            capabilities:
              drop:
                - ALL                          # Supprimer toutes les capabilities
            # readOnlyRootFilesystem: true     # Optionnel mais recommandé
```

### Notre Job d'init DB conforme

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: openwebui-db-init
  namespace: storage
spec:
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: OnFailure
      
      # Pod-level security
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        seccompProfile:
          type: RuntimeDefault
      
      containers:
        - name: init-db
          image: postgres:16
          
          # Container-level security
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
          
          env:
            - name: PGHOST
              value: postgresql-cluster-rw.storage.svc
            - name: PGUSER
              value: postgres
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgresql-cluster-superuser
                  key: password
          
          command:
            - /bin/sh
            - -c
            - |
              set -e
              until pg_isready -h $PGHOST -p 5432 -U $PGUSER; do
                sleep 2
              done
              psql -c "CREATE DATABASE IF NOT EXISTS mydb;"
```

### Tableau des paramètres Security Context

| Paramètre | Niveau | Requis PSS Restricted | Description |
|-----------|--------|----------------------|-------------|
| `runAsNonRoot` | Pod/Container | ✅ Oui | Interdit l'exécution en root |
| `runAsUser` | Pod/Container | Recommandé | Spécifie l'UID |
| `runAsGroup` | Pod/Container | Recommandé | Spécifie le GID |
| `fsGroup` | Pod | Non | GID pour les volumes |
| `seccompProfile.type` | Pod/Container | ✅ Oui | RuntimeDefault ou Localhost |
| `allowPrivilegeEscalation` | Container | ✅ Oui (false) | Bloque les escalades |
| `capabilities.drop` | Container | ✅ Oui (ALL) | Supprime les capabilities |
| `capabilities.add` | Container | Optionnel | Ajoute des capabilities spécifiques |
| `readOnlyRootFilesystem` | Container | Recommandé | Filesystem en lecture seule |
| `privileged` | Container | ❌ Interdit | Mode privilégié |

---

## Part 5: Problèmes courants et solutions

### Problème 1: Job échoue avec "Connection refused" puis affiche "success"

```
┌─────────────────────────────────────────────────────────────────────────┐
│  SYMPTÔME                                                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  $ kubectl logs -n ai-apps job/init-db                                  │
│  psql: error: connection refused                                        │
│  psql: error: connection refused                                        │
│  psql: error: connection refused                                        │
│  Database ready!                                                        │
│                                                                          │
│  Le job affiche "success" mais n'a rien fait!                          │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│  CAUSE                                                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Le script shell n'a pas `set -e` et continue après les erreurs        │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│  SOLUTION                                                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. Ajouter `set -e` pour arrêter sur erreur                           │
│  2. Utiliser `pg_isready` pour attendre PostgreSQL                      │
│                                                                          │
│  command:                                                               │
│    - /bin/sh                                                            │
│    - -c                                                                 │
│    - |                                                                  │
│      set -e                                                             │
│      until pg_isready -h $PGHOST -p 5432; do                           │
│        echo "Waiting..."                                                │
│        sleep 2                                                          │
│      done                                                               │
│      psql -c "CREATE DATABASE mydb;"                                    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Problème 2: Pod OOMKilled

```
┌─────────────────────────────────────────────────────────────────────────┐
│  SYMPTÔME                                                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  $ kubectl get pods -n ai-apps                                          │
│  open-webui-0   0/1   OOMKilled   3   2m                               │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│  CAUSE                                                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Le pod dépasse sa limite mémoire (memory limit)                       │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│  DIAGNOSTIC                                                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  # Vérifier les limites actuelles                                       │
│  kubectl get pod <pod> -o jsonpath='{.spec.containers[0].resources}'   │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│  SOLUTION                                                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Augmenter les limites dans values.yaml:                               │
│                                                                          │
│  resources:                                                             │
│    requests:                                                            │
│      memory: "512Mi"    # Mémoire garantie                             │
│      cpu: "200m"                                                        │
│    limits:                                                              │
│      memory: "2Gi"      # Limite max (augmentée)                       │
│      cpu: "1000m"                                                       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Problème 3: ArgoCD Application bloquée en "Sync"

```
┌─────────────────────────────────────────────────────────────────────────┐
│  SYMPTÔME                                                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  L'application ArgoCD reste bloquée en "Syncing" pendant des heures    │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│  CAUSE                                                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Un PreSync hook (Job) est bloqué et ne termine jamais                 │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│  DIAGNOSTIC                                                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  kubectl get application <app> -n argocd -o yaml | grep -A20 status    │
│  kubectl get jobs -n <namespace>                                        │
│  kubectl describe job <job> -n <namespace>                              │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│  SOLUTION                                                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. Supprimer le job bloqué:                                           │
│     kubectl delete job <job> -n <namespace>                             │
│                                                                          │
│  2. Supprimer les finalizers de l'application:                         │
│     kubectl patch application <app> -n argocd \                        │
│       --type json -p='[{"op":"remove","path":"/metadata/finalizers"}]' │
│                                                                          │
│  3. Supprimer et laisser recréer l'application:                        │
│     kubectl delete application <app> -n argocd                          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Problème 4: Secret non trouvé cross-namespace

```
┌─────────────────────────────────────────────────────────────────────────┐
│  SYMPTÔME                                                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Pod en CreateContainerConfigError                                      │
│  "secret 'postgresql-cluster-superuser' not found"                      │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│  CAUSE                                                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Les secrets sont namespace-scoped!                                     │
│  Un pod dans ai-apps ne peut pas lire un secret dans storage           │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│  SOLUTIONS                                                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Option A: Déplacer le workload dans le namespace du secret            │
│            (Ce qu'on a fait pour le job init-db)                        │
│                                                                          │
│  Option B: Copier le secret avec Sealed Secrets                        │
│            (Créer un SealedSecret dans le namespace cible)              │
│                                                                          │
│  Option C: Utiliser External Secrets Operator                          │
│            (Pour les secrets depuis Vault, AWS SM, etc.)                │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Part 6: Checklist de déploiement sécurisé

### Avant de déployer un nouveau workload

```
□ Namespace créé avec labels PSS restricted
  kubectl get ns <namespace> --show-labels

□ Security Context défini
  - runAsNonRoot: true
  - allowPrivilegeEscalation: false  
  - capabilities.drop: ["ALL"]
  - seccompProfile.type: RuntimeDefault

□ NetworkPolicy créée si accès inter-namespace nécessaire
  - Ingress depuis les namespaces autorisés
  - Egress vers DNS (kube-system:53/UDP)
  - Egress vers les services nécessaires

□ Secrets via Sealed Secrets (pas de plain secrets dans Git)

□ Resource limits définis
  - requests: mémoire/CPU garantis
  - limits: maximum autorisé

□ Healthchecks configurés
  - livenessProbe
  - readinessProbe
```

### Commandes de diagnostic

```bash
# Vérifier PSS d'un namespace
kubectl get namespace <ns> -o jsonpath='{.metadata.labels}' | jq

# Tester si un pod peut être créé
kubectl run test --image=nginx --dry-run=server -n <namespace>

# Vérifier les NetworkPolicies
kubectl get networkpolicy -n <namespace> -o yaml

# Tester la connectivité (avec security context)
kubectl run test --rm -it -n <source-ns> \
  --image=busybox \
  --overrides='{
    "spec": {
      "securityContext": {"runAsNonRoot":true,"runAsUser":1000,"seccompProfile":{"type":"RuntimeDefault"}},
      "containers": [{
        "name": "test",
        "image": "busybox",
        "command": ["wget","-qO-","service.target-ns.svc:port"],
        "securityContext": {"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}
      }]
    }
  }' -- wget -qO- service.target-ns.svc:port

# Vérifier les logs d'un job
kubectl logs -n <namespace> -l job-name=<job-name>

# Vérifier pourquoi un pod est en erreur
kubectl describe pod <pod> -n <namespace>
kubectl logs <pod> -n <namespace> --previous
```

---

## Références

- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Security Context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [Sealed Secrets](https://sealed-secrets.netlify.app/)
- [CNPG Security](https://cloudnative-pg.io/documentation/current/security/)
