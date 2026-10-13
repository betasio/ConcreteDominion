# Single-server private multiplayer deployment

This prepares a **private playtest**, not a public commercial launch. It runs the
real faction/PvP/rally/progression backend behind HTTPS. No hosting account or
domain is created, and nothing is deployed publicly by committing these files.
Development account/recovery keys remain the identity mechanism. Verified sign-in,
account/session management and abuse controls are still needed for public release.

## Host and DNS

Use one Linux VM with Docker Engine + Compose v2, Python 3/pip and Git; start with
2 vCPU / 2 GB RAM and persistent disk. Point a dedicated DNS A record (and AAAA
only if IPv6 works) at it. Allow inbound TCP 80/443 for Caddy certificate issuance
and HTTPS; restrict SSH to your administration network. Do not open port 8765.
Do not put another proxy/CDN in front of this initial stack: client-IP trust assumes
Caddy is the internet-facing proxy. Docker publishes ports independently of some
host firewall tools, so use the provider firewall too.

## Prepare and launch

Run from a checkout of the release commit on the VM:

```sh
python3 deploy/prepare.py --domain multiplayer.YOUR-DOMAIN.com
python3 -m pip download --require-hashes --only-binary=:all: \
  -r server/requirements-deploy.txt --dest server/wheels
# The container build uses only the verified wheel and pinned base image.
docker compose -f deploy/compose.yml build
docker compose -f deploy/compose.yml up -d --wait --wait-timeout 90
curl --fail https://multiplayer.YOUR-DOMAIN.com/healthz
```

`prepare.py` creates ignored `deploy/.env` and a random playtest key, preserving
existing files. The key is never printed. Its host directory is mode 0700; the
file is readable by the non-root API through a read-only Compose secret mount.
Distribute the key privately to testers; do not put it in Git, URLs, screenshots
or logs. A shared key restricts enrollment but is not a replacement for accounts.

The API runs as UID 10001 with a read-only root filesystem. Its SQLite database
and WAL live in the named `game_data` volume. Caddy's certificate storage also
persists in named volumes. Only Caddy publishes ports. The API's trusted-forwarded
headers are safe only while its internal Docker network remains private.
**Use one API instance/process**: it owns the SQLite lock, request quotas and
one-second rally departure worker. Do not scale it with `--scale` or replicas.

## Connect the game

Open **Faction → Online Faction Hub → Account**. Enter the HTTPS address and
playtest key, press **Use this server**, then create or connect a development
account. Keep that account's session and recovery keys securely. Server access
and account tokens stay in memory; enter them again after restarting the game.
Changing servers cancels requests and disconnects the previous account.

Share an account's player ID to invite it into a faction. Use a different faction
and at least two accounts on each side to exercise all six attacks per side.
Wars and prepared rallies award the online war chest and Command XP. Offline
estate saves, solo NPC play and billing remain independent.

## Health and operation

```sh
docker compose -f deploy/compose.yml ps
docker compose -f deploy/compose.yml logs --tail 100 api proxy
```

`/healthz` checks database access and a live rally worker; it returns 503 if the
worker stops or stalls. It reveals no account information and needs no key.
Docker records health status; **unhealthy status alone does not restart a running
container**. Monitor HTTPS health from your host/provider and investigate failures.
The restart policy handles process exits and host restarts. Logs rotate locally.
The single-process IP quotas reset on restart; this is not distributed rate limiting.

Stop/start safely with `docker compose -f deploy/compose.yml stop` / `up -d --wait`.
Never run `down --volumes` on the real deployment: that deletes saved game data
and certificate state. The automated test uses that command only for its uniquely
named disposable project.

## Back up and restore

```sh
bash deploy/backup.sh
```

This takes a consistent SQLite online backup, validates it, and copies it to
`deploy/backups/`. Run daily (for example with the host scheduler) and before each
update. Backups contain account credential hashes and player data; keep permissions
private, encrypt off-host copies and define retention. The script does not upload,
schedule or prune backups for you. Never copy a live SQLite file without its WAL.

Restore to a **new database path** so the previous database remains available:

```sh
docker compose -f deploy/compose.yml stop api
# Use the actual snapshot name. Start a one-off container with the same data volume.
docker compose -f deploy/compose.yml run --rm --no-deps --user 0:0 \
  -v "$PWD/deploy/backups:/backups:ro" api \
  python -m server.backup --source /backups/YOUR-SNAPSHOT.sqlite \
  --destination /data/restored.sqlite
docker compose -f deploy/compose.yml run --rm --no-deps --user 0:0 api \
  chown 10001:10001 /data/restored.sqlite
# Set CD_DATABASE=/data/restored.sqlite in deploy/.env, then:
docker compose -f deploy/compose.yml up -d --wait
```

The one-off restore uses root to read host-owned mode-0600 backups, then assigns
the restored database to the normal API user. The running API remains non-root.
Validate health, sign-in, faction membership and balances after restoring.
The helper refuses to overwrite an existing destination. Pick another filename
for subsequent rehearsals.

## Update and rollback

Back up first, check out the intended Git commit, repeat the verified wheel
prefetch and build, then `up -d --wait`. Use a distinct `CD_RELEASE` value in
`deploy/.env` (for example the commit SHA) to retain named images. Keep the previous
image and backup. To roll back, select its image tag and start with `up --no-build`;
if a schema change is incompatible, restore the matching backup to a new path.
Never assume rolling back code reverses a database migration.

Rotate the shared playtest key by securely replacing its file and recreating the
API container. Testers must enter the new key. Rotation does not revoke existing
account sessions; production session revocation is separate work.

## Local/CI deployment test

```sh
python3 -m pip download --require-hashes --only-binary=:all: \
  -r server/requirements-deploy.txt --dest server/wheels
docker build -f server/Dockerfile -t concrete-dominion-api:local .
python3 tools/deployment_probe.py
# With the repository's Godot version installed:
python3 tools/deployment_probe.py --godot
```

The probe starts a uniquely named Compose project on random loopback ports,
trusts that project's generated local CA (TLS verification stays enabled), runs
real wars, backs up data, restarts the API and verifies persistence. The optional
Godot check connects over HTTPS and buys an earned Hall upgrade. All test
credentials, volumes and containers are disposable; it does not contact an
existing deployment. This is not a load test or physical-device certification.
