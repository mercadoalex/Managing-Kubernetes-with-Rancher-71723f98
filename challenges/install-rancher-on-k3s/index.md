---
kind: challenge

title: 'Install Rancher on a K3s Cluster'

description: |
  Deploy Rancher on a single-node K3s cluster using Helm.
  You will install cert-manager, an NGINX ingress controller, and the Rancher management server - the standard production installation flow.

categories:
  - kubernetes
  - containers

tagz:
  - Rancher
  - K3s
  - Helm
  - cert-manager

difficulty: medium

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

  verify_cert_manager:
    run: |
      NS=$(kubectl get namespace cert-manager -o jsonpath='{.metadata.name}' 2>/dev/null)
      if [ "${NS}" != "cert-manager" ]; then
        echo "Namespace cert-manager does not exist"
        exit 1
      fi

      READY=$(kubectl get pods -n cert-manager -l app=cert-manager -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
      if [ "${READY}" != "True" ]; then
        echo "cert-manager pod is not ready"
        exit 1
      fi

      echo "cert-manager is installed and running"
    hintcheck: |
      NS=$(kubectl get namespace cert-manager -o jsonpath='{.metadata.name}' 2>/dev/null)
      if [ -z "${NS}" ]; then
        echo "The cert-manager namespace does not exist yet. Have you installed cert-manager?"
        exit 0
      fi

      PODS=$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | wc -l)
      if [ "${PODS}" -eq 0 ]; then
        echo "No pods found in the cert-manager namespace. The installation may still be in progress."
        exit 0
      fi

      NOT_READY=$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | grep -v "Running" | wc -l)
      if [ "${NOT_READY}" -gt 0 ]; then
        echo "Some cert-manager pods are not in Running state yet. Give them a moment to start."
        exit 0
      fi

  verify_ingress_controller:
    run: |
      NS=$(kubectl get namespace ingress-nginx -o jsonpath='{.metadata.name}' 2>/dev/null)
      if [ "${NS}" != "ingress-nginx" ]; then
        echo "Namespace ingress-nginx does not exist"
        exit 1
      fi

      READY=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
      if [ "${READY}" != "True" ]; then
        echo "NGINX ingress controller pod is not ready"
        exit 1
      fi

      echo "NGINX ingress controller is installed and running"
    hintcheck: |
      NS=$(kubectl get namespace ingress-nginx -o jsonpath='{.metadata.name}' 2>/dev/null)
      if [ -z "${NS}" ]; then
        echo "The ingress-nginx namespace does not exist. Have you installed the NGINX ingress controller?"
        exit 0
      fi

      PODS=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller --no-headers 2>/dev/null | wc -l)
      if [ "${PODS}" -eq 0 ]; then
        echo "No controller pod found in ingress-nginx namespace. Check if the Helm install completed."
        exit 0
      fi

  verify_rancher_namespace:
    run: |
      NS=$(kubectl get namespace cattle-system -o jsonpath='{.metadata.name}' 2>/dev/null)
      if [ "${NS}" != "cattle-system" ]; then
        echo "Namespace cattle-system does not exist"
        exit 1
      fi
      echo "cattle-system namespace exists"

  verify_rancher_running:
    needs:
      - verify_rancher_namespace
      - verify_cert_manager
      - verify_ingress_controller
    run: |
      REPLICAS=$(kubectl get deployment rancher -n cattle-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
      if [ -z "${REPLICAS}" ] || [ "${REPLICAS}" -lt 1 ]; then
        echo "Rancher deployment does not have ready replicas"
        exit 1
      fi

      echo "Rancher is running with ${REPLICAS} ready replica(s)"
    hintcheck: |
      DEP=$(kubectl get deployment rancher -n cattle-system --no-headers 2>/dev/null)
      if [ -z "${DEP}" ]; then
        echo "No Rancher deployment found in cattle-system. Have you run the helm install command?"
        exit 0
      fi

      UNAVAILABLE=$(kubectl get deployment rancher -n cattle-system -o jsonpath='{.status.unavailableReplicas}' 2>/dev/null)
      if [ -n "${UNAVAILABLE}" ] && [ "${UNAVAILABLE}" -gt 0 ]; then
        echo "Rancher pods are starting but not all replicas are available yet. This can take a minute or two."
        exit 0
      fi

  verify_rancher_ingress:
    needs:
      - verify_rancher_running
    run: |
      INGRESS=$(kubectl get ingress -n cattle-system -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
      if [ -z "${INGRESS}" ]; then
        echo "No ingress resource found in cattle-system"
        exit 1
      fi

      HOST=$(kubectl get ingress -n cattle-system -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null)
      if [ -z "${HOST}" ]; then
        echo "Ingress has no host configured"
        exit 1
      fi

      echo "Rancher ingress is configured for host: ${HOST}"
---

Rancher is a Kubernetes management platform that simplifies cluster operations at scale. In this challenge, you will perform the standard Rancher installation on a K3s cluster - the same process used in production environments.

The K3s cluster in this playground comes without an ingress controller or TLS certificate management. That is intentional - Rancher requires both, and installing them is part of the standard deployment workflow.

Your goal is to get Rancher fully running and accessible through an ingress endpoint.

## Step 1: Install cert-manager

Rancher uses cert-manager to issue and manage TLS certificates. Install it before anything else.

::simple-task
---
:tasks: tasks
:name: verify_cert_manager
---
#active
Waiting for cert-manager to be installed and running...

#completed
cert-manager is up and running.
::

::hint-box
---
:summary: Hint 1
---
cert-manager is installed via Helm. You need to add the Jetstack Helm repository and install the chart into the `cert-manager` namespace. Check the cert-manager documentation for the exact commands.
::

::hint-box
---
:summary: "Hint: CRDs"
---
cert-manager requires its Custom Resource Definitions to be installed. The Helm chart can handle this with the `--set crds.installCRDs=true` flag.
::

## Step 2: Install the NGINX Ingress Controller

Rancher needs an ingress controller to route external traffic to its pods. The NGINX ingress controller is the recommended choice for this setup.

::simple-task
---
:tasks: tasks
:name: verify_ingress_controller
---
#active
Waiting for the NGINX ingress controller to be installed and running...

#completed
NGINX ingress controller is ready.
::

::hint-box
---
:summary: Hint 3
---
The ingress-nginx project has its own Helm repository. Install the chart into the `ingress-nginx` namespace.
::

## Step 3: Install Rancher

With the prerequisites in place, install Rancher itself using the official Helm chart. Rancher is deployed into the `cattle-system` namespace.

::simple-task
---
:tasks: tasks
:name: verify_rancher_namespace
---
#active
Waiting for the cattle-system namespace...

#completed
The cattle-system namespace exists.
::

::simple-task
---
:tasks: tasks
:name: verify_rancher_running
---
#active
Waiting for Rancher to be running...

#completed
Rancher is deployed and running.
::

::hint-box
---
:summary: Hint 4
---
You need to add the Rancher Helm repository (either `rancher-stable` or `rancher-latest`), create the `cattle-system` namespace, and then install the chart. The `--set hostname=` flag is required.
::

::hint-box
---
:summary: "Hint: Bootstrap password"
---
Rancher requires a `bootstrapPassword` to be set during installation. Use `--set bootstrapPassword=admin` for this exercise.
::

## Step 4: Verify the Ingress

Once Rancher is running, it creates an ingress resource to handle external access.

::simple-task
---
:tasks: tasks
:name: verify_rancher_ingress
---
#active
Waiting for the Rancher ingress to be configured...

#completed
Rancher is fully installed and its ingress is configured. Well done.
::

::hint-box
---
:summary: Hint 5
---
If the ingress is not appearing, check that you set a valid `hostname` during the Helm install. Rancher uses that hostname to create its ingress rules.
::
