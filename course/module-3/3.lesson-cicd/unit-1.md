---
kind: unit

title: Continuous Delivery with Fleet and a Git Server

name: continuous-delivery-with-fleet
---

In the previous lesson you saw Fleet deploy from a public example repository. That taught the mechanics, but it was read-only: you watched Fleet pull someone else's repo. This lesson closes the loop with a Git server you own. You point Fleet at a repository on a self-hosted Gitea server, then edit a manifest, commit, and push - and watch Fleet reconcile that change onto the cluster on its own. That is continuous delivery: the commit is the trigger, and the cluster follows Git.

This playground gives you three machines: your :tab{text='dev-machine' machine='dev-machine'} workstation, the Rancher cluster (open the :tab{text='Rancher' name='Rancher'} tab), and a :tab{text='gitea' machine='gitea'} machine running a self-hosted **Gitea** Git server (open its web UI with the :tab{text='Gitea' name='Gitea'} tab). Gitea already hosts a `sample-app` repository with a small nginx Deployment.

::image-box
---
:src: __static__/cicd-gitops-loop-v1.png
:alt: The continuous delivery loop - the student commits a manifest change to the self-hosted Gitea server, Fleet running in Rancher detects the new commit, pulls it, and reconciles the change onto the cluster
:max-width: 900px
---
_You commit to Gitea; Fleet pulls the change and reconciles it onto the cluster._
::

## Pull-Based CD, Not a Push Pipeline

It is worth being precise about what "CI/CD" means here, because two different models often share the name.

- **A push pipeline** (for example a Gitea Actions or GitHub Actions workflow) runs steps on a commit and pushes changes to the cluster, often ending in a `kubectl apply`.
- **Pull-based GitOps** (what Fleet does) is the reverse: the cluster watches Git and pulls changes into itself. Nothing external applies to the cluster; the in-cluster agent reconciles it.

This lesson uses the pull-based model, because that is what Rancher Fleet is and what Rancher recommends for delivery. The commit still "triggers" the rollout, but the trigger is Fleet noticing a new commit and reconciling, not a pipeline running `kubectl` against your cluster.

::details-box
---
:summary: Where do build pipelines fit, then?
---

Pull-based GitOps and build pipelines are complementary, not competing. In a full setup, a CI pipeline does the *integration* work: it builds and tests your container image, pushes it to a registry, and then updates the manifests in Git - for example, bumping the image tag. Fleet then does the *delivery*: it sees the new commit and rolls the change out to the clusters. The pipeline never touches the cluster directly; it just changes what is in Git, and Fleet takes it from there. In this lesson you play the part of the pipeline by editing and committing the manifest yourself, so you can see the delivery half clearly.

::

::details-box
---
:summary: Can I use GitHub Actions, GitLab CI, Jenkins, or CircleCI with Fleet?
---

Yes - all of them, and you are not locked into any Rancher-specific pipeline. Fleet does not integrate with a CI tool through a plugin or a direct connection; the two meet at **Git**. Whatever builds your code just needs to commit the resulting manifest change (usually a new image tag) to the repository Fleet watches. Because "write a commit to Git" is something every CI system can do, they all work the same way:

- **GitHub Actions** and **GitLab CI** are the most common pairings, since the pipeline and the Git repository live in the same product - the "commit the change back to Git" step is built in.
- **Jenkins** and **CircleCI** integrate identically; they just need credentials to push to the manifest repository (or to open a pull request that gets merged).
- The same holds for **Gitea Actions**, **Tekton**, **Argo Workflows**, or any other runner.

A common and healthy shape is two repositories: an *app-source* repo that CI builds from, and a *config* repo that Fleet watches. CI bridges them - it builds the image and then commits the updated manifest to the config repo. The rule to remember is that the CI tool's job ends at the Git commit, and Fleet's job begins there. No pipeline ever runs `kubectl` against the cluster.

::

## Why a Git Server You Own

Pointing Fleet at a public repository is fine for a demo, but real delivery runs against a Git server your organization controls. This playground models that faithfully: Gitea runs on its **own machine**, separate from the cluster, exactly as a real Git server would.

::details-box
---
:summary: Why not run Gitea inside the cluster?
---

It is tempting to run the Git server as a pod on the same cluster Fleet deploys to, but that creates a bootstrapping problem: if the cluster has a bad day, you lose the Git server that holds the source of truth you need to recover it. A Git server should be independent of the clusters it feeds. That is why Gitea here lives on its own machine, and the cluster reaches it over the network - the production-faithful shape.

::

## Step 1: Explore the Gitea Repository

Open the :tab{text='Gitea' name='Gitea'} tab and log in with username `student` and password `student`.

::image-box
---
:src: __static__/gitea-login-screen-v1.png
:alt: The Gitea sign-in page served from the self-hosted Gitea server, with fields for username and password
:max-width: 800px
---
_The self-hosted Gitea server's sign-in page - log in with `student` / `student`._
::

Open the `student/sample-app` repository and look at `manifests/web.yaml` - a plain nginx `Deployment` with `replicas: 1`. This is the file Fleet will deploy, and the file you will change.

::image-box
---
:src: __static__/gitea-sample-app-repo-v1.png
:alt: The student/sample-app repository in the Gitea web UI after logging in, showing the manifests directory and the web.yaml Deployment file that Fleet deploys
:max-width: 900px
---
_The `student/sample-app` repository in Gitea, holding `manifests/web.yaml` - the manifest Fleet watches._
::

::image-box
---
:src: __static__/gitea-web-yaml-content-v1.png
:alt: The contents of manifests/web.yaml viewed in Gitea, an nginx Deployment named web with replicas set to 1 - the value the student will change to trigger a Fleet reconcile
:max-width: 900px
---
_`manifests/web.yaml` in Gitea - an nginx Deployment at `replicas: 1`, the line you will change later._
::

## Step 2: Point Fleet at the Gitea Repository

::remark-box
---
kind: warning
---

**Give Fleet a couple of minutes first.** Rancher installs Fleet as a follow-on step, so after the playground finishes loading Fleet still needs two to three minutes to register its custom resources and settle. If you create a GitRepo too early you will see an error like `no matches for kind "GitRepo"` - that just means Fleet is not ready yet, not that anything is broken. Confirm it is ready before you continue:

```bash
kubectl -n fleet-local get clusters.fleet.cattle.io
```

Wait until the `local` cluster shows a `BUNDLES-READY` count (for example `1/1`) and a recent `LAST-SEEN`. Then proceed.

::

From the :tab{text='dev-machine' machine='dev-machine'} terminal, create a `GitRepo` in the `fleet-local` namespace that points at the Gitea repo. Use the server's **IP address**, not its hostname. The here-document pipes the manifest straight into `kubectl`, so there is no file to create:

```bash
kubectl apply -f - <<'EOF'
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

If you prefer working with a file, save the manifest between the `EOF` markers to `web-app-gitrepo.yaml` and run `kubectl apply -f web-app-gitrepo.yaml` instead - the result is identical.

::remark-box
---
kind: warning
---

Use the Gitea server's IP address `172.16.0.4:3000` in the GitRepo, not `gitea:3000`. Fleet clones the repository from a pod inside the cluster, and cluster pods resolve names through the cluster DNS, which does not know the `gitea` machine name. The IP always works.

::

Watch Fleet pick it up and deploy:

```bash
kubectl -n fleet-local get gitrepo
kubectl -n fleet-local get bundles
kubectl get deploy web
```

The GitRepo resolves a commit, a `web-app-manifests` bundle reaches `Ready`, and the `web` Deployment appears with one replica.

::simple-task
---
:tasks: tasks
:name: verify_gitrepo_to_gitea
---
#active
Waiting for a GitRepo pointing at the Gitea server...

#completed
Fleet is watching your Gitea repository.
::

## Step 3: Commit a Change and Watch Fleet Reconcile

Now the real loop. Still on the :tab{text='dev-machine' machine='dev-machine'} terminal - your workstation, which has `git` and can reach Gitea over the network - clone the repository, change the replica count, commit, and push, all against Gitea. You never log in to the Gitea machine or the cluster to do this; you work as a developer would, from your own workstation. Fleet will notice the new commit and scale the Deployment for you.

```bash
cd /tmp
git clone http://student:student@172.16.0.4:3000/student/sample-app.git
cd sample-app
sed -i 's/replicas: 1/replicas: 3/' manifests/web.yaml
git -c user.email=student@example.com -c user.name=student commit -am "Scale web to 3 replicas"
git push origin main
```

Then watch the cluster follow Git, without any `kubectl apply` of your own:

```bash
kubectl get deploy web -w
```

Within a minute or so, `web` scales to three replicas - because Fleet polled Gitea, saw your commit, and reconciled the change.

::simple-task
---
:tasks: tasks
:name: verify_reconciled_change
---
#active
Waiting for Fleet to reconcile your committed change...

#completed
Fleet scaled the Deployment from your commit. The GitOps CD loop works end to end.
::

::details-box
---
:summary: How fast does Fleet notice a commit?
---

Fleet polls the Git repository on an interval (about 15 seconds by default), so a pushed change is usually reconciled within a minute. In production you can shorten the interval, or configure a webhook so Gitea notifies Fleet the instant a commit lands, removing the polling delay entirely. Either way the model is the same: the commit is the trigger, and Fleet does the applying.

::

## You're Done

You ran the full continuous delivery loop against a Git server you control: Fleet watches your Gitea repository, and a commit you push is reconciled onto the cluster automatically. This is how teams ship changes to Rancher-managed clusters at scale - not by running `kubectl` against each cluster, but by committing to Git and letting Fleet deliver.

The challenge below has you drive this loop yourself: point Fleet at the Gitea repo, commit a change, and confirm Fleet reconciles it. Solving it records your progress.

::card
---
:challenge: challenges.rancher-cicd-pipeline-b05d22e8
---
::
