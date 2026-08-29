---
kind: challenge

title: 'Drive a Deployment with a Fleet CD Pipeline'

description: |
  Wire up the continuous delivery half of a CI/CD pipeline: have Fleet watch a deployment repository and roll out a pinned application image, then confirm the running workload matches the version declared in Git.
  This is the GitOps contract that Rancher Fleet enforces.

categories:
  - kubernetes
  - containers

tagz:
  - Rancher
  - Fleet
  - CI/CD
  - GitOps
  - Continuous Delivery

difficulty: hard

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

      for i in $(seq 1 60); do
        if kubectl -n fleet-local get clusters.fleet.cattle.io \
            -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | grep -q .; then
          exit 0
        fi
        sleep 5
      done
      echo "Fleet local cluster did not register in time"
      exit 1

  verify_delivery_source:
    run: |
      rm -f /tmp/verify_cd_source_hint.txt

      # A Fleet CD source can be a GitRepo (online) or a Bundle produced by
      # `fleet apply` (offline / CI). Either is a valid delivery source.
      GR=$(kubectl -n fleet-local get gitrepo -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
      BUNDLE=$(kubectl -n fleet-local get bundles -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
      if [ -z "${GR}" ] && [ -z "${BUNDLE}" ]; then
        echo "No Fleet delivery source found - create a GitRepo or apply a Bundle with 'fleet apply'" | tee /tmp/verify_cd_source_hint.txt
        exit 1
      fi

      echo "Fleet delivery source present (gitrepo='${GR}' bundle='${BUNDLE}')"
    hintcheck: |
      if [ -f /tmp/verify_cd_source_hint.txt ]; then
        cat /tmp/verify_cd_source_hint.txt
        rm -f /tmp/verify_cd_source_hint.txt
      fi

  verify_app_running:
    needs:
      - verify_delivery_source
    run: |
      rm -f /tmp/verify_cd_app_hint.txt

      # The pipeline must produce a running deployment named 'cd-app' in the
      # 'cd-demo' namespace (the contract the student deploys to via Fleet).
      for i in $(seq 1 30); do
        READY=$(kubectl -n cd-demo get deployment cd-app -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        if [ "${READY:-0}" -ge 1 ]; then
          echo "Deployment cd-app is running"
          exit 0
        fi
        sleep 5
      done
      echo "Deployment 'cd-app' in namespace 'cd-demo' is not running yet" | tee /tmp/verify_cd_app_hint.txt
      exit 1
    hintcheck: |
      if [ -f /tmp/verify_cd_app_hint.txt ]; then
        cat /tmp/verify_cd_app_hint.txt
        rm -f /tmp/verify_cd_app_hint.txt
      fi

  verify_image_pinned:
    needs:
      - verify_app_running
    run: |
      rm -f /tmp/verify_cd_image_hint.txt

      # GitOps contract: the running image tag must be an explicit, pinned
      # version - never 'latest'. This mirrors CI writing a specific tag to Git.
      IMAGE=$(kubectl -n cd-demo get deployment cd-app \
        -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
      if [ -z "${IMAGE}" ]; then
        echo "Could not read the cd-app image" | tee /tmp/verify_cd_image_hint.txt
        exit 1
      fi

      TAG=$(echo "${IMAGE}" | awk -F: '{print $NF}')
      case "${IMAGE}" in
        *:*) : ;;
        *)
          echo "Image '${IMAGE}' has no explicit tag - pin a specific version" | tee /tmp/verify_cd_image_hint.txt
          exit 1
          ;;
      esac
      if [ "${TAG}" = "latest" ]; then
        echo "Image is pinned to 'latest' - CD must deploy an explicit version tag" | tee /tmp/verify_cd_image_hint.txt
        exit 1
      fi

      echo "cd-app runs pinned image ${IMAGE}"
    hintcheck: |
      if [ -f /tmp/verify_cd_image_hint.txt ]; then
        cat /tmp/verify_cd_image_hint.txt
        rm -f /tmp/verify_cd_image_hint.txt
      fi

  verify_managed_by_fleet:
    needs:
      - verify_image_pinned
    run: |
      rm -f /tmp/verify_cd_managed_hint.txt

      # The deployment must be owned by Fleet, proving it came through the CD
      # pipeline rather than a manual kubectl apply.
      LABELS=$(kubectl -n cd-demo get deployment cd-app -o jsonpath='{.metadata.labels}' 2>/dev/null)
      ANNOS=$(kubectl -n cd-demo get deployment cd-app -o jsonpath='{.metadata.annotations}' 2>/dev/null)
      if echo "${LABELS}${ANNOS}" | grep -qi "fleet.cattle.io\|objectset.rio.cattle.io"; then
        echo "cd-app is managed by Fleet"
        exit 0
      fi

      echo "cd-app does not appear to be managed by Fleet - deploy it through a GitRepo, not a manual apply" | tee /tmp/verify_cd_managed_hint.txt
      exit 1
    hintcheck: |
      if [ -f /tmp/verify_cd_managed_hint.txt ]; then
        cat /tmp/verify_cd_managed_hint.txt
        rm -f /tmp/verify_cd_managed_hint.txt
      fi
---

A CI/CD pipeline for Kubernetes splits cleanly in two. The CI half builds and tests code, produces a container image, and writes a specific image tag into a deployment repository. The CD half watches that repository and rolls the change out to clusters. Rancher Fleet owns the CD half, and its contract is strict: what runs on the cluster is exactly what Git declares.

This challenge focuses on that CD contract. Fleet is installed and the local cluster is registered. You will stand up the delivery side of a pipeline so that a `cd-app` deployment runs a specific, pinned image and is owned by Fleet - the observable result of a real pipeline.

The application must end up as a Deployment named `cd-app` in a `cd-demo` namespace, running an explicitly tagged image (not `latest`), delivered through Fleet.

## Step 1: Provide a Delivery Source

Give Fleet a delivery source for the application. That can be an online `GitRepo`, or - the offline path a CI runner uses - a `Bundle` produced by `fleet apply` from local manifests. Either works.

::simple-task
---
:tasks: tasks
:name: verify_delivery_source
---
#active
Waiting for a Fleet delivery source...

#completed
A Fleet delivery source exists.
::

::hint-box
---
:summary: Hint 1
---
When you cannot push to a Git host, the `fleet apply` CLI turns a directory of manifests into a Bundle and applies it directly - the same object a GitRepo would generate. Point it at a directory whose manifests deploy a `cd-app` Deployment into a `cd-demo` namespace.
::

## Step 2: Roll Out the Application

Fleet should deliver the manifests so that `cd-app` runs in `cd-demo`.

::simple-task
---
:tasks: tasks
:name: verify_app_running
---
#active
Waiting for cd-app to be running in cd-demo...

#completed
cd-app is running.
::

::hint-box
---
:summary: Hint 2
---
If the app never appears, the GitRepo path or branch is likely wrong, or the manifests deploy to a different name/namespace. Describe the GitRepo and its bundle to see what Fleet applied.
::

## Step 3: Pin the Image Version

The running image must carry an explicit version tag. Deploying `latest` breaks the GitOps guarantee that Git describes exactly what runs.

::simple-task
---
:tasks: tasks
:name: verify_image_pinned
---
#active
Checking that cd-app runs a pinned image tag...

#completed
cd-app runs a pinned image version.
::

::hint-box
---
:summary: Hint 3
---
In a real pipeline, CI writes a specific tag (a version or a commit SHA) into the manifest before Fleet deploys it. Make sure the image in your manifest ends with an explicit tag other than `latest`.
::

## Step 4: Prove Fleet Owns It

The deployment must be delivered by Fleet, not applied by hand. Fleet labels the resources it manages.

::simple-task
---
:tasks: tasks
:name: verify_managed_by_fleet
---
#active
Confirming cd-app is managed by Fleet...

#completed
cd-app is delivered and owned by Fleet. Well done.
::

::hint-box
---
:summary: Hint 4
---
A manual `kubectl apply` will satisfy the "running" check but fail this one - the resource carries no Fleet ownership metadata. The workload has to arrive through the GitRepo bundle for Fleet to own it.
::
