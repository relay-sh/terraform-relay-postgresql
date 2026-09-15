provider "relay" {
  endpoint = "api.staging.userelay.sh:443"
  org_id   = "00000000-0000-0000-0000-000000000000"
}

data "relay_workspace" "prod" {
  name = "prod"
}

module "billing" {
  source = "../.."

  workspace_id   = data.relay_workspace.prod.id
  name           = "billing"
  engine         = "postgresql"
  engine_version = "17"
  size           = "m"
  node_count     = 2
  cloud_provider = "aws"
  region         = "us-east-1"

  postgresql_parameters = {
    work_mem = "64MB"
  }

  users = {
    app = { roles = [{ role = "readWrite", db = "billing" }] }
  }
}

output "app_password" {
  value     = module.billing.generated_passwords["app"]
  sensitive = true
}
