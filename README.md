# terraform-relay-database

Creates a Relay managed database cluster and its engine users. A `size` preset
covers the common single-group shapes; `nodes` takes over for anything else.

```hcl
module "billing" {
  source  = "relay-sh/database/relay"
  version = "~> 0.0.1"

  workspace_id   = module.workspace.workspace_id
  name           = "billing"
  engine         = "postgresql"
  engine_version = "17"
  size           = "m"
  cloud_provider = "aws"
  region         = "us-east-1"

  users = {
    app = { roles = [{ role = "readWrite", db = "billing" }] }
  }
}
```

| Size | CPU  | Memory | Storage |
| ---- | ---- | ------ | ------- |
| s    | 500m | 1Gi    | 10Gi    |
| m    | 2    | 8Gi    | 50Gi    |
| l    | 4    | 16Gi   | 200Gi   |

Users get a generated password, exposed once in the sensitive
`generated_passwords` output and kept in state, unless `user_passwords` has an
entry for them.

Changing `name`, `engine` or `default_connections` replaces the cluster and its
data. Version upgrades go through Relay's upgrade flow; a plan that changes
`engine_version` fails instead of replacing the cluster.

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
| [relay_database.this](https://registry.terraform.io/providers/relay-sh/relay/latest/docs/resources/database) | resource |
| [relay_database_user.this](https://registry.terraform.io/providers/relay-sh/relay/latest/docs/resources/database_user) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_engine"></a> [engine](#input\_engine) | postgresql or mongodb. | `string` | n/a | yes |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | Engine version. Upgrades go through Relay's upgrade flow, not this variable. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Cluster name, unique in the workspace. Changing it replaces the cluster. | `string` | n/a | yes |
| <a name="input_workspace_id"></a> [workspace\_id](#input\_workspace\_id) | Workspace the cluster belongs to. | `string` | n/a | yes |
| <a name="input_backups_enabled"></a> [backups\_enabled](#input\_backups\_enabled) | Scheduled backups. Null keeps the platform default. | `bool` | `null` | no |
| <a name="input_cloud_provider"></a> [cloud\_provider](#input\_cloud\_provider) | Infrastructure provider for the data group when using size. | `string` | `null` | no |
| <a name="input_default_connections"></a> [default\_connections](#input\_default\_connections) | Relay-managed users and connections seeded when the cluster is ready. Changing it replaces the cluster. | <pre>object({<br/>    readonly  = optional(bool, false)<br/>    readwrite = optional(bool, false)<br/>    admin     = optional(bool, false)<br/>  })</pre> | `null` | no |
| <a name="input_keep_backups_on_destroy"></a> [keep\_backups\_on\_destroy](#input\_keep\_backups\_on\_destroy) | Keep the cluster's backups when it is destroyed. | `bool` | `false` | no |
| <a name="input_node_count"></a> [node\_count](#input\_node\_count) | Nodes in the data group when using size. | `number` | `1` | no |
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Explicit node groups, for shapes the presets do not cover. | <pre>list(object({<br/>    role     = string<br/>    count    = number<br/>    provider = string<br/>    region   = string<br/>    resources = object({<br/>      cpu           = string<br/>      memory        = string<br/>      storage       = string<br/>      storage_class = optional(string)<br/>      iops          = optional(number)<br/>      throughput    = optional(number)<br/>    })<br/>    tags = optional(map(string))<br/>  }))</pre> | `null` | no |
| <a name="input_params"></a> [params](#input\_params) | Engine parameters. | `map(string)` | `null` | no |
| <a name="input_postgresql_parameters"></a> [postgresql\_parameters](#input\_postgresql\_parameters) | PostgreSQL settings. An empty map resets them; null leaves them unmanaged. | `map(string)` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | Region for the data group when using size. | `string` | `null` | no |
| <a name="input_replication"></a> [replication](#input\_replication) | PostgreSQL replication tuning. | <pre>object({<br/>    mode                 = string<br/>    synchronous_replicas = optional(number)<br/>  })</pre> | `null` | no |
| <a name="input_size"></a> [size](#input\_size) | Preset node shape: s, m or l. Set either size or nodes. | `string` | `null` | no |
| <a name="input_timeouts"></a> [timeouts](#input\_timeouts) | Create, update and delete timeouts, for example 45m. | <pre>object({<br/>    create = optional(string)<br/>    update = optional(string)<br/>    delete = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_topology"></a> [topology](#input\_topology) | Cluster topology. Defaults to replication for PostgreSQL and replicaset for MongoDB. | `string` | `null` | no |
| <a name="input_user_passwords"></a> [user\_passwords](#input\_user\_passwords) | Passwords keyed by username, for users that should not get a generated one. | `map(string)` | `{}` | no |
| <a name="input_users"></a> [users](#input\_users) | Engine users keyed by username. A user without an entry in user\_passwords gets a generated password. | <pre>map(object({<br/>    roles = list(object({<br/>      role       = string<br/>      db         = optional(string, "")<br/>      collection = optional(string, "")<br/>    }))<br/>    description          = optional(string)<br/>    restricted_resources = optional(list(string))<br/>    expires_at           = optional(string)<br/>    connection_limit     = optional(number)<br/>    statement_timeout    = optional(string)<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_database_id"></a> [database\_id](#output\_database\_id) | Database ID. |
| <a name="output_endpoint"></a> [endpoint](#output\_endpoint) | Primary endpoint. |
| <a name="output_generated_passwords"></a> [generated\_passwords](#output\_generated\_passwords) | Generated passwords by username. Not recoverable from the API. |
| <a name="output_phase"></a> [phase](#output\_phase) | Cluster phase after the last apply. |
| <a name="output_private_endpoints"></a> [private\_endpoints](#output\_private\_endpoints) | Private endpoints by role. |
| <a name="output_public_endpoints"></a> [public\_endpoints](#output\_public\_endpoints) | Public endpoints by role. |
| <a name="output_usernames"></a> [usernames](#output\_usernames) | Created usernames. |
<!-- END_TF_DOCS -->
