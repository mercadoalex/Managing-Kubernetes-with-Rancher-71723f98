---
kind: unit

title: The Wider Security Surface

name: wider-security-surface
---

Pod security is one control among several. Hardening a Rancher-managed cluster in production means layering authentication, compliance scanning, network segmentation, and secrets management on top. This unit surveys those layers and where each fits - it is a map of the territory rather than a hands-on walk, because most of these controls depend on external systems (an identity provider, a policy-enforcing CNI, a secrets backend) that a single throwaway cluster does not have.

## Authentication: Who Gets In

Out of the box Rancher uses a local admin account, which is fine for a lab but not for a team. In production, Rancher integrates with an external **identity provider** so people log in with credentials they already have, and Rancher maps their group membership to roles automatically:

- **LDAP / Active Directory** - the classic enterprise directory.
- **SAML** (Okta, ADFS, Ping Identity, Keycloak) - single sign-on for web access.
- **GitHub / GitLab** - OAuth login, popular with engineering teams.
- **OpenID Connect** - standards-based federation for anything OIDC-capable.

::details-box
---
:summary: Why this is not hands-on here
---

Every one of these requires a *second system* to authenticate against - a running LDAP directory, a configured Okta tenant, a GitHub OAuth app. A disposable single-cluster playground has none of them, and standing one up would teach you about the identity provider, not about Rancher. The Rancher side is straightforward once an IdP exists: **Users & Authentication > Auth Provider**, pick the type, enter the endpoint and credentials, and map groups to Rancher roles. The skill that transfers is the concept - authenticate against an external directory, authorize by group - not the specific provider setup.

::

## Compliance: CIS Benchmark Scanning

Rancher ships a **CIS Benchmark** scanning tool that audits a cluster against the Center for Internet Security's Kubernetes Benchmark - a published checklist of hardening controls. You install it as a Rancher app, run a scan, and get a report of which controls pass, fail, or need manual review. Scans can be scheduled so you track compliance drift over time. It is the fastest way to answer "how hardened is this cluster against a recognized standard?" without auditing by hand.

## Network Policy: Segmenting Traffic

By default, every pod in a Kubernetes cluster can talk to every other pod. **NetworkPolicy** objects let you lock that down - default-deny all traffic, then allow only the connections each workload actually needs, isolating namespaces and restricting egress to known endpoints.

::remark-box
---
kind: warning
---

There is an important catch: NetworkPolicy objects are only enforced if the cluster's **CNI plugin supports them**. This playground's K3s uses the default Flannel CNI, which does **not** enforce NetworkPolicy - you could create the objects, but nothing would honor them. Production clusters that rely on network policy run a policy-enforcing CNI such as **Calico**, **Cilium**, or Canal. That is why network segmentation is described here rather than demonstrated: teaching a control that silently does nothing would be worse than not teaching it.

::

## Secrets Management

Kubernetes Secrets are only base64-encoded in etcd by default - encoded, not encrypted. Hardening secrets means one or more of:

- **Encryption at rest** for etcd, so a stolen etcd snapshot does not leak secrets.
- **External secret stores** - **HashiCorp Vault**, AWS Secrets Manager, or Azure Key Vault - that hold the real secret and inject it at runtime, so it never lives in the cluster datastore.
- **Sealed Secrets** - encrypt a secret so the ciphertext is safe to commit to Git, which fits the GitOps workflow from the Fleet lessons.

## Putting It Together

A hardened Rancher-managed cluster layers these controls: authenticate people against a real identity provider, authorize them by role, enforce Pod Security Standards on workloads (which you did hands-on in the previous unit), segment traffic with a policy-enforcing CNI, scan against the CIS Benchmark to catch drift, and keep secrets out of plain etcd. No single control is sufficient alone; security is the sum of the layers.
