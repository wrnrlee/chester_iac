# One set of firewall rules covers every server: they target the
# "valheim-server" network tag that each server VM carries.
# Uses the project's default VPC network.

resource "google_compute_firewall" "valheim_game" {
  name    = "allow-valheim-game"
  network = "default"
  project = var.project_id

  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["valheim-server"]

  allow {
    protocol = "udp"
    ports    = ["2456-2457"]
  }

  description = "Valheim game + query ports. Must stay open for players to connect."
}

resource "google_compute_firewall" "valheim_ssh_iap" {
  name    = "allow-valheim-ssh-iap"
  network = "default"
  project = var.project_id

  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["valheim-server"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  description = "SSH only via IAP TCP forwarding (gcloud compute ssh --tunnel-through-iap)."
}

# Shared by all start-triggers; each server binds it with an IAM condition
# limited to its own instance.
resource "google_project_iam_custom_role" "start_valheim_instance" {
  role_id     = "valheimStartInstance"
  project     = var.project_id
  title       = "Start Valheim Instance"
  description = "Minimal permissions to start and check the status of a Valheim GCE instance."
  permissions = [
    "compute.instances.start",
    "compute.instances.get",
    "compute.zoneOperations.get",
  ]
}

output "start_instance_role_id" {
  value = google_project_iam_custom_role.start_valheim_instance.id
}
