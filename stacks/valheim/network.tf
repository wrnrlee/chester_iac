# Uses the project's default VPC network to keep this stack simple. If you
# don't want a default network, swap `network = "default"` below for a
# reference to your own google_compute_network resource.

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

  description = "Valheim game + query (Steam A2S) ports. Must stay open to the internet for players to connect."
}

resource "google_compute_firewall" "valheim_ssh_iap" {
  name    = "allow-valheim-ssh-iap"
  network = "default"
  project = var.project_id

  direction     = "INGRESS"
  source_ranges = var.ssh_source_ranges
  target_tags   = ["valheim-server"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  description = "SSH restricted to IAP TCP forwarding range by default - no direct public SSH. Use `gcloud compute ssh --tunnel-through-iap`."
}
