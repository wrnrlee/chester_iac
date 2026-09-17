variable "project_id" {
  description = "GCP project ID that will own the Terraform state bucket."
  type        = string
}

variable "region" {
  description = "Region for the state bucket."
  type        = string
  default     = "us-central1"
}
