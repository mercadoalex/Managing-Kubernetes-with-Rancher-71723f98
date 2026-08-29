# Course Playgrounds (Internal)

Build artifacts for the custom playgrounds used by the "Managing Kubernetes with Rancher" course. Not published - authoring/build reference only.

## Playground → live name → lessons (source of truth)

Each custom playground is defined once by a manifest in its own folder here, built once with `labctl`, and then *referenced* by name from lessons. Lessons never re-run `labctl update` - they just point `playground.name` at the live (suffixed) name below.

| Manifest folder | Live name (suffixed) | Base | Used by |
|-----------------|----------------------|------|---------|
| `k3s-workstation` | `k3s-workstation-1430c761` | `k3s` | The install lesson (`module-1/2.lesson-installing-rancher`) - workstation kubeconfig ready, but Rancher NOT installed (installing it is the exercise) |
| `rancher-k3s` | `rancher-k3s-e09b66ec` | `k3s` | All post-install lessons (Module 1 "Exploring the UI" through Module 2) and single-cluster Rancher-dependent challenges |
| `rancher-k3s-downstream` | _(TBD - suffix assigned on create)_ | `flexbox` | Module 3 advanced lessons that need a second, importable cluster (multi-cluster management, and the import-downstream-cluster challenge) |

> All three playgrounds pre-configure the `dev-machine` workstation's kubeconfig so the student uses plain `kubectl`/`helm` from their workstation and never touches a control plane. The differences: `k3s-workstation` has no Rancher (installing it is the exercise); `rancher-k3s` has Rancher pre-installed on a single cluster; `rancher-k3s-downstream` has Rancher pre-installed on an upstream cluster PLUS a separate empty downstream cluster to import.

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

## `rancher-k3s-downstream` - two clusters (Rancher upstream + importable downstream)

Base: `flexbox` (the only base that accepts an arbitrary machine set - the fixed-machine `k3s` base cannot be extended with a fourth machine, so a second cluster is impossible on it). Used by the Module 3 advanced lessons that need a real downstream cluster to import and manage.

Manifest: `rancher-k3s-downstream/manifest.yaml`.

### Topology

| Machine | Address | Rootfs | Role |
|---------|---------|--------|------|
| `dev-machine` | `172.16.0.5` | `k3s-dev-machine` | Student workstation (kubectl + helm). Kubeconfig points at the UPSTREAM cluster only. |
| `rancher-server` | `172.16.0.2` | `k3s-cplane` | Upstream / management cluster. Single-node K3s; Rancher installed on top by init tasks. |
| `downstream-01` | `172.16.0.3` | `ubuntu-24-04` | Downstream / user cluster. K3s installed FRESH by an init task, empty, waiting to be imported. |

All three machines share one `local` subnet (`172.16.0.0/24`). The two clusters are kept distinct by their K3s datastores and tokens, not by network isolation - an earlier two-subnet design was dropped because iximiuz networks are isolated L2 bridges with no routing between them, which left the downstream cluster unable to reach Rancher (the cluster agent could never connect). Rancher's `server-url` is set to `http://172.16.0.2:30080` so the agent manifest handed to the downstream points at a routable address.

### Why the downstream cluster uses a fresh K3s install (not the baked `k3s-cplane`)

The baked `k3s-cplane` rootfs ships a **hardcoded K3s cluster token** (confirmed in the upstream bake recipe `playgrounds/scripts/get-k3s.sh`). Two `k3s-cplane` machines sharing that token could accidentally form one HA cluster instead of two independent ones. To guarantee the downstream is a genuinely separate cluster, `downstream-01` uses a plain `ubuntu-24-04` rootfs and installs K3s from scratch via the `init_downstream_k3s` task, giving it its own token and datastore. Traefik and ServiceLB are disabled there - the import exercise does not need them.

The downstream cluster is deliberately **not** wired into the dev-machine's kubeconfig. Registering it into Rancher through the UI is the whole point of the lesson.

### Build / register with labctl

```bash
# 1. Create from the flexbox base (prints a suffixed name).
PLAYGROUND=$(labctl playground create rancher-k3s-downstream --base flexbox -q)
echo "$PLAYGROUND"   # e.g. rancher-k3s-downstream-ab12cd34

# 2. Apply our manifest (dump the effective one and merge if labctl rejects it).
labctl playground update "$PLAYGROUND" -f rancher-k3s-downstream/manifest.yaml

# 3. Start it and watch the init tasks: init_downstream_k3s provisions the
#    downstream cluster; init_cert_manager + init_rancher provision Rancher.
labctl playground start "$PLAYGROUND"
labctl playground tasks "$PLAYGROUND"

# 4. Put the suffixed name into the Module 3 lessons' and the
#    import-downstream-cluster challenge's `playground.name`.
labctl playground destroy <play-id>   # tear down test instances
```

### Caveats

- **Resource budget:** Rancher wants ~2 vCPU / 4 GiB on its own. With the downstream node (~1 vCPU / 2 GiB) and the workstation (~1 vCPU / 1 GiB), the playground totals ~4 vCPU / ~7 GiB. The free tier caps a single VM at 2 vCPU / 4 GiB and a playground at 5 vCPU / 8 GiB, so `rancher-server` sits right at the per-VM ceiling and the whole topology is realistically a **paid-plan** playground. Requests above budget are scaled down proportionally, which would starve Rancher - so do not run this on free tier expecting a healthy Rancher.
- Init-task provisioning means both clusters build on the loading screen each boot (Rancher install dominates the wait). Same baked-image optimization path as `rancher-k3s` applies (see roadmap).
- `flexbox` requires the full machine set in the manifest (no inherited machines), which is why every machine, network, and tab is spelled out explicitly.

## Roadmap: baked OCI rootfs image (optimization)

Once the course content is validated and stable, graduate the `rancher-k3s` rootfs from "base + init task" to a **baked OCI image** with Rancher's images pre-pulled and its manifests/Helm state pre-applied, so post-install lessons boot in seconds instead of reinstalling Rancher each time.

- Build a bootable Linux rootfs image (NOT a regular app container) from a Dockerfile, push to `ghcr.io`.
- Point the manifest's `drives.source` at `oci://ghcr.io/<org>/rancher-k3s:vX` instead of the `k3s-*` base sources. The lesson content does not change - only the manifest's drive source.
- Pin the Rancher / cert-manager / K3s versions and rebuild deliberately.
- Trigger: do this after content is frozen (to avoid re-baking on every content fix), or sooner if init-task boot time proves intolerable in testing.
