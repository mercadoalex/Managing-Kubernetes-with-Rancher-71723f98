#!/bin/bash
set -euo pipefail

# NOTE: The intended solution is a UI action (create the namespace in Rancher's
# Cluster Explorer). This script exists only so CI can validate the challenge
# end-to-end. It reproduces what the Rancher UI does: it creates the namespace
# AND stamps the field.cattle.io/creatorId annotation that the second check
# looks for. A human should do this through the UI instead (see solution.md).

export KUBECONFIG="$HOME/.kube/config"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: rancher-explorer
  annotations:
    field.cattle.io/creatorId: user-solution-ci
EOF

examinerctl task wait verify_namespace_exists --timeout 30s
examinerctl task wait verify_created_via_ui --timeout 30s
