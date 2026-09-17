# chester_iac — Valheim server on GCP

Terraform (orchestrated with Terramate) that deploys a Valheim dedicated
server on a single GCE VM, which:

- backs up the world to Cloud Storage and shuts itself down after **30
  minutes with no players connected**, so it isn't burning compute money
  while idle;
- comes back up (with the game auto-starting) whenever the VM is started
  again, either manually or via the included Cloud Run "start" endpoint.

## Layout

- `stacks/bootstrap/` — one-time: creates the GCS bucket Terraform uses as
  a remote-state backend for everything else. Applied once, by hand.
- `stacks/valheim/` — the actual deployment: the VM, firewall rules, the
  world-backup bucket, the server-password secret, IAM, and the Cloud Run
  start-trigger.
- `trigger-service/` — source for the Cloud Run start-trigger container
  (adapted from `example_trigger_code/`, kept here for reference).
- `terramate.tm.hcl` / `stacks/*/*.tm.hcl` — Terramate config; generates
  each stack's `provider.tf` / `backend.tf` so they aren't hand-duplicated.

## First-time setup

1. **Enable the required GCP APIs** on your project (once):
   ```sh
   gcloud services enable \
     compute.googleapis.com \
     secretmanager.googleapis.com \
     run.googleapis.com \
     artifactregistry.googleapis.com \
     cloudbuild.googleapis.com \
     --project=<project-id>
   ```

2. **Bootstrap the Terraform state bucket** — see `stacks/bootstrap/README.md`.
   Note the `state_bucket_name` output and edit
   `stacks/valheim/backend.tm.hcl`, setting `global.state_bucket` to that
   bucket name, before running `terramate generate`.

3. **Build and push the trigger-service image** — see
   `trigger-service/README.md`. You need the resulting image URL for the
   `trigger_image` variable below.

4. **Generate and apply the `valheim` stack**:
   ```sh
   terramate generate
   cd stacks/valheim
   terraform init
   terraform apply \
     -var="project_id=<project-id>" \
     -var="server_password=<a real password, 5+ chars>" \
     -var="trigger_image=<image URL from step 3>" \
     -var='trigger_invoker_members=["user:you@example.com"]'
   ```

   First boot takes a few minutes (installs Docker + the Cloud SDK, then
   pulls the Valheim image). Check progress with:
   ```sh
   gcloud compute ssh <instance_name output> --zone <zone> --tunnel-through-iap \
     --command "sudo journalctl -u google-startup-scripts -f"
   ```

5. **Connect**: in Valheim, "join by IP" using the `server_ip` Terraform
   output and port `2456`, with the password you set above.

## Turning it back on

Once idle for 30 minutes, the instance stops itself. To start it again:

- **Manually**: `gcloud compute instances start <instance_name> --zone <zone>`, or
- **Via the trigger**: call the `start_trigger_url` output as one of the
  identities in `trigger_invoker_members`, e.g.
  ```sh
  curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" <start_trigger_url>
  ```

Either way, the VM's startup-script re-starts the Valheim container
automatically — nothing else to do.

## Testing the idle-shutdown path without waiting 30 minutes

SSH in (via IAP) and either:
- temporarily lower the timeout: `sudo systemctl edit valheim-idle-monitor.service`
  and add `Environment=IDLE_TIMEOUT_MINUTES=1`, then
  `sudo systemctl daemon-reload && sudo systemctl start valheim-idle-monitor.service`, or
- force it: `echo 0 | sudo tee /opt/valheim/last_active` then
  `sudo systemctl start valheim-idle-monitor.service` and watch
  `sudo journalctl -u valheim-idle-monitor -f`.

Confirm a new object lands in `gs://<backup_bucket>/worlds_local/` and the
instance shows as `TERMINATED` in the GCP console shortly after.

## Cost notes

While stopped you still pay for: the boot disk (`boot_disk_size_gb`, default
50GB pd-balanced), the reserved static IP (a few dollars/month), and world
backups in GCS (typically tens of MB — negligible). Compute (the biggest
cost) only accrues while the VM is running.
