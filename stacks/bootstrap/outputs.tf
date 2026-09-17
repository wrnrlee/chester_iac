output "state_bucket_name" {
  description = "GCS bucket used as the valheim stack's Terraform backend."
  value       = google_storage_bucket.tf_state.name
}

output "github_wif_provider" {
  description = "Set this as the GCP_WIF_PROVIDER repository variable in GitHub."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "github_deployer_service_account" {
  description = "Service account the GitHub workflow impersonates."
  value       = google_service_account.github_deployer.email
}

output "artifact_registry_repo" {
  description = "Docker repo the workflow pushes the trigger-service image to."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.valheim.repository_id}"
}

output "github_planner_service_account" {
  description = "Read-only service account pull-request plans impersonate."
  value       = google_service_account.github_planner.email
}
