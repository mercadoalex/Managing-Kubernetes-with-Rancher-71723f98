---
kind: unit

title: Importing and Provisioning Clusters

name: importing-and-provisioning-clusters
---

This lesson introduces Rancher's multi-cluster capabilities. You will learn how to import existing clusters into Rancher, provision new downstream clusters, and manage them from a single control plane.

<!-- [image] rancher-multi-cluster.png - Diagram of the management cluster controlling several downstream clusters -->

## Cluster Drivers and Registration

The lesson covers the different cluster drivers Rancher supports, the registration process for importing clusters, and how to switch between cluster contexts in the Rancher UI. It also explains the communication model between the Rancher management server and downstream clusters via the cluster agent.

<!-- [image] rancher-cluster-agent.png - Diagram of the cluster agent tunnel between Rancher server and a downstream cluster -->
