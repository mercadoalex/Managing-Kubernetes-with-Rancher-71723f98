---
kind: unit

title: Installing Rancher on K3s

name: installing-rancher-on-k3s
---

This lesson walks you through a full Rancher installation on a K3s cluster. You will install cert-manager for TLS certificate management, deploy an nginx ingress controller, and then install Rancher itself using Helm.

<!-- [image] rancher-install-flow.png - Diagram of the install flow: cert-manager, ingress controller, then Rancher via Helm -->

## Prerequisites on the Cluster

The K3s playground ships with Traefik and ServiceLB disabled, which matches the standard Rancher installation flow. Before installing Rancher, you need:

- **cert-manager** - issues and manages the TLS certificates Rancher needs
- **An ingress controller** - nginx-ingress routes external traffic to the Rancher UI

## Installing Rancher

Once the prerequisites are in place, Rancher installs as a Helm chart. By the end of this lesson, you will have a running Rancher instance accessible through a browser, ready to manage Kubernetes clusters.
