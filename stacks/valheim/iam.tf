# --- valheim-vm: attached to the GCE instance. -----------------------------
# Least privilege: can write to the backup bucket, read the one server
# password secret, and write logs/metrics. Deliberately has NO compute.*
# permissions - the idle-monitor stops the VM by shutting down the guest
# OS (`shutdown -h now`), which GCE detects and reflects as a stop, so no
# API-level stop permission is ever needed.

resource "google_service_account" "valheim_vm" {
  account_id   = "valheim-vm"
  display_name = "Valheim GCE instance"
  project      = var.project_id
}

resource "google_storage_bucket_iam_member" "vm_backup_bucket_writer" {
  bucket = google_storage_bucket.valheim_backups.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.valheim_vm.email}"
}

resource "google_secret_manager_secret_iam_member" "vm_password_accessor" {
  secret_id = google_secret_manager_secret.server_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.valheim_vm.email}"
}

resource "google_project_iam_member" "vm_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.valheim_vm.email}"
}

resource "google_project_iam_member" "vm_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.valheim_vm.email}"
}

# --- valheim-start-trigger: attached to the Cloud Run service. -------------
# Least privilege: can only start/inspect the one Valheim instance. No
# storage or secret access - it never needs to touch the world data.

resource "google_service_account" "start_trigger" {
  account_id   = "valheim-start-trigger"
  display_name = "Valheim Cloud Run start-trigger"
  project      = var.project_id
}

resource "google_project_iam_custom_role" "start_valheim_instance" {
  role_id     = "valheimStartInstance"
  project     = var.project_id
  title       = "Start Valheim Instance"
  description = "Minimal permissions to start and check the status of the Valheim GCE instance."
  permissions = [
    "compute.instances.start",
    "compute.instances.get",
    "compute.zoneOperations.get",
  ]
}

# Scoped with an IAM condition to the single Valheim instance resource,
# rather than granting project-wide compute.instanceAdmin.
resource "google_project_iam_member" "trigger_can_start_instance" {
  project = var.project_id
  role    = google_project_iam_custom_role.start_valheim_instance.id
  member  = "serviceAccount:${google_service_account.start_trigger.email}"

  condition {
    title       = "only-valheim-instance"
    description = "Restrict to the single Valheim server instance."
    expression  = "resource.name == \"projects/${var.project_id}/zones/${var.zone}/instances/${var.instance_name}\""
  }
}
