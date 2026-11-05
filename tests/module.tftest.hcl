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
  mock_resource "relay_connection" {
    defaults = {
      id = "conn-1"
    }
  }
  mock_resource "relay_backup_schedule" {
    defaults = {
      id               = "db-123"
      platform_default = false
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
    condition     = relay_postgresql_cluster.this.nodes["primary"].tier == "R30" && relay_postgresql_cluster.this.storage.size == "40Gi"
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
        count  = 1
        cloud  = "aws"
        region = "us-east-1"
        tier   = "R10"
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
        count  = 2
        cloud  = "aws"
        region = "us-east-1"
        tier   = "R20"
      }
      readers = {
        count  = 1
        cloud  = "aws"
        region = "us-east-1"
        tier   = "R10"
        role   = "read_only"
      }
      dr = {
        count  = 1
        cloud  = "aws"
        region = "us-east-1"
        tier   = "R10"
        role   = "standby"
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
        cloud  = "aws"
        region = "us-east-1"
        tier   = "R10"
        role   = "data"
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
    condition     = relay_postgresql_cluster.this.storage.autoscale.enabled && relay_postgresql_cluster.this.storage.autoscale.max_storage == "200Gi" && relay_postgresql_cluster.this.storage.size == "40Gi"
    error_message = "storage_autoscale applies to the cluster"
  }
}

run "storage_with_nodes" {
  command = apply

  variables {
    size   = null
    cloud  = null
    region = null
    nodes = {
      primary = {
        cloud     = "aws"
        region    = "us-east-1"
        tier      = "R10"
        resources = { disk_type = "gp3" }
      }
      readers = {
        cloud  = "aws"
        region = "us-east-1"
        tier   = "R30"
        role   = "read_only"
      }
    }
    storage_autoscale = { enabled = true, threshold_percent = 85, max_storage = "400Gi" }
    users             = {}
    user_passwords    = {}
  }

  assert {
    condition     = relay_postgresql_cluster.this.storage.size == "40Gi"
    error_message = "storage defaults to the largest included storage among the groups' tiers"
  }

  assert {
    condition     = relay_postgresql_cluster.this.storage.autoscale.threshold_percent == 85 && relay_postgresql_cluster.this.nodes["primary"].resources.disk_type == "gp3"
    error_message = "storage_autoscale applies to the cluster and disk attributes stay per group"
  }
}

run "explicit_storage_size" {
  command = apply

  variables {
    storage_size   = "250Gi"
    users          = {}
    user_passwords = {}
  }

  assert {
    condition     = relay_postgresql_cluster.this.storage.size == "250Gi"
    error_message = "storage_size overrides the included storage"
  }
}

run "no_storage_autoscale_by_default" {
  command = plan

  variables {
    users          = {}
    user_passwords = {}
  }

  assert {
    condition     = relay_postgresql_cluster.this.storage.autoscale == null
    error_message = "storage_autoscale stays off unless asked for"
  }
}

run "no_backup_schedule_by_default" {
  command = plan

  variables {
    users          = {}
    user_passwords = {}
  }

  assert {
    condition     = length(relay_backup_schedule.this) == 0
    error_message = "the platform default backup schedule is kept unless one is set"
  }
}

run "backup_schedule_with_tiers" {
  command = apply

  variables {
    backup_schedule = {
      snapshot_time    = { hour = 3, minute = 30 }
      pitr_window_days = 7
      tiers = [
        { frequency = "daily", interval = 1, retention_value = 7 },
        { frequency = "weekly", interval = 1, retention_value = 4, enabled = true },
      ]
    }
    users          = {}
    user_passwords = {}
  }

  assert {
    condition     = relay_backup_schedule.this[0].cluster_id == "db-123" && relay_backup_schedule.this[0].workspace_id == "ws-1"
    error_message = "the backup schedule targets the module's cluster"
  }

  assert {
    condition     = relay_backup_schedule.this[0].snapshot_time.hour == 3 && relay_backup_schedule.this[0].snapshot_time.minute == 30 && relay_backup_schedule.this[0].pitr_window_days == 7
    error_message = "snapshot_time and pitr_window_days pass through"
  }

  assert {
    condition     = length(relay_backup_schedule.this[0].tiers) == 2 && relay_backup_schedule.this[0].tiers[1].frequency == "weekly" && relay_backup_schedule.this[0].tiers[1].retention_value == 4
    error_message = "tiers pass through"
  }

  assert {
    condition     = relay_backup_schedule.this[0].max_backups == null
    error_message = "max_backups stays unset with tiers"
  }
}

run "backup_schedule_with_max_backups" {
  command = apply

  variables {
    backup_schedule = { max_backups = 7 }
    users           = {}
    user_passwords  = {}
  }

  assert {
    condition     = relay_backup_schedule.this[0].max_backups == 7 && relay_backup_schedule.this[0].tiers == null
    error_message = "max_backups passes through without tiers"
  }
}

run "rejects_tiers_and_max_backups" {
  command = plan

  variables {
    backup_schedule = {
      max_backups = 7
      tiers       = [{ frequency = "weekly", interval = 1, retention_value = 4 }]
    }
  }

  expect_failures = [var.backup_schedule]
}

run "rejects_yearly_tier" {
  command = plan

  variables {
    backup_schedule = {
      tiers = [{ frequency = "yearly", interval = 1, retention_value = 2 }]
    }
  }

  expect_failures = [var.backup_schedule]
}

run "default_connections_pass_through" {
  command = plan

  variables {
    default_connections = { readonly = true, admin = false }
  }

  assert {
    condition     = relay_postgresql_cluster.this.default_connections.readonly == true && relay_postgresql_cluster.this.default_connections.admin == false
    error_message = "default_connections reaches the cluster"
  }
}

run "no_connections_by_default" {
  command = plan

  assert {
    condition     = length(relay_connection.this) == 0 && length(output.connections) == 0
    error_message = "no connection is created unless a user asks for one"
  }
}

run "user_connections" {
  command = apply

  variables {
    users = {
      app_rw = {
        roles = [{ role = "readWrite", database = "billing" }, { role = "readOnly", database = "ledger" }]
        connections = [
          { database = "billing", audit_enabled = true, redact_enabled = true, policy_fail_mode = "open", deletion_protection = true },
          { database = "ledger", name = "ledger-ro", agent_pool = "edge" },
        ]
      }
      admin = {
        roles       = [{ role = "admin" }]
        connections = [{ database = "billing" }]
      }
    }
    user_passwords = {}
  }

  assert {
    condition     = keys(relay_connection.this) == ["admin/billing", "app_rw/billing", "app_rw/ledger"]
    error_message = "connections are keyed by user and database"
  }

  assert {
    condition     = relay_connection.this["app_rw/billing"].name == "billing-app-rw-billing" && relay_connection.this["app_rw/ledger"].name == "ledger-ro"
    error_message = "the name defaults to cluster-user-database with hyphens, and an explicit name wins"
  }

  assert {
    condition     = relay_connection.this["app_rw/billing"].engine == "postgres" && relay_connection.this["app_rw/billing"].managed_database_id == "db-123" && relay_connection.this["app_rw/billing"].user == "app_rw" && relay_connection.this["app_rw/billing"].database == "billing"
    error_message = "a connection is bound to the cluster, user and database without a host"
  }

  assert {
    condition     = relay_connection.this["app_rw/billing"].agent_pool == "default" && relay_connection.this["app_rw/ledger"].agent_pool == "edge"
    error_message = "agent_pool defaults to the managed agent"
  }

  assert {
    condition     = relay_connection.this["app_rw/billing"].audit_enabled == true && relay_connection.this["app_rw/billing"].redact_enabled == true && relay_connection.this["app_rw/billing"].policy_fail_mode == "open" && relay_connection.this["app_rw/billing"].deletion_protection == true
    error_message = "connection settings pass through"
  }

  assert {
    condition     = output.connections["app_rw/ledger"] == { id = "conn-1", name = "ledger-ro" }
    error_message = "connections are output by key with id and name"
  }
}

run "rejects_connection_to_database_outside_roles" {
  command = plan

  variables {
    users = {
      app = {
        roles       = [{ role = "readWrite", database = "billing" }]
        connections = [{ database = "ledger" }]
      }
    }
    databases      = { ledger = {} }
    user_passwords = {}
  }

  expect_failures = [var.users]
}

run "rejects_duplicate_connection" {
  command = plan

  variables {
    users = {
      app = {
        roles       = [{ role = "readWrite", database = "billing" }]
        connections = [{ database = "billing" }, { database = "billing", name = "second" }]
      }
    }
    user_passwords = {}
  }

  expect_failures = [var.users]
}

run "rejects_admin_connection_to_unknown_database" {
  command = plan

  variables {
    users = {
      admin = {
        roles       = [{ role = "admin" }]
        connections = [{ database = "nowhere" }]
      }
    }
    user_passwords = {}
  }

  expect_failures = [relay_connection.this]
}
