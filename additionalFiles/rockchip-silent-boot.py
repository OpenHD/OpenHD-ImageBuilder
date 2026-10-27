#!/usr/bin/env python3
"""Quiet kernel/systemd display output without changing root, DT or serial settings."""
import argparse
from pathlib import Path
import re

FLAGS = ('quiet', 'loglevel=0', 'logo.nologo', 'systemd.show_status=false', 'rd.systemd.show_status=false', 'vt.global_cursor_default=0')


def quiet_args(text):
    tokens = text.split()
    tokens = [t for t in tokens if t not in ('console=tty0', 'console=tty1', 'console=tty3', 'quiet', 'logo.nologo')
              and not t.startswith(('loglevel=', 'systemd.show_status=', 'rd.systemd.show_status=', 'vt.global_cursor_default='))]
    return ' '.join(tokens + ['console=tty3', *FLAGS])


def configure(root):
    root = Path(root)
    for relative in ('boot/extlinux/extlinux.conf', 'boot/extlinux/extlinux.txt'):
        path = root / relative
        if path.exists():
            path.write_text(re.sub(r'^(\s*APPEND\s+)([^\n]*)', lambda m: m[1] + quiet_args(m[2]), path.read_text(), flags=re.M | re.I))
    path = root / 'etc/kernel/cmdline'
    if path.exists():
        path.write_text(quiet_args(path.read_text()) + '\n')
    for relative in ('boot/armbianEnv.txt', 'boot/uEnv.txt', 'boot/firmware/ubuntuEnv.txt'):
        path = root / relative
        if not path.exists():
            continue
        text = path.read_text()
        text = re.sub(r'^verbosity=.*$', 'verbosity=0', text, flags=re.M)
        if re.search(r'^extraargs=', text, re.M):
            text = re.sub(r'^extraargs=(.*)$', lambda m: 'extraargs=' + quiet_args(m[1]), text, flags=re.M)
        else:
            text = text.rstrip() + '\nextraargs=' + quiet_args('') + '\n'
        path.write_text(text)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', default='/')
    configure(parser.parse_args().root)
