"""Reuse a complete successful six-board base build; never start an SDK build."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import urllib.parse
import urllib.request

REPO = 'OpenHD/luckfox-pico-sdk'
TARGETS = ['zero', 'ultra-w', 'ultra', 'pro-max', 'plus', 'mini']
BASE_URL = 'https://dl.cloudsmith.io/public/openhd/dev-release/raw/names/'


def published_url(filename):
    name = urllib.parse.quote(filename, safe='')
    return BASE_URL + name + '/versions/latest/' + name


def api(path):
    return json.loads(subprocess.check_output(['gh', 'api', path]))


def select():
    runs = api(f'repos/{REPO}/actions/workflows/build.yml/runs?status=success&branch=main&event=push&per_page=30')
    required = {'openhd-base-luckfox-pico-' + name for name in TARGETS}
    for run in runs['workflow_runs']:
        artifacts = api(f'repos/{REPO}/actions/runs/{run["id"]}/artifacts?per_page=100')['artifacts']
        if required <= {a['name'] for a in artifacts if not a['expired']}:
            return run
    raise ValueError('No complete retained Pico base build; publish/build board bases separately')


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(4 << 20), b''):
            h.update(block)
    return h.hexdigest()


class IncompatiblePublishedBase(ValueError):
    """A published base predates the required board capabilities."""


def fetch(target, output, run):
    output.mkdir(parents=True, exist_ok=True)
    # Published bases remain available after GitHub's temporary artifacts expire.
    name = 'openhd-base-' + target
    try:
        with urllib.request.urlopen(published_url(name + '.json'), timeout=30) as response:
            manifest = json.load(response)
        if manifest['target'] != target or manifest['runtime_abi'] != 'armv7a-hardfloat-uclibc':
            raise ValueError('Wrong published Pico base')
        if manifest.get('usb_role') != 'host':
            raise IncompatiblePublishedBase('Published Pico base predates USB host support')
        filenames = [manifest['image'], name + '.json']
        if manifest['boot_medium'] == 'emmc':
            filenames += [name + '-firmware.zip', name + '-firmware.zip.sha256']
        for filename in filenames:
            urllib.request.urlretrieve(published_url(filename), output / filename)
        if manifest['boot_medium'] == 'emmc':
            (output / (name + '-firmware.zip')).rename(output / 'firmware.zip')
            checksum = (output / (name + '-firmware.zip.sha256')).read_text().split()[0]
            if digest(output / 'firmware.zip') != checksum:
                raise ValueError('Published base firmware checksum mismatch')
    except (urllib.error.HTTPError, IncompatiblePublishedBase) as error:
        if isinstance(error, urllib.error.HTTPError) and error.code != 404:
            raise
        subprocess.run(['gh', 'run', 'download', str(run), '--repo', REPO,
                        '--name', name, '--dir', str(output)], check=True)
        manifest = json.loads((output / (name + '.json')).read_text())
        subprocess.run(['sha256sum', '-c', name + '.sha256'], cwd=output, check=True)
        if manifest['boot_medium'] == 'emmc':
            subprocess.run(['sha256sum', '-c', 'firmware.zip.sha256'], cwd=output, check=True)
    if manifest['target'] != target or manifest['runtime_abi'] != 'armv7a-hardfloat-uclibc':
        raise ValueError('Base target or ABI mismatch')
    if manifest.get('usb_role') != 'host':
        raise ValueError('Selected Pico base lacks USB host support; rebuild SDK board bases')
    if digest(output / manifest['image']) != manifest['sha256']:
        raise ValueError('Base disk checksum mismatch')
    return manifest


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--target')
    p.add_argument('--output', type=Path)
    p.add_argument('--run', type=int)
    a = p.parse_args()
    if a.target:
        fetch(a.target, a.output, a.run)
    else:
        # The known verified build is a fallback only when a published base can
        # already be used; fetch() reports expired artifacts if no base exists.
        try:
            print(select()['id'])
        except ValueError:
            print(40189150025)
