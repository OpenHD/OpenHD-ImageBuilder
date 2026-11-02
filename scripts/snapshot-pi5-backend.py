#!/usr/bin/env python3
"""Archive a committed OpenHD tree and its exact gitlink revisions, without local edits."""
import argparse
import io
import subprocess
import tarfile
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('checkout', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--revision', default='HEAD')
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
manifest = []

def snapshot(checkout, revision, relative=Path('.')):
    def git(*arguments):
        return subprocess.check_output(['git', '-C', str(checkout), *arguments])
    commit = git('rev-parse', revision).decode().strip()
    manifest.append(f'{relative.as_posix()}={commit}')
    with tarfile.open(fileobj=io.BytesIO(git('archive', commit))) as archive:
        archive.extractall(args.output / relative, filter='data')
    for entry in git('ls-tree', '-r', '-z', commit).split(b'\0'):
        if not entry:
            continue
        metadata, path = entry.split(b'\t', 1)
        mode, _, sha = metadata.split()
        if mode == b'160000':
            child = Path(path.decode())
            # Devourer's reference driver archives are not build inputs.
            if (relative / child).as_posix().startswith('OpenHD/ohd_interface/lib/devourer/reference/'):
                continue
            snapshot(checkout / child, sha.decode(), relative / child)

snapshot(args.checkout, args.revision)
(args.output / 'snapshot-revisions.txt').write_text('\n'.join(manifest) + '\n')
