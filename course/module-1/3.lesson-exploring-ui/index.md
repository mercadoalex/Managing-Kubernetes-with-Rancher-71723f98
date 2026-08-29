---
kind: lesson

title: Exploring the Rancher UI
description: |
  Navigate the Rancher dashboard - cluster explorer, workload views, and global settings.

name: exploring-rancher-ui
slug: exploring-rancher-ui

createdAt: 2026-08-27
updatedAt: 2026-08-27

categories:
- kubernetes

tagz:
- rancher
- ui

# cover: __static__/cover.png

playground:
  name: rancher-k3s-e09b66ec

challenges:
  rancher-create-namespace-ui-a41237c6: {}

tasks:
  # Tasks run on the dev-machine workstation as laborant, using the
  # pre-provisioned kubeconfig at ~/.kube/config.
  verify_local_cluster:
    machine: dev-machine
    user: laborant
    run: |
      export KUBECONFIG=$HOME/.kube/config
      READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready")
      if [ "${READY:-0}" -lt 1 ]; then
        echo "The local cluster is not reachable yet"
        exit 1
      fi
      echo "Local cluster reachable with ${READY} Ready node(s)"

  verify_lesson_complete:
    machine: dev-machine
    user: laborant
    needs:
      - verify_local_cluster
    run: |
      export KUBECONFIG=$HOME/.kube/config
      # Rancher must be running for the UI tour to make sense.
      REPLICAS=$(kubectl -n cattle-system get deployment rancher -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
      if [ -z "${REPLICAS}" ] || [ "${REPLICAS}" -lt 1 ]; then
        echo "Rancher is not running yet"
        exit 1
      fi
      echo "Rancher is running - lesson environment ready"
---
