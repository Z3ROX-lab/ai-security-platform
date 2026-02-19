# Langfuse LLM Observability Architecture

## Status
**Deferred** - February 2026 (RAM constraints)

## Overview

Langfuse is an open-source LLM observability platform that provides:
- Trace collection for LLM interactions
- Prompt management
- Evaluation and scoring
- Cost tracking
- User analytics

## Architecture

### Langfuse v3 Components

```
┌─────────────────────────────────────────────────────────────────┐
│                         LANGFUSE v3                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ÉTAPE 1: INIT JOBS (one-time)                                 │
│  ─────────────────────────────                                  │
│                                                                 │
│  ┌──────────────────┐          ┌──────────────────┐            │
│  │   langfuse-db    │          │   langfuse-s3    │            │
│  │      init        │          │      init        │            │
│  └────────┬─────────┘          └────────┬─────────┘            │
│           │                             │                       │
│           │ CREATE DATABASE             │ CREATE BUCKET         │
│           │ CREATE USER                 │ s3://langfuse         │
│           ▼                             ▼                       │
│  ┌──────────────────┐          ┌──────────────────┐            │
│  │   PostgreSQL     │          │   SeaweedFS      │            │
│  │   (CNPG)         │          │   (S3)           │            │
│  │                  │          │                  │            │
│  │  DB: langfuse    │          │  Bucket:langfuse │            │
│  │  User: langfuse  │          │                  │            │
│  └──────────────────┘          └──────────────────┘            │
│           │                             │                       │
│           └──────────┬──────────────────┘                       │
│                      │                                          │
│  ÉTAPE 2: LANGFUSE   │  (après init jobs)                      │
│  ────────────────    │                                          │
│                      ▼                                          │
│           ┌──────────────────┐                                  │
│           │     LANGFUSE     │                                  │
│           │   ┌──────────┐   │                                  │
│           │   │   Web    │   │◄─── UI + API                    │
│           │   └──────────┘   │                                  │
│           │   ┌──────────┐   │                                  │
│           │   │  Worker  │   │◄─── Background jobs             │
│           │   └──────────┘   │                                  │
│           └────────┬─────────┘                                  │
│                    │                                            │
│         ┌──────────┼──────────┬──────────────┐                 │
│         │          │          │              │                  │
│         ▼          ▼          ▼              ▼                  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│  │PostgreSQL│ │SeaweedFS │ │ClickHouse│ │  Redis   │          │
│  │(existant)│ │(existant)│ │ (nouveau)│ │(nouveau) │          │
│  │          │ │          │ │          │ │          │          │
│  │  Users   │ │ Artifacts│ │  Traces  │ │  Cache   │          │
│  │  Config  │ │  Media   │ │ Analytics│ │  Queue   │          │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘          │
│      ON A DÉJÀ ✅           DÉPLOYÉS PAR LE CHART              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Backend Requirements

| Backend | Role | Source | RAM |
|---------|------|--------|-----|
| **PostgreSQL** | Users, config, projects | ✅ Existing (CNPG) | 0 (reused) |
| **S3 (SeaweedFS)** | Artifacts, media files | ✅ Existing | 0 (reused) |
| **ClickHouse** | Traces, analytics (OLAP) | 🆕 Langfuse chart | ~1.5Gi |
| **Redis** | Cache, job queue | 🆕 Langfuse chart | ~256Mi |
| **Langfuse Web** | UI + API | 🆕 Langfuse chart | ~512Mi |
| **Langfuse Worker** | Background processing | 🆕 Langfuse chart | ~512Mi |
| **Total new** | | | **~3.5Gi** |

## Why Langfuse Was Deferred

### Resource Constraints

```
Current RAM Usage:    15Gi / 16Gi
Langfuse Addition:    ~3.5Gi
───────────────────────────────
Would Require:        ~18.5Gi (exceeds available)
```

### Existing Observability Coverage

| Feature | Current Solution | Langfuse Would Add |
|---------|------------------|-------------------|
| Logs | Loki + Grafana | LLM-specific views |
| Metrics | Prometheus | Token/cost tracking |
| Tracing | - | ✅ LLM traces |
| Prompt Management | - | ✅ Version control |
| Evaluations | - | ✅ Scoring system |

## Deployment Files (Prepared)

### Directory Structure

```
argocd/applications/observability/
├── langfuse/
│   ├── application.yaml
│   └── values.yaml
└── langfuse-init/
    ├── application.yaml
    └── manifests/
        └── init-jobs.yaml
```

### Init Jobs

The init jobs prepare existing backends:

```yaml
# langfuse-init/manifests/init-jobs.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: langfuse-db-init
  namespace: storage
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: false
      containers:
        - name: init-db
          image: postgres:15
          securityContext:
            privileged: false
            allowPrivilegeEscalation: false
          command:
            - /bin/bash
            - -c
            - |
              PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U postgres -c "
                CREATE DATABASE langfuse;
                CREATE USER langfuse WITH PASSWORD '$LANGFUSE_DB_PASSWORD';
                GRANT ALL PRIVILEGES ON DATABASE langfuse TO langfuse;
              "
          env:
            - name: POSTGRES_HOST
              value: "postgresql-rw.storage.svc.cluster.local"
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgresql-cluster-superuser
                  key: password
---
apiVersion: batch/v1
kind: Job
metadata:
  name: langfuse-s3-init
  namespace: storage
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: false
      containers:
        - name: init-s3
          image: amazon/aws-cli:2.13.0
          securityContext:
            privileged: false
            allowPrivilegeEscalation: false
          command:
            - /bin/bash
            - -c
            - |
              aws --endpoint-url http://seaweedfs-s3.storage.svc:8333 \
                s3 mb s3://langfuse || true
```

### Langfuse Values

```yaml
# langfuse/values.yaml
langfuse:
  ingress:
    enabled: true
    className: traefik
    hosts:
      - host: langfuse.ai-platform.localhost
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: langfuse-tls
        hosts:
          - langfuse.ai-platform.localhost

  postgresql:
    deploy: false
    host: postgresql-rw.storage.svc.cluster.local
    port: 5432
    database: langfuse
    auth:
      existingSecret: langfuse-secrets
      secretKeys:
        usernameKey: db-username
        passwordKey: db-password

  s3:
    enabled: true
    endpoint: http://seaweedfs-s3.storage.svc:8333
    bucket: langfuse
    region: us-east-1
    auth:
      existingSecret: langfuse-secrets
      secretKeys:
        accessKeyIdKey: s3-access-key
        secretAccessKeyKey: s3-secret-key

  clickhouse:
    deploy: true
    persistence:
      enabled: true
      size: 10Gi

  redis:
    deploy: true
    persistence:
      enabled: true
      size: 1Gi

  secrets:
    salt: ""  # Generate: openssl rand -hex 32
    nextAuthSecret: ""  # Generate: openssl rand -hex 32
    encryptionKey: ""  # Generate: openssl rand -hex 32
```

## Future Deployment

When resources allow (more RAM or cloud deployment):

```bash
# 1. Generate secrets
export LANGFUSE_SALT=$(openssl rand -hex 32)
export LANGFUSE_NEXTAUTH=$(openssl rand -hex 32)
export LANGFUSE_ENCRYPTION=$(openssl rand -hex 32)

# 2. Update values.yaml with secrets

# 3. Add to /etc/hosts
echo "127.0.0.1 langfuse.ai-platform.localhost" | sudo tee -a /etc/hosts

# 4. Commit and push
git add argocd/applications/observability/langfuse*
git commit -m "feat: add Langfuse LLM Observability"
git push

# 5. ArgoCD will auto-sync, or manual:
kubectl apply -f argocd/applications/observability/langfuse-init/application.yaml
kubectl apply -f argocd/applications/observability/langfuse/application.yaml
```

## Integration with AI Platform

### Open WebUI → Langfuse

```python
# pipelines/langfuse_pipeline.py
from langfuse import Langfuse

langfuse = Langfuse(
    public_key="pk-...",
    secret_key="sk-...",
    host="http://langfuse.langfuse.svc:3000"
)

def trace_llm_call(prompt, response, model, tokens):
    trace = langfuse.trace(
        name="chat-completion",
        metadata={"model": model}
    )
    trace.generation(
        name="llm-response",
        input=prompt,
        output=response,
        usage={"total_tokens": tokens}
    )
```

### Guardrails API → Langfuse

```python
# Track blocked requests
langfuse.event(
    name="guardrail-blocked",
    metadata={
        "reason": "injection_detected",
        "scanner": "llm-guard"
    }
)
```

## OWASP LLM Coverage

| Threat | Langfuse Feature |
|--------|------------------|
| LLM01: Prompt Injection | Trace analysis, pattern detection |
| LLM02: Sensitive Data | Token inspection |
| LLM04: DoS | Cost tracking, token limits |
| LLM07: Data Leakage | Output monitoring |

## References

- [Langfuse Documentation](https://langfuse.com/docs)
- [Langfuse Helm Chart](https://github.com/langfuse/langfuse-k8s)
- GitHub Issue: "Add Langfuse LLM Observability"
