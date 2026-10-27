provider "relay" {}

data "relay_workspace" "prod" {
  name = "prod"
}

module "billing" {
  source = "../.."

  workspace_id   = data.relay_workspace.prod.id
  name           = "billing"
  engine_version = "18"
  size           = "R30"
  node_count     = 2
  cloud          = "aws"
  region         = "us-east-1"

  parameters = {
    work_mem = "64MB"
  }

  backup_schedule = {
    snapshot_time    = { hour = 3, minute = 30 }
    pitr_window_days = 14
    tiers = [
      { frequency = "daily", interval = 1, retention_value = 7 },
      { frequency = "weekly", interval = 1, retention_value = 4 },
    ]
  }

  users = {
    app = { roles = [{ role = "readWrite", database = "billing" }] }
  }
}

output "app_password" {
  value     = module.billing.generated_passwords["app"]
  sensitive = true
}
