resource "google_artifact_registry_repository" "valheim" {
  project       = var.project_id
  location      = var.region
  repository_id = "valheim"
  format        = "DOCKER"
  description   = "Container images for the Valheim start-trigger Cloud Run service."
}

resource "google_cloud_run_v2_service" "start_trigger" {
  name     = "${var.instance_name}-start-trigger"
  project  = var.project_id
  location = var.region

  template {
    service_account = google_service_account.start_trigger.email

    containers {
      image = var.trigger_image

      env {
        name  = "INSTANCE_NAME"
        value = var.instance_name
      }
      env {
        name  = "ZONE"
        value = var.zone
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "256Mi"
        }
      }
    }

    scaling {
      max_instance_count = 2
    }
  }

  # Traffic is 100% to latest by default; kept explicit for clarity.
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [google_artifact_registry_repository.valheim]
}

# Private by default: only the identities listed in
# var.trigger_invoker_members can call this service. Left empty, nobody
# but the project owner/editor can invoke it via IAM.
resource "google_cloud_run_v2_service_iam_member" "invokers" {
  for_each = toset(var.trigger_invoker_members)

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.start_trigger.name
  role     = "roles/run.invoker"
  member   = each.value
}
