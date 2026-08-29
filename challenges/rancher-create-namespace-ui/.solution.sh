#!/bin/bash
set -euo pipefail

# NOTE: The intended solution is a UI action (create the namespace in Rancher's
# Cluster Explorer). This script exists only so CI can validate the challenge
# end-to-end. It reproduces what the Rancher UI does: it creates the namespace
# AND assigns it to a Rancher Project via the field.cattle.io/projectId
# annotation/label that the second check looks for. A human should do this
# through the UI instead (see solution.md).

export KUBECONFIG="$HOME/.kube/config"

# Discover the local cluster's default project id (Rancher assigns UI-created
# namespaces to a project; we mimic that here).
PROJECT_ID=$(kubectl -n local get projects.management.cattle.io \
  -o jsonpath='{.items[?(@.spec.displayName=="Default")].metadata.name}' 2>/dev/null)
PROJECT_ID=${PROJECT_ID:-p-default}

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: rancher-explorer
  annotations:
    field.cattle.io/projectId: "local:${PROJECT_ID}"
  labels:
    field.cattle.io/projectId: "${PROJECT_ID}"
EOF

examinerctl task wait verify_namespace_exists --timeout 30s
examinerctl task wait verify_created_via_ui --timeout 30s
