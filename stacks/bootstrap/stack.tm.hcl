stack {
  name        = "bootstrap"
  description = "One-time bootstrap: creates the GCS bucket used for the valheim stack's Terraform remote state. Applied once, by hand, with local state (see README.md in this directory)."
  id          = "bootstrap-tfstate"
}
