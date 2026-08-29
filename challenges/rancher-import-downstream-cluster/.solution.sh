#!/bin/bash
set -euo pipefail

# CI solution for "Import a Downstream Cluster into Rancher".
#
# Runs on the dev-machine workstation. The UI performs three actions when you
# import a Generic cluster; this script does the same programmatically so CI can
# pass headlessly:
#   1. Create a clusters.management.cattle.io object on the upstream (Rancher).
#   2. Read the registration manifest URL Rancher generates for it.
#   3. Apply that manifest on the downstream cluster (over SSH to downstream-01),
#      which installs the cluster agent and completes the import.

export KUBECONFIG=$HOME/.kube/config

# Wait for Rancher's management API.
for i in $(seq 1 60); do
  kubectl get clusters.management.cattle.io local >/dev/null 2>&1 && break
  sleep 4
done

# 1. Create the imported-cluster object. Rancher assigns it a generated name
#    (c-xxxxx) and creates a same-named namespace to hold its registration token.
cat <<'EOF' | kubectl create -f - -o jsonpath='{.metadata.name}' > /tmp/cluster_id
apiVersion: management.cattle.io/v3
kind: Cluster
metadata:
  generateName: c-
spec:
  displayName: downstream
EOF
CLUSTER_ID=$(cat /tmp/cluster_id)
echo "Created cluster object: ${CLUSTER_ID}"

# 2. Rancher auto-creates a clusterregistrationtoken in the cluster's namespace.
#    Poll for its manifest URL (the same URL the UI shows in the import command).
MANIFEST_URL=""
for i in $(seq 1 60); do
  MANIFEST_URL=$(kubectl -n "${CLUSTER_ID}" get clusterregistrationtokens.management.cattle.io \
    -o jsonpath='{.items[0].status.manifestUrl}' 2>/dev/null || true)
  [ -n "${MANIFEST_URL}" ] && break
  sleep 4
done
if [ -z "${MANIFEST_URL}" ]; then
  echo "Registration manifest URL never appeared"
  exit 1
fi
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
