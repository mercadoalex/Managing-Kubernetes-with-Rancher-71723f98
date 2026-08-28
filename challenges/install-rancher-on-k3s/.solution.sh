#!/bin/bash
set -euo pipefail

# Install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.installCRDs=true

kubectl rollout status deployment cert-manager -n cert-manager --timeout=120s
kubectl rollout status deployment cert-manager-webhook -n cert-manager --timeout=120s
kubectl rollout status deployment cert-manager-cainjector -n cert-manager --timeout=120s

examinerctl task wait verify_cert_manager --timeout 60s

# Install NGINX ingress controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace

kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx --timeout=120s

examinerctl task wait verify_ingress_controller --timeout 60s

# Install Rancher
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update
kubectl create namespace cattle-system

helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.localhost \
  --set bootstrapPassword=admin \
  --set replicas=1

kubectl rollout status deployment rancher -n cattle-system --timeout=300s

examinerctl task wait verify_rancher_namespace --timeout 30s
examinerctl task wait verify_rancher_running --timeout 120s
examinerctl task wait verify_rancher_ingress --timeout 60s
