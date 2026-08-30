#!/bin/bash
set -euo pipefail

# CI solution for "Ship a Change Through Fleet and a Git Server".
# Runs on the dev-machine workstation. Points Fleet at the self-hosted Gitea
# repo, then commits a scale-up and lets Fleet reconcile it - the same loop the
# student performs by hand.
#
# NOTE: the GitRepo and git URLs use the Gitea server IP (172.16.0.4:3000), not
# the 'gitea' hostname. Fleet clones from a cluster pod, and cluster DNS does
# not resolve VM machine names - validated live.

export KUBECONFIG=$HOME/.kube/config

# 1. Point Fleet at the Gitea repo (targets the local cluster via fleet-local).
cat <<EOF | kubectl apply -f -
apiVersion: fleet.cattle.io/v1alpha1
kind: GitRepo
metadata:
  name: web-app
  namespace: fleet-local
spec:
  repo: http://172.16.0.4:3000/student/sample-app
  branch: main
  paths:
  - manifests
  targets:
  - clusterSelector: {}
EOF

examinerctl task wait verify_gitrepo_to_gitea --timeout 60s
examinerctl task wait verify_app_deployed --timeout 240s

# 2. Commit a change (scale to 3) to Gitea and let Fleet reconcile it.
rm -rf /tmp/sample-app
git clone http://student:student@172.16.0.4:3000/student/sample-app.git /tmp/sample-app
cd /tmp/sample-app
sed -i 's/replicas: 1/replicas: 3/' manifests/web.yaml
git -c user.email=student@example.com -c user.name=student commit -am "Scale web to 3 replicas"
git push origin main

examinerctl task wait verify_committed_change_reconciled --timeout 240s
