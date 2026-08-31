#!/bin/bash
set -euo pipefail

# Runs on the dev-machine workstation, using the pre-provisioned kubeconfig.
export KUBECONFIG="$HOME/.kube/config"

# Add the Kong Helm repo and install the ingress controller with the proxy
# pinned to NodePort 30081 (no external LB on this cluster). Idempotent:
# `helm upgrade --install` re-runs cleanly whether or not Kong is present.
helm repo add kong https://charts.konghq.com
helm repo update

helm upgrade --install kong kong/ingress \
  --namespace kong --create-namespace \
  --set gateway.proxy.type=NodePort \
  --set gateway.proxy.http.nodePort=30081 \
  --wait --timeout 5m

examinerctl task wait verify_kong_installed --timeout 60s
examinerctl task wait verify_ingressclass --timeout 30s
examinerctl task wait verify_nodeport --timeout 30s

# Run a workload for Kong to route to. Idempotent: create only if absent so a
# re-run does not abort under set -e on an "already exists" error.
kubectl get namespace demo >/dev/null 2>&1 || kubectl create namespace demo
kubectl -n demo get deployment web >/dev/null 2>&1 \
  || kubectl -n demo create deployment web --image=nginx:1.27
kubectl -n demo get svc web >/dev/null 2>&1 \
  || kubectl -n demo expose deployment web --port=80
kubectl -n demo rollout status deployment/web --timeout=120s

# Route it through Kong with the kong ingress class. `apply` is idempotent.
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: demo
spec:
  ingressClassName: kong
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
EOF

examinerctl task wait verify_route --timeout 120s
