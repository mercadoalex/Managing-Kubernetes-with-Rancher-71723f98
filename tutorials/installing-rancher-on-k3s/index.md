---
kind: tutorial

title: Installing Rancher on K3s

description: |
  Walk through the complete Rancher installation process on a K3s cluster -
  from installing cert-manager and an ingress controller to deploying Rancher via Helm.

categories:
  - kubernetes
  - containers

tagz:
  - Rancher
  - K3s
  - Helm
  - cert-manager
  - Ingress

createdAt: 2026-08-27
updatedAt: 2026-08-27

playground:
  name: ubuntu-k3s-bare
---

## Overview

Rancher is installed via a Helm chart into an existing Kubernetes cluster. Before Rancher itself can be deployed, two dependencies must be in place:

1. **cert-manager** - manages TLS certificates for the Rancher UI and API
2. **An ingress controller** - routes external traffic to the Rancher pods

This tutorial walks through the full installation sequence on a K3s cluster that has no pre-installed ingress controller or certificate management.

## Prerequisites

Confirm your K3s cluster is running and `kubectl` is configured:

```bash
kubectl get nodes
```

Verify Helm is available:

```bash
helm version
```

## Step 1: Install cert-manager

cert-manager automates the issuance and renewal of TLS certificates. Rancher uses it to provision its own self-signed or Let's Encrypt certificates.

Add the Jetstack Helm repository:

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

Install cert-manager with its Custom Resource Definitions (CRDs):

```bash
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true
```

Wait for the cert-manager pods to become ready:

```bash
kubectl -n cert-manager rollout status deployment/cert-manager
kubectl -n cert-manager rollout status deployment/cert-manager-webhook
kubectl -n cert-manager rollout status deployment/cert-manager-cainjector
```

Verify the installation:

```bash
kubectl get pods -n cert-manager
```

All three pods (cert-manager, webhook, and cainjector) should be in `Running` state.

## Step 2: Install the NGINX Ingress Controller

The K3s playground has Traefik disabled, so you need an ingress controller to expose Rancher. NGINX Ingress Controller is the most common choice for Rancher deployments.

Add the ingress-nginx Helm repository:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

Install it:

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.https=443
```

Wait for the controller to be ready:

```bash
kubectl -n ingress-nginx rollout status deployment/ingress-nginx-controller
```

Using `NodePort` with port 443 makes Rancher accessible directly on the node's IP without needing a cloud load balancer.

## Step 3: Add the Rancher Helm Repository

```bash
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update
```

You can verify the repository was added:

```bash
helm search repo rancher-stable/rancher
```

## Step 4: Install Rancher

Create the namespace where Rancher will live:

```bash
kubectl create namespace cattle-system
```

Install Rancher with a self-signed certificate (appropriate for learning environments):

```bash
helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.localhost \
  --set bootstrapPassword=admin \
  --set ingress.tls.source=rancher \
  --set replicas=1
```

Key parameters:
- `hostname` - the FQDN for the Rancher UI. In a lab environment, `rancher.localhost` works fine.
- `bootstrapPassword` - the initial admin password for first login.
- `ingress.tls.source=rancher` - uses Rancher's self-signed CA (backed by cert-manager).
- `replicas=1` - a single replica is sufficient for a learning environment.

## Step 5: Wait for Rancher to Start

Rancher takes a few minutes to fully initialize. Monitor the rollout:

```bash
kubectl -n cattle-system rollout status deployment/rancher
```

Check that all Rancher pods are running:

```bash
kubectl -n cattle-system get pods
```

You should see the `rancher` deployment pod in `Running` state along with the `rancher-webhook` pod that appears shortly after.

## Step 6: Verify the Installation

Check the namespaces Rancher created:

```bash
kubectl get namespaces | grep -E "cattle|fleet"
```

You should see:
- `cattle-system` - where Rancher server runs
- `cattle-fleet-system` - where Fleet (the built-in GitOps engine) runs
- `cattle-fleet-local-system` - Fleet's local cluster agent

Verify Rancher is responding by curling its health endpoint:

```bash
curl -sk https://rancher.localhost/healthz
```

If it returns `ok`, Rancher is up and serving requests.

## What Happens During Installation

When Rancher starts, it performs several bootstrap operations:

1. Generates its internal CA certificate (via cert-manager)
2. Creates the `cattle-fleet-system` namespace and deploys Fleet
3. Registers the local cluster as a managed cluster
4. Starts the Rancher webhook for admission control
5. Initializes the admin user with the bootstrap password

This is why the first startup takes longer than a typical Helm install - Rancher is setting up its entire management plane.

## Summary

You now have a working Rancher installation on K3s with:
- cert-manager handling TLS certificates
- NGINX Ingress Controller routing traffic to Rancher
- Rancher server running with a self-signed certificate

In the next unit, you will log into the Rancher UI and explore the cluster dashboard.
