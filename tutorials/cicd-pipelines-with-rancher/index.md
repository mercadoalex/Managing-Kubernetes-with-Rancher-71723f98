---
kind: tutorial

title: CI/CD Pipelines with Rancher

description: |
  Build end-to-end CI/CD pipelines that integrate external CI systems with
  Rancher Fleet for continuous delivery to Kubernetes clusters.

categories:
  - kubernetes
  - containers

tagz:
  - Rancher
  - CI/CD
  - Fleet
  - GitHub Actions
  - Pipelines
  - Container Registry

createdAt: 2026-08-27
updatedAt: 2026-08-27

playground:
  name: ubuntu-k3s-bare
---

## Overview

A CI/CD pipeline for Kubernetes typically has two halves:

- **CI (Continuous Integration)** - build the application, run tests, create a container image, and push it to a registry
- **CD (Continuous Delivery)** - deploy the new image to one or more clusters

Rancher Fleet handles the CD side natively. The CI side is handled by external systems like GitHub Actions, GitLab CI, or Jenkins. This tutorial shows how to connect the two into a seamless pipeline.

## The CI/CD Model with Fleet

The recommended architecture:

1. Developer pushes code to the **application repository**
2. CI system builds and tests the code, then pushes an image to a container registry
3. CI updates the **deployment repository** (or the same repo) with the new image tag
4. Fleet detects the change in the deployment repository and rolls out the update to target clusters

This separation of concerns (app code vs. deployment manifests) is a GitOps best practice. The deployment repository is the source of truth for what runs in the cluster.

## Setting Up a Container Registry

The playground includes access to a private registry at `registry.iximiuz.com`. Verify it is reachable:

```bash
curl -s https://registry.iximiuz.com/v2/ | jq .
```

You can also use Docker Hub or any OCI-compatible registry. For this tutorial, we will build and push images locally.

## Building a Container Image

Create a simple application:

```bash
mkdir -p /tmp/demo-app
cat <<EOF > /tmp/demo-app/main.go
package main

import (
    "fmt"
    "net/http"
    "os"
)

func main() {
    version := os.Getenv("APP_VERSION")
    if version == "" {
        version = "unknown"
    }
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintf(w, "Hello from version %s\n", version)
    })
    http.ListenAndServe(":8080", nil)
}
EOF

cat <<EOF > /tmp/demo-app/Dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY main.go .
RUN go build -o server main.go

FROM alpine:3.20
COPY --from=builder /app/server /server
ENV APP_VERSION=1.0.0
EXPOSE 8080
CMD ["/server"]
EOF
```

Build the image using the K3s built-in containerd (via nerdctl or ctr):

```bash
cd /tmp/demo-app
docker build -t registry.iximiuz.com/demo-app:v1.0.0 .
docker push registry.iximiuz.com/demo-app:v1.0.0
```

## Creating Deployment Manifests

Create a deployment manifest that Fleet will manage:

```bash
mkdir -p /tmp/fleet-manifests
cat <<EOF > /tmp/fleet-manifests/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
      - name: demo-app
        image: registry.iximiuz.com/demo-app:v1.0.0
        ports:
        - containerPort: 8080
        env:
        - name: APP_VERSION
          value: "1.0.0"
---
apiVersion: v1
kind: Service
metadata:
  name: demo-app
  namespace: default
spec:
  selector:
    app: demo-app
  ports:
  - port: 80
    targetPort: 8080
EOF
```

In a real workflow, these manifests live in a Git repository that Fleet watches.

## GitHub Actions Pipeline Example

A typical GitHub Actions workflow that implements the CI half:

```yaml
name: CI Pipeline

on:
  push:
    branches: [main]

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    - name: Build container image
      run: |
        docker build -t registry.example.com/demo-app:${{ github.sha }} .

    - name: Push to registry
      run: |
        echo "${{ secrets.REGISTRY_PASSWORD }}" | docker login registry.example.com -u ${{ secrets.REGISTRY_USERNAME }} --password-stdin
        docker push registry.example.com/demo-app:${{ github.sha }}

    - name: Update deployment manifest
      run: |
        sed -i "s|image:.*|image: registry.example.com/demo-app:${{ github.sha }}|" manifests/deployment.yaml
        git config user.name "CI Bot"
        git config user.email "ci@example.com"
        git add manifests/
        git commit -m "Deploy ${{ github.sha }}"
        git push
```

The last step updates the deployment manifest with the new image tag and commits it back. Fleet picks up this change and deploys the new version automatically.

## GitLab CI Pipeline Example

The equivalent in GitLab CI:

```yaml
stages:
  - build
  - deploy

build:
  stage: build
  image: docker:24
  services:
    - docker:24-dind
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA

update-manifests:
  stage: deploy
  image: alpine/git
  script:
    - git clone https://token:${DEPLOY_TOKEN}@gitlab.com/org/fleet-manifests.git
    - cd fleet-manifests
    - "sed -i \"s|image:.*|image: ${CI_REGISTRY_IMAGE}:${CI_COMMIT_SHA}|\" deployment.yaml"
    - git add .
    - git commit -m "Deploy ${CI_COMMIT_SHA}"
    - git push
```

## Connecting Fleet to the Deployment Repository

Once your CI pushes updated manifests to a Git repository, configure Fleet to watch it:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: fleet.cattle.io/v1alpha1
kind: GitRepo
metadata:
  name: demo-app-deploy
  namespace: fleet-local
spec:
  repo: https://github.com/your-org/fleet-manifests
  branch: main
  paths:
  - ./
  pollingInterval: 30s
  targets:
  - clusterSelector:
      matchLabels:
        management.cattle.io/cluster-display-name: local
EOF
```

The `pollingInterval` controls how frequently Fleet checks for new commits. For production, 30-60 seconds is typical.

## Private Repository Authentication

For private Git repositories, create a Secret with credentials:

```bash
kubectl -n fleet-local create secret generic git-auth \
  --from-literal=username=git-user \
  --from-literal=password=git-token
```

Reference it in the GitRepo:

```yaml
spec:
  clientSecretName: git-auth
```

For SSH-based authentication:

```bash
kubectl -n fleet-local create secret generic git-ssh \
  --from-file=ssh-privatekey=/path/to/key
```

## Image Update Automation

An alternative to having CI commit manifest changes is to use image update automation. Fleet can be combined with tools that watch a container registry and automatically update image tags in Git when a new version appears.

The workflow becomes:
1. CI builds and pushes a new image tag
2. An automation tool detects the new tag in the registry
3. It updates the manifest in Git with the new tag
4. Fleet picks up the change and deploys

This removes the need for CI to have write access to the deployment repository.

## Rolling Updates and Rollbacks

When Fleet deploys a new version, Kubernetes handles the rolling update:

```bash
kubectl rollout status deployment/demo-app
```

If something goes wrong, revert by:
- Reverting the commit in Git (Fleet will reconcile back to the previous state)
- Or using `kubectl rollout undo deployment/demo-app` (Fleet will detect drift and re-apply from Git on the next cycle, so Git revert is the proper GitOps approach)

Check rollout history:

```bash
kubectl rollout history deployment/demo-app
```

## Pipeline Observability

Monitor the pipeline end-to-end:

```bash
# Check Fleet GitRepo status
kubectl -n fleet-local get gitrepo demo-app-deploy -o wide

# Check bundle deployment state
kubectl -n fleet-local get bundles | grep demo-app

# Verify the running version
kubectl get deployment demo-app -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## Summary

You now have the complete picture of CI/CD with Rancher. External CI systems handle the build and test phase, while Fleet handles continuous delivery. The deployment repository in Git serves as the source of truth, and Fleet ensures clusters always match that truth. In the next unit, you will set up observability to monitor both your pipelines and the workloads they deploy.
