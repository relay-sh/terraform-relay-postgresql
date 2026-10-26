mock_provider "relay" {
  mock_resource "relay_postgresql_cluster" {
    defaults = {
      id            = "db-123"
      phase         = "running"
      endpoint_host = "billing.db"
      endpoint_port = 5432
    }
  }
  mock_resource "relay_postgresql_database" {
    defaults = {
      id    = "db-123/billing"
      phase = "Ready"
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

  assert {
    condition     = output.databases == ["billing"] && relay_postgresql_database.this["billing"].cluster_id == "db-123"
    error_message = "a database named in roles is created once on the module's cluster"
  }
}

run "databases" {
  command = apply

  variables {
    users = {
      app   = { roles = [{ role = "readWrite", database = "billing" }, { role = "readOnly", database = "ledger" }] }
      admin = { roles = [{ role = "admin" }] }
    }
    databases = {
      billing = { description = "invoices" }
      archive = {}
    }
    user_passwords = {}
  }

  assert {
    condition     = output.databases == ["archive", "billing", "ledger"]
    error_message = "databases from roles and from var.databases are merged, and admin adds none"
  }

  assert {
    condition     = relay_postgresql_database.this["billing"].description == "invoices" && relay_postgresql_database.this["ledger"].description == null
    error_message = "var.databases sets the description of a database named in roles"
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

run "node_roles" {
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
      dr = {
        count     = 1
        cloud     = "aws"
        region    = "us-east-1"
        tier      = "R10"
        resources = { storage = "10Gi" }
        role      = "standby"
      }
    }
    users          = {}
    user_passwords = {}
  }

  assert {
    condition     = relay_postgresql_cluster.this.nodes["writers"].role == "electable" && relay_postgresql_cluster.this.nodes["readers"].role == "read_only" && relay_postgresql_cluster.this.nodes["dr"].role == "standby"
    error_message = "a group is electable unless it asks for another role"
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
        cloud     = "aws"
        region    = "us-east-1"
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

run "storage_autoscale_with_size" {
  command = apply

  variables {
    storage_autoscale = { enabled = true, max_storage = "200Gi" }
    users             = {}
    user_passwords    = {}
  }

  assert {
    condition     = relay_postgresql_cluster.this.nodes["primary"].resources.storage_autoscale.enabled && relay_postgresql_cluster.this.nodes["primary"].resources.storage_autoscale.max_storage == "200Gi"
    error_message = "storage_autoscale reaches the size preset group"
  }
}

run "storage_autoscale_per_group" {
  command = apply

  variables {
    size   = null
    cloud  = null
    region = null
    nodes = {
      primary = {
        cloud  = "aws"
        region = "us-east-1"
        tier   = "R20"
        resources = {
          storage           = "40Gi"
          storage_autoscale = { enabled = true, threshold_percent = 85, max_storage = "400Gi" }
        }
      }
    }
    users          = {}
    user_passwords = {}
  }

  assert {
    condition     = relay_postgresql_cluster.this.nodes["primary"].resources.storage_autoscale.threshold_percent == 85
    error_message = "storage_autoscale passes through on explicit nodes"
  }
}

run "no_storage_autoscale_by_default" {
  command = plan

  variables {
    users          = {}
    user_passwords = {}
  }

  assert {
    condition     = relay_postgresql_cluster.this.nodes["primary"].resources.storage_autoscale == null
    error_message = "storage_autoscale stays off unless asked for"
  }
}
