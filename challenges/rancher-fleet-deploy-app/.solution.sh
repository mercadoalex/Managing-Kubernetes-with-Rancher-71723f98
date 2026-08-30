#!/bin/bash
set -euo pipefail

# CI solution for "Deploy an Application with a Fleet GitRepo".
# Runs on the dev-machine workstation against the upstream Rancher cluster.
# Fleet ships with Rancher, so we just create a GitRepo in fleet-local (which
# targets the local cluster) and let Fleet build the bundle and apply it.

export KUBECONFIG=$HOME/.kube/config

# Create a GitRepo pointing at the fleet-examples 'simple' path. An empty
# clusterSelector targets every cluster in the namespace - here, the local one.
cat <<EOF | kubectl apply -f -
apiVersion: fleet.cattle.io/v1alpha1
kind: GitRepo
metadata:
  name: sample-app
  namespace: fleet-local
spec:
  repo: https://github.com/rancher/fleet-examples
  branch: master
  paths:
  - simple
  targets:
  - clusterSelector: {}
EOF

examinerctl task wait verify_gitrepo_exists --timeout 30s
examinerctl task wait verify_bundle_ready --timeout 240s
examinerctl task wait verify_workload_deployed --timeout 120s
