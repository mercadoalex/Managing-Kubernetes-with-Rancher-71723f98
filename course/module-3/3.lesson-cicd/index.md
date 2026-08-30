---
kind: lesson

title: CI/CD with Rancher Fleet and a Git Server
description: |
  Run the real GitOps loop against a Git server you own - commit a change and watch Fleet reconcile it onto the cluster.

name: cicd-pipelines-rancher
slug: cicd-pipelines-rancher

createdAt: 2026-08-27
updatedAt: 2026-08-27

categories:
- kubernetes

tagz:
- rancher
- cicd
- fleet

# cover: __static__/cover.png

# CI/CD playground: Rancher (with Fleet) + a self-hosted Gitea Git server on its
# own machine. See playgrounds/rancher-k3s-gitea/manifest.yaml.
# TODO(publish): if the suffix changes, update it here.
playground:
  name: rancher-k3s-gitea-6cdd37fb

challenges:
  rancher-cicd-pipeline-b05d22e8: {}

tasks:
  # Verification runs on the dev-machine workstation as laborant, against the
  # Rancher (local) cluster. The GitRepo points at the self-hosted Gitea server.
  verify_gitrepo_to_gitea:
    machine: dev-machine
    user: laborant
    run: |
      export KUBECONFIG=$HOME/.kube/config
      # A GitRepo in fleet-local whose repo URL is the in-cluster-reachable
      # Gitea address (the node IP, not the 'gitea' hostname - cluster pods use
      # CoreDNS and cannot resolve VM machine names).
      MATCH=$(kubectl -n fleet-local get gitrepo \
        -o jsonpath='{range .items[*]}{.spec.repo}{"\n"}{end}' 2>/dev/null \
        | grep -c '172.16.0.4:3000')
      if [ "${MATCH:-0}" -lt 1 ]; then
        echo "No GitRepo pointing at the Gitea server (172.16.0.4:3000) yet"
        exit 1
      fi
      echo "GitRepo targets the self-hosted Gitea server"

  verify_reconciled_change:
    machine: dev-machine
    user: laborant
    needs:
      - verify_gitrepo_to_gitea
    timeout_seconds: 240
    run: |
      export KUBECONFIG=$HOME/.kube/config
      # The seed ships web with replicas: 1. The exercise is to commit a change
      # (scale up) to Gitea and let Fleet reconcile it. Confirm the running
      # Deployment now has more than 1 replica - proof the commit reached the
      # cluster through Fleet, not through a manual kubectl apply.
      for i in $(seq 1 30); do
        R=$(kubectl get deploy web -o jsonpath='{.spec.replicas}' 2>/dev/null)
        if [ -n "${R}" ] && [ "${R}" -gt 1 ]; then
          echo "Fleet reconciled a committed change: web now has ${R} replicas"
          exit 0
        fi
        sleep 6
      done
      echo "web is not scaled above 1 yet; commit a replica change to Gitea and let Fleet reconcile it"
      exit 1
---
