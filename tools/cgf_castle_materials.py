"""Restore shared castle slot indices after RC removes unused FBX materials.

Use on a fresh RC output: python tools/cgf_castle_materials.py file.cgf
Checks the embedded submaterial names instead of assuming a compacted order.
"""
from pathlib import Path
import struct
import sys
import cgf_setmtl

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'assets'))
from material_set import NAMES

LIBRARY='objects/mercenaries/walls/merc_castle_stone'

def patch(path):
    version,chunks=cgf_setmtl.read(path)
    libraries=[c for c in chunks if c['type']==0x1014]
    assert len(libraries)==1,'Expected one material library'
    mtl=libraries[0]
    assert mtl['ver']==0x802
    b=mtl['payload'];count=struct.unpack_from('<I',b,128)[0]
    assert 0<count<=len(NAMES),(path,count)
    physical=list(struct.unpack_from('<%di'%count,b,132))
    names=[n.decode('ascii') for n in b[132+4*count:].split(b'\0')[:count]]
    assert len(set(names))==count and all(n in NAMES for n in names),names
    mapping={i:NAMES.index(n) for i,n in enumerate(names)}
    for c in chunks:
        if c['type']!=0x1017:continue
        assert c['ver']==0x800
        body=bytearray(c['payload']);n=struct.unpack_from('<I',body,4)[0]
        for i in range(n):
            at=16+i*36+16
            old=struct.unpack_from('<i',body,at)[0]
            struct.pack_into('<i',body,at,mapping[old])
        c['payload']=bytes(body)
    phys=[-1]*len(NAMES)
    for old,new in mapping.items():phys[new]=physical[old]
    mtl['payload']=(LIBRARY.encode('ascii').ljust(128,b'\0')+struct.pack('<I',len(NAMES))
        +struct.pack('<%di'%len(phys),*phys)+b''.join(n.encode('ascii')+b'\0' for n in NAMES))
    cgf_setmtl.write(path,version,chunks)
    return names

if __name__=='__main__':
    print('Restored castle material slots:',patch(sys.argv[1]))
