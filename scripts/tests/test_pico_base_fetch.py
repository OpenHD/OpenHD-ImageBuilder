"""Do not prefer an obsolete published base over a compatible SDK artifact."""
import hashlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import fetch_pico_base as fetcher


class BaseFetchTests(unittest.TestCase):
    def test_select_specific_nand_base_from_manual_sdk_build(self):
        target = 'luckfox-pico-pro-max-nand'
        def api(path):
            if '/workflows/' in path:
                self.assertNotIn('event=push', path)
                return {'workflow_runs': [{'id': 456}]}
            return {'artifacts': [{'name': 'openhd-base-' + target, 'expired': False}]}
        with patch.object(fetcher, 'api', side_effect=api):
            self.assertEqual(fetcher.select(target)['id'], 456)

    def test_nand_seed_is_downloaded_and_verified(self):
        target = 'luckfox-pico-mini-nand'
        name = 'openhd-base-' + target
        contents = {'firmware.zip': b'board-partitions', 'seed.tar.xz': b'rootfs-seed'}
        manifest = dict(target=target, runtime_abi='armv7a-hardfloat-uclibc',
                        image='firmware.zip', boot_medium='spi_nand', usb_role='host',
                        application_slots=False, usb_role_switching=True, rootfs_seed='seed.tar.xz',
                        sha256=hashlib.sha256(contents['firmware.zip']).hexdigest(),
                        rootfs_seed_sha256=hashlib.sha256(contents['seed.tar.xz']).hexdigest())
        contents[name + '.json'] = json.dumps(manifest).encode()
        for corrupt in (False, True):
            with self.subTest(corrupt=corrupt), tempfile.TemporaryDirectory() as tmp:
                def retrieve(url, destination):
                    data = contents[Path(destination).name]
                    if corrupt and Path(destination).name == 'seed.tar.xz':
                        data += b'corrupted'
                    Path(destination).write_bytes(data)

                with patch.object(fetcher.urllib.request, 'urlopen', return_value=io.BytesIO(json.dumps(manifest).encode())), \
                        patch.object(fetcher.urllib.request, 'urlretrieve', side_effect=retrieve), \
                        patch.object(fetcher.subprocess, 'run') as fallback:
                    if corrupt:
                        with self.assertRaisesRegex(ValueError, 'seed checksum'):
                            fetcher.fetch(target, Path(tmp), 123)
                    else:
                        self.assertEqual(fetcher.fetch(target, Path(tmp), 123), manifest)
                    fallback.assert_not_called()

    def test_legacy_published_base_uses_selected_sdk_run(self):
        target = 'luckfox-pico-mini'
        name = 'openhd-base-' + target
        disk = b'verified-current-base'
        legacy = dict(target=target, runtime_abi='armv7a-hardfloat-uclibc',
                      image=name + '.img.xz', boot_medium='sd_card',
                      sha256=hashlib.sha256(disk).hexdigest())
        current = dict(legacy, usb_role='host', usb_role_switching=True)
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)

            def run(command, **kwargs):
                if command[:3] == ['gh', 'run', 'download']:
                    self.assertEqual(command[3], '123')
                    (output / (name + '.json')).write_text(json.dumps(current))
                    (output / current['image']).write_bytes(disk)

            with patch.object(fetcher.urllib.request, 'urlopen', return_value=io.BytesIO(json.dumps(legacy).encode())), \
                    patch.object(fetcher.urllib.request, 'urlretrieve') as published_download, \
                    patch.object(fetcher.subprocess, 'run', side_effect=run):
                result = fetcher.fetch(target, output, 123)
            self.assertEqual(result['usb_role'], 'host')
            published_download.assert_not_called()

    def test_legacy_boolean_is_repaired_only_after_checksum_verification(self):
        target = 'luckfox-pico-mini'
        name = 'openhd-base-' + target
        disk = b'verified-current-base'
        manifest = dict(target=target, runtime_abi='armv7a-hardfloat-uclibc',
                        image=name + '.img.xz', boot_medium='sd_card',
                        usb_role='host', usb_role_switching=True,
                        sha256=hashlib.sha256(disk).hexdigest())
        original = json.dumps(manifest).replace('true', 'True')
        for corrupt in (False, True):
            with self.subTest(corrupt=corrupt), tempfile.TemporaryDirectory() as tmp:
                output = Path(tmp)
                metadata = output / (name + '.json')

                def run(command, **kwargs):
                    if command[:3] == ['gh', 'run', 'download']:
                        metadata.write_text(original)
                        (output / manifest['image']).write_bytes(disk)
                    elif command[0] == 'sha256sum':
                        self.assertEqual(metadata.read_text(), original)
                        if corrupt:
                            raise fetcher.subprocess.CalledProcessError(1, command)

                legacy = dict(manifest, usb_role_switching=False)
                with patch.object(fetcher.urllib.request, 'urlopen', return_value=io.BytesIO(json.dumps(legacy).encode())), \
                        patch.object(fetcher.subprocess, 'run', side_effect=run):
                    if corrupt:
                        with self.assertRaises(fetcher.subprocess.CalledProcessError):
                            fetcher.fetch(target, output, 123)
                        self.assertEqual(metadata.read_text(), original)
                    else:
                        self.assertEqual(fetcher.fetch(target, output, 123), manifest)
                        self.assertEqual(json.loads(metadata.read_text()), manifest)

    def test_reject_old_artifact_after_published_fallback(self):
        target = 'luckfox-pico-mini'
        manifest = dict(target=target, runtime_abi='armv7a-hardfloat-uclibc',
                        image='base.img.xz', boot_medium='sd_card')
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)

            def run(command, **kwargs):
                if command[:3] == ['gh', 'run', 'download']:
                    (output / ('openhd-base-' + target + '.json')).write_text(json.dumps(manifest))

            with patch.object(fetcher.urllib.request, 'urlopen', return_value=io.BytesIO(json.dumps(manifest).encode())), \
                    patch.object(fetcher.subprocess, 'run', side_effect=run):
                with self.assertRaisesRegex(ValueError, 'lacks USB host'):
                    fetcher.fetch(target, output, 123)


if __name__ == '__main__':
    unittest.main()
