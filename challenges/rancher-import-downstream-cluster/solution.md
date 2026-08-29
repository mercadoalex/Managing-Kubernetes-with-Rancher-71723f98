---
title: Import the Downstream Cluster
---

You have two clusters that do not yet know about each other: Rancher on the upstream cluster, and an empty K3s cluster on `downstream-01`. Bringing the second one under Rancher is a three-part move - tell Rancher you want to add a cluster, let it hand you a registration manifest, and apply that manifest on the cluster you are adding.

<!--more-->

## Create the Import in Rancher

Open the **Rancher** tab and log in. Go to the cluster management view and choose **Import Existing**, then pick the **Generic** type - this works for any standard Kubernetes cluster, which our downstream K3s is. Give it a name like `downstream` and create it.

Rancher immediately shows a registration command. It is a `kubectl apply` of a manifest served from the Rancher server, and it installs the Rancher cluster agent into whatever cluster you run it against. Because our Rancher uses a self-signed certificate, use the **insecure** variant of the command if Rancher offers one.

From the workstation you can watch the new cluster object appear:

```bash
kubectl get clusters.management.cattle.io
```

A generated name like `c-xxxxx` shows up next to `local`, sitting in a `Pending` state until the agent connects.

## Apply the Registration Command on the Downstream Cluster

Switch to the **downstream-01** terminal. This shell is on the downstream cluster itself, and its `kubectl` points at that cluster - which is exactly where the agent needs to go. Paste and run the registration command Rancher gave you.

The agent lands in the `cattle-system` namespace and dials back to Rancher over an outbound tunnel. You can watch it come up:

```bash
kubectl -n cattle-system get pods
```

## Watch It Go Active

Back in the Rancher UI, the `downstream` cluster moves from **Pending** to **Active** as the agent reports in. Confirm the same from the workstation:

```bash
kubectl get clusters.management.cattle.io
```

The imported cluster now shows a Ready condition of `True`, and Rancher manages it alongside `local`. You can switch between the two from the cluster picker and deploy to either one.

## Why the Two Terminals Matter

The single most common mistake here is running the registration command in the wrong place. The manifest must be applied on the cluster being imported, so it goes in the **downstream-01** terminal. The **dev-machine** workstation targets the upstream Rancher cluster - useful for watching the import land, but applying the agent manifest there would try to register Rancher into itself. Keep the two straight and the import is smooth.
