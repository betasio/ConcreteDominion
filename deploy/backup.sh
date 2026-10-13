#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
umask 077
mkdir -p backups
snapshot="snapshot-$(date -u +%Y%m%dT%H%M%SZ)-$$.sqlite"
docker compose -f compose.yml exec -T api python -c '
import os, sys
from pathlib import Path
from server.backup import copy_database
Path("/data/backups").mkdir(exist_ok=True)
copy_database(os.environ["CD_DATABASE"], "/data/backups/"+sys.argv[1])
' "$snapshot"
docker compose -f compose.yml cp "api:/data/backups/$snapshot" "backups/$snapshot"
docker compose -f compose.yml exec -T api python -c 'import os,sys; os.unlink("/data/backups/"+sys.argv[1])' "$snapshot"
printf 'Verified backup saved to deploy/backups/%s\n' "$snapshot"
