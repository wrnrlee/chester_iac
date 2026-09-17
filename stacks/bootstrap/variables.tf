variable "project_id" {
  description = "GCP project ID that the Valheim stack deploys into."
  type        = string
  default     = "my-user-project-308320"
}

variable "region" {
  description = "Region for the state bucket and Artifact Registry repo."
  type        = string
  default     = "us-central1"
}

variable "github_repository" {
  description = "GitHub repo (owner/name) allowed to deploy via Workload Identity Federation. Nothing else can impersonate the deployer service account."
  type        = string
  default     = "wrnrlee/chester_iac"
}
