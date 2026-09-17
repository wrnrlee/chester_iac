resource "google_compute_address" "static_ip" {
  name    = "${var.name}-ip"
  project = var.project_id
  region  = var.region
}

resource "google_compute_instance" "server" {
  name         = var.name
  project      = var.project_id
  zone         = var.zone
  machine_type = var.machine_type

  # Matches the shared firewall rules in stacks/shared.
  tags = ["valheim-server"]

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
    # The disk (world saves, Docker images) persists across stop/start,
    # which is why the idle-monitor stops rather than deletes the VM.
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.static_ip.address
    }
  }

  service_account {
    email  = google_service_account.vm.email
    scopes = ["cloud-platform"] # real permissions come from the IAM bindings in iam.tf
  }

  metadata = {
    server-name          = local.display_name
    world-name           = local.world_name
    server-public        = var.server_public ? "1" : "0"
    idle-timeout-minutes = tostring(var.idle_timeout_minutes)
    backup-bucket        = google_storage_bucket.backups.name
    password-secret-id   = google_secret_manager_secret.server_password.secret_id
    startup-script = templatefile("${path.module}/scripts/startup.sh.tftpl", {
      idle_monitor_py = file("${path.module}/scripts/idle-monitor.py")
    })
  }

  depends_on = [
    google_secret_manager_secret_iam_member.vm_password_accessor,
    google_storage_bucket_iam_member.vm_backup_writer,
  ]
}
