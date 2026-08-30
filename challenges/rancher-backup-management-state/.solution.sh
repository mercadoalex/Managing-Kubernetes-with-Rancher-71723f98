#!/bin/bash
set -euo pipefail

# CI solution for "Back Up the Rancher Management State".
# Runs on the dev-machine workstation. The operator and the rancher-resource-set
# ResourceSet are already installed by the init tasks. Create a Backup and wait
# for it to complete.

export KUBECONFIG=$HOME/.kube/config

kubectl apply -f - <<'EOF'
apiVersion: resources.cattle.io/v1
kind: Backup
metadata:
  name: rancher-state-backup
spec:
  resourceSetName: rancher-resource-set
EOF

# Wait for the backup to finish: Ready condition True and a filename recorded.
for i in $(seq 1 36); do
  READY=$(kubectl get backup rancher-state-backup \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  FILE=$(kubectl get backup rancher-state-backup -o jsonpath='{.status.filename}' 2>/dev/null || true)
  if [ "${READY}" = "True" ] && [ -n "${FILE}" ]; then
    echo "Backup completed: ${FILE}"
    break
  fi
  sleep 5
done

examinerctl task wait verify_backup_completed --timeout 60s
