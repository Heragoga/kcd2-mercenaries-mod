"""Build a queryable disassembly corpus from WHGame.dll.

Extracts the facts an analyst needs - function boundaries, strings, cross
references, call graph, RTTI classes and vtables, imports, cvar names - into a
SQLite database. Instructions are NOT stored; `disasm_query.py dis` disassembles
a function on demand, which keeps the corpus at a few hundred MB instead of ~2GB.

Every function is decoded from its own .pdata boundary rather than by scanning
for byte patterns, so cross references are attributed exactly and there are no
mid-instruction false positives.

    python tools/disasm_build.py [dll] [-o OUTDIR]

Default output is %KCD2_DISASM_DIR% or E:\\kcd2_disasm. See docs/disassembly.md.
"""
import argparse
import hashlib
import json
import os
import re
import sqlite3
import struct
import sys
import time

import pefile
from capstone import CS_ARCH_X86, CS_MODE_64, Cs

DEFAULT_DLL = r"C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2\Bin\Win64MasterMasterSteamPGO\WHGame.dll"
DEFAULT_OUT = os.environ.get("KCD2_DISASM_DIR", r"E:\kcd2_disasm")

STRING_SECTIONS = (".rdata", "_RDATA", ".data", ".rsrc")

SCHEMA = """
PRAGMA journal_mode=OFF;
PRAGMA synchronous=OFF;
CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE sections(name TEXT, rva INT, vsize INT, raw_size INT, chars INT, exec INT);
CREATE TABLE functions(
    rva INT PRIMARY KEY, end_rva INT, size INT, n_ins INT,
    name TEXT, class TEXT, vtable_index INT,
    is_fragment INT, primary_rva INT);
CREATE TABLE strings(rva INT PRIMARY KEY, len INT, section TEXT, text TEXT);
CREATE TABLE xrefs(src INT, dst INT, kind TEXT, src_fn INT);
CREATE TABLE calls(caller INT, callee INT, n INT);
CREATE TABLE rtti(name TEXT, td_rva INT, col_rva INT, vtable_rva INT, slots INT, base_off INT);
CREATE TABLE vtable_slots(vtable_rva INT, idx INT, fn_rva INT);
CREATE TABLE imports(dll TEXT, name TEXT, iat_rva INT);
CREATE TABLE cvars(name TEXT, str_rva INT, refs INT);
CREATE TABLE symbols(rva INT PRIMARY KEY, name TEXT, note TEXT);
CREATE TABLE binds(registrar INT, tbl TEXT, name TEXT, impl INT, ord INT);
"""

INDEXES = """
CREATE INDEX ix_fn_name ON functions(name);
CREATE INDEX ix_fn_class ON functions(class);
CREATE INDEX ix_str_text ON strings(text);
CREATE INDEX ix_xref_dst ON xrefs(dst);
CREATE INDEX ix_xref_src ON xrefs(src);
CREATE INDEX ix_xref_srcfn ON xrefs(src_fn);
CREATE INDEX ix_call_caller ON calls(caller);
CREATE INDEX ix_call_callee ON calls(callee);
CREATE INDEX ix_rtti_name ON rtti(name);
CREATE INDEX ix_rtti_vt ON rtti(vtable_rva);
CREATE INDEX ix_vts ON vtable_slots(vtable_rva, idx);
CREATE INDEX ix_vts_fn ON vtable_slots(fn_rva);
CREATE INDEX ix_imp_name ON imports(name);
CREATE INDEX ix_imp_iat ON imports(iat_rva);
CREATE INDEX ix_cvar ON cvars(name);
CREATE INDEX ix_sym_name ON symbols(name);
CREATE INDEX ix_bind_name ON binds(name);
CREATE INDEX ix_bind_impl ON binds(impl);
CREATE INDEX ix_bind_reg ON binds(registrar);
"""

RIP_RE = re.compile(r"\[rip ([+-]) (0x[0-9a-f]+)\]")
CVAR_RE = re.compile(
    r"^(?:wh|ai|g|r|e|s|p|sys|con|ac|es|ca|gt|net|v|q|d|i|t|mov|pl|cl|sv|log|mfx|hud)"
    r"_[A-Za-z][A-Za-z0-9_]{2,60}$")
IDENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]{1,63}$")

_T0 = time.time()


def log(msg):
    print(f"[{time.time() - _T0:7.1f}s] {msg}", flush=True)


class Img:
    def __init__(self, path):
        self.path = path
        self.pe = pefile.PE(path, fast_load=True)
        self.pe.parse_data_directories(directories=[
            pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_IMPORT"]])
        self.base = self.pe.OPTIONAL_HEADER.ImageBase
        self.buf = self.pe.get_memory_mapped_image()
        self.secs = [(s.Name.rstrip(b"\x00").decode(errors="replace"),
                      s.VirtualAddress,
                      s.VirtualAddress + max(s.Misc_VirtualSize, s.SizeOfRawData),
                      s.Misc_VirtualSize, s.SizeOfRawData, s.Characteristics)
                     for s in self.pe.sections]
        self._exec = [(lo, hi) for _, lo, hi, _, _, ch in self.secs if ch & 0x20000000]

    def sec_of(self, rva):
        for n, lo, hi, _, _, _ in self.secs:
            if lo <= rva < hi:
                return n
        return None

    def is_exec(self, rva):
        return any(lo <= rva < hi for lo, hi in self._exec)

    def rdata_ranges(self):
        return [(lo, hi) for n, lo, hi, _, _, _ in self.secs if n in (".rdata", "_RDATA")]

    def u32(self, rva):
        return struct.unpack_from("<I", self.buf, rva)[0]

    def u64(self, rva):
        return struct.unpack_from("<Q", self.buf, rva)[0]

    def valid(self, rva):
        return 0 <= rva < len(self.buf)


def parse_functions(im):
    """RUNTIME_FUNCTION entries; resolve chained fragments to their primary."""
    out = {}
    pdata = next((s for s in im.secs if s[0] == ".pdata"), None)
    if not pdata:
        return out
    lo, hi = pdata[1], pdata[1] + pdata[3]
    for rva in range(lo, hi - 11, 12):
        begin, end, unwind = struct.unpack_from("<III", im.buf, rva)
        if not begin or not im.valid(begin) or not im.is_exec(begin) or end <= begin:
            continue
        frag, primary = 0, begin
        if im.valid(unwind) and im.buf[unwind] >> 3 & 0x4:  # UNW_FLAG_CHAININFO
            chain = unwind + 4 + im.buf[unwind + 2] * 2
            chain += chain & 2
            if im.valid(chain + 12):
                p = im.u32(chain)
                if im.valid(p) and im.is_exec(p):
                    frag, primary = 1, p
        prev = out.get(begin)
        if prev is None or end > prev[0]:
            out[begin] = (end, frag, primary)
    return out


def extract_strings(im):
    pat = re.compile(rb"[\x20-\x7e]{4,400}\x00")
    for name, lo, hi, _, _, _ in im.secs:
        if name not in STRING_SECTIONS:
            continue
        for m in pat.finditer(im.buf, lo, hi):
            s = m.group()[:-1]
            yield m.start(), len(s), name, s.decode("latin1")


def decode_all(im, funcs, fn_set):
    """Decode every function; yield xrefs, call edges and instruction counts."""
    md = Cs(CS_ARCH_X86, CS_MODE_64)
    xrefs, edges, counts = [], {}, {}
    done = 0
    for start in sorted(funcs):
        end = funcs[start][0]
        n = 0
        for addr, size, mn, ops in md.disasm_lite(im.buf[start:end], start):
            n += 1
            if "rip" in ops:
                m = RIP_RE.search(ops)
                if m:
                    d = int(m.group(2), 16)
                    dst = addr + size + (-d if m.group(1) == "-" else d)
                    if im.valid(dst):
                        kind = "code" if im.is_exec(dst) else "data"
                        if mn in ("call", "jmp"):
                            kind = "iat"
                        xrefs.append((addr, dst, kind, start))
            elif mn in ("call", "jmp") and ops[:2] == "0x":
                dst = int(ops, 16)
                if dst in fn_set:
                    k = (start, dst)
                    edges[k] = edges.get(k, 0) + 1
                    if mn == "call":
                        xrefs.append((addr, dst, "call", start))
        counts[start] = n
        done += 1
        if done % 50000 == 0:
            log(f"  decoded {done:,}/{len(funcs):,} functions, {len(xrefs):,} xrefs")
    return xrefs, edges, counts


def vtable_len(im, vt_rva, cap=512):
    n = 0
    while n < cap:
        v = im.u64(vt_rva + n * 8)
        if not (im.base <= v < im.base + len(im.buf)) or not im.is_exec(v - im.base):
            break
        n += 1
    return n


def scan_rtti(im):
    """One pass for type descriptors, one for COLs, one for vftables."""
    td = {}
    for m in re.finditer(rb"\.\?A[VU][A-Za-z0-9_@?$]{0,250}@@\x00", im.buf):
        rva = m.start() - 0x10
        if rva >= 0:
            td[rva] = m.group()[:-1].decode("latin1")

    cols = {}  # col_va -> (name, td_rva, col_rva, base_off)
    for lo, hi in im.rdata_ranges():
        for col in range(lo, hi - 24, 4):
            if im.u32(col) != 1:
                continue
            t = im.u32(col + 12)
            if t in td and im.u32(col + 20) == col:
                cols[im.base + col] = (td[t], t, col, im.u32(col + 4))

    out = []
    for lo, hi in im.rdata_ranges():
        for q in range(lo, hi - 8, 8):
            v = im.u64(q)
            hit = cols.get(v)
            if hit is None:
                continue
            vt = q + 8
            n = vtable_len(im, vt)
            if n >= 2:
                name, t, col, boff = hit
                out.append((name, t, col, vt, n, boff))
    return out


def demangle(rtti_name):
    """'.?AVCScriptSystem@@' -> 'CScriptSystem'; namespaces joined with '::'."""
    body = rtti_name[4:-2] if rtti_name.endswith("@@") else rtti_name[4:]
    parts = [p for p in body.split("@") if p]
    return "::".join(reversed(parts)) if parts else rtti_name


def inject_igame(gim, rtti):
    """IGame ships no RTTI; add its vtable so its slots get named like the rest."""
    from disassemble_whgame import find_igame_vtable, vtable_len as guide_vtable_len
    vt, _ = find_igame_vtable(gim)
    if vt is not None:
        rtti.append((".?AVIGame@@", 0, 0, vt, guide_vtable_len(gim, vt), 0))


def rescue_symbols(db_path, new_sha, out_dir):
    """Hand-verified symbols outlast a rebuild - but only within the same binary.

    RVAs are meaningless across a patch, so if the DLL changed the old names are
    written to a dated JSON beside the corpus and NOT carried forward.
    """
    if not os.path.exists(db_path):
        return []
    try:
        old = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
        meta = dict(old.execute("SELECT key, value FROM meta"))
        rows = list(old.execute("SELECT rva, name, note FROM symbols"))
        old.close()
    except sqlite3.Error:
        return []
    if not rows:
        return []
    if meta.get("sha256") == new_sha:
        log(f"  carrying {len(rows)} existing symbols forward")
        return rows
    path = os.path.join(out_dir, f"symbols_{meta.get('build', 'unknown')}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump([{"rva": hex(r), "name": n, "note": o} for r, n, o in rows], f, indent=2)
    log(f"  !! binary changed: {len(rows)} symbols NOT carried (RVAs stale). Saved to {path}")
    return []


def seed_symbols(db, gim, rtti, carried=()):
    """Names verified in docs/disassembly.md, so annotations read gEnv->pConsole.

    Carried-over symbols win: they were checked against the real thing, these
    are only a starting point.
    """
    from disassemble_whgame import locate_genv
    syms = []
    found = locate_genv(gim)
    if found:
        g = found[0]
        syms += [(g, "gEnv", "SSystemGlobalEnvironment; derived from the exec autoexec.cfg site"),
                 (g + 0x28, "gEnv->pScriptSystem", "IScriptSystem*"),
                 (g + 0x90, "gEnv->pGame", "IGame*"),
                 (g + 0xA8, "gEnv->pConsole", "IConsole*")]
    vts = {demangle(n): vt for n, _t, _c, vt, _s, bo in rtti if bo == 0}
    for cls, i, nm in (("CScriptSystem", 5, "IScriptSystem::ExecuteFile"),
                       ("CScriptSystem", 6, "IScriptSystem::ExecuteBuffer"),
                       ("CScriptSystem", 7, "IScriptSystem::UnloadScript"),
                       ("CScriptSystem", 13, "IScriptSystem::CreateTable"),
                       ("CScriptTable", 7, "IScriptTable::SetValueAny"),
                       ("CScriptTable", 22, "IScriptTable::AddFunction"),
                       ("CXConsole", 35, "IConsole::ExecuteString"),
                       ("CCryAction", 100, "IGameFramework::RegisterListener"),
                       ("IGame", 4, "IGame::CompleteInit"),
                       ("IGame", 12, "IGame::GetLongName"),
                       ("IGame", 13, "IGame::GetName"),
                       ("IGame", 16, "IGame::GetIGameFramework")):
        vt = vts.get(cls)
        if vt is not None:
            syms.append((gim.qword(vt + i * 8) - gim.base, nm, f"{cls} vtable slot {i}"))
    syms += list(carried)  # last write wins, so verified names beat the seeds
    db.executemany("INSERT OR REPLACE INTO symbols VALUES(?,?,?)", syms)
    return db.execute("SELECT COUNT(*) FROM symbols").fetchone()[0]


def bind_candidates(xrefs, str_map, fn_set):
    """Functions that reference >=3 identifier strings and >=3 function pointers."""
    ns, nc = {}, {}
    for _s, d, k, f in xrefs:
        if f is None:
            continue
        if k == "data" and d in str_map and IDENT_RE.match(str_map[d]):
            ns[f] = ns.get(f, 0) + 1
        elif k == "code" and d in fn_set:
            nc[f] = nc.get(f, 0) + 1
    return [f for f, n in ns.items() if n >= 3 and nc.get(f, 0) >= 3]


def extract_binds(im, funcs, fn_set, str_map, cands):
    """name -> function registrations: `lea rdx,[name]` + `lea reg,[fn]` then a call.

    Covers CryEngine SCRIPT_REG_* (impl lea, functor call, name lea, register
    call) and the WH template registrars (impl lea, name lea, call) alike. The
    table name is the string handed to a callee that several registrars share a
    string-only call to (SetGlobalName and its WH equivalents), never a callee
    that also performs registrations.
    """
    md = Cs(CS_ARCH_X86, CS_MODE_64)
    per_fn, pair_callees = {}, set()
    for start in cands:
        end = funcs[start][0]
        name = impl = None
        name_at = impl_at = 0
        pairs, solo = [], []
        for ins in md.disasm(im.buf[start:end], start):
            if ins.mnemonic == "lea" and "rip" in ins.op_str:
                m = RIP_RE.search(ins.op_str)
                if not m:
                    continue
                d = int(m.group(2), 16)
                dst = ins.address + ins.size + (-d if m.group(1) == "-" else d)
                if dst in fn_set:
                    impl, impl_at = dst, ins.address
                elif ins.op_str.startswith("rdx,") and dst in str_map and IDENT_RE.match(str_map[dst]):
                    name, name_at = str_map[dst], ins.address
            elif ins.mnemonic == "call":
                direct = int(ins.op_str, 16) if ins.op_str[:2] == "0x" else None
                if name and impl and abs(name_at - impl_at) < 96:
                    pairs.append((name, impl))
                    name = impl = None
                    if direct is not None:
                        pair_callees.add(direct)
                elif name and impl is None and direct is not None:
                    solo.append((direct, name))
                    name = None
        if len(pairs) >= 3:
            per_fn[start] = (pairs, solo)

    # SetGlobalName is called once per registrar; SetGlobalValue("CONST", n) many times
    per_callee = {}
    for pairs, solo in per_fn.values():
        cnt = {}
        for c, _ in solo:
            if c not in pair_callees:
                cnt[c] = cnt.get(c, 0) + 1
        for c, k in cnt.items():
            per_callee.setdefault(c, []).append(k)
    namers = {c for c, ks in per_callee.items()
              if len(ks) >= 3 and sorted(ks)[len(ks) // 2] == 1}
    out = []
    for start, (pairs, solo) in per_fn.items():
        tbl = next((s for c, s in solo if c in namers), None)
        out += [(start, tbl, n, f, i) for i, (n, f) in enumerate(pairs)]
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dll", nargs="?", default=DEFAULT_DLL)
    ap.add_argument("-o", "--out", default=DEFAULT_OUT)
    a = ap.parse_args()
    if not os.path.isfile(a.dll):
        print("not found:", a.dll)
        return 1
    os.makedirs(a.out, exist_ok=True)
    db_path = os.path.join(a.out, "whgame.sqlite")

    log(f"loading {a.dll}")
    im = Img(a.dll)
    sha = hashlib.sha256(open(a.dll, "rb").read()).hexdigest()
    carried = rescue_symbols(db_path, sha, a.out)
    if os.path.exists(db_path):
        os.remove(db_path)
    version = ", ".join(sorted(set(
        t.decode() for t in re.findall(rb"(?:release|master)_\d+_\d+(?:_\d+)*", im.buf)))) or "?"
    log(f"build {version}  sha256 {sha[:16]}")

    db = sqlite3.connect(db_path)
    db.executescript(SCHEMA)
    db.executemany("INSERT INTO sections VALUES(?,?,?,?,?,?)",
                   [(n, lo, vs, rs, ch, 1 if ch & 0x20000000 else 0)
                    for n, lo, _hi, vs, rs, ch in im.secs])

    log("parsing .pdata")
    funcs = parse_functions(im)
    fn_set = set(funcs)
    covered = sum(v[0] - k for k, v in funcs.items())
    text_size = next(s[3] for s in im.secs if s[0] == ".text")
    log(f"  {len(funcs):,} functions, {sum(1 for v in funcs.values() if v[1]):,} fragments, "
        f"{100.0 * covered / text_size:.1f}% of .text covered")

    log("extracting strings")
    strs = list(extract_strings(im))
    db.executemany("INSERT OR IGNORE INTO strings VALUES(?,?,?,?)", strs)
    log(f"  {len(strs):,} strings")

    log("decoding functions")
    xrefs, edges, counts = decode_all(im, funcs, fn_set)
    for i in range(0, len(xrefs), 200000):
        db.executemany("INSERT INTO xrefs VALUES(?,?,?,?)", xrefs[i:i + 200000])
    db.executemany("INSERT INTO calls VALUES(?,?,?)",
                   ((s, d, c) for (s, d), c in edges.items()))
    log(f"  {len(xrefs):,} xrefs, {len(edges):,} call edges")

    log("scanning RTTI")
    rtti = scan_rtti(im)
    from disassemble_whgame import Image as GuideImage
    gim = GuideImage(a.dll)
    inject_igame(gim, rtti)
    names, slots = {}, []
    for name, _td, _col, vt, ns, boff in rtti:
        cls = demangle(name)
        for i in range(ns):
            fn = im.u64(vt + i * 8) - im.base
            slots.append((vt, i, fn))
            if boff == 0 and fn not in names:
                names[fn] = (f"{cls}::vf{i}", cls, i)
    db.executemany("INSERT INTO rtti VALUES(?,?,?,?,?,?)",
                   [(demangle(n), t, c, vt, ns, bo) for n, t, c, vt, ns, bo in rtti])
    db.executemany("INSERT INTO vtable_slots VALUES(?,?,?)", slots)
    log(f"  {len(rtti):,} vtables, {len(slots):,} slots, {len(names):,} functions named")

    log("imports")
    imps = []
    if hasattr(im.pe, "DIRECTORY_ENTRY_IMPORT"):
        for entry in im.pe.DIRECTORY_ENTRY_IMPORT:
            dll = entry.dll.decode(errors="replace")
            for f in entry.imports:
                imps.append((dll, (f.name or b"").decode(errors="replace") or f"ord_{f.ordinal}",
                             f.address - im.base if f.address else 0))
    db.executemany("INSERT INTO imports VALUES(?,?,?)", imps)
    log(f"  {len(imps):,} imports")

    log("writing functions")
    db.executemany("INSERT INTO functions VALUES(?,?,?,?,?,?,?,?,?)",
                   ((r, funcs[r][0], funcs[r][0] - r, counts.get(r, 0),
                     names.get(r, (f"sub_{r:X}", None, None))[0],
                     names.get(r, (None, None, None))[1],
                     names.get(r, (None, None, None))[2],
                     funcs[r][1], funcs[r][2]) for r in sorted(funcs)))

    log("cvar candidates")
    referenced = {}
    for _s, d, _k, _f in xrefs:
        referenced[d] = referenced.get(d, 0) + 1
    cvars = [(t, rva, referenced[rva]) for rva, _ln, _sec, t in strs
             if rva in referenced and CVAR_RE.match(t)]
    db.executemany("INSERT INTO cvars VALUES(?,?,?)", cvars)
    log(f"  {len(cvars):,} cvars")

    log("extracting name->function registrations")
    str_map = {rva: t for rva, _l, _s, t in strs}
    binds = extract_binds(im, funcs, fn_set, str_map, bind_candidates(xrefs, str_map, fn_set))
    db.executemany("INSERT INTO binds VALUES(?,?,?,?,?)", binds)
    log(f"  {len(binds):,} registrations in {len({b[0] for b in binds}):,} registrar functions")

    log("seeding symbols")
    log(f"  {seed_symbols(db, gim, rtti, carried):,} symbols")

    log("indexing")
    db.executescript(INDEXES)

    counts_tbl = {t: db.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
                  for t in ("functions", "strings", "xrefs", "calls", "rtti",
                            "vtable_slots", "imports", "cvars", "binds", "symbols")}
    meta = {"dll": a.dll, "sha256": sha, "build": version,
            "image_base": hex(im.base),
            "text_coverage_pct": f"{100.0 * covered / text_size:.1f}",
            "generated": time.strftime("%Y-%m-%d %H:%M:%S"),
            "tool": "disasm_build.py",
            **{f"n_{k}": v for k, v in counts_tbl.items()}}
    db.executemany("INSERT INTO meta VALUES(?,?)", ((k, str(v)) for k, v in meta.items()))
    db.commit()
    db.execute("VACUUM")
    db.close()

    with open(os.path.join(a.out, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)

    log(f"done -> {db_path}  ({os.path.getsize(db_path) / 1048576:.0f} MB)")
    for k, v in counts_tbl.items():
        print(f"    {k:<14}{v:>12,}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
