---
kind: unit

title: Compliance, Network Policies, and Secrets

name: compliance-network-secrets
---

Beyond authentication and pod security, hardening a Rancher-managed cluster involves compliance scanning, network segmentation, and secrets management.

## CIS Benchmarks

Rancher includes a CIS Benchmark scanning tool that audits clusters against the Center for Internet Security Kubernetes Benchmark. Scans produce a report showing which controls pass, fail, or require manual review. You can schedule periodic scans and track compliance over time.

<!-- [image] rancher-cis-scan.png - Screenshot of a CIS benchmark scan report in Rancher -->

## Network Policies and Segmentation

Security-focused network segmentation includes:

- Isolating projects from each other at the network level
- Restricting egress to known external endpoints
- Enforcing mTLS between services (through a service mesh integration)

## Secrets Management

Rancher integrates with external secret stores:

- **HashiCorp Vault** - inject secrets at runtime without storing them in etcd
- **AWS Secrets Manager / Azure Key Vault** - cloud-native secret backends
- **Sealed Secrets** - encrypt secrets in Git for GitOps workflows
