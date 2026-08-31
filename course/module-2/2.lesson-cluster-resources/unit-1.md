---
kind: unit

title: Projects, Namespaces, and RBAC

name: projects-namespaces-rbac
---

When more than one team shares a cluster, you need ways to organize resources, cap what each team can consume, and control who can do what. Kubernetes gives you **namespaces** and **RBAC** for this. Rancher adds one more layer on top - **Projects** - that makes managing groups of namespaces far easier. This lesson is where the "what's a Project?" question from the last lesson gets its full answer.

Open the :tab{text='Rancher' name='Rancher'} tab for the UI, and use the :tab{text='dev-machine' machine='dev-machine'} terminal for `kubectl`.

::image-box
---
:src: __static__/rancher-projects-namespaces-v1.png
:alt: The Rancher Projects/Namespaces page for the local cluster, showing namespaces grouped under their projects such as Default and System
:max-width: 900px
---
_Rancher's Projects/Namespaces page groups namespaces under the projects that own them._
::

## Namespaces, Projects, and How They Relate

Three concepts, from the bottom up:

- **Namespace** - the native Kubernetes unit of isolation. It scopes resource names and is the boundary most RBAC rules apply to.
- **Project** - a **Rancher-only** grouping over one or more namespaces. Kubernetes has no idea projects exist; they are stored as Rancher custom resources. A Project lets you apply RBAC and resource quotas to *all* its namespaces at once.
- **RBAC** - the rules that say which users and groups may perform which actions, and where.

The payoff: instead of repeating the same RBAC and quota setup for every namespace a team owns, you attach it once to their Project, and every namespace in the Project inherits it.

::details-box
---
:summary: Where do Projects actually live?
---

A Rancher Project is a custom resource in the local (management) cluster. You can see them directly:

```bash
kubectl -n local get projects.management.cattle.io
```

Each has a generated name like `p-xxxxx` and a human-friendly `spec.displayName` (such as "Default" or "System"). When a namespace joins a Project, Rancher stamps it with a `field.cattle.io/projectId` label and annotation pointing at that `p-xxxxx` id - which is exactly the marker the previous lesson's challenge checked for.

::

## Step 1: Create a Project

In the Rancher UI, enter the **local** cluster, then go to **Cluster > Projects/Namespaces** and click **Create Project**. Name it `team-alpha` and create it.

::image-box
---
:src: __static__/rancher-create-project-v1.png
:alt: The Rancher Create Project form with the project name set to team-alpha, ready to create a new project in the local cluster
:max-width: 900px
---
_The Rancher Create Project form - naming the new project team-alpha._
::

Confirm it exists from the workstation:

```bash
kubectl -n local get projects.management.cattle.io -o custom-columns=NAME:.metadata.name,DISPLAY:.spec.displayName
```

You will see `team-alpha` in the list alongside the built-in `Default` and `System` projects.

::image-box
---
:src: __static__/projects-list-output-v1.png
:alt: Terminal output of kubectl listing management.cattle.io projects, showing the team-alpha project alongside the built-in Default and System projects with their generated p-xxxxx names
:max-width: 800px
---
_The `kubectl` project list shows `team-alpha` next to the built-in `Default` and `System` projects._
::

::simple-task
---
:tasks: tasks
:name: verify_project
---
#active
Waiting for a Rancher Project named `team-alpha`...

#completed
The `team-alpha` project exists.
::

## Step 2: Create a Namespace Inside the Project

Still on the **Projects/Namespaces** page, find the **team-alpha** group and click its **Create Namespace** button. Name the namespace `alpha-web`.

Because you created it under `team-alpha`, Rancher assigns it to that Project. Verify the link from the terminal:

```bash
kubectl get namespace alpha-web -o jsonpath='{.metadata.labels.field\.cattle\.io/projectId}'; echo
```

The value printed is the `p-xxxxx` id of the `team-alpha` project - the namespace now belongs to it.

::simple-task
---
:tasks: tasks
:name: verify_namespace_in_project
---
#active
Waiting for the `alpha-web` namespace in the `team-alpha` project...

#completed
`alpha-web` belongs to the `team-alpha` project.
::

## Step 3: Cap Resources with a Quota

Without limits, one team can starve the cluster. A **ResourceQuota** caps how much a namespace may consume. Apply one to `alpha-web` from the terminal:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: alpha-web-quota
  namespace: alpha-web
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 2Gi
    limits.cpu: "4"
    limits.memory: 4Gi
    pods: "20"
EOF
```

Check it:

```bash
kubectl -n alpha-web describe resourcequota alpha-web-quota
```

::image-box
---
:src: __static__/resourcequota-describe-v1.png
:alt: Terminal output of kubectl describe resourcequota for alpha-web-quota, listing each resource with its used and hard limits for CPU requests and limits, memory requests and limits, and pods
:max-width: 800px
---
_`kubectl describe` on the quota shows each capped resource with its used and hard limits._
::

::simple-task
---
:tasks: tasks
:name: verify_quota
---
#active
Waiting for a ResourceQuota on `alpha-web`...

#completed
The `alpha-web` namespace has a resource quota. Well done.
::

::details-box
---
:summary: Project quotas vs. namespace quotas
---

Rancher can also set a **project-level** quota in the UI (**Edit** the project, then the Resource Quotas tab). A project quota defines a total budget for the Project and a default slice each namespace gets, and Rancher creates the underlying Kubernetes `ResourceQuota` objects in each namespace for you.

In this lesson you applied the `ResourceQuota` directly to the namespace with `kubectl` to see the raw Kubernetes object. Both approaches end in the same place - a `ResourceQuota` in the namespace - which is the recurring theme: Rancher's higher-level controls are conveniences over standard Kubernetes objects.

::

## Rancher RBAC: Roles That Understand Projects

Kubernetes RBAC has four building blocks: **Role** and **RoleBinding** (namespace-scoped), and **ClusterRole** and **ClusterRoleBinding** (cluster-wide). They control who can do what, and where.

Rancher layers friendlier, ready-made roles on top - and crucially, some of them are **Project-scoped**, which plain Kubernetes cannot express on its own:

- **Cluster Owner / Cluster Member** - control at the whole-cluster level.
- **Project Owner** - full control over everything in a Project's namespaces.
- **Project Member** - manage workloads within a Project.
- **Read Only** - view without changing.

Assigning a user "Project Member" on `team-alpha` grants them the right permissions across *every* namespace in that project at once - Rancher translates that into the underlying Kubernetes RoleBindings for you. You manage these under **Cluster > Projects/Namespaces** (per project) or **Users & Authentication** (globally).

::details-box
---
:summary: What Rancher generates under the hood
---

When you give a user a Project role in the Rancher UI, Rancher creates standard Kubernetes `RoleBinding` objects in each of the Project's namespaces, bound to Rancher-managed roles. You can confirm this with `kubectl`:

```bash
kubectl -n alpha-web get rolebindings
```

So even Rancher's Project-scoped RBAC ultimately resolves to the same `Role`/`RoleBinding` objects you would write by hand - Rancher just keeps them in sync across the Project's namespaces as it grows.

::

## You're Done

You created a Rancher Project, put a namespace inside it, capped that namespace with a resource quota, and saw how Rancher's Project-scoped roles map down to ordinary Kubernetes RBAC. That is the toolkit for running a cluster shared by multiple teams.

The challenge below asks you to build this isolation yourself from the ground up - namespace, quota, and a scoped read-only role - so you understand the primitives Rancher's Projects sit on top of.

::card
---
:challenge: challenges.rancher-configure-projects-rbac-37074855
---
::
