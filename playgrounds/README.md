# Course Playgrounds (Internal)

Build artifacts for the custom playgrounds used by the "Managing Kubernetes with Rancher" course. Not published - authoring/build reference only.

## Playground → live name → lessons (source of truth)

Each custom playground is defined once by a manifest in its own folder here, built once with `labctl`, and then *referenced* by name from lessons. Lessons never re-run `labctl update` - they just point `playground.name` at the live (suffixed) name below.

| Manifest folder | Live name (suffixed) | Base | Used by |
|-----------------|----------------------|------|---------|
| `k3s-workstation` | `k3s-workstation-1430c761` | `k3s` | The install lesson (`module-1/2.lesson-installing-rancher`) - workstation kubeconfig ready, but Rancher NOT installed (installing it is the exercise) |
| `rancher-k3s` | `rancher-k3s-e09b66ec` | `k3s` | All post-install lessons (Module 1 "Exploring the UI" onward) and Rancher-dependent challenges |

> Both playgrounds pre-configure the `dev-machine` workstation's kubeconfig so the student uses plain `kubectl`/`helm` from their workstation and never touches the control plane. The difference is only whether Rancher is pre-installed: `k3s-workstation` = no (install lesson), `rancher-k3s` = yes (everything after).

## `rancher-k3s` - K3s with Rancher pre-installed

Base: `k3s` (multi-node, ships Helm + Traefik + ServiceLB). Two init tasks install cert-manager and then Rancher (behind Traefik), so post-install lessons boot into a ready Rancher environment.

Manifest: `rancher-k3s/manifest.yaml`.

### Build / register with labctl

A custom playground is always overrides on top of a base, registered via `labctl`. The platform appends a unique suffix to the name - use that suffixed name everywhere afterward (including each post-install lesson's `playground.name`).

```bash
# 1. Create the custom playground from the k3s base (prints a suffixed name).
PLAYGROUND=$(labctl playground create rancher-k3s --base k3s -q)
echo "$PLAYGROUND"   # e.g. rancher-k3s-ab12cd34

# 2. Apply our manifest. `update` expects a COMPLETE manifest; if labctl
#    rejects ours, dump the effective one, merge our initTasks/tabs into it,
#    then re-apply:
#       labctl playground manifest "$PLAYGROUND" > effective.yaml
labctl playground update "$PLAYGROUND" -f rancher-k3s/manifest.yaml

# 3. Start it and watch the init tasks provision cert-manager + Rancher.
labctl playground start "$PLAYGROUND"
labctl playground tasks "$PLAYGROUND"     # watch init_cert_manager, init_rancher

# 4. Once verified, put the suffixed name into each post-install lesson's
#    `playground.name`. Tear down test instances with:
labctl playground destroy <play-id>
```

### Caveats

- Free-tier accounts can hold only ONE custom playground at a time; paid plans lift this.
- This is init-task provisioning: Rancher reinstalls on the loading screen each boot (a few minutes). That is the accepted tradeoff for now - see the roadmap below.
- Verify `--set ingress.ingressClassName=traefik` matches the current Rancher chart before relying on it (checked against the live playground).

## Roadmap: baked OCI rootfs image (optimization)

Once the course content is validated and stable, graduate the `rancher-k3s` rootfs from "base + init task" to a **baked OCI image** with Rancher's images pre-pulled and its manifests/Helm state pre-applied, so post-install lessons boot in seconds instead of reinstalling Rancher each time.

- Build a bootable Linux rootfs image (NOT a regular app container) from a Dockerfile, push to `ghcr.io`.
- Point the manifest's `drives.source` at `oci://ghcr.io/<org>/rancher-k3s:vX` instead of the `k3s-*` base sources. The lesson content does not change - only the manifest's drive source.
- Pin the Rancher / cert-manager / K3s versions and rebuild deliberately.
- Trigger: do this after content is frozen (to avoid re-baking on every content fix), or sooner if init-task boot time proves intolerable in testing.
