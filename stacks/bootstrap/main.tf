# Bootstrap: everything CI needs to exist *before* it can run.
#   - required GCP APIs
#   - the GCS bucket for the valheim stack's Terraform state
#   - the Artifact Registry repo CI pushes the trigger-service image to
#   - keyless GitHub Actions -> GCP auth (Workload Identity Federation)
#     plus a deployer account (main/master only) and a read-only planner
#     account (pull requests)
#
# Applied once, by hand, with local state. This stack is self-contained
# (it does not use the Terramate-generated provider) so it can be applied
# with plain `terraform` and no Terramate install.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  # Intentionally no backend block: this stack applies with local state.
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  apis = [
    "artifactregistry.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ]

  # What the valheim stack creates: VM + firewall, buckets, a secret,
  # service accounts, a custom role, project IAM bindings, Cloud Run.
  deployer_roles = [
    "roles/compute.admin",
    "roles/storage.admin",
    "roles/secretmanager.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/iam.roleAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/run.admin",
    "roles/artifactregistry.writer",
    "roles/serviceusage.serviceUsageConsumer",
  ]

  # Read-only account used by pull-request plans. It can read everything
  # Terraform refreshes (including IAM policies and the server-password
  # secret payload) but cannot change anything.
  planner_roles = [
    "roles/viewer",
    "roles/iam.securityReviewer",
    "roles/secretmanager.secretAccessor",
    "roles/serviceusage.serviceUsageConsumer",
  ]

  # Only pushes to these branches may impersonate the deployer.
  deploy_refs = ["refs/heads/main", "refs/heads/master"]
}

resource "google_project_service" "apis" {
  for_each           = toset(local.apis)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# --- Terraform state ---------------------------------------------------

resource "google_storage_bucket" "tf_state" {
  name                        = "${var.project_id}-valheim-tfstate"
  location                    = var.region
  project                     = var.project_id
  uniform_bucket_level_access = true
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 10
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.apis]
}

# --- Container images ----------------------------------------------------

resource "google_artifact_registry_repository" "valheim" {
  project       = var.project_id
  location      = var.region
  repository_id = "valheim"
  format        = "DOCKER"
  description   = "Container images for the Valheim start-trigger Cloud Run service."

  depends_on = [google_project_service.apis]
}

# --- GitHub Actions deployer (keyless) ------------------------------------

resource "google_service_account" "github_deployer" {
  account_id   = "github-deployer"
  display_name = "GitHub Actions deployer (chester_iac)"
  project      = var.project_id

  depends_on = [google_project_service.apis]
}

# Note: projectIamAdmin makes this account effectively owner-equivalent,
# which is why only main/master runs of this repo can impersonate it.
resource "google_project_iam_member" "deployer" {
  for_each = toset(local.deployer_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.github_deployer.email}"
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"

  depends_on = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
    # e.g. "wrnrlee/chester_iac@refs/heads/main"; PR runs carry
    # refs/pull/<n>/merge, so they can never match a deploy branch.
    "attribute.repo_ref" = "assertion.repository + \"@\" + assertion.ref"
  }

  # Reject tokens from any other repository outright.
  attribute_condition = "assertion.repository == \"${var.github_repository}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Deployer (owner-equivalent): only workflow runs on main/master, i.e. after
# a PR is merged. Pull-request runs are rejected here even from this repo.
resource "google_service_account_iam_member" "github_can_impersonate_deployer" {
  for_each           = toset(local.deploy_refs)
  service_account_id = google_service_account.github_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repo_ref/${var.github_repository}@${each.value}"
}

# --- GitHub Actions planner (read-only, used by pull requests) -------------

resource "google_service_account" "github_planner" {
  account_id   = "github-planner"
  display_name = "GitHub Actions read-only planner (chester_iac)"
  project      = var.project_id

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "planner" {
  for_each = toset(local.planner_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.github_planner.email}"
}

resource "google_storage_bucket_iam_member" "planner_reads_state" {
  bucket = google_storage_bucket.tf_state.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.github_planner.email}"
}

# Any run from this repo (including PRs from its own branches) may plan.
resource "google_service_account_iam_member" "github_can_impersonate_planner" {
  service_account_id = google_service_account.github_planner.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}
