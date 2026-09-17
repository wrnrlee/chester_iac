# Generates backend.tf for this stack only. Update global.state_bucket
# below after running the bootstrap stack, rather than editing the
# generated backend.tf directly - Terramate will overwrite it.

globals {
  # Set this to the `state_bucket_name` output from stacks/bootstrap.
  state_bucket = "REPLACE_WITH_BOOTSTRAP_STATE_BUCKET"
}

generate_hcl "_generated_backend.tf" {
  content {
    terraform {
      backend "gcs" {
        bucket = global.state_bucket
        prefix = "valheim"
      }
    }
  }
}
