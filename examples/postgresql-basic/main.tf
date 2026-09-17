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

  users = {
    app = { roles = [{ role = "readWrite", database = "billing" }] }
  }
}

output "app_password" {
  value     = module.billing.generated_passwords["app"]
  sensitive = true
}
