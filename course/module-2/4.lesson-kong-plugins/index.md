---
kind: lesson

title: Gateway Policies with Kong Plugins
description: |
  Turn Kong from a plain ingress controller into an API gateway by attaching policies as Kubernetes resources - rate limiting and key authentication - with Kong's own CRDs.

name: kong-plugins
slug: kong-plugins

createdAt: 2026-08-31
updatedAt: 2026-08-31

categories:
- kubernetes

tagz:
- rancher
- kong
- api-gateway
- plugins

# cover: __static__/cover.png

# Single-cluster playground with Rancher pre-installed (dev-machine workstation).
# TODO(publish): confirm/replace the suffix if it changes.
playground:
  name: rancher-k3s-e09b66ec

# Gate challenge for this lesson. Files live in
# challenges/rancher-kong-rate-limit/, registered on the platform as the
# suffixed name below.
challenges:
  rancher-kong-rate-limit-849ce3bd: {}

tasks:
  # Tasks run on the dev-machine workstation as laborant, using the
  # pre-provisioned kubeconfig at ~/.kube/config.
  verify_ratelimit_enforced:
    machine: dev-machine
    user: laborant
    run: |
      export KUBECONFIG=$HOME/.kube/config
      # A rate-limiting KongPlugin must exist in the demo namespace.
      if ! kubectl -n demo get kongplugin -o jsonpath='{.items[*].plugin}' 2>/dev/null | grep -qw rate-limiting; then
        echo "No rate-limiting KongPlugin found in the 'demo' namespace yet."
        echo "Create a KongPlugin with 'plugin: rate-limiting' and attach it to the web Ingress."
        exit 1
      fi
      # Prove enforcement, not just the object: hammer the route past the limit
      # and confirm Kong starts returning HTTP 429. The proxy is a NodePort on
      # 30081 (its LoadBalancer IP stays pending because Traefik owns 80/443).
      SAW_429=""
      for i in $(seq 1 25); do
        CODE=$(curl -sS --max-time 8 -o /dev/null -w "%{http_code}" \
          "http://172.16.0.2:30081/" 2>/dev/null || true)
        if [ "${CODE}" = "429" ]; then
          SAW_429="yes"
          break
        fi
      done
      if [ "${SAW_429}" != "yes" ]; then
        echo "The route did not return HTTP 429 within 25 requests - rate limiting is not enforcing yet."
        echo "Attach the rate-limiting plugin to the web Ingress with the konghq.com/plugins annotation, and set a small per-minute limit."
        exit 1
      fi
      echo "Rate limiting is enforcing: the route returns HTTP 429 once the limit is exceeded."

  verify_keyauth_enforced:
    machine: dev-machine
    user: laborant
    needs:
      - verify_ratelimit_enforced
    run: |
      export KUBECONFIG=$HOME/.kube/config
      # A key-auth KongPlugin must exist in the demo namespace.
      if ! kubectl -n demo get kongplugin -o jsonpath='{.items[*].plugin}' 2>/dev/null | grep -qw key-auth; then
        echo "No key-auth KongPlugin found in the 'demo' namespace yet."
        echo "Create a KongPlugin with 'plugin: key-auth' and attach it to the web Ingress."
        exit 1
      fi
      # A request WITHOUT a valid key must be rejected. Rate limiting may still
      # be active, so treat 401 as the pass signal and keep trying briefly in
      # case the limiter returns 429 first.
      SAW_401=""
      for i in $(seq 1 25); do
        CODE=$(curl -sS --max-time 8 -o /dev/null -w "%{http_code}" \
          "http://172.16.0.2:30081/" 2>/dev/null || true)
        if [ "${CODE}" = "401" ]; then
          SAW_401="yes"
          break
        fi
        sleep 1
      done
      if [ "${SAW_401}" != "yes" ]; then
        echo "A request with no API key was not rejected with HTTP 401 - key authentication is not enforcing yet."
        echo "Attach the key-auth plugin to the web Ingress and create a KongConsumer with a credential."
        exit 1
      fi
      echo "Key authentication is enforcing: a request with no valid key is rejected with HTTP 401."
---
