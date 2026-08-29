---
kind: lesson

title: Multi-Cluster Management
description: |
  Register a second, independent Kubernetes cluster into Rancher and manage both from one control plane.

name: multi-cluster-management
slug: multi-cluster-management

createdAt: 2026-08-27
updatedAt: 2026-08-27

categories:
- kubernetes

tagz:
- rancher
- multi-cluster

# cover: __static__/cover.png

# Two-cluster topology: rancher-server (upstream, Rancher pre-installed) +
# downstream-01 (a separate, empty K3s cluster to import) + dev-machine
# workstation. See playgrounds/rancher-k3s-downstream/manifest.yaml.
# TODO(publish): replace with the suffixed name printed by
#   `labctl playground create rancher-k3s-downstream --base flexbox`
playground:
  name: rancher-k3s-downstream-54528e97

challenges:
  # TODO(publish): replace with the suffixed name the platform assigns when the
  # reworked challenge is (re)created, then reference it in the ::card below.
  rancher-import-downstream-cluster-REPLACEME: {}

tasks:
  # All verification runs on the dev-machine workstation as laborant, against
  # the UPSTREAM (Rancher) cluster via the pre-provisioned kubeconfig. Importing
  # the downstream cluster creates a management Cluster object on the upstream,
  # so we can confirm the import from here.
  verify_downstream_imported:
    machine: dev-machine
    user: laborant
    run: |
      export KUBECONFIG=$HOME/.kube/config
      # Rancher records every managed cluster as a clusters.management.cattle.io
      # object on the upstream. The built-in Rancher cluster is named "local";
      # an imported cluster shows up as an additional object.
      COUNT=$(kubectl get clusters.management.cattle.io \
        --no-headers 2>/dev/null | grep -v '^local ' | wc -l | tr -d ' ')
      if [ "${COUNT:-0}" -lt 1 ]; then
        echo "No imported cluster found yet. Register downstream-01 in Rancher first."
        exit 1
      fi
      echo "Found ${COUNT} imported cluster(s) besides local"

  verify_downstream_active:
    machine: dev-machine
    user: laborant
    needs:
      - verify_downstream_imported
    run: |
      export KUBECONFIG=$HOME/.kube/config
      # The imported cluster must reach the Ready/Active state, which only
      # happens once the cluster agent on downstream-01 connects back to Rancher.
      NAME=$(kubectl get clusters.management.cattle.io \
        --no-headers 2>/dev/null | grep -v '^local ' | head -1 | awk '{print $1}')
      if [ -z "${NAME}" ]; then
        echo "No imported cluster object to check"
        exit 1
      fi
      READY=$(kubectl get clusters.management.cattle.io "${NAME}" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
      if [ "${READY}" != "True" ]; then
        echo "Imported cluster '${NAME}' is registered but not Ready yet; wait for its agent to connect"
        exit 1
      fi
      echo "Imported cluster '${NAME}' is Ready and managed by Rancher"
---
