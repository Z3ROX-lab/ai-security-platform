# ADR-011: LLM Application Framework - LangChain

## Status
**Accepted**

## Date
2025-01-27

## Context

L'AI Security Platform nécessite un framework pour construire des applications LLM avec les fonctionnalités suivantes :
- Connexion à différents LLMs (Ollama local, potentiellement cloud)
- RAG (Retrieval Augmented Generation) pour interroger des documents
- Mémoire conversationnelle
- Agents avec outils
- Intégration avec les vector databases (Qdrant)

Plusieurs frameworks sont disponibles sur le marché pour répondre à ces besoins.

## Options évaluées

### Option A: LangChain

| Aspect | Évaluation |
|--------|------------|
| **Maturité** | ⭐⭐⭐⭐⭐ Framework le plus mature (2022), 90k+ GitHub stars |
| **Communauté** | ⭐⭐⭐⭐⭐ Très large, beaucoup de ressources |
| **Flexibilité** | ⭐⭐⭐⭐⭐ Supporte tous les use cases LLM |
| **Providers** | ⭐⭐⭐⭐⭐ Ollama, OpenAI, Anthropic, Mistral, etc. |
| **Vector DBs** | ⭐⭐⭐⭐⭐ Qdrant, Pinecone, ChromaDB, Weaviate |
| **RAG** | ⭐⭐⭐⭐ Bon support, mais LlamaIndex est meilleur |
| **Complexité** | ⭐⭐⭐ Abstractions parfois lourdes |
| **Documentation** | ⭐⭐⭐⭐ Complète mais parfois confuse |

**Avantages:**
- Standard de l'industrie
- Utilisé par Open WebUI (notre interface chat)
- Écosystème riche (LangSmith pour monitoring, LangServe pour API)
- Support LCEL (LangChain Expression Language) pour syntaxe moderne
- Intégration native avec Ollama

**Inconvénients:**
- Abstractions parfois trop lourdes pour des cas simples
- API qui change fréquemment
- Courbe d'apprentissage

### Option B: LlamaIndex

| Aspect | Évaluation |
|--------|------------|
| **Maturité** | ⭐⭐⭐⭐ Mature, 30k+ GitHub stars |
| **Communauté** | ⭐⭐⭐⭐ Grande communauté |
| **Flexibilité** | ⭐⭐⭐ Focalisé sur RAG/data |
| **RAG** | ⭐⭐⭐⭐⭐ Meilleur framework pour RAG |
| **Agents** | ⭐⭐⭐ Support limité comparé à LangChain |

**Avantages:**
- Excellent pour RAG et indexation de documents
- Plus simple que LangChain pour les cas data-centric
- Meilleure gestion des index et chunks

**Inconvénients:**
- Moins flexible pour les agents et workflows complexes
- Pas utilisé par Open WebUI
- Moins de providers supportés

### Option C: Haystack (deepset)

| Aspect | Évaluation |
|--------|------------|
| **Maturité** | ⭐⭐⭐⭐ Production-ready |
| **Enterprise** | ⭐⭐⭐⭐⭐ Conçu pour l'entreprise |
| **Flexibilité** | ⭐⭐⭐ Modulaire mais moins flexible |

**Avantages:**
- Conçu pour la production enterprise
- Pipelines modulaires et testables
- Bon pour search/QA

**Inconvénients:**
- Moins de providers LLM
- Communauté plus petite
- Pas utilisé par Open WebUI

### Option D: Semantic Kernel (Microsoft)

| Aspect | Évaluation |
|--------|------------|
| **Maturité** | ⭐⭐⭐ Relativement nouveau |
| **Enterprise** | ⭐⭐⭐⭐ Backing Microsoft |
| **Langages** | ⭐⭐⭐⭐⭐ C#, Python, Java |

**Avantages:**
- Support Microsoft (Azure OpenAI)
- Multi-langage
- Bonne intégration .NET

**Inconvénients:**
- Moins mature en Python
- Écosystème plus petit
- Focus sur l'écosystème Microsoft

### Option E: Direct API Calls

| Aspect | Évaluation |
|--------|------------|
| **Simplicité** | ⭐⭐⭐⭐⭐ Le plus simple |
| **Flexibilité** | ⭐⭐⭐⭐⭐ Contrôle total |
| **Maintenance** | ⭐⭐ Tout à développer soi-même |

**Avantages:**
- Pas de dépendance externe
- Contrôle total
- Léger

**Inconvénients:**
- Tout à implémenter (memory, RAG, agents)
- Pas de réutilisation
- Maintenance lourde

## Matrice de décision

| Critère | Poids | LangChain | LlamaIndex | Haystack | Semantic Kernel | Direct API |
|---------|-------|-----------|------------|----------|-----------------|------------|
| Compatibilité Open WebUI | 25% | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| Support Ollama | 20% | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| RAG capabilities | 20% | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| Agents & Tools | 15% | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| Communauté & Support | 10% | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐ |
| Simplicité | 10% | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Score pondéré** | | **4.35** | 3.65 | 3.15 | 2.95 | 3.10 |

## Decision

**Nous adoptons LangChain comme framework principal pour les applications LLM.**

### Justification

1. **Compatibilité Open WebUI**: Open WebUI utilise déjà LangChain en interne. Utiliser le même framework assure la cohérence et facilite les extensions.

2. **Support Ollama natif**: `langchain-community` inclut des intégrations Ollama prêtes à l'emploi (LLM, Chat, Embeddings).

3. **Écosystème complet**: LangChain couvre tous nos besoins actuels et futurs :
   - RAG pour Phase 6 (Qdrant)
   - Agents pour Phase 7 (Guardrails)
   - Memory pour conversations
   - Tools pour extensions

4. **Standard de l'industrie**: Facilite le recrutement et l'onboarding.

5. **LlamaIndex en complément**: Pour les cas RAG avancés, LlamaIndex peut être utilisé en complément (ils sont compatibles).

## Architecture d'intégration

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    LANGCHAIN INTEGRATION                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                      APPLICATIONS                                │   │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐       │   │
│  │  │  Open WebUI   │  │ Custom Apps   │  │   Pipelines   │       │   │
│  │  │  (Chat UI)    │  │  (Future)     │  │   (Future)    │       │   │
│  │  └───────────────┘  └───────────────┘  └───────────────┘       │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                  │                                      │
│                                  ▼                                      │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                       LANGCHAIN                                  │   │
│  │                                                                  │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │   │
│  │  │   Chains    │  │   Agents    │  │   Memory    │             │   │
│  │  │             │  │   + Tools   │  │             │             │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘             │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │   │
│  │  │  Prompts    │  │  Loaders    │  │ Retrievers  │             │   │
│  │  │  Templates  │  │  (Docs)     │  │   (RAG)     │             │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘             │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                  │                                      │
│          ┌───────────────────────┼───────────────────────┐             │
│          ▼                       ▼                       ▼             │
│  ┌───────────────┐      ┌───────────────┐      ┌───────────────┐      │
│  │    Ollama     │      │    Qdrant     │      │  PostgreSQL   │      │
│  │   (Mistral)   │      │  (Vectors)    │      │  (Memory)     │      │
│  │               │      │               │      │               │      │
│  │ ai-inference  │      │   ai-apps     │      │   storage     │      │
│  └───────────────┘      └───────────────┘      └───────────────┘      │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Packages à utiliser

```python
# Core
langchain>=0.1.0
langchain-community>=0.0.20
langchain-core>=0.1.0

# Providers
langchain-ollama>=0.0.1       # Pour Ollama (local)

# Vector Stores
langchain-qdrant>=0.0.1       # Pour Qdrant (Phase 6)

# Document Processing
pypdf>=3.0.0                  # PDF loading
unstructured>=0.10.0          # Multi-format loading
```

## Considérations de sécurité

| Risque | Mitigation |
|--------|------------|
| Prompt Injection | NeMo Guardrails (Phase 7) |
| Data Leakage (RAG) | RBAC sur documents, filtrage par user |
| Code Execution (Agents) | Sandbox, whitelist des tools |
| Sensitive Data | LLM local (Ollama), pas de cloud |

## Conséquences

### Positives
- Cohérence avec Open WebUI
- Écosystème riche et mature
- Flexibilité pour les évolutions futures
- Grande communauté pour le support

### Négatives
- Complexité additionnelle vs API directe
- Dépendance sur un framework externe
- API qui évolue rapidement (breaking changes possibles)

### Risques
| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| Breaking changes API | Moyenne | Moyen | Pin versions, tests |
| Framework abandonné | Faible | Haut | Monitoring, plan B (LlamaIndex) |
| Performance overhead | Faible | Faible | Profiling, optimisation si besoin |

## Références

- [LangChain Documentation](https://python.langchain.com/docs/)
- [LangChain GitHub](https://github.com/langchain-ai/langchain)
- [Open WebUI GitHub](https://github.com/open-webui/open-webui)
- [LlamaIndex vs LangChain](https://docs.llamaindex.ai/en/stable/community/integrations/using_with_langchain/)
- [ADR-010: AI Chat Interface (Open WebUI)](./ADR-010-ai-chat-interface.md)
