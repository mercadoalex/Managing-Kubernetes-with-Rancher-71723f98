---
title: Create a Backup and Wait for It to Complete
---

The operator and the ResourceSet are already running, so the whole task is a single `Backup` object plus the patience to let the operator finish writing the archive.

<!--more-->

## Request the Backup

A `Backup` object names the ResourceSet it should use. The `rancher-resource-set` is already present, so the spec is short:

```bash
kubectl apply -f - <<'EOF'
apiVersion: resources.cattle.io/v1
kind: Backup
metadata:
  name: rancher-state-backup
spec:
  resourceSetName: rancher-resource-set
EOF
```

The operator picks up the new object, gathers every resource the ResourceSet selects, packages them into a `tar.gz`, and writes it to the persistent volume the operator was installed with.

## Watch It Complete

The operator records progress on the `Backup` object itself. Poll its `Ready` condition and `filename`:

```bash
kubectl get backup rancher-state-backup \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status} {.status.filename}{"\n"}'
```

At first the condition reads `Unknown` while the operator works. After a short wait it becomes `True` and the `filename` field fills in with the name of the archive, something like `rancher-state-backup-<uuid>-<timestamp>.tar.gz`. That filename is the proof the archive was written - the backup is complete and the challenge is solved.

If the condition stays at `Unknown`, the usual cause is a missing or misnamed ResourceSet. Check the operator logs with `kubectl -n cattle-resources-system logs deploy/rancher-backup`; a line reading `resourcesets.resources.cattle.io "rancher-resource-set" not found` means the Backup is pointing at a ResourceSet that does not exist.
