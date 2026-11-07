# terraform-relay-postgresql

Creates a Relay managed PostgreSQL cluster, the logical databases its users'
roles name, and the users. A `size`
catalog tier covers the common single-group shapes; `nodes` takes over when
you need more than one group.

```hcl
module "billing" {
  source  = "relay-sh/postgresql/relay"
  version = "~> 0.1.0"

  workspace_id = module.workspace.workspace_id
  name         = "billing"
  engine_version = "18"
  size           = "R30"
  cloud          = "aws"
  region       = "us-east-1"

  users = {
    app = { roles = [{ role = "readWrite", database = "billing" }] }
  }
}
```

| Size | CPU  | Memory | Included storage |
| ---- | ---- | ------ | ---------------- |
| R5   | 500m | 1Gi    | 5Gi              |
| R10  | 1    | 2Gi    | 10Gi             |
| R20  | 2    | 4Gi    | 20Gi             |
| R30  | 2    | 8Gi    | 40Gi             |
| R40  | 4    | 16Gi   | 80Gi             |
| R50  | 8    | 32Gi   | 160Gi            |
| R60  | 16   | 64Gi   | 320Gi            |
| R80  | 32   | 128Gi  | 750Gi            |
| R100 | 48   | 192Gi  | 1000Gi           |
| R200 | 64   | 256Gi  | 1500Gi           |

CPU and memory are derived from `size` / `nodes.*.tier`. An unknown name is
rejected. Storage is one size for every node, since every node holds the same
data: the included storage of `size` (or of the largest tier in `nodes`) unless
`storage_size` says otherwise. It grows on its own with `storage_autoscale`, up
to its `max_storage`. Disk type, IOPS and throughput stay per group.

A group in `nodes` can autoscale its compute: `autoscaling` moves it one tier
at a time between `min_tier` and `max_tier`, and the node count never changes.
Without `rules` the Relay default policy applies. `tier` stays the configured
value, so a move never shows as a plan diff; the cluster's
`nodes["<group>"].current_tier` reports the tier the group runs at. This needs
provider 0.1.1 or later, the `compute_autoscale` feature and a paid plan.

```hcl
nodes = {
  primary = {
    cloud  = "aws"
    region = "us-east-1"
    tier   = "R30"
    autoscaling = {
      enabled  = true
      min_tier = "R20"
      max_tier = "R50"
      rules    = [{ metric = "cpu", scale_up_above = 75, scale_down_below = 30 }]
    }
  }
}
```

Users get a generated password, exposed once in the sensitive
`generated_passwords` output and kept in state, unless `user_passwords` has an
entry for them.

A user can list `connections`, one per database, and the module creates a
Relay connection for each, signed in as that user. The platform supplies the
address and credential, so no secret reaches Terraform. The database must be one
of the user's role databases; a user with a role that names no database (for
example `admin`) can use any database of the module. The name defaults to
`<cluster>-<user>-<database>` with `_` turned into `-`. Connections are keyed
`<user>/<database>` in the `connections` output. This needs provider 0.0.14 or
later.

```hcl
users = {
  app = {
    roles       = [{ role = "readWrite", database = "billing" }]
    connections = [{ database = "billing", audit_enabled = true }]
  }
}
```

Backups follow the platform default schedule unless `backup_schedule` is set.
Removing it later resets the cluster to that default; it does not turn backups
off. Every enabled tier is rendered into the cluster's backup crons and
retention counts; the weekly tier takes the full backup and the daily tier the
incremental one.

Changing `name` replaces the cluster and its data. Version upgrades go through
Relay's upgrade flow; a plan that changes `engine_version` fails instead of replacing
the cluster.


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7 |
| <a name="requirement_relay"></a> [relay](#requirement\_relay) | >= 0.0.1, < 0.2.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_relay"></a> [relay](#provider\_relay) | >= 0.0.1, < 0.2.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [relay_backup_schedule.this](https://registry.terraform.io/providers/relay-sh/relay/latest/docs/resources/backup_schedule) | resource |
| [relay_connection.this](https://registry.terraform.io/providers/relay-sh/relay/latest/docs/resources/connection) | resource |
| [relay_postgresql_cluster.this](https://registry.terraform.io/providers/relay-sh/relay/latest/docs/resources/postgresql_cluster) | resource |
| [relay_postgresql_database.this](https://registry.terraform.io/providers/relay-sh/relay/latest/docs/resources/postgresql_database) | resource |
| [relay_postgresql_user.this](https://registry.terraform.io/providers/relay-sh/relay/latest/docs/resources/postgresql_user) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_name"></a> [name](#input\_name) | Cluster name, unique in the workspace. Changing it replaces the cluster. | `string` | n/a | yes |
| <a name="input_workspace_id"></a> [workspace\_id](#input\_workspace\_id) | Workspace the cluster belongs to. | `string` | n/a | yes |
| <a name="input_backup_schedule"></a> [backup\_schedule](#input\_backup\_schedule) | Backup schedule for the cluster. Null keeps the platform default; removing it resets the cluster to that default. Set either tiers or max\_backups. Every enabled tier is rendered into the backup crons; the weekly tier takes the full backup and the daily tier the incremental one. | <pre>object({<br/>    snapshot_time = optional(object({<br/>      hour   = number<br/>      minute = number<br/>    }))<br/>    tiers = optional(list(object({<br/>      frequency       = string<br/>      interval        = number<br/>      retention_value = number<br/>      retention_unit  = optional(string)<br/>      enabled         = optional(bool)<br/>    })))<br/>    max_backups      = optional(number)<br/>    pitr_window_days = optional(number)<br/>  })</pre> | `null` | no |
| <a name="input_cloud"></a> [cloud](#input\_cloud) | Cloud for the primary group when using size, for example aws. | `string` | `null` | no |
| <a name="input_databases"></a> [databases](#input\_databases) | Logical databases keyed by name, created before the users. Every database named in a user's roles is created even without an entry here. | <pre>map(object({<br/>    description = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_default_connections"></a> [default\_connections](#input\_default\_connections) | Relay-managed read-only, read-write and admin users, each with a Relay connection. Null creates all three on create and keeps the current value afterwards; a role omitted inside the object does the same. Turning a role off on an existing cluster deletes its connection and user. | <pre>object({<br/>    readonly  = optional(bool)<br/>    readwrite = optional(bool)<br/>    admin     = optional(bool)<br/>  })</pre> | `null` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | While true, the platform refuses to delete the cluster, and a destroy or a replacement fails before deleting it. | `bool` | `false` | no |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | Major PostgreSQL version. Omit it and the platform picks one. Upgrades go through Relay's upgrade flow, not this variable. | `string` | `null` | no |
| <a name="input_keep_backups_on_destroy"></a> [keep\_backups\_on\_destroy](#input\_keep\_backups\_on\_destroy) | Keep the cluster's backups when it is destroyed. | `bool` | `false` | no |
| <a name="input_node_count"></a> [node\_count](#input\_node\_count) | Nodes in the primary group when using size. | `number` | `1` | no |
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Explicit node groups keyed by group name. Each group names a catalog tier; CPU and memory are derived. A group is `electable` unless it is set to `standby`, which keeps it out of the synchronous commit path, or `read_only`, which also keeps it out of elections. Storage is set for the whole cluster with storage\_size and storage\_autoscale. `autoscaling` moves a group one tier at a time between min\_tier and max\_tier; without rules the Relay default policy applies. | <pre>map(object({<br/>    count  = optional(number, 1)<br/>    cloud  = string<br/>    region = string<br/>    tier   = string<br/>    resources = optional(object({<br/>      disk_type  = optional(string)<br/>      iops       = optional(number)<br/>      throughput = optional(number)<br/>    }), {})<br/>    role = optional(string, "electable")<br/>    autoscaling = optional(object({<br/>      enabled  = bool<br/>      min_tier = optional(string)<br/>      max_tier = optional(string)<br/>      rules = optional(list(object({<br/>        metric           = string<br/>        scale_up_above   = number<br/>        scale_down_below = number<br/>      })))<br/>      scale_up_window            = optional(string)<br/>      scale_down_window          = optional(string)<br/>      respect_maintenance_window = optional(bool)<br/>    }))<br/>  }))</pre> | `null` | no |
| <a name="input_parameters"></a> [parameters](#input\_parameters) | PostgreSQL settings. An empty map resets them; null leaves them unmanaged. | `map(string)` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | Region for the primary group when using size. | `string` | `null` | no |
| <a name="input_replication"></a> [replication](#input\_replication) | Commit replication for the cluster. | <pre>object({<br/>    mode                 = string<br/>    synchronous_replicas = optional(number)<br/>  })</pre> | `null` | no |
| <a name="input_size"></a> [size](#input\_size) | Catalog machine tier (R5–R200). CPU and memory come from the catalog; included storage is the default volume. Set either size or nodes. | `string` | `null` | no |
| <a name="input_storage_autoscale"></a> [storage\_autoscale](#input\_storage\_autoscale) | Grows every node's volume past storage\_size, up to max\_storage, when disk usage crosses threshold\_percent. | <pre>object({<br/>    enabled           = bool<br/>    threshold_percent = optional(number)<br/>    increase_percent  = optional(number)<br/>    max_storage       = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_storage_size"></a> [storage\_size](#input\_storage\_size) | Volume size of every node in the cluster, for example 100Gi. Defaults to the included storage of size, or of the largest tier in nodes. It can grow but not shrink. | `string` | `null` | no |
| <a name="input_timeouts"></a> [timeouts](#input\_timeouts) | Create, update and delete timeouts, for example 45m. | <pre>object({<br/>    create = optional(string)<br/>    update = optional(string)<br/>    delete = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_user_passwords"></a> [user\_passwords](#input\_user\_passwords) | Passwords keyed by username, for users that should not get a generated one. | `map(string)` | `{}` | no |
| <a name="input_users"></a> [users](#input\_users) | PostgreSQL users keyed by username. A user without an entry in user\_passwords gets a generated password. A database named in roles is created by the module. connections creates one Relay connection per entry, signed in as that user on the named database, which must be one of the user's role databases (any module database for a user with a role that names none). The name defaults to <cluster>-<user>-<database> with underscores turned into hyphens. | <pre>map(object({<br/>    roles = list(object({<br/>      role     = string<br/>      database = optional(string, "")<br/>    }))<br/>    description          = optional(string)<br/>    restricted_resources = optional(list(string))<br/>    expires_at           = optional(string)<br/>    connection_limit     = optional(number)<br/>    statement_timeout    = optional(string)<br/>    connections = optional(list(object({<br/>      database            = string<br/>      name                = optional(string)<br/>      agent_pool          = optional(string, "default")<br/>      audit_enabled       = optional(bool)<br/>      redact_enabled      = optional(bool)<br/>      policy_fail_mode    = optional(string)<br/>      deletion_protection = optional(bool)<br/>    })), [])<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | Cluster ID. |
| <a name="output_connections"></a> [connections](#output\_connections) | Relay connections by "<user>/<database>": id and name. |
| <a name="output_databases"></a> [databases](#output\_databases) | Created logical database names. |
| <a name="output_endpoint"></a> [endpoint](#output\_endpoint) | Primary endpoint. |
| <a name="output_generated_passwords"></a> [generated\_passwords](#output\_generated\_passwords) | Generated passwords by username. Not recoverable from the API. |
| <a name="output_phase"></a> [phase](#output\_phase) | Cluster phase after the last apply. |
| <a name="output_private_endpoints"></a> [private\_endpoints](#output\_private\_endpoints) | Private endpoints by role. |
| <a name="output_public_endpoints"></a> [public\_endpoints](#output\_public\_endpoints) | Public endpoints by role. |
| <a name="output_usernames"></a> [usernames](#output\_usernames) | Created usernames. |
<!-- END_TF_DOCS -->
