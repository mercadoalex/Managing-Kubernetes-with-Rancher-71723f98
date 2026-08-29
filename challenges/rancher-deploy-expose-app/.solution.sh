#!/bin/bash
set -euo pipefail

# Runs on the dev-machine workstation, using the pre-provisioned kubeconfig.
export KUBECONFIG="$HOME/.kube/config"

# Create the namespace
kubectl create namespace demo

examinerctl task wait verify_namespace --timeout 30s

# Deploy NGINX and scale to 3 replicas
kubectl -n demo create deployment nginx --image=nginx:1.27
kubectl -n demo scale deployment nginx --replicas=3
kubectl -n demo rollout status deployment/nginx --timeout=180s

examinerctl task wait verify_deployment_scaled --timeout 60s

# Expose the deployment on port 80
kubectl -n demo expose deployment nginx --port=80

examinerctl task wait verify_service --timeout 30s

# Route external traffic with an ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  namespace: demo
spec:
  ingressClassName: traefik
  rules:
  - host: nginx.localhost
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
EOF

examinerctl task wait verify_ingress --timeout 30s
examinerctl task wait verify_http_reachable --timeout 90s
