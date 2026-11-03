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
    def test_nand_seed_is_downloaded_and_verified(self):
        target = 'luckfox-pico-mini-nand'
        name = 'openhd-base-' + target
        contents = {'firmware.zip': b'board-partitions', 'seed.tar.xz': b'rootfs-seed'}
        manifest = dict(target=target, runtime_abi='armv7a-hardfloat-uclibc',
                        image='firmware.zip', boot_medium='spi_nand', usb_role='host',
                        application_slots=False, rootfs_seed='seed.tar.xz',
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
        current = dict(legacy, usb_role='host')
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
