# Course Playgrounds (Internal)

Build artifacts for the custom playgrounds used by the "Managing Kubernetes with Rancher" course. Not published - authoring/build reference only.

## Playground → live name → lessons (source of truth)

Each custom playground is defined once by a manifest in its own folder here, built once with `labctl`, and then *referenced* by name from lessons. Lessons never re-run `labctl update` - they just point `playground.name` at the live (suffixed) name below.

| Manifest folder | Live name (suffixed) | Base | Used by |
|-----------------|----------------------|------|---------|
| `k3s-workstation` | `k3s-workstation-1430c761` | `k3s` | The install lesson (`module-1/2.lesson-installing-rancher`) - workstation kubeconfig ready, but Rancher NOT installed (installing it is the exercise) |
| `rancher-k3s` | `rancher-k3s-e09b66ec` | `k3s` | All post-install lessons (Module 1 "Exploring the UI" through Module 2) and single-cluster Rancher-dependent challenges |
| `rancher-k3s-downstream` | `rancher-k3s-downstream-54528e97` | `flexbox` | Module 3 multi-cluster + Fleet lessons (import-downstream-cluster challenge; the Fleet GitOps lesson also runs here) |
| `rancher-k3s-gitea` | `rancher-k3s-gitea-6cdd37fb` | `flexbox` | Module 3 CI/CD lesson - Rancher + a self-hosted Gitea Git server for the commit-and-reconcile GitOps loop (cicd-pipeline challenge) |

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

All three machines share one `local` subnet (`172.16.0.0/24`). The two clusters are kept distinct by their K3s datastores and tokens, not by network isolation - an earlier two-subnet design was dropped because iximiuz networks are isolated L2 bridges with no routing between them, which left the downstream cluster unable to reach Rancher (the cluster agent could never connect). Rancher's `server-url` is set to `https://172.16.0.2.sslip.io:30443` so the agent manifest handed to the downstream points at a routable, name-matching address.

### Why the downstream cluster uses a fresh K3s install (not the baked `k3s-cplane`)

The baked `k3s-cplane` rootfs ships a **hardcoded K3s cluster token** (confirmed in the upstream bake recipe `playgrounds/scripts/get-k3s.sh`). Two `k3s-cplane` machines sharing that token could accidentally form one HA cluster instead of two independent ones. To guarantee the downstream is a genuinely separate cluster, `downstream-01` uses a plain `ubuntu-24-04` rootfs and installs K3s from scratch via the `init_downstream_k3s` task, giving it its own token and datastore. Traefik and ServiceLB are disabled there - the import exercise does not need them.

The downstream cluster is deliberately **not** wired into the dev-machine's kubeconfig. Registering it into Rancher through the UI is the whole point of the lesson.

### Why Rancher runs in self-signed HTTPS mode here (NOT `tls=external`)

This is the single most important difference from the single-cluster `rancher-k3s` playground, and it was found the hard way during live validation. The single-cluster playground installs Rancher with `--set tls=external` and exposes it over plain HTTP so the dashboard WebSocket rides `ws://` through the iximiuz tab. That works fine when nothing needs to *verify* Rancher's certificate. Cluster import does need exactly that, and `tls=external` breaks it:

- With `tls=external`, Rancher's read-only `cacerts` setting stays **empty**. The downstream cluster agent then has no CA to verify Rancher and crash-loops with `x509: certificate signed by unknown authority` / `Certificate chain is not complete`.
- `cacerts` is **read-only** (the settings admission webhook rejects patches), so this cannot be repaired on a running install. It has to be populated at install time, and only the self-signed mode (or a real-CA mode) does that.

So this playground installs Rancher in its **default self-signed mode** (no `tls=external`). Rancher generates its own CA, populates `cacerts` (~660 bytes of PEM), and serves HTTPS. The agent's `--insecure` registration command then verifies against that CA and connects. Confirmed end-to-end: agent `1/1 Running`, imported cluster reaches `Ready=True`.

Consequences baked into the manifest:

- **Hostname is an sslip.io name:** `--set hostname=172.16.0.2.sslip.io`. `172.16.0.2.sslip.io` resolves to `172.16.0.2`, so the name is both routable from the downstream and valid as the certificate SAN. `rancher.localhost` would not resolve from `downstream-01`.
- **Both NodePorts, HTTPS is primary:** the `rancher` service is patched to NodePort with `http` on 30080 and `https` on 30443. Self-signed Rancher force-redirects HTTP to HTTPS, so 30080 is only a redirect stub; the browser tab and the agent both use `https://172.16.0.2.sslip.io:30443`.
- **The Rancher UI tab uses `tls: true`:** `kind: http-port`, `number: 30443`, `tls: true`. The iximiuz proxy speaks HTTPS to the NodePort and, because generated tab URLs are always HTTPS, the dashboard WebSocket travels `wss://` end-to-end (the supported path, unlike the plain-HTTP `ws://` hack the single-cluster playground relies on). Students accept a one-time browser certificate warning.
- **Registration token quirk:** in this Rancher version the `clusterregistrationtoken` CR's `status.token` is empty and `status.manifestUrl` carries a literal `{token}` placeholder. The real token lives in the secret `crt-token-default-token` in the cluster's namespace. The challenge `.solution.sh` reads it from there and builds the URL as `https://172.16.0.2.sslip.io:30443/v3/import/<token>_<cluster-id>.yaml`.

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

## `rancher-k3s-gitea` - Rancher + a self-hosted Gitea Git server (CI/CD lesson)

Base: `flexbox`. Used by the Module 3 CI/CD lesson to teach the full GitOps loop with a Git server the student owns: point Fleet at a Gitea repo, then push a commit and watch Fleet reconcile the change onto the cluster.

Manifest: `rancher-k3s-gitea/manifest.yaml`.

### Topology (3 VMs, one shared network)

| Machine | Address | Rootfs | Role |
|---------|---------|--------|------|
| `dev-machine` | `172.16.0.5` | `k3s-dev-machine` | Workstation: kubectl + helm + git, kubeconfig -> Rancher (local) cluster. Where GitRepos are created and commits are pushed. |
| `rancher-server` | `172.16.0.2` | `k3s-cplane` | Single-node K3s running Rancher (self-signed) and its bundled Fleet. |
| `gitea` | `172.16.0.4` | `docker` | Runs Gitea as a container on port 3000, seeded with a `sample-app` repo. |

No downstream cluster: the CI/CD loop deploys to the local cluster via `fleet-local`, so a second cluster is not needed. Machine names resolve as hostnames, so the cluster and workstation reach Gitea at `http://gitea:3000`.

### Why Gitea runs on its own machine (not a pod in the cluster)

Co-locating the Git server on the very cluster it configures is a bootstrapping anti-pattern: if the cluster has a bad day you lose the source of truth you need to recover it. A separate, independent Git server is the production-faithful shape, so Gitea gets its own VM here.

### How Gitea is provisioned

The `init_gitea` task (on the `gitea` machine) runs Gitea as a container with `INSTALL_LOCK=true` (no setup wizard), waits for its API, then uses the Gitea API to:

1. create a `student` admin user (password `student`),
2. create a public `sample-app` repo on branch `main`,
3. seed it with `manifests/web.yaml` (a simple nginx Deployment).

Fleet then points a GitRepo at `http://gitea:3000/student/sample-app`, branch `main`, path `manifests`. Pushing a change to that file (for example, bumping `replicas`) is what the student commits to trigger a reconcile.

### Rancher install

Identical self-signed recipe as `rancher-k3s-downstream` (cert-manager, then Rancher with `hostname=172.16.0.2.sslip.io`, both NodePorts 30080/30443, `server-url=https://172.16.0.2.sslip.io:30443`, Rancher UI tab `tls: true` on 30443). Fleet ships with Rancher, so nothing extra is installed for GitOps.

### Build / register with labctl

```bash
PLAYGROUND=$(labctl playground create rancher-k3s-gitea --base flexbox -q)
echo "$PLAYGROUND"   # e.g. rancher-k3s-gitea-ab12cd34
labctl playground update "$PLAYGROUND" -f rancher-k3s-gitea/manifest.yaml
labctl playground start "$PLAYGROUND"
labctl playground tasks "$PLAYGROUND"   # watch init_gitea, init_cert_manager, init_rancher
```

### Caveats

- **Resource budget:** ~4 vCPU / ~7 GiB across 3 VMs (Rancher 2C/4G dominates). Fits the paid tier comfortably; not intended for free tier (Rancher would be starved).
- Gitea image pinned to `gitea/gitea:1.22` - bump deliberately.
- The seed uses HTTP basic auth (`student:student`) against the Gitea API; fine for a lab, not a production credential pattern.

## Roadmap: baked OCI rootfs image (optimization)

Once the course content is validated and stable, graduate the `rancher-k3s` rootfs from "base + init task" to a **baked OCI image** with Rancher's images pre-pulled and its manifests/Helm state pre-applied, so post-install lessons boot in seconds instead of reinstalling Rancher each time.

- Build a bootable Linux rootfs image (NOT a regular app container) from a Dockerfile, push to `ghcr.io`.
- Point the manifest's `drives.source` at `oci://ghcr.io/<org>/rancher-k3s:vX` instead of the `k3s-*` base sources. The lesson content does not change - only the manifest's drive source.
- Pin the Rancher / cert-manager / K3s versions and rebuild deliberately.
- Trigger: do this after content is frozen (to avoid re-baking on every content fix), or sooner if init-task boot time proves intolerable in testing.
