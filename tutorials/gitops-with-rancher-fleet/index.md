---
kind: tutorial

title: GitOps with Rancher Fleet

description: |
  Use Rancher Fleet to implement GitOps-driven deployments across one or many clusters.
  Learn how to create GitRepos, configure bundles, and target clusters with selectors.

categories:
  - kubernetes
  - containers

tagz:
  - Rancher
  - Fleet
  - GitOps
  - Bundles
  - Multi-Cluster Deployment

createdAt: 2026-08-27
updatedAt: 2026-08-27

playground:
  name: ubuntu-k3s-bare
---

## Overview

Rancher Fleet is a GitOps engine built into Rancher. It continuously watches Git repositories and deploys their contents to one or more Kubernetes clusters. Fleet handles raw Kubernetes manifests, Helm charts, and Kustomize overlays - all from a single Git source.

Fleet is installed automatically when you deploy Rancher. In this tutorial, you will create Git repositories, define deployment targets, and observe how Fleet reconciles cluster state with your Git source of truth.

## How Fleet Works

Fleet operates on three key concepts:

**GitRepo** - a custom resource that points Fleet at a Git repository. It defines what to watch and where to deploy.

**Bundle** - the unit of deployment Fleet creates from a GitRepo. Each path in the repository that contains deployable content becomes a bundle.

**Cluster Groups and Selectors** - how Fleet decides which clusters receive which bundles. You target clusters by labels, names, or group membership.

The reconciliation loop:
1. Fleet detects a change in the Git repository
2. It generates or updates bundles from the repository contents
3. Bundles are deployed to clusters matching the target selectors
4. Fleet continuously monitors drift and re-applies if the cluster state diverges from Git

## Exploring Fleet Components

Fleet is already running on your cluster. Check its components:

```bash
kubectl get namespaces | grep fleet
```

You should see:
- `cattle-fleet-system` - the Fleet controller
- `cattle-fleet-local-system` - the local cluster's Fleet agent

Check the Fleet controller:

```bash
kubectl -n cattle-fleet-system get pods
kubectl -n cattle-fleet-system get deployments
```

## Creating a GitRepo Resource

A GitRepo tells Fleet where to find your manifests. Create a simple deployment from a public Git repository:

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
  - clusterSelector:
      matchLabels:
        management.cattle.io/cluster-display-name: local
EOF
```

Key fields:
- `repo` - the Git repository URL
- `branch` - which branch to watch
- `paths` - subdirectories within the repo that contain deployable content
- `targets` - which clusters should receive the deployment

## Monitoring GitRepo Status

Check the status of the GitRepo:

```bash
kubectl -n fleet-local get gitrepo sample-app
```

Watch the bundles that Fleet creates:

```bash
kubectl -n fleet-local get bundles
```

A bundle transitions through states: `NotReady` to `Ready` as resources are deployed successfully.

Get detailed status:

```bash
kubectl -n fleet-local describe gitrepo sample-app
```

The status section shows the number of ready bundles, any errors, and the last observed Git commit.

## Understanding Bundles

Each path in a GitRepo becomes a separate bundle. Fleet auto-detects the content type:

- If the path contains a `Chart.yaml`, Fleet treats it as a Helm chart
- If the path contains a `kustomization.yaml`, Fleet uses Kustomize
- Otherwise, Fleet applies raw Kubernetes manifests

List bundles and their states:

```bash
kubectl -n fleet-local get bundles -o wide
```

Inspect a specific bundle:

```bash
kubectl -n fleet-local describe bundle sample-app-simple
```

## Targeting Clusters

Fleet uses label selectors to determine where bundles are deployed. In a multi-cluster setup, you can target deployments precisely.

### By Cluster Label

```yaml
targets:
- clusterSelector:
    matchLabels:
      environment: production
```

### By Cluster Group

Cluster groups are named collections of clusters:

```yaml
targets:
- clusterGroup: staging-clusters
```

### All Clusters

```yaml
targets:
- clusterSelector: {}
```

### Multiple Targets with Overrides

You can deploy the same content to multiple targets with different configurations:

```yaml
targets:
- name: dev
  clusterSelector:
    matchLabels:
      environment: dev
  helm:
    values:
      replicas: 1
- name: prod
  clusterSelector:
    matchLabels:
      environment: production
  helm:
    values:
      replicas: 3
```

## Deploying a Helm Chart via Fleet

Fleet can deploy Helm charts directly from Git. Create a GitRepo that points to a chart:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: fleet.cattle.io/v1alpha1
kind: GitRepo
metadata:
  name: helm-app
  namespace: fleet-local
spec:
  repo: https://github.com/rancher/fleet-examples
  branch: master
  paths:
  - single-cluster/helm
  targets:
  - clusterSelector:
      matchLabels:
        management.cattle.io/cluster-display-name: local
EOF
```

Fleet reads the `Chart.yaml` and `values.yaml` in the path and installs the chart on matching clusters.

Monitor the deployment:

```bash
kubectl -n fleet-local get gitrepo helm-app
kubectl -n fleet-local get bundles | grep helm
```

## Drift Detection and Reconciliation

Fleet continuously monitors deployed resources. If someone modifies a resource directly (bypassing Git), Fleet detects the drift and re-applies the desired state from Git.

This is the core GitOps guarantee: Git is the source of truth. Manual changes are overwritten on the next reconciliation cycle.

Check if any bundles have drifted:

```bash
kubectl -n fleet-local get bundles -o jsonpath='{range .items[*]}{.metadata.name}: {.status.conditions[*].type}{"\n"}{end}'
```

## Fleet in the Rancher UI

In the Rancher UI, Fleet is accessible under **Continuous Delivery** in the top navigation:

- **Git Repos** - view and create GitRepo resources
- **Clusters** - see which clusters Fleet manages and their group membership
- **Bundles** - inspect individual bundles and their deployment status

## Cleaning Up

Remove the GitRepo resources:

```bash
kubectl -n fleet-local delete gitrepo sample-app
kubectl -n fleet-local delete gitrepo helm-app
```

Fleet automatically removes the deployed resources when the GitRepo is deleted (unless `keepResources: true` is set).

## Summary

Fleet brings GitOps to Rancher natively. You define what to deploy (GitRepo with paths), where to deploy (cluster selectors), and Fleet handles the rest - including continuous reconciliation and drift correction. In the next unit, you will build on Fleet to implement CI/CD pipelines that automatically push changes through your deployment workflow.
