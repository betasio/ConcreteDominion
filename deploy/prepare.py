"""Create local deployment configuration; never print or overwrite credentials."""
from pathlib import Path
import argparse
import os
import re
import secrets


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--domain', required=True, help='DNS hostname only, e.g. multiplayer.example.com')
    args = parser.parse_args()
    domain = args.domain.lower()
    if len(domain) > 253 or not all(re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', part) for part in domain.split('.')):
        parser.error('Use a DNS hostname without scheme, port or path')
    folder = Path(__file__).resolve().parent
    private = folder/'secrets'
    private.mkdir(mode=0o700, exist_ok=True)
    private.chmod(0o700)
    key = private/'playtest_key'
    if not key.exists():
        fd = os.open(key, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o400)
        with os.fdopen(fd, 'w') as output:
            output.write(secrets.token_hex(32)+'\n')
        # Compose file-backed secrets keep source permissions; container UID differs.
        # The containing host directory remains private (0700).
        key.chmod(0o444)
    config = folder/'.env'
    if not config.exists():
        with config.open('x') as output:
            output.write(f'CD_DOMAIN={domain}\nCD_RELEASE=local\n')
        config.chmod(0o600)
    print('Deployment files prepared. Existing configuration and keys were preserved.')
    print('Share deploy/secrets/playtest_key only through your private tester channel.')


if __name__ == '__main__':
    main()
