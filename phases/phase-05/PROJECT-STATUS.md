# AI Security Platform - Project Status

**Last Updated:** 2025-01-29

---

## Current State

### Infrastructure ✅ COMPLETE

| Component | Status | URL |
|-----------|--------|-----|
| K3d Cluster | ✅ Running | - |
| ArgoCD | ✅ Running | https://argocd.ai-platform.localhost |
| Traefik | ✅ Running | - |
| cert-manager | ✅ Running | - |

### Storage ✅ COMPLETE

| Component | Status | Notes |
|-----------|--------|-------|
| PostgreSQL (CNPG) | ✅ Running | 3 replicas, storage namespace |
| SeaweedFS | 🔲 NOT DEPLOYED | Planned for RAG phase |

### Security ✅ COMPLETE

| Component | Status | Notes |
|-----------|--------|-------|
| Keycloak | ✅ Running | https://auth.ai-platform.localhost |
| Sealed Secrets | ✅ Running | kubeseal CLI installed |
| NetworkPolicies | ✅ Configured | PostgreSQL, cross-namespace |
| Pod Security Standards | ✅ Enforced | Restricted on app namespaces |

### AI Stack ⚠️ IN PROGRESS

| Component | Status | Notes |
|-----------|--------|-------|
| Ollama | ✅ Running | Mistral 7B loaded |
| Open WebUI | ✅ Running | https://chat.ai-platform.localhost |
| Keycloak SSO | ⚠️ TESTING | CoreDNS configured, needs final test |
| Qdrant | 🔲 NOT DEPLOYED | Phase 6 |
| NeMo Guardrails | 🔲 NOT DEPLOYED | Phase 7 |

---

## Current Task: Keycloak SSO Integration

### What's Done
1. ✅ Created Keycloak client `open-webui` in realm `ai-platform`
2. ✅ Created SealedSecret for OIDC client secret
3. ✅ Configured Open WebUI with OIDC env vars
4. ✅ Fixed .gitignore for sealed secrets
5. ✅ Added CoreDNS entry for `auth.ai-platform.localhost`
6. ✅ Created users in Keycloak realm `ai-platform`

### What's Left
1. 🔲 Test SSO login in incognito browser
2. 🔲 Verify user creation in Open WebUI after SSO login
3. 🔲 Document the SSO integration

### Known Issues
- After laptop reboot, K3d network breaks → Solution: `k3d cluster stop/start`
- CoreDNS NodeHosts may need re-verification after cluster restart

### Test Procedure
1. Open incognito browser
2. Go to https://chat.ai-platform.localhost
3. Click "Continue with Keycloak"
4. Login with `zerotrust` / password
5. Should redirect back to Open WebUI logged in

---

## Documents Created (To Commit)

### ADRs
- [ ] ADR-011-llm-application-framework.md (LangChain)
- [ ] ADR-012-sovereign-llm-strategy.md (vLLM, Mistral, Fine-tuning)
- [ ] ADR-013-cni-strategy.md (Flannel vs Cilium)

### Knowledge Base
- [ ] langchain-guide.md
- [ ] kubernetes-security-architecture-guide.md
- [ ] sealed-secrets-guide.md
- [ ] k3d-troubleshooting-guide.md

### Location
All files available in `~/Downloads/` or `/mnt/user-data/outputs/`

---

## Next Steps (Priority Order)

1. **Test Keycloak SSO** - Validate login works
2. **Commit all docs** - Push to Git repository
3. **Phase 6: Qdrant** - Vector DB for RAG
4. **Phase 6: SeaweedFS** - Object storage for documents
5. **Phase 7: NeMo Guardrails** - LLM security

---

## Quick Commands

```bash
# After reboot
k3d cluster stop ai-security-platform
k3d cluster start ai-security-platform
kubectl get pods -A -w

# Check CoreDNS for auth.ai-platform.localhost
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.NodeHosts}'

# If missing, re-add:
kubectl patch configmap coredns -n kube-system --type='json' -p='[
  {"op": "replace", "path": "/data/NodeHosts", "value": "172.20.0.3 k3d-ai-security-platform-server-0\n172.20.0.2 k3d-ai-security-platform-agent-1\n172.20.0.4 k3d-ai-security-platform-agent-0\n10.43.233.142 auth.ai-platform.localhost\n"}
]'
kubectl rollout restart deployment coredns -n kube-system

# Test SSO
curl -k https://chat.ai-platform.localhost
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    AI SECURITY PLATFORM                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  INGRESS (Traefik)                                                      │
│  ├── chat.ai-platform.localhost    → Open WebUI (ai-apps)              │
│  ├── auth.ai-platform.localhost    → Keycloak (auth)                   │
│  └── argocd.ai-platform.localhost  → ArgoCD (argocd)                   │
│                                                                          │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐              │
│  │  Open WebUI │────▶│   Ollama    │────▶│  Mistral 7B │              │
│  │  (Chat UI)  │     │ (Inference) │     │   (Model)   │              │
│  └──────┬──────┘     └─────────────┘     └─────────────┘              │
│         │                                                               │
│         │ OIDC                                                          │
│         ▼                                                               │
│  ┌─────────────┐     ┌─────────────┐                                   │
│  │  Keycloak   │────▶│ PostgreSQL  │                                   │
│  │   (SSO)     │     │   (CNPG)    │                                   │
│  └─────────────┘     └─────────────┘                                   │
│                                                                          │
│  Security: TLS ✅ | NetworkPolicies ✅ | PSS ✅ | Sealed Secrets ✅    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```
