provider "relay" {}

data "relay_workspace" "prod" {
  name = "prod"
}

module "billing" {
  source = "../.."

  workspace_id   = data.relay_workspace.prod.id
  name           = "billing"
  engine_version = "18"

  nodes = {
    primary = {
      count  = 2
      cloud  = "aws"
      region = "us-east-1"
      tier   = "R30"
      autoscaling = {
        enabled  = true
        min_tier = "R20"
        max_tier = "R50"
        rules = [
          { metric = "cpu", scale_up_above = 75, scale_down_below = 30 },
          { metric = "postgres.connections", scale_up_above = 80, scale_down_below = 40 },
        ]
        scale_up_window   = "5m"
        scale_down_window = "6h"
      }
    }
  }
}

output "cluster_id" {
  value = module.billing.cluster_id
}
