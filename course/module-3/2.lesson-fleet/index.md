---
kind: lesson

title: GitOps with Rancher Fleet
description: |
  Use Rancher Fleet to deploy applications from Git and keep clusters matching what is in the repository.

name: gitops-rancher-fleet
slug: gitops-rancher-fleet

createdAt: 2026-08-27
updatedAt: 2026-08-27

categories:
- kubernetes

tagz:
- rancher
- fleet
- gitops

# cover: __static__/cover.png

# Same two-cluster playground as the multi-cluster lesson. Fleet ships with
# Rancher (in cattle-fleet-system), so nothing extra is installed - the lesson
# uses the Fleet that is already running on the upstream cluster.
playground:
  name: rancher-k3s-downstream-54528e97

challenges:
  rancher-fleet-deploy-app-db93d774: {}

tasks:
  # Verification runs on the dev-machine workstation as laborant, against the
  # upstream Rancher cluster via the pre-provisioned kubeconfig. Fleet objects
  # for the local cluster live in the fleet-local namespace.
  verify_gitrepo_exists:
    machine: dev-machine
    user: laborant
    run: |
      export KUBECONFIG=$HOME/.kube/config
      GR=$(kubectl -n fleet-local get gitrepo \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
      if [ -z "${GR}" ]; then
        echo "No GitRepo found in the fleet-local namespace yet"
        exit 1
      fi
      echo "${GR}"

  verify_workload_deployed:
    machine: dev-machine
    user: laborant
    needs:
      - verify_gitrepo_exists
    run: |
      export KUBECONFIG=$HOME/.kube/config
      # Fleet turns the GitRepo path into a Bundle and applies it. Confirm at
      # least one bundle reached Ready, which only happens once its resources
      # are successfully applied to the cluster.
      for i in $(seq 1 30); do
        READY=$(kubectl -n fleet-local get bundles \
          -o jsonpath='{range .items[*]}{.status.summary.ready}{" "}{.status.summary.desiredReady}{"\n"}{end}' 2>/dev/null \
          | awk 'NF==2 && $1>0 && $1==$2' | wc -l | tr -d ' ')
        if [ "${READY:-0}" -ge 1 ]; then
          echo "A Fleet bundle is Ready and its workload is applied"
          exit 0
        fi
        sleep 5
      done
      echo "No Fleet bundle reached Ready yet; give it time to apply"
      exit 1
---
