---
kind: challenge

title: 'Rate-Limit a Route with a Kong Plugin'

description: |
  Kong is already installed and routing a workload. Turn it from a plain ingress
  controller into an API gateway: attach a rate-limiting plugin to the route so
  the gateway rejects requests over the limit with HTTP 429.

categories:
  - kubernetes

tagz:
  - Rancher
  - Kong
  - api-gateway
  - plugins

difficulty: medium

createdAt: 2026-08-31
updatedAt: 2026-08-31

# Single-cluster playground with Rancher pre-installed (dev-machine workstation).
# TODO(publish): confirm/replace the suffix if it changes.
playground:
  name: rancher-k3s-e09b66ec

tasks:
  # Wait until the workstation can reach the cluster.
  init_wait_cluster:
    init: true
    machine: dev-machine
    user: laborant
    timeout_seconds: 240
    run: |
      export KUBECONFIG=$HOME/.kube/config
      for i in $(seq 1 60); do
        kubectl get nodes 2>/dev/null | grep -q " Ready" && exit 0
        sleep 4
      done
      echo "Cluster not reachable from the workstation in time"
      exit 1

  # Install Kong and route a web workload through it, so the challenge is about
  # attaching a plugin - not installing Kong (that was the previous challenge).
  init_install_kong:
    init: true
    machine: dev-machine
    user: laborant
    needs:
      - init_wait_cluster
    timeout_seconds: 420
    run: |
      export KUBECONFIG=$HOME/.kube/config
      helm repo add kong https://charts.konghq.com >/dev/null 2>&1 || true
      helm repo update kong >/dev/null 2>&1 || true
      if ! helm status kong -n kong >/dev/null 2>&1; then
        helm install kong kong/ingress \
          --namespace kong --create-namespace \
          --set gateway.proxy.type=NodePort \
          --set gateway.proxy.http.nodePort=30081 \
          --wait --timeout 5m >/dev/null 2>&1 || true
      fi
      kubectl get namespace demo >/dev/null 2>&1 || kubectl create namespace demo
      kubectl -n demo get deployment web >/dev/null 2>&1 \
        || kubectl -n demo create deployment web --image=nginx:1.27
      kubectl -n demo get svc web >/dev/null 2>&1 \
        || kubectl -n demo expose deployment web --port=80
      kubectl apply -f - >/dev/null 2>&1 <<'EOF' || true
      apiVersion: networking.k8s.io/v1
      kind: Ingress
      metadata:
        name: web
        namespace: demo
      spec:
        ingressClassName: kong
        rules:
          - http:
              paths:
                - path: /
                  pathType: Prefix
                  backend:
                    service:
                      name: web
                      port:
                        number: 80
      EOF
      kubectl -n demo rollout status deployment/web --timeout=180s >/dev/null 2>&1 || true
      echo "Kong installed and the web workload is routed through it."

  # Baseline for the negative condition: before the student adds a rate limit,
  # the route serves normally - a burst of requests returns 200, never 429.
  init_baseline_no_limit:
    init: true
    machine: dev-machine
    user: laborant
    needs:
      - init_install_kong
    timeout_seconds: 180
    run: |
      export KUBECONFIG=$HOME/.kube/config
      # Wait for the route to come up (HTTP 200 through the gateway NodePort).
      READY=""
      for i in $(seq 1 30); do
        CODE=$(curl -sS --max-time 8 -o /dev/null -w "%{http_code}" \
          "http://172.16.0.2:30081/" 2>/dev/null || true)
        if [ "${CODE}" = "200" ]; then
          READY="yes"
          break
        fi
        sleep 3
      done
      if [ "${READY}" != "yes" ]; then
        echo "The baseline route never returned HTTP 200 - Kong route not ready."
        exit 1
      fi
      # Confirm there is no rate limiting yet: a burst stays at 200, no 429.
      for i in $(seq 1 12); do
        CODE=$(curl -sS --max-time 8 -o /dev/null -w "%{http_code}" \
          "http://172.16.0.2:30081/" 2>/dev/null || true)
        if [ "${CODE}" = "429" ]; then
          echo "Unexpected: the route is already rate-limited at baseline."
          exit 1
        fi
      done
      echo "Baseline confirmed: the route serves without a rate limit (no 429)."

  # Gate: a rate-limiting KongPlugin is attached AND the gateway enforces it,
  # returning HTTP 429 once the limit is exceeded.
  verify_ratelimit_enforced:
    machine: dev-machine
    user: laborant
    needs:
      - init_baseline_no_limit
    run: |
      export KUBECONFIG=$HOME/.kube/config
      rm -f /tmp/verify_ratelimit_hint.txt

      if ! kubectl -n demo get kongplugin -o jsonpath='{.items[*].plugin}' 2>/dev/null | grep -qw rate-limiting; then
        echo "No rate-limiting KongPlugin found in the 'demo' namespace yet." | tee /tmp/verify_ratelimit_hint.txt
        echo "Create a KongPlugin with 'plugin: rate-limiting' and attach it to the web Ingress." | tee -a /tmp/verify_ratelimit_hint.txt
        exit 1
      fi

      # Prove enforcement: hammer the route and confirm a 429 appears.
      SAW_429=""
      for i in $(seq 1 30); do
        CODE=$(curl -sS --max-time 8 -o /dev/null -w "%{http_code}" \
          "http://172.16.0.2:30081/" 2>/dev/null || true)
        if [ "${CODE}" = "429" ]; then
          SAW_429="yes"
          break
        fi
      done
      if [ "${SAW_429}" != "yes" ]; then
        echo "The route did not return HTTP 429 within 30 requests - the rate limit is not enforcing." | tee /tmp/verify_ratelimit_hint.txt
        echo "Attach the plugin to the web Ingress with the konghq.com/plugins annotation, and use a small per-minute limit." | tee -a /tmp/verify_ratelimit_hint.txt
        exit 1
      fi
      echo "Rate limiting is enforcing: the route returns HTTP 429 once the limit is exceeded."
    hintcheck: |
      if [ -f /tmp/verify_ratelimit_hint.txt ]; then
        cat /tmp/verify_ratelimit_hint.txt
        rm -f /tmp/verify_ratelimit_hint.txt
      fi
---

Kong is already installed on this cluster, and a `web` workload in the `demo` namespace is routed through it - a request to the Kong gateway on `http://172.16.0.2:30081/` returns HTTP 200. Right now Kong is just forwarding traffic, no different from any ingress controller.

Your job is to make it behave like an **API gateway**: attach a **rate-limiting** plugin to the route so that once a client exceeds the limit, the gateway rejects further requests with **HTTP 429 Too Many Requests** - before they ever reach the workload. You work from the :tab{text='dev-machine' machine='dev-machine'} terminal.

## Rate-Limit the Route

Create a rate-limiting Kong plugin and attach it to the `web` Ingress. Pick a small per-minute limit so the effect is easy to see. When it works, a burst of requests to the gateway starts returning `429` once the limit is passed.

::simple-task
---
:tasks: tasks
:name: verify_ratelimit_enforced
---
#active
Waiting for the route to return HTTP 429 once the rate limit is exceeded...

#completed
Rate limiting is enforcing - your gateway now throttles the route.
::

::hint-box
---
:summary: Hint 1 - the plugin object
---
Kong plugins are Kubernetes resources. Create a `KongPlugin` (API group `configuration.konghq.com/v1`) in the `demo` namespace with `plugin: rate-limiting` and a `config` that sets a per-minute limit. For a DB-less Kong like this one, use `policy: local` so the count is kept in the gateway pod with no external store.
::

::hint-box
---
:summary: Hint 2 - attaching it to the route
---
A `KongPlugin` does nothing until a route references it. Add the annotation `konghq.com/plugins=<your-plugin-name>` to the `web` Ingress in the `demo` namespace (`kubectl annotate ingress ...`). Give Kong a few seconds to reconcile, then send more requests than your limit allows and watch for the `429`.
::
