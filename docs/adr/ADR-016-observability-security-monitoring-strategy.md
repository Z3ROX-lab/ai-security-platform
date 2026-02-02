# ADR-016: Observability and Security Monitoring Strategy

## Status

**Accepted**

## Date

2026-01-31

## Context

The AI Security Platform requires comprehensive observability and security monitoring to:

1. **Operational visibility**: Monitor platform health, performance, and resource usage
2. **Security monitoring**: Detect runtime threats, anomalies, and policy violations
3. **Compliance**: Audit logging and traceability for enterprise requirements
4. **Troubleshooting**: Debug issues across distributed microservices
5. **Supply chain security**: Verify container image integrity (OWASP LLM05)

### Requirements

| Requirement | Priority | Description |
|-------------|----------|-------------|
| Metrics collection | High | CPU, memory, custom app metrics |
| Log aggregation | High | Centralized logging with search |
| Distributed tracing | Medium | Request flow across services |
| Runtime security | High | Threat detection, anomaly alerts |
| Image verification | Medium | Supply chain integrity |
| Resource efficiency | High | Must fit in 32GB home lab |
| Enterprise relevance | High | Skills transferable to production |

### Current Resource Usage

| Metric | Used | Available |
|--------|------|-----------|
| Memory (actual) | ~4.2Gi | ~28Gi |
| Memory (requests) | ~8.5Gi | ~24Gi |
| Memory (limits) | ~13.4Gi | ~19Gi |

## Decision Drivers

1. **Resource constraints**: Home lab with 32GB RAM
2. **Cloud-native alignment**: Kubernetes-native tooling preferred
3. **Open source**: Avoid vendor lock-in and licensing costs
4. **Market relevance**: Tools used in enterprise environments
5. **Integration**: Works well with existing stack (ArgoCD, Keycloak, etc.)

## Options Considered

### Option 1: ELK Stack (Elasticsearch, Logstash, Kibana)

```
┌─────────────────────────────────────────────────────────────────┐
│                        ELK STACK                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Elasticsearch│  │   Logstash   │  │    Kibana    │          │
│  │              │  │              │  │              │          │
│  │   ~2-4Gi     │  │   ~1-2Gi     │  │   ~512Mi     │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                 │
│  + Filebeat/Metricbeat (~256Mi each)                           │
│  + Elastic APM for traces (~512Mi)                             │
│  + Elastic Security for SIEM                                   │
│                                                                 │
│  Total: ~4-8Gi RAM                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Pros:**
- Industry standard, especially in traditional enterprise (banks, telcos)
- Mature ecosystem (10+ years)
- Integrated SIEM capabilities (Elastic Security)
- Strong full-text search
- Large talent pool familiar with ELK
- More job postings currently (~60-70% market share in legacy)

**Cons:**
- High resource consumption (4-8Gi minimum)
- Elastic License (SSPL) - not truly open source since 2021
- Complex operations (index management, sharding)
- Not Kubernetes-native (designed pre-K8s era)
- Expensive in production (hardware + potential licensing)
- Overkill for small/medium deployments

### Option 2: Grafana Stack (Prometheus, Loki, Tempo, Grafana)

```
┌─────────────────────────────────────────────────────────────────┐
│                      GRAFANA STACK                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Prometheus  │  │     Loki     │  │    Tempo     │          │
│  │   Metrics    │  │     Logs     │  │   Traces     │          │
│  │   ~500Mi     │  │   ~500Mi     │  │   ~256Mi     │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                 │                 │                   │
│         └─────────────────┼─────────────────┘                   │
│                           ▼                                     │
│                    ┌──────────────┐                             │
│                    │   Grafana    │                             │
│                    │  Dashboards  │                             │
│                    │   ~256Mi     │                             │
│                    └──────────────┘                             │
│                                                                 │
│  Total: ~1.5Gi RAM                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Pros:**
- Kubernetes-native design
- Lightweight (~1.5Gi vs 4-8Gi for ELK)
- Fully open source (Apache 2.0 / AGPLv3)
- Each component does one thing well
- Prometheus is the de-facto standard for K8s metrics
- Growing adoption in cloud-native companies (~30-40% and rising)
- Cost-effective in production
- Excellent Grafana dashboards and alerting

**Cons:**
- Loki has limited search compared to Elasticsearch
- No built-in SIEM (requires additional tools)
- Smaller talent pool for Loki/Tempo specifically
- Multiple components to manage

### Option 3: Hybrid (Grafana Stack + ELK for SIEM)

Use Grafana stack for operational observability, add ELK only for security/SIEM use cases.

**Pros:**
- Best of both worlds
- Can demonstrate knowledge of both stacks

**Cons:**
- Highest resource usage
- Complexity of managing two logging systems
- Overkill for home lab

### Option 4: Managed Services (Datadog, New Relic, Splunk Cloud)

**Pros:**
- Zero operational overhead
- Enterprise features out of box

**Cons:**
- Expensive ($$$)
- Not suitable for home lab
- Vendor lock-in
- No hands-on learning of internals

## Decision

**Chosen: Option 2 - Grafana Stack** with additional security components.

### Complete Observability Stack

| Component | Purpose | RAM | License |
|-----------|---------|-----|---------|
| **Prometheus** | Metrics collection & alerting | ~500Mi | Apache 2.0 |
| **Grafana** | Dashboards & visualization | ~256Mi | AGPLv3 |
| **Loki** | Log aggregation | ~500Mi | AGPLv3 |
| **Tempo** | Distributed tracing | ~256Mi | AGPLv3 |
| **Falco** | Runtime security & threat detection | ~500Mi | Apache 2.0 |
| **Cosign** | Image signing | CLI | Apache 2.0 |
| **Kyverno** | Policy enforcement & image verification | ~200Mi | Apache 2.0 |
| **Total** | | **~2.2Gi** | |

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    OBSERVABILITY & SECURITY STACK                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                         GRAFANA                                  │   │
│  │              Unified dashboards for all data                     │   │
│  │  https://grafana.ai-platform.localhost                           │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│         ▲                    ▲                    ▲                     │
│         │                    │                    │                     │
│  ┌──────┴─────┐       ┌──────┴─────┐       ┌──────┴─────┐              │
│  │ Prometheus │       │    Loki    │       │   Tempo    │              │
│  │  Metrics   │       │    Logs    │       │   Traces   │              │
│  │            │       │            │       │            │              │
│  │ • CPU/RAM  │       │ • App logs │       │ • Requests │              │
│  │ • Custom   │       │ • K8s logs │       │ • Latency  │              │
│  │ • Alerts   │       │ • Audit    │       │ • Errors   │              │
│  └──────┬─────┘       └──────┬─────┘       └──────┬─────┘              │
│         │                    │                    │                     │
│         └────────────────────┼────────────────────┘                     │
│                              │                                          │
│                     ┌────────▼────────┐                                 │
│                     │   Applications  │                                 │
│                     │   & Platform    │                                 │
│                     └─────────────────┘                                 │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     SECURITY LAYER                               │   │
│  │                                                                  │   │
│  │  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │   │
│  │  │    Falco     │    │   Kyverno    │    │    Cosign    │       │   │
│  │  │              │    │              │    │              │       │   │
│  │  │ • Runtime    │    │ • Policies   │    │ • Signing    │       │   │
│  │  │   threats    │    │ • Admission  │    │ • Verify     │       │   │
│  │  │ • Anomalies  │    │ • Image      │    │              │       │   │
│  │  │ • Syscalls   │    │   verify     │    │              │       │   │
│  │  └──────────────┘    └──────────────┘    └──────────────┘       │   │
│  │                                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Rationale

### Why Grafana Stack over ELK?

| Factor | Grafana Stack | ELK | Winner |
|--------|---------------|-----|--------|
| **RAM usage** | ~1.5Gi | ~4-8Gi | Grafana |
| **K8s native** | Yes (designed for K8s) | No (adapted later) | Grafana |
| **License** | Open source | SSPL (restricted) | Grafana |
| **Complexity** | Moderate | High | Grafana |
| **Prometheus** | Native integration | Requires adapter | Grafana |
| **Market trend** | Growing (cloud-native) | Stable (legacy) | Grafana |
| **Search power** | Basic (label-based) | Advanced (full-text) | ELK |
| **SIEM** | Need Falco addon | Built-in | ELK |

**Key decision factors:**

1. **Resource efficiency**: 1.5Gi vs 4-8Gi is critical for home lab
2. **Kubernetes alignment**: Prometheus is the standard for K8s metrics
3. **Open source**: AGPLv3/Apache 2.0 vs SSPL
4. **Modern skills**: Cloud-native stack is increasingly demanded
5. **Falco fills SIEM gap**: Runtime security without ELK overhead

### Why include Falco + Kyverno?

| OWASP LLM | Threat | Solution |
|-----------|--------|----------|
| LLM05 | Supply Chain | Cosign + Kyverno (image verification) |
| LLM10 | Model Theft | Falco (detect data exfiltration) |
| General | Runtime attacks | Falco (syscall monitoring) |

### ELK consideration for future

ELK is documented here but **not implemented** because:

1. Resource constraints (32GB shared with LLM inference)
2. Grafana stack covers 90% of observability needs
3. Falco provides security monitoring without ELK overhead

**Recommendation for enterprise**: If SIEM integration is required (SOC, compliance), consider:
- Elastic Cloud (managed) for production
- Integration with existing enterprise SIEM (Splunk, QRadar)
- Falco alerts forwarded to SIEM via webhook

## Consequences

### Positive

- **Lightweight**: 2.2Gi total vs 4-8Gi for ELK
- **Three pillars**: Metrics (Prometheus) + Logs (Loki) + Traces (Tempo)
- **Security**: Falco + Kyverno cover runtime and supply chain
- **Unified UI**: Single Grafana dashboard for everything
- **Cost effective**: All open source, no licensing
- **Portfolio value**: Demonstrates cloud-native AND security monitoring

### Negative

- **Limited log search**: Loki is label-based, not full-text like Elasticsearch
- **No built-in SIEM**: Must rely on Falco + external SIEM integration
- **Learning curve**: Multiple tools to learn vs single ELK stack

### Neutral

- **Market position**: Both ELK and Grafana stack are valuable skills
- **Enterprise adoption**: ELK still dominates legacy, Grafana growing fast

## Implementation Plan

### Phase 8: Observability & Security Monitoring

| Step | Component | Description |
|------|-----------|-------------|
| 8a | Prometheus + Grafana | Metrics and dashboards |
| 8b | Loki | Log aggregation |
| 8c | Tempo | Distributed tracing |
| 8d | Falco | Runtime security |
| 8e | Cosign + Kyverno | Supply chain security |

### Resource Budget

| Current | + Observability | + LLM loaded | Total | Available |
|---------|-----------------|--------------|-------|-----------|
| 4.2Gi | +2.2Gi | +4-8Gi | ~14Gi | ~18Gi ✅ |

### Access URLs (Planned)

| Service | URL |
|---------|-----|
| Grafana | https://grafana.ai-platform.localhost |
| Prometheus | https://prometheus.ai-platform.localhost |
| Alertmanager | https://alertmanager.ai-platform.localhost |

## Compliance Mapping

| Framework | Control | Solution |
|-----------|---------|----------|
| **OWASP LLM05** | Supply Chain | Cosign + Kyverno |
| **OWASP LLM10** | Model Theft | Falco + NetworkPolicies |
| **NIST CSF** | DE.CM (Monitoring) | Prometheus, Loki, Falco |
| **NIST CSF** | DE.AE (Anomalies) | Falco |
| **ISO 27001** | A.12.4 (Logging) | Loki |
| **ISO 27001** | A.12.6 (Vulnerability) | Kyverno |

## Alternatives for Enterprise

If deploying in enterprise with more resources:

| Scenario | Recommendation |
|----------|----------------|
| **SOC integration needed** | Add ELK or forward Falco to existing SIEM |
| **Compliance heavy** | Elastic Security or Splunk |
| **Unlimited budget** | Datadog / New Relic |
| **Air-gapped** | Full Grafana stack + Falco |

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Loki](https://grafana.com/docs/loki/)
- [Grafana Tempo](https://grafana.com/docs/tempo/)
- [Falco](https://falco.org/docs/)
- [Kyverno](https://kyverno.io/docs/)
- [Cosign](https://docs.sigstore.dev/cosign/overview/)
- [ELK Stack](https://www.elastic.co/what-is/elk-stack)
- [Elastic License FAQ](https://www.elastic.co/licensing/elastic-license)
- [CNCF Observability Landscape](https://landscape.cncf.io/card-mode?category=observability-and-analysis)

## Related ADRs

- [ADR-004: Storage Strategy](ADR-004-storage-strategy.md)
- [ADR-009: AI Guardrails Strategy](ADR-009-ai-guardrails-strategy.md)
- [ADR-013: CNI Strategy](ADR-013-cni-strategy.md)
