---
kind: unit

title: Upgrades and Certificate Rotation

name: upgrades-and-certificate-rotation
---

Keeping Rancher current involves upgrading the server, the downstream clusters, and rotating certificates before they expire.

## Upgrading Rancher

Rancher upgrades follow the standard Helm upgrade path:

1. Review the release notes for breaking changes
2. Take a backup of the current state
3. Update the Helm repository (`helm repo update`)
4. Run `helm upgrade rancher rancher-latest/rancher` with the same values
5. Monitor the rollout and verify the UI is accessible

Key considerations:

- Rancher supports upgrading one minor version at a time (e.g., 2.8 to 2.9, not 2.7 to 2.9)
- Downstream cluster agents auto-update after the server upgrade
- cert-manager may also need upgrading if the new Rancher version requires a newer API version

## Upgrading Downstream Clusters

For K3s/RKE2 clusters provisioned by Rancher, upgrades are managed through the UI:

1. Select the cluster in Cluster Management
2. Edit the cluster configuration
3. Change the Kubernetes version
4. Rancher orchestrates a rolling upgrade of control plane and worker nodes

Imported clusters are upgraded independently by their operators - Rancher only manages what it provisions.

## Certificate Rotation

Certificates issued by cert-manager have expiry dates. Rancher and K3s both have internal certificates that rotate automatically, but you should monitor:

- Rancher ingress TLS certificate renewal
- K3s internal certificates (auto-rotated on restart if within 90 days of expiry)
- Webhook certificates used by admission controllers
