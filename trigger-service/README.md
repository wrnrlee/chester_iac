# trigger-service

Minimal Cloud Run HTTP service that runs `gcloud compute instances start`
on the Valheim server when hit. Adapted from `example_trigger_code/` in
this repo (same pattern, simplified - no SSH step needed since the
instance's own startup-script starts the Valheim container automatically).

The `INSTANCE_NAME` and `ZONE` environment variables are set by Terraform
(see `modules/valheim-server/cloudrun.tf`) - nothing to configure by hand here.

## Build and push

You don't need to do this by hand: the GitHub workflow builds this image
and pushes it to
`us-central1-docker.pkg.dev/my-user-project-308320/valheim/trigger-service:<commit sha>`
on every deploy, then passes that tag to Terraform. To build it locally anyway:

```sh
gcloud builds submit trigger-service \
  --tag us-central1-docker.pkg.dev/my-user-project-308320/valheim/trigger-service:manual \
  --project my-user-project-308320
```

## Who can call it

The Cloud Run service is private by default (no `allUsers` invoker
binding) - only the identities listed in the `trigger_invoker_members`
Terraform variable can call it, e.g.:

```sh
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" <cloud-run-url>
```
