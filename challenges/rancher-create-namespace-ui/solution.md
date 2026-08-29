---
title: Create the Namespace in the Cluster Explorer
---

This one is meant to be done by clicking, not typing - the whole point is to practice driving Rancher's UI.

<!--more-->

## Create it in the UI

1. Open the **Rancher** tab and log in.
2. In the global navigation on the left, click the **local** cluster. The sidebar switches to the Cluster Explorer.
3. Under the **Cluster** section, open **Projects/Namespaces**.
4. Click **Create Namespace** (top right).
5. Enter the name `rancher-explorer` and click **Create**.

That's it. The namespace appears in the list immediately, and the challenge checks turn green - one confirming the namespace exists, the other confirming it came through Rancher rather than the command line.

## Why not just use kubectl?

You could create the namespace with `kubectl create namespace rancher-explorer`, and the first check would pass - but the second would fail. Rancher stamps namespaces it creates through the UI with a `field.cattle.io/creatorId` annotation, which a plain `kubectl create` does not set. The challenge looks for that marker precisely to make sure you exercised the UI, which is the skill this lesson is about.
