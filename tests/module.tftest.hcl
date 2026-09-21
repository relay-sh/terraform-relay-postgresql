mock_provider "relay" {
  mock_resource "relay_postgresql_cluster" {
    defaults = {
      id            = "db-123"
      phase         = "running"
      endpoint_host = "billing.db"
      endpoint_port = 5432
    }
  }
  mock_resource "relay_postgresql_user" {
    defaults = {
      id                 = "db-123/app"
      generated_password = "generated"
    }
  }
}

variables {
  workspace_id   = "ws-1"
  name           = "billing"
  engine_version = "18"
  size           = "R30"
  node_count     = 2
  cloud          = "aws"
  region         = "us-east-1"
  users = {
    app       = { roles = [{ role = "readWrite", database = "billing" }] }
    reporting = { roles = [{ role = "readOnly", database = "billing" }], connection_limit = 5 }
  }
  user_passwords = {
    reporting = "hunter2"
  }
}

run "size_preset_and_users" {
  command = apply

  assert {
    condition     = length(relay_postgresql_cluster.this.nodes) == 1 && relay_postgresql_cluster.this.nodes["primary"].count == 2
    error_message = "size builds one primary group with node_count nodes"
  }

  assert {
    condition     = relay_postgresql_cluster.this.nodes["primary"].tier == "R30" && relay_postgresql_cluster.this.nodes["primary"].resources.storage == "40Gi"
    error_message = "size R30 maps to catalog included storage"
  }

  assert {
    condition     = relay_postgresql_cluster.this.nodes["primary"].role == "electable"
    error_message = "the size preset builds an electable group"
  }

  assert {
    condition     = relay_postgresql_user.this["app"].generate_password && relay_postgresql_user.this["app"].password == null
    error_message = "a user without a password gets a generated one"
  }

  assert {
    condition     = !relay_postgresql_user.this["reporting"].generate_password
    error_message = "a user with a password does not get a generated one"
  }

  assert {
    condition     = relay_postgresql_user.this["reporting"].cluster_id == "db-123"
    error_message = "users are created on the module's cluster"
  }

  assert {
    condition     = output.cluster_id == "db-123" && output.endpoint.port == 5432 && output.usernames == ["app", "reporting"]
    error_message = "outputs expose the cluster and its users"
  }

  assert {
    condition     = keys(nonsensitive(output.generated_passwords)) == ["app"]
    error_message = "only generated passwords are output"
  }
}

run "explicit_nodes" {
  command = apply

  variables {
    size   = null
    cloud  = null
    region = null
    nodes = {
      primary = {
        count  = 3
        cloud  = "gcp"
        region = "us-central1"
        tier   = "R20"
        resources = {
          storage = "40Gi"
        }
      }
    }
    users          = {}
    user_passwords = {}
  }

  assert {
    condition     = relay_postgresql_cluster.this.nodes["primary"].cloud == "gcp" && relay_postgresql_cluster.this.nodes["primary"].count == 3 && relay_postgresql_cluster.this.nodes["primary"].tier == "R20"
    error_message = "explicit nodes pass through"
  }
}

run "rejects_size_and_nodes" {
  command = plan

  variables {
    nodes = {
      primary = {
        count     = 1
        cloud     = "aws"
        region    = "us-east-1"
        tier      = "R10"
        resources = { storage = "10Gi" }
      }
    }
  }

  expect_failures = [relay_postgresql_cluster.this]
}

run "rejects_size_without_placement" {
  command = plan

  variables {
    region = null
  }

  expect_failures = [relay_postgresql_cluster.this]
}

run "postgresql_tuning_passes_through" {
  command = apply

  variables {
    parameters     = { work_mem = "64MB" }
    replication    = { mode = "async", synchronous_replicas = 1 }
    users          = {}
    user_passwords = {}
  }

  assert {
    condition     = relay_postgresql_cluster.this.parameters["work_mem"] == "64MB"
    error_message = "parameters pass through"
  }

  assert {
    condition     = relay_postgresql_cluster.this.replication.mode == "async" && relay_postgresql_cluster.this.replication.synchronous_replicas == 1
    error_message = "replication passes through"
  }
}

run "read_only_group" {
  command = apply

  variables {
    size   = null
    cloud  = null
    region = null
    nodes = {
      writers = {
        count     = 2
        cloud     = "aws"
        region    = "us-east-1"
        tier      = "R20"
        resources = { storage = "40Gi" }
      }
      readers = {
        count     = 1
        cloud     = "aws"
        region    = "us-east-1"
        tier      = "R10"
        resources = { storage = "10Gi" }
        role      = "read_only"
      }
    }
    users          = {}
    user_passwords = {}
  }

  assert {
    condition     = relay_postgresql_cluster.this.nodes["writers"].role == "electable" && relay_postgresql_cluster.this.nodes["readers"].role == "read_only"
    error_message = "a group is electable unless it asks to be read_only"
  }
}

run "rejects_unknown_role" {
  command = plan

  variables {
    size   = null
    cloud  = null
    region = null
    nodes = {
      primary = {
        tier      = "R10"
        resources = { storage = "10Gi" }
        role      = "data"
      }
    }
  }

  expect_failures = [var.nodes]
}

run "rejects_unknown_size" {
  command = plan

  variables {
    size = "R140"
  }

  expect_failures = [var.size]
}
