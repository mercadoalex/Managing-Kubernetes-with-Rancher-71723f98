#!/bin/bash
set -euo pipefail

# Install standalone Fleet (CRDs then controller)
helm -n cattle-fleet-system install --create-namespace --wait \
  fleet-crd oci://reg.rancher.com/rancher/fleet-crd

helm -n cattle-fleet-system install --create-namespace --wait \
  fleet oci://reg.rancher.com/rancher/fleet

examinerctl task wait verify_fleet_crds --timeout 60s
examinerctl task wait verify_fleet_controller --timeout 120s

# Wait for the local cluster to register
for i in $(seq 1 60); do
  if kubectl -n fleet-local get clusters.fleet.cattle.io -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | grep -q .; then
    break
  fi
  sleep 5
done

examinerctl task wait verify_cluster_registered --timeout 120s

# Label the registered cluster for targeting
CLUSTER=$(kubectl -n fleet-local get clusters.fleet.cattle.io -o jsonpath='{.items[0].metadata.name}')
kubectl -n fleet-local label cluster.fleet.cattle.io "${CLUSTER}" env=lab --overwrite

examinerctl task wait verify_cluster_labeled --timeout 30s
