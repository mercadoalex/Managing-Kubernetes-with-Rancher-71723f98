---
kind: challenge

title: 'Install Kong from the Rancher Catalog and Route a Workload'

description: |
  Add the Kong Helm repository to Rancher's Apps, install the Kong ingress controller, and route a workload through the Kong gateway.
  This is the everyday platform-app workflow: add a repo, install a tool, and wire your workloads into it.

categories:
  - kubernetes

tagz:
  - Rancher
  - Kong
  - Ingress
  - platform-apps

difficulty: medium

createdAt: 2026-08-30
updatedAt: 2026-08-30

# Single-cluster playground with Rancher pre-installed (dev-machine workstation).
# TODO(publish): confirm/replace the suffix if it changes.
playground:
  name: rancher-k3s-e09b66ec

tasks:
  verify_kong_installed:
    machine: dev-machine
    user: laborant
    run: |
      export KUBECONFIG=$HOME/.kube/config
      rm -f /tmp/verify_kong_hint.txt

      CTRL=$(kubectl -n kong get deploy -l app.kubernetes.io/name=controller \
        -o jsonpath='{.items[0].status.readyReplicas}' 2>/dev/null || true)
      GW=$(kubectl -n kong get deploy -l app.kubernetes.io/name=gateway \
        -o jsonpath='{.items[0].status.readyReplicas}' 2>/dev/null || true)
      if [ "${CTRL:-0}" -lt 1 ] || [ "${GW:-0}" -lt 1 ]; then
        echo "Kong's controller and gateway are not both running in the 'kong' namespace yet." | tee /tmp/verify_kong_hint.txt
        exit 1
      fi
      echo "Kong controller and gateway are both running."
    hintcheck: |
      if [ -f /tmp/verify_kong_hint.txt ]; then
        cat /tmp/verify_kong_hint.txt
        rm -f /tmp/verify_kong_hint.txt
      fi

  verify_ingressclass:
    machine: dev-machine
    user: laborant
    needs:
      - verify_kong_installed
    run: |
      export KUBECONFIG=$HOME/.kube/config
      if ! kubectl get ingressclass kong >/dev/null 2>&1; then
        echo "The 'kong' IngressClass does not exist yet - is Kong fully installed?"
        exit 1
      fi
      echo "The 'kong' IngressClass is registered."

  verify_nodeport:
    machine: dev-machine
    user: laborant
    needs:
      - verify_ingressclass
    run: |
      export KUBECONFIG=$HOME/.kube/config
      rm -f /tmp/verify_nodeport_hint.txt

      NP=$(kubectl -n kong get svc kong-gateway-proxy \
        -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}' 2>/dev/null || true)
      if [ "${NP}" != "30081" ]; then
        echo "Kong's proxy is not exposed on NodePort 30081 (found: '${NP}')." | tee /tmp/verify_nodeport_hint.txt
        echo "The gateway proxy must be a NodePort service with HTTP on nodePort 30081." | tee -a /tmp/verify_nodeport_hint.txt
        exit 1
      fi
      echo "Kong's proxy is exposed on NodePort 30081."
    hintcheck: |
      if [ -f /tmp/verify_nodeport_hint.txt ]; then
        cat /tmp/verify_nodeport_hint.txt
        rm -f /tmp/verify_nodeport_hint.txt
      fi

  verify_route:
    machine: dev-machine
    user: laborant
    needs:
      - verify_nodeport
    run: |
      export KUBECONFIG=$HOME/.kube/config
      rm -f /tmp/verify_route_hint.txt

      # An Ingress in the demo namespace must opt into the Kong class.
      ICLASS=$(kubectl -n demo get ingress -o jsonpath='{.items[0].spec.ingressClassName}' 2>/dev/null || true)
      if [ "${ICLASS}" != "kong" ]; then
        echo "No Ingress in namespace 'demo' using ingressClassName 'kong' yet." | tee /tmp/verify_route_hint.txt
        exit 1
      fi

      # Prove Kong actually serves the route: HTTP 200 through the gateway
      # NodePort on the control-plane node IP. Poll to allow route programming.
      for i in $(seq 1 20); do
        CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
          http://172.16.0.2:30081/ 2>/dev/null || true)
        if [ "${CODE}" = "200" ]; then
          echo "Kong serves the route (HTTP 200 on :30081) - challenge complete."
          exit 0
        fi
        sleep 3
      done
      echo "Kong did not return HTTP 200 on :30081 (last code: ${CODE})." | tee /tmp/verify_route_hint.txt
      echo "Check the Ingress backend points at a running Service in 'demo'." | tee -a /tmp/verify_route_hint.txt
      exit 1
    hintcheck: |
      if [ -f /tmp/verify_route_hint.txt ]; then
        cat /tmp/verify_route_hint.txt
        rm -f /tmp/verify_route_hint.txt
      fi
---

Rancher's Apps catalog is where a platform team installs and manages shared tooling on a cluster. In this challenge you will use it for a real task: add a third-party Helm repository, install the **Kong** ingress controller from it, and route a workload through the Kong gateway.

The playground is a multi-node K3s cluster with Rancher already installed. K3s ships **Traefik** as the default ingress controller; Kong will join it as a second controller that workloads opt into per-Ingress. Work from the :tab{text='dev-machine' machine='dev-machine'} terminal (its `kubectl` and `helm` are already pointed at the cluster), or drive the same steps through the Rancher UI's **Apps** screens.

## Step 1: Install Kong from the Catalog

Add Kong's Helm repository and install its ingress controller into a `kong` namespace. The Kong gateway's proxy must be reachable on **NodePort 30081** (this cluster has no external load balancer, so a fixed NodePort is how you reach the gateway).

::simple-task
---
:tasks: tasks
:name: verify_kong_installed
---
#active
Waiting for Kong's controller and gateway to be running...

#completed
Kong is installed and running.
::

::simple-task
---
:tasks: tasks
:name: verify_ingressclass
---
#active
Waiting for the `kong` IngressClass...

#completed
The `kong` IngressClass is registered.
::

::simple-task
---
:tasks: tasks
:name: verify_nodeport
---
#active
Waiting for the Kong proxy on NodePort 30081...

#completed
The Kong proxy is exposed on NodePort 30081.
::

::hint-box
---
:summary: Hint 1 - adding the repo and installing
---
Kong is not a built-in Rancher chart, so register its Helm repository first (`charts.konghq.com`), then install its `ingress` chart into a new `kong` namespace. The recommended chart runs Kong in DB-less mode, so there is no database to set up.
::

::hint-box
---
:summary: Hint 2 - pinning the proxy port
---
The gateway's proxy Service wants a `LoadBalancer` address it will never get here, so it stays `<pending>`. Configure the proxy as a `NodePort` instead and pin its HTTP port to `30081` - the chart exposes values for the proxy service type and its HTTP node port. This is what makes the gateway reachable at `172.16.0.2:30081`.
::

## Step 2: Route a Workload Through Kong

Run any HTTP workload in a `demo` namespace, put a Service in front of it, and create an Ingress that uses the **kong** ingress class so Kong handles its traffic. When it works, a request to the Kong gateway returns HTTP 200.

::simple-task
---
:tasks: tasks
:name: verify_route
---
#active
Waiting for a request to reach your workload through Kong on port 30081...

#completed
Traffic is flowing through Kong to your workload. Well done.
::

You can watch it in the browser through the :tab{text='Kong' name='Kong'} tab once the route is live.

::hint-box
---
:summary: Hint 3 - the one field that picks Kong
---
An Ingress goes through Kong instead of the default Traefik when its `spec.ingressClassName` is set to `kong`. Make sure the Ingress backend points at your Service and that the Service has endpoints (its selector matches running pods).
::
