---
title: Install Kong from the Catalog and Route Through It
---

The challenge walks the everyday platform-app path: register a vendor's Helm repository, install the tool from Rancher's catalog, then wire a workload into it. Here it is Kong as a second ingress controller next to the Traefik that k3s already runs.

<!--more-->

## Add the Kong Repository and Install

Kong is not a built-in Rancher chart, so add its Helm repository first. In the Rancher UI this is **Apps > Repositories > Create**; from the terminal it is one command:

```bash
helm repo add kong https://charts.konghq.com
helm repo update
```

Install Kong's `ingress` chart into a `kong` namespace. The chart runs Kong in DB-less mode, so there is nothing else to set up. The one thing this cluster forces is how the gateway is reached: it has no external load balancer, so the gateway's `LoadBalancer` Service would sit at `<pending>` forever. Pin the proxy to a NodePort instead:

```bash
helm install kong kong/ingress \
  --namespace kong --create-namespace \
  --set gateway.proxy.type=NodePort \
  --set gateway.proxy.http.nodePort=30081 \
  --wait --timeout 5m
```

Confirm both pods are up and Kong registered its ingress class:

```bash
kubectl -n kong get pods
kubectl get ingressclass
```

You will see `traefik (default)` and `kong`. The gateway proxy is now on NodePort `30081`:

```bash
kubectl -n kong get svc kong-gateway-proxy
```

## Route a Workload Through Kong

Run a small HTTP workload in a `demo` namespace and put a Service in front of it:

```bash
kubectl create namespace demo
kubectl -n demo create deployment web --image=nginx:1.27
kubectl -n demo expose deployment web --port=80
```

Create an Ingress that names the `kong` class. That single field is what routes the traffic through Kong rather than the default Traefik:

```bash
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
```

## Verify Traffic Flows Through Kong

The gateway listens on NodePort `30081`. Send a request to it on the control-plane node's address:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://172.16.0.2:30081/
```

A `200` means the request went through Kong, matched the Ingress rule, and reached the nginx pod. The same page opens in the browser through the **Kong** tab. Traefik is still the default for every other route - each Ingress chooses its controller with `ingressClassName`.
