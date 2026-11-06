"""Overlay current native applications on a verified reusable Mini NAND seed."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile
from assemble_pico_image import extract_applications, load


def install_config_mount(root, sdk):
    name = 'etc/init.d/S25openhd-nand'
    source = sdk / 'project/cfg/BoardConfig_IPC/overlay/overlay-openhd-pico-nand' / name
    content = source.read_bytes()
    if b'mount --bind /userdata/Config /Config' not in content:
        raise ValueError('NAND startup must mount a real persistent /Config directory')
    destination = root / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(content)
    destination.chmod(0o755)


def verify_runtime(root):
    for name in ('usr/local/share/OpenHD/SysUtils/wifi_cards.json',
                 'lib/modprobe.d/openhd-devourer-eu.conf',
                 'usr/sbin/usb_modeswitch', 'usr/sbin/openhd-usb-power-recover'):
        if not (root / name).is_file():
            raise ValueError('Missing Devourer runtime policy/helper: ' + name)
    def resolve(path):
        for _ in range(40):
            if not path.is_symlink():
                return path
            link = path.readlink()
            path = root / str(link).lstrip('/') if link.is_absolute() else path.parent / link
            path = Path(os.path.normpath(path))
            if not path.is_relative_to(root):
                raise ValueError('Runtime symlink escapes NAND root')
        raise ValueError('Runtime symlink loop')
    pending = [root / 'usr/bin/openhd', root / 'usr/bin/openhd_sys_utils']
    done = set()
    while pending:
        path = resolve(pending.pop())
        if path in done:
            continue
        done.add(path)
        header = path.read_bytes()[:20]
        if header[:6] != b'\x7fELF\x01\x01' or header[18:20] != b'\x28\x00':
            raise ValueError('Expected ARM32 runtime: ' + str(path))
        dynamic = subprocess.check_output(['readelf', '-d', str(path)], text=True)
        for name in re.findall(r'\(NEEDED\).*?\[(.*?)\]', dynamic):
            if '/' in name or name.startswith('libgst'):
                raise ValueError('Invalid native NAND dependency: ' + name)
            found = next((root / d / name for d in ('usr/lib', 'lib', 'oem/usr/lib')
                          if resolve(root / d / name).is_file()), None)
            if found is None:
                raise ValueError('Missing NAND runtime library: ' + name)
            pending.append(found)
    binary = (root / 'usr/bin/openhd').read_bytes()
    for signature in (b'Devourer identified', b'packet-address=mb-valid'):
        if signature not in binary:
            raise ValueError('NAND applications lack Devourer or the native VENC packet fix')
    for name in ('librockit.so', 'librkaiq.so'):
        if not (root / 'usr/lib' / name).is_file():
            raise ValueError('Missing native camera library: ' + name)
    return len(done)


def assemble(base, applications, sdk, target, output):
    base, applications, sdk, output = [p.resolve() for p in (base, applications, sdk, output)]
    output.mkdir(parents=True, exist_ok=True)
    nand = load(sdk / 'scripts/pico_nand.py', 'pico_nand')
    meta = json.loads((base / ('openhd-base-' + target + '.json')).read_text())
    app = json.loads((applications / 'applications.json').read_text())
    profile = nand.TARGETS.get(target)
    if (not profile or meta['target'] != target or meta.get('board_config') != profile['board']
            or meta.get('nand_capacity') != profile['capacity'] or meta['boot_medium'] != 'spi_nand'
            or meta.get('usb_role') != 'host' or meta.get('usb_role_switching') is not True
            or meta.get('provisioning') != 'ubi-static-rootfs-v1' or meta.get('application_slots') is not False
            or meta['runtime_abi'] != 'armv7a-hardfloat-uclibc'
            or app['platform'] != 'luckfox-pico' or app['architecture'] != 'armhf'
            or app.get('video_backend') != 'native-pico-mpi' or app.get('gstreamer') is not False):
        raise ValueError('Incompatible minimal NAND base/application pair')
    for name, expected in ((meta['image'], meta['sha256']),
                           (meta['rootfs_seed'], meta['rootfs_seed_sha256'])):
        if Path(name).name != name or nand.digest(base / name) != expected:
            raise ValueError('NAND base checksum/path mismatch')
    subprocess.run(['sha256sum', '-c', 'applications.sha256'], cwd=applications, check=True)
    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        images, root, stage = work / 'images', work / 'root', work / 'stage'
        images.mkdir(); stage.mkdir()
        with zipfile.ZipFile(base / meta['image']) as archive:
            if set(archive.namelist()) != set(nand.FILES):
                raise ValueError('Unexpected NAND base firmware inventory')
            for name in nand.FILES:
                (images / name).write_bytes(archive.read(name))
        for name, expected in meta['board_files'].items():
            if name not in nand.FILES or nand.digest(images / name) != expected:
                raise ValueError('NAND board partition checksum mismatch')
        nand.check_images(images)
        nand.check_boot(images / 'boot.img')
        nand.extract_seed(base / meta['rootfs_seed'], root)
        install_config_mount(root, sdk)
        nand.check_root(root)
        extract_applications(applications / 'applications.tar.gz', stage, app)
        for directory in ('usr', 'lib'):
            subprocess.run(['cp', '-a', str(stage / directory) + '/.', str(root / directory)], check=True)
        package = sdk / 'sysdrv/tools/board/buildroot/package'
        for source, name in (('OpenHD/start.sh', 'S99openhd'), ('OpenHD-SysUtils/start.sh', 'S98openhd-sysutils')):
            destination = root / 'etc/init.d' / name
            shutil.copyfile(package / source, destination); destination.chmod(0o755)
        config = root / 'usr/local/share/OpenHD/SysUtils/config.json'
        config.parent.mkdir(parents=True, exist_ok=True)
        config.write_text(json.dumps(dict(platform_type=25, platform_name='RV110X', run_mode='air',
            camera_type=140, camera_resolution_fps='1280x720@60', firstboot=False,
            init_system='init.d', shell='busybox', wifi_enable_autodetect=True,
            disable_ethernet_link=True, air_unit_ip='192.168.3.1',
            ground_unit_ip='192.168.3.2'), indent=2) + '\n')
        usb_source = sdk / 'sysdrv/tools/board/android-tools/S50usbdevice'
        usb_destination = root / 'etc/init.d/S50usbdevice'
        usb_destination.write_bytes(usb_source.read_bytes()); usb_destination.chmod(0o755)
        role_source = sdk / 'sysdrv/tools/board/android-tools/openhd-pico-usb-role'
        role_destination = root / 'usr/sbin/openhd-pico-usb-role'
        role_destination.write_bytes(role_source.read_bytes()); role_destination.chmod(0o755)
        network_source = sdk / 'project/cfg/BoardConfig_IPC/overlay/overlay-luckfox-buildroot-init/etc/init.d/S99usb0config'
        network_destination = root / 'etc/init.d/S99usb0config'
        network_destination.write_bytes(network_source.read_bytes()); network_destination.chmod(0o755)
        checked = verify_runtime(root)
        nand.check_root(root, applications=True)
        recorded = dict(schema=1, target=target, source_commits=dict(sdk=meta['sdk_commit'], **app['source_commits']),
            base_image_sha256=meta['sha256'], sdk_sha256=app['sdk_sha256'], assembly='existing-nand-base-application-overlay',
            video_backend='native-pico-mpi', gstreamer=False, devourer=True, webui=False,
            usb_role='host', usb_role_switching=True, provisioning='ubi-static-rootfs-v1',
            application_slots=False, config_mount='userdata-bind-v1', usb_ethernet_ip='192.168.3.1', usb_host_ip='192.168.3.2', sensor='MIS5001', camera_format='1280x720@60',
            runtime_elf_files_checked=checked, nand_capacity=profile['capacity'],
            nand_partition_bytes=sum(size for _, size in nand.PARTITIONS.values()),
            runtime_files={name: nand.digest(root / name) for name in app['files']})
        recorded['config_startup_sha256'] = nand.digest(root / 'etc/init.d/S25openhd-nand')
        recorded['assembly_sdk_commit'] = subprocess.check_output(['git', '-c', 'safe.directory=' + str(sdk), '-C', str(sdk), 'rev-parse', 'HEAD'], text=True).strip()
        manifest = json.dumps(recorded, indent=2) + '\n'
        (root / 'etc/openhd-image-components.json').write_text(manifest)
        nand.make_rootfs(root, images / 'rootfs.img')
        nand.package_firmware(images, output / 'firmware.zip', sdk / 'tools/linux/Linux_Pack_Firmware')
        for name, expected in meta['board_files'].items():
            if nand.digest(images / name) != expected:
                raise ValueError('NAND assembly changed a board partition: ' + name)
        (output / ('openhd-' + target + '.components.json')).write_text(manifest)
    with (output / ('openhd-' + target + '.sha256')).open('w') as stream:
        for path in sorted(output.iterdir()):
            if not path.name.endswith('.sha256'):
                stream.write(nand.digest(path) + '  ' + path.name + '\n')
    print('Verified minimal NAND image, unchanged board partitions and native Devourer/camera runtime')
