---
title: Deliver a Pinned Image Through Fleet
---

The CI half of a pipeline ends by writing a specific image tag into a set of manifests. This challenge starts where that leaves off: hand those manifests to Fleet and let it deliver them. Because you cannot push to a Git host from inside the playground, the `fleet apply` CLI stands in for the GitRepo - it turns a local directory into the same Bundle a GitRepo would produce.

<!--more-->

## Prepare the Manifests

Create a directory with a Deployment named `cd-app` in a `cd-demo` namespace, pinned to a specific image tag (never `latest`):

```bash
mkdir -p /tmp/cd-manifests
cat <<EOF > /tmp/cd-manifests/cd-app.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cd-demo
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cd-app
  namespace: cd-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cd-app
  template:
    metadata:
      labels:
        app: cd-app
    spec:
      containers:
      - name: cd-app
        image: nginx:1.27.2
        ports:
        - containerPort: 80
EOF
```

The pinned `1.27.2` tag is what a CI job would have written after building and pushing the image.

## Deliver with Fleet

Turn the directory into a Bundle and apply it. `fleet apply` reads the manifests, wraps them in a Bundle, and Fleet delivers it to the local cluster:

```bash
fleet apply --namespace fleet-local cd-app /tmp/cd-manifests
```

Watch the bundle and the workload:

```bash
kubectl -n fleet-local get bundles
kubectl -n cd-demo get deployment cd-app
```

## Confirm the Contract

Fleet now owns the deployment, and the running image is exactly the pinned tag from the manifest:

```bash
kubectl -n cd-demo get deployment cd-app -o jsonpath='{.spec.template.spec.containers[0].image}'
kubectl -n cd-demo get deployment cd-app -o jsonpath='{.metadata.labels}'
```

The image reads `nginx:1.27.2`, and the labels carry Fleet's ownership metadata. To ship a new version, a CI job would rewrite the tag and re-apply - Fleet reconciles the deployment to match, which is the whole point of GitOps-driven continuous delivery.
