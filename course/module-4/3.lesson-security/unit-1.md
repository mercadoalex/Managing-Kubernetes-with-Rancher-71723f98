---
kind: unit

title: Enforcing Pod Security

name: enforcing-pod-security
---

A cluster is only as safe as the workloads it lets run. By default, Kubernetes will happily schedule a container that runs as root, mounts the host filesystem, or asks for privileged access - exactly the things an attacker wants. This lesson closes that door with **Pod Security Admission**, a control built into the Kubernetes API server that rejects unsafe pods before they ever start. You drive it from the :tab{text='dev-machine' machine='dev-machine'} workstation.

::image-box
---
:src: __static__/pod-security-admission-v1.png
:alt: A pod creation request passing through the API server's Pod Security Admission controller, which checks the target namespace's enforce level and admits a compliant pod while rejecting a privileged one
:max-width: 900px
---
_Pod Security Admission checks every pod against its namespace's standard and rejects the ones that violate it._
::

## The Three Pod Security Standards

Kubernetes defines three built-in **Pod Security Standards**, from most to least permissive:

- **privileged** - no restrictions; anything goes. This is the default when you set nothing.
- **baseline** - blocks the most dangerous settings (privileged containers, host namespaces) while staying easy to adopt.
- **restricted** - the hardened profile: containers must run as non-root, drop all Linux capabilities, disallow privilege escalation, and use a seccomp profile.

You apply a standard to a **namespace** with a label, and the API server enforces it on every pod created there. This is namespace-scoped by design: you can run system components under a loose policy while holding your application namespaces to `restricted`.

::details-box
---
:summary: Pod Security Admission vs the old PodSecurityPolicy
---

If you have seen `PodSecurityPolicy` (PSP) in older material, note that it was removed in Kubernetes 1.25. Pod Security Admission is its built-in replacement: simpler (three fixed standards instead of hand-written policies), namespace-labelled, and always compiled into the API server so there is nothing to install. For rules beyond the three standards - say, "every image must come from our registry" - you reach for a policy engine like OPA Gatekeeper or Kubewarden, which the wider-security unit covers.

::

## Step 1: Create a Namespace for Your Apps

Create a namespace to hold application workloads. From the :tab{text='dev-machine' machine='dev-machine'} terminal:

```bash
kubectl create namespace secure-apps
```

At this point the namespace has no policy - it is effectively `privileged`, so an unsafe pod would run without complaint.

## Step 2: Enforce the Restricted Standard

Label the namespace so the API server enforces the `restricted` standard on every pod created in it:

```bash
kubectl label namespace secure-apps \
  pod-security.kubernetes.io/enforce=restricted
```

That single label is the whole control. Confirm it:

```bash
kubectl get namespace secure-apps --show-labels
```

::simple-task
---
:tasks: tasks
:name: verify_namespace_enforced
---
#active
Waiting for secure-apps to enforce the restricted standard...

#completed
The namespace enforces the restricted Pod Security Standard.
::

::details-box
---
:summary: enforce, audit, and warn - three ways to apply a standard
---

Each standard can be attached at three levels, and you can mix them:

- `pod-security.kubernetes.io/enforce` - **rejects** violating pods outright. This is the one with teeth.
- `pod-security.kubernetes.io/warn` - **allows** the pod but returns a warning to the user, useful for flagging issues without breaking anything.
- `pod-security.kubernetes.io/audit` - **allows** the pod and records a violation in the audit log, for after-the-fact review.

A common rollout pattern is to set `warn` and `audit` to `restricted` first, watch what would break, fix it, and only then switch `enforce` to `restricted`. Here we go straight to `enforce` because the point is to see the rejection.

::

## Step 3: Watch an Unsafe Pod Get Rejected

Now try to run a **privileged** container in that namespace - the kind of workload the restricted standard exists to stop:

```bash
kubectl -n secure-apps run rogue --image=nginx:1.27 \
  --overrides='{"spec":{"containers":[{"name":"rogue","image":"nginx:1.27","securityContext":{"privileged":true}}]}}'
```

Instead of scheduling, the API server rejects the request with a Pod Security violation, listing exactly which rules the pod broke (privileged, allowPrivilegeEscalation, missing runAsNonRoot, capabilities, and seccomp). Nothing is created - the unsafe workload never runs.

Contrast that with a compliant pod, which the same namespace accepts:

```bash
kubectl -n secure-apps run safe --image=nginx:1.27 \
  --overrides='{"spec":{"containers":[{"name":"safe","image":"nginx:1.27","securityContext":{"runAsNonRoot":true,"runAsUser":1000,"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"seccompProfile":{"type":"RuntimeDefault"}}}]}}'
```

::simple-task
---
:tasks: tasks
:name: verify_privileged_pod_rejected
---
#active
Waiting for the restricted standard to reject a privileged pod...

#completed
The restricted standard rejected the privileged pod. Your namespace is hardened.
::

::details-box
---
:summary: Setting Pod Security levels from the Rancher UI
---

Everything you just did with `kubectl` is also available in the Rancher UI. When you create or edit a namespace (or a Project), Rancher exposes the Pod Security Admission level as a dropdown, so you can set `enforce`, `warn`, and `audit` to privileged, baseline, or restricted without touching labels by hand. Rancher also ships built-in **Pod Security Admission Configuration Templates** that you can apply cluster-wide, so new namespaces inherit a secure default. The underlying mechanism is identical - Rancher is writing the same namespace labels the API server reads.

::

## You're Done

You enforced the `restricted` Pod Security Standard on a namespace and watched the API server reject a privileged pod before it could run - a real, built-in security control with no extra components. That is the foundation of workload security in Kubernetes: decide what "safe" means per namespace, and let the API server enforce it on every pod.

Pod security is one layer. The next unit surveys the rest of the security surface on a Rancher-managed cluster - authentication, compliance scanning, network policy, and secrets - and where each fits.

The challenge below asks you to harden a namespace yourself and prove an unsafe pod is turned away. Solving it records your progress.

::card
---
:challenge: challenges.rancher-enforce-pod-security-9d671d94
---
::
