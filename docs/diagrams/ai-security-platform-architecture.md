# AI Security Platform - Architecture

```mermaid
flowchart TB
    subgraph EXTERNAL["👤 External"]
        USER[User / Browser]
    end

    subgraph CLUSTER["☸️ K3d Cluster (32GB RAM)"]
        
        subgraph INGRESS["🌐 Ingress Layer"]
            TRAEFIK[Traefik<br/>Reverse Proxy]
        end

        subgraph APPS["🚀 Applications"]
            direction LR
            WEBUI[Open WebUI<br/>Chat Interface]
            PIPELINES[Pipelines<br/>LLM Guard Filter]
            KEYCLOAK[Keycloak<br/>IAM / SSO]
            OLLAMA[Ollama<br/>Mistral 7B]
            QDRANT[Qdrant<br/>Vector DB]
            RAGAPI[RAG API<br/>FastAPI]
            GUARDRAILS[Guardrails API<br/>LLM Guard]
        end

        subgraph SECURITY["🛡️ AI Security - OWASP LLM Top 10"]
            direction LR
            LLM01[LLM01<br/>Prompt Injection<br/>✅ LLM Guard]
            LLM02[LLM02<br/>Insecure Output<br/>✅ Toxicity Filter]
            LLM04[LLM04<br/>Model DoS<br/>✅ Kyverno]
            LLM05[LLM05<br/>Supply Chain<br/>✅ Cosign]
            LLM06[LLM06<br/>PII Disclosure<br/>✅ LLM Guard]
            LLM10[LLM10<br/>Model Theft<br/>✅ Falco]
            SECRETS[Sealed Secrets]
            NETPOL[NetworkPolicies]
        end

        subgraph OBSERVABILITY["📊 Observability & Monitoring"]
            direction LR
            PROMETHEUS[Prometheus<br/>Metrics]
            GRAFANA[Grafana<br/>Dashboards]
            ALERTMANAGER[Alertmanager<br/>Alerts]
            LOKI[Loki<br/>Logs]
            PROMTAIL[Promtail<br/>Log Collector]
            FALCO[Falco<br/>Runtime Security]
            KYVERNO[Kyverno<br/>Policy Engine<br/>6 Policies]
        end

        subgraph STORAGE["💾 Data & Storage"]
            direction LR
            POSTGRESQL[(PostgreSQL<br/>CNPG)]
            SEAWEEDFS[(SeaweedFS<br/>S3)]
            LOCALPATH[(local-path<br/>PVCs)]
        end

        subgraph PLATFORM["⚙️ Platform"]
            direction LR
            ARGOCD[ArgoCD<br/>GitOps]
            CERTMANAGER[cert-manager<br/>TLS]
            TERRAFORM[Terraform<br/>IaC]
        end

    end

    subgraph GITHUB["🐙 GitHub"]
        REPO[ai-security-platform<br/>Source of Truth]
    end

    %% Connections
    USER --> TRAEFIK
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
    
    GUARDRAILS --> LLM01
    GUARDRAILS --> LLM02
    GUARDRAILS --> LLM06
    
    KYVERNO --> LLM04
    KYVERNO --> LLM05
    FALCO --> LLM10
    
    PROMETHEUS --> GRAFANA
    LOKI --> GRAFANA
    ALERTMANAGER --> GRAFANA
    PROMTAIL --> LOKI
    
    KEYCLOAK --> POSTGRESQL
    WEBUI --> POSTGRESQL
    
    ARGOCD --> REPO
    REPO --> ARGOCD

    %% Styling
    classDef ingress fill:#e1f5fe,stroke:#0288d1,stroke-width:2px
    classDef apps fill:#e8f5e9,stroke:#4caf50,stroke-width:2px
    classDef security fill:#ffebee,stroke:#f44336,stroke-width:2px
    classDef observability fill:#fff3e0,stroke:#ff9800,stroke-width:2px
    classDef storage fill:#e3f2fd,stroke:#2196f3,stroke-width:2px
    classDef platform fill:#f3e5f5,stroke:#9c27b0,stroke-width:2px
    
    class TRAEFIK ingress
    class WEBUI,PIPELINES,KEYCLOAK,OLLAMA,QDRANT,RAGAPI,GUARDRAILS apps
    class LLM01,LLM02,LLM04,LLM05,LLM06,LLM10,SECRETS,NETPOL security
    class PROMETHEUS,GRAFANA,ALERTMANAGER,LOKI,PROMTAIL,FALCO,KYVERNO observability
    class POSTGRESQL,SEAWEEDFS,LOCALPATH storage
    class ARGOCD,CERTMANAGER,TERRAFORM platform
```

## Components Summary

| Layer | Components | Namespace |
|-------|------------|-----------|
| **Ingress** | Traefik | kube-system |
| **Applications** | Open WebUI, Pipelines, Keycloak, Ollama, Qdrant, RAG API, Guardrails | ai-apps, ai-inference, auth |
| **Security** | LLM Guard, Sealed Secrets, NetworkPolicies, PSS | ai-inference, security |
| **Observability** | Prometheus, Grafana, Loki, Falco, Kyverno | observability, falco, kyverno |
| **Storage** | PostgreSQL (CNPG), SeaweedFS, local-path | storage |
| **Platform** | ArgoCD, cert-manager | argocd, cert-manager |

## OWASP LLM Top 10 Coverage

| Risk | Status | Mitigation |
|------|--------|------------|
| LLM01: Prompt Injection | ✅ | LLM Guard + Pipelines |
| LLM02: Insecure Output | ✅ | LLM Guard Toxicity |
| LLM03: Training Data Poisoning | ✅ | Model pinning (Ollama) |
| LLM04: Model DoS | ✅ | Kyverno resource limits |
| LLM05: Supply Chain | ✅ | Kyverno + Cosign |
| LLM06: PII Disclosure | ✅ | LLM Guard PII redaction |
| LLM07: Insecure Plugin | ✅ | N/A (no plugins) |
| LLM08: Excessive Agency | 🔲 | Planned (NeMo) |
| LLM09: Overreliance | 🔲 | Planned |
| LLM10: Model Theft | ✅ | Falco + NetworkPolicies |

## Access URLs

| Service | URL |
|---------|-----|
| ArgoCD | https://argocd.ai-platform.localhost |
| Keycloak | https://auth.ai-platform.localhost |
| Open WebUI | https://chat.ai-platform.localhost |
| Grafana | https://grafana.ai-platform.localhost |
| Prometheus | https://prometheus.ai-platform.localhost |
| RAG API | https://rag.ai-platform.localhost |
| Guardrails | https://guardrails.ai-platform.localhost |
