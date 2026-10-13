## 0.0.1 (Unreleased)

BREAKING CHANGES:

* The module provisions `relay_postgresql_cluster` / `relay_postgresql_user`.
* `size` is a catalog machine tier (`R5`–`R200`), not `s`/`m`/`l`. CPU and memory are derived from the name.
* `nodes` is a map of groups with required `tier`. Storage stays a customer choice; `cpu` and `memory` are not inputs.
* Every group in `nodes` requires `cloud` and `region`, matching the provider.

FEATURES:

* Managed PostgreSQL cluster with catalog size presets and database users.
