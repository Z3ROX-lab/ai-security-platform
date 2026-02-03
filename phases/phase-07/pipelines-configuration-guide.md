# Open WebUI Pipelines - Configuration Guide

## Overview

Ce guide documente l'intégration des Guardrails LLM Guard dans Open WebUI via le système Pipelines.

| Composant | Rôle |
|-----------|------|
| **Open WebUI** | Interface chat |
| **Pipelines** | Serveur de plugins/filtres |
| **LLM Guard Filter** | Notre pipeline custom |
| **Guardrails API** | Backend ML (scanners) |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    OPEN WEBUI + PIPELINES + GUARDRAILS                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  User Message                                                               │
│       │                                                                     │
│       ▼                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         OPEN WEBUI                                   │   │
│  │                  chat.ai-platform.localhost                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│       │                                                                     │
│       ▼                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      PIPELINES SERVER                                │   │
│  │              open-webui-pipelines.ai-apps.svc:9099                   │   │
│  │                                                                      │   │
│  │  ┌───────────────────────────────────────────────────────────────┐  │   │
│  │  │              LLM GUARD FILTER PIPELINE                         │  │   │
│  │  │                                                                │  │   │
│  │  │  inlet()  ─────────────────────────────────────────────────►  │  │   │
│  │  │     │                                                          │  │   │
│  │  │     │  POST /scan/input                                        │  │   │
│  │  │     │     │                                                    │  │   │
│  │  │     │     ▼                                                    │  │   │
│  │  │     │  ┌─────────────────────────────────────────────────┐    │  │   │
│  │  │     │  │           GUARDRAILS API                        │    │  │   │
│  │  │     │  │   guardrails-api.ai-inference.svc:8000          │    │  │   │
│  │  │     │  │                                                 │    │  │   │
│  │  │     │  │   • PromptInjection Scanner                     │    │  │   │
│  │  │     │  │   • Toxicity Scanner                            │    │  │   │
│  │  │     │  │   • Secrets Scanner                             │    │  │   │
│  │  │     │  └─────────────────────────────────────────────────┘    │  │   │
│  │  │     │                                                          │  │   │
│  │  │     ▼                                                          │  │   │
│  │  │  BLOCKED? ──► Yes ──► Return Error 🛡️                         │  │   │
│  │  │     │                                                          │  │   │
│  │  │     No                                                         │  │   │
│  │  │     │                                                          │  │   │
│  │  │     ▼                                                          │  │   │
│  │  │  Continue to LLM (Ollama)                                      │  │   │
│  │  │     │                                                          │  │   │
│  │  │     ▼                                                          │  │   │
│  │  │  outlet() ◄────────────────────────────────────────────────   │  │   │
│  │  │     │                                                          │  │   │
│  │  │     │  POST /scan/output                                       │  │   │
│  │  │     │                                                          │  │   │
│  │  │     ▼                                                          │  │   │
│  │  │  PII Redacted? ──► <PERSON>, <EMAIL>, <SSN>                   │  │   │
│  │  │     │                                                          │  │   │
│  │  └─────┼──────────────────────────────────────────────────────────┘  │   │
│  │        │                                                              │   │
│  └────────┼──────────────────────────────────────────────────────────────┘   │
│           │                                                                   │
│           ▼                                                                   │
│     Safe Response to User                                                    │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Prérequis

| Composant | Status |
|-----------|--------|
| Guardrails API déployé | `kubectl get pods -n ai-inference -l app=guardrails-api` |
| Open WebUI déployé | `kubectl get pods -n ai-apps -l app.kubernetes.io/instance=open-webui` |
| Pipelines server | `kubectl get pods -n ai-apps -l app.kubernetes.io/component=open-webui-pipelines` |

## Configuration

### 1. Vérifier la connexion Pipelines

```bash
# Test depuis Open WebUI
kubectl exec -it -n ai-apps open-webui-0 -- curl -s \
  -H "Authorization: Bearer 0p3n-w3bu!" \
  http://open-webui-pipelines.ai-apps.svc.cluster.local:9099/
```

Résultat attendu : `{"status":true}`

### 2. Configurer la connexion dans Open WebUI

1. Aller sur https://chat.ai-platform.localhost
2. Se connecter via Keycloak
3. **Admin Panel** → **Settings** → **Connections**
4. Dans "Manage OpenAI API Connections", vérifier :
   - URL : `http://open-webui-pipelines.ai-apps.svc.cluster.local:9099`
   - API Key : `0p3n-w3bu!`
5. **Save**

### 3. Uploader le Pipeline

1. **Admin Panel** → **Settings** → **Pipelines**
2. Cliquer "Upload Pipeline"
3. Sélectionner `llmguard_filter_pipeline.py`
4. **Save**

### 4. Vérifier le chargement

```bash
kubectl logs -n ai-apps deployment/open-webui-pipelines --tail=20
```

Résultat attendu :
```
Loaded module: llmguard_filter_pipeline
[LLM Guard] Started - URL: http://guardrails-api.ai-inference.svc.cluster.local:8000
```

## Pipeline Code

Le fichier `llmguard_filter_pipeline.py` :

```python
"""
title: LLM Guard Filter Pipeline
author: Z3ROX
version: 2.0
license: MIT
description: Calls Guardrails API for prompt injection detection and PII filtering
"""

from typing import List, Optional
from pydantic import BaseModel
import requests

class Pipeline:
    class Valves(BaseModel):
        pipelines: List[str] = ["*"]  # Apply to all models
        priority: int = 0
        guardrails_url: str = "http://guardrails-api.ai-inference.svc.cluster.local:8000"
        enabled: bool = True
        block_on_detection: bool = True

    def __init__(self):
        self.type = "filter"
        self.id = "llmguard_filter"
        self.name = "LLM Guard Security Filter"
        self.valves = self.Valves()

    async def inlet(self, body: dict, user: Optional[dict] = None) -> dict:
        """Scan input for prompt injection before LLM"""
        # ... calls POST /scan/input
        
    async def outlet(self, body: dict, user: Optional[dict] = None) -> dict:
        """Scan output for PII after LLM"""
        # ... calls POST /scan/output
```

## Configuration des Valves

Les "Valves" sont les paramètres configurables du pipeline :

| Valve | Default | Description |
|-------|---------|-------------|
| `pipelines` | `["*"]` | Modèles ciblés (* = tous) |
| `priority` | `0` | Priorité d'exécution |
| `guardrails_url` | `http://guardrails-api...` | URL du backend |
| `enabled` | `true` | Activer/désactiver |
| `block_on_detection` | `true` | Bloquer ou juste logger |

Pour modifier les valves :
1. **Admin Panel** → **Settings** → **Pipelines**
2. Cliquer sur le pipeline "LLM Guard Security Filter"
3. Modifier les paramètres
4. **Save**

## Persistence

| Élément | Stockage | Persisté |
|---------|----------|----------|
| Pipeline code | PVC `open-webui-pipelines` (2Gi) | ✅ Oui |
| Valves config | PVC `open-webui-pipelines` | ✅ Oui |
| Logs | stdout | ❌ Non |

```bash
# Vérifier le stockage
kubectl get pvc -n ai-apps | grep pipelines

# Voir les fichiers persistés
kubectl exec -it -n ai-apps deployment/open-webui-pipelines -- \
  ls -la /app/pipelines/
```

## Monitoring

### Logs en temps réel

```bash
kubectl logs -n ai-apps deployment/open-webui-pipelines -f
```

### Logs avec filtrage LLM Guard

```bash
kubectl logs -n ai-apps deployment/open-webui-pipelines -f | grep "LLM Guard"
```

### Exemple de logs

```
[LLM Guard] User: admin, Valid: false, Risk: 1.0
[LLM Guard] User: john, Valid: true, Risk: -1.0
[LLM Guard] PII redacted from response
```

## Troubleshooting

| Problème | Cause | Solution |
|----------|-------|----------|
| "Pipelines Not Detected" | API Key manquante | Ajouter `0p3n-w3bu!` dans Connections |
| Pipeline non chargé | Erreur de syntaxe | Vérifier logs pipelines |
| Guardrails API unreachable | Service down | `kubectl get pods -n ai-inference` |
| Messages non bloqués | `enabled: false` | Vérifier les Valves |

### Test de connectivité

```bash
# Pipelines → Guardrails
kubectl exec -it -n ai-apps deployment/open-webui-pipelines -- \
  curl -s http://guardrails-api.ai-inference.svc.cluster.local:8000/health
```

## Sécurité

| Aspect | Implémentation |
|--------|----------------|
| API Key Pipelines | `0p3n-w3bu!` (changer en prod) |
| Network | ClusterIP only (pas d'ingress) |
| Code execution | Warning : ne pas charger de pipelines non trusted |

## Références

- [Open WebUI Pipelines Docs](https://docs.openwebui.com/features/pipelines/)
- [Pipelines GitHub](https://github.com/open-webui/pipelines)
- [LLM Guard Examples](https://github.com/open-webui/pipelines/tree/main/examples/filters)

---

**Date:** 2026-02-03
**Author:** Z3ROX - AI Security Platform
**Version:** 1.0.0
