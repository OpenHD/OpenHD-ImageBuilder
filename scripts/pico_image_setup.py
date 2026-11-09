"""Image defaults shared by the SD/eMMC and NAND Luckfox assemblers."""
from pathlib import Path
import os
import re
import secrets
import subprocess


def install_ssh_login(root):
    root = Path(root)
    etc = root / 'etc'
    passwd = (etc / 'passwd').read_text().splitlines()
    group = (etc / 'group').read_text().splitlines()
    account = next((line.split(':') for line in passwd if line.startswith('openhd:')), None)
    if account is None:
        occupied = {int(line.split(':')[2]) for line in passwd + group}
        uid = next(n for n in range(1000, 60000) if n not in occupied)
        existing_group = next((line.split(':') for line in group if line.startswith('openhd:')), None)
        gid = existing_group[2] if existing_group else str(uid)
        account = ['openhd', 'x', str(uid), gid, 'OpenHD', '/home/openhd', '/bin/sh']
        if existing_group is None:
            group.append(f'openhd:x:{uid}:')
    account[1], account[5], account[6] = 'x', '/home/openhd', '/bin/sh'
    passwd = [line for line in passwd if not line.startswith('openhd:')]
    passwd.append(':'.join(account))
    password = subprocess.check_output(
        ['openssl', 'passwd', '-6', '-salt', secrets.token_hex(8), '-stdin'],
        input='openhd\n', text=True).strip()
    shadow = (etc / 'shadow').read_text().splitlines()
    shadow = [line for line in shadow if not line.startswith('openhd:')]
    shadow.append(f'openhd:{password}:19000:0:99999:7:::')
    for name, lines in (('passwd', passwd), ('group', group), ('shadow', shadow)):
        (etc / name).write_text('\n'.join(lines) + '\n')
    (etc / 'shadow').chmod(0o600)
    home = root / 'home/openhd'
    home.mkdir(parents=True, exist_ok=True)
    # Assembly runs as root; retain correct ownership in the generated filesystem.
    os.chown(home, int(account[2]), int(account[3]))
    home.chmod(0o755)
    config = etc / 'ssh/sshd_config'
    text = config.read_text()
    # OpenSSH uses the first global value, before any Include/Match sections.
    text = re.sub(r'(?im)^(AllowUsers\s+)(.*)$',
                  lambda m: m[0] if 'openhd' in m[2].split() else m[0] + ' openhd', text)
    if not text.startswith('PasswordAuthentication yes\n'):
        text = 'PasswordAuthentication yes\n' + text
    config.write_text(text)


def install_nand_recordings(root):
    source = Path(__file__).with_name('pico_nand_recordings.sh')
    destination = Path(root) / 'etc/init.d/S97openhd-recordings'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(source.read_bytes())
    destination.chmod(0o755)
