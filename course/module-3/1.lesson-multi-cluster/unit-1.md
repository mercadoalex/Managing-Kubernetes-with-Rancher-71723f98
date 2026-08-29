---
kind: unit

title: Importing a Downstream Cluster

name: importing-a-downstream-cluster
---

Up to now you have worked with a single cluster - the one Rancher itself runs on. Rancher's real job, though, is to manage *many* clusters from one place. This lesson introduces that model by registering a second, independent Kubernetes cluster into Rancher and watching it come under management.

This playground gives you two separate clusters:

- **The upstream (management) cluster** runs Rancher. This is the `local` cluster you have seen in the UI. It lives on the `rancher-server` machine.
- **The downstream (user) cluster** is a fresh, empty K3s cluster on the `downstream-01` machine. It has never met Rancher. Bringing it under management is your task.

You drive everything from the :tab{text='dev-machine' machine='dev-machine'} workstation, open the dashboard with the :tab{text='Rancher' name='Rancher'} tab, and run the registration command on the downstream cluster through the :tab{text='downstream-01' machine='downstream-01'} terminal.

::image-box
---
:src: __static__/rancher-multi-cluster-topology-v1.png
:alt: One management cluster running Rancher and a separate downstream K3s cluster on the same network, with the downstream cluster agent dialing back to Rancher over an outbound tunnel
:max-width: 900px
---
::

::details-box
---
:summary: Why keep Rancher and the downstream cluster separate?
---

Rancher's own architecture guidance is that the cluster running Rancher should be separate from the clusters it manages. The management cluster holds Rancher's state and the record of every cluster, user, and permission; the downstream clusters run your actual applications. Keeping them apart means a busy or failing workload cluster cannot take Rancher down with it, and it mirrors how real deployments are laid out. That is exactly the shape of this playground: Rancher on one cluster, your workloads destined for another.

::

## Step 1: Confirm You Start With Only the Local Cluster

In the :tab{text='dev-machine' machine='dev-machine'} terminal, list the clusters Rancher knows about:

```bash
kubectl get clusters.management.cattle.io
```

You should see a single entry named `local` - the cluster Rancher runs on. There is no downstream cluster yet, because we have not told Rancher about it.

::details-box
---
:summary: What is a management Cluster object?
---

Rancher represents every cluster it manages as a `clusters.management.cattle.io` custom resource on the upstream cluster. The built-in one is always named `local`. When you import or provision another cluster, Rancher creates a new object here to track it - its state, its agent connection, and its access details. Listing these objects is a quick, UI-free way to see Rancher's fleet from the command line, and it is exactly what this lesson's checks look at.

::

## Step 2: Start the Import in the Rancher UI

Open the :tab{text='Rancher' name='Rancher'} tab and log in. Rancher here uses a self-signed certificate, so your browser shows a certificate warning the first time you open the tab - accept it to continue. From the home screen, click **Import Existing** (under **Cluster Management > Clusters**, use **Import Existing**).

::details-box
---
:summary: Why the browser warns about the certificate
---

This playground runs Rancher with a self-signed certificate - the same `ingress.tls.source=rancher` mode covered in the installation lesson. Because the certificate is signed by Rancher's own CA rather than a public authority, your browser does not trust it automatically and shows a warning. Accepting it is safe in this controlled lab. The same self-signed CA is what the downstream cluster's agent must trust to complete the import, which is why the registration command you use in the next step is the insecure variant.

::

Choose the **Generic** cluster type (this covers any standard Kubernetes cluster, which is what our downstream K3s is), give the cluster a name such as `downstream`, and click **Create**.

Rancher then shows you a **registration command** - a `kubectl apply` of a manifest served from the Rancher server. That manifest installs the Rancher **cluster agent** into the target cluster, which dials back to Rancher and completes the registration.

<!-- [image placeholder] rancher-import-registration-command.png - the registration command Rancher displays after creating a Generic import -->

::details-box
---
:summary: What does the registration command install?
---

The command applies a manifest that creates the `cattle-system` namespace on the downstream cluster and deploys the **cluster agent** (and a node agent) into it. The cluster agent opens an outbound tunnel to the Rancher server, so Rancher never needs a direct inbound route to the downstream API server - the agent calls home. Once the tunnel is up, Rancher can read and act on the downstream cluster through it. This is why an imported cluster works even when it sits behind a firewall or on a separate network, as our downstream cluster does here.

::

## Step 3: Run the Registration Command on the Downstream Cluster

Copy the registration command Rancher displayed. Then switch to the :tab{text='downstream-01' machine='downstream-01'} terminal - this is the shell *on the downstream cluster itself* - and run it there.

Because the downstream node uses K3s, its `kubectl` is already configured for its own cluster, so the `kubectl apply` from Rancher lands on the right place.

If Rancher's command is a piped `curl ... | kubectl apply -f -`, run it as-is. If you copied a self-signed variant, use the `--insecure` form Rancher offers.

::details-box
---
:summary: Which terminal am I in, and which cluster does it talk to?
---

This is the one place in the course where you deliberately work *on* a cluster node rather than from the workstation. The :tab{text='downstream-01' machine='downstream-01'} terminal is a shell on the downstream cluster's node, and its `kubectl` targets the downstream cluster. The :tab{text='dev-machine' machine='dev-machine'} terminal, by contrast, targets the upstream Rancher cluster. Keep the two straight: you apply the agent manifest on **downstream-01**, and you verify the result from **dev-machine** (or in the Rancher UI).

::

## Step 4: Watch the Cluster Become Active

Back in the Rancher UI, the new `downstream` cluster moves from **Pending** to **Active** as its agent connects and reports in. This can take a minute or two while the agent pods start.

Confirm it from the :tab{text='dev-machine' machine='dev-machine'} terminal as well - Rancher created a management object for the imported cluster on the upstream:

```bash
kubectl get clusters.management.cattle.io
```

You now see a second entry alongside `local`.

::simple-task
---
:tasks: tasks
:name: verify_downstream_imported
---
#active
Waiting for an imported cluster to appear in Rancher...

#completed
Rancher has registered the downstream cluster.
::

::simple-task
---
:tasks: tasks
:name: verify_downstream_active
---
#active
Waiting for the imported cluster to reach the Ready state...

#completed
The downstream cluster is Active and managed by Rancher.
::

## You're Done

You registered a separate, independent cluster into Rancher and watched it come under management through the cluster agent. From here, Rancher can deploy to, monitor, and control the downstream cluster exactly as it does the local one - and you can switch between them from the cluster picker in the UI.

The challenge below has you do the import on your own and confirm the cluster reaches the Active state. Solving it records your progress.

::card
---
:challenge: challenges.rancher-import-downstream-cluster-adec5893
---
::
