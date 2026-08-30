---
title: Ship a Change Through Fleet and Gitea
---

Continuous delivery with Fleet is a loop: Fleet watches a Git repository, and whatever you commit there is what runs on the cluster. This challenge runs that loop against the self-hosted Gitea server, in two moves - point Fleet at the repo, then push a change and watch it land.

<!--more-->

## Point Fleet at the Gitea Repository

Create a GitRepo in `fleet-local` that points at the Gitea repo. Use the server's IP address, because Fleet clones from a pod inside the cluster and the cluster DNS does not resolve the `gitea` machine name:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: fleet.cattle.io/v1alpha1
kind: GitRepo
metadata:
  name: web-app
  namespace: fleet-local
spec:
  repo: http://172.16.0.4:3000/student/sample-app
  branch: main
  paths:
  - manifests
  targets:
  - clusterSelector: {}
EOF
```

Fleet clones the repo, builds a bundle, and applies it. The `web` Deployment appears with one replica:

```bash
kubectl -n fleet-local get gitrepo
kubectl get deploy web
```

## Commit a Change and Let Fleet Reconcile

Now change the app through Git, not through `kubectl`. Clone the repository, bump the replica count, commit, and push:

```bash
cd /tmp
git clone http://student:student@172.16.0.4:3000/student/sample-app.git
cd sample-app
sed -i 's/replicas: 1/replicas: 3/' manifests/web.yaml
git -c user.email=student@example.com -c user.name=student commit -am "Scale web to 3 replicas"
git push origin main
```

Then watch the cluster follow Git:

```bash
kubectl get deploy web -w
```

Within a minute Fleet polls Gitea, sees the new commit, and scales `web` to three replicas. You never ran `kubectl scale` - the commit drove the rollout, which is the whole point of GitOps-driven continuous delivery. To ship any future change, you would edit the manifest, commit, and push again; Fleet reconciles the cluster to match every time.

## Why the IP and Not the Hostname

The one thing that trips people up here is the repo URL. From the workstation you can reach the Git server as `gitea:3000`, but Fleet's clone job runs as a pod inside the cluster, and cluster pods resolve names through the cluster DNS, which knows nothing about the `gitea` VM. Using the node IP `172.16.0.4:3000` sidesteps DNS entirely and always works.
