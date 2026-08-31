#!/bin/bash
set -euo pipefail

# CI solution for "Rate-Limit a Route with a Kong Plugin".
# Runs on the dev-machine workstation. Kong and the web route are already
# installed by the init tasks. Create a rate-limiting KongPlugin and attach it
# to the web Ingress, then let the gate confirm the route returns 429.

export KUBECONFIG=$HOME/.kube/config

kubectl apply -f - <<'EOF'
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: rate-limit-5
  namespace: demo
plugin: rate-limiting
config:
  minute: 5
  policy: local
EOF

kubectl -n demo annotate ingress web konghq.com/plugins=rate-limit-5 --overwrite

# Give Kong a moment to program the limit into the gateway.
sleep 8

# Sanity: drive the route past the limit so a 429 is present for the gate.
for i in $(seq 1 10); do
  curl -sS -o /dev/null "http://172.16.0.2:30081/" 2>/dev/null || true
done

examinerctl task wait verify_ratelimit_enforced --timeout 90s
