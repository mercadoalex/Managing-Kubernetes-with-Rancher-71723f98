---
kind: tutorial

title: Deploying Workloads with Rancher

description: |
  Deploy applications on a Rancher-managed cluster using both the UI and CLI.
  Learn how to create deployments, expose services, and install Helm charts through the Rancher catalog.

categories:
  - kubernetes
  - containers

tagz:
  - Rancher
  - Deployments
  - Services
  - Helm
  - Workloads

createdAt: 2026-08-27
updatedAt: 2026-08-27

playground:
  name: ubuntu-k3s-bare
---

## Overview

Rancher provides multiple ways to deploy workloads to a managed cluster. You can use the web UI for visual management, `kubectl` for scripted operations, or the built-in Helm chart catalog for packaged applications. This tutorial covers all three approaches.

## Deploying with kubectl

The most direct way to deploy a workload is through `kubectl`. Rancher does not change how standard Kubernetes resources work - it simply observes and manages them.

Create a namespace for your applications:

```bash
kubectl create namespace demo
```

Deploy an NGINX instance:

```bash
kubectl -n demo create deployment nginx --image=nginx:1.27 --replicas=2
```

Verify the deployment:

```bash
kubectl -n demo get deployments
kubectl -n demo get pods
```

Expose it as a service:

```bash
kubectl -n demo expose deployment nginx --port=80 --type=ClusterIP
```

Confirm the service is accessible from within the cluster:

```bash
kubectl -n demo get svc nginx
curl -s $(kubectl -n demo get svc nginx -o jsonpath='{.spec.clusterIP}')
```

Everything you just created is immediately visible in the Rancher UI under the Workload section of the cluster dashboard.

## Deploying Through the Rancher UI

The Rancher UI provides a form-based workflow for creating deployments without writing YAML.

The flow for creating a deployment in the UI is:

1. Navigate to the cluster dashboard
2. Go to **Workload > Deployments**
3. Click **Create**
4. Fill in the deployment name, container image, namespace, and replica count
5. Optionally configure environment variables, ports, volumes, and resource limits
6. Click **Create**

Behind the scenes, Rancher translates the form inputs into a standard Kubernetes Deployment manifest and applies it to the cluster.

## Scaling Workloads

Scale the NGINX deployment from the CLI:

```bash
kubectl -n demo scale deployment nginx --replicas=4
```

Watch the pods come up:

```bash
kubectl -n demo get pods -w
```

You can also scale through the Rancher UI by editing the deployment and adjusting the replica count. Both methods produce the same result - they patch the deployment's `spec.replicas` field.

## Creating Services and Ingresses

To make a workload accessible outside the cluster, create an ingress resource:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  namespace: demo
spec:
  ingressClassName: nginx
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

Verify the ingress was created:

```bash
kubectl -n demo get ingress
```

Test it:

```bash
curl -sk -H "Host: nginx.localhost" https://localhost
```

## Installing Applications from the Rancher Chart Catalog

Rancher includes a built-in chart catalog that provides curated Helm charts. You can browse and install them from the UI under **Apps > Charts**.

From the CLI, you can achieve the same by adding Helm repositories and installing charts directly. For example, deploying Redis:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm install redis bitnami/redis \
  --namespace demo \
  --set architecture=standalone \
  --set auth.enabled=false
```

Wait for it to be ready:

```bash
kubectl -n demo rollout status statefulset/redis-master
```

Verify Redis is running:

```bash
kubectl -n demo exec -it redis-master-0 -- redis-cli ping
```

In the Rancher UI, this Helm release appears under **Apps > Installed Apps** with full lifecycle management (upgrade, rollback, uninstall).

## Viewing Workload Health

Rancher aggregates workload health across the cluster. From the cluster dashboard:

- **Green** - all replicas are available
- **Yellow** - deployment is progressing (rolling update, scaling)
- **Red** - pods are in error state (CrashLoopBackOff, ImagePullBackOff, etc.)

You can also check health from the CLI:

```bash
kubectl -n demo get deployments
kubectl -n demo describe deployment nginx
```

The `AVAILABLE` column in the deployment list shows how many replicas are serving traffic.

## Cleaning Up

Remove the demo resources:

```bash
kubectl delete namespace demo
```

This deletes all deployments, services, ingresses, and pods within the namespace.

## Summary

You have deployed workloads through both `kubectl` and the Rancher UI, exposed services via ingress, installed a Helm chart from the catalog, and observed workload health. Rancher acts as a management layer on top of standard Kubernetes - it does not change how resources work, but it provides visibility and simplified management. In the next unit, you will learn how to organize cluster resources using namespaces, projects, and RBAC.
