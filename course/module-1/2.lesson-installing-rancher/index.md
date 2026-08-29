---
kind: lesson

title: Installing Rancher on K3s
description: |
  Install cert-manager, an ingress controller, and Rancher itself on a K3s cluster using Helm.

name: installing-rancher-on-k3s
slug: installing-rancher-on-k3s

createdAt: 2026-08-27
updatedAt: 2026-08-27

categories:
- kubernetes

tagz:
- rancher
- k3s
- helm

# cover: __static__/cover.png

playground:
  name: k3s-workstation-1430c761

tasks:
  # All tasks run on dev-machine (the student's workstation) as the laborant
  # user, so they pick up the kubeconfig the student sets up at ~/.kube/config.
  verify_on_workstation:
    machine: dev-machine
    user: laborant
    run: |
      HOST=$(hostname)
      if [ "${HOST}" != "dev-machine" ]; then
        echo "Expected workstation host dev-machine, got ${HOST}"
        exit 1
      fi
      echo "On workstation dev-machine"

  verify_cert_manager:
    machine: dev-machine
    user: laborant
    needs:
      - verify_on_workstation
    run: |
      export KUBECONFIG=$HOME/.kube/config
      # cert-manager ships three deployments; all must have a ready replica.
      for dep in cert-manager cert-manager-webhook cert-manager-cainjector; do
        READY=$(kubectl -n cert-manager get deployment "${dep}" \
          -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        if [ -z "${READY}" ] || [ "${READY}" -lt 1 ]; then
          echo "cert-manager component '${dep}' is not ready yet"
          exit 1
        fi
      done
      echo "cert-manager is installed and ready"

  verify_rancher_running:
    machine: dev-machine
    user: laborant
    needs:
      - verify_cert_manager
    run: |
      export KUBECONFIG=$HOME/.kube/config
      REPLICAS=$(kubectl -n cattle-system get deployment rancher -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
      if [ -z "${REPLICAS}" ] || [ "${REPLICAS}" -lt 1 ]; then
        echo "Rancher deployment does not have a ready replica yet"
        exit 1
      fi
      echo "Rancher is running"

  verify_rancher_ingress:
    machine: dev-machine
    user: laborant
    needs:
      - verify_rancher_running
    run: |
      export KUBECONFIG=$HOME/.kube/config
      HOST=$(kubectl -n cattle-system get ingress -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null)
      if [ -z "${HOST}" ]; then
        echo "No Rancher ingress with a host rule found yet"
        exit 1
      fi
      echo "Rancher ingress is configured for host ${HOST}"

  verify_lesson_complete:
    machine: dev-machine
    user: laborant
    needs:
      - verify_rancher_ingress
    run: |
      # End-to-end proof: Rancher answers OK on its health endpoint. From the
      # workstation, rancher.localhost is not resolvable, so we reach the
      # control-plane IP and send the Host header Traefik matches on.
      BODY=$(curl -sk --max-time 5 --resolve rancher.localhost:443:172.16.0.2 \
        https://rancher.localhost/healthz 2>/dev/null)
      if [ "${BODY}" != "ok" ]; then
        echo "Rancher healthz did not return ok yet (got: '${BODY}')"
        exit 1
      fi
      echo "Rancher is healthy and serving - lesson complete"
---
