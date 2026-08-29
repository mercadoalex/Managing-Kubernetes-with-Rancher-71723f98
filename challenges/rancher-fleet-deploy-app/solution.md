---
title: Deploy an App Through a Fleet GitRepo
---

Fleet is already running and the local cluster is registered, so the whole exercise is a single GitOps loop: declare a GitRepo, let Fleet build a bundle from it, and watch the workload appear.

<!--more-->

## Create the GitRepo

Point Fleet at the `simple` path of the public `fleet-examples` repository. An empty `clusterSelector` targets every cluster in the namespace, which on this single-node setup is just the local cluster:

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

A mismatched `branch` (this repo uses `master`) or a wrong `path` is the usual culprit.

## Confirm the Workload

The `simple` example deploys an NGINX workload. Once the bundle is ready, the Deployment exists on the cluster:

```bash
kubectl get deployments -A | grep -i frontend
```

Fleet labels every resource it manages, so you can always trace a running workload back to the bundle that created it. Deleting the GitRepo would remove the workload again - Git stays the source of truth.
