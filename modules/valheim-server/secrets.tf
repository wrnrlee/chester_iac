resource "google_secret_manager_secret" "server_password" {
  secret_id = "${var.name}-server-password"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "server_password" {
  secret      = google_secret_manager_secret.server_password.id
  secret_data = var.server_password
}
