"""Query the WHGame.dll disassembly corpus built by disasm_build.py.

    python tools/disasm_query.py info
    python tools/disasm_query.py fn       <addr|name>         function summary
    python tools/disasm_query.py dis      <addr|name> [-n N]  annotated disassembly
    python tools/disasm_query.py strings  <regex> [-n N]      strings + who references them
    python tools/disasm_query.py xrefs    <addr>              every reference to an address
    python tools/disasm_query.py callers  <addr|name>
    python tools/disasm_query.py callees  <addr|name>
    python tools/disasm_query.py vtable   <class|addr>        slots with hints
    python tools/disasm_query.py rtti     <regex>             classes
    python tools/disasm_query.py imports  <regex>
    python tools/disasm_query.py cvar     <regex>             cvar/command names + users
    python tools/disasm_query.py binds    <regex>             Lua-style name->function registrations
    python tools/disasm_query.py symbols  <regex>             named addresses (gEnv, verified vtable slots, ...)
    python tools/disasm_query.py name     <addr> <name> [--note ...]   label an address for everyone
    python tools/disasm_query.py at       <addr>              what lives at an address
    python tools/disasm_query.py sql      "<select ...>"      raw query

Addresses: VA (0x1808641A9), RVA (0x8641A9 / 8641A9), a function name
(sub_8641A9, CScriptSystem::vf13) or a symbol (gEnv->pConsole). The corpus lives
in %KCD2_DISASM_DIR% or E:\\kcd2_disasm.
"""
import argparse
import os
import re
import sqlite3
import sys

DEFAULT_DIR = os.environ.get("KCD2_DISASM_DIR", r"E:\kcd2_disasm")


class Corpus:
    def __init__(self, d):
        path = os.path.join(d, "whgame.sqlite")
        if not os.path.isfile(path):
            sys.exit(f"corpus not found: {path}  (run tools/disasm_build.py)")
        self.db = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
        self.meta = dict(self.db.execute("SELECT key, value FROM meta"))
        self.base = int(self.meta["image_base"], 16)
        self.symbols = dict(self.db.execute("SELECT rva, name FROM symbols"))
        self._img = None

    # ---- image on demand (only `dis` and `at` need bytes) ----
    @property
    def img(self):
        if self._img is None:
            import pefile
            pe = pefile.PE(self.meta["dll"], fast_load=True)
            self._img = pe.get_memory_mapped_image()
        return self._img

    # ---- address helpers ----
    def rva(self, s):
        """Accept VA, RVA, or a function name; return RVA."""
        s = s.strip()
        row = self.db.execute("SELECT rva FROM functions WHERE name = ?", (s,)).fetchone()
        if row:
            return row[0]
        row = self.db.execute("SELECT rva FROM symbols WHERE name = ?", (s,)).fetchone()
        if row:
            return row[0]
        m = re.fullmatch(r"(?:0x)?([0-9a-fA-F]+)", s)
        if not m:
            m2 = re.fullmatch(r"sub_([0-9a-fA-F]+)", s)
            if not m2:
                sys.exit(f"not an address or known name: {s}")
            return int(m2.group(1), 16)
        v = int(m.group(1), 16)
        return v - self.base if v >= self.base else v

    def fn_of(self, rva):
        return self.db.execute(
            "SELECT * FROM functions WHERE rva <= ? ORDER BY rva DESC LIMIT 1", (rva,)).fetchone() \
            if self.db.execute("SELECT 1 FROM functions WHERE rva <= ? AND end_rva > ?",
                               (rva, rva)).fetchone() else None

    def fn_name(self, rva):
        s = self.symbols.get(rva)
        if s:
            return s
        r = self.db.execute("SELECT name FROM functions WHERE rva = ?", (rva,)).fetchone()
        return r[0] if r else f"0x{rva:X}"

    def string_at(self, rva):
        r = self.db.execute("SELECT text FROM strings WHERE rva = ?", (rva,)).fetchone()
        return r[0] if r else None

    def import_at(self, rva):
        r = self.db.execute("SELECT dll, name FROM imports WHERE iat_rva = ?", (rva,)).fetchone()
        return f"{r[1]} ({r[0]})" if r else None

    def vtable_at(self, rva):
        r = self.db.execute(
            "SELECT name, vtable_rva FROM rtti WHERE vtable_rva <= ? AND vtable_rva + slots*8 > ?",
            (rva, rva)).fetchone()
        return f"{r[0]}::vftable+0x{rva - r[1]:X}" if r else None

    def describe(self, rva):
        """One-line label for any address."""
        if rva in self.symbols:
            return self.symbols[rva]
        s = self.string_at(rva)
        if s is not None:
            return f'"{s[:70]}"'
        i = self.import_at(rva)
        if i:
            return f"import {i}"
        v = self.vtable_at(rva)
        if v:
            return v
        f = self.fn_of(rva)
        if f:
            return f[4] if f[0] == rva else f"{f[4]}+0x{rva - f[0]:X}"
        sec = self.db.execute(
            "SELECT name FROM sections WHERE rva <= ? AND rva + vsize > ?", (rva, rva)).fetchone()
        return f"{sec[0]}:0x{rva:X}" if sec else f"0x{rva:X}"


def va(c, rva):
    return f"0x{c.base + rva:X}"


# ---------------------------------------------------------------- commands
def cmd_info(c, a):
    for k, v in c.meta.items():
        print(f"{k:<20} {v}")


def cmd_fn(c, a):
    rows = c.db.execute("SELECT * FROM functions WHERE name LIKE ? LIMIT 50",
                        (a.target,)).fetchall() if "%" in a.target else []
    if not rows:
        rva = c.rva(a.target)
        f = c.fn_of(rva)
        rows = [f] if f else []
    if not rows:
        print("no function contains that address")
        return
    for f in rows:
        rva, end, size, n_ins, name, cls, vi, frag, primary = f
        print(f"{name}   RVA 0x{rva:X}   VA {va(c, rva)}   size {size}   {n_ins} instructions")
        sym = c.db.execute("SELECT name, note FROM symbols WHERE rva = ?", (rva,)).fetchone()
        if sym:
            print(f"   symbol   : {sym[0]}   ({sym[1]})")
        if cls:
            print(f"   vtable   : {cls} slot {vi} (0x{vi * 8:X})")
        for tbl, bname, reg in c.db.execute(
                "SELECT tbl, name, registrar FROM binds WHERE impl = ? LIMIT 4", (rva,)):
            print(f"   bound as : {(tbl + '.') if tbl else ''}{bname}   (registered in {c.fn_name(reg)})")
        nreg = c.db.execute("SELECT COUNT(*), tbl FROM binds WHERE registrar = ?", (rva,)).fetchone()
        if nreg and nreg[0]:
            print(f"   registrar: {nreg[0]} names" + (f" for table {nreg[1]}" if nreg[1] else "") +
                  "   (list with: binds --registrar)")
        if frag:
            print(f"   fragment : chained to {c.fn_name(primary)}")
        others = c.db.execute(
            "SELECT r.name, v.idx FROM vtable_slots v JOIN rtti r ON r.vtable_rva = v.vtable_rva "
            "WHERE v.fn_rva = ? AND NOT (r.name = ? AND v.idx = ?) LIMIT 8", (rva, cls or "", vi or -1)).fetchall()
        if others:
            print("   also in  : " + ", ".join(f"{n}[{i}]" for n, i in others))
        callers = c.db.execute(
            "SELECT caller, n FROM calls WHERE callee = ? ORDER BY n DESC", (rva,)).fetchall()
        callees = c.db.execute(
            "SELECT callee, n FROM calls WHERE caller = ? ORDER BY n DESC", (rva,)).fetchall()
        print(f"   callers  : {len(callers)}" +
              ("  " + ", ".join(c.fn_name(x) for x, _ in callers[:8]) if callers else ""))
        print(f"   callees  : {len(callees)}" +
              ("  " + ", ".join(c.fn_name(x) for x, _ in callees[:8]) if callees else ""))
        strs = c.db.execute(
            "SELECT DISTINCT s.text FROM xrefs x JOIN strings s ON s.rva = x.dst "
            "WHERE x.src_fn = ? LIMIT 12", (rva,)).fetchall()
        if strs:
            print("   strings  : " + " | ".join(f'"{s[0][:60]}"' for s in strs))
        imps = c.db.execute(
            "SELECT DISTINCT i.name FROM xrefs x JOIN imports i ON i.iat_rva = x.dst "
            "WHERE x.src_fn = ? LIMIT 12", (rva,)).fetchall()
        if imps:
            print("   imports  : " + ", ".join(i[0] for i in imps))
        if len(rows) > 1:
            print()


def cmd_dis(c, a):
    from capstone import CS_ARCH_X86, CS_MODE_64, Cs
    rva = c.rva(a.target)
    f = c.fn_of(rva)
    if not f:
        sys.exit("no function contains that address")
    start, end, _, _, name = f[0], f[1], f[2], f[3], f[4]
    ann = {}
    for src, dst, kind in c.db.execute(
            "SELECT src, dst, kind FROM xrefs WHERE src_fn = ?", (start,)):
        ann[src] = c.describe(dst)
    md = Cs(CS_ARCH_X86, CS_MODE_64)
    print(f"; {name}   RVA 0x{start:X}-0x{end:X}   VA {va(c, start)}")
    n = 0
    for ins in md.disasm(c.img[start:end], start):
        if n >= a.max:
            print(f"; ... truncated at {a.max} instructions (use -n)")
            break
        n += 1
        note = ann.get(ins.address)
        tail = f"    ; {note}" if note else ""
        mark = "" if ins.address != rva or rva == start else "  <--"
        print(f"  {ins.address:08X}  {ins.bytes.hex(' '):<24} {ins.mnemonic:<7} {ins.op_str}{tail}{mark}")


def cmd_strings(c, a):
    pat = re.compile(a.pattern, re.I)
    n = 0
    for rva, text in c.db.execute("SELECT rva, text FROM strings"):
        if not pat.search(text):
            continue
        n += 1
        if n > a.max:
            print(f"... more than {a.max} matches (use -n)")
            break
        users = c.db.execute(
            "SELECT DISTINCT src_fn FROM xrefs WHERE dst = ? AND src_fn IS NOT NULL LIMIT 6",
            (rva,)).fetchall()
        who = ", ".join(c.fn_name(u[0]) for u in users) or "-"
        print(f"0x{rva:08X}  {text[:90]!r:<94} <- {who}")


def cmd_xrefs(c, a):
    rva = c.rva(a.target)
    print(f"references to 0x{rva:X} ({c.describe(rva)}):")
    rows = c.db.execute(
        "SELECT src, kind, src_fn FROM xrefs WHERE dst = ? ORDER BY src LIMIT ?",
        (rva, a.max)).fetchall()
    for src, kind, fn in rows:
        print(f"  {kind:<5} 0x{src:08X}  in {c.fn_name(fn) if fn else '?'}")
    print(f"{len(rows)} shown")


def cmd_callers(c, a):
    rva = c.rva(a.target)
    rows = c.db.execute("SELECT caller, n FROM calls WHERE callee = ? ORDER BY n DESC LIMIT ?",
                        (rva, a.max)).fetchall()
    print(f"callers of {c.fn_name(rva)}: {len(rows)}")
    for r, n in rows:
        print(f"  {c.fn_name(r):<40} 0x{r:08X}  x{n}")


def cmd_callees(c, a):
    rva = c.rva(a.target)
    rows = c.db.execute("SELECT callee, n FROM calls WHERE caller = ? ORDER BY n DESC LIMIT ?",
                        (rva, a.max)).fetchall()
    print(f"callees of {c.fn_name(rva)}: {len(rows)}")
    for r, n in rows:
        print(f"  {c.fn_name(r):<40} 0x{r:08X}  x{n}")


def cmd_vtable(c, a):
    rows = c.db.execute(
        "SELECT name, vtable_rva, slots, base_off FROM rtti WHERE name = ? OR name LIKE ?",
        (a.target, a.target)).fetchall()
    if not rows:
        rva = c.rva(a.target)
        rows = c.db.execute(
            "SELECT name, vtable_rva, slots, base_off FROM rtti WHERE vtable_rva = ?", (rva,)).fetchall()
    if not rows:
        print("no vtable")
        return
    for name, vt, slots, boff in rows:
        print(f"{name}  vftable RVA 0x{vt:X}  VA {va(c, vt)}  slots={slots}  base_off={boff}")
        for idx, fn in c.db.execute(
                "SELECT idx, fn_rva FROM vtable_slots WHERE vtable_rva = ? ORDER BY idx", (vt,)):
            strs = c.db.execute(
                "SELECT s.text FROM xrefs x JOIN strings s ON s.rva = x.dst WHERE x.src_fn = ? LIMIT 3",
                (fn,)).fetchall()
            hint = "; ".join(s[0][:40] for s in strs)
            fname = c.fn_name(fn)
            print(f"   [{idx:>3}] 0x{idx * 8:04X}  0x{fn:08X}  {fname:<36} {hint}")


def cmd_rtti(c, a):
    pat = re.compile(a.pattern, re.I)
    rows = [r for r in c.db.execute("SELECT name, vtable_rva, slots, base_off FROM rtti ORDER BY name")
            if pat.search(r[0])]
    for name, vt, slots, boff in rows[:a.max]:
        print(f"{name:<60} vftable 0x{vt:08X}  slots={slots:<4} base_off={boff}")
    print(f"{min(len(rows), a.max)} of {len(rows)} shown")


def cmd_imports(c, a):
    pat = re.compile(a.pattern, re.I)
    n = 0
    for dll, name, iat in c.db.execute("SELECT dll, name, iat_rva FROM imports ORDER BY dll, name"):
        if pat.search(name) or pat.search(dll):
            users = c.db.execute("SELECT COUNT(DISTINCT src_fn) FROM xrefs WHERE dst = ?", (iat,)).fetchone()[0]
            print(f"{dll:<28} {name:<48} iat 0x{iat:08X}  used by {users} fns")
            n += 1
            if n >= a.max:
                print("... (use -n)")
                break


def cmd_cvar(c, a):
    pat = re.compile(a.pattern, re.I)
    n = 0
    for name, rva, refs in c.db.execute("SELECT name, str_rva, refs FROM cvars ORDER BY name"):
        if not pat.search(name):
            continue
        n += 1
        if n > a.max:
            print("... (use -n)")
            break
        users = c.db.execute(
            "SELECT DISTINCT src_fn FROM xrefs WHERE dst = ? AND src_fn IS NOT NULL LIMIT 4", (rva,)).fetchall()
        print(f"{name:<44} str 0x{rva:08X}  refs {refs:<3} <- " +
              ", ".join(c.fn_name(u[0]) for u in users))


def cmd_at(c, a):
    rva = c.rva(a.target)
    print(f"0x{rva:X}  VA {va(c, rva)}  -> {c.describe(rva)}")
    sec = c.db.execute("SELECT name FROM sections WHERE rva <= ? AND rva + vsize > ?", (rva, rva)).fetchone()
    print(f"section  : {sec[0] if sec else '?'}")
    n = c.db.execute("SELECT COUNT(*) FROM xrefs WHERE dst = ?", (rva,)).fetchone()[0]
    print(f"xrefs    : {n}")
    raw = c.img[rva:rva + 32]
    print(f"bytes    : {raw.hex(' ')}")


def cmd_binds(c, a):
    if a.registrar:
        reg = c.rva(a.registrar)
        rows = c.db.execute(
            "SELECT tbl, name, impl, registrar FROM binds WHERE registrar = ? ORDER BY ord", (reg,)).fetchall()
    else:
        pat = re.compile(a.pattern, re.I)
        rows = [r for r in c.db.execute("SELECT tbl, name, impl, registrar FROM binds ORDER BY tbl, name")
                if pat.search(r[1]) or (r[0] and pat.search(r[0]))]
    for tbl, name, impl, reg in rows[:a.max]:
        label = f"{tbl}.{name}" if tbl else name
        print(f"{label:<44} impl {c.fn_name(impl):<32} 0x{impl:08X}   registrar {c.fn_name(reg)}")
    print(f"{min(len(rows), a.max)} of {len(rows)} shown")


def cmd_symbols(c, a):
    pat = re.compile(a.pattern, re.I)
    for rva, name, note in c.db.execute("SELECT rva, name, note FROM symbols ORDER BY rva"):
        if pat.search(name) or pat.search(note or ""):
            print(f"0x{rva:08X}  {name:<40} {note or ''}")


def cmd_name(c, a):
    rva = c.rva(a.target)
    rw = sqlite3.connect(os.path.join(a.dir, "whgame.sqlite"))
    rw.execute("INSERT OR REPLACE INTO symbols VALUES(?,?,?)", (rva, a.name, a.note))
    rw.commit()
    rw.close()
    print(f"0x{rva:X} = {a.name}")


def cmd_sql(c, a):
    cur = c.db.execute(a.query)
    cols = [d[0] for d in cur.description] if cur.description else []
    if cols:
        print(" | ".join(cols))
    for i, row in enumerate(cur):
        if i >= a.max:
            print("... (use -n)")
            break
        print(" | ".join(f"0x{v:X}" if isinstance(v, int) and v > 4096 else str(v) for v in row))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dir", default=DEFAULT_DIR)
    sub = ap.add_subparsers(dest="cmd", required=True)

    def add(name, fn, target=None, pattern=None, query=None, n=40):
        p = sub.add_parser(name)
        if target:
            p.add_argument("target")
        if pattern:
            p.add_argument("pattern")
        if query:
            p.add_argument("query")
        p.add_argument("-n", "--max", type=int, default=n)
        p.set_defaults(fn=fn)

    add("info", cmd_info)
    add("fn", cmd_fn, target=True)
    add("dis", cmd_dis, target=True, n=400)
    add("strings", cmd_strings, pattern=True)
    add("xrefs", cmd_xrefs, target=True, n=60)
    add("callers", cmd_callers, target=True)
    add("callees", cmd_callees, target=True)
    add("vtable", cmd_vtable, target=True)
    add("rtti", cmd_rtti, pattern=True, n=80)
    add("imports", cmd_imports, pattern=True, n=80)
    add("cvar", cmd_cvar, pattern=True, n=80)
    add("at", cmd_at, target=True)
    add("sql", cmd_sql, query=True, n=100)
    add("symbols", cmd_symbols, pattern=True, n=500)
    p = sub.add_parser("binds")
    p.add_argument("pattern", nargs="?", default=".")
    p.add_argument("--registrar", help="list every name registered by this function")
    p.add_argument("-n", "--max", type=int, default=80)
    p.set_defaults(fn=cmd_binds)
    p = sub.add_parser("name")
    p.add_argument("target")
    p.add_argument("name")
    p.add_argument("--note", default="")
    p.set_defaults(fn=cmd_name)

    a = ap.parse_args()
    a.fn(Corpus(a.dir), a)


if __name__ == "__main__":
    main()
