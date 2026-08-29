---
kind: challenge

title: 'Deploy an Application with a Fleet GitRepo'

description: |
  Use Rancher Fleet to deploy an application from a Git repository to the local cluster.
  Create a GitRepo resource, watch Fleet turn it into a Bundle, and confirm the workload lands - the core GitOps loop.

categories:
  - kubernetes
  - containers

tagz:
  - Rancher
  - Fleet
  - GitOps
  - Bundles

difficulty: medium

createdAt: 2026-08-27
updatedAt: 2026-08-27

playground:
  name: ubuntu-k3s-bare

tasks:
  init_wait_k3s:
    init: true
    run: |
      for i in $(seq 1 30); do
        if kubectl get nodes | grep -q " Ready"; then
          exit 0
        fi
        sleep 2
      done
      echo "K3s did not become ready in time"
      exit 1

  init_install_fleet:
    init: true
    needs:
      - init_wait_k3s
    run: |
      if kubectl get crd gitrepos.fleet.cattle.io >/dev/null 2>&1 \
         && kubectl -n cattle-fleet-system get deployment fleet-controller >/dev/null 2>&1; then
        exit 0
      fi
      helm -n cattle-fleet-system install --create-namespace --wait \
        fleet-crd oci://reg.rancher.com/rancher/fleet-crd
      helm -n cattle-fleet-system install --create-namespace --wait \
        fleet oci://reg.rancher.com/rancher/fleet

      # Wait for the local cluster to register before the student starts.
      for i in $(seq 1 60); do
        if kubectl -n fleet-local get clusters.fleet.cattle.io \
            -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | grep -q .; then
          exit 0
        fi
        sleep 5
      done
      echo "Fleet local cluster did not register in time"
      exit 1

  verify_gitrepo_exists:
    run: |
      rm -f /tmp/verify_gitrepo_hint.txt

      GR=$(kubectl -n fleet-local get gitrepo -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
      if [ -z "${GR}" ]; then
        echo "No GitRepo found in the fleet-local namespace" | tee /tmp/verify_gitrepo_hint.txt
        exit 1
      fi

      echo "${GR}"
    hintcheck: |
      if [ -f /tmp/verify_gitrepo_hint.txt ]; then
        cat /tmp/verify_gitrepo_hint.txt
        rm -f /tmp/verify_gitrepo_hint.txt
      fi

  verify_bundle_ready:
    needs:
      - verify_gitrepo_exists
    run: |
      rm -f /tmp/verify_bundle_hint.txt

      # Fleet turns each deployable path in the GitRepo into a Bundle.
      # Wait for at least one bundle to reach Ready.
      for i in $(seq 1 30); do
        READY=$(kubectl -n fleet-local get bundles \
          -o jsonpath='{range .items[*]}{.status.summary.ready}{" "}{.status.summary.desiredReady}{"\n"}{end}' 2>/dev/null \
          | awk 'NF==2 && $1>0 && $1==$2' | wc -l)
        if [ "${READY:-0}" -ge 1 ]; then
          echo "At least one Fleet bundle is Ready"
          exit 0
        fi
        sleep 5
      done
      echo "No Fleet bundle reached the Ready state" | tee /tmp/verify_bundle_hint.txt
      exit 1
    hintcheck: |
      if [ -f /tmp/verify_bundle_hint.txt ]; then
        cat /tmp/verify_bundle_hint.txt
        rm -f /tmp/verify_bundle_hint.txt
      fi

  verify_workload_deployed:
    needs:
      - verify_bundle_ready
    run: |
      rm -f /tmp/verify_workload_hint.txt

      # The fleet-examples 'simple' path deploys a workload into the
      # fleet-mc-simple-example / simple-app namespace. Rather than hardcode a
      # namespace, confirm Fleet actually created a Deployment somewhere via a bundle.
      FOUND=$(kubectl get deployments -A \
        -l objectset.rio.cattle.io/hash \
        -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null | head -n1)
      if [ -z "${FOUND}" ]; then
        # Fall back: any deployment owned by a fleet bundle labels its resources.
        FOUND=$(kubectl get deployments -A \
          -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name} {.metadata.labels}{"\n"}{end}' 2>/dev/null \
          | grep -i "fleet" | head -n1)
      fi
      if [ -z "${FOUND}" ]; then
        echo "No Fleet-managed Deployment found yet. Give the bundle time to apply its resources." | tee /tmp/verify_workload_hint.txt
        exit 1
      fi

      echo "Fleet deployed a workload: ${FOUND}"
    hintcheck: |
      if [ -f /tmp/verify_workload_hint.txt ]; then
        cat /tmp/verify_workload_hint.txt
        rm -f /tmp/verify_workload_hint.txt
      fi
---

Fleet's promise is simple: point it at a Git repository, and it keeps your cluster matching what is in Git. It does this by turning each deployable path in a repo into a Bundle, then applying that bundle to every targeted cluster and watching for drift.

Fleet is already installed on this single-node cluster and the local cluster is registered. Your job is to create a GitRepo that pulls a sample application from a public repository and let Fleet deploy it.

## Step 1: Create a GitRepo

Create a `GitRepo` in the `fleet-local` namespace that points at a public example repository and a path containing deployable manifests.

::simple-task
---
:tasks: tasks
:name: verify_gitrepo_exists
---
#active
Waiting for a GitRepo in fleet-local...

#completed
A GitRepo exists in fleet-local.
::

::hint-box
---
:summary: Hint 1
---
The `rancher/fleet-examples` repository is the canonical source for this. A GitRepo needs a `repo`, a `branch`, and one or more `paths`. Target the local cluster with a `clusterSelector` (an empty selector matches every cluster in the namespace).
::

## Step 2: Watch Fleet Build a Bundle

Fleet converts the GitRepo path into a Bundle and deploys it. The bundle should reach the `Ready` state.

::simple-task
---
:tasks: tasks
:name: verify_bundle_ready
---
#active
Waiting for a Fleet bundle to become Ready...

#completed
A Fleet bundle is Ready.
::

::hint-box
---
:summary: Hint 2
---
Watch `kubectl -n fleet-local get bundles`. A bundle moves from `NotReady` to `Ready` as its resources apply. If it stays `NotReady`, describe the GitRepo and the bundle to see the error - a wrong path or branch is the usual cause.
::

## Step 3: Confirm the Workload Landed

Once the bundle is ready, Fleet has applied the manifests. Confirm a workload created by Fleet is present on the cluster.

::simple-task
---
:tasks: tasks
:name: verify_workload_deployed
---
#active
Waiting for a Fleet-managed workload...

#completed
Fleet deployed the application. Well done.
::

::hint-box
---
:summary: Hint 3
---
Fleet labels the resources it manages. If you do not see a workload, the bundle may still be applying, or the chosen path may not contain a Deployment - pick a path from fleet-examples that deploys one (the `simple` example does).
::
