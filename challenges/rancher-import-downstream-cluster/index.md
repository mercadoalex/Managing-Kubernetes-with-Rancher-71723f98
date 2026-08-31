---
kind: challenge

title: 'Import a Downstream Cluster into Rancher'

description: |
  Register a second, independent Kubernetes cluster into Rancher and bring it
  under management. You start with Rancher running on one cluster and a separate,
  empty K3s cluster next to it; your job is to import the second cluster so
  Rancher manages both. This is the everyday multi-cluster workflow a Rancher
  operator performs.

categories:
  - kubernetes
  - containers

tagz:
  - Rancher
  - multi-cluster
  - import
  - downstream

difficulty: medium

createdAt: 2026-08-27
updatedAt: 2026-08-27

# Two-cluster topology (see playgrounds/rancher-k3s-downstream/manifest.yaml):
# rancher-server = upstream (Rancher pre-installed), downstream-01 = separate
# empty K3s to import, dev-machine = workstation targeting the upstream.
# TODO(publish): replace with the suffixed name from
#   `labctl playground create rancher-k3s-downstream --base flexbox`.
playground:
  name: rancher-k3s-downstream-54528e97

tasks:
  # Confirm the upstream Rancher cluster is reachable from the workstation and
  # that only the built-in 'local' cluster exists at the start. This gives the
  # negative baseline for the import checks below.
  init_wait_rancher:
    init: true
    machine: dev-machine
    user: laborant
    timeout_seconds: 240
    run: |
      export KUBECONFIG=$HOME/.kube/config
      for i in $(seq 1 60); do
        if kubectl get clusters.management.cattle.io local >/dev/null 2>&1; then
          exit 0
        fi
        sleep 4
      done
      echo "Rancher management API not ready in time"
      exit 1

  # Confirm the downstream K3s cluster is up on downstream-01 before the student
  # tries to import it.
  init_wait_downstream:
    init: true
    machine: downstream-01
    user: root
    timeout_seconds: 300
    run: |
      for i in $(seq 1 75); do
        if k3s kubectl get nodes 2>/dev/null | grep -q ' Ready '; then
          exit 0
        fi
        sleep 4
      done
      echo "Downstream K3s cluster did not become ready in time"
      exit 1

  # Gate step 1: an imported cluster (anything other than 'local') exists.
  verify_cluster_imported:
    machine: dev-machine
    user: laborant
    needs:
      - init_wait_rancher
      - init_wait_downstream
    run: |
      rm -f /tmp/verify_import_hint.txt
      export KUBECONFIG=$HOME/.kube/config
      COUNT=$(kubectl get clusters.management.cattle.io \
        --no-headers 2>/dev/null | grep -v '^local ' | wc -l | tr -d ' ')
      if [ "${COUNT:-0}" -lt 1 ]; then
        echo "No imported cluster yet. Create a Generic import in Rancher and run the registration command on downstream-01." \
          | tee /tmp/verify_import_hint.txt
        exit 1
      fi
      NAME=$(kubectl get clusters.management.cattle.io \
        --no-headers 2>/dev/null | grep -v '^local ' | head -1 | awk '{print $1}')
      echo "${NAME}"
    hintcheck: |
      if [ -f /tmp/verify_import_hint.txt ]; then
        cat /tmp/verify_import_hint.txt
        rm -f /tmp/verify_import_hint.txt
      fi

  # Gate step 2: the imported cluster reached the Ready state, which only
  # happens once its cluster agent connects back to Rancher.
  verify_cluster_active:
    machine: dev-machine
    user: laborant
    needs:
      - verify_cluster_imported
    env:
      - CLUSTER=x(.needs.verify_cluster_imported.stdout)
    timeout_seconds: 300
    run: |
      rm -f /tmp/verify_active_hint.txt
      export KUBECONFIG=$HOME/.kube/config
      if [ -z "${CLUSTER}" ]; then
        echo "Could not determine the imported cluster name" | tee /tmp/verify_active_hint.txt
        exit 1
      fi
      READY=$(kubectl get clusters.management.cattle.io "${CLUSTER}" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
      if [ "${READY}" != "True" ]; then
        echo "Cluster '${CLUSTER}' is registered but not Ready. Wait for its agent pods on downstream-01 to start, or check the registration command ran successfully." \
          | tee /tmp/verify_active_hint.txt
        exit 1
      fi
      echo "Cluster '${CLUSTER}' is Active and managed by Rancher"
    hintcheck: |
      if [ -f /tmp/verify_active_hint.txt ]; then
        cat /tmp/verify_active_hint.txt
        rm -f /tmp/verify_active_hint.txt
      fi
---

Rancher's core value is managing many clusters from one place. In this challenge you take a cluster that Rancher has never seen and bring it under management.

The playground gives you two separate Kubernetes clusters:

- The **upstream** cluster runs Rancher. It is the `local` cluster, on the `rancher-server` machine. You reach it with `kubectl` from the :tab{text='dev-machine' machine='dev-machine'} workstation.
- The **downstream** cluster is a fresh, empty K3s cluster on the :tab{text='downstream-01' machine='downstream-01'} machine. Rancher does not know about it yet.

Your task: import the downstream cluster into Rancher so it appears as a managed, Active cluster alongside `local`.

## Step 1: Register the Cluster in Rancher

Open the :tab{text='Rancher' name='Rancher'} tab, create a **Generic** cluster import, and give it a name. Rancher will show you a registration command.

::simple-task
---
:tasks: tasks
:name: verify_cluster_imported
---
#active
Waiting for an imported cluster to appear in Rancher...

#completed
The downstream cluster is registered with Rancher.
::

::hint-box
---
:summary: Hint 1 - where to start the import
---
In the Rancher UI, go to the cluster management area and choose **Import Existing**, then the **Generic** type. Naming the cluster and creating it produces a registration command you will run in the next step. You can also list clusters from the workstation with `kubectl get clusters.management.cattle.io` to watch a new object appear.
::

## Step 2: Run the Registration Command on the Downstream Cluster

Take the registration command Rancher gave you and run it on the downstream cluster - in the :tab{text='downstream-01' machine='downstream-01'} terminal, whose `kubectl` targets the downstream K3s. This installs the Rancher cluster agent, which connects back to Rancher and completes the import.

Two adjustments are needed to make the command work on this playground - see the hints below if it fails.

::simple-task
---
:tasks: tasks
:name: verify_cluster_active
---
#active
Waiting for the imported cluster to reach the Active/Ready state...

#completed
The downstream cluster is Active and fully managed by Rancher. Well done.
::

::hint-box
---
:summary: Hint 2 - use Rancher's internal address, not the URL from the browser
---
The registration URL Rancher shows is built from your browser's address - the iximiuz proxy hostname (`...iximiuz.com`). The downstream node is not logged in to that proxy, so `curl` fetches a sign-in HTML page instead of the manifest, and `kubectl` then fails with `error validating "STDIN": invalid object`. Swap the hostname for Rancher's internal lab address `172.16.0.2.sslip.io:30443`, keeping the `/v3/import/....yaml` path unchanged. Use the `curl --insecure ...` variant (self-signed certificate).
::

::hint-box
---
:summary: Hint 3 - permission denied reading the K3s kubeconfig
---
On downstream-01 you are the `laborant` user, but K3s's kubeconfig at `/etc/rancher/k3s/k3s.yaml` is root-only, so a plain `kubectl` fails with `permission denied`. Pipe the manifest into `sudo k3s kubectl apply -f -` instead - `k3s kubectl` under `sudo` reads the root-owned config correctly.
::

::hint-box
---
:summary: Hint 4 - registered but stuck at Pending
---
A cluster that appears but never goes Active usually means the agent did not start on the downstream side. Make sure you applied the manifest in the :tab{text='downstream-01' machine='downstream-01'} terminal (not the workstation) and that its pods in the `cattle-system` namespace are coming up.
::
