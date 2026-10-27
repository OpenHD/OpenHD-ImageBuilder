#!/usr/bin/env python3
"""Select the Wayland variant of the image's existing Mali GPU/DDK, never another GPU."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import time
import urllib.request

REVISION = '961afae0c1e6af8db7197cc722a26b5a998067e6'
DRIVERS = {
    'bifrost-g52-g2p0': ('libmali-bifrost-g52-g2p0-wayland-gbm.so', '5a9acc8732dbfebffb0d52401c7582fb0268870d48261b304edbfb836a7b15da'),
    'bifrost-g52-g13p0': ('libmali-bifrost-g52-g13p0-x11-wayland-gbm.so', '83d33d2893f7d228bd95983bc8a53c126d95ab4ff62b9a8b61af460ed026455a'),
    'valhall-g610-g6p0': ('libmali-valhall-g610-g6p0-x11-wayland-gbm.so', '4b3f9e47375ecdbfbb10f6546b9f331bbbe86c74e2f61e1dd779a7ace067425f'),
    'valhall-g610-g13p0': ('libmali-valhall-g610-g13p0-x11-wayland-gbm.so', 'e6173c8f380f89f381ca255049dc0db0aa83412c8aa935bfbc0de87d1c54ab7e'),
    'valhall-g610-g24p0': ('libmali-valhall-g610-g24p0-x11-wayland-gbm.so', '1b05c9cb38a87d696961cb38b0222befd6bc6748d463958701c61852bd858f30'),
}


def select_driver(status):
    installed = []
    for entry in status.split('\n\n'):
        if '\nStatus: install ok installed\n' not in '\n' + entry + '\n':
            continue
        package = re.search(r'^Package: (libmali-[^\n]+)', entry, re.M)
        if package:
            name = package[1]
            for driver in DRIVERS:
                if name.startswith('libmali-' + driver + '-'):
                    installed.append(driver)
                    break
            else:
                if 'hook' not in name:
                    raise ValueError('Unsupported installed Mali driver: ' + name)
    if len(set(installed)) > 1:
        raise ValueError('Ambiguous Mali GPU/DDK packages: ' + ', '.join(installed))
    return installed[0] if installed else None


def download(url):
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=45) as response:
                return response.read()
        except OSError:
            if attempt == 2:
                raise
            time.sleep(2)


def install(root, cache=None):
    root = Path(root)
    status = (root / 'var/lib/dpkg/status').read_text()
    driver = select_driver(status)
    dest = root / 'usr/local/share/qopenhd-rockchip/mali'
    dest.mkdir(parents=True, exist_ok=True)
    if driver is None:
        # Mainline/Mesa images use their own EGL/GBM implementation. Never
        # substitute a guessed proprietary DDK or leave an old private override.
        if (dest / 'libmali.so.1').exists():
            raise ValueError('Private Mali override exists but image has no matching Mali package')
        mesa = any(re.search(r'^Package: libegl-mesa0$', entry, re.M) and
                   'Status: install ok installed' in entry for entry in status.split('\n\n'))
        if not mesa:
            raise ValueError('Image has neither a supported Mali package nor installed Mesa EGL')
        print('Rockchip native display: using image-provided Mesa EGL/GBM')
        return
    name, expected = DRIVERS[driver]
    target = dest / 'libmali.so.1'
    if not target.exists() or hashlib.sha256(target.read_bytes()).hexdigest() != expected:
        base = f'https://raw.githubusercontent.com/JeffyCN/mirrors/{REVISION}/'
        cached = Path(cache) / name if cache else None
        data = cached.read_bytes() if cached and cached.exists() else download(base + 'lib/aarch64-linux-gnu/' + name)
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError('Mali checksum mismatch: ' + name)
        temporary = target.with_suffix('.partial')
        temporary.write_bytes(data)
        temporary.replace(target)
    for name in ['libEGL.so.1', 'libGLESv2.so.2', 'libgbm.so.1']:
        link = dest / name
        if link.is_symlink() or link.exists():
            link.unlink()
        link.symlink_to('libmali.so.1')
    license_file = dest / 'END_USER_LICENCE_AGREEMENT.txt'
    if not license_file.exists():
        license_file.write_bytes(download(f'https://raw.githubusercontent.com/JeffyCN/mirrors/{REVISION}/END_USER_LICENCE_AGREEMENT.txt'))
    record = {'source_revision': REVISION, 'driver': driver, 'file': DRIVERS[driver][0], 'sha256': expected}
    (dest / 'source.json').write_text(json.dumps(record, indent=2) + '\n')
    print('Rockchip native display: matched ' + driver)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', default='/')
    parser.add_argument('--cache')
    args = parser.parse_args()
    install(args.root, args.cache)
