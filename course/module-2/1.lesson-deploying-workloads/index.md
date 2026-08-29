---
kind: lesson

title: Deploying Workloads with Rancher
description: |
  Create deployments, expose them with services and ingress, and manage scaling through Rancher.

name: deploying-workloads
slug: deploying-workloads

createdAt: 2026-08-27
updatedAt: 2026-08-27

categories:
- kubernetes

tagz:
- rancher
- workloads

# cover: __static__/cover.png

playground:
  name: rancher-k3s-e09b66ec

challenges:
  rancher-deploy-expose-app-0956816a: {}

tasks:
  # Tasks run on the dev-machine workstation as laborant, using the
  # pre-provisioned kubeconfig at ~/.kube/config.
  verify_deployment:
    machine: dev-machine
    user: laborant
    run: |
      export KUBECONFIG=$HOME/.kube/config
      READY=$(kubectl -n demo get deployment web -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
      if [ -z "${READY}" ] || [ "${READY}" -lt 1 ]; then
        echo "Deployment 'web' in namespace 'demo' is not running yet"
        exit 1
      fi
      echo "Deployment 'web' is running with ${READY} ready replica(s)"

  verify_service:
    machine: dev-machine
    user: laborant
    needs:
      - verify_deployment
    run: |
      export KUBECONFIG=$HOME/.kube/config
      if ! kubectl -n demo get svc web >/dev/null 2>&1; then
        echo "No service named 'web' in namespace 'demo' yet"
        exit 1
      fi
      EP=$(kubectl -n demo get endpoints web -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null)
      if [ -z "${EP}" ]; then
        echo "Service 'web' has no backing endpoints yet"
        exit 1
      fi
      echo "Service 'web' is exposing the deployment"

  verify_scaled:
    machine: dev-machine
    user: laborant
    needs:
      - verify_service
    run: |
      export KUBECONFIG=$HOME/.kube/config
      READY=$(kubectl -n demo get deployment web -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
      READY=${READY:-0}
      if [ "${READY}" -lt 3 ]; then
        echo "Deployment 'web' has ${READY} ready replica(s); scale it to at least 3"
        exit 1
      fi
      echo "Deployment 'web' is scaled to ${READY} replicas - lesson complete"
---
