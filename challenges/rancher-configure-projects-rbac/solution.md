---
title: Namespace, Quota, and Scoped RBAC
---

The work here is the manual version of what Rancher Projects and roles automate: a namespace to hold a team's resources, a quota to keep it in bounds, and a role plus binding that grant one user narrow, read-only access.

<!--more-->

## Create the Namespace

```bash
kubectl create namespace team-frontend
```

## Cap Resource Usage

A ResourceQuota with a `spec.hard` map limits what the namespace can consume. Cap both pods and CPU requests at a minimum:

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

## Define a Read-Only Role

Grant only `get`, `list`, and `watch`. Leaving out every write verb is what makes this role safe to hand to a viewer:

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

## Bind the Role to alice

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

## Confirm the Boundary

Impersonate alice to check both sides of the permission boundary:

```bash
kubectl auth can-i list pods --namespace team-frontend --as alice     # yes
kubectl auth can-i delete pods --namespace team-frontend --as alice   # no
kubectl auth can-i create deployments --namespace team-frontend --as alice  # no
```

Reads are allowed, writes are denied. In Rancher, assigning the built-in Project Read-Only role produces the same effect through the UI, generating the roles and bindings for you.
