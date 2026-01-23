# ADR-004: Storage Strategy

## Status
**Accepted** (Updated 2025-01-23)

## Date
2025-01-21 (Updated 2025-01-23)

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
| **Object Storage** | S3-compatible for ML artifacts | SeaweedFS |
| **Block Storage** | PVCs for databases | local-path (K3d) / Longhorn (production) |
| **Database** | PostgreSQL for Keycloak, MLflow | Separate deployment |

---

## Block Storage Decision

### Update (2025-01-23): local-path vs Longhorn

#### Original Plan: Longhorn

Longhorn was initially chosen for block storage (PVCs) because:
- Distributed block storage with replication
- Snapshots and backups
- Web UI for management
- CNCF Sandbox project

#### Issue Encountered: WSL2/Docker Desktop Limitation

```
Error: path "/var/lib/longhorn/" is mounted on "/" but it is not a shared mount
```

**Root Cause**: Longhorn requires "shared mount propagation" which is not available on:
- WSL2 (Windows Subsystem for Linux)
- Docker Desktop (Mac/Windows)
- Some containerized Kubernetes distributions

This is a fundamental limitation of how Docker/WSL2 handles mount namespaces.

#### Solution: local-path-provisioner

For this home lab running on WSL2, we use **local-path-provisioner** which:
- ✅ Comes pre-installed with K3d
- ✅ Works on WSL2/Docker Desktop
- ✅ Simple and reliable
- ✅ Sufficient for single-node development

| Aspect | local-path | Longhorn |
|--------|------------|----------|
| **Replication** | ❌ No | ✅ Yes |
| **Snapshots** | ❌ No | ✅ Yes |
| **Backup to S3** | ❌ No | ✅ Yes |
| **Web UI** | ❌ No | ✅ Yes |
| **WSL2 Compatible** | ✅ Yes | ❌ No |
| **Complexity** | Simple | More complex |
| **Home Lab** | ✅ Sufficient | Overkill |

#### When to Use Longhorn

Longhorn is recommended for:
- Bare-metal Kubernetes clusters
- VMs with proper mount propagation
- Production environments needing HA
- Multi-node clusters with replication needs

```
# Requirements for Longhorn:
# 1. Native Linux (not WSL2)
# 2. Shared mount propagation enabled:
#    sudo mount --make-rshared /
# 3. Or use K3d with:
#    --volume /path:/var/lib/longhorn:shared
```

---

## Object Storage Decision

### Options Considered

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

#### MinIO Verdict
**Not recommended for new deployments.** While existing installations may continue working, starting a new project on MinIO in 2025 introduces unnecessary risk.

---

### Option 2: Ceph (RADOS Gateway)

| Aspect | Details |
|--------|---------|
| **Description** | Unified distributed storage (block, file, object) |
| **License** | LGPL v2.1 / v3 |
| **Status** | ✅ Actively maintained |

#### Ceph Pros
- ✅ **Best S3 compatibility** (576/576 tests passed)
- ✅ Multi-protocol: Block (RBD), File (CephFS), Object (RGW)
- ✅ Enterprise-proven (CERN, Bloomberg, DreamWorks)

#### Ceph Cons
- ❌ **Very complex** to deploy and operate
- ❌ Requires minimum 3 nodes for production
- ❌ High resource overhead (2-4GB RAM per TB + MON/MGR)

#### Ceph Verdict
**Excellent for enterprise, overkill for home lab.** Not suitable for a single-node 32GB setup.

---

### Option 3: SeaweedFS ✅ SELECTED

| Aspect | Details |
|--------|---------|
| **Description** | Fast distributed storage for blobs, objects, files |
| **License** | Apache 2.0 |
| **Language** | Go |
| **Status** | ✅ Actively maintained |

#### SeaweedFS Pros
- ✅ **Apache 2.0 license** (permissive)
- ✅ Simple deployment (single node OK)
- ✅ Low resource footprint (~500MB RAM)
- ✅ S3-compatible API via Filer
- ✅ Active development and community
- ✅ Kubernetes Helm chart available

#### SeaweedFS Cons
- ⚠️ Lower S3 compatibility than Ceph (56/576 tests)
- ⚠️ No versioning support (major S3 feature)

#### SeaweedFS Verdict
**Excellent balance for home lab and learning.**

---

## Decision Summary

### Block Storage: local-path-provisioner

```yaml
# All PVCs use local-path StorageClass
persistence:
  storageClass: local-path
```

**Rationale**: Longhorn not compatible with WSL2/Docker Desktop. local-path is pre-installed with K3d and sufficient for home lab.

### Object Storage: SeaweedFS

```yaml
# S3-compatible endpoint
S3 API: http://seaweedfs-s3.storage.svc:8333
```

**Rationale**: Apache 2.0 license, low resources, active development.

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
│  └──────────┬──────────┘    └──────────┬──────────┘        │
│             │                          │                    │
│             ▼                          ▼                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              LOCAL-PATH-PROVISIONER                  │   │
│  │            (Block Storage for PVCs)                  │   │
│  │                                                      │   │
│  │  • PostgreSQL data                                   │   │
│  │  • SeaweedFS volumes                                 │   │
│  │  • Other stateful workloads                          │   │
│  │                                                      │   │
│  │  ⚠️ Single-node only, no replication                │   │
│  │  ℹ️ Use Longhorn for production (bare-metal)        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation

### Phase 2A: Block Storage (local-path)

Already installed with K3d. Verify:

```bash
kubectl get storageclass
# NAME                   PROVISIONER             RECLAIMPOLICY
# local-path (default)   rancher.io/local-path   Delete
```

### Phase 2B: Object Storage (SeaweedFS)

Deploy via ArgoCD:

```yaml
# argocd/applications/storage/seaweedfs/values.yaml
persistence:
  storageClass: local-path  # Use K3d default
```

### Phase 2C: Database (PostgreSQL)

Deploy via ArgoCD:

```yaml
# argocd/applications/storage/postgresql/values.yaml
primary:
  persistence:
    storageClass: local-path  # Use K3d default
```

---

## Migration Path

### Home Lab → Production

| Component | Home Lab | Production |
|-----------|----------|------------|
| Block Storage | local-path | Longhorn / Ceph RBD |
| Object Storage | SeaweedFS | SeaweedFS / Ceph RGW / S3 |
| Database | PostgreSQL (single) | PostgreSQL HA |

### Enabling Longhorn (Production)

For bare-metal or VM clusters (not WSL2):

```bash
# 1. Ensure shared mount propagation
sudo mount --make-rshared /

# 2. Or recreate K3d with shared volume
k3d cluster create my-cluster \
  --volume /var/lib/longhorn:/var/lib/longhorn:shared

# 3. Deploy Longhorn via ArgoCD
```

---

## Consequences

### Positive
- ✅ Works on WSL2/Docker Desktop (local-path)
- ✅ Low resource footprint
- ✅ Simple setup, fast iteration
- ✅ SeaweedFS provides S3 API for ML workflows
- ✅ Skills transferable to production

### Negative
- ❌ No block storage replication (local-path)
- ❌ No snapshots/backups built-in (local-path)
- ❌ Data loss if node fails

### Mitigations
- Document production setup with Longhorn
- Use SeaweedFS replication for critical data
- Regular backups of PostgreSQL
- Treat home lab as ephemeral

---

## Lessons Learned

1. **WSL2 Limitations**: Not all Kubernetes storage solutions work on WSL2/Docker Desktop. Always test early.

2. **Start Simple**: local-path is sufficient for learning and development. Add complexity (Longhorn) when needed.

3. **Document Alternatives**: Clearly document production recommendations even when using simpler solutions for development.

---

## References

- [SeaweedFS GitHub](https://github.com/seaweedfs/seaweedfs)
- [Longhorn Documentation](https://longhorn.io/docs/)
- [Longhorn WSL2 Issue](https://github.com/longhorn/longhorn/issues/2292)
- [K3d local-path-provisioner](https://k3d.io/v5.6.0/usage/exposing_services/)
- [local-path-provisioner GitHub](https://github.com/rancher/local-path-provisioner)
