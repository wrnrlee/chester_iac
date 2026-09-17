# --- VM service account ----------------------------------------------------
# Can write this server's backup bucket, read this server's password and
# write logs/metrics. No compute permissions: the idle-monitor stops the VM
# by shutting down the guest OS, which GCE reports as a stop.

resource "google_service_account" "vm" {
  account_id   = "${var.name}-vm"
  display_name = "Valheim ${var.name} VM"
  project      = var.project_id
}

resource "google_storage_bucket_iam_member" "vm_backup_writer" {
  bucket = google_storage_bucket.backups.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.vm.email}"
}

resource "google_secret_manager_secret_iam_member" "vm_password_accessor" {
  secret_id = google_secret_manager_secret.server_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vm.email}"
}

resource "google_project_iam_member" "vm_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vm.email}"
}

resource "google_project_iam_member" "vm_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.vm.email}"
}

# --- Start-trigger service account -----------------------------------------
# Can only start/inspect this one VM (shared custom role, conditioned on the
# instance name). No storage or secret access.

resource "google_service_account" "trigger" {
  account_id   = "${var.name}-trigger"
  display_name = "Valheim ${var.name} start-trigger"
  project      = var.project_id
}

resource "google_project_iam_member" "trigger_can_start_instance" {
  project = var.project_id
  role    = var.start_instance_role_id
  member  = "serviceAccount:${google_service_account.trigger.email}"

  condition {
    title       = "only-${var.name}"
    description = "Restrict to the ${var.name} Valheim instance."
    expression  = "resource.name == \"projects/${var.project_id}/zones/${var.zone}/instances/${var.name}\""
  }
}
