resource "relay_database" "this" {
  workspace_id = var.workspace_id
  name         = var.name
  engine       = var.engine
  version      = var.engine_version
  nodes        = local.nodes

  params                  = var.params
  postgresql_parameters   = var.postgresql_parameters
  backups_enabled         = var.backups_enabled
  replication             = var.replication
  default_connections     = var.default_connections
  keep_backups_on_destroy = var.keep_backups_on_destroy

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }

  lifecycle {
    precondition {
      condition     = (var.size == null) != (var.nodes == null)
      error_message = "Set exactly one of size or nodes."
    }
    precondition {
      condition     = var.nodes != null || (var.cloud_provider != null && var.region != null)
      error_message = "cloud_provider and region are required when using size."
    }
    precondition {
      condition     = var.postgresql_parameters == null || var.engine == "postgresql"
      error_message = "postgresql_parameters only applies to postgresql."
    }
    precondition {
      condition     = var.replication == null || var.engine == "postgresql"
      error_message = "replication only applies to postgresql."
    }
  }
}

resource "relay_database_user" "this" {
  for_each = var.users

  workspace_id         = var.workspace_id
  database_id          = relay_database.this.id
  username             = each.key
  roles                = each.value.roles
  password             = contains(local.password_users, each.key) ? var.user_passwords[each.key] : null
  generate_password    = !contains(local.password_users, each.key)
  description          = each.value.description
  restricted_resources = each.value.restricted_resources
  expires_at           = each.value.expires_at
  connection_limit     = each.value.connection_limit
  statement_timeout    = each.value.statement_timeout
}
