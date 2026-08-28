---
kind: unit

title: Backup, Restore, and Disaster Recovery

name: backup-restore-disaster-recovery
---

This unit covers protecting the Rancher management state and recovering from failure.

<!-- [image] rancher-backup-flow.png - Diagram of the rancher-backup operator writing snapshots to S3 -->

## Backup and Restore

Rancher provides a backup operator (`rancher-backup`) that takes snapshots of the Rancher management state. This includes:

- Cluster registrations and configurations
- User accounts and RBAC bindings
- Catalogs and installed apps metadata
- Fleet GitRepo definitions and cluster groups

Backups are stored as tar archives in an S3-compatible bucket or a persistent volume. You schedule automatic backups and retain them based on a configurable policy.

### Restoring from Backup

Restore is performed by deploying the backup operator on a fresh Rancher installation and pointing it at an existing backup. This recovers the full management plane state, including downstream cluster connections (though the downstream clusters themselves must still be reachable).

## Disaster Recovery

A complete disaster recovery plan for Rancher includes:

- Regular automated backups stored off-cluster (S3)
- Documented restore procedure tested periodically
- etcd snapshots for the local K3s cluster (separate from Rancher backups)
- DNS failover if the Rancher server hostname needs to point to a new installation
