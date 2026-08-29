#!/bin/bash
set -euo pipefail

# Ensure the fleet CLI is available (installs it if the playground lacks it).
if ! command -v fleet >/dev/null 2>&1; then
  FLEET_VERSION=$(kubectl -n cattle-fleet-system get deployment fleet-controller \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null | awk -F: '{print $NF}')
  FLEET_VERSION=${FLEET_VERSION:-v0.10.0}
  ARCH=$(uname -m); case "${ARCH}" in x86_64) ARCH=amd64;; aarch64) ARCH=arm64;; esac
  curl -fsSL -o /usr/local/bin/fleet \
    "https://github.com/rancher/fleet/releases/download/${FLEET_VERSION}/fleet-linux-${ARCH}" \
    || curl -fsSL -o /usr/local/bin/fleet \
    "https://github.com/rancher/fleet/releases/latest/download/fleet-linux-${ARCH}"
  chmod +x /usr/local/bin/fleet
fi

# Fetch the pinned application manifest (a CI job would have written the tag).
mkdir -p /tmp/cd-manifests
wget --no-cache -O /tmp/cd-manifests/cd-app.yaml \
  "https://labs.iximiuz.com/__static__/cd-app.yaml?t=$(date +%s)"

# Deliver the manifests through Fleet as a Bundle (offline CD path).
fleet apply --namespace fleet-local cd-app /tmp/cd-manifests

examinerctl task wait verify_delivery_source --timeout 60s
examinerctl task wait verify_app_running --timeout 180s
examinerctl task wait verify_image_pinned --timeout 30s
examinerctl task wait verify_managed_by_fleet --timeout 30s
