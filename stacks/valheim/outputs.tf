output "server_ip" {
  description = "Static external IP of the Valheim server. Give this to players (with the game port, 2456/udp) once the server is running."
  value       = google_compute_address.valheim_static_ip.address
}

output "backup_bucket" {
  description = "GCS bucket receiving world backups before each idle shutdown."
  value       = google_storage_bucket.valheim_backups.name
}

output "start_trigger_url" {
  description = "URL of the Cloud Run service that starts the Valheim instance. Private by default - see trigger_invoker_members."
  value       = google_cloud_run_v2_service.start_trigger.uri
}

output "instance_name" {
  description = "Name of the Valheim GCE instance (for gcloud compute ... commands)."
  value       = google_compute_instance.valheim.name
}
