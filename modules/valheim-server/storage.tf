resource "google_storage_bucket" "backups" {
  name                        = "${var.project_id}-${var.name}-backups"
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = var.backup_bucket_force_destroy

  versioning {
    enabled = true
  }

  # The idle-monitor overwrites worlds_local/ in place on every shutdown;
  # versioning keeps earlier copies, pruned after backup_retention_days.
  lifecycle_rule {
    condition {
      days_since_noncurrent_time = var.backup_retention_days
    }
    action {
      type = "Delete"
    }
  }
}
