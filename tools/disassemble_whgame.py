"""Static analysis of WHGame.dll: locate gEnv and validate engine vtable offsets.

Implements the procedure from https://github.com/muyuanjin/kcd2-mod-docs
(DISASSEMBLY.md) without IDA, and re-derives everything from the binary so the
results stay valid after a game patch moves the addresses.

    python tools/disassemble_whgame.py genv [dll]
    python tools/disassemble_whgame.py validate [dll]
    python tools/disassemble_whgame.py builds <dll> [dll...]

See docs/disassembly.md for what the numbers mean.
"""
import os
import re
import struct
import sys

import pefile
from capstone import CS_ARCH_X86, CS_MODE_64, Cs

DEFAULT_DLL = r"C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2\Bin\Win64MasterMasterSteamPGO\WHGame.dll"

# The autoexec call site. Both forms load gEnv->pConsole into rcx; 1.4+ builds
# reordered the operands, so neither signature matches every build.
SIGS = [
    ("V1.1 - V1.2.2", "48 8B 0D ?? ?? ?? ?? 48 8D 15 ?? ?? ?? ?? 45 33 C9 45 33 C0 4C 8B 11 41 FF 92 ?? ?? ?? ?? 48 85 FF"),
    ("V1.4 - V1.5.x", "48 8B 0D ?? ?? ?? ?? 45 33 C9 45 33 C0 48 8B 11 4C 8B 92 ?? ?? ?? ?? 48 8D 15 ?? ?? ?? ?? 41 FF D2 48 85 FF"),
]

PCONSOLE_OFF = 0xA8  # gEnv->pConsole, 22nd member of SSystemGlobalEnvironment

GENV_MEMBERS = {0x28: "pScriptSystem", 0x90: "pGame", 0xA8: "pConsole"}

# guide item -> (gEnv member offset, vtable slot)
CLAIMS = [
    ("#4  IScriptSystem::CreateTable", 0x28, 0x68),
    ("#12 IScriptSystem::ExecuteBuffer", 0x28, 0x38),
    ("#7  IGame::CompleteInit", 0x90, 0x20),
    ("#8  IGame::GetLongName", 0x90, 0x60),
    ("#9  IGame::GetName", 0x90, 0x68),
    ("#10 IGame::GetIGameFramework", 0x90, 0x80),
]

# 7-byte RIP-relative forms: <2-byte opcode><modrm mod=00 rm=101><disp32>
RIP_PATTERNS = [p + bytes([(r << 3) | 5])
                for p in (b"\x48\x8d", b"\x4c\x8d", b"\x48\x8b",
                          b"\x4c\x8b", b"\x48\x89", b"\x4c\x89")
                for r in range(8)]


class Image:
    def __init__(self, path):
        self.path = path
        self.pe = pefile.PE(path, fast_load=True)
        self.base = self.pe.OPTIONAL_HEADER.ImageBase
        self.buf = self.pe.get_memory_mapped_image()
        self.secs = [(s.Name.rstrip(b"\x00").decode(errors="replace"),
                      s.VirtualAddress,
                      s.VirtualAddress + max(s.Misc_VirtualSize, s.SizeOfRawData),
                      s.Characteristics) for s in self.pe.sections]

    def sec_of(self, rva):
        for n, lo, hi, _ in self.secs:
            if lo <= rva < hi:
                return n
        return None

    def is_exec(self, rva):
        return any(lo <= rva < hi and ch & 0x20000000 for _, lo, hi, ch in self.secs)

    def exec_ranges(self):
        return [(lo, hi) for _, lo, hi, ch in self.secs if ch & 0x20000000]

    def rdata_ranges(self):
        return [(lo, hi) for n, lo, hi, _ in self.secs if n in (".rdata", "_RDATA")]

    def qword(self, rva):
        return struct.unpack_from("<Q", self.buf, rva)[0]

    def disp32(self, rva):
        return struct.unpack_from("<i", self.buf, rva)[0]

    def cstr(self, rva, cap=120):
        end = self.buf.find(b"\x00", rva, rva + cap)
        if end <= rva:
            return None
        s = self.buf[rva:end]
        return s.decode("latin1") if all(32 <= c < 127 for c in s) else None

    def version(self):
        tags = set(re.findall(rb"(?:release|master)_\d+_\d+(?:_\d+)*", self.buf))
        return ", ".join(sorted(t.decode() for t in tags)) or "?"

    def rip_refs_to(self, target_va):
        """Every RIP-relative instruction whose operand resolves to target_va."""
        out = []
        for lo, hi in self.exec_ranges():
            for pat in RIP_PATTERNS:
                pos = lo
                while True:
                    pos = self.buf.find(pat, pos, hi)
                    if pos < 0:
                        break
                    if self.base + pos + 7 + self.disp32(pos + 3) == target_va:
                        out.append(pos)
                    pos += 1
        return out


def parse_sig(sig):
    vals, mask = [], []
    for tok in sig.split():
        vals.append(0 if tok == "??" else int(tok, 16))
        mask.append(tok != "??")
    return vals, mask


def sig_scan(im, sig):
    vals, mask = parse_sig(sig)
    best_start = best_len = cur_start = cur_len = 0
    for i, m in enumerate(mask):
        if m:
            cur_start = cur_start if cur_len else i
            cur_len += 1
            if cur_len > best_len:
                best_len, best_start = cur_len, cur_start
        else:
            cur_len = 0
    anchor = bytes(vals[best_start:best_start + best_len])
    hits = []
    for lo, hi in im.exec_ranges():
        pos = lo
        while True:
            pos = im.buf.find(anchor, pos, hi)
            if pos < 0:
                break
            start = pos - best_start
            if start >= lo and all(not mask[k] or im.buf[start + k] == vals[k]
                                   for k in range(len(vals))):
                hits.append(start)
            pos += 1
    return sorted(set(hits))


def align_decode(im, md, win_start, target_rva):
    """Decode from successive starts until the stream lands exactly on target_rva."""
    for start in range(win_start, target_rva):
        ins = list(md.disasm(im.buf[start:target_rva + 24], im.base + start))
        if any(i.address == im.base + target_rva for i in ins):
            return start, ins
    return None, []


def locate_genv(im):
    """Returns (genv_rva, pconsole_rva, instructions, lea_rva) or None."""
    s = im.buf.find(b"exec autoexec.cfg\x00")
    if s < 0:
        return None
    xrefs = im.rip_refs_to(im.base + s)
    if not xrefs:
        return None
    md = Cs(CS_ARCH_X86, CS_MODE_64)
    _, ins = align_decode(im, md, xrefs[0] - 64, xrefs[0])
    mov = None
    for i in ins:
        if i.address >= im.base + xrefs[0]:
            break
        if i.mnemonic == "mov" and i.op_str.startswith("rcx, qword ptr [rip"):
            mov = i
    if mov is None:
        return None
    mrva = mov.address - im.base
    pconsole = mrva + 7 + im.disp32(mrva + 3)
    return pconsole - PCONSOLE_OFF, pconsole, ins, xrefs[0]


def cmd_genv(paths):
    im = Image(paths[0])
    print(f"file        : {im.path}")
    print(f"image base  : 0x{im.base:X}   build {im.version()}")

    s = im.buf.find(b"exec autoexec.cfg\x00")
    print(f"\n[1] 'exec autoexec.cfg' at RVA 0x{s:08X} ({im.sec_of(s)})")
    xrefs = im.rip_refs_to(im.base + s)
    print(f"[2] RIP-relative xrefs: {len(xrefs)}" + "".join(f"  RVA 0x{x:08X}" for x in xrefs))

    print("[3] signature coverage")
    for label, sig in SIGS:
        hits = sig_scan(im, sig)
        state = "UNIQUE" if len(hits) == 1 else ("no match" if not hits else f"{len(hits)} matches")
        extra = f"  RVA 0x{hits[0]:08X}" if len(hits) == 1 else ""
        print(f"      {label:<16} {state}{extra}")

    found = locate_genv(im)
    if not found:
        print("!! could not resolve gEnv")
        return
    genv, pconsole, ins, lea = found
    print(f"\n[4] call site")
    for i in ins:
        tag = ""
        if i.address == im.base + lea:
            tag = "   <- 'exec autoexec.cfg'"
        elif i.mnemonic == "mov" and i.op_str.startswith("rcx, qword ptr [rip") \
                and i.address - im.base + 7 + im.disp32(i.address - im.base + 3) == pconsole:
            tag = "   <- gEnv->pConsole"
        print(f"      0x{i.address:012X}  {i.bytes.hex(' '):<26} {i.mnemonic:<7} {i.op_str}{tag}")
        if i.address > im.base + lea + 8:
            break

    print(f"\n[5] &gEnv->pConsole  RVA 0x{pconsole:08X}   VA 0x{im.base + pconsole:X}   ({im.sec_of(pconsole)})")
    print(f"    gEnv             RVA 0x{genv:08X}   VA 0x{im.base + genv:X}   ({im.sec_of(genv)})")

    print("\n[6] cross-check - RIP references to each gEnv slot")
    for off in sorted(GENV_MEMBERS):
        n = len(im.rip_refs_to(im.base + genv + off))
        print(f"      gEnv+0x{off:02X}  {GENV_MEMBERS[off]:<14} {n:>6} refs")


def slot_histogram(im, member_va):
    """Vtable slots the game calls through a gEnv member."""
    md = Cs(CS_ARCH_X86, CS_MODE_64)
    hist = {}
    for pos in im.rip_refs_to(member_va):
        iface = vtbl = None
        for k, ins in enumerate(md.disasm(im.buf[pos:pos + 80], im.base + pos)):
            if k > 14 or ins.mnemonic in ("ret", "jmp"):
                break
            ops = ins.op_str
            if k == 0 and ins.mnemonic == "mov":
                iface = ops.split(",")[0].strip()
            elif iface and ins.mnemonic == "mov" and ops.endswith(f"qword ptr [{iface}]"):
                vtbl = ops.split(",")[0].strip()
            elif vtbl and f"[{vtbl} +" in ops and ins.mnemonic in ("call", "mov"):
                off = int(ops.split("+")[1].strip(" ]"), 16)
                hist[off] = hist.get(off, 0) + 1
                break
            elif vtbl and ins.mnemonic == "call" and ops == f"qword ptr [{vtbl}]":
                hist[0] = hist.get(0, 0) + 1
                break
    return hist


def vtable_len(im, vt_rva, cap=256):
    n = 0
    while n < cap:
        v = im.qword(vt_rva + n * 8)
        if not (im.base <= v < im.base + len(im.buf)) or not im.is_exec(v - im.base):
            break
        n += 1
    return n


def vtable_index_of(im, fn_va):
    """(vtable_rva, index) for every .rdata pointer to fn_va."""
    out = []
    key = struct.pack("<Q", fn_va)
    for lo, hi in im.rdata_ranges():
        p = lo
        while True:
            p = im.buf.find(key, p, hi)
            if p < 0:
                break
            if p % 8 == 0:
                start = p
                while start - 8 >= lo:
                    v = im.qword(start - 8)
                    if not (im.base <= v < im.base + len(im.buf)) or not im.is_exec(v - im.base):
                        break
                    start -= 8
                out.append((start, (p - start) // 8))
            p += 1
    return out


def find_igame_vtable(im):
    """IGame has no RTTI here; find it via GetName returning 'KCD2'."""
    for lo, hi in im.exec_ranges():
        pos = lo
        while True:
            pos = im.buf.find(b"\x48\x8d\x05", pos, hi)
            if pos < 0:
                break
            if im.buf[pos + 7] == 0xC3:
                tgt = pos + 7 + im.disp32(pos + 3)
                if 0 <= tgt < len(im.buf) and im.cstr(tgt) == "KCD2":
                    for vt, idx in vtable_index_of(im, im.base + pos):
                        return vt, idx
            pos += 1
    return None, None


def fn_strings(im, fn_rva, max_ins=120):
    md = Cs(CS_ARCH_X86, CS_MODE_64)
    out = []
    for k, ins in enumerate(md.disasm(im.buf[fn_rva:fn_rva + 700], im.base + fn_rva)):
        if k > max_ins or ins.mnemonic == "ret":
            break
        if ins.mnemonic == "lea" and "[rip" in ins.op_str:
            tgt = ins.address - im.base + ins.size + im.disp32(ins.address - im.base + ins.size - 4)
            if 0 <= tgt < len(im.buf) and not im.is_exec(tgt):
                s = im.cstr(tgt)
                if s and len(s) >= 3 and s not in out:
                    out.append(s)
    return out


def cmd_validate(paths):
    im = Image(paths[0])
    found = locate_genv(im)
    if not found:
        print("!! could not resolve gEnv")
        return
    genv, _, _, _ = found
    print(f"file  : {im.path}")
    print(f"build : {im.version()}")
    print(f"gEnv  : RVA 0x{genv:08X}\n")

    hists = {}
    for off, name in GENV_MEMBERS.items():
        hists[off] = slot_histogram(im, im.base + genv + off)
        top = sorted(hists[off], key=lambda k: -hists[off][k])[:6]
        summary = ", ".join(f"0x{s:X}({hists[off][s]})" for s in top)
        print(f"  gEnv+0x{off:02X} {name:<14} busiest slots: {summary}")

    print("\nguide 'Verified Offsets' vs this build")
    for label, member, slot in CLAIMS:
        n = hists.get(member, {}).get(slot, 0)
        print(f"  {label:<34} slot 0x{slot:03X} index {slot // 8:<3} "
              f"{'called ' + str(n) + 'x' if n else 'no direct gEnv call site'}")

    vt, idx = find_igame_vtable(im)
    if vt is None:
        print("\n  IGame vtable: not found")
        return
    igame_vt = vt
    print(f"\n  IGame vftable RVA 0x{igame_vt:08X}  slots={vtable_len(im, igame_vt)}"
          f"   (GetName found at index {idx})")
    for i in (4, 12, 13, 16):
        fn = im.qword(igame_vt + i * 8)
        hints = "; ".join(fn_strings(im, fn - im.base)[:2])
        print(f"      [{i:>2}] slot 0x{i * 8:03X}  fn 0x{fn:X}  {hints}")


def cmd_builds(paths):
    print(f"{'build':<28} {'size':>11} {'version':<22} {'gEnv RVA':>10} {'pConsole RVA':>13}")
    print("-" * 90)
    rows = []
    for p in paths:
        im = Image(p)
        found = locate_genv(im)
        name = os.path.basename(p)
        if not found:
            print(f"{name:<28} {os.path.getsize(p):>11,} {im.version():<22} !! unresolved")
            continue
        genv, pconsole, _, _ = found
        print(f"{name:<28} {os.path.getsize(p):>11,} {im.version():<22} "
              f"0x{genv:08X} 0x{pconsole:08X}")
        rows.append((name, im))
    print("\nsignature validity")
    print(f"{'build':<28} " + " ".join(f"{l:>16}" for l, _ in SIGS))
    for name, im in rows:
        cells = []
        for _, sig in SIGS:
            n = len(sig_scan(im, sig))
            cells.append("UNIQUE" if n == 1 else ("-" if n == 0 else f"{n}x AMBIG"))
        print(f"{name:<28} " + " ".join(f"{c:>16}" for c in cells))


def main(argv):
    cmds = {"genv": cmd_genv, "validate": cmd_validate, "builds": cmd_builds}
    if len(argv) < 2 or argv[1] not in cmds:
        print(__doc__)
        return 1
    paths = argv[2:] or [DEFAULT_DLL]
    missing = [p for p in paths if not os.path.isfile(p)]
    if missing:
        print("not found: " + ", ".join(missing))
        return 1
    cmds[argv[1]](paths)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
