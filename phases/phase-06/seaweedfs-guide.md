# SeaweedFS Deployment Guide

## Overview

SeaweedFS is a fast distributed storage system providing S3-compatible object storage for the AI Security Platform.

| Attribute | Value |
|-----------|-------|
| **License** | Apache 2.0 |
| **S3 Compatibility** | Yes |
| **Filer UI** | https://seaweedfs.ai-platform.localhost |
| **S3 API** | https://s3.ai-platform.localhost |
| **Namespace** | storage |
| **Helm Chart** | seaweedfs/seaweedfs |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        SEAWEEDFS                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐           │
│  │   MASTER    │   │   VOLUME    │   │    FILER    │           │
│  │             │   │             │   │             │           │
│  │ • Metadata  │   │ • Data blobs│   │ • S3 API    │           │
│  │ • Topology  │   │ • Storage   │   │ • File API  │           │
│  │             │   │             │   │ • Web UI    │           │
│  │  :9333      │   │  :8080      │   │  :8888/:8333│           │
│  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘           │
│         │                 │                 │                   │
│         └────────────┬────┴─────────────────┘                   │
│                      │                                          │
│              ┌───────▼───────┐                                  │
│              │  ADMIN UI     │                                  │
│              │   :33333      │                                  │
│              └───────────────┘                                  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    INGRESS (Traefik)                     │   │
│  │  seaweedfs.ai-platform.localhost → Filer :8888           │   │
│  │  s3.ai-platform.localhost        → S3 API :8333          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

### 1. DNS Configuration

Add to your hosts file:

**Linux/Mac**: `/etc/hosts`
**Windows**: `C:\Windows\System32\drivers\etc\hosts`

```
127.0.0.1 seaweedfs.ai-platform.localhost
127.0.0.1 s3.ai-platform.localhost
```

### 2. Namespace PodSecurity

⚠️ **IMPORTANT**: SeaweedFS uses `hostPath` volumes for logs, which requires the `storage` namespace to be set to `privileged`.

If your namespace has `restricted` PodSecurity (default in this platform), update it:

```bash
# Check current labels
kubectl get namespace storage --show-labels | grep pod-security

# If restricted, change to privileged
kubectl label namespace storage \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/warn=privileged \
  pod-security.kubernetes.io/audit=privileged \
  --overwrite
```

**For GitOps**: Update `argocd/applications/security/security-baseline/manifests/namespaces.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: storage
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
```

### 3. Verify Cluster

```bash
# Check cluster is running
kubectl get nodes

# Check storage class
kubectl get storageclass

# Check existing storage pods
kubectl get pods -n storage
```

## Deployment

### Step 1: Create ArgoCD Application

```bash
# Create directory
mkdir -p ~/work/ai-security-platform/argocd/applications/storage/seaweedfs

# Copy application file
cp ~/Downloads/seaweedfs-application.yaml \
   ~/work/ai-security-platform/argocd/applications/storage/seaweedfs/application.yaml
```

### Step 2: Commit and Push

```bash
cd ~/work/ai-security-platform

git add argocd/applications/storage/seaweedfs/
git commit -m "feat(phase-06): add SeaweedFS S3-compatible object storage"
git push
```

### Step 3: Verify Sync

ArgoCD should auto-sync. Check status:

```bash
# Via CLI
kubectl get applications -n argocd seaweedfs

# Or watch pods
kubectl get pods -n storage -w
```

### Step 4: Wait for Pods

```bash
# All pods should be Running
kubectl get pods -n storage

# Expected output:
# NAME                    READY   STATUS    RESTARTS   AGE
# seaweedfs-master-0      1/1     Running   0          2m
# seaweedfs-volume-0      1/1     Running   0          2m
# seaweedfs-filer-0       1/1     Running   0          2m
# seaweedfs-admin-xxx     1/1     Running   0          2m
```

### Step 5: Verify Ingress

```bash
kubectl get ingress -n storage

# Expected:
# NAME               HOSTS                              ADDRESS     PORTS     AGE
# seaweedfs-filer    seaweedfs.ai-platform.localhost   127.0.0.1   80, 443   2m
# seaweedfs-s3       s3.ai-platform.localhost          127.0.0.1   80, 443   2m
```

### Step 6: Test Access

```bash
# Test Filer UI
curl -k https://seaweedfs.ai-platform.localhost

# Test S3 API
curl -k https://s3.ai-platform.localhost
```

## Using SeaweedFS

### Create Buckets via Web UI

The easiest way to create buckets:

1. Open https://seaweedfs.ai-platform.localhost in your browser
2. Click **New Folder** button
3. Create the following folders (buckets):

| Folder Name | Purpose |
|-------------|---------|
| `mlflow-artifacts` | MLflow model artifacts |
| `datasets` | Training datasets |
| `backups` | PostgreSQL backups |
| `rag-documents` | Documents for RAG |

These folders will appear as S3 buckets when accessed via the S3 API.

### Web UI

Open in browser: https://seaweedfs.ai-platform.localhost

Features:
- Browse files and directories
- Upload/download files
- Create directories
- View storage statistics

### S3 API with AWS CLI

```bash
# Configure AWS CLI for SeaweedFS
aws configure set default.s3.signature_version s3v4

# Create alias for convenience
alias s3local='aws --endpoint-url https://s3.ai-platform.localhost --no-verify-ssl s3'

# List buckets
s3local ls

# Create bucket
s3local mb s3://mlflow-artifacts
s3local mb s3://datasets
s3local mb s3://backups
s3local mb s3://rag-documents

# Upload file
s3local cp myfile.txt s3://datasets/

# List files
s3local ls s3://datasets/

# Download file
s3local cp s3://datasets/myfile.txt ./downloaded.txt
```

### S3 API with Python (boto3)

```python
import boto3
from botocore.config import Config

# Create S3 client
s3 = boto3.client(
    's3',
    endpoint_url='https://s3.ai-platform.localhost',
    aws_access_key_id='any',      # Auth disabled by default
    aws_secret_access_key='any',
    verify=False,                  # Self-signed cert
    config=Config(signature_version='s3v4')
)

# Create bucket
s3.create_bucket(Bucket='my-bucket')

# Upload file
s3.upload_file('local_file.txt', 'my-bucket', 'remote_file.txt')

# List objects
response = s3.list_objects_v2(Bucket='my-bucket')
for obj in response.get('Contents', []):
    print(obj['Key'])

# Download file
s3.download_file('my-bucket', 'remote_file.txt', 'downloaded.txt')

# Generate presigned URL
url = s3.generate_presigned_url(
    'get_object',
    Params={'Bucket': 'my-bucket', 'Key': 'remote_file.txt'},
    ExpiresIn=3600
)
print(url)
```

### weed CLI (Native SeaweedFS)

```bash
# Port-forward to master
kubectl port-forward -n storage svc/seaweedfs-master 9333:9333 &

# Use weed CLI
weed shell

# Inside weed shell:
> fs.ls /
> fs.mkdir /data
> fs.upload /data/test.txt ./local_file.txt
> fs.cat /data/test.txt
> fs.rm /data/test.txt
> exit
```

## Configuration

### Enable S3 Authentication

For production, enable S3 authentication:

1. **Create Secret with credentials**:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: seaweedfs-s3-secret
  namespace: storage
type: Opaque
stringData:
  seaweedfs_s3_config: |
    {
      "identities": [
        {
          "name": "admin",
          "credentials": [
            {
              "accessKey": "admin-access-key",
              "secretKey": "change-this-secret-key"
            }
          ],
          "actions": ["Admin", "Read", "Write", "List", "Tagging"]
        },
        {
          "name": "readonly",
          "credentials": [
            {
              "accessKey": "readonly-access-key",
              "secretKey": "change-this-secret-key"
            }
          ],
          "actions": ["Read", "List"]
        }
      ]
    }
```

2. **Update application.yaml**:

```yaml
filer:
  s3:
    enabled: true
    enableAuth: true
    existingConfigSecret: seaweedfs-s3-secret
```

### Increase Storage

Edit `application.yaml`:

```yaml
volume:
  dataDirs:
    - name: "data"
      size: "50Gi"  # Increase from 10Gi
```

### Multiple Volume Servers (Production)

```yaml
volume:
  replicas: 3
  dataDirs:
    - name: "data"
      size: "100Gi"
```

## Integration Examples

### MLflow

```bash
# Set environment variables
export MLFLOW_S3_ENDPOINT_URL=https://s3.ai-platform.localhost
export AWS_ACCESS_KEY_ID=admin-access-key
export AWS_SECRET_ACCESS_KEY=change-this-secret-key

# Start MLflow with S3 backend
mlflow server \
  --backend-store-uri postgresql://mlflow:password@postgresql:5432/mlflow \
  --default-artifact-root s3://mlflow-artifacts/
```

### LangChain Document Loader

```python
from langchain.document_loaders import S3FileLoader

loader = S3FileLoader(
    bucket="rag-documents",
    key="document.pdf",
    endpoint_url="https://s3.ai-platform.localhost"
)
documents = loader.load()
```

### Backup Script

```bash
#!/bin/bash
# backup-to-seaweedfs.sh

BUCKET="backups"
DATE=$(date +%Y%m%d-%H%M%S)
S3_ENDPOINT="https://s3.ai-platform.localhost"

# Backup PostgreSQL
kubectl exec -n storage postgresql-cluster-0 -- \
  pg_dump -U postgres keycloak | \
  aws s3 cp - s3://${BUCKET}/postgres/keycloak-${DATE}.sql \
    --endpoint-url ${S3_ENDPOINT}

echo "Backup completed: s3://${BUCKET}/postgres/keycloak-${DATE}.sql"
```

## Monitoring

### Check Storage Usage

```bash
# Via kubectl
kubectl exec -n storage seaweedfs-master-0 -- \
  weed shell -master localhost:9333 -shell "volume.list"

# Via API
curl -k https://seaweedfs.ai-platform.localhost/cluster/status
```

### View Logs

```bash
# Master logs
kubectl logs -n storage seaweedfs-master-0

# Volume logs
kubectl logs -n storage seaweedfs-volume-0

# Filer logs
kubectl logs -n storage seaweedfs-filer-0
```

### Metrics (Prometheus)

SeaweedFS exposes Prometheus metrics:

```bash
# Port-forward metrics
kubectl port-forward -n storage svc/seaweedfs-filer 9327:9327

# Scrape metrics
curl http://localhost:9327/metrics
```

## Troubleshooting

### Pods Not Starting - PodSecurity Violation

If you see errors like:
```
violates PodSecurity "restricted:latest": 
  allowPrivilegeEscalation != false
  restricted volume types (volume "seaweedfs-master-log-volume" uses restricted volume type "hostPath")
```

**Solution**: The namespace must be `privileged`:

```bash
# Check current labels
kubectl get namespace storage --show-labels | grep pod-security

# Fix: Set to privileged
kubectl label namespace storage \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/warn=privileged \
  pod-security.kubernetes.io/audit=privileged \
  --overwrite

# Force pod recreation
kubectl delete statefulset -n storage seaweedfs-master seaweedfs-filer
# ArgoCD will recreate them automatically
```

### Pod CrashLoopBackOff

```bash
# Check events
kubectl describe pod -n storage seaweedfs-master-0

# Common causes:
# - PVC not bound (check storageclass)
# - Resource limits too low
# - Port conflicts
```

### S3 API Errors

```bash
# Check filer logs
kubectl logs -n storage seaweedfs-filer-0 | grep -i error

# Test connectivity
kubectl exec -n storage seaweedfs-filer-0 -- \
  wget -qO- http://localhost:8333
```

### Ingress Not Working

```bash
# Check ingress
kubectl describe ingress -n storage

# Check Traefik logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik

# Verify certificate
kubectl get certificate -n storage
```

### PVC Pending

```bash
# Check PVC status
kubectl get pvc -n storage

# Check storageclass
kubectl get storageclass

# For local-path, check provisioner
kubectl logs -n kube-system -l app=local-path-provisioner
```

## Cleanup

To remove SeaweedFS:

```bash
# Delete ArgoCD application
kubectl delete application -n argocd seaweedfs

# Delete PVCs (data will be lost!)
kubectl delete pvc -n storage -l app.kubernetes.io/name=seaweedfs

# Verify
kubectl get all -n storage
```

## References

- [SeaweedFS GitHub](https://github.com/seaweedfs/seaweedfs)
- [SeaweedFS Wiki](https://github.com/seaweedfs/seaweedfs/wiki)
- [SeaweedFS S3 API](https://github.com/seaweedfs/seaweedfs/wiki/Amazon-S3-API)
- [Helm Chart](https://github.com/seaweedfs/seaweedfs/tree/master/k8s/charts/seaweedfs)
- [ADR-004: Storage Strategy](../../docs/adr/ADR-004-storage-strategy.md)
