#!/bin/bash
set -euo pipefail

# CI solution for "Enforce a Pod Security Standard".
# Runs on the dev-machine workstation. The secure-apps namespace already exists
# (created by the baseline init task). Label it to enforce the restricted
# standard; the privileged pod then gets rejected by the API server.

export KUBECONFIG=$HOME/.kube/config

# Enforce the restricted Pod Security Standard on the namespace.
kubectl label namespace secure-apps \
  pod-security.kubernetes.io/enforce=restricted --overwrite

examinerctl task wait verify_namespace_enforced --timeout 30s
examinerctl task wait verify_privileged_pod_rejected --timeout 30s
