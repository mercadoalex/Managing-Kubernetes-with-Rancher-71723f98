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
  name: ubuntu-k3s-bare

tasks:
  init_wait_k3s:
    init: true
    run: |
      for i in $(seq 1 30); do
        if kubectl get nodes | grep -q " Ready"; then
          exit 0
        fi
        sleep 2
      done
      echo "K3s did not become ready in time"
      exit 1

  init_install_ingress:
    init: true
    needs:
      - init_wait_k3s
    run: |
      if kubectl get namespace ingress-nginx >/dev/null 2>&1; then
        exit 0
      fi
      helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
      helm repo update >/dev/null 2>&1
      helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.type=NodePort \
        --set controller.watchIngressWithoutClass=true
      kubectl -n ingress-nginx rollout status deployment/ingress-nginx-controller --timeout=180s

  verify_namespace:
    run: |
      if ! kubectl get namespace demo >/dev/null 2>&1; then
        echo "Namespace 'demo' does not exist yet"
        exit 1
      fi
      echo "Namespace 'demo' exists"

  verify_deployment_scaled:
    needs:
      - verify_namespace
    run: |
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
    needs:
      - verify_deployment_scaled
    run: |
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
    needs:
      - verify_service
    run: |
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
    needs:
      - verify_ingress
    run: |
      HOSTNAME=$(kubectl -n demo get ingress -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null)
      if [ -z "${HOSTNAME}" ]; then
        echo "Could not determine the ingress host"
        exit 1
      fi

      for i in $(seq 1 15); do
        CODE=$(curl -s -o /dev/null -w '%{http_code}' -H "Host: ${HOSTNAME}" http://127.0.0.1 2>/dev/null || true)
        if [ "${CODE}" = "200" ]; then
          echo "Ingress serves HTTP 200 for host ${HOSTNAME}"
          exit 0
        fi
        sleep 2
      done
      echo "Ingress did not return HTTP 200 for host ${HOSTNAME} (last code: ${CODE})"
      exit 1
---

Rancher gives you a visual, form-driven way to run applications on a cluster, but every workload it creates is still plain Kubernetes underneath. In this challenge you will build the full path an application takes from a container image to reachable HTTP traffic: a Deployment, a Service, and an Ingress.

The playground is a single-node K3s cluster. An NGINX ingress controller is already installed for you, so you can focus on the workload itself rather than on cluster setup.

Your goal is to run an NGINX application in a `demo` namespace, scale it out, expose it, and route external traffic to it.

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

Create an Ingress in the `demo` namespace that routes a host of your choice to the `nginx` service on port 80. The ingress controller is already installed and watches ingresses in all namespaces.

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
The ingress `spec.rules[].http.paths[].backend.service.name` must point at the `nginx` service, and `spec.rules[].host` must be set. Set `ingressClassName: nginx` so the installed controller picks it up.
::

::hint-box
---
:summary: "Hint: testing reachability"
---
The controller is reachable on the node itself. You can simulate a browser request with `curl` by sending the right `Host` header to `127.0.0.1`, without configuring DNS.
::
