---
kind: tutorial

title: Managing Cluster Resources with Rancher

description: |
  Organize cluster resources using Rancher Projects, configure resource quotas,
  and set up RBAC for multi-team environments.

categories:
  - kubernetes
  - containers

tagz:
  - Rancher
  - RBAC
  - Projects
  - Namespaces
  - Resource Quotas

createdAt: 2026-08-27
updatedAt: 2026-08-27

playground:
  name: ubuntu-k3s-bare
---

## Overview

In a shared Kubernetes cluster, you need mechanisms to isolate teams, control resource consumption, and restrict access. Kubernetes provides namespaces and RBAC natively. Rancher extends these with Projects - a grouping abstraction that bundles namespaces together and applies policies at the group level.

This tutorial covers namespace management, Rancher Projects, resource quotas, and RBAC configuration.

## Namespaces

Namespaces are the basic unit of isolation in Kubernetes. Create a few namespaces to simulate a multi-team environment:

```bash
kubectl create namespace team-frontend
kubectl create namespace team-backend
kubectl create namespace team-data
```

List all namespaces:

```bash
kubectl get namespaces
```

Each namespace provides a scope for resource names and a boundary for RBAC policies.

## Rancher Projects

A Rancher Project groups one or more namespaces under a single management unit. Projects provide:

- A single RBAC boundary across multiple namespaces
- Aggregated resource quotas
- Network policy enforcement at the project level

Projects are a Rancher-specific concept - they do not exist in upstream Kubernetes. They are stored as custom resources in the cluster.

### Creating a Project

In the Rancher UI, navigate to **Cluster > Projects/Namespaces** and click **Create Project**. Assign a name and optionally move existing namespaces into it.

From the CLI, you can inspect projects as custom resources:

```bash
kubectl get projects.management.cattle.io -n local
```

### Assigning Namespaces to a Project

In the UI, you can drag namespaces into a project or edit the namespace to set its project membership.

From the CLI, namespaces are associated with projects through annotations:

```bash
kubectl get namespace team-frontend -o jsonpath='{.metadata.annotations}'
```

The `field.cattle.io/projectId` annotation links a namespace to its parent project.

## Resource Quotas

Resource quotas prevent any single team from consuming all cluster resources. Rancher allows you to set quotas at the project level, which are then distributed across the project's namespaces.

### Setting Namespace-Level Quotas

Apply a resource quota directly to a namespace:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-frontend-quota
  namespace: team-frontend
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 2Gi
    limits.cpu: "4"
    limits.memory: 4Gi
    pods: "20"
EOF
```

Verify the quota:

```bash
kubectl -n team-frontend describe resourcequota team-frontend-quota
```

### Setting LimitRanges

LimitRanges define default resource requests and limits for containers that do not specify their own:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: team-frontend-limits
  namespace: team-frontend
spec:
  limits:
  - default:
      cpu: 500m
      memory: 256Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    type: Container
EOF
```

Now any pod created in `team-frontend` without explicit resource specifications will get these defaults applied automatically.

## Role-Based Access Control (RBAC)

Kubernetes RBAC controls who can do what within a cluster. It uses four key resources:

- **Role** - defines permissions within a single namespace
- **ClusterRole** - defines permissions cluster-wide
- **RoleBinding** - assigns a Role to a user/group within a namespace
- **ClusterRoleBinding** - assigns a ClusterRole to a user/group cluster-wide

### Creating a Role

Create a role that allows reading pods and deployments in the `team-frontend` namespace:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: frontend-viewer
  namespace: team-frontend
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
EOF
```

### Creating a RoleBinding

Bind the role to a user:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: frontend-viewer-binding
  namespace: team-frontend
subjects:
- kind: User
  name: alice
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: frontend-viewer
  apiGroup: rbac.authorization.k8s.io
EOF
```

Verify the binding:

```bash
kubectl -n team-frontend get rolebindings
kubectl -n team-frontend describe rolebinding frontend-viewer-binding
```

### Rancher's Built-in Roles

Rancher provides predefined global roles and project roles that simplify RBAC:

- **Cluster Owner** - full control over the cluster
- **Cluster Member** - can view most resources and create projects
- **Project Owner** - full control within a project's namespaces
- **Project Member** - can manage workloads within the project
- **Read-Only** - view access only

These roles are managed through the Rancher UI under **Users & Authentication > Roles**.

## Testing Access

You can verify RBAC is working by checking what a specific user can do:

```bash
kubectl auth can-i list pods --namespace team-frontend --as alice
kubectl auth can-i create deployments --namespace team-frontend --as alice
kubectl auth can-i delete pods --namespace team-backend --as alice
```

The first two should return `yes` (viewing is allowed), while the last should return `no` (alice has no permissions in `team-backend`).

## Network Policies

For additional isolation between projects, you can apply network policies that restrict pod-to-pod communication:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-cross-namespace
  namespace: team-frontend
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}
EOF
```

This policy restricts ingress traffic to `team-frontend` pods so that only other pods within the same namespace can communicate with them.

## Cleaning Up

```bash
kubectl delete namespace team-frontend team-backend team-data
```

## Summary

You have learned how to organize a cluster for multi-team use. Rancher Projects group namespaces and provide an additional RBAC boundary. Resource quotas and limit ranges prevent resource hogging. Kubernetes RBAC combined with Rancher's built-in roles gives you fine-grained access control. In the next unit, you will move beyond a single cluster and learn how Rancher manages multiple clusters simultaneously.
