output "instance_name" {
  description = "Name of the GCE instance (for gcloud compute commands)."
  value       = google_compute_instance.server.name
}

output "server_ip" {
  description = "Static external IP. Players join on port 2456."
  value       = google_compute_address.static_ip.address
}

output "world_name" {
  description = "World the server loads."
  value       = local.world_name
}

output "backup_bucket" {
  description = "Bucket receiving world backups before each idle shutdown."
  value       = google_storage_bucket.backups.name
}

output "start_trigger_url" {
  description = "URL of the Cloud Run service that starts this server."
  value       = google_cloud_run_v2_service.start_trigger.uri
}
