## 0.0.1 (Unreleased)

BREAKING CHANGES:

* `size` is a catalog machine tier (`R5`–`R200`), not `s`/`m`/`l`. CPU and memory are derived from the name. `nodes[].tier` is required; `nodes[].resources` no longer accepts `cpu` or `memory`.

FEATURES:

* Managed PostgreSQL cluster with catalog size presets and database users.
