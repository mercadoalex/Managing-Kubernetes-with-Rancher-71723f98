---
title: Install Fleet and Register the Local Cluster
---

Standalone Fleet gives you Rancher's cluster registration and targeting model without needing a full Rancher server and a second cluster. Install it, let the local agent register, then label the cluster so GitOps deployments can find it.

<!--more-->

## Install Fleet

Fleet is published as two OCI Helm charts - the CRDs and the controller. Install them in order into `cattle-fleet-system`:

```bash
helm -n cattle-fleet-system install --create-namespace --wait \
  fleet-crd oci://reg.rancher.com/rancher/fleet-crd

helm -n cattle-fleet-system install --create-namespace --wait \
  fleet oci://reg.rancher.com/rancher/fleet
```

Confirm the controller is running:

```bash
kubectl -n cattle-fleet-system get pods
```

## Confirm Registration

The local Fleet agent registers the cluster automatically. Wait for the `Cluster` object to appear in `fleet-local`:

```bash
kubectl -n fleet-local get clusters.fleet.cattle.io
```

You will see a single cluster (named `local`) once the agent connects.

## Label the Cluster

Add an `env` label to the registered cluster object so a GitRepo can target it:

```bash
CLUSTER=$(kubectl -n fleet-local get clusters.fleet.cattle.io -o jsonpath='{.items[0].metadata.name}')
kubectl -n fleet-local label cluster.fleet.cattle.io "${CLUSTER}" env=lab
```

Verify the label landed:

```bash
kubectl -n fleet-local get clusters.fleet.cattle.io --show-labels
```

This is exactly how Rancher targets downstream clusters: register the cluster, label it, then match those labels from a GitRepo's `clusterSelector`.
