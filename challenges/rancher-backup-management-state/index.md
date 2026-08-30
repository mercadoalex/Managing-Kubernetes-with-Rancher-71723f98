---
kind: challenge

title: 'Back Up the Rancher Management State'

description: |
  Protect a Rancher installation against disaster. The Rancher Backup operator
  and a ResourceSet are already in place - create a Backup and confirm the
  operator produces a completed archive of the management state, the first step
  of any real recovery plan.

categories:
  - kubernetes

tagz:
  - Rancher
  - backup
  - disaster-recovery

difficulty: medium

createdAt: 2026-08-27
updatedAt: 2026-08-27

# Single-cluster playground with Rancher pre-installed (dev-machine workstation).
# TODO(publish): replace with the live suffix if it changes.
playground:
  name: rancher-k3s-e09b66ec

tasks:
  # Wait until the workstation can reach the cluster.
  init_wait_cluster:
    init: true
    machine: dev-machine
    user: laborant
    timeout_seconds: 240
    run: |
      export KUBECONFIG=$HOME/.kube/config
      for i in $(seq 1 60); do
        kubectl get nodes 2>/dev/null | grep -q " Ready" && exit 0
        sleep 4
      done
      echo "Cluster not reachable from the workstation in time"
      exit 1

  # Install the Rancher Backup operator and the ResourceSet for the student, so
  # the challenge is about producing a backup rather than installing infra.
  init_install_operator:
    init: true
    machine: dev-machine
    user: laborant
    needs:
      - init_wait_cluster
    timeout_seconds: 420
    run: |
      export KUBECONFIG=$HOME/.kube/config
      helm repo add rancher-charts https://charts.rancher.io >/dev/null 2>&1 || true
      helm repo update rancher-charts >/dev/null 2>&1 || true
      if ! helm status rancher-backup-crd -n cattle-resources-system >/dev/null 2>&1; then
        helm install rancher-backup-crd rancher-charts/rancher-backup-crd \
          -n cattle-resources-system --create-namespace >/dev/null 2>&1 || true
      fi
      if ! helm status rancher-backup -n cattle-resources-system >/dev/null 2>&1; then
        helm install rancher-backup rancher-charts/rancher-backup \
          -n cattle-resources-system \
          --set persistence.enabled=true \
          --set persistence.storageClass=local-path \
          --set persistence.size=2Gi >/dev/null 2>&1 || true
      fi
      kubectl apply -f - >/dev/null 2>&1 <<'EOF' || true
      apiVersion: resources.cattle.io/v1
      kind: ResourceSet
      metadata:
        name: rancher-resource-set
      controllerReferences:
        - apiVersion: "apps/v1"
          resource: "deployments"
          name: "rancher"
          namespace: "cattle-system"
      resourceSelectors:
        - apiVersion: "v1"
          kindsRegexp: "^namespaces$"
          resourceNameRegexp: "^cattle-|^p-|^c-|^user-|^local$"
        - apiVersion: "management.cattle.io/v3"
          kindsRegexp: "."
        - apiVersion: "v1"
          kindsRegexp: "^secrets$"
          namespaceRegexp: "^cattle-system$"
      EOF
      kubectl -n cattle-resources-system rollout status deploy/rancher-backup --timeout=300s >/dev/null 2>&1
      AVAIL=$(kubectl -n cattle-resources-system get deploy rancher-backup \
        -o jsonpath='{.status.availableReplicas}' 2>/dev/null || true)
      if [ "${AVAIL:-0}" -lt 1 ] 2>/dev/null; then
        echo "The rancher-backup operator did not become available in time"
        exit 1
      fi
      echo "Rancher Backup operator and ResourceSet are ready"

  # Baseline for the negative condition: at the start, no completed backup
  # exists. The gate later requires one, proving the student created it.
  init_baseline_no_backup:
    init: true
    machine: dev-machine
    user: laborant
    needs:
      - init_install_operator
    run: |
      export KUBECONFIG=$HOME/.kube/config
      FOUND=""
      for b in $(kubectl get backup -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true); do
        R=$(kubectl get backup "$b" \
          -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
        F=$(kubectl get backup "$b" -o jsonpath='{.status.filename}' 2>/dev/null || true)
        if [ "$R" = "True" ] && [ -n "$F" ]; then
          FOUND="$b"; break
        fi
      done
      if [ -n "$FOUND" ]; then
        echo "Unexpected: a completed backup ($FOUND) already exists at the baseline"
        exit 1
      fi
      echo "Baseline confirmed: no completed backup exists yet"

  # Gate: a Backup exists and has completed (Ready=True with a filename).
  verify_backup_completed:
    machine: dev-machine
    user: laborant
    needs:
      - init_baseline_no_backup
    run: |
      rm -f /tmp/verify_backup_hint.txt
      export KUBECONFIG=$HOME/.kube/config
      READY=""
      FILE=""
      for b in $(kubectl get backup -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true); do
        R=$(kubectl get backup "$b" \
          -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
        F=$(kubectl get backup "$b" -o jsonpath='{.status.filename}' 2>/dev/null || true)
        if [ "$R" = "True" ] && [ -n "$F" ]; then
          READY="True"; FILE="$F"; break
        fi
      done
      if [ "$READY" = "True" ] && [ -n "$FILE" ]; then
        echo "A backup completed successfully: ${FILE}"
        exit 0
      fi
      echo "No completed backup found yet. Create a Backup that references the rancher-resource-set ResourceSet, and wait for its Ready condition to become True." \
        | tee /tmp/verify_backup_hint.txt
      exit 1
    hintcheck: |
      if [ -f /tmp/verify_backup_hint.txt ]; then
        cat /tmp/verify_backup_hint.txt
        rm -f /tmp/verify_backup_hint.txt
      fi
---

A Rancher installation is the map of everything it manages: cluster registrations, users, role bindings, catalogs, and Fleet definitions. If that state is lost, you lose the connection to every downstream cluster even if the clusters themselves survive. Protecting it is the foundation of disaster recovery.

The **Rancher Backup operator** is already installed on this cluster, along with a `rancher-resource-set` ResourceSet that defines which resources belong in a backup. You work from the :tab{text='dev-machine' machine='dev-machine'} workstation, which has `kubectl` configured against the cluster. Your job: create a backup and confirm the operator produces a completed archive.

## Create a Completed Backup

Request a one-time backup that uses the `rancher-resource-set` ResourceSet, then wait for the operator to finish writing the archive.

::simple-task
---
:tasks: tasks
:name: verify_backup_completed
---
#active
Waiting for a backup to complete (Ready=True with a filename)...

#completed
A backup completed and its archive is stored. Your Rancher state is protected.
::

::hint-box
---
:summary: Hint 1 - the Backup object
---
The operator watches for `Backup` objects in the `resources.cattle.io/v1` API. A `Backup` needs one thing in its spec: the name of the ResourceSet to use, which is already present as `rancher-resource-set`. Create the object with `kubectl apply`.
::

::hint-box
---
:summary: Hint 2 - confirming completion
---
The operator records progress on the `Backup` object. Check its `Ready` condition and its `filename` field with `kubectl get backup <name> -o yaml`. When the condition is `True` and a filename is set, the archive has been written. If it stays at `Unknown`, look at `kubectl -n cattle-resources-system logs deploy/rancher-backup`.
::
