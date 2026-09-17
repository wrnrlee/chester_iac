# chester_iac — Valheim servers on GCP

Terraform (orchestrated with Terramate) that runs any number of Valheim
dedicated servers in GCP project **`my-user-project-308320`**. Each server:

- runs on its own GCE VM with its own static IP, world backups, password
  and start button;
- backs up its world to Cloud Storage and **shuts itself down after 30
  minutes with no players**, so it isn't billed for compute while idle;
- starts the game automatically whenever the VM starts again.

Current servers: **brotherskaraminkov**, **youmadbro**.

## Layout

```
modules/valheim-server/      everything for ONE server (VM, IP, bucket, secret, IAM, Cloud Run)
  scripts/                   VM startup script + idle monitor
stacks/bootstrap/            one-time setup, applied by hand (state bucket, CI identities, APIs)
stacks/shared/               firewall rules + custom role used by every server
stacks/servers/<name>/       one small stack per server: settings only
trigger-service/             Cloud Run "start the server" service (Go)
terramate.tm.hcl             project/region globals; generates provider, backend and inputs per stack
.github/workflows/           plan on PR, deploy after merge
.github/scripts/             per-stack plan/apply logic used by the workflows
```

Every stack has its own Terraform state
(`gs://my-user-project-308320-valheim-tfstate/<stack path>/`), so servers
can be planned, deployed and destroyed independently.

## Adding a server

1. Copy an existing server folder and rename it, e.g.
   `stacks/servers/youmadbro` -> `stacks/servers/newserver`.
2. In the copy, replace the old name with the new one in both files:
   - `stack.tm.hcl`: `name`, `description`, `id`
   - `main.tf`: `name`, `world_name`, and the key in `lookup(var.server_passwords, "...")`

   Names must be 3-20 characters of lowercase letters, digits and hyphens.
3. Add a password for it to the `VALHEIM_SERVER_PASSWORDS` secret (see below).
4. Open a PR, check the plan comment, merge.

Per-server options (display name, machine type, idle timeout, public
listing) are commented in each `main.tf`; the full list is in
`modules/valheim-server/variables.tf`.

**Removing a server:** deleting its folder does *not* destroy anything - CI
never runs `terraform destroy`. Destroy it by hand first (with project
owner credentials): `cd stacks/servers/<name> && terramate generate && terraform init && terraform destroy`.
Its backup bucket is kept unless `backup_bucket_force_destroy = true`.

## Deployment (GitHub Actions)

| When | Workflow | What happens |
|---|---|---|
| Pull request into main/master | `plan-valheim.yml` | Builds the trigger image (no push), runs a **read-only** `terraform plan` for each affected stack, posts them as one PR comment. Nothing changes in GCP. |
| Merge / push to main/master | `deploy-valheim.yml` | Pushes the trigger image, then plans and applies each affected stack, `shared` first. |
| Manual run (Actions tab, main/master) | `deploy-valheim.yml` | Re-deploys every stack. |

**Which stacks run:** if a change only touches files inside
`stacks/shared/` or `stacks/servers/<name>/`, only those stacks run. If it
touches anything shared by all servers - `modules/`, `trigger-service/`,
`terramate.tm.hcl` or `.github/` - every stack runs.

This is enforced in GCP, not just in the workflow files: the owner-level
`github-deployer` account can only be used by runs on `main`/`master`.
Pull requests use the read-only `github-planner`. Pull requests from forks
get no secrets or GCP token, so they don't plan.

Recommended: a branch protection rule on `main` requiring the
**Build check and plan** check.

### One-time setup

1. **Apply the bootstrap stack** with project-owner credentials - see
   `stacks/bootstrap/README.md`.
2. **Add these in GitHub** (repo Settings -> Secrets and variables -> Actions, repository level):

   | Type | Name | Value |
   |---|---|---|
   | Variable | `GCP_WIF_PROVIDER` | bootstrap output `github_wif_provider` |
   | Secret | `VALHEIM_SERVER_PASSWORDS` | JSON with one password per server, e.g. `{"brotherskaraminkov": "pass-one", "youmadbro": "pass-two"}` |
   | Variable | `TRIGGER_INVOKER_MEMBERS` | optional, e.g. `["user:you@gmail.com"]` |

   Passwords must be 5+ characters. The workflows fail early, naming the
   server, if one is missing.
3. **Open a PR, review the plan, merge.** First boot of a new VM takes a few
   minutes (Docker + Cloud SDK install, image pull). Watch it with:
   ```sh
   gcloud compute ssh <server> --zone us-central1-a --project my-user-project-308320 \
     --tunnel-through-iap --command "sudo journalctl -u google-startup-scripts -f"
   ```
4. **Connect:** in Valheim, "join by IP" using the server's IP (in the deploy
   run summary, or `gcloud compute addresses describe <server>-ip --region us-central1`),
   port `2456`.

The stacks use the project's `default` VPC network.

## Per-server names

For a server called `<server>`:

| Thing | Name |
|---|---|
| VM | `<server>` |
| Static IP | `<server>-ip` |
| Backup bucket | `my-user-project-308320-<server>-backups` |
| Password secret | `<server>-server-password` |
| Start trigger (Cloud Run) | `<server>-start-trigger` |
| Service accounts | `<server>-vm`, `<server>-trigger` |

## Importing an existing world

A Valheim world is two files: `<World>.fwl` and `<World>.db`. On Windows
they're in `%USERPROFILE%\AppData\LocalLow\IronGate\Valheim\worlds_local\`.
If the world is saved to Steam Cloud, use **Manage saves** in the game to
move it to local first.

1. **Make the server load that world name:** set `world_name` in
   `stacks/servers/<server>/main.tf` and merge. (Files can be renamed on
   upload, as below, so the local names don't have to match.)
2. **Upload and swap** (bash, from your PC; this starts the server):
   ```bash
   SERVER=brotherskaraminkov
   WORLD=brotherskaraminkov          # the world_name from main.tf
   PROJECT_ID=my-user-project-308320
   ZONE=us-central1-a
   BUCKET="$PROJECT_ID-$SERVER-backups"
   SRC_DB="/c/path/to/MyWorld.db"    # local files, any name
   SRC_FWL="/c/path/to/MyWorld.fwl"

   gcloud storage cp "$SRC_DB"  "gs://$BUCKET/worlds_local/$WORLD.db"
   gcloud storage cp "$SRC_FWL" "gs://$BUCKET/worlds_local/$WORLD.fwl"

   gcloud compute instances start "$SERVER" --zone "$ZONE" --project "$PROJECT_ID"
   gcloud compute ssh "$SERVER" --zone "$ZONE" --project "$PROJECT_ID" --tunnel-through-iap --command "
     sudo docker stop valheim
     sudo rm -f /opt/valheim/config/worlds_local/$WORLD.*
     sudo gcloud storage cp 'gs://$BUCKET/worlds_local/$WORLD.*' /opt/valheim/config/worlds_local/
     sudo google_metadata_script_runner startup
   "
   ```
   The last line re-runs the startup script, which restarts the game.

Do the swap on the VM, not only in the bucket: at every idle shutdown the
server copies its own world to the bucket, which would overwrite an upload
of the same name. Run both commands within 30 minutes of the server
starting. The bucket keeps overwritten versions for 30 days.

## Turning a server back on

After 30 idle minutes a server stops itself. To start it again:

- `gcloud compute instances start <server> --zone us-central1-a --project my-user-project-308320`, or
- call its start trigger as one of `TRIGGER_INVOKER_MEMBERS`:
  ```sh
  URL=$(gcloud run services describe <server>-start-trigger --region us-central1 --project my-user-project-308320 --format 'value(status.url)')
  curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" "$URL"
  ```

## Testing idle shutdown without waiting 30 minutes

SSH in (`gcloud compute ssh <server> ... --tunnel-through-iap`), then:
```sh
echo 0 | sudo tee /opt/valheim/last_active
sudo systemctl start valheim-idle-monitor.service
sudo journalctl -u valheim-idle-monitor -f
```
You should see "players connected: 0", a backup to
`gs://my-user-project-308320-<server>-backups/worlds_local/`, and the
instance should show as stopped shortly after. If you only ever see
"A2S query failed", the monitor can't read the player count and will never
shut the server down.

## Cost notes

While stopped, each server still costs its boot disk (50GB pd-balanced by
default), its reserved static IP, and a few MB of backups. Compute is only
billed while the VM runs.
