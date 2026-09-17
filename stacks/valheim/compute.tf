resource "google_compute_address" "valheim_static_ip" {
  name    = "${var.instance_name}-ip"
  project = var.project_id
  region  = var.region
}

resource "google_compute_instance" "valheim" {
  name         = var.instance_name
  project      = var.project_id
  zone         = var.zone
  machine_type = var.machine_type
  tags         = ["valheim-server"]

  # Guest-initiated shutdown (from the idle-monitor) is what stops this
  # instance; this option just controls behavior if someone stops it from
  # the console/API instead, and keeps it from being treated as a delete.
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
    # Disk (and everything on it - world saves, docker images) persists
    # across stop/start, which is why the idle-monitor stops rather than
    # deletes the instance.
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.valheim_static_ip.address
    }
  }

  service_account {
    email  = google_service_account.valheim_vm.email
    scopes = ["cloud-platform"] # actual permissions are constrained by IAM roles in iam.tf, not by scope
  }

  metadata = {
    server-name           = var.server_name
    world-name            = var.world_name
    server-public         = var.server_public ? "1" : "0"
    idle-timeout-minutes  = tostring(var.idle_timeout_minutes)
    backup-bucket         = google_storage_bucket.valheim_backups.name
    password-secret-id    = google_secret_manager_secret.server_password.secret_id
    startup-script        = templatefile("${path.module}/scripts/startup.sh.tftpl", {
      idle_monitor_py = file("${path.module}/scripts/idle-monitor.py")
    })
  }

  depends_on = [
    google_secret_manager_secret_iam_member.vm_password_accessor,
    google_storage_bucket_iam_member.vm_backup_bucket_writer,
  ]
}
