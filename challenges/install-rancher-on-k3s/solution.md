---
title: Install Rancher Using Helm
---

The installation follows the standard Rancher deployment workflow: cert-manager first, then an ingress controller, then Rancher itself.

<!--more-->

## Install cert-manager

Add the Jetstack repository and install cert-manager with its CRDs:

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.installCRDs=true
```

Wait for all cert-manager pods to become ready:

```bash
kubectl rollout status deployment cert-manager -n cert-manager
kubectl rollout status deployment cert-manager-webhook -n cert-manager
```

## Install the NGINX Ingress Controller

Add the ingress-nginx repository and install the controller:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

Wait for the controller to be ready:

```bash
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx
```

## Install Rancher

Add the Rancher stable repository, create the namespace, and install:

```bash
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update

kubectl create namespace cattle-system

helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.localhost \
  --set bootstrapPassword=admin \
  --set replicas=1
```

Using `replicas=1` is appropriate for a single-node K3s cluster. In production you would use 3 replicas for high availability.

Wait for Rancher to finish rolling out:

```bash
kubectl rollout status deployment rancher -n cattle-system
```

## Verify

Check that everything is running:

```bash
kubectl get pods -n cert-manager
kubectl get pods -n ingress-nginx
kubectl get pods -n cattle-system
kubectl get ingress -n cattle-system
```

The ingress should show the hostname you configured. Rancher is now installed and managing the local cluster.
