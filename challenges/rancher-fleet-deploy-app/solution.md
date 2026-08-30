---
title: Deploy an App Through a Fleet GitRepo
---

Fleet ships with Rancher and the local cluster is already registered with it, so the whole exercise is a single GitOps loop: declare a GitRepo, let Fleet build a bundle from it, and watch the workload appear. You do all of this from the dev-machine workstation.

<!--more-->

## Create the GitRepo

Point Fleet at the `simple` path of the public `fleet-examples` repository. Create the GitRepo in the `fleet-local` namespace so it targets the local cluster; an empty `clusterSelector` matches every cluster in that namespace:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: fleet.cattle.io/v1alpha1
kind: GitRepo
metadata:
  name: sample-app
  namespace: fleet-local
spec:
  repo: https://github.com/rancher/fleet-examples
  branch: master
  paths:
  - simple
  targets:
  - clusterSelector: {}
EOF
```

## Watch the Bundle

Fleet turns the `simple` path into a bundle and applies it. Watch it reach `Ready`:

```bash
kubectl -n fleet-local get gitrepo sample-app
kubectl -n fleet-local get bundles
```

If a bundle sits in `NotReady`, describe it to find out why:

```bash
kubectl -n fleet-local describe bundle sample-app-simple
```

A mismatched `branch` (this repository uses `master`) or a wrong `path` is the usual culprit.

## Confirm the Workload

The `simple` example deploys a small application (a frontend plus a couple of redis workloads) into the `default` namespace. Once the bundle is ready, those Deployments exist, and Fleet annotates every resource it applies with an objectset id that traces back to the bundle:

```bash
kubectl -n default get deployments
kubectl -n default get deploy frontend \
  -o jsonpath='{.metadata.annotations.objectset\.rio\.cattle\.io/id}'; echo
```

The id (`default-sample-app-simple-cattle-fleet-local-system`) ties the workload back to your `sample-app` GitRepo.

Deleting the GitRepo would remove the workload again - Git stays the source of truth. That is the whole point of the GitOps loop: the cluster follows the repository, not manual commands.
