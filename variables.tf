variable "workspace_id" {
  description = "Workspace the cluster belongs to."
  type        = string
}

variable "name" {
  description = "Cluster name, unique in the workspace. Changing it replaces the cluster."
  type        = string
}

variable "engine" {
  description = "postgresql or mongodb."
  type        = string

  validation {
    condition     = contains(["postgresql", "mongodb"], var.engine)
    error_message = "engine must be postgresql or mongodb."
  }
}

variable "engine_version" {
  description = "Engine version. Upgrades go through Relay's upgrade flow, not this variable."
  type        = string
}

variable "size" {
  description = "Preset node shape: s, m or l. Set either size or nodes."
  type        = string
  default     = null

  validation {
    condition     = var.size == null || contains(["s", "m", "l"], coalesce(var.size, "s"))
    error_message = "size must be s, m or l."
  }
}

variable "node_count" {
  description = "Nodes in the data group when using size."
  type        = number
  default     = 1
}

variable "cloud_provider" {
  description = "Infrastructure provider for the data group when using size."
  type        = string
  default     = null
}

variable "region" {
  description = "Region for the data group when using size."
  type        = string
  default     = null
}

variable "nodes" {
  description = "Explicit node groups, for shapes the presets do not cover."
  type = list(object({
    role     = string
    count    = number
    provider = string
    region   = string
    resources = object({
      cpu           = string
      memory        = string
      storage       = string
      storage_class = optional(string)
      iops          = optional(number)
      throughput    = optional(number)
    })
    tags = optional(map(string))
  }))
  default = null
}

variable "params" {
  description = "Engine parameters."
  type        = map(string)
  default     = null
}

variable "postgresql_parameters" {
  description = "PostgreSQL settings. An empty map resets them; null leaves them unmanaged."
  type        = map(string)
  default     = null
}

variable "backups_enabled" {
  description = "Scheduled backups. Null keeps the platform default."
  type        = bool
  default     = null
}

variable "replication" {
  description = "PostgreSQL replication tuning."
  type = object({
    mode                 = string
    synchronous_replicas = optional(number)
  })
  default = null
}

variable "default_connections" {
  description = "Relay-managed users and connections seeded when the cluster is ready. Changing it replaces the cluster."
  type = object({
    readonly  = optional(bool, false)
    readwrite = optional(bool, false)
    admin     = optional(bool, false)
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
  description = "Engine users keyed by username. A user without an entry in user_passwords gets a generated password."
  type = map(object({
    roles = list(object({
      role       = string
      db         = optional(string, "")
      collection = optional(string, "")
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
