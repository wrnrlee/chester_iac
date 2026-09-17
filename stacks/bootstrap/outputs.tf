output "state_bucket_name" {
  description = "Name of the GCS bucket to use as the valheim stack's Terraform backend bucket."
  value       = google_storage_bucket.tf_state.name
}
