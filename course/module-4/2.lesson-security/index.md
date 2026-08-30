---
kind: lesson

title: Security and Access Control
description: |
  Enforce a Pod Security Standard on a namespace and watch Kubernetes reject an unsafe workload.

name: security-and-access-control
slug: security-and-access-control

createdAt: 2026-08-27
updatedAt: 2026-08-27

categories:
- kubernetes
- security

tagz:
- rancher
- pod-security
- admission-control

# cover: __static__/cover.png

# Single-cluster playground with Rancher pre-installed (dev-machine workstation).
playground:
  name: rancher-k3s-e09b66ec

challenges:
  rancher-enforce-pod-security-9d671d94: {}

tasks:
  # Verification runs on the dev-machine workstation as laborant, against the
  # cluster via the pre-provisioned kubeconfig.
  verify_namespace_enforced:
    machine: dev-machine
    user: laborant
    run: |
      export KUBECONFIG=$HOME/.kube/config
      # The secure-apps namespace must enforce the "restricted" Pod Security
      # Standard via the enforce label.
      LEVEL=$(kubectl get namespace secure-apps \
        -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)
      if [ "${LEVEL}" != "restricted" ]; then
        echo "Namespace secure-apps does not enforce the restricted standard yet (found: '${LEVEL:-none}')"
        exit 1
      fi
      echo "secure-apps enforces the restricted Pod Security Standard"

  verify_privileged_pod_rejected:
    machine: dev-machine
    user: laborant
    needs:
      - verify_namespace_enforced
    run: |
      export KUBECONFIG=$HOME/.kube/config
      # With restricted enforced, a privileged pod must be rejected by the API
      # server. We attempt a dry-run apply of a privileged pod and require it to
      # FAIL. (Dry-run still runs admission, so PSA rejects it without creating
      # anything.) If it is accepted, the policy is not actually enforcing.
      OUT=$(kubectl -n secure-apps run psa-probe --image=nginx:1.27 \
        --dry-run=server \
        --overrides='{"spec":{"containers":[{"name":"psa-probe","image":"nginx:1.27","securityContext":{"privileged":true}}]}}' 2>&1 || true)
      if echo "${OUT}" | grep -qiE "violat|forbidden|denied|restricted"; then
        echo "A privileged pod is rejected by the restricted policy"
        exit 0
      fi
      echo "A privileged pod was NOT rejected - the restricted standard is not enforcing"
      exit 1
---
