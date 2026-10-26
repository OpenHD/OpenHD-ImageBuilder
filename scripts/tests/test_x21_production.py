"""Check full-update contents and reject mixed SDKs or nonproduction bases."""
from pathlib import Path
import hashlib,io,json,re,subprocess,sys,tarfile,tempfile,unittest,zipfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from fetch_x21_base import validate_index,validate_payloads
from resolve_matching_components import select_pair
from build_x21_full_update import build,write_entry

class ProductionTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.work=Path(self.tmp.name)
        self.firmware=self.work/'firmware.zip';self.seed=self.work/'seed.tar.gz'
        self.make_firmware()
        self.make_seed()

    def make_firmware(self,ohd=100,root=b'hsqsread-only-root'):
        sizes={'ohd':ohd<<20,'boot_a':64<<20,'boot_b':64<<20,'rootfs_a':64<<20,'rootfs_b':64<<20}
        table=' '.join(f'0x{size//512:x}@0x0({name})' for name,size in sizes.items())
        with zipfile.ZipFile(self.firmware,'w') as z:
            for name,data in {'parameter.txt':table.encode(),'rootfs.img':root,'boot.img':b'new-kernel','uboot.img':b'bootloader'}.items():
                z.writestr('output/firmware/'+name,data)

    def make_seed(self,name='start-ohd.sh'):
        with tarfile.open(self.seed,'w:gz') as t:
            item=tarfile.TarInfo(name);item.size=3;t.addfile(item,io.BytesIO(b'run'))

    def test_reject_debug_storage_and_writable_root(self):
        validate_payloads(self.firmware,self.seed)
        self.make_firmware(ohd=192)
        with self.assertRaisesRegex(ValueError,'ohd'):validate_payloads(self.firmware,self.seed)
        self.make_firmware(root=b'UBI#')
        with self.assertRaisesRegex(ValueError,'SquashFS'):validate_payloads(self.firmware,self.seed)

    def test_reject_bench_state(self):
        for name in ['x21-diagnostics/capture.h264','ohd-rw/video.json','.ssh/key','../escape']:
            self.make_seed(name)
            with self.subTest(name=name),self.assertRaises(ValueError):validate_payloads(self.firmware,self.seed)

    def test_require_production_index(self):
        index={'schema':1,'platform':'x21b','production':True,'camera_profile':'arducam_openhd',
               'storage':{'ohd_bytes':100<<20,'boot_bytes':64<<20,'rootfs_bytes':64<<20,'rootfs_type':'squashfs'},
               'sdk_sha256':'a'*64,'sdk_buildroot_commit':'b'*40,
               'files':{r:{'filename':'openhd-x21b-'+r,'sha256':'c'*64,'size':1} for r in ['firmware','ohd_seed']}}
        validate_index(index)
        index['production']=False
        with self.assertRaises(ValueError):validate_index(index)

    def test_newest_matching_base_sdk(self):
        def candidate(sdk,date,name):return ({'sdk_sha256':sdk,'sdk_buildroot_commit':'base'},name,date)
        ohd=[candidate('old','2026-01-01','old-ohd'),candidate('base','2026-02-01','base-ohd'),candidate('base','2026-03-01','newest-ohd')]
        sysutils=[candidate('old','2026-04-01','old-sys'),candidate('base','2026-03-01','base-sys')]
        self.assertEqual(select_pair(ohd,sysutils,'base')[:2],('newest-ohd','base-sys'))
        with self.assertRaises(RuntimeError):select_pair(ohd,sysutils,'missing')

    def test_new_sysutils_is_selected_when_openhd_upload_is_older(self):
        def candidate(date,name):return ({'sdk_sha256':'sdk','sdk_buildroot_commit':'base'},name,date)
        ohd=[candidate('2026-01-01','openhd')]
        sysutils=[candidate('2026-02-01','z-old-sysutils'),candidate('2026-03-01','a-new-sysutils')]
        self.assertEqual(select_pair(ohd,sysutils,'sdk')[:2],('openhd','a-new-sysutils'))

    def test_full_update_contains_new_base_and_ohd_for_each_slot(self):
        ohd=self.work/'ohd.img'
        with ohd.open('wb') as f:f.truncate(100<<20)
        app=self.work/'application.ohd'
        empty=self.work/'empty';empty.touch()
        with app.open('wb') as f:
            write_entry(f,ohd,'ohd.img',1);write_entry(f,empty,'TRAILER!!!',2)
        output=self.work/'full.ohd_base';build(self.firmware,app,output)
        extract=self.work/'extract';extract.mkdir()
        with output.open('rb') as src:
            subprocess.run(['cpio','-id','--quiet'],stdin=src,cwd=extract,check=True)
        desc=(extract/'sw-description').read_text()
        for slot,devices in [('a',[9,0,3,7]),('b',[9,1,4,8])]:
            section=desc.split('slot-'+slot+':')[1].split('); };')[0]
            for device in devices:self.assertIn('device = "mtd'+str(device)+'"',section)
            self.assertIn('ohd.img',section)
        self.assertEqual((extract/'boot.img').read_bytes(),b'new-kernel')
        self.assertEqual((extract/'ohd.img').stat().st_size,100<<20)
        for name in ['ohd.img','uboot.img','boot.img','rootfs.img']:
            sha=hashlib.sha256((extract/name).read_bytes()).hexdigest()
            self.assertIn(sha,desc)
        self.assertEqual(output.with_name(output.name+'.sha256').read_text().split()[0],hashlib.sha256(output.read_bytes()).hexdigest())

if __name__=='__main__':unittest.main()
