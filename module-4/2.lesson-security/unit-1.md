---
kind: unit

title: Authentication and Pod Security

name: authentication-and-pod-security
---

This unit covers securing Rancher-managed clusters - authentication providers and pod-level security controls.

<!-- [image] rancher-auth-providers.png - Diagram of external identity providers integrating with Rancher -->

## Authentication Providers

Rancher supports integrating with external identity providers so users do not need local accounts:

- **LDAP/Active Directory** - enterprise directory integration
- **SAML** (Okta, ADFS, Ping Identity) - SSO for web-based access
- **GitHub/GitLab** - OAuth-based login for development teams
- **OpenID Connect** - standards-based identity federation

Once configured, users authenticate through their existing credentials and Rancher maps them to roles automatically based on group membership.

## Pod Security

Rancher provides two mechanisms for enforcing pod-level security:

- **Pod Security Admissions (PSA)** - Kubernetes-native enforcement at the namespace level (privileged, baseline, restricted)
- **OPA Gatekeeper / Kubewarden** - policy engines that allow custom admission rules beyond what PSA covers

Through the Rancher UI, you can assign PSA levels per namespace or project and deploy policy templates that prevent privileged containers, enforce image pull policies, or require resource limits.
