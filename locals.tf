locals {
  presets = {
    s = { cpu = "500m", memory = "1Gi", storage = "10Gi" }
    m = { cpu = "2", memory = "8Gi", storage = "50Gi" }
    l = { cpu = "4", memory = "16Gi", storage = "200Gi" }
  }

  nodes = var.nodes != null ? var.nodes : [{
    role      = "data"
    count     = var.node_count
    provider  = var.cloud_provider
    region    = var.region
    resources = merge(local.presets[coalesce(var.size, "s")], { storage_class = null, iops = null, throughput = null })
    tags      = null
  }]

  password_users = toset(nonsensitive(keys(var.user_passwords)))
}
