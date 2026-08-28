---
kind: unit

title: Continuous Delivery with Fleet

name: continuous-delivery-with-fleet
---

This lesson builds on Fleet to cover end-to-end continuous delivery workflows. You will learn how to integrate external CI systems (such as GitHub Actions or GitLab CI) with Rancher-managed clusters, and how Fleet serves as the CD layer that picks up new artifacts and rolls them out.

<!-- [image] cicd-pipeline.png - Diagram of the pipeline: build image, push to registry, update Git, Fleet deploys -->

## From Commit to Rollout

The lesson walks through building a pipeline that builds a container image, pushes it to a registry, updates the Git repository manifests, and lets Fleet deploy the new version automatically. It also covers strategies for staging vs. production rollouts across multiple clusters.

<!-- [image] cicd-staging-prod.png - Diagram of staging and production rollout targeting across clusters -->
