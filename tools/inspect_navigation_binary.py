"""Read-only PE inspection for the installed game's navigation investigation."""
import argparse
import re
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tmp/collision-python'))
import pefile
from capstone import Cs, CS_ARCH_X86, CS_MODE_64

p = argparse.ArgumentParser()
p.add_argument('binary')
p.add_argument('pattern')
p.add_argument('--disasm', action='store_true')
p.add_argument('--address', type=lambda s: int(s, 16))
p.add_argument('--size', type=int, default=600)
args = p.parse_args()
data = Path(args.binary).read_bytes()
pe = pefile.PE(data=data)
base = pe.OPTIONAL_HEADER.ImageBase
md = Cs(CS_ARCH_X86, CS_MODE_64)
if args.address:
    offset = pe.get_offset_from_rva(args.address-base)
    for ins in md.disasm(data[offset:offset+args.size], args.address):
        note = ''
        match = re.search(r'\[rip ([+-]) (0x[0-9a-f]+)\]', ins.op_str)
        if match:
            target = ins.address+ins.size+int(match[2],16)*(1 if match[1]=='+' else -1)
            try:
                at = pe.get_offset_from_rva(target-base)
                st = data[at:at+160].split(b'\0')[0]
                if len(st)>3 and all(32<=x<127 for x in st): note=' ; '+st.decode()
            except Exception: pass
        print(f'{ins.address:x}: {ins.mnemonic:8} {ins.op_str}{note}')
    sys.exit()
strings = {}
for m in re.finditer(rb'[\x20-\x7e]{5,}', data):
    s = m.group().decode()
    if re.search(args.pattern, s, re.I):
        strings[base + pe.get_rva_from_offset(m.start())] = s
for addr, s in strings.items():
    print(f'STRING {addr:x} {s}')
for entry in getattr(pe, 'DIRECTORY_ENTRY_EXPORT', []).symbols:
    name = (entry.name or b'').decode(errors='replace')
    if re.search(args.pattern, name, re.I):
        print(f'EXPORT {base + entry.address:x} {name}')
if not args.disasm:
    sys.exit()
functions = [(base+e.struct.BeginAddress, base+e.struct.EndAddress)
             for e in getattr(pe, 'DIRECTORY_ENTRY_EXCEPTION', [])]
shown = set()
for sec in pe.sections:
    if not sec.Characteristics & 0x20000000:
        continue
    raw = sec.get_data()
    va = base + sec.VirtualAddress
    # RIP-relative LEA operands, validated by the disassembler before use.
    for m in re.finditer(rb'[\x48-\x4f]\x8d[\x05\x0d\x15\x1d\x25\x2d\x35\x3d]', raw):
        i = m.start()
        if i+7 > len(raw): continue
        dest = va+i+7+struct.unpack_from('<i',raw,i+3)[0]
        if dest not in strings: continue
        print(f'XREF {va+i:x} -> {strings[dest]}')
        bounds = next(((a,b) for a,b in functions if a<=va+i<b), (va+i-48,va+i+96))
        if bounds in shown: continue
        shown.add(bounds)
        a,b = bounds
        if b-a>6000: a,b=max(a,va+i-150),min(b,va+i+200)
        off=pe.get_offset_from_rva(a-base)
        for ins in md.disasm(data[off:off+b-a],a):
            print(f'  {ins.address:x}: {ins.mnemonic:8} {ins.op_str}')
