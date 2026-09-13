"""Render the whole of WHGame.dll as annotated assembly text.

`disasm_query.py dis` is the fast path for one function. This is for when you
want the code on disk: every function in .pdata, disassembled, with strings,
call targets, symbols and vtable slots resolved inline - about 1.5 GB across
~60 shards, plus a TSV index so a shard and line can be found without grepping
the lot.

    python tools/disasm_listing.py            # -> %KCD2_DISASM_DIR%\\listing
    python tools/disasm_listing.py --limit 500

Reads the corpus built by disasm_build.py (needs it for names/xrefs).
"""
import argparse
import bisect
import os
import sqlite3
import sys
import time

import pefile
from capstone import CS_ARCH_X86, CS_MODE_64, Cs

DEFAULT_DIR = os.environ.get("KCD2_DISASM_DIR", r"E:\kcd2_disasm")
SHARD = 0x100000  # 1 MB of code per shard

_T0 = time.time()


def log(m):
    print(f"[{time.time() - _T0:7.1f}s] {m}", flush=True)


class Ctx:
    """Everything needed to label an address, preloaded into memory."""

    def __init__(self, d):
        db = sqlite3.connect(f"file:{os.path.join(d, 'whgame.sqlite')}?mode=ro", uri=True)
        self.meta = dict(db.execute("SELECT key, value FROM meta"))
        self.base = int(self.meta["image_base"], 16)

        self.fn = {}
        for rva, end, size, n_ins, name, cls, vi in db.execute(
                "SELECT rva, end_rva, size, n_ins, name, class, vtable_index FROM functions"):
            self.fn[rva] = (end, size, n_ins, name, cls, vi)
        self.sym = {r: (n, o) for r, n, o in db.execute("SELECT rva, name, note FROM symbols")}
        self.str = dict(db.execute("SELECT rva, text FROM strings"))
        self.imp = {r: f"{n} ({d_})" for d_, n, r in
                    db.execute("SELECT dll, name, iat_rva FROM imports")}

        self.callers = {}
        for callee, n in db.execute("SELECT callee, COUNT(*) FROM calls GROUP BY callee"):
            self.callers[callee] = n
        self.caller_names = {}
        for callee, caller in db.execute("SELECT callee, caller FROM calls"):
            self.caller_names.setdefault(callee, []).append(caller)

        vt = sorted(db.execute("SELECT vtable_rva, slots, name FROM rtti WHERE base_off = 0"))
        self.vt_start = [v[0] for v in vt]
        self.vt = vt

        self.sec = sorted((r, r + v, n) for n, r, v in
                          db.execute("SELECT name, rva, vsize FROM sections"))
        self.sec_start = [s[0] for s in self.sec]

        self.bind = {}
        for impl, tbl, name in db.execute("SELECT impl, tbl, name FROM binds"):
            self.bind.setdefault(impl, []).append(f"{tbl}.{name}" if tbl else name)
        db.close()

        pe = pefile.PE(self.meta["dll"], fast_load=True)
        self.img = pe.get_memory_mapped_image()

    def name_of(self, rva):
        s = self.sym.get(rva)
        if s:
            return s[0]
        f = self.fn.get(rva)
        return f[3] if f else f"0x{rva:X}"

    def describe(self, rva):
        s = self.sym.get(rva)
        if s:
            return s[0]
        t = self.str.get(rva)
        if t is not None:
            return '"' + (t[:70] + "..." if len(t) > 70 else t) + '"'
        i = self.imp.get(rva)
        if i:
            return "import " + i
        f = self.fn.get(rva)
        if f:
            return f[3]
        j = bisect.bisect_right(self.vt_start, rva) - 1
        if j >= 0:
            start, slots, nm = self.vt[j]
            if rva < start + slots * 8:
                return f"{nm}::vftable[{(rva - start) // 8}]"
        k = bisect.bisect_right(self.sec_start, rva) - 1
        if k >= 0 and rva < self.sec[k][1]:
            return f"{self.sec[k][2]}:0x{rva:X}"
        return f"0x{rva:X}"


def header(c, rva):
    end, size, n_ins, name, cls, vi = c.fn[rva]
    out = [";" + "=" * 78]
    sym = c.sym.get(rva)
    title = f"; {sym[0]}   ({name})" if sym and sym[0] != name else f"; {name}"
    out.append(title)
    out.append(f"; RVA 0x{rva:08X}-0x{end:08X}   VA 0x{c.base + rva:X}   "
               f"{size} bytes, {n_ins} instructions")
    if cls:
        out.append(f"; vtable  : {cls} slot {vi} (0x{vi * 8:X})")
    if sym and sym[1]:
        out.append(f"; symbol  : {sym[1]}")
    for b in c.bind.get(rva, [])[:4]:
        out.append(f"; lua     : {b}")
    n = c.callers.get(rva, 0)
    if n:
        names = ", ".join(c.name_of(x) for x in sorted(set(c.caller_names.get(rva, [])))[:6])
        out.append(f"; callers : {n}   {names}")
    out.append(";" + "=" * 78)
    return out


def render(c, rva, md):
    end = c.fn[rva][0]
    lines = header(c, rva)
    code = c.img[rva:end]
    for addr, size, mn, ops in md.disasm_lite(code, rva):
        note = ""
        if "rip" in ops:
            i = ops.find("[rip ")
            if i >= 0:
                j = ops.find("]", i)
                body = ops[i + 5:j]
                try:
                    d = int(body[2:], 16)
                    tgt = addr + size + (-d if body[0] == "-" else d)
                    note = "    ; " + c.describe(tgt)
                except ValueError:
                    pass
        elif mn in ("call", "jmp") and ops[:2] == "0x":
            try:
                tgt = int(ops, 16)
                if tgt in c.fn:
                    note = "    ; " + c.name_of(tgt)
            except ValueError:
                pass
        raw = code[addr - rva:addr - rva + size].hex(" ")
        lines.append(f"  {addr:08X}  {raw:<26} {mn:<7} {ops}{note}")
    lines.append("")
    return lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=DEFAULT_DIR)
    ap.add_argument("--limit", type=int, help="only this many functions (smoke test)")
    a = ap.parse_args()

    log("loading corpus")
    c = Ctx(a.dir)
    out_dir = os.path.join(a.dir, "listing")
    os.makedirs(out_dir, exist_ok=True)
    log(f"{len(c.fn):,} functions, {len(c.str):,} strings, {len(c.sym)} symbols")

    md = Cs(CS_ARCH_X86, CS_MODE_64)
    rvas = sorted(c.fn)
    if a.limit:
        rvas = rvas[:a.limit]

    index = open(os.path.join(out_dir, "INDEX.tsv"), "w", encoding="utf-8", newline="\n")
    index.write("rva_hex\tname\tshard\tline\tsize\tn_ins\n")

    cur_shard, fh, line_no, n_lines = None, None, 1, 0
    written = 0
    for rva in rvas:
        shard = rva - (rva % SHARD)
        if shard != cur_shard:
            if fh:
                fh.close()
            cur_shard = shard
            fname = f"text_{shard:07X}.asm"
            fh = open(os.path.join(out_dir, fname), "w", encoding="utf-8", newline="\n")
            banner = [f"; WHGame.dll {c.meta['build']}  shard 0x{shard:07X}-0x{shard + SHARD:07X}",
                      f"; image base {c.meta['image_base']} - addresses below are RVAs",
                      f"; generated by tools/disasm_listing.py; index in INDEX.tsv", ""]
            fh.write("\n".join(banner) + "\n")
            line_no = len(banner) + 1
        lines = render(c, rva, md)
        fh.write("\n".join(lines) + "\n")
        index.write(f"{rva:08X}\t{c.name_of(rva)}\t{os.path.basename(fh.name)}\t{line_no}"
                    f"\t{c.fn[rva][1]}\t{c.fn[rva][2]}\n")
        line_no += len(lines)
        n_lines += len(lines)
        written += 1
        if written % 25000 == 0:
            log(f"  {written:,}/{len(rvas):,} functions, {n_lines:,} lines")
    if fh:
        fh.close()
    index.close()

    shards = sorted(f for f in os.listdir(out_dir) if f.endswith(".asm"))
    total = sum(os.path.getsize(os.path.join(out_dir, f)) for f in shards)
    log(f"done: {written:,} functions, {n_lines:,} lines, {len(shards)} shards, "
        f"{total / 1073741824:.2f} GB -> {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
