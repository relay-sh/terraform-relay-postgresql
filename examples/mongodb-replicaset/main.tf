provider "relay" {}

module "events" {
  source = "../.."

  workspace_id   = "00000000-0000-0000-0000-000000000000"
  name           = "events"
  engine         = "mongodb"
  engine_version = "8.0"

  nodes = [{
    role     = "data"
    count    = 3
    provider = "gcp"
    region   = "us-central1"
    resources = {
      cpu           = "2"
      memory        = "8Gi"
      storage       = "100Gi"
      storage_class = "premium-rwo"
    }
  }]

  keep_backups_on_destroy = true

  timeouts = {
    create = "60m"
  }
}
