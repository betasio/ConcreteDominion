"""Consistent SQLite snapshot. Also restore to a NEW database path while stopped."""
import argparse
from contextlib import closing
import os
from pathlib import Path
import sqlite3
import tempfile


def copy_database(source, destination):
    source, destination = Path(source).resolve(), Path(destination).resolve()
    if not source.is_file() or destination.exists():
        raise ValueError('Source must exist and destination must be a new file')
    fd, temporary = tempfile.mkstemp(prefix='.sqlite-backup-', dir=destination.parent)
    os.close(fd)
    try:
        with closing(sqlite3.connect(source.as_uri()+'?mode=ro', uri=True)) as src:
            with closing(sqlite3.connect(temporary)) as dst:
                src.backup(dst)
                if dst.execute('PRAGMA quick_check').fetchone()[0] != 'ok':
                    raise ValueError('Backup integrity check failed')
        with open(temporary, 'rb') as snapshot:
            os.fsync(snapshot.fileno())
        # Publish without overwriting any existing backup, including concurrent jobs.
        os.link(temporary, destination)
    finally:
        os.unlink(temporary)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', required=True)
    parser.add_argument('--destination', required=True)
    args = parser.parse_args()
    copy_database(args.source, args.destination)
    print('Database snapshot verified and saved.')


if __name__ == '__main__':
    main()
