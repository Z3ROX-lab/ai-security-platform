# AI Security Platform - Architecture

```mermaid
flowchart TB
    USER["👤 User"] --> TRAEFIK

    subgraph CLUSTER["K3d Cluster"]
        
        subgraph INGRESS["Ingress"]
            TRAEFIK["Traefik"]
        end

        subgraph APPS["Applications"]
            WEBUI["Open WebUI"]
            PIPELINES["Pipelines"]
            KEYCLOAK["Keycloak"]
            OLLAMA["Ollama"]
            QDRANT["Qdrant"]
            RAGAPI["RAG API"]
            GUARDRAILS["Guardrails API"]
        end

        subgraph SECURITY["AI Security"]
            LLMGUARD["LLM Guard"]
            SECRETS["Sealed Secrets"]
            NETPOL["NetworkPolicies"]
            PSS["Pod Security Standards"]
        end

        subgraph OBSERVABILITY["Observability"]
            PROMETHEUS["Prometheus"]
            GRAFANA["Grafana"]
            ALERTMANAGER["Alertmanager"]
            LOKI["Loki"]
            PROMTAIL["Promtail"]
            FALCO["Falco"]
            KYVERNO["Kyverno"]
        end

        subgraph STORAGE["Storage"]
            POSTGRESQL[("PostgreSQL")]
            SEAWEEDFS[("SeaweedFS S3")]
        end

        subgraph PLATFORM["Platform"]
            ARGOCD["ArgoCD"]
            CERTMANAGER["cert-manager"]
        end

    end

    GITHUB["GitHub"] <--> ARGOCD

    TRAEFIK --> WEBUI
    TRAEFIK --> KEYCLOAK
    TRAEFIK --> GRAFANA
    TRAEFIK --> RAGAPI
    TRAEFIK --> GUARDRAILS
    
    WEBUI --> PIPELINES
    PIPELINES --> GUARDRAILS
    PIPELINES --> OLLAMA
    WEBUI --> KEYCLOAK
    
    RAGAPI --> GUARDRAILS
    RAGAPI --> QDRANT
    RAGAPI --> OLLAMA
    
    GUARDRAILS --> LLMGUARD
    
    PROMETHEUS --> GRAFANA
    LOKI --> GRAFANA
    PROMTAIL --> LOKI
    
    KEYCLOAK --> POSTGRESQL
    WEBUI --> POSTGRESQL
```

---

## Namespaces

| Namespace | Components |
|-----------|------------|
| ai-apps | Open WebUI, Pipelines |
| ai-inference | Ollama, Qdrant, RAG API, Guardrails |
| auth | Keycloak |
| storage | PostgreSQL, SeaweedFS |
| observability | Prometheus, Grafana, Alertmanager, Loki, Promtail |
| falco | Falco |
| kyverno | Kyverno |
| argocd | ArgoCD |
| cert-manager | cert-manager |

---

## OWASP LLM Top 10

| Risk | Status | Mitigation |
|------|:------:|------------|
| LLM01 Prompt Injection | ✅ | LLM Guard |
| LLM02 Insecure Output | ✅ | LLM Guard Toxicity |
| LLM03 Training Data Poisoning | ✅ | Model pinning |
| LLM04 Model DoS | ✅ | Kyverno resource limits |
| LLM05 Supply Chain | ✅ | Kyverno + Cosign |
| LLM06 PII Disclosure | ✅ | LLM Guard |
| LLM07 Insecure Plugin | ✅ | N/A |
| LLM08 Excessive Agency | 🔲 | Planned |
| LLM09 Overreliance | 🔲 | Planned |
| LLM10 Model Theft | ✅ | Falco + NetworkPolicies |

---

## URLs

| Service | URL |
|---------|-----|
| ArgoCD | https://argocd.ai-platform.localhost |
| Keycloak | https://auth.ai-platform.localhost |
| Open WebUI | https://chat.ai-platform.localhost |
| Grafana | https://grafana.ai-platform.localhost |
| Prometheus | https://prometheus.ai-platform.localhost |
| RAG API | https://rag.ai-platform.localhost |
| Guardrails | https://guardrails.ai-platform.localhost |
