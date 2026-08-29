---
kind: challenge

title: 'Create a Namespace Through the Rancher UI'

description: |
  Prove you can navigate Rancher's Cluster Explorer by creating a namespace called `rancher-explorer` in the local cluster - using the UI, not the command line.
  A quick, hands-on check that you found your way around the dashboard.

categories:
  - kubernetes
  - containers

tagz:
  - Rancher
  - UI
  - Namespaces

difficulty: easy

createdAt: 2026-08-27
updatedAt: 2026-08-27

playground:
  name: rancher-k3s-e09b66ec

tasks:
  verify_namespace_exists:
    machine: dev-machine
    user: laborant
    run: |
      export KUBECONFIG=$HOME/.kube/config
      rm -f /tmp/verify_ns_hint.txt

      if ! kubectl get namespace rancher-explorer >/dev/null 2>&1; then
        echo "No namespace named 'rancher-explorer' yet. Create it from the Rancher UI." | tee /tmp/verify_ns_hint.txt
        exit 1
      fi

      echo "Namespace 'rancher-explorer' exists"
    hintcheck: |
      if [ -f /tmp/verify_ns_hint.txt ]; then
        cat /tmp/verify_ns_hint.txt
        rm -f /tmp/verify_ns_hint.txt
      fi

  verify_created_via_ui:
    machine: dev-machine
    user: laborant
    needs:
      - verify_namespace_exists
    run: |
      export KUBECONFIG=$HOME/.kube/config
      rm -f /tmp/verify_ui_hint.txt

      # Rancher assigns every namespace created through its UI to a Project,
      # stamping a field.cattle.io/projectId annotation. A plain
      # `kubectl create namespace` never sets it - so its presence confirms the
      # student used the Rancher UI, as the lesson intends.
      PROJECT=$(kubectl get namespace rancher-explorer \
        -o jsonpath='{.metadata.annotations.field\.cattle\.io/projectId}' 2>/dev/null)
      if [ -z "${PROJECT}" ]; then
        echo "The namespace exists but is not assigned to a Rancher Project, which means it was not created through the Rancher UI. Delete it and create 'rancher-explorer' from the Rancher UI instead." | tee /tmp/verify_ui_hint.txt
        exit 1
      fi

      echo "Namespace 'rancher-explorer' was created through the Rancher UI (project: ${PROJECT})"
    hintcheck: |
      if [ -f /tmp/verify_ui_hint.txt ]; then
        cat /tmp/verify_ui_hint.txt
        rm -f /tmp/verify_ui_hint.txt
      fi
---

You have toured the Rancher dashboard - now put it to use. This short challenge asks you to do one thing entirely through the **Rancher UI**: create a namespace called `rancher-explorer` in the **local** cluster.

Doing it in the UI (rather than with `kubectl`) is the point - it proves you can find your way to the right place in the Cluster Explorer and drive Rancher, which is what the rest of the course builds on.

## Your Task

Open the Rancher UI (the **Rancher** tab), enter the **local** cluster, and create a namespace named exactly `rancher-explorer`.

::simple-task
---
:tasks: tasks
:name: verify_namespace_exists
---
#active
Waiting for a namespace called `rancher-explorer`...

#completed
The `rancher-explorer` namespace exists.
::

::simple-task
---
:tasks: tasks
:name: verify_created_via_ui
---
#active
Confirming it was created through the Rancher UI...

#completed
Created through the Rancher UI. You know your way around the dashboard.
::

::hint-box
---
:summary: Where do I create a namespace in the UI?
---

Enter the **local** cluster from the global navigation. In the Cluster Explorer, look under the **Cluster** section for **Projects/Namespaces** (Rancher groups namespaces there). Use the **Create Namespace** button, name it `rancher-explorer`, and create it.
::

::hint-box
---
:summary: "It says my namespace was not created through Rancher"
---

The check confirms the namespace is assigned to a Rancher **Project** - something Rancher does automatically when you create a namespace in its UI, but `kubectl create namespace` does not. If you created `rancher-explorer` with `kubectl` out of habit, delete it (`kubectl delete namespace rancher-explorer`) and create it again from the Rancher UI (it lands in **Project: Default**).
::
