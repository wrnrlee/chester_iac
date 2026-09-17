resource "google_storage_bucket" "valheim_backups" {
  name                        = "${var.project_id}-valheim-backups"
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = var.backup_bucket_force_destroy

  versioning {
    enabled = true
  }

  # The idle-monitor overwrites gs://<bucket>/worlds_local in place on
  # every shutdown; versioning keeps prior copies as noncurrent versions
  # so a bad save doesn't destroy earlier progress. This rule prunes those
  # older versions after backup_retention_days.
  lifecycle_rule {
    condition {
      days_since_noncurrent_time = var.backup_retention_days
    }
    action {
      type = "Delete"
    }
  }
}
