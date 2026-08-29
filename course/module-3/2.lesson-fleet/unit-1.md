---
kind: unit

title: Fleet Concepts and GitRepos

name: fleet-concepts-and-gitrepos
---

This lesson introduces Rancher Fleet - the built-in GitOps engine that ships with Rancher. You will learn how Fleet watches Git repositories and automatically deploys manifests to one or many clusters.

<!-- [image] fleet-gitops-flow.png - Diagram showing Git commit flowing through Fleet to multiple clusters -->

## Core Fleet Objects

The lesson covers Fleet's core concepts: GitRepos, Bundles, BundleDeployments, and cluster groups. You will configure a Git repository as a deployment source, define targeting rules to control which clusters receive which workloads, and observe how changes pushed to Git propagate automatically to the cluster.

<!-- [image] fleet-objects.png - Diagram of GitRepo -> Bundle -> BundleDeployment relationship -->
