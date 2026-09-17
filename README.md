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

## Deployment (GitHub Actions)

Deploys to GCP project **`my-user-project-308320`** only after code reaches
`main`/`master`:

| When                         | Workflow             | What happens |
|------------------------------|----------------------|--------------|
| Pull request into main/master | `plan-valheim.yml`   | Builds the trigger image (no push), runs a **read-only** `terraform plan`, posts it as a PR comment. Nothing changes in GCP. |
| Merge / push to main/master  | `deploy-valheim.yml` | Pushes the image tagged with the commit SHA, then `terraform plan` + `apply`. |

Both run only when `stacks/valheim/`, `trigger-service/`,
`terramate.tm.hcl` or the workflows change. Deploys are serialized in merge
order, and you can re-run one by hand from the Actions tab (main/master only).

This is enforced in GCP, not just in the workflow files: the owner-level
`github-deployer` account can only be used by runs on `refs/heads/main` or
`refs/heads/master`. Pull requests use `github-planner`, which is read-only,
so a PR can't change the project even if its workflow file is edited.
Pull requests from forks get no secrets or GCP token, so they don't plan.

Recommended: in GitHub, add a branch protection rule on `main` that requires
the **Build check and plan** check to pass before merging.

### One-time setup

1. **Apply the bootstrap stack** from your own machine (needs `gcloud auth
   application-default login` as a project owner). It enables the APIs and
   creates the state bucket, Artifact Registry repo, and the deployer
   identity - see `stacks/bootstrap/README.md`.
   ```sh
   cd stacks/bootstrap
   terraform init
   terraform apply
   ```
2. **Add these in GitHub** (repo Settings -> Secrets and variables -> Actions):

   | Type     | Name                      | Value                                                |
   |----------|---------------------------|------------------------------------------------------|
   | Variable | `GCP_WIF_PROVIDER`        | bootstrap output `github_wif_provider`               |
   | Secret   | `VALHEIM_SERVER_PASSWORD` | the Valheim join password (5+ characters)            |
   | Variable | `TRIGGER_INVOKER_MEMBERS` | optional, e.g. `["user:you@gmail.com"]`              |

3. **Open a pull request** to review the plan, then **merge it**. The deploy
   run creates everything; first boot of the VM takes a few minutes (Docker + Cloud SDK install, image pull):
   ```sh
   gcloud compute ssh valheim-server --zone us-central1-a --tunnel-through-iap \
     --project my-user-project-308320 \
     --command "sudo journalctl -u google-startup-scripts -f"
   ```

4. **Connect**: in Valheim, "join by IP" using the server IP from the run
   summary, port `2456`, and your password.

The stack uses the project's `default` VPC network. If your project doesn't
have one, create it or change `network` in `stacks/valheim/network.tf` and
`compute.tf`.

## Importing an existing world

A Valheim world is two files named after the world: `<World>.fwl` and
`<World>.db`. On Windows they're in
`%USERPROFILE%\AppData\LocalLow\IronGate\Valheim\worlds_local\`. If
the world is saved to Steam Cloud, use **Manage saves** in the game to move
it to local first.

1. **Make the server load that world name.** Set the default of
   `world_name` in `stacks/valheim/variables.tf` to your world's file name
   (without the extension), then open a PR and merge it.
2. **Upload and swap the files** (bash, from your PC; the server must be running):
   ```bash
   PROJECT_ID=my-user-project-308320
   ZONE=us-central1-a
   BUCKET=my-user-project-308320-valheim-backups
   WORLD=MyWorld   # your world's file name, same as world_name
   SRC="$HOME/AppData/LocalLow/IronGate/Valheim/worlds_local"

   gcloud storage cp "$SRC/$WORLD.fwl" "$SRC/$WORLD.db" "gs://$BUCKET/worlds_local/"

   gcloud compute instances start valheim-server --zone "$ZONE" --project "$PROJECT_ID"
   gcloud compute ssh valheim-server --zone "$ZONE" --project "$PROJECT_ID" --tunnel-through-iap --command "
     sudo docker stop valheim
     sudo rm -f /opt/valheim/config/worlds_local/$WORLD.*
     sudo gcloud storage cp 'gs://$BUCKET/worlds_local/$WORLD.*' /opt/valheim/config/worlds_local/
     sudo google_metadata_script_runner startup
   "
   ```
   The last line re-runs the startup script, which restarts the server with
   the current `world_name` and password.

Do the swap on the VM, not just in the bucket. The server copies its own
world to the bucket at every idle shutdown, which would overwrite an upload
of the same name.

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
