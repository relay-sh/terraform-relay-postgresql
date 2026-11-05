variable "workspace_id" {
  description = "Workspace the cluster belongs to."
  type        = string
}

variable "name" {
  description = "Cluster name, unique in the workspace. Changing it replaces the cluster."
  type        = string
}

variable "engine_version" {
  description = "Major PostgreSQL version. Omit it and the platform picks one. Upgrades go through Relay's upgrade flow, not this variable."
  type        = string
  default     = null
}

variable "size" {
  description = "Catalog machine tier (R5–R200). CPU and memory come from the catalog; included storage is the default volume. Set either size or nodes."
  type        = string
  default     = null

  validation {
    condition     = var.size == null || contains(["R5", "R10", "R20", "R30", "R40", "R50", "R60", "R80", "R100", "R200"], coalesce(var.size, "R5"))
    error_message = "size must be a catalog name: R5, R10, R20, R30, R40, R50, R60, R80, R100, or R200."
  }
}

variable "node_count" {
  description = "Nodes in the primary group when using size."
  type        = number
  default     = 1
}

variable "cloud" {
  description = "Cloud for the primary group when using size, for example aws."
  type        = string
  default     = null
}

variable "region" {
  description = "Region for the primary group when using size."
  type        = string
  default     = null
}

variable "nodes" {
  description = "Explicit node groups keyed by group name. Each group names a catalog tier; CPU and memory are derived. A group is `electable` unless it is set to `standby`, which keeps it out of the synchronous commit path, or `read_only`, which also keeps it out of elections. Storage is set for the whole cluster with storage_size and storage_autoscale."
  type = map(object({
    count  = optional(number, 1)
    cloud  = string
    region = string
    tier   = string
    resources = optional(object({
      disk_type  = optional(string)
      iops       = optional(number)
      throughput = optional(number)
    }), {})
    role = optional(string, "electable")
  }))
  default = null

  validation {
    condition     = var.nodes == null || alltrue([for n in values(coalesce(var.nodes, {})) : contains(["electable", "standby", "read_only"], n.role)])
    error_message = "node role must be electable, standby or read_only."
  }
}

variable "storage_size" {
  description = "Volume size of every node in the cluster, for example 100Gi. Defaults to the included storage of size, or of the largest tier in nodes. It can grow but not shrink."
  type        = string
  default     = null
}

variable "storage_autoscale" {
  description = "Grows every node's volume past storage_size, up to max_storage, when disk usage crosses threshold_percent."
  type = object({
    enabled           = bool
    threshold_percent = optional(number)
    increase_percent  = optional(number)
    max_storage       = optional(string)
  })
  default = null
}

variable "backup_schedule" {
  description = "Backup schedule for the cluster. Null keeps the platform default; removing it resets the cluster to that default. Set either tiers or max_backups. Every enabled tier is rendered into the backup crons; the weekly tier takes the full backup and the daily tier the incremental one."
  type = object({
    snapshot_time = optional(object({
      hour   = number
      minute = number
    }))
    tiers = optional(list(object({
      frequency       = string
      interval        = number
      retention_value = number
      retention_unit  = optional(string)
      enabled         = optional(bool)
    })))
    max_backups      = optional(number)
    pitr_window_days = optional(number)
  })
  default = null

  validation {
    condition     = try(var.backup_schedule.tiers == null || var.backup_schedule.max_backups == null, true)
    error_message = "backup_schedule takes either tiers or max_backups, not both."
  }

  validation {
    condition     = try(alltrue([for t in var.backup_schedule.tiers : contains(["hourly", "daily", "weekly", "monthly"], t.frequency)]), true)
    error_message = "backup_schedule tier frequency must be hourly, daily, weekly or monthly."
  }
}

variable "parameters" {
  description = "PostgreSQL settings. An empty map resets them; null leaves them unmanaged."
  type        = map(string)
  default     = null
}

variable "replication" {
  description = "Commit replication for the cluster."
  type = object({
    mode                 = string
    synchronous_replicas = optional(number)
  })
  default = null
}

variable "default_connections" {
  description = "Relay-managed read-only, read-write and admin users, each with a Relay connection. Null creates all three on create and keeps the current value afterwards; a role omitted inside the object does the same. Turning a role off on an existing cluster deletes its connection and user."
  type = object({
    readonly  = optional(bool)
    readwrite = optional(bool)
    admin     = optional(bool)
  })
  default = null
}

variable "keep_backups_on_destroy" {
  description = "Keep the cluster's backups when it is destroyed."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "While true, the platform refuses to delete the cluster, and a destroy or a replacement fails before deleting it."
  type        = bool
  default     = false
}

variable "timeouts" {
  description = "Create, update and delete timeouts, for example 45m."
  type = object({
    create = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default = {}
}

variable "databases" {
  description = "Logical databases keyed by name, created before the users. Every database named in a user's roles is created even without an entry here."
  type = map(object({
    description = optional(string)
  }))
  default = {}
}

variable "users" {
  description = "PostgreSQL users keyed by username. A user without an entry in user_passwords gets a generated password. A database named in roles is created by the module. connections creates one Relay connection per entry, signed in as that user on the named database, which must be one of the user's role databases (any module database for a user with a role that names none). The name defaults to <cluster>-<user>-<database> with underscores turned into hyphens."
  type = map(object({
    roles = list(object({
      role     = string
      database = optional(string, "")
    }))
    description          = optional(string)
    restricted_resources = optional(list(string))
    expires_at           = optional(string)
    connection_limit     = optional(number)
    statement_timeout    = optional(string)
    connections = optional(list(object({
      database            = string
      name                = optional(string)
      agent_pool          = optional(string, "default")
      audit_enabled       = optional(bool)
      redact_enabled      = optional(bool)
      policy_fail_mode    = optional(string)
      deletion_protection = optional(bool)
    })), [])
  }))
  default = {}

  validation {
    condition = alltrue(flatten([
      for u in values(var.users) : [
        for c in u.connections :
        anytrue([for r in u.roles : r.database == "" || r.database == c.database])
      ]
    ]))
    error_message = "A connection's database must be one of the user's role databases, unless the user has a role without a database."
  }

  validation {
    condition = length(distinct(flatten([
      for k, u in var.users : [for c in u.connections : "${k}/${c.database}"]
    ]))) == length(flatten([for u in values(var.users) : u.connections]))
    error_message = "A user can have only one connection per database."
  }
}

variable "user_passwords" {
  description = "Passwords keyed by username, for users that should not get a generated one."
  type        = map(string)
  default     = {}
  sensitive   = true
}
