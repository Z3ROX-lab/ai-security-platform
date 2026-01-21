# ADR-004: Storage Strategy

## Status
**Accepted**

## Date
2025-01-21

## Context

The AI Security Platform requires object storage (S3-compatible) for:
- ML model artifacts and weights
- Training datasets
- MLflow experiment artifacts
- Backup and archival
- RAG document storage

Additionally, we need persistent storage for databases (PostgreSQL) and other stateful workloads.

### Requirements

| Requirement | Priority | Notes |
|-------------|----------|-------|
| S3-compatible API | Must have | Industry standard for ML tools |
| Kubernetes native | Must have | Helm chart or operator |
| Open source | Must have | No vendor lock-in |
| Single-node capable | Must have | Home lab constraint (32GB RAM) |
| Low resource footprint | Must have | RAM needed for AI workloads |
| Production-viable | Should have | Skills transferable to enterprise |
| Active maintenance | Must have | Security patches, community |
| Permissive license | Should have | Apache 2.0 preferred |

### Storage Types Needed

| Type | Use Case | Solution |
|------|----------|----------|
| **Object Storage** | S3-compatible for ML artifacts | This ADR |
| **Block Storage** | PVCs for databases | Longhorn / Local Path |
| **Database** | PostgreSQL for Keycloak, MLflow | Separate deployment |

## Options Considered

### Option 1: MinIO

| Aspect | Details |
|--------|---------|
| **Description** | High-performance S3-compatible object storage |
| **License** | AGPL v3 (changed from Apache 2.0 in 2021) |
| **Status** | ⚠️ **Maintenance mode since December 2025** |

#### MinIO History & Current State
```
Timeline:
├── 2014-2021: Apache 2.0 license, rapid adoption
├── 2021: License changed to AGPL v3
├── June 2025: Web UI removed from community edition
├── December 2025: Entered "maintenance mode"
│   ├── No new features or enhancements
│   ├── No pull requests accepted
│   ├── Security fixes "case-by-case"
│   └── Users directed to MinIO AIStor ($96,000/year minimum)
```

#### MinIO Pros
- Excellent S3 compatibility (321/576 Ceph tests passed)
- Simple single-binary deployment
- Extensive documentation
- Wide ecosystem integration

#### MinIO Cons
- ❌ **No longer actively developed (open source)**
- ❌ AGPL v3 license (copyleft, compliance burden)
- ❌ Web UI removed from free version
- ❌ Enterprise version costs $96,000+/year
- ❌ "Bait and switch" perception in community
- ❌ Security risk: patches not guaranteed

#### MinIO Verdict
**Not recommended for new deployments.** While existing installations may continue working, starting a new project on MinIO in 2025 introduces unnecessary risk.

---

### Option 2: Ceph (RADOS Gateway)

| Aspect | Details |
|--------|---------|
| **Description** | Unified distributed storage (block, file, object) |
| **License** | LGPL v2.1 / v3 |
| **Governance** | Ceph Foundation (Linux Foundation) |
| **Status** | ✅ Actively maintained |

#### Ceph Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                      CEPH CLUSTER                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   MON       │  │   MON       │  │   MON       │         │
│  │  (Monitor)  │  │  (Monitor)  │  │  (Monitor)  │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│         │               │               │                   │
│         └───────────────┼───────────────┘                   │
│                         │                                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │    OSD      │  │    OSD      │  │    OSD      │         │
│  │  (Storage)  │  │  (Storage)  │  │  (Storage)  │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│                         │                                    │
│  ┌──────────────────────┴──────────────────────┐           │
│  │                    RADOS                     │           │
│  │        (Reliable Autonomic Distributed       │           │
│  │              Object Store)                   │           │
│  └──────────────────────┬──────────────────────┘           │
│                         │                                    │
│         ┌───────────────┼───────────────┐                   │
│         ▼               ▼               ▼                   │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐          │
│  │    RBD      │ │   CephFS    │ │    RGW      │          │
│  │   (Block)   │ │   (File)    │ │  (Object)   │          │
│  │             │ │             │ │ S3-compat   │          │
│  └─────────────┘ └─────────────┘ └─────────────┘          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

#### Ceph Pros
- ✅ **Best S3 compatibility** (576/576 tests passed)
- ✅ Multi-protocol: Block (RBD), File (CephFS), Object (RGW)
- ✅ Enterprise-proven (CERN, Bloomberg, DreamWorks)
- ✅ Open governance (Linux Foundation)
- ✅ Kubernetes integration via Rook operator
- ✅ Petabyte+ scale
- ✅ Self-healing, no single point of failure

#### Ceph Cons
- ❌ **Very complex** to deploy and operate
- ❌ Requires minimum 3 nodes for production
- ❌ High resource overhead (2-4GB RAM per TB + MON/MGR)
- ❌ Steep learning curve (weeks to master)
- ❌ Overkill for home lab / single-node deployment

#### Ceph Resource Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| Nodes | 3 | 5+ |
| RAM per OSD | 2GB | 4GB |
| MON RAM | 2GB | 4GB |
| MGR RAM | 1GB | 2GB |
| Network | 1Gbps | 10Gbps |

#### Ceph Verdict
**Excellent for enterprise, overkill for home lab.** Ceph is the gold standard for distributed storage but requires significant resources and expertise. Not suitable for a single-node 32GB setup.

---

### Option 3: SeaweedFS

| Aspect | Details |
|--------|---------|
| **Description** | Fast distributed storage for blobs, objects, files |
| **License** | Apache 2.0 |
| **Language** | Go |
| **Status** | ✅ Actively maintained |

#### SeaweedFS Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                     SEAWEEDFS                                │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    MASTER                            │   │
│  │         (Manages volume assignment)                  │   │
│  │              Port: 9333                              │   │
│  └─────────────────────────┬───────────────────────────┘   │
│                            │                                │
│         ┌──────────────────┼──────────────────┐            │
│         ▼                  ▼                  ▼            │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
│  │   VOLUME    │    │   VOLUME    │    │   VOLUME    │    │
│  │   SERVER    │    │   SERVER    │    │   SERVER    │    │
│  │  Port: 8080 │    │  Port: 8081 │    │  Port: 8082 │    │
│  └─────────────┘    └─────────────┘    └─────────────┘    │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    FILER                             │   │
│  │         (Optional: POSIX-like interface)            │   │
│  │         (S3 API endpoint)                           │   │
│  │              Port: 8888                              │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

#### SeaweedFS Pros
- ✅ **Apache 2.0 license** (permissive)
- ✅ Simple deployment (single node OK)
- ✅ Low resource footprint (~512MB RAM)
- ✅ S3-compatible API via Filer
- ✅ Optimized for small files (O(1) disk seek)
- ✅ Active development and community
- ✅ Kubernetes Helm chart available
- ✅ Cloud tiering support
- ✅ Scales from single node to multi-datacenter

#### SeaweedFS Cons
- ⚠️ Lower S3 compatibility than Ceph (56/576 tests)
- ⚠️ Less enterprise adoption than Ceph
- ⚠️ No versioning support (major S3 feature)
- ⚠️ Documentation could be better

#### SeaweedFS Resource Requirements

| Deployment | Master | Volume | Filer | Total |
|------------|--------|--------|-------|-------|
| Minimal | 100MB | 200MB | 200MB | ~500MB |
| Recommended | 256MB | 512MB | 512MB | ~1.3GB |

#### SeaweedFS Verdict
**Excellent balance for home lab and learning.** Apache 2.0 license, low resources, active development. Good stepping stone before Ceph in enterprise.

---

### Option 4: Garage

| Aspect | Details |
|--------|---------|
| **Description** | Lightweight S3-compatible distributed storage |
| **License** | AGPL v3 |
| **Language** | Rust |
| **Status** | ✅ Actively maintained |

#### Garage Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                       GARAGE                                 │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                   GARAGE NODE                        │   │
│  │                                                      │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │   │
│  │  │  S3 API     │  │   Admin     │  │    RPC      │ │   │
│  │  │  Gateway    │  │    API      │  │  (Cluster)  │ │   │
│  │  │  Port:3900  │  │  Port:3903  │  │  Port:3901  │ │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘ │   │
│  │                                                      │   │
│  │  ┌───────────────────────────────────────────────┐  │   │
│  │  │              Data Storage                      │  │   │
│  │  │        (Replication: 3x default)              │  │   │
│  │  └───────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

#### Garage Pros
- ✅ **Ultra-lightweight** (~256MB RAM)
- ✅ Written in Rust (memory safe, performant)
- ✅ Simple single-binary deployment
- ✅ Designed for geo-distributed setups
- ✅ Good for edge deployments
- ✅ Active development

#### Garage Cons
- ⚠️ **AGPL v3 license** (copyleft, compliance concerns)
- ⚠️ Limited S3 compatibility (no versioning, lifecycle)
- ⚠️ Smaller community than SeaweedFS
- ⚠️ Less enterprise adoption
- ⚠️ Focused on small-scale deployments (<10TB)

#### Garage Verdict
**Good for edge/lightweight scenarios, but AGPL license is a concern.** If license isn't an issue, excellent minimal choice.

---

### Option 5: RustFS

| Aspect | Details |
|--------|---------|
| **Description** | High-performance S3-compatible storage in Rust |
| **License** | Apache 2.0 |
| **Language** | Rust |
| **Status** | ⚠️ New project (no major version yet) |

#### RustFS Pros
- ✅ Apache 2.0 license
- ✅ Written in Rust (performance, safety)
- ✅ Active development (weekly releases)
- ✅ Designed as MinIO replacement

#### RustFS Cons
- ❌ **No major version release yet**
- ❌ Limited production track record
- ❌ Documentation still maturing
- ❌ Risky for production use in 2025

#### RustFS Verdict
**Promising but too early.** Watch this project for 2026, but not ready for production or serious learning today.

---

## Comparison Matrix

| Criteria | MinIO | Ceph | SeaweedFS | Garage | RustFS |
|----------|-------|------|-----------|--------|--------|
| **S3 Compatibility** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| **Single-node** | ✅ | ❌ | ✅ | ✅ | ✅ |
| **Resource usage** | Low | High | Low | Very Low | Low |
| **License** | AGPL | LGPL | Apache 2.0 | AGPL | Apache 2.0 |
| **Active development** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Enterprise ready** | ⚠️ | ✅ | ✅ | ⚠️ | ❌ |
| **Community** | Large | Large | Medium | Small | Small |
| **K8s integration** | ✅ | ✅ (Rook) | ✅ | ✅ | ⚠️ |
| **Home lab suitable** | ⚠️ | ❌ | ✅ | ✅ | ⚠️ |

### S3 Compatibility Test Results (Ceph s3-tests)

| Solution | Passed | Failed | Score |
|----------|--------|--------|-------|
| Ceph RGW | 576 | 69 | Best |
| Zenko | 382 | - | Good |
| MinIO | 321 | 311 | Moderate |
| SeaweedFS | 56 | 176 | Basic |

---

## Decision

**We chose SeaweedFS** for the following reasons:

### Primary Factors

1. **License**: Apache 2.0 is permissive and enterprise-friendly, unlike AGPL (MinIO, Garage).

2. **Resource Efficiency**: ~500MB RAM fits our 32GB home lab where AI workloads need priority.

3. **Active Development**: Unlike MinIO, SeaweedFS is actively maintained with regular releases.

4. **Single-Node Support**: Can start minimal and scale later, unlike Ceph which requires 3+ nodes.

5. **Sufficient S3 Compatibility**: While not as complete as Ceph, covers core operations needed for ML workflows (PUT, GET, DELETE, multipart upload).

6. **Learning Path**: Skills transfer to enterprise (S3 concepts, distributed storage) while being practical for home lab.

### Decision Matrix

| Requirement | SeaweedFS | Score |
|-------------|-----------|-------|
| S3-compatible | ✅ Yes | ✓ |
| Single-node | ✅ Yes | ✓ |
| Low resources | ✅ ~500MB | ✓ |
| Apache 2.0 | ✅ Yes | ✓ |
| Active dev | ✅ Yes | ✓ |
| K8s ready | ✅ Helm chart | ✓ |

---

## Architecture

### Storage Layer Overview
```
┌─────────────────────────────────────────────────────────────┐
│                    STORAGE LAYER                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────┐    ┌─────────────────────┐        │
│  │    SEAWEEDFS        │    │    POSTGRESQL       │        │
│  │   (Object Store)    │    │    (Database)       │        │
│  │                     │    │                     │        │
│  │  • ML Models        │    │  • Keycloak         │        │
│  │  • Datasets         │    │  • MLflow metadata  │        │
│  │  • MLflow artifacts │    │  • Application data │        │
│  │  • RAG documents    │    │                     │        │
│  │                     │    │                     │        │
│  │  S3 API: :8333      │    │  Port: 5432         │        │
│  └─────────────────────┘    └─────────────────────┘        │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    LONGHORN                          │   │
│  │               (Block Storage for PVCs)               │   │
│  │                                                      │   │
│  │  • PostgreSQL data                                   │   │
│  │  • SeaweedFS volumes                                 │   │
│  │  • Other stateful workloads                          │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### SeaweedFS Deployment
```yaml
# Simplified K8s deployment
SeaweedFS:
  Master:
    replicas: 1
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
  Volume:
    replicas: 1
    resources:
      requests:
        memory: "512Mi"
        cpu: "200m"
    storage: 50Gi
  Filer:
    replicas: 1
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
    s3:
      enabled: true
      port: 8333
```

---

## Implementation Plan

### Phase 2A: Block Storage (Longhorn)
1. Deploy Longhorn for PVC provisioning
2. Configure default StorageClass
3. Test PVC creation

### Phase 2B: Object Storage (SeaweedFS)
1. Deploy SeaweedFS via Helm (ArgoCD)
2. Configure S3 endpoint
3. Create buckets for ML workflows
4. Test S3 operations

### Phase 2C: Database (PostgreSQL)
1. Deploy PostgreSQL with Longhorn PVC
2. Configure for Keycloak and MLflow
3. Set up backups

---

## Migration Path to Enterprise

When moving to production/enterprise:

| Home Lab | Enterprise |
|----------|------------|
| SeaweedFS | Ceph RGW or AWS S3 |
| Longhorn | Ceph RBD or cloud block storage |
| Single-node | Multi-node cluster |

The S3 API is the same, so applications don't need changes.

---

## Consequences

### Positive
- Low resource footprint leaves RAM for AI workloads
- Apache 2.0 license, no compliance concerns
- Active community and development
- Skills transferable (S3 API is universal)
- Can scale if needed

### Negative
- Lower S3 compatibility than Ceph
- Less enterprise adoption than Ceph/MinIO
- May need to migrate for large-scale production

### Mitigations
- Document any S3 features we rely on
- Use standard S3 operations only
- Plan migration path to Ceph for enterprise

---

## Alternatives Considered but Rejected

| Alternative | Reason for Rejection |
|-------------|----------------------|
| MinIO | Maintenance mode, uncertain future |
| Ceph | Overkill for home lab, 3+ nodes required |
| Garage | AGPL license concern |
| RustFS | Too new, no major release |
| Cloud S3 | Want to learn self-hosted, cost |

---

## References

- [SeaweedFS GitHub](https://github.com/seaweedfs/seaweedfs)
- [SeaweedFS Documentation](https://github.com/seaweedfs/seaweedfs/wiki)
- [MinIO Maintenance Mode Announcement](https://github.com/minio/minio/commit/27742d4)
- [Ceph Documentation](https://docs.ceph.com/)
- [Garage Documentation](https://garagehq.deuxfleurs.fr/)
- [S3 API Reference](https://docs.aws.amazon.com/AmazonS3/latest/API/Welcome.html)
