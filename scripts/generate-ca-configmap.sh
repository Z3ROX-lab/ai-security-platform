#!/bin/bash
# generate-ca-configmap.sh
# Generates the keycloak-ca-cert ConfigMap for OpenWebUI
# Required for: Entra ID federation (HTTPS trust)
set -e
echo "=== Generating CA cert bundle for OpenWebUI ==="
echo "[1/4] Extracting platform CA root cert..."
kubectl get secret -n cert-manager ai-platform-ca-secret \
  -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/ca-root.crt
echo "[2/4] Extracting system CA bundle from OpenWebUI pod..."
kubectl exec -n ai-apps open-webui-0 -c open-webui -- \
  cat /etc/ssl/certs/ca-certificates.crt > /tmp/combined.crt
echo "[3/4] Combining CA bundles..."
cat /tmp/ca-root.crt >> /tmp/combined.crt
echo "[4/4] Creating ConfigMap keycloak-ca-cert in ai-apps..."
kubectl delete configmap keycloak-ca-cert -n ai-apps --ignore-not-found
kubectl create configmap keycloak-ca-cert -n ai-apps \
  --from-file=ca-certificates.crt=/tmp/combined.crt
rm -f /tmp/ca-root.crt /tmp/combined.crt
echo "Done! Restart OpenWebUI: kubectl delete pod -n ai-apps open-webui-0"
