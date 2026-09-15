mock_provider "relay" {
  mock_resource "relay_database" {
    defaults = {
      id            = "db-123"
      phase         = "running"
      endpoint_host = "billing.db"
      endpoint_port = 5432
    }
  }
  mock_resource "relay_database_user" {
    defaults = {
      id                 = "db-123/app"
      generated_password = "generated"
    }
  }
}

variables {
  workspace_id   = "ws-1"
  name           = "billing"
  engine         = "postgresql"
  engine_version = "17"
  size           = "m"
  node_count     = 2
  cloud_provider = "aws"
  region         = "us-east-1"
  users = {
    app       = { roles = [{ role = "readWrite", db = "billing" }] }
    reporting = { roles = [{ role = "readOnly", db = "billing" }], connection_limit = 5 }
  }
  user_passwords = {
    reporting = "hunter2"
  }
}

run "size_preset_and_users" {
  command = apply

  assert {
    condition     = length(relay_database.this.nodes) == 1 && relay_database.this.nodes[0].count == 2
    error_message = "size builds one data group with node_count nodes"
  }

  assert {
    condition     = relay_database.this.nodes[0].resources.cpu == "2" && relay_database.this.nodes[0].resources.storage == "50Gi"
    error_message = "size m maps to the m preset"
  }

  assert {
    condition     = relay_database.this.topology == "replication"
    error_message = "postgresql defaults to replication"
  }

  assert {
    condition     = relay_database_user.this["app"].generate_password && relay_database_user.this["app"].password == null
    error_message = "a user without a password gets a generated one"
  }

  assert {
    condition     = !relay_database_user.this["reporting"].generate_password
    error_message = "a user with a password does not get a generated one"
  }

  assert {
    condition     = relay_database_user.this["reporting"].database_id == "db-123"
    error_message = "users are created on the module's cluster"
  }

  assert {
    condition     = output.database_id == "db-123" && output.endpoint.port == 5432 && output.usernames == ["app", "reporting"]
    error_message = "outputs expose the cluster and its users"
  }

  assert {
    condition     = keys(nonsensitive(output.generated_passwords)) == ["app"]
    error_message = "only generated passwords are output"
  }
}

run "explicit_nodes_for_mongodb" {
  command = apply

  variables {
    engine         = "mongodb"
    engine_version = "8.0"
    size           = null
    cloud_provider = null
    region         = null
    nodes = [{
      role     = "data"
      count    = 3
      provider = "gcp"
      region   = "us-central1"
      resources = {
        cpu     = "1"
        memory  = "4Gi"
        storage = "20Gi"
      }
    }]
    users          = {}
    user_passwords = {}
  }

  assert {
    condition     = relay_database.this.topology == "replicaset" && relay_database.this.nodes[0].provider == "gcp"
    error_message = "mongodb defaults to replicaset and explicit nodes pass through"
  }
}

run "rejects_size_and_nodes" {
  command = plan

  variables {
    nodes = [{
      role      = "data"
      count     = 1
      provider  = "aws"
      region    = "us-east-1"
      resources = { cpu = "1", memory = "1Gi", storage = "1Gi" }
    }]
  }

  expect_failures = [relay_database.this]
}

run "rejects_size_without_placement" {
  command = plan

  variables {
    region = null
  }

  expect_failures = [relay_database.this]
}

run "rejects_postgresql_parameters_on_mongodb" {
  command = plan

  variables {
    engine                = "mongodb"
    postgresql_parameters = { work_mem = "64MB" }
  }

  expect_failures = [relay_database.this]
}

run "rejects_replication_on_mongodb" {
  command = plan

  variables {
    engine      = "mongodb"
    replication = { mode = "async" }
  }

  expect_failures = [relay_database.this]
}

run "rejects_unknown_engine_and_size" {
  command = plan

  variables {
    engine = "mysql"
    size   = "xl"
  }

  expect_failures = [var.engine, var.size]
}
