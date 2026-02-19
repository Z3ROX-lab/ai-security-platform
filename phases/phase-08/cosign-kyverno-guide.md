# Cosign + Kyverno - Supply Chain Security Guide

## Overview

Ce guide montre comment sécuriser la supply chain des images containers avec Cosign (signature) et Kyverno (vérification).

| Composant | Rôle |
|-----------|------|
| **Cosign** | Signer les images (CLI) |
| **Kyverno** | Vérifier les signatures (admission controller) |
| **Sigstore** | Infrastructure de signature (Fulcio, Rekor) |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SUPPLY CHAIN SECURITY FLOW                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        BUILD PHASE                                   │   │
│  │                                                                      │   │
│  │  1. Build Image    2. Push to Registry    3. Sign with Cosign       │   │
│  │                                                                      │   │
│  │  ┌──────────┐      ┌──────────┐          ┌──────────┐              │   │
│  │  │ Dockerfile│ ──► │  Image   │ ──────►  │  Cosign  │              │   │
│  │  │          │      │ Registry │          │  Sign    │              │   │
│  │  └──────────┘      └──────────┘          └────┬─────┘              │   │
│  │                                               │                     │   │
│  │                                               ▼                     │   │
│  │                                          Signature                  │   │
│  │                                          stored in                  │   │
│  │                                          Registry                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                       DEPLOY PHASE                                   │   │
│  │                                                                      │   │
│  │  4. Deploy Request    5. Kyverno Verifies    6. Admit/Reject        │   │
│  │                                                                      │   │
│  │  ┌──────────┐      ┌──────────────┐       ┌──────────┐             │   │
│  │  │ kubectl  │ ──► │   Kyverno    │ ──►   │ Kubernetes│             │   │
│  │  │ apply    │      │ Admission    │       │  API      │             │   │
│  │  └──────────┘      │              │       └──────────┘             │   │
│  │                    │ • Fetch sig  │                                 │   │
│  │                    │ • Verify key │       ✅ Signed → Admit         │   │
│  │                    │ • Check Rekor│       ❌ Unsigned → Reject      │   │
│  │                    └──────────────┘                                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Prérequis

```bash
# Installer Cosign
# Linux
curl -sSL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 -o /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign

# Mac
brew install cosign

# Vérifier
cosign version
```

## Partie 1: Signature avec clé locale

### 1.1 Générer une paire de clés

```bash
# Créer le répertoire
mkdir -p ~/.cosign

# Générer la paire de clés
cosign generate-key-pair

# Résultat:
# - cosign.key (clé privée - GARDER SECRÈTE)
# - cosign.pub (clé publique - à distribuer)
```

### 1.2 Signer une image

```bash
# Exemple avec une image custom
IMAGE="ghcr.io/z3rox-lab/rag-api:v1.0.0"

# Signer
cosign sign --key cosign.key $IMAGE

# Vérifier la signature
cosign verify --key cosign.pub $IMAGE
```

### 1.3 Voir la signature

```bash
# Lister les signatures
cosign tree $IMAGE

# Résultat:
# 📦 ghcr.io/z3rox-lab/rag-api:v1.0.0
# └── 🔐 Signatures
#     └── sha256:abc123...
```

## Partie 2: Signature Keyless (Sigstore)

Plus simple, utilise OIDC (GitHub, Google, Microsoft).

### 2.1 Signer avec OIDC

```bash
# Signer (ouvre un navigateur pour authentification)
COSIGN_EXPERIMENTAL=1 cosign sign $IMAGE

# Ou spécifier le provider
cosign sign --oidc-issuer https://token.actions.githubusercontent.com $IMAGE
```

### 2.2 Vérifier

```bash
# Vérifier avec l'identité du signataire
cosign verify \
  --certificate-identity "user@example.com" \
  --certificate-oidc-issuer "https://accounts.google.com" \
  $IMAGE
```

## Partie 3: Intégration CI/CD (GitHub Actions)

### 3.1 Workflow de build et signature

```yaml
# .github/workflows/build-sign.yaml
name: Build and Sign Image

on:
  push:
    tags:
      - 'v*'

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-sign:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write  # Required for keyless signing
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Build and Push
        id: build
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.ref_name }}
      
      - name: Install Cosign
        uses: sigstore/cosign-installer@v3
      
      - name: Sign Image (Keyless)
        env:
          COSIGN_EXPERIMENTAL: "true"
        run: |
          cosign sign --yes \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}
```

### 3.2 Workflow avec clé secrète

```yaml
      - name: Sign Image (with key)
        env:
          COSIGN_KEY: ${{ secrets.COSIGN_PRIVATE_KEY }}
          COSIGN_PASSWORD: ${{ secrets.COSIGN_PASSWORD }}
        run: |
          echo "$COSIGN_KEY" > cosign.key
          cosign sign --key cosign.key \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}
          rm cosign.key
```

## Partie 4: Politique Kyverno

### 4.1 Vérification avec clé publique

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signatures
spec:
  validationFailureAction: Enforce
  rules:
    - name: verify-signature
      match:
        any:
        - resources:
            kinds:
              - Pod
            namespaces:
              - ai-inference
      verifyImages:
        - imageReferences:
            - "ghcr.io/z3rox-lab/*"
          attestors:
            - entries:
                - keys:
                    publicKeys: |-
                      -----BEGIN PUBLIC KEY-----
                      MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
                      -----END PUBLIC KEY-----
```

### 4.2 Vérification Keyless (GitHub Actions)

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-github-signatures
spec:
  validationFailureAction: Enforce
  rules:
    - name: verify-github-workflow
      match:
        any:
        - resources:
            kinds:
              - Pod
            namespaces:
              - ai-inference
      verifyImages:
        - imageReferences:
            - "ghcr.io/z3rox-lab/*"
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/Z3ROX-lab/ai-security-platform/.github/workflows/*"
                    issuer: "https://token.actions.githubusercontent.com"
                    rekor:
                      url: https://rekor.sigstore.dev
```

## Partie 5: Démo complète

### 5.1 Setup initial

```bash
# 1. Générer les clés
cd ~/work/ai-security-platform
mkdir -p .cosign
cd .cosign
cosign generate-key-pair

# 2. Stocker la clé publique dans un ConfigMap
kubectl create configmap cosign-public-key \
  --from-file=cosign.pub=cosign.pub \
  -n kyverno

# 3. Ajouter cosign.pub au repo (PAS la clé privée!)
cp cosign.pub ../
cd ..
echo "cosign.key" >> .gitignore
git add cosign.pub .gitignore
git commit -m "chore: add cosign public key"
```

### 5.2 Test - Image non signée (BLOQUÉE)

```bash
# Créer un pod avec une image non signée
kubectl run test-unsigned \
  --image=ghcr.io/z3rox-lab/test:unsigned \
  -n ai-inference --dry-run=server

# Résultat attendu (si policy en Enforce):
# Error: admission webhook denied the request: 
# image signature verification failed
```

### 5.3 Test - Image signée (ACCEPTÉE)

```bash
# 1. Build et push une image de test
docker build -t ghcr.io/z3rox-lab/test:signed .
docker push ghcr.io/z3rox-lab/test:signed

# 2. Signer
cosign sign --key .cosign/cosign.key ghcr.io/z3rox-lab/test:signed

# 3. Vérifier
cosign verify --key .cosign/cosign.pub ghcr.io/z3rox-lab/test:signed

# 4. Déployer
kubectl run test-signed \
  --image=ghcr.io/z3rox-lab/test:signed \
  -n ai-inference

# Résultat: Pod créé ✅
```

### 5.4 Vérifier les Policy Reports

```bash
# Voir les violations
kubectl get policyreport -A

# Détails
kubectl describe policyreport -n ai-inference
```

## Partie 6: Attestations SBOM/Vuln

Cosign peut aussi attacher des attestations (SBOM, scan de vulns).

### 6.1 Attacher un SBOM

```bash
# Générer SBOM avec Syft
syft ghcr.io/z3rox-lab/rag-api:v1.0.0 -o spdx-json > sbom.json

# Attacher comme attestation
cosign attest --key cosign.key \
  --predicate sbom.json \
  --type spdxjson \
  ghcr.io/z3rox-lab/rag-api:v1.0.0
```

### 6.2 Attacher un rapport de vulnérabilités

```bash
# Scanner avec Trivy
trivy image ghcr.io/z3rox-lab/rag-api:v1.0.0 --format cosign-vuln > vuln.json

# Attacher
cosign attest --key cosign.key \
  --predicate vuln.json \
  --type vuln \
  ghcr.io/z3rox-lab/rag-api:v1.0.0
```

### 6.3 Policy Kyverno pour vérifier les attestations

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-sbom-attestation
spec:
  validationFailureAction: Audit
  rules:
    - name: check-sbom
      match:
        any:
        - resources:
            kinds:
              - Pod
            namespaces:
              - ai-inference
      verifyImages:
        - imageReferences:
            - "ghcr.io/z3rox-lab/*"
          attestations:
            - predicateType: https://spdx.dev/Document
              attestors:
                - entries:
                    - keys:
                        publicKeys: |-
                          -----BEGIN PUBLIC KEY-----
                          ...
                          -----END PUBLIC KEY-----
```

## Troubleshooting

| Problème | Cause | Solution |
|----------|-------|----------|
| `signature not found` | Image non signée | `cosign sign --key ... $IMAGE` |
| `key verification failed` | Mauvaise clé publique | Vérifier cosign.pub |
| `OIDC token error` | Token expiré | Re-authentifier |
| `Rekor lookup failed` | Réseau | Vérifier accès à rekor.sigstore.dev |

### Debug Kyverno

```bash
# Logs Kyverno
kubectl logs -n kyverno -l app.kubernetes.io/component=admission-controller -f

# Policy Reports
kubectl get clusterpolicyreport -o wide
```

## OWASP LLM05 Coverage

| Menace | Mitigation |
|--------|------------|
| Images compromises | Signature obligatoire |
| Man-in-the-middle | Vérification digest |
| Rollback attack | Rekor transparency log |
| Compromission CI/CD | Keyless avec OIDC identity |

## Références

- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)
- [Kyverno Image Verification](https://kyverno.io/docs/writing-policies/verify-images/)
- [Sigstore](https://www.sigstore.dev/)
- [SLSA Framework](https://slsa.dev/)

---

**Date:** 2026-02-03
**Author:** Z3ROX - AI Security Platform
**Version:** 1.0.0
