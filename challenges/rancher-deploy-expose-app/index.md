---
kind: challenge

title: 'Deploy and Expose an Application on Kubernetes'

description: |
  Deploy an NGINX application to a Kubernetes cluster, scale it, expose it with a Service, and route external traffic to it with an Ingress.
  This is the core workload workflow you will drive through Rancher in day-to-day operations.

categories:
  - kubernetes
  - containers

tagz:
  - Rancher
  - Deployments
  - Services
  - Ingress
  - Workloads

difficulty: easy

createdAt: 2026-08-27
updatedAt: 2026-08-27

playground:
  name: rancher-k3s-e09b66ec

tasks:
  verify_namespace:
    machine: dev-machine
    user: laborant
    run: |
      export KUBECONFIG=$HOME/.kube/config
      if ! kubectl get namespace demo >/dev/null 2>&1; then
        echo "Namespace 'demo' does not exist yet"
        exit 1
      fi
      echo "Namespace 'demo' exists"

  verify_deployment_scaled:
    machine: dev-machine
    user: laborant
    needs:
      - verify_namespace
    run: |
      export KUBECONFIG=$HOME/.kube/config
      rm -f /tmp/verify_deployment_hint.txt

      if ! kubectl -n demo get deployment nginx >/dev/null 2>&1; then
        echo "No deployment named 'nginx' in namespace 'demo'" | tee /tmp/verify_deployment_hint.txt
        exit 1
      fi

      IMAGE=$(kubectl -n demo get deployment nginx -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
      case "${IMAGE}" in
        nginx|nginx:*) : ;;
        *)
          echo "Deployment 'nginx' is not running an nginx image (found: ${IMAGE})" | tee /tmp/verify_deployment_hint.txt
          exit 1
          ;;
      esac

      READY=$(kubectl -n demo get deployment nginx -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
      READY=${READY:-0}
      if [ "${READY}" -lt 3 ]; then
        echo "Deployment 'nginx' has ${READY} ready replica(s); at least 3 are required" | tee /tmp/verify_deployment_hint.txt
        exit 1
      fi

      echo "Deployment 'nginx' is running with ${READY} ready replicas"
    hintcheck: |
      if [ -f /tmp/verify_deployment_hint.txt ]; then
        cat /tmp/verify_deployment_hint.txt
        rm -f /tmp/verify_deployment_hint.txt
      fi

  verify_service:
    machine: dev-machine
    user: laborant
    needs:
      - verify_deployment_scaled
    run: |
      export KUBECONFIG=$HOME/.kube/config
      rm -f /tmp/verify_service_hint.txt

      if ! kubectl -n demo get svc nginx >/dev/null 2>&1; then
        echo "No service named 'nginx' in namespace 'demo'" | tee /tmp/verify_service_hint.txt
        exit 1
      fi

      PORT=$(kubectl -n demo get svc nginx -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
      if [ "${PORT}" != "80" ]; then
        echo "Service 'nginx' does not expose port 80 (found: ${PORT})" | tee /tmp/verify_service_hint.txt
        exit 1
      fi

      ENDPOINTS=$(kubectl -n demo get endpoints nginx -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null)
      if [ -z "${ENDPOINTS}" ]; then
        echo "Service 'nginx' has no backing endpoints - check the selector matches the deployment pods" | tee /tmp/verify_service_hint.txt
        exit 1
      fi

      echo "Service 'nginx' exposes port 80 and has active endpoints"
    hintcheck: |
      if [ -f /tmp/verify_service_hint.txt ]; then
        cat /tmp/verify_service_hint.txt
        rm -f /tmp/verify_service_hint.txt
      fi

  verify_ingress:
    machine: dev-machine
    user: laborant
    needs:
      - verify_service
    run: |
      export KUBECONFIG=$HOME/.kube/config
      rm -f /tmp/verify_ingress_hint.txt

      ING=$(kubectl -n demo get ingress -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
      if [ -z "${ING}" ]; then
        echo "No ingress resource found in namespace 'demo'" | tee /tmp/verify_ingress_hint.txt
        exit 1
      fi

      HOST=$(kubectl -n demo get ingress "${ING}" -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
      if [ -z "${HOST}" ]; then
        echo "Ingress '${ING}' has no host rule configured" | tee /tmp/verify_ingress_hint.txt
        exit 1
      fi

      BACKEND=$(kubectl -n demo get ingress "${ING}" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null)
      if [ "${BACKEND}" != "nginx" ]; then
        echo "Ingress '${ING}' does not route to the 'nginx' service (found backend: ${BACKEND})" | tee /tmp/verify_ingress_hint.txt
        exit 1
      fi

      echo "Ingress '${ING}' routes host '${HOST}' to the nginx service"
    hintcheck: |
      if [ -f /tmp/verify_ingress_hint.txt ]; then
        cat /tmp/verify_ingress_hint.txt
        rm -f /tmp/verify_ingress_hint.txt
      fi

  verify_http_reachable:
    machine: dev-machine
    user: laborant
    needs:
      - verify_ingress
    run: |
      export KUBECONFIG=$HOME/.kube/config
      HOSTNAME=$(kubectl -n demo get ingress -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null)
      if [ -z "${HOSTNAME}" ]; then
        echo "Could not determine the ingress host"
        exit 1
      fi

      # Traefik (the k3s ingress controller) serves on the control-plane node's
      # port 80. From the workstation we reach it at the control-plane IP,
      # sending the Host header the ingress rule matches on.
      for i in $(seq 1 20); do
        CODE=$(curl -s -o /dev/null -w '%{http_code}' -H "Host: ${HOSTNAME}" http://172.16.0.2 2>/dev/null || true)
        if [ "${CODE}" = "200" ]; then
          echo "Ingress serves HTTP 200 for host ${HOSTNAME}"
          exit 0
        fi
        sleep 3
      done
      echo "Ingress did not return HTTP 200 for host ${HOSTNAME} (last code: ${CODE})"
      exit 1
---

Rancher gives you a visual, form-driven way to run applications on a cluster, but every workload it creates is still plain Kubernetes underneath. In this challenge you will build the full path an application takes from a container image to reachable HTTP traffic: a Deployment, a Service, and an Ingress.

The playground is a multi-node K3s cluster with Rancher already installed. K3s ships the **Traefik** ingress controller out of the box, so you can focus on the workload itself rather than on cluster setup. Work from the **dev-machine** terminal (its `kubectl` is already pointed at the cluster) - or use the Rancher UI; both reach the same cluster.

Your goal is to run an NGINX application in a `demo` namespace, scale it out, expose it, and route external traffic to it through Traefik.

## Step 1: Create the Namespace

Applications in this challenge live in a namespace called `demo`.

::simple-task
---
:tasks: tasks
:name: verify_namespace
---
#active
Waiting for the `demo` namespace...

#completed
The `demo` namespace exists.
::

## Step 2: Deploy and Scale NGINX

Create a Deployment named `nginx` in the `demo` namespace that runs an `nginx` image, and scale it to at least 3 replicas.

::simple-task
---
:tasks: tasks
:name: verify_deployment_scaled
---
#active
Waiting for a scaled `nginx` deployment...

#completed
The `nginx` deployment is running with at least 3 replicas.
::

::hint-box
---
:summary: Hint 1
---
You can create a deployment imperatively with `kubectl create deployment`, then adjust the replica count with `kubectl scale`. The image name should start with `nginx`.
::

## Step 3: Expose the Deployment

Create a Service named `nginx` in the `demo` namespace that serves port 80 and selects the deployment's pods.

::simple-task
---
:tasks: tasks
:name: verify_service
---
#active
Waiting for the `nginx` service on port 80...

#completed
The `nginx` service is exposing the deployment on port 80.
::

::hint-box
---
:summary: Hint 2
---
`kubectl expose deployment` generates a service whose selector already matches the deployment's pods. Make sure the service port is 80. If the service has no endpoints, the selector does not match any running pods.
::

## Step 4: Route Traffic with an Ingress

Create an Ingress in the `demo` namespace that routes a host of your choice to the `nginx` service on port 80, using the **Traefik** ingress class that ships with K3s.

::simple-task
---
:tasks: tasks
:name: verify_ingress
---
#active
Waiting for an ingress routing to the nginx service...

#completed
The ingress is routing a host to the nginx service.
::

::simple-task
---
:tasks: tasks
:name: verify_http_reachable
---
#active
Waiting for the ingress to serve HTTP 200...

#completed
Traffic reaches nginx through the ingress. Well done.
::

::hint-box
---
:summary: Hint 3
---
The ingress `spec.rules[].http.paths[].backend.service.name` must point at the `nginx` service, and `spec.rules[].host` must be set. Set `ingressClassName: traefik` so K3s's built-in controller picks it up.
::

::hint-box
---
:summary: "Hint: testing reachability"
---
Traefik runs on the control-plane node and serves on its port 80. From the dev-machine you can simulate a browser request with `curl` by sending the right `Host` header to the control-plane's address (`172.16.0.2`), without configuring DNS.
::
