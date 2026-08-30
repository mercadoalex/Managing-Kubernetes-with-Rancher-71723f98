---
kind: challenge

title: 'Deploy an Application with a Fleet GitRepo'

description: |
  Use Rancher Fleet to deploy an application from a Git repository to the local
  cluster. Create a GitRepo resource, watch Fleet turn it into a Bundle, and
  confirm the workload lands - the core GitOps loop, driven by the Fleet that
  ships with Rancher.

categories:
  - kubernetes
  - containers

tagz:
  - Rancher
  - Fleet
  - gitops
  - bundles

difficulty: medium

createdAt: 2026-08-27
updatedAt: 2026-08-27

# Two-cluster playground (see playgrounds/rancher-k3s-downstream/manifest.yaml).
# Fleet ships with Rancher, so nothing is installed here - the tasks just wait
# for the Fleet that is already running on the upstream cluster.
# TODO(publish): replace with the suffixed name from
#   `labctl playground create rancher-k3s-downstream --base flexbox`.
playground:
  name: rancher-k3s-downstream-54528e97

tasks:
  # Wait for Rancher's bundled Fleet to be ready and for the local cluster to be
  # registered with it, so the student starts from a working Fleet.
  init_wait_fleet:
    init: true
    machine: dev-machine
    user: laborant
    timeout_seconds: 300
    run: |
      export KUBECONFIG=$HOME/.kube/config
      for i in $(seq 1 75); do
        if kubectl -n fleet-local get clusters.fleet.cattle.io \
            -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | grep -q .; then
          exit 0
        fi
        sleep 4
      done
      echo "Fleet local cluster did not register in time"
      exit 1

  # Gate step 1: a GitRepo exists in fleet-local.
  verify_gitrepo_exists:
    machine: dev-machine
    user: laborant
    needs:
      - init_wait_fleet
    run: |
      rm -f /tmp/verify_gitrepo_hint.txt
      export KUBECONFIG=$HOME/.kube/config
      GR=$(kubectl -n fleet-local get gitrepo \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
      if [ -z "${GR}" ]; then
        echo "No GitRepo found in the fleet-local namespace. Create one that points at a repo, branch, and path." \
          | tee /tmp/verify_gitrepo_hint.txt
        exit 1
      fi
      echo "${GR}"
    hintcheck: |
      if [ -f /tmp/verify_gitrepo_hint.txt ]; then
        cat /tmp/verify_gitrepo_hint.txt
        rm -f /tmp/verify_gitrepo_hint.txt
      fi

  # Gate step 2: Fleet turned the GitRepo into a Bundle that reached Ready.
  verify_bundle_ready:
    machine: dev-machine
    user: laborant
    needs:
      - verify_gitrepo_exists
    timeout_seconds: 240
    run: |
      rm -f /tmp/verify_bundle_hint.txt
      export KUBECONFIG=$HOME/.kube/config
      for i in $(seq 1 40); do
        READY=$(kubectl -n fleet-local get bundles \
          -o jsonpath='{range .items[*]}{.status.summary.ready}{" "}{.status.summary.desiredReady}{"\n"}{end}' 2>/dev/null \
          | awk 'NF==2 && $1>0 && $1==$2' | wc -l | tr -d ' ')
        if [ "${READY:-0}" -ge 1 ]; then
          echo "At least one Fleet bundle is Ready"
          exit 0
        fi
        sleep 5
      done
      echo "No Fleet bundle reached the Ready state. Check the GitRepo branch and path (fleet-examples uses branch master and has a 'simple' path)." \
        | tee /tmp/verify_bundle_hint.txt
      exit 1
    hintcheck: |
      if [ -f /tmp/verify_bundle_hint.txt ]; then
        cat /tmp/verify_bundle_hint.txt
        rm -f /tmp/verify_bundle_hint.txt
      fi

  # Gate step 3: a Fleet-managed workload actually landed on the cluster.
  verify_workload_deployed:
    machine: dev-machine
    user: laborant
    needs:
      - verify_bundle_ready
    run: |
      rm -f /tmp/verify_workload_hint.txt
      export KUBECONFIG=$HOME/.kube/config
      # Fleet stamps every resource it applies with an objectset id annotation
      # that includes the workspace (fleet-local-system). Find a Deployment
      # carrying that id - excluding the fleet-agent bootstrap, which is present
      # before the student does anything. A match means a GitRepo/bundle
      # actually deployed a workload.
      FOUND=$(kubectl get deployments -A \
        -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name} {.metadata.annotations.objectset\.rio\.cattle\.io/id}{"\n"}{end}' 2>/dev/null \
        | grep "fleet-local-system" | grep -v "fleet-agent" | head -n1)
      if [ -z "${FOUND}" ]; then
        echo "No Fleet-deployed workload found yet. Give the bundle time to apply its resources." \
          | tee /tmp/verify_workload_hint.txt
        exit 1
      fi
      echo "Fleet deployed a workload: ${FOUND%% *}"
    hintcheck: |
      if [ -f /tmp/verify_workload_hint.txt ]; then
        cat /tmp/verify_workload_hint.txt
        rm -f /tmp/verify_workload_hint.txt
      fi
---

Fleet is Rancher's built-in GitOps engine: point it at a Git repository, and it keeps your cluster matching what is in the repository. It turns each deployable path in a repo into a Bundle, then applies that bundle to every targeted cluster.

Fleet already runs on this playground because it ships with Rancher, and the `local` cluster is registered with it. You work from the :tab{text='dev-machine' machine='dev-machine'} workstation. Your task is to create a GitRepo that pulls a sample application from a public repository and let Fleet deploy it to the local cluster.

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
:summary: Hint 1 - what a GitRepo needs
---
The `rancher/fleet-examples` repository is the canonical source for this. A GitRepo needs a `repo` URL, a `branch`, and one or more `paths`. Create it in the `fleet-local` namespace so it targets the local cluster. An empty `clusterSelector` under `targets` matches every cluster in the namespace.
::

## Step 2: Watch Fleet Build a Bundle

Fleet converts the GitRepo path into a Bundle and applies it. The bundle should reach the `Ready` state.

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
:summary: Hint 2 - the bundle stays NotReady
---
Watch `kubectl -n fleet-local get bundles`. A bundle moves from `NotReady` to `Ready` as its resources apply. If it stays `NotReady`, describe the GitRepo and the bundle to see the error - a wrong branch or path is the usual cause. The `fleet-examples` repository uses the `master` branch and has a `simple` path that deploys a workload.
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
:summary: Hint 3 - no workload yet
---
Fleet labels every resource it manages with the bundle that created it. If you do not see a workload, the bundle may still be applying, or the chosen path may not contain a Deployment - pick a path from fleet-examples that deploys one (the `simple` path does).
::
