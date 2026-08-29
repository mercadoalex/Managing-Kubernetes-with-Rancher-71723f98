---
kind: unit

title: What is Rancher?

name: what-is-rancher
---

Rancher is an open-source platform for managing Kubernetes clusters at scale. It provides a unified control plane that simplifies cluster operations - from provisioning and configuration to monitoring and access control - across any infrastructure.

::image-box
---
:src: __static__/rancher-overview-v1.png
:alt: Rancher as a single control plane that an operator uses to manage Kubernetes clusters across cloud, on-premises, and edge infrastructure
:max-width: 900px
---
::

## Why Rancher Exists

Managing a single Kubernetes cluster is already complex. Managing multiple clusters across different environments (on-premises, cloud, edge) multiplies that complexity. Rancher solves this by offering a single pane of glass where operators can manage all their clusters, regardless of where they run.

::image-box
---
:src: __static__/rancher-complexity-v1.png
:alt: A before-and-after comparison - without Rancher an operator juggles many clusters each with its own separate tooling, and with Rancher the same clusters are managed through one unified control plane
:max-width: 900px
---
::

## What This Course Covers

In the following lessons, you will install Rancher on a K3s cluster, explore its management capabilities, and work your way up to multi-cluster GitOps, CI/CD, and observability. Each lesson builds on the previous one, so by the end you will have hands-on experience with the full Rancher workflow.

## About the Playground

This is a Rancher course, not a Kubernetes course. Every lesson runs on a playground that already has a multi-node K3s cluster installed and running - you do not set up Kubernetes yourself. Your focus stays on Rancher: installing it, and using it to manage workloads and clusters.

We use K3s as the underlying cluster for a few practical reasons:

- **Lightweight and fast** - K3s is a certified, fully conformant Kubernetes distribution with a small footprint, so the cluster boots quickly and leaves room for Rancher to run.
- **Batteries included** - the playground's K3s ships with Helm, the Traefik ingress controller, and a ServiceLB load balancer already enabled, which gives Rancher a working ingress path out of the box.
- **Same team as Rancher** - K3s and Rancher are both developed by SUSE, so they are a natural, well-supported pairing.

::details-box
---
:summary: What exactly is K3s, and how is it different from Kubernetes?
---

K3s is a fully certified, conformant Kubernetes distribution. It passes the same CNCF conformance tests as any other Kubernetes, exposes the same APIs, and runs the same workloads. Anything you learn on K3s about deployments, services, namespaces, and RBAC applies directly to any other cluster. In that sense, learning on K3s is learning Kubernetes.

What makes it different is the packaging, not the behaviour. Standard Kubernetes is assembled from several separate components (the API server, scheduler, controller manager, etcd, and a container runtime) that you install and wire together. K3s bundles all of that into a single binary under 100 MB, with sensible defaults chosen for you. The name is a nod to that trimming down: Kubernetes is often abbreviated "K8s", and K3s is the lighter take on it.

A few things make it lightweight:

- **One binary, one process to run.** K3s packages the control plane and node components together and starts them as a single service, so a cluster comes up in seconds.
- **A simpler datastore option.** It can use an embedded lightweight database instead of a full etcd cluster, which removes a lot of operational overhead for small setups (etcd is still available for high-availability clusters).
- **Batteries included.** K3s ships with common pieces already enabled - the Traefik ingress controller, the ServiceLB load balancer, CoreDNS, local-path storage, and metrics-server - which is exactly why this playground has a working ingress path for Rancher out of the box.

::image-box
---
:src: __static__/k3s-internals-v1.png
:alt: The internals of K3s packaged as a single binary - control plane (API server, scheduler, controller manager, embedded datastore), node components (kubelet, containerd, networking), and bundled add-ons (Traefik, ServiceLB, CoreDNS, local-path, metrics-server), contrasted with standard Kubernetes assembled from separate components
:max-width: 850px
---
::

Because of that small footprint, K3s is popular at the edge, in IoT and CI environments, and for development, but it is also used in real production. For heavier or more customized production clusters, SUSE offers RKE2, and full installers like kubeadm remain common - Rancher can manage all of them. Here, K3s simply gives us a fast, faithful Kubernetes to run Rancher on without spending the course setting up the cluster itself.

::

A few components are still installed by hand during the course - cert-manager and Rancher itself in the next lesson, and things like the monitoring stack later on - because installing and configuring them is part of what you are here to learn. What you will never have to do is build the Kubernetes cluster underneath.

::image-box
---
:src: __static__/rancher-playground-components-v1.png
:alt: The playground's components in order - K3s with bundled Traefik and ServiceLB provided out of the box, then Helm, cert-manager, and Rancher used or installed during the course
:max-width: 900px
---
::
