#!/bin/bash
set -euo pipefail

# Runs on the dev-machine workstation, using the pre-provisioned kubeconfig.
export KUBECONFIG="$HOME/.kube/config"

# Create the team namespace
kubectl create namespace team-frontend

examinerctl task wait verify_namespace --timeout 30s

# Cap resource consumption for the namespace
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

examinerctl task wait verify_quota --timeout 30s

# Define a read-only role
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

examinerctl task wait verify_role --timeout 30s

# Bind the role to user alice
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

examinerctl task wait verify_can_read --timeout 30s
examinerctl task wait verify_cannot_write --timeout 30s
