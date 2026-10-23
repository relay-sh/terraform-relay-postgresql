# terraform-relay-postgresql

Creates a Relay managed PostgreSQL cluster, the logical databases its users'
roles name, and the users. A `size`
catalog tier covers the common single-group shapes; `nodes` takes over when
you need extra storage or more than one group.

```hcl
module "billing" {
  source  = "relay-sh/postgresql/relay"
  version = "~> 0.0.1"

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
rejected. Storage can grow past the included amount via `nodes`.

Users get a generated password, exposed once in the sensitive
`generated_passwords` output and kept in state, unless `user_passwords` has an
entry for them.

Changing `name` replaces the cluster and its data. Version upgrades go through
Relay's upgrade flow; a plan that changes `engine_version` fails instead of replacing
the cluster.


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7 |
| <a name="requirement_relay"></a> [relay](#requirement\_relay) | ~> 0.0.1 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_relay"></a> [relay](#provider\_relay) | ~> 0.0.1 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [relay_postgresql_cluster.this](https://registry.terraform.io/providers/relay-sh/relay/latest/docs/resources/postgresql_cluster) | resource |
| [relay_postgresql_database.this](https://registry.terraform.io/providers/relay-sh/relay/latest/docs/resources/postgresql_database) | resource |
| [relay_postgresql_user.this](https://registry.terraform.io/providers/relay-sh/relay/latest/docs/resources/postgresql_user) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_name"></a> [name](#input\_name) | Cluster name, unique in the workspace. Changing it replaces the cluster. | `string` | n/a | yes |
| <a name="input_workspace_id"></a> [workspace\_id](#input\_workspace\_id) | Workspace the cluster belongs to. | `string` | n/a | yes |
| <a name="input_cloud"></a> [cloud](#input\_cloud) | Cloud for the primary group when using size, for example aws. | `string` | `null` | no |
| <a name="input_databases"></a> [databases](#input\_databases) | Logical databases keyed by name, created before the users. Every database named in a user's roles is created even without an entry here. | <pre>map(object({<br/>    description = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | Major PostgreSQL version. Omit it and the platform picks one. Upgrades go through Relay's upgrade flow, not this variable. | `string` | `null` | no |
| <a name="input_keep_backups_on_destroy"></a> [keep\_backups\_on\_destroy](#input\_keep\_backups\_on\_destroy) | Keep the cluster's backups when it is destroyed. | `bool` | `false` | no |
| <a name="input_node_count"></a> [node\_count](#input\_node\_count) | Nodes in the primary group when using size. | `number` | `1` | no |
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Explicit node groups keyed by group name. Each group names a catalog tier; CPU and memory are derived. A group is `electable` unless it is set to `standby`, which keeps it out of the synchronous commit path, or `read_only`, which also keeps it out of elections. Use this to set storage above the included size or add extra groups. | <pre>map(object({<br/>    count  = optional(number, 1)<br/>    cloud  = string<br/>    region = string<br/>    tier   = string<br/>    resources = object({<br/>      storage    = string<br/>      disk_type  = optional(string)<br/>      iops       = optional(number)<br/>      throughput = optional(number)<br/>    })<br/>    role = optional(string, "electable")<br/>  }))</pre> | `null` | no |
| <a name="input_parameters"></a> [parameters](#input\_parameters) | PostgreSQL settings. An empty map resets them; null leaves them unmanaged. | `map(string)` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | Region for the primary group when using size. | `string` | `null` | no |
| <a name="input_replication"></a> [replication](#input\_replication) | Commit replication for the cluster. | <pre>object({<br/>    mode                 = string<br/>    synchronous_replicas = optional(number)<br/>  })</pre> | `null` | no |
| <a name="input_size"></a> [size](#input\_size) | Catalog machine tier (R5–R200). CPU and memory come from the catalog; included storage is the default volume. Set either size or nodes. | `string` | `null` | no |
| <a name="input_timeouts"></a> [timeouts](#input\_timeouts) | Create, update and delete timeouts, for example 45m. | <pre>object({<br/>    create = optional(string)<br/>    update = optional(string)<br/>    delete = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_user_passwords"></a> [user\_passwords](#input\_user\_passwords) | Passwords keyed by username, for users that should not get a generated one. | `map(string)` | `{}` | no |
| <a name="input_users"></a> [users](#input\_users) | PostgreSQL users keyed by username. A user without an entry in user\_passwords gets a generated password. A database named in roles is created by the module. | <pre>map(object({<br/>    roles = list(object({<br/>      role     = string<br/>      database = optional(string, "")<br/>    }))<br/>    description          = optional(string)<br/>    restricted_resources = optional(list(string))<br/>    expires_at           = optional(string)<br/>    connection_limit     = optional(number)<br/>    statement_timeout    = optional(string)<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | Cluster ID. |
| <a name="output_databases"></a> [databases](#output\_databases) | Created logical database names. |
| <a name="output_endpoint"></a> [endpoint](#output\_endpoint) | Primary endpoint. |
| <a name="output_generated_passwords"></a> [generated\_passwords](#output\_generated\_passwords) | Generated passwords by username. Not recoverable from the API. |
| <a name="output_phase"></a> [phase](#output\_phase) | Cluster phase after the last apply. |
| <a name="output_private_endpoints"></a> [private\_endpoints](#output\_private\_endpoints) | Private endpoints by role. |
| <a name="output_public_endpoints"></a> [public\_endpoints](#output\_public\_endpoints) | Public endpoints by role. |
| <a name="output_usernames"></a> [usernames](#output\_usernames) | Created usernames. |
<!-- END_TF_DOCS -->
