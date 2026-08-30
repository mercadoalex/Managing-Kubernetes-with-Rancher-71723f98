---
kind: challenge

title: 'Ship a Change Through Fleet and a Git Server'

description: |
  Run the continuous delivery loop against a self-hosted Gitea Git server: point
  Fleet at a repository, then commit and push a manifest change and watch Fleet
  reconcile it onto the cluster. This is the GitOps contract Rancher Fleet
  enforces - the cluster follows Git, with no manual kubectl apply.

categories:
  - kubernetes
  - containers

tagz:
  - Rancher
  - Fleet
  - cicd
  - gitops
  - continuous-delivery

difficulty: medium

createdAt: 2026-08-27
updatedAt: 2026-08-27

# CI/CD playground: Rancher (with Fleet) + a self-hosted Gitea server on its own
# machine (see playgrounds/rancher-k3s-gitea/manifest.yaml).
# TODO(publish): replace with the suffixed name from
#   `labctl playground create rancher-k3s-gitea --base flexbox`.
playground:
  name: rancher-k3s-gitea-6cdd37fb

tasks:
  # Wait for Rancher's bundled Fleet (local cluster registered) and for Gitea to
  # be serving, so the student starts from a working environment.
  init_wait_ready:
    init: true
    machine: dev-machine
    user: laborant
    timeout_seconds: 360
    run: |
      export KUBECONFIG=$HOME/.kube/config
      # Fleet ready
      for i in $(seq 1 75); do
        kubectl -n fleet-local get clusters.fleet.cattle.io \
          -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | grep -q . && break
        sleep 4
      done
      # Gitea serving its seeded repo (via the reachable node IP)
      for i in $(seq 1 45); do
        if curl -sf http://172.16.0.4:3000/student/sample-app/raw/branch/main/manifests/web.yaml >/dev/null 2>&1; then
          exit 0
        fi
        sleep 4
      done
      echo "Gitea or Fleet not ready in time"
      exit 1

  # Gate step 1: a GitRepo in fleet-local points at the self-hosted Gitea server.
  verify_gitrepo_to_gitea:
    machine: dev-machine
    user: laborant
    needs:
      - init_wait_ready
    run: |
      rm -f /tmp/verify_gr_hint.txt
      export KUBECONFIG=$HOME/.kube/config
      MATCH=$(kubectl -n fleet-local get gitrepo \
        -o jsonpath='{range .items[*]}{.spec.repo}{"\n"}{end}' 2>/dev/null \
        | grep -c '172.16.0.4:3000')
      if [ "${MATCH:-0}" -lt 1 ]; then
        echo "No GitRepo in fleet-local pointing at the Gitea server (use http://172.16.0.4:3000/student/sample-app, the IP not the hostname)." \
          | tee /tmp/verify_gr_hint.txt
        exit 1
      fi
      echo "GitRepo targets the self-hosted Gitea server"
    hintcheck: |
      if [ -f /tmp/verify_gr_hint.txt ]; then
        cat /tmp/verify_gr_hint.txt
        rm -f /tmp/verify_gr_hint.txt
      fi

  # Gate step 2: Fleet deployed the app from Gitea (bundle Ready + web running).
  verify_app_deployed:
    machine: dev-machine
    user: laborant
    needs:
      - verify_gitrepo_to_gitea
    timeout_seconds: 240
    run: |
      rm -f /tmp/verify_app_hint.txt
      export KUBECONFIG=$HOME/.kube/config
      for i in $(seq 1 40); do
        READY=$(kubectl get deploy web -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        if [ "${READY:-0}" -ge 1 ]; then
          echo "Fleet deployed web from Gitea"
          exit 0
        fi
        sleep 5
      done
      echo "The web Deployment is not running yet. Check the GitRepo branch (main) and path (manifests)." \
        | tee /tmp/verify_app_hint.txt
      exit 1
    hintcheck: |
      if [ -f /tmp/verify_app_hint.txt ]; then
        cat /tmp/verify_app_hint.txt
        rm -f /tmp/verify_app_hint.txt
      fi

  # Gate step 3: a committed change was reconciled. The seed ships replicas: 1;
  # the student commits a scale-up, and Fleet must reconcile it to > 1.
  verify_committed_change_reconciled:
    machine: dev-machine
    user: laborant
    needs:
      - verify_app_deployed
    timeout_seconds: 240
    run: |
      rm -f /tmp/verify_change_hint.txt
      export KUBECONFIG=$HOME/.kube/config
      for i in $(seq 1 30); do
        R=$(kubectl get deploy web -o jsonpath='{.spec.replicas}' 2>/dev/null)
        if [ -n "${R}" ] && [ "${R}" -gt 1 ]; then
          echo "Fleet reconciled a committed change: web now has ${R} replicas"
          exit 0
        fi
        sleep 6
      done
      echo "web is still at 1 replica. Clone the Gitea repo, change replicas in manifests/web.yaml, commit, and push - Fleet will reconcile it." \
        | tee /tmp/verify_change_hint.txt
      exit 1
    hintcheck: |
      if [ -f /tmp/verify_change_hint.txt ]; then
        cat /tmp/verify_change_hint.txt
        rm -f /tmp/verify_change_hint.txt
      fi
---

Continuous delivery with Fleet is a contract: the cluster runs exactly what Git declares, and a commit is what triggers a rollout. In this challenge you run that loop end to end against a Git server you control.

The playground has a self-hosted **Gitea** server on its own machine (open the :tab{text='Gitea' name='Gitea'} tab, user `student`, password `student`). It hosts a `student/sample-app` repository with `manifests/web.yaml`, an nginx Deployment set to one replica. You work from the :tab{text='dev-machine' machine='dev-machine'} workstation.

## Step 1: Point Fleet at the Gitea Repository

Create a `GitRepo` in the `fleet-local` namespace that points at the Gitea repo. Use the server's IP address `172.16.0.4:3000`, not its hostname - Fleet clones from a cluster pod, and cluster DNS does not resolve the `gitea` machine name.

::simple-task
---
:tasks: tasks
:name: verify_gitrepo_to_gitea
---
#active
Waiting for a GitRepo pointing at the Gitea server...

#completed
Fleet is watching your Gitea repository.
::

::hint-box
---
:summary: Hint 1 - the GitRepo
---
A GitRepo needs `repo`, `branch`, and `paths`. The repo is `http://172.16.0.4:3000/student/sample-app`, the branch is `main`, and the path is `manifests`. Create it in `fleet-local` so it targets the local cluster.
::

## Step 2: Let Fleet Deploy the App

Fleet clones the repo, builds a bundle, and applies it. The `web` Deployment should appear.

::simple-task
---
:tasks: tasks
:name: verify_app_deployed
---
#active
Waiting for Fleet to deploy the app from Gitea...

#completed
Fleet deployed the app from your Git server.
::

::hint-box
---
:summary: Hint 2 - nothing deployed
---
Check `kubectl -n fleet-local get gitrepo` and `get bundles`. If the GitRepo shows no commit, the repo URL is likely wrong (must be the IP, not `gitea`). If the bundle stays NotReady, check the branch (`main`) and path (`manifests`).
::

## Step 3: Commit a Change and Watch It Reconcile

Now the real loop. Clone the Gitea repository, change the replica count in `manifests/web.yaml`, commit, and push. Do not run `kubectl scale` - the change must come through Git. Fleet will reconcile it.

::simple-task
---
:tasks: tasks
:name: verify_committed_change_reconciled
---
#active
Waiting for Fleet to reconcile your committed change...

#completed
Fleet reconciled your commit. The continuous delivery loop works end to end.
::

::hint-box
---
:summary: Hint 3 - push the change, do not scale by hand
---
Clone with `git clone http://student:student@172.16.0.4:3000/student/sample-app.git`, edit `manifests/web.yaml` to set `replicas` above 1, commit, and `git push origin main`. Fleet polls Gitea (about every 15 seconds) and reconciles the change. A `kubectl scale` would satisfy nothing here - the point is that the commit drives the rollout.
::
