---
title: Enforce the Restricted Pod Security Standard
---

Pod Security Admission turns a single namespace label into a hard rule: the API server refuses any pod that violates the standard you set. The whole task is one label and one check.

<!--more-->

## Enforce the Standard

The `secure-apps` namespace starts with no policy. Label it to enforce the `restricted` standard, which requires containers to run as non-root, drop all capabilities, disallow privilege escalation, and use a seccomp profile:

```bash
kubectl label namespace secure-apps \
  pod-security.kubernetes.io/enforce=restricted --overwrite
```

Confirm the label is set:

```bash
kubectl get namespace secure-apps --show-labels
```

## Prove an Unsafe Pod Is Rejected

Now try to run a privileged container in that namespace. The API server refuses it instead of scheduling it - a server-side dry run is enough to see the rejection without creating anything:

```bash
kubectl -n secure-apps run rogue --image=nginx:1.27 --dry-run=server \
  --overrides='{"spec":{"containers":[{"name":"rogue","image":"nginx:1.27","securityContext":{"privileged":true}}]}}'
```

The response is a Pod Security violation listing the broken rules (privileged, allowPrivilegeEscalation, runAsNonRoot, capabilities, seccompProfile). Nothing is created.

A compliant pod, by contrast, is accepted by the same namespace:

```bash
kubectl -n secure-apps run safe --image=nginx:1.27 --dry-run=server \
  --overrides='{"spec":{"containers":[{"name":"safe","image":"nginx:1.27","securityContext":{"runAsNonRoot":true,"runAsUser":1000,"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"seccompProfile":{"type":"RuntimeDefault"}}}]}}'
```

That is the whole point of the restricted standard: the namespace now runs only workloads that meet a hardened security bar, and the API server enforces it on every pod without any extra component.
