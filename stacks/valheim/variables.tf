variable "project_id" {
  description = "GCP project ID to deploy into."
  type        = string
}

variable "region" {
  description = "GCP region for regional resources (Cloud Run, Artifact Registry, bucket)."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for the Valheim VM."
  type        = string
  default     = "us-central1-a"
}

variable "instance_name" {
  description = "Name of the Valheim GCE instance."
  type        = string
  default     = "valheim-server"
}

variable "machine_type" {
  description = "GCE machine type. Valheim recommends 4+ GB RAM; e2-standard-2 (8GB) gives headroom for mods."
  type        = string
  default     = "e2-standard-2"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB. Holds the Docker image, world saves, and backups staging area."
  type        = number
  default     = 50
}

variable "server_name" {
  description = "Public name of the Valheim server, shown in the in-game server browser."
  type        = string
  default     = "Chester's Valheim Server"
}

variable "world_name" {
  description = "Name of the Valheim world/save file."
  type        = string
  default     = "brotherskaraminkov"
}

variable "server_public" {
  description = "Whether the server is listed publicly in the in-game server browser."
  type        = bool
  default     = false
}

variable "idle_timeout_minutes" {
  description = "Minutes with zero connected players before the server backs up the world and shuts itself down."
  type        = number
  default     = 30
}

variable "backup_bucket_force_destroy" {
  description = "If true, `terraform destroy` will delete the backup bucket even if it still has world backups in it. Leave false in normal use."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "How many days of noncurrent (superseded) world-backup object versions to retain in the GCS bucket."
  type        = number
  default     = 30
}

variable "ssh_source_ranges" {
  description = "CIDR ranges allowed to reach SSH (port 22). Defaults to the IAP TCP forwarding range only - no direct public SSH."
  type        = list(string)
  default     = ["35.235.240.0/20"]
}

variable "trigger_image" {
  description = "Fully qualified container image URL for the Cloud Run start-trigger service. Set automatically by the GitHub workflow, which builds and pushes trigger-service/ on every run."
  type        = string
}

variable "trigger_invoker_members" {
  description = "IAM members allowed to invoke the Cloud Run start-trigger (e.g. [\"user:you@example.com\"]). Kept private by default so random internet traffic can't wake the VM."
  type        = list(string)
  default     = []
}
