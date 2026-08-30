---
kind: challenge

title: 'Enforce a Pod Security Standard'

description: |
  Harden a namespace so Kubernetes refuses to run unsafe workloads. Enforce the
  restricted Pod Security Standard on a namespace and confirm that a privileged
  pod is rejected by the API server - a built-in security control that stops
  dangerous containers before they ever start.

categories:
  - kubernetes
  - security

tagz:
  - Rancher
  - pod-security
  - admission-control

difficulty: medium

createdAt: 2026-08-27
updatedAt: 2026-08-27

# Single-cluster playground with Rancher pre-installed (dev-machine workstation).
# TODO(publish): replace with the live suffix if it changes.
playground:
  name: rancher-k3s-e09b66ec

tasks:
  # Baseline: create the target namespace with NO policy, and prove a privileged
  # pod is ACCEPTED there (server dry-run passes). This establishes that the
  # later rejection is caused by the policy, not by something else. Required by
  # the challenge-authoring rule for negative-condition checks.
  init_baseline:
    init: true
    machine: dev-machine
    user: laborant
    timeout_seconds: 180
    run: |
      export KUBECONFIG=$HOME/.kube/config
      for i in $(seq 1 45); do
        kubectl get nodes 2>/dev/null | grep -q " Ready" && break
        sleep 4
      done
      kubectl create namespace secure-apps 2>/dev/null || true
      # Confirm a privileged pod would be admitted while the namespace has no
      # enforce label (server dry-run runs admission but creates nothing).
      OUT=$(kubectl -n secure-apps run baseline-probe --image=nginx:1.27 \
        --dry-run=server \
        --overrides='{"spec":{"containers":[{"name":"baseline-probe","image":"nginx:1.27","securityContext":{"privileged":true}}]}}' 2>&1 || true)
      if echo "${OUT}" | grep -qiE "violat|forbidden|denied"; then
        echo "Unexpected: privileged pod rejected with no policy in place: ${OUT}"
        exit 1
      fi
      echo "Baseline confirmed: without a policy, a privileged pod is admitted"

  # Gate 1: the namespace enforces the restricted standard.
  verify_namespace_enforced:
    machine: dev-machine
    user: laborant
    needs:
      - init_baseline
    run: |
      rm -f /tmp/verify_ns_hint.txt
      export KUBECONFIG=$HOME/.kube/config
      LEVEL=$(kubectl get namespace secure-apps \
        -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)
      if [ "${LEVEL}" != "restricted" ]; then
        echo "Namespace secure-apps does not enforce the restricted standard yet (found: '${LEVEL:-none}'). Add the pod-security.kubernetes.io/enforce=restricted label." \
          | tee /tmp/verify_ns_hint.txt
        exit 1
      fi
      echo "secure-apps enforces the restricted Pod Security Standard"
    hintcheck: |
      if [ -f /tmp/verify_ns_hint.txt ]; then
        cat /tmp/verify_ns_hint.txt
        rm -f /tmp/verify_ns_hint.txt
      fi

  # Gate 2: a privileged pod is now rejected by the enforced policy.
  verify_privileged_pod_rejected:
    machine: dev-machine
    user: laborant
    needs:
      - verify_namespace_enforced
    run: |
      rm -f /tmp/verify_reject_hint.txt
      export KUBECONFIG=$HOME/.kube/config
      # A rejected pod makes kubectl exit non-zero; capture the output without
      # letting that abort the task, then inspect it for the violation message.
      OUT=$(kubectl -n secure-apps run reject-probe --image=nginx:1.27 \
        --dry-run=server \
        --overrides='{"spec":{"containers":[{"name":"reject-probe","image":"nginx:1.27","securityContext":{"privileged":true}}]}}' 2>&1 || true)
      if echo "${OUT}" | grep -qiE "violat|forbidden|denied|restricted"; then
        echo "A privileged pod is rejected by the restricted policy"
        exit 0
      fi
      echo "A privileged pod was NOT rejected - the restricted standard is not enforcing on secure-apps." \
        | tee /tmp/verify_reject_hint.txt
      exit 1
    hintcheck: |
      if [ -f /tmp/verify_reject_hint.txt ]; then
        cat /tmp/verify_reject_hint.txt
        rm -f /tmp/verify_reject_hint.txt
      fi
---

Kubernetes will run almost anything you give it, including containers that run as root or ask for privileged access - exactly what an attacker wants. **Pod Security Admission** is a control built into the API server that rejects unsafe pods before they start, based on a standard you set per namespace.

This playground has a namespace called `secure-apps` that currently has no policy - a privileged pod would run there without complaint. You work from the :tab{text='dev-machine' machine='dev-machine'} workstation. Your job: enforce the `restricted` standard on `secure-apps` and confirm an unsafe pod is turned away.

## Step 1: Enforce the Restricted Standard

Label the `secure-apps` namespace so the API server enforces the `restricted` Pod Security Standard on every pod created in it.

::simple-task
---
:tasks: tasks
:name: verify_namespace_enforced
---
#active
Waiting for secure-apps to enforce the restricted standard...

#completed
The namespace enforces the restricted Pod Security Standard.
::

::hint-box
---
:summary: Hint 1 - the label
---
Pod Security Admission is driven by a namespace label. The enforce level uses the key `pod-security.kubernetes.io/enforce` with a value of `privileged`, `baseline`, or `restricted`. Set it with `kubectl label namespace ...`.
::

## Step 2: Confirm an Unsafe Pod Is Rejected

With `restricted` enforced, a privileged pod must be refused by the API server. Prove it.

::simple-task
---
:tasks: tasks
:name: verify_privileged_pod_rejected
---
#active
Waiting for the restricted standard to reject a privileged pod...

#completed
The privileged pod was rejected. Your namespace is hardened. Well done.
::

::hint-box
---
:summary: Hint 2 - trigger the rejection
---
Try to create a pod with a container whose `securityContext` sets `privileged: true` in the `secure-apps` namespace. The API server should refuse it with a Pod Security violation instead of scheduling it. A server-side dry run (`kubectl run ... --dry-run=server`) is enough to see the rejection without creating anything.
::
