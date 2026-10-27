resource "relay_postgresql_cluster" "this" {
  workspace_id = var.workspace_id
  name         = var.name
  version      = var.engine_version
  nodes        = local.nodes
  parameters   = var.parameters
  replication  = var.replication

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
      condition     = var.nodes != null || (var.cloud != null && var.region != null)
      error_message = "cloud and region are required when using size."
    }
  }
}

resource "relay_postgresql_database" "this" {
  for_each = local.databases

  workspace_id = var.workspace_id
  cluster_id   = relay_postgresql_cluster.this.id
  name         = each.key
  description  = each.value.description
}

resource "relay_postgresql_user" "this" {
  for_each = var.users

  depends_on = [relay_postgresql_database.this]

  workspace_id         = var.workspace_id
  cluster_id           = relay_postgresql_cluster.this.id
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

resource "relay_backup_schedule" "this" {
  count = var.backup_schedule == null ? 0 : 1

  workspace_id     = var.workspace_id
  cluster_id       = relay_postgresql_cluster.this.id
  snapshot_time    = var.backup_schedule.snapshot_time
  tiers            = var.backup_schedule.tiers
  max_backups      = var.backup_schedule.max_backups
  pitr_window_days = var.backup_schedule.pitr_window_days
}
