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
    condition     = var.size == null || contains(["R5", "R10", "R20", "R30", "R40", "R50", "R60", "R70", "R80", "R90", "R100", "R200"], coalesce(var.size, "R5"))
    error_message = "size must be a catalog name: R5, R10, R20, R30, R40, R50, R60, R70, R80, R90, R100, or R200."
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
  description = "Explicit node groups keyed by group name. Each group names a catalog tier; CPU and memory are derived. A group is `electable` unless it is set to `read_only`, which keeps it out of the commit path and out of elections. Use this to set storage above the included size or add extra groups."
  type = map(object({
    count  = optional(number, 1)
    cloud  = optional(string)
    region = optional(string)
    tier   = string
    resources = object({
      storage       = string
      storage_class = optional(string)
      iops          = optional(number)
      throughput    = optional(number)
    })
    role = optional(string, "electable")
  }))
  default = null

  validation {
    condition     = var.nodes == null || alltrue([for n in values(coalesce(var.nodes, {})) : contains(["electable", "read_only"], n.role)])
    error_message = "node role must be electable or read_only."
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

variable "keep_backups_on_destroy" {
  description = "Keep the cluster's backups when it is destroyed."
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

variable "users" {
  description = "PostgreSQL users keyed by username. A user without an entry in user_passwords gets a generated password."
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
  }))
  default = {}
}

variable "user_passwords" {
  description = "Passwords keyed by username, for users that should not get a generated one."
  type        = map(string)
  default     = {}
  sensitive   = true
}
