---
kind: tutorial

title: Multi-Cluster Management with Rancher

description: |
  Learn how to import existing clusters into Rancher, provision new downstream clusters,
  and manage multiple clusters from a single control plane.

categories:
  - kubernetes
  - containers

tagz:
  - Rancher
  - Multi-Cluster
  - Cluster Import
  - Downstream Clusters
  - Fleet

createdAt: 2026-08-27
updatedAt: 2026-08-27

playground:
  name: ubuntu-k3s-bare
---

## Overview

Managing a single Kubernetes cluster is one thing. In production, organizations often run multiple clusters - different environments (dev, staging, production), different regions, or different teams. Rancher was built for exactly this scenario: managing many clusters from one place.

This tutorial covers how Rancher handles multiple clusters, how to import existing clusters, and how the cluster lifecycle works.

## The Multi-Cluster Model

Rancher's architecture separates the **management cluster** (where Rancher runs) from **downstream clusters** (where workloads run). From the Rancher UI, you manage all downstream clusters as if they were local.

Each downstream cluster runs a lightweight agent that maintains a persistent connection back to the Rancher server. This agent:

- Reports cluster health and resource usage
- Executes management commands from Rancher
- Enforces RBAC policies defined in Rancher

## Cluster Types in Rancher

Rancher supports three models for managed clusters:

**Imported clusters** - existing clusters that you register with Rancher. You install the Rancher agent manually, and Rancher gains visibility and management control.

**Rancher-provisioned clusters** - clusters created through Rancher using supported providers:
- RKE2 / K3s on infrastructure you provide (bare metal, VMs)
- Hosted Kubernetes services: EKS, AKS, GKE

**Local cluster** - the cluster where Rancher itself runs. It appears in the cluster list but typically should not host user workloads in production.

## Importing an Existing Cluster

To import a cluster into Rancher, you generate a registration command from the Rancher UI or API, then run it on the target cluster.

### Step 1: Generate the Import Command

From the Rancher home page, click **Import Existing**. Rancher provides a `kubectl apply` command that installs the cluster agent.

You can also generate the import manifest via the API:

```bash
curl -sk -u admin:admin \
  https://rancher.localhost/v3/clusterregistrationtokens \
  | jq '.data[0].command'
```

### Step 2: Apply the Agent on the Target Cluster

On the cluster you want to import, run the provided command. It looks like:

```bash
kubectl apply -f https://rancher.localhost/v3/import/<token>.yaml
```

The agent pods start in the `cattle-system` namespace of the downstream cluster and establish a tunnel back to the Rancher server.

### Step 3: Verify Registration

Back in the Rancher UI, the imported cluster transitions from **Pending** to **Active** once the agent connects successfully.

From the CLI on the management cluster:

```bash
kubectl get clusters.management.cattle.io
```

This lists all clusters managed by this Rancher instance with their current state.

## Understanding the Cluster Agent

The cluster agent runs two key components on each downstream cluster:

**cattle-cluster-agent** - maintains the connection to the Rancher server, syncs cluster state, and relays management commands.

**cattle-node-agent** (DaemonSet) - runs on every node and provides node-level operations like executing kubectl commands and collecting node health data.

Check the agent status on the local cluster:

```bash
kubectl -n cattle-system get pods
kubectl -n cattle-system get deployments
```

## Cluster Lifecycle Operations

Once a cluster is managed by Rancher, you can perform lifecycle operations from the central UI:

**Inspect** - view nodes, workloads, events, and resource consumption across all clusters from one dashboard.

**Configure** - modify cluster settings, upgrade Kubernetes versions (for Rancher-provisioned clusters), and adjust node pools.

**Rotate certificates** - trigger certificate rotation for cluster components.

**Snapshot and restore** - take etcd snapshots and restore from them (for RKE2/K3s clusters provisioned by Rancher).

## Cluster Selectors and Labels

Rancher allows you to label clusters and use selectors to target operations at groups of clusters:

```bash
kubectl label clusters.management.cattle.io local environment=lab
```

These labels become important when using Fleet for GitOps - you can target deployments to clusters matching specific labels (e.g., deploy to all clusters labeled `environment=production`).

View cluster labels:

```bash
kubectl get clusters.management.cattle.io --show-labels
```

## Managing Access Across Clusters

Rancher's RBAC extends across all managed clusters. From the global level, you can:

- Grant a user access to specific clusters
- Assign cluster-level roles (Owner, Member, Read-Only)
- Define project memberships that carry across cluster boundaries

This centralized access model is one of Rancher's primary value propositions - instead of managing kubeconfig files and RBAC for each cluster independently, you handle it all from one place.

## Switching Between Clusters

From the CLI, you can use Rancher's `kubectl` proxy or generate per-cluster kubeconfig files.

Check which clusters are available:

```bash
kubectl config get-contexts
```

In the Rancher UI, switching clusters is a single click from the home page or the cluster dropdown in the top navigation.

## Summary

Rancher turns multi-cluster management from a complex operational burden into a centralized workflow. You can import existing clusters, provision new ones, and manage them all through a single UI and API. Cluster agents maintain the connection, while Rancher provides unified RBAC, lifecycle management, and visibility. In the next unit, you will learn how Rancher Fleet takes this further by enabling GitOps-driven deployments across all your managed clusters.
