# trigger-service

Minimal Cloud Run HTTP service that runs `gcloud compute instances start`
on the Valheim server when hit. Adapted from `example_trigger_code/` in
this repo (same pattern, simplified - no SSH step needed since the
instance's own startup-script starts the Valheim container automatically).

The `INSTANCE_NAME` and `ZONE` environment variables are set by Terraform
(see `stacks/valheim/cloudrun.tf`) - nothing to configure by hand here.

## Build and push

Run this once before the first `terraform apply` of the `valheim` stack
(the Cloud Run service needs an image to reference), and again any time
you change `main.go`:

```sh
cd trigger-service
gcloud artifacts repositories create valheim \
  --repository-format=docker \
  --location=<region> \
  --project=<project-id>   # one-time, or let Terraform's google_artifact_registry_repository create it first

gcloud builds submit \
  --tag <region>-docker.pkg.dev/<project-id>/valheim/trigger-service:latest \
  --project=<project-id>
```

Then set that image URL as `trigger_image` when applying the `valheim`
stack.

## Who can call it

The Cloud Run service is private by default (no `allUsers` invoker
binding) - only the identities listed in the `trigger_invoker_members`
Terraform variable can call it, e.g.:

```sh
gcloud auth print-identity-token | \
  curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" <cloud-run-url>
```
