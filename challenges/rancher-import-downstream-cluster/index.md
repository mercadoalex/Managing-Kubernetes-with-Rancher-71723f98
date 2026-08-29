---
kind: challenge

title: 'Register and Label a Cluster for Fleet Management'

description: |
  Install standalone Fleet on a K3s cluster and bring the local cluster under Fleet management, then label it so it can be targeted by GitOps deployments.
  This models the registration and targeting mechanics Rancher uses to manage downstream clusters.

categories:
  - kubernetes
  - containers

tagz:
  - Rancher
  - Fleet
  - Multi-Cluster
  - GitOps

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

  verify_fleet_crds:
    run: |
      rm -f /tmp/verify_fleet_crds_hint.txt

      if ! kubectl get crd clusters.fleet.cattle.io >/dev/null 2>&1; then
        echo "Fleet CRDs are not installed yet (clusters.fleet.cattle.io missing)" | tee /tmp/verify_fleet_crds_hint.txt
        exit 1
      fi
      if ! kubectl get crd gitrepos.fleet.cattle.io >/dev/null 2>&1; then
        echo "Fleet CRDs are not installed yet (gitrepos.fleet.cattle.io missing)" | tee /tmp/verify_fleet_crds_hint.txt
        exit 1
      fi

      echo "Fleet CRDs are installed"
    hintcheck: |
      if [ -f /tmp/verify_fleet_crds_hint.txt ]; then
        cat /tmp/verify_fleet_crds_hint.txt
        rm -f /tmp/verify_fleet_crds_hint.txt
      fi

  verify_fleet_controller:
    needs:
      - verify_fleet_crds
    run: |
      rm -f /tmp/verify_fleet_ctrl_hint.txt

      READY=$(kubectl get pods -A -l app=fleet-controller \
        -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null | grep -c "Running")
      if [ "${READY:-0}" -lt 1 ]; then
        echo "The Fleet controller is not running yet" | tee /tmp/verify_fleet_ctrl_hint.txt
        exit 1
      fi

      echo "Fleet controller is running"
    hintcheck: |
      if [ -f /tmp/verify_fleet_ctrl_hint.txt ]; then
        cat /tmp/verify_fleet_ctrl_hint.txt
        rm -f /tmp/verify_fleet_ctrl_hint.txt
      fi

  verify_cluster_registered:
    needs:
      - verify_fleet_controller
    run: |
      rm -f /tmp/verify_cluster_reg_hint.txt

      # Standalone Fleet registers the local cluster as a Fleet Cluster object
      # in the fleet-local namespace once the agent connects.
      CLUSTER=$(kubectl -n fleet-local get clusters.fleet.cattle.io \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
      if [ -z "${CLUSTER}" ]; then
        echo "No Fleet Cluster object found in fleet-local. The local agent may still be registering." | tee /tmp/verify_cluster_reg_hint.txt
        exit 1
      fi

      echo "${CLUSTER}"
    hintcheck: |
      if [ -f /tmp/verify_cluster_reg_hint.txt ]; then
        cat /tmp/verify_cluster_reg_hint.txt
        rm -f /tmp/verify_cluster_reg_hint.txt
      fi

  verify_cluster_labeled:
    needs:
      - verify_cluster_registered
    env:
      - CLUSTER=x(.needs.verify_cluster_registered.stdout)
    run: |
      rm -f /tmp/verify_cluster_label_hint.txt

      NAME=$(kubectl -n fleet-local get clusters.fleet.cattle.io \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
      if [ -z "${NAME}" ]; then
        echo "Could not find the Fleet Cluster object" | tee /tmp/verify_cluster_label_hint.txt
        exit 1
      fi

      ENV=$(kubectl -n fleet-local get cluster.fleet.cattle.io "${NAME}" \
        -o jsonpath='{.metadata.labels.env}' 2>/dev/null)
      if [ -z "${ENV}" ]; then
        echo "The cluster has no 'env' label yet. Add one so Fleet can target it." | tee /tmp/verify_cluster_label_hint.txt
        exit 1
      fi

      echo "Cluster '${NAME}' carries label env=${ENV}"
    hintcheck: |
      if [ -f /tmp/verify_cluster_label_hint.txt ]; then
        cat /tmp/verify_cluster_label_hint.txt
        rm -f /tmp/verify_cluster_label_hint.txt
      fi
---

Rancher manages downstream clusters by registering each one as a managed object and then using labels to decide what gets deployed where. Fleet, the GitOps engine that ships with Rancher, uses the same mechanics: every managed cluster becomes a `Cluster` object, and label selectors decide which workloads land on it.

In this challenge you work with standalone Fleet on a single K3s cluster. That keeps the moving parts small while exercising the exact registration and labeling model Rancher uses at scale. Your goal is to install Fleet, confirm the local cluster is registered, and label it so it can be targeted.

Note: a full two-cluster import needs a running Rancher server plus a second cluster - too heavy for a focused exercise. Standalone Fleet reproduces the registration and targeting behavior on one node.

## Step 1: Install Fleet

Install the Fleet CRDs and the Fleet controller. Standalone Fleet is distributed as two Helm charts published as OCI artifacts.

::simple-task
---
:tasks: tasks
:name: verify_fleet_crds
---
#active
Waiting for the Fleet CRDs...

#completed
Fleet CRDs are installed.
::

::simple-task
---
:tasks: tasks
:name: verify_fleet_controller
---
#active
Waiting for the Fleet controller to run...

#completed
The Fleet controller is running.
::

::hint-box
---
:summary: Hint 1
---
Fleet ships as `fleet-crd` and `fleet` charts. Install the CRD chart first, then the controller chart, both into the `cattle-fleet-system` namespace. The charts are available as OCI references under the Rancher registry.
::

## Step 2: Confirm the Local Cluster Is Registered

Once Fleet is running, its local agent registers the cluster as a `Cluster` object in the `fleet-local` namespace.

::simple-task
---
:tasks: tasks
:name: verify_cluster_registered
---
#active
Waiting for the local cluster to register with Fleet...

#completed
The local cluster is registered with Fleet.
::

::hint-box
---
:summary: Hint 2
---
Registration is automatic - the local Fleet agent creates the object shortly after the controller starts. Look under `kubectl -n fleet-local get clusters.fleet.cattle.io`. If it is empty, give the agent a moment.
::

## Step 3: Label the Cluster for Targeting

Add an `env` label to the registered Fleet `Cluster` object. This is the label a GitRepo would match to target this cluster.

::simple-task
---
:tasks: tasks
:name: verify_cluster_labeled
---
#active
Waiting for an env label on the cluster...

#completed
The cluster is labeled and ready to be targeted. Well done.
::

::hint-box
---
:summary: Hint 3
---
Label the `cluster.fleet.cattle.io` object in `fleet-local` (not the Kubernetes Node). Any value for the `env` key works - `env=lab`, for example. `kubectl label` operates on the object directly.
::
