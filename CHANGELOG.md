## 0.1.1 (November 5, 2026)

ENHANCEMENTS:

* `deletion_protection` makes the platform refuse to delete the cluster ([#20](https://github.com/relay-sh/terraform-relay-postgresql/pull/20))

## 0.1.0 (November 4, 2026)

BREAKING CHANGES:

* Needs provider 0.1.0. Storage is cluster-wide: `nodes.*.resources.storage` and `nodes.*.resources.storage_autoscale` are removed. Set the size with the new `storage_size` (default: the included storage of `size`, or of the largest tier in `nodes`) and autoscaling with `storage_autoscale`, which now applies with `nodes` too. `nodes.*.resources` is optional and holds `disk_type`, `iops` and `throughput`. The provider upgrades existing state on its own

## 0.0.3 (November 4, 2026)

ENHANCEMENTS:

* `users[*].connections` creates a Relay connection per user and database through `relay_connection`, exposed in the `connections` output. It needs provider 0.0.14 or later ([#17](https://github.com/relay-sh/terraform-relay-postgresql/pull/17))

## 0.0.2 (November 3, 2026)

ENHANCEMENTS:

* `default_connections` passes the Relay-managed read-only, read-write and admin users and connections to the cluster; null creates all three on create and keeps the current value afterwards. It needs provider 0.0.10 or later ([#15](https://github.com/relay-sh/terraform-relay-postgresql/pull/15))

## 0.0.1 (October 28, 2026)

BREAKING CHANGES:

* The module provisions `relay_postgresql_cluster` / `relay_postgresql_user`.
* `size` is a catalog machine tier (`R5`–`R200`), not `s`/`m`/`l`. CPU and memory are derived from the name.
* `nodes` is a map of groups with required `tier`. Storage stays a customer choice; `cpu` and `memory` are not inputs.
* Every group in `nodes` requires `cloud` and `region`, matching the provider.

FEATURES:

* Managed PostgreSQL cluster with catalog size presets and database users.
* `storage_autoscale` grows volumes past their storage, for the size preset or per group in `nodes`.
* Creates every logical database named in `users[*].roles[*].database`, plus any in `databases`, before the users.
* `backup_schedule` manages the cluster's backup schedule through `relay_backup_schedule`; null keeps the platform default.
