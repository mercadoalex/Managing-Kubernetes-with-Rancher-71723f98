---
kind: unit

title: Rancher Architecture

name: rancher-architecture
---

Rancher runs as a set of containers on top of an existing Kubernetes cluster (the "local" or "management" cluster). From there, it can import existing clusters, provision new clusters on infrastructure providers, and manage K3s and RKE2 distributions natively.

<!-- [image] rancher-architecture.png - Architecture diagram showing management cluster, downstream clusters, agents, and communication flow -->

## Key Components

Rancher's architecture consists of several key pieces:

- **Rancher Server** - the management plane that runs on a Kubernetes cluster and exposes both a UI and an API
- **Rancher Agent** - deployed on downstream clusters to establish a tunnel back to the Rancher server
- **Fleet** - the built-in GitOps engine for continuous delivery across clusters
- **Authentication Proxy** - integrates with external identity providers (LDAP, SAML, GitHub, etc.)

<!-- [image] rancher-components.png - Diagram of the key components: server, agent, Fleet, and authentication proxy -->

Rancher can import existing Kubernetes clusters for centralized management, provision new clusters on infrastructure providers (AWS, Azure, GCP, vSphere, bare metal), and enforce consistent policies and RBAC across all managed clusters.
