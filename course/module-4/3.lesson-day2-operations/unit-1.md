---
kind: unit

title: Backing Up the Rancher Management State

name: backing-up-rancher-state
---

The single most important day-2 question is: if this cluster died right now, could you get it back? For a Rancher-managed environment, the answer starts with protecting Rancher's own state - the cluster registrations, users, role bindings, catalogs, and Fleet definitions that live in the management plane. Lose that and you lose the map of everything Rancher knows about, even if the downstream clusters survive.

Rancher ships a purpose-built tool for this: the **Rancher Backup** operator (`rancher-backup`). In this unit you install it and produce a real, completed backup. You drive everything from the :tab{text='dev-machine' machine='dev-machine'} workstation, which has `helm` and `kubectl` configured against the cluster.

::image-box
---
:src: __static__/rancher-backup-flow-v1.png
:alt: The Rancher Backup operator reading the Rancher management state selected by a ResourceSet, packaging it into a tar.gz archive, and writing that archive to a persistent volume backed by the local-path storage class
:max-width: 900px
---
_The Rancher Backup operator gathers the resources named by a ResourceSet and writes a tar.gz archive to its storage target._
::

## Step 1: Install the Rancher Backup Operator

The operator is published as a Helm chart in the `rancher-charts` repository. It comes in two parts: a CRD chart that installs the `Backup`, `Restore`, and `ResourceSet` custom resource definitions, and the operator chart itself. Install both into the `cattle-resources-system` namespace, and point the operator's storage at the cluster's built-in `local-path` storage class so backups land on a persistent volume:

```bash
helm repo add rancher-charts https://charts.rancher.io
helm repo update

helm install rancher-backup-crd rancher-charts/rancher-backup-crd \
  -n cattle-resources-system --create-namespace

helm install rancher-backup rancher-charts/rancher-backup \
  -n cattle-resources-system \
  --set persistence.enabled=true \
  --set persistence.storageClass=local-path \
  --set persistence.size=2Gi
```

The operator is a single lightweight deployment. Wait for it to become available:

```bash
kubectl -n cattle-resources-system rollout status deploy/rancher-backup
```

::simple-task
---
:tasks: tasks
:name: verify_operator_installed
---
#active
Waiting for the rancher-backup operator to be running...

#completed
The rancher-backup operator is running.
::

## Step 2: Tell the Operator What to Back Up

The operator does not decide on its own which objects matter. It reads a **ResourceSet** - a definition that selects exactly which resources belong in a backup. When you install `rancher-backup` through the Rancher UI catalog, Rancher seeds a standard ResourceSet named `rancher-resource-set` for you. Because you installed the chart directly with Helm, you create that ResourceSet yourself. It selects the Rancher management namespaces, all `management.cattle.io` objects, and the Rancher system secrets:

```yaml
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
```

Apply it:

```bash
kubectl apply -f - <<'EOF'
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
```

::details-box
---
:summary: What a ResourceSet actually captures
---
A ResourceSet is a list of selectors, each matching resources by API group, kind, name, or namespace using regular expressions. The `rancher-resource-set` above grabs the Rancher management namespaces (`cattle-*`, project namespaces `p-*`, cluster namespaces `c-*`, user namespaces, and `local`), every custom resource in the `management.cattle.io` group (clusters, users, role templates, catalogs, settings, and more), and the secrets in `cattle-system` that hold Rancher's own credentials. That set is enough to reconstruct the Rancher management plane on a fresh install. Without a ResourceSet the operator has nothing to gather and the backup fails with `resourcesets.resources.cattle.io "rancher-resource-set" not found`.
::

## Step 3: Create a Backup

With the operator running and a ResourceSet in place, request a one-time backup. A `Backup` object simply names the ResourceSet to use:

```yaml
apiVersion: resources.cattle.io/v1
kind: Backup
metadata:
  name: rancher-state-backup
spec:
  resourceSetName: rancher-resource-set
```

Apply it:

```bash
kubectl apply -f - <<'EOF'
apiVersion: resources.cattle.io/v1
kind: Backup
metadata:
  name: rancher-state-backup
spec:
  resourceSetName: rancher-resource-set
EOF
```

::hint-box
---
:summary: How to watch the backup after you apply it
---
The backup runs asynchronously, so it will not be ready the instant you apply the object. Poll its status in a loop until the `Ready` condition turns `True` and a `filename` appears:

```bash
for i in $(seq 1 24); do
  kubectl get backup rancher-state-backup \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status} {.status.filename}{"\n"}'
  sleep 5
done
```

You can also watch the whole object update live with `kubectl get backup rancher-state-backup -w`, or read the full status with `kubectl get backup rancher-state-backup -o yaml`. It usually completes within a minute.
::

The operator gathers the selected resources, packages them into a `tar.gz` archive, and writes it to the persistent volume. It records progress on the `Backup` object itself. Watch it complete:

```bash
kubectl get backup rancher-state-backup \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status} {.status.filename}{"\n"}'
```

When the backup finishes, the `Ready` condition becomes `True` and the `filename` field holds the name of the archive it produced.

::simple-task
---
:tasks: tasks
:name: verify_backup_completed
---
#active
Waiting for a backup to complete (Ready=True with a filename)...

#completed
A backup completed and its archive is stored on the volume. Nicely done.
::

::hint-box
---
:summary: The backup stays at Ready=Unknown
---
If the `Backup` object sits at `Ready=Unknown`, check the operator logs with `kubectl -n cattle-resources-system logs deploy/rancher-backup`. The most common cause on a Helm-based install is a missing ResourceSet - the operator keeps retrying and logs `resourcesets.resources.cattle.io "rancher-resource-set" not found`. Make sure Step 2 applied cleanly before creating the Backup.
::

## Restoring: The Other Half

A backup is only useful if you can restore from it. The same operator handles restore through a `Restore` object that points at a backup archive. On a fresh Rancher installation, you install the operator, make the backup archive reachable (from the same volume, or from an S3 bucket), and create a `Restore` that names the file. The operator recreates the management resources, reconnecting Rancher to the downstream clusters it knew about - as long as those clusters are still reachable. Restoring is disruptive and reboots parts of the management plane, so this lesson gates on producing a verified backup rather than performing a full restore cycle.

::card
---
:challenge: challenges.rancher-backup-management-state-d6b7da83
---
::
