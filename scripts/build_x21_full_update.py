"""Combine current applications with the matching A/B base, not OHD alone."""
from pathlib import Path
import argparse,hashlib,re,subprocess,tempfile,zipfile
from fetch_x21_base import validate_firmware

def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
    return h.hexdigest()

def write_entry(output,path,name,inode):
    size=path.stat().st_size
    with path.open('rb') as f:checksum=sum(sum(b) for b in iter(lambda:f.read(1024*1024),b''))&0xffffffff
    filename=name.encode()+b'\0'
    fields=[inode,0o100644,0,0,1,0,size,0,0,0,0,len(filename),checksum]
    header=b'070702'+b''.join(f'{v:08x}'.encode() for v in fields)
    output.write(header+filename);output.write(b'\0'*(-(len(header)+len(filename))%4))
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''):output.write(block)
    output.write(b'\0'*(-size%4))

def build(firmware,application_update,output):
    validate_firmware(firmware)
    with tempfile.TemporaryDirectory() as tmp:
        work=Path(tmp)
        with zipfile.ZipFile(firmware) as z:
            for name,limit in [('uboot.img',4<<20),('boot.img',64<<20),('rootfs.img',64<<20)]:
                entry=z.getinfo('output/firmware/'+name)
                if entry.file_size>limit:raise ValueError('Oversized base partition: '+name)
                with z.open(entry) as src,(work/name).open('wb') as dst:
                    for b in iter(lambda:src.read(1024*1024),b''):dst.write(b)
        with application_update.open('rb') as src:
            subprocess.run(['cpio','-id','--quiet','--no-absolute-filenames','ohd.img'],stdin=src,cwd=work,check=True)
        if (work/'ohd.img').stat().st_size!=100<<20:raise ValueError('OHD update must cover standard mtd9')
        def image(name,device):
            return '{ filename = "'+name+'"; device = "'+device+'"; type = "flash"; sha256 = "'+digest(work/name)+'"; }'
        version=re.sub('[^A-Za-z0-9_.-]','_',output.stem)
        desc='software = { version = "'+version+'"; description = "Full X21B base and application update";\n'
        desc+='stable = {\n'
        for slot,devices in [('a',[0,3,7]),('b',[1,4,8])]:
            images=[image('ohd.img','mtd9')]
            images.extend(image(n,'mtd'+str(d)) for n,d in zip(['uboot.img','boot.img','rootfs.img'],devices))
            desc+='slot-'+slot+': { images: ('+','.join(images)+'); };\n'
        desc+='}; };\n'
        (work/'sw-description').write_text(desc)
        output.parent.mkdir(parents=True,exist_ok=True)
        with output.open('wb') as dst:
            for i,name in enumerate(['sw-description','ohd.img','uboot.img','boot.img','rootfs.img'],1):write_entry(dst,work/name,name,i)
            empty=work/'empty';empty.touch();write_entry(dst,empty,'TRAILER!!!',6)
    output.with_name(output.name+'.sha256').write_text(digest(output)+'  '+output.name+'\n')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('firmware',type=Path);p.add_argument('application_update',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
    build(a.firmware.resolve(),a.application_update.resolve(),a.output.resolve())
