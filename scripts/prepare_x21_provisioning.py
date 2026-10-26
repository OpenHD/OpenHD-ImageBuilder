"""Order the legacy X21 launcher after SysUtils provisioning/settings import."""
from pathlib import Path
import argparse
import re

WAIT = '''# ImageWriter provisioning must finish before OpenHD consumes settings.
openhd_ready=0
for openhd_wait in $(seq 1 60); do
    if [ -S /run/openhd/openhd_sys.sock ]; then openhd_ready=1; break; fi
    sleep 1
done
if [ "$openhd_ready" != 1 ]; then
    echo "SysUtils did not become ready; OpenHD was not started." >&2
    exit 1
fi
'''

def prepare(path):
    text = path.read_text()
    if '# ImageWriter provisioning must finish' in text:
        return
    launch = re.compile(r'^.*\bnohup\s+/ohd/usr/bin/openhd(?:\s+[^\n]*)?$', re.M)
    matches = list(launch.finditer(text))
    if len(matches) != 1:
        raise ValueError('Expected one direct OpenHD launch in the verified X21 seed')
    at = matches[0].start()
    if '/ohd/usr/bin/openhd_sys_utils' not in text[:at]:
        raise ValueError('SysUtils must start before OpenHD')
    path.write_bytes((text[:at] + WAIT + text[at:]).encode())

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('launcher', type=Path)
    prepare(p.parse_args().launcher)
