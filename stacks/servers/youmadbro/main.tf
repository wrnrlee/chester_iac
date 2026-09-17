module "server" {
  source = "../../../modules/valheim-server"

  name       = "youmadbro"
  world_name = "youmadbro"
  # Optional settings (see modules/valheim-server/variables.tf):
  # display_name         = "Name in the server browser"
  # machine_type         = "e2-standard-2"
  # idle_timeout_minutes = 30

  # Common inputs - the same in every server stack.
  project_id              = var.project_id
  region                  = var.region
  zone                    = var.zone
  trigger_image           = var.trigger_image
  trigger_invoker_members = var.trigger_invoker_members
  server_password         = lookup(var.server_passwords, "youmadbro", "")
  start_instance_role_id  = "projects/${var.project_id}/roles/valheimStartInstance"
}

output "server" {
  value = module.server
}
