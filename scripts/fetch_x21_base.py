"""Fetch firmware and OHD seed from a single verified production build index."""
from pathlib import Path,PurePosixPath
import argparse,hashlib,json,re,tarfile,time,urllib.error,urllib.parse,urllib.request,zipfile

BASE_URL='https://dl.cloudsmith.io/public/openhd/dev-release/raw/files/'
INDEX_URL=BASE_URL+'openhd-x21b-base-latest.json'

def validate_index(index):
    if (index.get('schema'),index.get('platform'),index.get('production'),index.get('camera_profile'))!=(1,'x21b',True,'arducam_openhd'):
        raise ValueError('A production arducam_openhd base is required; rebuild OpenHD-X21B with camera=arducam_openhd')
    expected={'ohd_bytes':100<<20,'boot_bytes':64<<20,'rootfs_bytes':64<<20,'rootfs_type':'squashfs'}
    if index.get('storage')!=expected:raise ValueError('Nonstandard/debug X21 storage layout')
    for key in ['sdk_sha256','sdk_buildroot_commit']:
        if not re.fullmatch('[0-9a-f]{64}' if key=='sdk_sha256' else '[0-9a-f]{40}',index.get(key,'')):
            raise ValueError('Missing SDK provenance: '+key)
    for role in ['firmware','ohd_seed']:
        entry=index['files'][role];name=entry['filename']
        if not re.fullmatch(r'openhd-x21b-[A-Za-z0-9_.-]+',name) or '/' in name:
            raise ValueError('Invalid base filename')
        if not re.fullmatch('[0-9a-f]{64}',entry['sha256']) or entry['size']<=0:
            raise ValueError('Invalid base checksum/size')

def download(url,path,expected=None):
    for attempt in range(5):
        h=hashlib.sha256();size=0
        try:
            with urllib.request.urlopen(url,timeout=120) as response,path.open('wb') as out:
                for block in iter(lambda:response.read(1024*1024),b''):
                    out.write(block);h.update(block);size+=len(block)
            break
        except (urllib.error.URLError,TimeoutError,OSError):
            if attempt==4:raise
            time.sleep(3)
    if expected and (h.hexdigest()!=expected['sha256'] or size!=expected['size']):
        path.unlink();raise ValueError('Base artifact checksum/size mismatch: '+path.name)

def validate_firmware(firmware):
    with zipfile.ZipFile(firmware) as z:
        for name in ['boot.img','rootfs.img','uboot.img','parameter.txt']:
            if z.namelist().count('output/firmware/'+name)!=1:
                raise ValueError('Missing or duplicate base firmware partition: '+name)
        with z.open('output/firmware/rootfs.img') as f:
            if f.read(4)!=b'hsqs':
                raise ValueError('Base firmware does not use a read-only SquashFS root')
        table=z.read('output/firmware/parameter.txt').decode()
        sizes={n:int(s,16)*512 for s,n in re.findall(r'(0x[0-9a-fA-F]+)@0x[0-9a-fA-F]+\(([^)]+)\)',table)}
        for n,size in {'ohd':100<<20,'boot_a':64<<20,'boot_b':64<<20,'rootfs_a':64<<20,'rootfs_b':64<<20}.items():
            if sizes.get(n)!=size:raise ValueError('Wrong base partition size: '+n)
def validate_payloads(firmware,seed):
    validate_firmware(firmware)
    with tarfile.open(seed,'r:gz') as t:
        for member in t:
            path=PurePosixPath(member.name);parts=path.parts
            if path.is_absolute() or any(p in {'x21-diagnostics','.ssh','captures','..'} for p in parts):
                raise ValueError('Debug or invalid data in production seed: '+member.name)
            if 'ohd-rw' in parts and member.isfile():
                raise ValueError('Saved user/bench settings in production seed')

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--index-url',default=INDEX_URL)
    p.add_argument('--output',type=Path,required=True);p.add_argument('--env-file',type=Path,required=True);a=p.parse_args()
    a.output.mkdir(parents=True,exist_ok=True)
    index_path=a.output/'base-manifest.json';download(a.index_url,index_path)
    index=json.loads(index_path.read_text());validate_index(index)
    for role,dst in [('firmware','firmware.zip'),('ohd_seed','ohd-seed.tar.gz')]:
        entry=index['files'][role]
        download(BASE_URL+urllib.parse.quote(entry['filename']),a.output/dst,entry)
    validate_payloads(a.output/'firmware.zip',a.output/'ohd-seed.tar.gz')
    with a.env_file.open('a') as f:
        for key,value in {'X21_BASE_VERSION':index['version'],'X21_BASE_SDK_SHA256':index['sdk_sha256'],
                          'X21_CAMERA_PROFILE':index['camera_profile'],
                          'X21_BASE_BUILDROOT_COMMIT':index['sdk_buildroot_commit'],
                          'X21_OHD_SEED_SHA256':index['files']['ohd_seed']['sha256']}.items():
            if '\n' in str(value):raise ValueError('Invalid metadata value')
            f.write(key+'='+str(value)+'\n')
    print('Verified production X21 base '+index['version'])
if __name__=='__main__':main()
