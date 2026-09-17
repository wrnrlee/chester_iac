# Root Terramate configuration.
#
# This project has a single deployable stack today (stacks/valheim) plus a
# one-time bootstrap stack (stacks/bootstrap) that creates the GCS bucket
# used for Terraform remote state. Terramate is used here mainly for code
# generation - the provider block below is generated into every stack so
# it never has to be hand-duplicated - and to make it easy to add more
# stacks later (another environment, another game server) without
# re-deriving this wiring.

terramate {
  config {
    git {
      default_branch = "main"
      default_remote = "origin"
    }
  }
}

globals {
  # Edit these for your project (Terramate globals don't read shell/CI
  # env vars automatically - unlike `terraform apply`, which does pick up
  # TF_VAR_* env vars for the variables declared in variables.tf).
  project_id = "REPLACE_WITH_YOUR_GCP_PROJECT_ID"
  region     = "us-central1"
  zone       = "us-central1-a"
}

generate_hcl "_generated_provider.tf" {
  content {
    terraform {
      required_version = ">= 1.5.0"

      required_providers {
        google = {
          source  = "hashicorp/google"
          version = "~> 5.0"
        }
      }
    }

    provider "google" {
      project = global.project_id
      region  = global.region
      zone    = global.zone
    }
  }
}
