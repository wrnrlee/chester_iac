# valheim-server module

Everything for one Valheim server: VM, static IP, backup bucket, password
secret, two least-privilege service accounts, and a Cloud Run start-trigger.
All names derive from `name`, so any number of servers can share a project.

Not used directly - each server is a stack under `stacks/servers/` that
calls this module. Requires `stacks/shared` (firewall rules and the
`valheimStartInstance` custom role) to be applied first.
