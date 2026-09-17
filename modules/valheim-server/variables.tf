# --- Identity ---------------------------------------------------------------

variable "name" {
  description = "Short server name. Every resource for this server is named from it (VM, IP, bucket, secret, service accounts, Cloud Run service), so it must be unique within the project."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,18}[a-z0-9]$", var.name))
    error_message = "name must be 3-20 characters: lowercase letters, digits and hyphens, starting with a letter and not ending with a hyphen (it becomes part of service account IDs, which are capped at 30 characters)."
  }
}

variable "project_id" {
  description = "GCP project ID to deploy into."
  type        = string
}

variable "region" {
  description = "GCP region for regional resources (static IP, Cloud Run, bucket)."
  type        = string
}

variable "zone" {
  description = "GCP zone for the VM."
  type        = string
}

# --- Game settings -----------------------------------------------------------

variable "display_name" {
  description = "Server name shown in the in-game server browser. Defaults to name."
  type        = string
  default     = null
}

variable "world_name" {
  description = "Valheim world/save file name, without extension. Defaults to name."
  type        = string
  default     = null
}

variable "server_public" {
  description = "Whether the server is listed publicly in the in-game server browser."
  type        = bool
  default     = false
}

variable "server_password" {
  description = "Valheim join password. Stored in Secret Manager, not in instance metadata."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.server_password) >= 5
    error_message = "Missing or too short server password (Valheim requires 5+ characters). Add an entry for this server to the VALHEIM_SERVER_PASSWORDS GitHub secret."
  }
}

variable "idle_timeout_minutes" {
  description = "Minutes with zero connected players before the world is backed up and the VM shuts itself down."
  type        = number
  default     = 30
}

# --- Machine -------------------------------------------------------------------

variable "machine_type" {
  description = "GCE machine type. Valheim recommends 4+ GB RAM; e2-standard-2 (8GB) leaves headroom for mods."
  type        = string
  default     = "e2-standard-2"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB. Holds Docker, the game files and world saves."
  type        = number
  default     = 50
}

# --- Backups -----------------------------------------------------------------

variable "backup_retention_days" {
  description = "Days to keep superseded world-backup versions in the bucket."
  type        = number
  default     = 30
}

variable "backup_bucket_force_destroy" {
  description = "If true, destroying this server also deletes its world backups. Leave false in normal use."
  type        = bool
  default     = false
}

# --- Start trigger -------------------------------------------------------------

variable "trigger_image" {
  description = "Container image for the Cloud Run start-trigger. Set by the deploy workflow."
  type        = string
}

variable "trigger_invoker_members" {
  description = "IAM members allowed to call the start-trigger, e.g. [\"user:you@example.com\"]."
  type        = list(string)
  default     = []
}

variable "start_instance_role_id" {
  description = "Full ID of the shared custom role that allows starting an instance (created by stacks/shared)."
  type        = string
}

locals {
  display_name = coalesce(var.display_name, var.name)
  world_name   = coalesce(var.world_name, var.name)
}
