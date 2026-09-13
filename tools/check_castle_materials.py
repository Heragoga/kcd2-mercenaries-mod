"""Regression checks for the actual material header/slot export failures."""
from pathlib import Path
import struct
import cgf_setmtl as c

names=b'wall\0quoin\0allure\0trim\0proxy\0'
tail=struct.pack('<I',5)+struct.pack('<5i',*([-1]*5))+names
original=b'default'.ljust(128,b'\0')+tail
library='objects/mercenaries/walls/merc_castle_stone'
patched=c.set_library(original,library)
assert len(patched)==len(original)
assert patched[128:]==tail
broken=library.encode()+b'\0'+original[len(b'default\0'):]
assert c.set_library(broken,library)==patched
assert c.set_library(patched,library)==patched
root=Path(__file__).resolve().parents[1]
for path in (root/'data/Objects/mercenaries/walls').glob('merc_castle_*.cgf'):
    for ch in c.read(path)[1]:
        if ch['type']!=0x1014:continue
        b=ch['payload'];n=struct.unpack_from('<I',b,128)[0]
        assert n in [3,7],(path,n)
        names=b[132+4*n:].split(b'\0')
        assert len(names)==n+1 and names[-1]==b'',(path,n,names)
print('PASS: fixed header size, legacy repair, idempotence, all shipped castle material tables')
