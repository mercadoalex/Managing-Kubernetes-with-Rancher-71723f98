---
kind: lesson

title: Day-2 Operations
description: |
  Install the Rancher Backup operator and produce a completed backup of the Rancher management state, then survey the wider data-protection landscape.

name: day-2-operations
slug: day-2-operations

createdAt: 2026-08-27
updatedAt: 2026-08-27

categories:
- kubernetes

tagz:
- rancher
- backup
- disaster-recovery

# cover: __static__/cover.png

# Single-cluster playground with Rancher pre-installed (dev-machine workstation).
# Backup work is driven from the dev-machine with Helm and kubectl.
playground:
  name: rancher-k3s-e09b66ec

challenges:
  rancher-backup-management-state-d6b7da83: {}

tasks:
  # Verification runs on the dev-machine workstation as laborant, against the
  # cluster via the pre-provisioned kubeconfig.
  verify_operator_installed:
    machine: dev-machine
    user: laborant
    run: |
      export KUBECONFIG=$HOME/.kube/config
      # The rancher-backup operator must be deployed and available.
      AVAIL=$(kubectl -n cattle-resources-system get deploy rancher-backup \
        -o jsonpath='{.status.availableReplicas}' 2>/dev/null || true)
      if [ "${AVAIL:-0}" -lt 1 ] 2>/dev/null; then
        echo "The rancher-backup operator is not available yet in cattle-resources-system"
        exit 1
      fi
      echo "The rancher-backup operator is running"

  verify_backup_completed:
    machine: dev-machine
    user: laborant
    needs:
      - verify_operator_installed
    run: |
      export KUBECONFIG=$HOME/.kube/config
      # A Backup must exist AND have completed: its Ready condition is True and
      # it recorded the filename of the archive it produced.
      READY=""
      FILE=""
      for b in $(kubectl get backup -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true); do
        R=$(kubectl get backup "$b" \
          -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
        F=$(kubectl get backup "$b" -o jsonpath='{.status.filename}' 2>/dev/null || true)
        if [ "$R" = "True" ] && [ -n "$F" ]; then
          READY="True"; FILE="$F"; break
        fi
      done
      if [ "$READY" = "True" ] && [ -n "$FILE" ]; then
        echo "A backup completed successfully: ${FILE}"
        exit 0
      fi
      echo "No completed backup found yet (need a Backup with Ready=True and a filename set)"
      exit 1
---
