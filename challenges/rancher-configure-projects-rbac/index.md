---
kind: challenge

title: 'Isolate a Team with Quotas and RBAC'

description: |
  Carve out a namespace for a team, cap its resource consumption with a ResourceQuota, and grant a user scoped read-only access with a Role and RoleBinding.
  These are the native Kubernetes primitives Rancher Projects and roles build on.

categories:
  - kubernetes
  - containers

tagz:
  - Rancher
  - RBAC
  - Namespaces
  - resource-quotas

difficulty: medium

createdAt: 2026-08-27
updatedAt: 2026-08-27

playground:
  name: rancher-k3s-e09b66ec

tasks:
  init_baseline_no_access:
    init: true
    machine: dev-machine
    user: laborant
    run: |
      export KUBECONFIG=$HOME/.kube/config
      # Baseline for the negative check: with no RoleBinding in place, alice
      # must have no access. If this fails, the cluster is not a clean slate.
      CAN=$(kubectl auth can-i list pods --namespace default --as alice 2>/dev/null)
      if [ "${CAN}" = "yes" ]; then
        echo "User 'alice' already has access before the challenge starts"
        exit 1
      fi
      echo "Baseline confirmed: alice has no access yet"

  verify_namespace:
    machine: dev-machine
    user: laborant
    run: |
      export KUBECONFIG=$HOME/.kube/config
      if ! kubectl get namespace team-frontend >/dev/null 2>&1; then
        echo "Namespace 'team-frontend' does not exist yet"
        exit 1
      fi
      echo "Namespace 'team-frontend' exists"

  verify_quota:
    machine: dev-machine
    user: laborant
    needs:
      - verify_namespace
    run: |
      export KUBECONFIG=$HOME/.kube/config
      rm -f /tmp/verify_quota_hint.txt

      QUOTA=$(kubectl -n team-frontend get resourcequota -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
      if [ -z "${QUOTA}" ]; then
        echo "No ResourceQuota found in namespace 'team-frontend'" | tee /tmp/verify_quota_hint.txt
        exit 1
      fi

      PODS=$(kubectl -n team-frontend get resourcequota "${QUOTA}" -o jsonpath='{.spec.hard.pods}' 2>/dev/null)
      CPU=$(kubectl -n team-frontend get resourcequota "${QUOTA}" -o jsonpath='{.spec.hard.requests\.cpu}' 2>/dev/null)
      if [ -z "${PODS}" ] || [ -z "${CPU}" ]; then
        echo "ResourceQuota '${QUOTA}' must cap both pods and requests.cpu (found pods='${PODS}', requests.cpu='${CPU}')" | tee /tmp/verify_quota_hint.txt
        exit 1
      fi

      echo "ResourceQuota '${QUOTA}' caps pods and CPU requests in team-frontend"
    hintcheck: |
      if [ -f /tmp/verify_quota_hint.txt ]; then
        cat /tmp/verify_quota_hint.txt
        rm -f /tmp/verify_quota_hint.txt
      fi

  verify_role:
    machine: dev-machine
    user: laborant
    needs:
      - verify_namespace
    run: |
      export KUBECONFIG=$HOME/.kube/config
      rm -f /tmp/verify_role_hint.txt

      ROLE=$(kubectl -n team-frontend get role -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
      if [ -z "${ROLE}" ]; then
        echo "No Role found in namespace 'team-frontend'" | tee /tmp/verify_role_hint.txt
        exit 1
      fi

      # The role must grant read verbs (get/list) on pods, and must NOT grant write verbs.
      READ_OK=$(kubectl -n team-frontend get role "${ROLE}" -o json 2>/dev/null \
        | grep -E '"(get|list)"' | wc -l)
      if [ "${READ_OK}" -eq 0 ]; then
        echo "Role '${ROLE}' does not grant any read verbs (get/list)" | tee /tmp/verify_role_hint.txt
        exit 1
      fi

      WRITE_BAD=$(kubectl -n team-frontend get role "${ROLE}" -o json 2>/dev/null \
        | grep -E '"(create|update|patch|delete|\*)"' | wc -l)
      if [ "${WRITE_BAD}" -gt 0 ]; then
        echo "Role '${ROLE}' grants write verbs - it should be read-only (get/list/watch)" | tee /tmp/verify_role_hint.txt
        exit 1
      fi

      echo "Role '${ROLE}' grants read-only access in team-frontend"
    hintcheck: |
      if [ -f /tmp/verify_role_hint.txt ]; then
        cat /tmp/verify_role_hint.txt
        rm -f /tmp/verify_role_hint.txt
      fi

  verify_can_read:
    machine: dev-machine
    user: laborant
    needs:
      - verify_role
    run: |
      export KUBECONFIG=$HOME/.kube/config
      rm -f /tmp/verify_can_read_hint.txt

      if ! kubectl -n team-frontend get rolebinding -o jsonpath='{.items[0].metadata.name}' >/dev/null 2>&1; then
        echo "No RoleBinding found in namespace 'team-frontend'" | tee /tmp/verify_can_read_hint.txt
        exit 1
      fi

      CAN=$(kubectl auth can-i list pods --namespace team-frontend --as alice 2>/dev/null)
      if [ "${CAN}" != "yes" ]; then
        echo "User 'alice' cannot list pods in team-frontend - is the RoleBinding bound to user 'alice'?" | tee /tmp/verify_can_read_hint.txt
        exit 1
      fi

      echo "User 'alice' can list pods in team-frontend"
    hintcheck: |
      if [ -f /tmp/verify_can_read_hint.txt ]; then
        cat /tmp/verify_can_read_hint.txt
        rm -f /tmp/verify_can_read_hint.txt
      fi

  verify_cannot_write:
    machine: dev-machine
    user: laborant
    needs:
      - verify_can_read
    run: |
      export KUBECONFIG=$HOME/.kube/config
      rm -f /tmp/verify_cannot_write_hint.txt

      CAN_DELETE=$(kubectl auth can-i delete pods --namespace team-frontend --as alice 2>/dev/null)
      if [ "${CAN_DELETE}" = "yes" ]; then
        echo "User 'alice' can delete pods in team-frontend - the access should be read-only" | tee /tmp/verify_cannot_write_hint.txt
        exit 1
      fi

      CAN_CREATE=$(kubectl auth can-i create deployments --namespace team-frontend --as alice 2>/dev/null)
      if [ "${CAN_CREATE}" = "yes" ]; then
        echo "User 'alice' can create deployments in team-frontend - the access should be read-only" | tee /tmp/verify_cannot_write_hint.txt
        exit 1
      fi

      echo "User 'alice' has read-only access - writes are correctly denied"
    hintcheck: |
      if [ -f /tmp/verify_cannot_write_hint.txt ]; then
        cat /tmp/verify_cannot_write_hint.txt
        rm -f /tmp/verify_cannot_write_hint.txt
      fi
---

Rancher Projects and its built-in roles are convenience layers over primitives that already exist in Kubernetes: namespaces, resource quotas, and RBAC. Understanding those primitives is what lets you reason about who can do what once Rancher is in the picture. In this challenge you will set up isolation for a single team by hand.

Work from the **dev-machine** terminal (its `kubectl` is already pointed at the cluster). You will create a namespace for a frontend team, cap its resource usage, and give a user named `alice` read-only access to it - and only it.

## Step 1: Create the Team Namespace

Create a namespace called `team-frontend`.

::simple-task
---
:tasks: tasks
:name: verify_namespace
---
#active
Waiting for the `team-frontend` namespace...

#completed
The `team-frontend` namespace exists.
::

## Step 2: Cap Resource Consumption

Add a ResourceQuota to `team-frontend` that limits at least the number of pods and the total CPU requests. This stops one team from exhausting the cluster.

::simple-task
---
:tasks: tasks
:name: verify_quota
---
#active
Waiting for a ResourceQuota that caps pods and CPU...

#completed
The namespace has a ResourceQuota capping pods and CPU.
::

::hint-box
---
:summary: Hint 1
---
A `ResourceQuota` object with a `spec.hard` map does the job. Include both a `pods` count and a `requests.cpu` value. The tutorial for this lesson shows the field layout.
::

## Step 3: Define a Read-Only Role

Create a Role in `team-frontend` that grants only read verbs (`get`, `list`, `watch`) on workload resources. It must not grant any write verbs.

::simple-task
---
:tasks: tasks
:name: verify_role
---
#active
Waiting for a read-only Role in team-frontend...

#completed
A read-only Role exists in team-frontend.
::

::hint-box
---
:summary: Hint 2
---
Keep the `verbs` list restricted to `get`, `list`, and `watch`. Any of `create`, `update`, `patch`, `delete`, or the `*` wildcard will make the role fail the read-only check.
::

## Step 4: Bind the Role to alice

Create a RoleBinding that binds your read-only Role to the user `alice`. Then confirm that alice can read but cannot write.

::simple-task
---
:tasks: tasks
:name: verify_can_read
---
#active
Waiting for alice to gain read access...

#completed
alice can list pods in team-frontend.
::

::simple-task
---
:tasks: tasks
:name: verify_cannot_write
---
#active
Confirming alice cannot modify resources...

#completed
alice has read-only access - writes are denied. Well done.
::

::hint-box
---
:summary: Hint 3
---
The RoleBinding `subjects` entry should be `kind: User` with `name: alice`, and its `roleRef` should point at the Role you created. You can check the result yourself with `kubectl auth can-i ... --as alice`.
::
