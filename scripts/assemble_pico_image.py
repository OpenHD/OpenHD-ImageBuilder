"""Replace applications in a verified Pico base, preserving all other partitions."""
import argparse
import hashlib
import importlib.util
import json
import lzma
from pathlib import Path
import shutil
import struct
import subprocess
import tarfile
import tempfile
import zipfile


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def root_partition(image, name="rootfs"):
    with image.open('rb') as stream:
        stream.seek(512)
        header = stream.read(512)
        if header[:8] != b'EFI PART':
            raise ValueError('Base must be a complete GPT disk')
        lba, count, size = struct.unpack_from('<QII', header, 72)
        if size < 128 or count * size > 1 << 20:
            raise ValueError('Invalid GPT inventory')
        stream.seek(lba * 512)
        entries = stream.read(count * size)
    roots = []
    for start in range(0, len(entries), size):
        entry = entries[start:start + size]
        if entry[:16] == bytes(16):
            continue
        if entry[56:128].decode('utf-16-le').rstrip('\0') == name:
            first, last = struct.unpack_from('<QQ', entry, 32)
            roots.append((first * 512, (last - first + 1) * 512))
    if len(roots) != 1 or roots[0][0] + roots[0][1] > image.stat().st_size:
        raise ValueError('Expected one bounded rootfs partition')
    return roots[0]


def outside_digest(image, offset, length):
    h = hashlib.sha256()
    with image.open('rb') as stream:
        for start, end in ((0, offset), (offset + length, image.stat().st_size)):
            stream.seek(start)
            while start < end:
                block = stream.read(min(4 << 20, end - start))
                if not block:
                    raise ValueError('Truncated base disk')
                h.update(block)
                start += len(block)
    return h.hexdigest()


def extract_applications(archive, destination, manifest):
    with tarfile.open(archive, 'r:gz') as package:
        for entry in package:
            relative = Path(entry.name)
            if relative.is_absolute() or '..' in relative.parts:
                raise ValueError('Application archive path escapes root')
            if relative.parts and relative.parts[0] not in ('.', 'usr', 'lib'):
                raise ValueError('Unexpected application path: ' + entry.name)
        package.extractall(destination, filter='data')
    for name, expected in manifest['files'].items():
        path = destination / name
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError('Application checksum mismatch: ' + name)


def assemble(base, applications, sdk, target, output):
    base, applications, sdk, output = [p.resolve() for p in (base, applications, sdk, output)]
    output.mkdir(parents=True, exist_ok=True)
    meta = json.loads((base / ('openhd-base-' + target + '.json')).read_text())
    app = json.loads((applications / 'applications.json').read_text())
    if (meta['target'], meta['runtime_abi'], app['platform'], app['architecture']) != (
            target, 'armv7a-hardfloat-uclibc', 'luckfox-pico', 'armhf'):
        raise ValueError('Incompatible Pico application/base pair')
    if meta.get('usb_role') != 'host':
        raise ValueError('Pico base lacks USB host support; rebuild/publish SDK board bases')
    subprocess.run(['sha256sum', '-c', 'applications.sha256'], cwd=applications, check=True)
    firmware = load(sdk / 'scripts/package_imagewriter_firmware.py', 'pico_firmware')
    update = load(sdk / 'scripts/package-pico-update.py', 'pico_update')
    verifier = load(sdk / 'scripts/record_pico_components.py', 'pico_verify')
    with tempfile.TemporaryDirectory(dir=output.parent) as work:
        work = Path(work)
        disk, root, stage = work / 'disk.img', work / 'root', work / 'stage'
        with lzma.open(base / meta['image']) as src, disk.open('wb') as dst:
            shutil.copyfileobj(src, dst, 4 << 20)
        firmware.check_disk(disk)
        boot_offset, boot_length = root_partition(disk, 'boot')
        boot_image, boot_dtb = work / 'boot.img', work / 'boot.dtb'
        with disk.open('rb') as src, boot_image.open('wb') as dst:
            src.seek(boot_offset)
            remaining = boot_length
            while remaining:
                block = src.read(min(4 << 20, remaining))
                if not block:
                    raise ValueError('Truncated Pico boot partition')
                dst.write(block)
                remaining -= len(block)
        subprocess.run(['dumpimage', '-T', 'flat_dt', '-p', '0', '-o', str(boot_dtb), str(boot_image)], check=True)
        usb_mode = subprocess.check_output(['fdtget', '-t', 's', str(boot_dtb),
                                           '/usbdrd/usb@ffb00000', 'dr_mode'], text=True).strip()
        if usb_mode != 'host':
            raise ValueError('Pico base boot DTB does not enable USB host mode')
        offset, length = root_partition(disk)
        before = outside_digest(disk, offset, length)
        root.mkdir()
        stage.mkdir()
        extract_applications(applications / 'applications.tar.gz', stage, app)
        if app.get('video_backend') != 'native-pico-mpi' or app.get('gstreamer') is not False:
            raise ValueError('Pico images require the native VI/VENC camera build')
        dynamic = subprocess.check_output(['readelf', '-d', str(stage / 'usr/bin/openhd')], text=True)
        if 'libgst' in dynamic:
            raise ValueError('Pico OpenHD must run without GStreamer')
        for library in ('librockit.so', 'librkaiq.so'):
            if not (stage / 'usr/lib' / library).is_file():
                raise ValueError('Missing native camera runtime: ' + library)
        subprocess.run(['mount', '-o', f'loop,offset={offset},sizelimit={length}',
                        str(disk), str(root)], check=True)
        try:
            # Copy into the existing filesystem, retaining all board/runtime data.
            for directory in ('usr', 'lib'):
                if (root / directory).is_symlink():
                    raise ValueError('Unexpected symlink at root directory: ' + directory)
                subprocess.run(['cp', '-a', str(stage / directory) + '/.', str(root / directory)], check=True)
            for name, expected in app['files'].items():
                installed = update.target_file(root, root / name)
                if hashlib.sha256(installed.read_bytes()).hexdigest() != expected:
                    raise ValueError('Installed application differs from payload: ' + name)
            package = sdk / 'sysdrv/tools/board/buildroot/package'
            for source, destination in (
                    ('OpenHD/start.sh', 'etc/init.d/S99openhd'),
                    ('OpenHD/slots.sh', 'etc/init.d/S97openhd-slots'),
                    ('OpenHD/pico-update.py', 'usr/sbin/openhd-pico-update'),
                    ('OpenHD-SysUtils/start.sh', 'etc/init.d/S98openhd-sysutils')):
                path = root / destination
                path.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(package / source, path)
                path.chmod(0o755)
            overlay = sdk / 'project/cfg/BoardConfig_IPC/overlay/overlay-luckfox-buildroot-init/etc/init.d'
            for name in ('S39ethernet-mac', 'S50sshd'):
                shutil.copyfile(overlay / name, root / 'etc/init.d' / name)
                (root / 'etc/init.d' / name).chmod(0o755)
            shutil.copyfile(sdk / 'sysdrv/tools/board/android-tools/S50usbdevice', root / 'etc/init.d/S50usbdevice')
            (root / 'etc/init.d/S50usbdevice').chmod(0o755)
            hotspot = root / 'usr/sbin/openhd-pico-hotspot'
            hotspot.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(sdk / 'project/cfg/BoardConfig_IPC/overlay/overlay-luckfox-buildroot-init/usr/sbin/openhd-pico-hotspot', hotspot)
            hotspot.chmod(0o755)
            base_id = hashlib.sha256((meta['sdk_commit'] + ':' + target).encode()).hexdigest()
            (root / 'etc/openhd-pico-base-id').write_text(base_id + '\n')
            commits = app['source_commits']
            payload = output / ('OpenHD-' + target + '.pico-ohd')
            update.package(root, payload, 'readelf', {n: commits[n] for n in ('openhd', 'sysutils')})
            recorded = verifier.inspect(root, payload, target, dict(sdk=meta['sdk_commit'], **commits))
            recorded.update(base_image_sha256=meta['sha256'], base_run=meta.get('base_run'),
                            sdk_sha256=app['sdk_sha256'], assembly='existing-base-application-overlay',
                            video_backend=app['video_backend'], gstreamer=False, usb_role='host',
                            ethernet_mac='persistent', venc_packet_address='mb-valid')
            manifest = json.dumps(recorded, indent=2) + '\n'
            (root / 'etc/openhd-image-components.json').write_text(manifest)
            (output / ('openhd-' + target + '.components.json')).write_text(manifest)
            subprocess.run(['sync'], check=True)
        finally:
            subprocess.run(['umount', str(root)], check=True)
        if outside_digest(disk, offset, length) != before:
            raise ValueError('Assembly modified board boot/data partitions outside rootfs')
        firmware.check_disk(disk)
        if meta['boot_medium'] == 'emmc':
            with zipfile.ZipFile(base / 'firmware.zip') as archive:
                loader = work / 'download.bin'
                loader.write_bytes(archive.read('download.bin'))
                transport = json.loads(archive.read('firmware-manifest.json'))
                if (transport['sdk_commit'] != meta['sdk_commit'] or
                        transport['loader_sha256'] != firmware.digest(loader)):
                    raise ValueError('Base loader provenance mismatch')
            firmware.package(disk, loader,
                             sdk / 'project/cfg/BoardConfig_IPC' / meta['board_config'],
                             output / 'firmware.zip', meta['sdk_commit'])
        image = output / ('openhd-' + target + '.img.xz')
        with image.open('wb') as stream:
            subprocess.run(['xz', '-T0', '-3', '-c', str(disk)], stdout=stream, check=True)
    with (output / ('openhd-' + target + '.sha256')).open('w') as stream:
        for path in sorted(output.iterdir()):
            if not path.name.endswith('.sha256'):
                stream.write(firmware.digest(path) + '  ' + path.name + '\n')
    print('Reused base; verified applications, Devourer, runtime libraries and unchanged boot partitions')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    for n in ('base', 'applications', 'sdk', 'output'):
        p.add_argument('--' + n, type=Path, required=True)
    p.add_argument('--target', required=True)
    a = p.parse_args()
    assemble(a.base, a.applications, a.sdk, a.target, a.output)
