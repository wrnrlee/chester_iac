# Bootstrap stack

Creates everything the GitHub deploy workflow needs before it can run, in
project `my-user-project-308320`:

- enables the required GCP APIs
- the GCS bucket for the valheim stack's Terraform state
  (`my-user-project-308320-valheim-tfstate`)
- the `valheim` Artifact Registry repo the workflow pushes images to
- a Workload Identity pool/provider that only trusts GitHub Actions tokens
  from `wrnrlee/chester_iac`
- `github-deployer` (can change the project) - usable only by runs on
  `main`/`master`, i.e. after a merge
- `github-planner` (read-only) - used by pull-request plans

It's a chicken-and-egg stack (CI can't create its own credentials), so it's
applied once, by hand, with local state and plain Terraform - no Terramate
needed.

## Usage

```sh
gcloud auth application-default login   # as a project owner
cd stacks/bootstrap
terraform init
terraform apply
```

Then copy the `github_wif_provider` output into the `GCP_WIF_PROVIDER`
repository variable in GitHub (see the top-level README).

The local `terraform.tfstate` it leaves behind is gitignored. Keep it
somewhere safe if you want to change or destroy these resources later.
