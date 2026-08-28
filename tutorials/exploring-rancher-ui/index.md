---
kind: tutorial

title: Exploring the Rancher UI

description: |
  Log into the Rancher web interface for the first time, navigate the cluster dashboard,
  and understand the key areas of the management UI.

categories:
  - kubernetes
  - containers

tagz:
  - Rancher
  - UI
  - Dashboard
  - Cluster Management

createdAt: 2026-08-27
updatedAt: 2026-08-27

playground:
  name: ubuntu-k3s-bare
---

## Overview

Once Rancher is installed and running, the primary way most administrators interact with it is through the web UI. The Rancher UI provides a complete cluster management experience - from viewing workloads and pods to configuring RBAC and deploying applications.

This tutorial assumes Rancher is already installed (as covered in the previous unit). You will access the UI, complete the initial setup, and learn your way around the dashboard.

## Accessing the Rancher UI

Rancher's web interface is served over HTTPS on the hostname you configured during installation. In this playground, that is `rancher.localhost`.

Confirm Rancher is responding:

```bash
curl -sk https://rancher.localhost/healthz
```

The UI is accessible at `https://rancher.localhost`. Since the playground uses port publishing, you can open the published port URL in your browser to access the interface directly.

## First Login and Bootstrap

On first access, Rancher presents a bootstrap screen. You need:

1. The bootstrap password you set during installation (`admin` in this lab)
2. To set a new admin password (or keep the bootstrap one for lab purposes)
3. To accept the Rancher server URL

You can also retrieve the bootstrap password programmatically if needed:

```bash
kubectl get secret --namespace cattle-system bootstrap-secret \
  -o go-template='{{.data.bootstrapPassword|base64decode}}'
```

After login, Rancher drops you into the home page showing the cluster list.

## The Home Page

The home page shows all clusters managed by this Rancher instance. After a fresh install, you will see one cluster - the **local** cluster. This is the cluster where Rancher itself is running.

Key elements on the home page:
- **Cluster list** - each cluster card shows its name, state, Kubernetes version, and node count
- **Import Existing** button - registers an external cluster with Rancher
- **Create** button - provisions a new cluster through Rancher

## Cluster Dashboard

Click the **local** cluster to enter the cluster dashboard. This is the primary workspace for managing a single cluster. The dashboard is divided into several sections accessible from the left sidebar:

**Cluster** section:
- **Nodes** - view and manage cluster nodes, their roles, conditions, and resource usage
- **Namespaces** - list and create namespaces
- **Events** - recent cluster events (scheduling decisions, errors, warnings)

**Workload** section:
- **Deployments** - manage deployment objects
- **Pods** - view individual pods, their logs, and exec into containers
- **Services** - services and their endpoints
- **Ingresses** - ingress rules and their backends
- **CronJobs / Jobs** - scheduled and one-off jobs

**Storage** section:
- **PersistentVolumes** - cluster-level storage resources
- **PersistentVolumeClaims** - namespace-scoped storage requests
- **StorageClasses** - available storage provisioners

**Apps** section:
- **Charts** - Helm chart repositories and available charts
- **Installed Apps** - Helm releases deployed in the cluster

## Inspecting Cluster Resources via CLI

Everything visible in the UI corresponds to Kubernetes API objects. You can verify this from the terminal.

List the nodes as shown in the UI:

```bash
kubectl get nodes -o wide
```

Check the deployments across all namespaces:

```bash
kubectl get deployments -A
```

View the Rancher-specific resources:

```bash
kubectl get pods -n cattle-system
kubectl get pods -n cattle-fleet-system
```

## Global Settings

From the top navigation bar, you can access global settings that apply across all managed clusters:

- **Users & Authentication** - manage local users, configure external auth providers (LDAP, SAML, GitHub, etc.)
- **Global Settings** - server URL, telemetry, branding, performance settings
- **Feature Flags** - enable or disable experimental Rancher features
- **Cluster Management** - the top-level view for managing all clusters, drivers, and cloud credentials

## Understanding the Rancher API

The UI is backed by the Rancher API. Every action you take in the UI is an API call. You can interact with the API directly:

```bash
curl -sk https://rancher.localhost/v3 | jq '.type'
```

This returns the API schema root. The Rancher API extends the standard Kubernetes API with additional resources for cluster management, user authentication, and multi-cluster operations.

List clusters through the API:

```bash
curl -sk -u admin:admin https://rancher.localhost/v3/clusters | jq '.data[].name'
```

## Summary

You now know how to navigate the Rancher UI. The dashboard provides a centralized view of your cluster's workloads, storage, networking, and configuration. In the next unit, you will use both the UI and CLI to deploy actual workloads through Rancher.
