---
kind: unit

title: What is Rancher?

name: what-is-rancher
---

Rancher is an open-source platform for managing Kubernetes clusters at scale. It provides a unified control plane that simplifies cluster operations - from provisioning and configuration to monitoring and access control - across any infrastructure.

<!-- [image] rancher-overview.png - High-level diagram showing Rancher managing multiple clusters across cloud, on-prem, and edge -->

## Why Rancher Exists

Managing a single Kubernetes cluster is already complex. Managing multiple clusters across different environments (on-premises, cloud, edge) multiplies that complexity. Rancher solves this by offering a single pane of glass where operators can manage all their clusters, regardless of where they run.

## What This Course Covers

In the following lessons, you will install Rancher on a K3s cluster, explore its management capabilities, and work your way up to multi-cluster GitOps, CI/CD, and observability. Each lesson builds on the previous one, so by the end you will have hands-on experience with the full Rancher workflow.

## About the Playground

This is a Rancher course, not a Kubernetes course. Every lesson runs on a playground that already has a multi-node K3s cluster installed and running - you do not set up Kubernetes yourself. Your focus stays on Rancher: installing it, and using it to manage workloads and clusters.

We use K3s as the underlying cluster for a few practical reasons:

- **Lightweight and fast** - K3s is a certified, fully conformant Kubernetes distribution with a small footprint, so the cluster boots quickly and leaves room for Rancher to run.
- **Batteries included** - the playground's K3s ships with Helm, the Traefik ingress controller, and a ServiceLB load balancer already enabled, which gives Rancher a working ingress path out of the box.
- **Same team as Rancher** - K3s and Rancher are both developed by SUSE, so they are a natural, well-supported pairing.

A few components are still installed by hand during the course - cert-manager and Rancher itself in the next lesson, and things like the monitoring stack later on - because installing and configuring them is part of what you are here to learn. What you will never have to do is build the Kubernetes cluster underneath.
