# The server password is stored in Secret Manager rather than in plain
# instance metadata or Terraform state as a readable value baked into a
# resource other than the secret version itself. Supply it at apply time,
# e.g.:
#   terraform apply -var="server_password=..." ...
# or via a TF_VAR_server_password environment variable / a gitignored
# *.auto.tfvars file - never commit it.

variable "server_password" {
  description = "Valheim server join password. Must be at least 5 characters (Valheim requirement). Stored in Secret Manager, not in plaintext metadata."
  type        = string
  sensitive   = true
}

resource "google_secret_manager_secret" "server_password" {
  secret_id = "${var.instance_name}-server-password"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "server_password" {
  secret      = google_secret_manager_secret.server_password.id
  secret_data = var.server_password
}
