---
kind: lesson

title: Deploying Platform Apps - Kong Gateway
description: |
  Add a Helm repository to Rancher's Apps catalog, install the Kong ingress controller, and route a workload through the Kong gateway.

name: platform-apps-kong
slug: platform-apps-kong

createdAt: 2026-08-30
updatedAt: 2026-08-30

categories:
- kubernetes

tagz:
- rancher
- kong
- ingress
- platform-apps

# cover: __static__/cover.png

# Single-cluster playground with Rancher pre-installed (dev-machine workstation).
# TODO(publish): confirm/replace the suffix if it changes.
playground:
  name: rancher-k3s-e09b66ec

# Gate challenge for this lesson. Files live in
# challenges/rancher-install-kong-catalog/, registered on the platform as the
# suffixed name below.
challenges:
  rancher-install-kong-catalog-6660440d: {}

tasks:
  # Tasks run on the dev-machine workstation as laborant, using the
  # pre-provisioned kubeconfig at ~/.kube/config.
  verify_kong_installed:
    machine: dev-machine
    user: laborant
    run: |
      export KUBECONFIG=$HOME/.kube/config
      # Kong's controller and gateway are separate deployments, distinguished by
      # the app.kubernetes.io/name label (controller vs gateway).
      CTRL=$(kubectl -n kong get deploy -l app.kubernetes.io/name=controller \
        -o jsonpath='{.items[0].status.readyReplicas}' 2>/dev/null || true)
      GW=$(kubectl -n kong get deploy -l app.kubernetes.io/name=gateway \
        -o jsonpath='{.items[0].status.readyReplicas}' 2>/dev/null || true)
      if [ "${CTRL:-0}" -lt 1 ] || [ "${GW:-0}" -lt 1 ]; then
        echo "Kong is not installed and running yet in the 'kong' namespace."
        echo "Add the Kong Helm repo to Rancher's Apps and install 'kong/ingress'."
        exit 1
      fi
      echo "Kong controller and gateway are both running."

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

  verify_route:
    machine: dev-machine
    user: laborant
    needs:
      - verify_ingressclass
    run: |
      export KUBECONFIG=$HOME/.kube/config
      # There must be an Ingress in the demo namespace routed through Kong.
      ICLASS=$(kubectl -n demo get ingress -o jsonpath='{.items[0].spec.ingressClassName}' 2>/dev/null || true)
      if [ "${ICLASS}" != "kong" ]; then
        echo "No Ingress in namespace 'demo' using ingressClassName 'kong' yet."
        exit 1
      fi
      # On this playground the Kong proxy is a NodePort on 30081 (its
      # LoadBalancer external IP stays pending because Traefik owns 80/443).
      # Prove the route actually serves traffic by hitting Kong on the control-
      # plane node IP. HTTP 200 means Kong programmed the route to the backend.
      CODE=$(curl -sS --max-time 8 -o /dev/null -w "%{http_code}" \
        "http://172.16.0.2:30081/" 2>/dev/null || true)
      if [ "${CODE}" != "200" ]; then
        echo "Kong is not serving the route yet (got HTTP '${CODE}' from :30081)."
        echo "Confirm the Ingress uses ingressClassName 'kong' and give Kong a moment to program it."
        exit 1
      fi
      echo "An Ingress in 'demo' is served through Kong on :30081 (HTTP 200) - lesson complete."
---
