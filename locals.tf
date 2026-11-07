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
        disk_type  = null
        iops       = null
        throughput = null
      }
      role        = "electable"
      autoscaling = null
    }
  }

  storage_size = coalesce(var.storage_size, "${max([for n in values(local.nodes) : tonumber(trimsuffix(local.included_storage[n.tier], "Gi"))]...)}Gi")

  password_users = toset(nonsensitive(keys(var.user_passwords)))

  role_databases = toset(flatten([for u in values(var.users) : [for r in u.roles : r.database if r.database != ""]]))
  databases      = merge({ for name in local.role_databases : name => { description = null } }, var.databases)

  connections = merge([
    for uname, u in var.users : {
      for c in u.connections : "${uname}/${c.database}" => merge(c, {
        user = uname
        name = coalesce(c.name, replace("${var.name}-${uname}-${c.database}", "_", "-"))
      })
    }
  ]...)
}
