---
kind: lesson

title: Managing Cluster Resources
description: |
  Organize and control access to cluster resources with Rancher projects, namespaces, RBAC, and resource quotas.

name: managing-cluster-resources
slug: managing-cluster-resources

createdAt: 2026-08-27
updatedAt: 2026-08-27

categories:
- kubernetes

tagz:
- rancher
- rbac
- projects

# cover: __static__/cover.png

playground:
  name: rancher-k3s-e09b66ec

challenges:
  rancher-configure-projects-rbac-37074855: {}

tasks:
  # Tasks run on the dev-machine workstation as laborant, using the
  # pre-provisioned kubeconfig at ~/.kube/config.
  verify_project:
    machine: dev-machine
    user: laborant
    run: |
      export KUBECONFIG=$HOME/.kube/config
      PID=$(kubectl -n local get projects.management.cattle.io \
        -o jsonpath='{.items[?(@.spec.displayName=="team-alpha")].metadata.name}' 2>/dev/null)
      if [ -z "${PID}" ]; then
        echo "No Rancher Project named 'team-alpha' yet - create it in the UI"
        exit 1
      fi
      echo "Project 'team-alpha' exists (${PID})"

  verify_namespace_in_project:
    machine: dev-machine
    user: laborant
    needs:
      - verify_project
    run: |
      export KUBECONFIG=$HOME/.kube/config
      PID=$(kubectl -n local get projects.management.cattle.io \
        -o jsonpath='{.items[?(@.spec.displayName=="team-alpha")].metadata.name}' 2>/dev/null)
      NS_PID=$(kubectl get namespace alpha-web \
        -o jsonpath='{.metadata.labels.field\.cattle\.io/projectId}' 2>/dev/null)
      if [ -z "${NS_PID}" ]; then
        echo "Namespace 'alpha-web' does not exist or is not in a project yet"
        exit 1
      fi
      if [ "${NS_PID}" != "${PID}" ]; then
        echo "Namespace 'alpha-web' is not in the 'team-alpha' project (found project: ${NS_PID})"
        exit 1
      fi
      echo "Namespace 'alpha-web' belongs to project 'team-alpha'"

  verify_quota:
    machine: dev-machine
    user: laborant
    needs:
      - verify_namespace_in_project
    run: |
      export KUBECONFIG=$HOME/.kube/config
      Q=$(kubectl -n alpha-web get resourcequota -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
      if [ -z "${Q}" ]; then
        echo "No ResourceQuota in namespace 'alpha-web' yet"
        exit 1
      fi
      echo "ResourceQuota '${Q}' is set on 'alpha-web' - lesson complete"
---
