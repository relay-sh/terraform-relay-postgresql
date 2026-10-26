locals {
  included_storage = {
    R5   = "5Gi"
    R10  = "10Gi"
    R20  = "20Gi"
    R30  = "40Gi"
    R40  = "80Gi"
    R50  = "160Gi"
    R60  = "320Gi"
    R80  = "750Gi"
    R100 = "1000Gi"
    R200 = "1500Gi"
  }

  nodes = var.nodes != null ? var.nodes : {
    primary = {
      count  = var.node_count
      cloud  = var.cloud
      region = var.region
      tier   = var.size
      resources = {
        storage    = local.included_storage[var.size]
        disk_type  = null
        iops       = null
        throughput = null

        storage_autoscale = var.storage_autoscale
      }
      role = "electable"
    }
  }

  password_users = toset(nonsensitive(keys(var.user_passwords)))

  role_databases = toset(flatten([for u in values(var.users) : [for r in u.roles : r.database if r.database != ""]]))
  databases      = merge({ for name in local.role_databases : name => { description = null } }, var.databases)
}
