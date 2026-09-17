# Root Terramate configuration.
#
#   stacks/bootstrap        one-time, applied by hand (own provider, local state)
#   stacks/shared           firewall rules + custom role used by every server
#   stacks/servers/<name>   one stack per Valheim server
#
# Terramate generates the provider, backend and common input variables for
# every stack tagged "valheim", so a server stack only contains its own
# settings. Each stack gets its own state file, keyed by its path.

terramate {
  config {
    git {
      default_branch = "main"
      default_remote = "origin"
    }
  }
}

globals {
  project_id   = "my-user-project-308320"
  region       = "us-central1"
  zone         = "us-central1-a"
  state_bucket = "my-user-project-308320-valheim-tfstate"
}

generate_hcl "_generated_provider.tf" {
  condition = tm_contains(terramate.stack.tags, "valheim")

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

generate_hcl "_generated_backend.tf" {
  condition = tm_contains(terramate.stack.tags, "valheim")

  content {
    terraform {
      backend "gcs" {
        bucket = global.state_bucket
        # e.g. stacks/servers/youmadbro -> .../stacks/servers/youmadbro/default.tfstate
        prefix = tm_trimprefix(terramate.stack.path.absolute, "/")
      }
    }
  }
}

# Inputs every valheim stack receives. Values come from TF_VAR_* environment
# variables set by the GitHub workflows (or the defaults below).
generate_hcl "_generated_inputs.tf" {
  condition = tm_contains(terramate.stack.tags, "valheim")

  content {
    variable "project_id" {
      type    = string
      default = global.project_id
    }

    variable "region" {
      type    = string
      default = global.region
    }

    variable "zone" {
      type    = string
      default = global.zone
    }
  }
}

# Extra inputs for server stacks only.
generate_hcl "_generated_server_inputs.tf" {
  condition = tm_contains(terramate.stack.tags, "valheim-server")

  content {
    variable "trigger_image" {
      description = "Start-trigger container image, set by the deploy workflow."
      type        = string
    }

    variable "trigger_invoker_members" {
      description = "IAM members allowed to call start-triggers, from the TRIGGER_INVOKER_MEMBERS repo variable."
      type        = list(string)
      default     = []
    }

    variable "server_passwords" {
      description = "Map of server name to join password, from the VALHEIM_SERVER_PASSWORDS secret."
      type        = map(string)
      sensitive   = true
      default     = {}
    }
  }
}
