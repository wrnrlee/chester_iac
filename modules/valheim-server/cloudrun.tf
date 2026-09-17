resource "google_cloud_run_v2_service" "start_trigger" {
  name     = "${var.name}-start-trigger"
  project  = var.project_id
  location = var.region

  template {
    service_account = google_service_account.trigger.email

    containers {
      image = var.trigger_image

      env {
        name  = "INSTANCE_NAME"
        value = google_compute_instance.server.name
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

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# Private by default: only var.trigger_invoker_members can call it.
resource "google_cloud_run_v2_service_iam_member" "invokers" {
  for_each = toset(var.trigger_invoker_members)

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.start_trigger.name
  role     = "roles/run.invoker"
  member   = each.value
}
