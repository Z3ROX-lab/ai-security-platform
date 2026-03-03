#!/bin/bash
# post-deploy-entra-id.sh
# Run after ArgoCD sync to apply patches not supported by Helm chart
# 1. Generate CA cert ConfigMap
# 2. Patch OpenWebUI StatefulSet with volume mount
set -e
echo "=== Post-deploy: Entra ID federation patches ==="

# 1. Generate CA cert bundle
echo "[1/3] Generating CA cert bundle..."
kubectl get secret -n cert-manager ai-platform-ca-secret \
  -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/ca-root.crt
kubectl exec -n ai-apps open-webui-0 -c open-webui -- \
  cat /etc/ssl/certs/ca-certificates.crt > /tmp/combined.crt
cat /tmp/ca-root.crt >> /tmp/combined.crt
kubectl delete configmap keycloak-ca-cert -n ai-apps --ignore-not-found
kubectl create configmap keycloak-ca-cert -n ai-apps \
  --from-file=ca-certificates.crt=/tmp/combined.crt

# 2. Patch StatefulSet with volume
echo "[2/3] Patching OpenWebUI StatefulSet..."
kubectl patch statefulset -n ai-apps open-webui --type=json -p='[
  {"op":"add","path":"/spec/template/spec/volumes/-","value":{"name":"keycloak-ca","configMap":{"name":"keycloak-ca-cert"}}},
  {"op":"add","path":"/spec/template/spec/containers/0/volumeMounts/-","value":{"name":"keycloak-ca","mountPath":"/etc/ssl/keycloak","readOnly":true}}
]'

# 3. Restart pod
echo "[3/3] Restarting OpenWebUI..."
kubectl delete pod -n ai-apps open-webui-0
kubectl wait --for=condition=ready pod/open-webui-0 -n ai-apps --timeout=120s

rm -f /tmp/ca-root.crt /tmp/combined.crt
echo "=== Done! Entra ID federation ready ==="
