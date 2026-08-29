#!/bin/bash
set -euo pipefail

# CI solution for "Import a Downstream Cluster into Rancher".
#
# Runs on the dev-machine workstation. The UI performs three actions when you
# import a Generic cluster; this script does the same programmatically so CI can
# pass headlessly:
#   1. Create a clusters.management.cattle.io object on the upstream (Rancher).
#   2. Build the registration manifest URL from the token Rancher mints for it.
#   3. Apply that manifest on the downstream cluster (over SSH to downstream-01),
#      which installs the cluster agent and completes the import.
#
# Two details learned from the live playground and baked in here:
#   - Rancher runs in self-signed HTTPS mode on NodePort 30443, reached via the
#     sslip.io hostname (matches server-url and the cert SAN). Plain HTTP 30080
#     just redirects to https, so we use https + --insecure.
#   - In this Rancher version the token value is NOT in the CR's status.token
#     field (that stays empty and status.manifestUrl carries a literal {token}
#     placeholder). The real token lives in the secret crt-token-default-token
#     in the cluster's namespace, so we read it from there and build the URL.

export KUBECONFIG=$HOME/.kube/config

RANCHER_URL="https://172.16.0.2.sslip.io:30443"

# Wait for Rancher's management API.
for i in $(seq 1 60); do
  kubectl get clusters.management.cattle.io local >/dev/null 2>&1 && break
  sleep 4
done

# 1. Create the imported-cluster object. Rancher assigns it a generated name
#    (c-xxxxx) and creates a same-named namespace to hold its registration token.
CLUSTER_ID=$(kubectl create -f - -o jsonpath='{.metadata.name}' <<'EOF'
apiVersion: management.cattle.io/v3
kind: Cluster
metadata:
  generateName: c-
spec:
  displayName: downstream
EOF
)
echo "Created cluster object: ${CLUSTER_ID}"

# 2. Rancher mints a registration token whose value lands in the secret
#    crt-token-default-token in the cluster's namespace. Poll for it, decode it,
#    and assemble the import manifest URL.
TOKEN=""
for i in $(seq 1 60); do
  TOKEN=$(kubectl -n "${CLUSTER_ID}" get secret crt-token-default-token \
    -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || true)
  [ -n "${TOKEN}" ] && break
  sleep 4
done
if [ -z "${TOKEN}" ]; then
  echo "Registration token never appeared"
  exit 1
fi
MANIFEST_URL="${RANCHER_URL}/v3/import/${TOKEN}_${CLUSTER_ID}.yaml"
echo "Registration manifest URL: ${MANIFEST_URL}"

# 3. Apply the registration manifest on the downstream cluster. The agent must
#    be installed there, so we SSH to downstream-01 and use its k3s kubectl.
#    --insecure because the playground Rancher uses a self-signed certificate.
ssh -nT -o StrictHostKeyChecking=no downstream-01 \
  "curl --insecure -sfL '${MANIFEST_URL}' | sudo k3s kubectl apply -f -"

# Wait for the imported cluster to reach Ready.
for i in $(seq 1 60); do
  READY=$(kubectl get clusters.management.cattle.io "${CLUSTER_ID}" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  [ "${READY}" = "True" ] && break
  sleep 5
done

examinerctl task wait verify_cluster_imported --timeout 60s
examinerctl task wait verify_cluster_active --timeout 240s
