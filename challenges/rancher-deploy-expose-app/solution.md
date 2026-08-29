---
title: Deploy, Scale, and Expose NGINX
---

The task mirrors the everyday workload flow in Rancher, just driven from the command line: create a namespace, run a deployment, expose it, and route traffic in from outside.

<!--more-->

## Create the Namespace

Everything lives in the `demo` namespace, so create it first:

```bash
kubectl create namespace demo
```

## Deploy and Scale

Create an NGINX deployment and scale it to three replicas. You can do this in two commands:

```bash
kubectl -n demo create deployment nginx --image=nginx:1.27
kubectl -n demo scale deployment nginx --replicas=3
```

Wait until all three pods are ready:

```bash
kubectl -n demo rollout status deployment/nginx
```

## Expose with a Service

`kubectl expose` creates a Service whose selector already matches the deployment's pods:

```bash
kubectl -n demo expose deployment nginx --port=80
```

Confirm the service picked up endpoints:

```bash
kubectl -n demo get endpoints nginx
```

If the endpoints list is empty, the pods are not ready yet or the selector does not match.

## Route Traffic with an Ingress

K3s ships the Traefik ingress controller, so no controller install is needed. Create an ingress that sends a host to the `nginx` service, using the `traefik` ingress class:

```bash
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
```

## Verify Reachability

You do not need real DNS - send the matching `Host` header to Traefik on the control-plane node (`172.16.0.2`):

```bash
curl -s -o /dev/null -w '%{http_code}\n' -H "Host: nginx.localhost" http://172.16.0.2
```

A `200` means traffic is flowing from Traefik through the service to the NGINX pods. Everything you just built appears in the Rancher UI under the cluster's Workload and Service Discovery sections.
