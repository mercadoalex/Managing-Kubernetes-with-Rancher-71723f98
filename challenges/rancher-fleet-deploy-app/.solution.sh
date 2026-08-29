#!/bin/bash
set -euo pipefail

# Create a GitRepo pointing at the fleet-examples 'simple' path
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
examinerctl task wait verify_bundle_ready --timeout 180s
examinerctl task wait verify_workload_deployed --timeout 120s
