"""KCD2 modding knowledge base: full-text search, API/cvar lookup, section reader, web UI, docs lint.

    python tools/kb.py search  <query> [--source docs,api] [--tag ai] [--kind guide]
                                        [--scope kcd2|mercenaries] [--status current] [-n 10] [--json]
    python tools/kb.py api     <name|prefix|regex>     Lua ScriptBind lookup (docs/kcd2/api/index.tsv)
    python tools/kb.py cvar    <regex> [--all-data]    cvar lookup (docs/kcd2/data/cvars.tsv)
    python tools/kb.py show    <path[#anchor]|path:line> [--all]   print one section, or a page outline
    python tools/kb.py toc     [--scope ..] [--tag ..] [--kind ..]  map of the docs (from frontmatter)
    python tools/kb.py build   [--full] [--with-vanilla] [--with-code] [--no-vanilla] [--no-code]
    python tools/kb.py stats                           what is in the index
    python tools/kb.py serve   [--port 8765]           local web UI on http://127.0.0.1:8765/
    python tools/kb.py check   [--strict] [-n N]       docs lint; exit 1 on errors

Query syntax: words are ANDed (falls back to OR when nothing has them all), "quoted phrase",
-word excludes, word* is a prefix. Identifiers work as typed: System.SetCVar, entity:GetWorldPos,
ai_CompatibilityMode, XGenAIModule.SendMessageToEntity; so do their parts (CVar, SendMessage).
Hits print as  path:line#anchor  [source/kind/status]  Page > Section  plus the matching line,
with the matched terms marked >>like this<<. Feed `path#anchor` to `show` to read that section.

Sources (tag with --source): docs (docs/**/*.md|txt), api (docs/kcd2/api), data (docs/kcd2/data/*.tsv),
wiki (references/.../official-wiki), vanilla (vanilla Scripts + Libs/Tables, opt-in: build
--with-vanilla), mod (this mod's data/**/*.lua|xml, opt-in: build --with-code). Opt-in sources stay
on for later builds until --no-vanilla / --no-code. The index lives in tools/out/kb.sqlite, is
rebuilt incrementally (mtime+size) and is refreshed automatically when docs change.

Python 3 stdlib only (sqlite3 with FTS5).
"""
import argparse
import difflib
import html
import json
import os
import posixpath
import re
import sqlite3
import sys
import time
import unicodedata
import urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_ROOT = os.path.dirname(HERE)
SCHEMA = 4
CONTENTLESS = ", content='', contentless_delete=1" if sqlite3.sqlite_version_info >= (3, 43, 0) else ""

TAGS = ["lua", "ai", "bt", "skald", "ui", "camp", "combat", "engine", "data", "assets", "world",
        "audio", "testing", "tooling"]
KINDS = ["guide", "reference", "feature", "postmortem", "test-plan", "research", "index"]
STATUSES = ["current", "historical", "superseded"]
SCOPES = ["kcd2", "mercenaries"]
REQUIRED_FM = ["title", "summary", "tags", "kind", "status", "scope"]
PUBLIC_GUIDE_DIRS = ("general", "skald", "xml", "behaviour-trees", "tutorials")

ALL_SOURCES = ["docs", "api", "data", "wiki", "vanilla", "mod"]
DEFAULT_SOURCES = ["docs", "api", "data", "wiki"]
OPTIONAL_SOURCES = ["vanilla", "mod"]
STATIC_SOURCES = {"vanilla"}          # not stat-walked on every search; only on `build`

WIKI_DIR = "references/kcd2-mod-docs-main/official-wiki"
VANILLA_DIRS = [("references/kcd2-mod-docs-main/Scripts", (".lua", ".xml", ".ent")),
                ("references/kcd2-mod-docs-main/Libs/Tables", (".xml",))]
MOD_DIRS = [("data", (".lua", ".xml"))]
MOD_SKIP = ("data/Scripts/mods/mercveg",)     # generated vegetation tiles (46 MB of numbers)
CODE_SOURCES = ("vanilla", "mod")             # stored in the contentless `ftsc` table
CODE_MAX_BYTES = 4_000_000
API_DIR = "docs/kcd2/api"
DATA_DIR = "docs/kcd2/data"

# Weights for bm25(fts, title, heading, names, ident, body): a hit in the page title, the section
# heading or a declared name beats one in running text.
BM25_W = (10.0, 6.0, 6.0, 1.5, 1.0)
SOURCE_FACTOR = {"api": 1.1, "docs": 1.0, "data": 0.8, "wiki": 0.9, "mod": 0.7, "vanilla": 0.55}
STATUS_FACTOR = {"historical": 0.6, "superseded": 0.45}

CODE_MAX_LINES = 12000        # lines of one vanilla/mod file that get indexed
CODE_CHUNK = 80               # target lines per code chunk
DOC_CHUNK_MAX = 160           # doc sections longer than this are split (same anchor)


# ----------------------------------------------------------------------------------------------
# text helpers

def read_text(path):
    with open(path, "rb") as f:
        data = f.read()
    if data.startswith(b"\xef\xbb\xbf"):
        data = data[3:]
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        text = data.decode("cp1252", errors="replace")
    return text.replace("\r\n", "\n").replace("\r", "\n")


def read_lines(path):
    return read_text(path).split("\n")


IDENT_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*(?:[.:][A-Za-z_][A-Za-z0-9_]*)*")
CAMEL_RE = re.compile(r"[A-Z]+(?=[A-Z][a-z])|[A-Z]?[a-z]+|[A-Z]+|[0-9]+")
INTERESTING_RE = re.compile(r"[._:]|[a-z][A-Z]|[A-Z]{2}[a-z]|[A-Za-z][0-9]")
WORD_RE = re.compile(r"[^\W_]+", re.UNICODE)


def ident_variants(tok, out, parts_out=None):
    """Whole identifier and its dotted/underscored parts go to `out`; camelCase runs
    (SetCVar -> set, cvar, setc, ...) go to `parts_out` (a weaker column) when given."""
    parts_out = out if parts_out is None else parts_out
    parts = [p for p in re.split(r"[.:]", tok) if p]
    if len(parts) > 1:
        out.add("".join(parts).replace("_", "").lower())
    for p in parts:
        subs = [s for s in p.split("_") if s]
        if len(subs) > 1:
            out.add("".join(subs).lower())
        for s in subs:
            out.add(s.lower())
            camel = CAMEL_RE.findall(s)
            k = len(camel)
            if 1 < k <= 12:
                for i in range(k):
                    for j in range(i + 1, min(k, i + 4) + 1):
                        if j - i < k:
                            parts_out.add("".join(camel[i:j]).lower())


def idents_of(text, out=None, all_tokens=False, parts_out=None):
    out = set() if out is None else out
    for tok in IDENT_RE.findall(text):
        if all_tokens or INTERESTING_RE.search(tok):
            ident_variants(tok, out, parts_out)
    return out


def ident_str(s):
    return " ".join(sorted(v for v in s if len(v) > 1))


# ----------------------------------------------------------------------------------------------
# frontmatter

def _scalar(v):
    v = v.strip()
    if v[:1] in "\"'" and v[-1:] == v[:1] and len(v) >= 2:
        return v[1:-1]
    m = re.match(r"^(.*?)\s+#.*$", v)
    if m and not v.startswith("["):
        v = m.group(1).strip()
    if v.startswith("[") and "]" in v:
        inner = v[1:v.rindex("]")]
        return [x.strip().strip("\"'") for x in inner.split(",") if x.strip()]
    return v


def parse_frontmatter(lines):
    """-> (dict or None, index of first body line, [(lineno, msg)])"""
    if not lines or lines[0].strip() != "---":
        return None, 0, []
    end = None
    for i in range(1, min(len(lines), 300)):
        if lines[i].strip() in ("---", "..."):
            end = i
            break
    if end is None:
        return None, 0, [(1, "frontmatter opened with --- but never closed")]
    fm, errs, key = {}, [], None
    for j in range(1, end):
        raw = lines[j].rstrip()
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        m = re.match(r"^([A-Za-z_][\w-]*)\s*:(?:\s+(.*)|\s*)$", raw)
        if m and not raw[0].isspace():
            key = m.group(1)
            val = (m.group(2) or "").strip()
            fm[key] = "" if val in ("", ">", "|", ">-", "|-") else _scalar(val)
        elif key and raw.lstrip().startswith("- "):
            if not isinstance(fm.get(key), list):
                fm[key] = []
            fm[key].append(_scalar(raw.lstrip()[2:]))
        elif key and raw[0].isspace() and isinstance(fm.get(key), str):
            fm[key] = (fm[key] + " " + raw.strip()).strip()
        else:
            errs.append((j + 1, f"unparseable frontmatter line: {raw.strip()[:60]}"))
    return fm, end + 1, errs


# ----------------------------------------------------------------------------------------------
# markdown structure: headings with GitHub anchors

FENCE_RE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
ATX_RE = re.compile(r"^ {0,3}(#{1,6})(?:[ \t]+(.*?))?[ \t]*$")
SETEXT_RE = re.compile(r"^ {0,3}(=+|-+)[ \t]*$")
HR_RE = re.compile(r"^ {0,3}([-*_])(?:[ \t]*\1){2,}[ \t]*$")
LIST_RE = re.compile(r"^( {0,3})([-*+]|\d{1,9}[.)])(?:([ \t]+)(.*)|$)")


def strip_inline(t):
    """Rendered text of a heading line (what GitHub slugs): markup gone, code content kept."""
    codes = []

    def keep(m):
        codes.append(m.group(2))
        return f"\x00{len(codes) - 1}\x00"
    t = re.sub(r"(`+)(.+?)\1", keep, t)
    t = re.sub(r"!\[([^\]]*)\]\([^)]*\)", r"\1", t)
    t = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", t)
    t = re.sub(r"\[([^\]]*)\]\[[^\]]*\]", r"\1", t)
    t = re.sub(r"<[^>]+>", "", t)
    t = t.replace("\\", "") if "\\" in t else t
    t = re.sub(r"\*+", "", t)
    t = re.sub(r"(?<![A-Za-z0-9_])_+(?=[^\s_])|(?<=[^\s_])_+(?![A-Za-z0-9_])", "", t)
    t = re.sub(r"~~", "", t)
    t = re.sub(r"\x00(\d+)\x00", lambda m: codes[int(m.group(1))], t)
    return html.unescape(t).strip()


def slug_base(text):
    out = []
    for ch in text.strip().lower():
        if ch in " -_" or ch.isalnum() or unicodedata.category(ch)[0] in "LMN" or unicodedata.category(ch) == "Pc":
            out.append(ch)
    return "".join(out).replace(" ", "-")


class Slugger:
    """github-slugger: duplicates get -1, -2, ..."""

    def __init__(self):
        self.seen = {}

    def slug(self, text):
        base = slug_base(text)
        s = base
        while s in self.seen:
            self.seen[base] += 1
            s = f"{base}-{self.seen[base]}"
        self.seen[s] = 0
        return s


class Heading:
    __slots__ = ("line", "level", "raw", "text", "slug")

    def __init__(self, line, level, raw, text, slug):
        self.line, self.level, self.raw, self.text, self.slug = line, level, raw, text, slug


def md_headings(lines, start=None):
    """Top-level headings (ATX + setext), skipping frontmatter and fenced code. line is 0-based."""
    if start is None:
        _, start, _ = parse_frontmatter(lines)
    out, sl = [], Slugger()
    fence = None
    prev_para = False
    for i in range(start, len(lines)):
        line = lines[i]
        if fence:
            m = FENCE_RE.match(line)
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence) and not m.group(2).strip():
                fence = None
            prev_para = False
            continue
        m = FENCE_RE.match(line)
        if m and not (m.group(1)[0] == "`" and "`" in m.group(2)):
            fence = m.group(1)
            prev_para = False
            continue
        m = ATX_RE.match(line)
        if m:
            raw = re.sub(r"[ \t]+#+[ \t]*$", "", m.group(2) or "")
            raw = "" if re.fullmatch(r"#+", raw) else raw
            text = strip_inline(raw)
            out.append(Heading(i, len(m.group(1)), raw, text, sl.slug(text)))
            prev_para = False
            continue
        m = SETEXT_RE.match(line)
        if m and prev_para:
            raw = lines[i - 1].strip()
            text = strip_inline(raw)
            out.append(Heading(i - 1, 1 if m.group(1)[0] == "=" else 2, raw, text, sl.slug(text)))
            prev_para = False
            continue
        s = line.strip()
        prev_para = bool(s) and not (
            line.startswith("    ") or line.startswith("\t") or s[0] in "|><" or LIST_RE.match(line)
            or HR_RE.match(line))
    return out


def html_ids(lines):
    return set(re.findall(r"<a\s+(?:name|id)\s*=\s*[\"']([^\"']+)[\"']", "\n".join(lines))) | \
        set(re.findall(r"\sid\s*=\s*[\"']([^\"']+)[\"']", "\n".join(lines)))


def section_span(heads, idx, nlines):
    """Line range [start, end) of heading idx including its subsections."""
    h = heads[idx]
    end = nlines
    for h2 in heads[idx + 1:]:
        if h2.level <= h.level:
            end = h2.line
            break
    return h.line, end


def first_paragraph(lines, start):
    """First prose paragraph (for summary fallbacks), as plain text."""
    buf, fence = [], False
    for line in lines[start:]:
        s = line.strip()
        if FENCE_RE.match(line):
            fence = not fence
            if buf:
                break
            continue
        if fence:
            continue
        if not s:
            if buf:
                break
            continue
        if s.startswith("#") or HR_RE.match(line) or s.startswith("|") or s.startswith("<"):
            if buf:
                break
            continue
        buf.append(s.lstrip(">*- ").strip())
    t = strip_inline(" ".join(buf))
    m = re.match(r"(.+?[.!?])(\s|$)", t)
    t = m.group(1) if m and len(m.group(1)) > 30 else t
    return t[:200] + ("..." if len(t) > 200 else "")


# ----------------------------------------------------------------------------------------------
# index: files -> records

class Rec:
    __slots__ = ("path", "line", "end", "anchor", "hpath", "title", "heading", "names", "ident", "body")

    def __init__(self, path, line, end, anchor, hpath, title, heading, names, ident, body):
        self.path, self.line, self.end, self.anchor, self.hpath = path, line, end, anchor, hpath
        self.title, self.heading, self.names, self.ident, self.body = title, heading, names, ident, body


def infer_scope(rel):
    if rel.startswith("docs/kcd2/") or rel.startswith(WIKI_DIR) or rel.startswith("references/"):
        return "kcd2"
    parts = rel.split("/")
    if len(parts) > 2 and parts[0] == "docs" and parts[1] in PUBLIC_GUIDE_DIRS:
        return "kcd2"
    return "mercenaries"


def split_long(start, end, lines, maxlen):
    """Split [start, end) into pieces <= maxlen, preferring blank lines; returns [(s, e)]."""
    if end - start <= maxlen:
        return [(start, end)]
    out, s = [], start
    while end - s > maxlen:
        cut = s + maxlen
        for k in range(s + maxlen, s + maxlen // 2, -1):
            if not lines[k - 1].strip():
                cut = k
                break
        out.append((s, cut))
        s = cut
    out.append((s, end))
    return out


def md_file_meta(rel, lines):
    fm, body_start, _ = parse_frontmatter(lines)
    heads = md_headings(lines, body_start)
    h1 = next((h for h in heads if h.level == 1), None)
    fm = fm or {}
    tags = fm.get("tags") or []
    if isinstance(tags, str):
        tags = [t for t in re.split(r"[,\s]+", tags) if t]
    meta = {
        "title": str(fm.get("title") or (h1.text if h1 else posixpath.basename(rel))),
        "summary": str(fm.get("summary") or first_paragraph(lines, (h1.line + 1) if h1 else body_start)),
        "tags": [str(t) for t in tags],
        "kind": str(fm.get("kind") or ""),
        "status": str(fm.get("status") or ""),
        "scope": str(fm.get("scope") or infer_scope(rel)),
        "verified": str(fm.get("verified") or ""),
        "has_fm": 1 if fm else 0,
    }
    return meta, heads, body_start


def index_md(rel, lines, meta, heads, body_start, api_table=None):
    recs = []
    title = meta["title"]
    bounds = [h for h in heads if h.level <= 3]
    starts = [(body_start, None)] + [(h.line, h) for h in bounds]
    if len(starts) > 1 and starts[1][0] <= body_start:
        starts = starts[1:]
    stack = []
    first = True
    for k, (s, h) in enumerate(starts):
        e = starts[k + 1][0] if k + 1 < len(starts) else len(lines)
        if h is not None:
            while stack and stack[-1].level >= h.level:
                stack.pop()
            if h.level > 1:
                stack.append(h)
        section = " > ".join(x.text for x in stack)
        text_lines = lines[s:e]
        if not any(x.strip() for x in text_lines) and not first:
            continue
        hpath = title + (" > " + section if section else "")
        anchor = h.slug if h is not None else ""
        names, weak = set(), set()
        idents_of(section, names, all_tokens=True, parts_out=weak)
        if api_table and h is not None and h.level > 1:
            m = IDENT_RE.search(h.text)
            if m:
                full = m.group(0) if ("." in m.group(0) or ":" in m.group(0)) else f"{api_table}.{m.group(0)}"
                idents_of(full, names, all_tokens=True, parts_out=weak)
                section = section + " " + full
        for ps, pe in split_long(s, e, lines, DOC_CHUNK_MAX):
            body = "\n".join(lines[ps:pe])
            extra = ""
            if first:
                extra = "\n" + meta["summary"] + "\n" + " ".join(meta["tags"])
                idents_of(title, names, all_tokens=True, parts_out=weak)
            recs.append(Rec(rel, ps + 1, pe, anchor, hpath, title if first else "", section,
                            ident_str(names), ident_str(idents_of(body) | weak), body + extra))
            first = False
    return recs


def index_txt(rel, lines, meta):
    recs, title = [], meta["title"]
    s = 0
    while s < len(lines):
        e = min(len(lines), s + 60)
        if e < len(lines):
            for k in range(e, s + 20, -1):
                if not lines[k - 1].strip():
                    e = k
                    break
        body = "\n".join(lines[s:e])
        if body.strip():
            recs.append(Rec(rel, s + 1, e, "", title, title if not recs else "", "", "",
                            ident_str(idents_of(body)), body))
        s = e
    return recs


NUM_ATTR_RE = re.compile(r"\s[\w:.-]+=\"[-+\d.eE, ]*\"")
GUID_RE = re.compile(r"\{?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}?")
NOISE_ATTR_RE = re.compile(r"\s(?:Text|Guid|xmlns(?::\w+)?|InstanceType)=\"[^\"]*\"")


def reduce_xml(line):
    """What of an XML line is worth indexing: no numbers-only/GUID attributes, no dialogue
    text (Czech in vanilla quests), no indentation. Keeps one output line per input line."""
    return GUID_RE.sub("", NOISE_ATTR_RE.sub("", NUM_ATTR_RE.sub("", line))).strip()
LUA_FN_RE = re.compile(r"^(?:local\s+)?function\s+([\w.:\[\]\"']+)|^([\w.:\[\]\"']+)\s*=\s*function\b")
XML_NAME_RE = re.compile(r"<([\w:.-]+)[^>]*?\sName=\"([^\"]+)\"")


def index_code(rel, text, source):
    lines = text.split("\n")
    truncated = len(lines) > CODE_MAX_LINES
    lines = lines[:CODE_MAX_LINES]
    is_lua = rel.lower().endswith(".lua")
    base = posixpath.basename(rel)
    recs = []
    # chunk boundaries
    cuts = [0]
    if is_lua:
        for i, line in enumerate(lines):
            if i - cuts[-1] >= 8 and LUA_FN_RE.match(line):
                cuts.append(i)
            elif i - cuts[-1] >= 150:
                cuts.append(i)
    else:
        i = CODE_CHUNK
        while i < len(lines):
            best = i
            for k in range(i, min(len(lines), i + 30)):
                ln = lines[k]
                ind = len(ln) - len(ln.lstrip())
                if ln.lstrip().startswith("<") and not ln.lstrip().startswith("</") and ind <= 8:
                    best = k
                    break
            cuts.append(best)
            i = best + CODE_CHUNK
    cuts.append(len(lines))
    title_words = " ".join(p for p in re.split(r"[/_.\-]", rel) if p)
    for k in range(len(cuts) - 1):
        s, e = cuts[k], cuts[k + 1]
        if s >= e:
            continue
        chunk = lines[s:e]
        if not is_lua:
            chunk = [reduce_xml(ln) for ln in chunk]
        body = "\n".join(chunk)
        if not body.strip():
            continue
        head = ""
        if is_lua:
            for ln in lines[s:e]:
                m = LUA_FN_RE.match(ln)
                if m:
                    head = m.group(1) or m.group(2)
                    break
        else:
            m = XML_NAME_RE.search(body)
            if m:
                head = f"{m.group(1)} {m.group(2)}"
        names, weak = set(), set()
        if head:
            idents_of(head, names, all_tokens=True, parts_out=weak)
        if k == 0:
            idents_of(base.rsplit(".", 1)[0], names, all_tokens=True, parts_out=weak)
        recs.append(Rec(rel, s + 1, e, f"L{s + 1}", base + (" > " + head if head else ""),
                        title_words if k == 0 else "", head, ident_str(names),
                        ident_str((idents_of(body) if is_lua or source != "vanilla" else set()) | weak), body))
    if truncated and recs:
        recs[-1].body += f"\n[kb: file truncated at {CODE_MAX_LINES} lines]"
    return recs


def read_tsv(path):
    """-> (header list, [(lineno, cells)])"""
    lines = read_lines(path)
    rows = []
    header = None
    for i, line in enumerate(lines):
        if not line.strip() or line.startswith("#"):
            continue
        cells = line.split("\t")
        if header is None:
            header = [c.strip() for c in cells]
            continue
        rows.append((i + 1, [c.strip() for c in cells]))
    return header or [], rows


API_COLS = {
    "table": ["table", "namespace", "class", "tbl", "ns", "lua_table", "object", "owner"],
    "function": ["function", "name", "fn", "method", "func", "member"],
    "full": ["qualified", "full", "fullname", "full_name", "qualified_name", "lua_name", "id", "symbol"],
    "signature": ["signature", "sig", "prototype", "syntax", "params", "args", "parameters"],
    "summary": ["summary", "description", "desc", "brief", "doc", "help", "notes"],
    "status": ["status", "flags", "state", "availability"],
    "page": ["page", "link", "href", "url", "file", "anchor", "doc_page"],
}


class ApiIndex:
    """docs/kcd2/api/index.tsv, header-driven (see API_COLS for accepted column names)."""

    def __init__(self, root):
        self.path = os.path.join(root, *API_DIR.split("/"), "index.tsv")
        self.rows = []
        if not os.path.isfile(self.path):
            return
        header, rows = read_tsv(self.path)
        low = [h.lower() for h in header]
        col = {}
        for key, names in API_COLS.items():
            for n in names:
                if n in low and low.index(n) not in col.values():
                    col[key] = low.index(n)
                    break
        if "function" not in col and "full" not in col:       # headerless: name, signature, summary
            rows = [(1, header)] + rows
            header = ["function", "signature", "summary"]
            low = header
            col = {"function": 0, "signature": 1, "summary": 2}
        used = set(col.values())
        for ln, cells in rows:
            def get(k):
                i = col.get(k)
                return cells[i] if i is not None and i < len(cells) else ""
            tbl, fn, full = get("table"), get("function"), get("full")
            if full and not fn:
                fn = re.split(r"[.:]", full)[-1]
                tbl = tbl or (full[: -len(fn) - 1] if len(full) > len(fn) else "")
            if fn and ("." in fn or ":" in fn) and not tbl:
                tbl, fn = re.split(r"[.:](?=[^.:]*$)", fn)
            full = f"{tbl}.{fn}" if tbl else fn
            flags = []
            if get("status"):
                flags.append(get("status"))
            extra = {}
            for i, h in enumerate(header):
                if i in used or i >= len(cells):
                    continue
                v = cells[i]
                extra[h] = v
                vl = v.lower()
                # y/n and count columns become flags ("in_docs in_binary vanilla_uses=12");
                # free-text columns (cpp_class, examples) stay in `extra`
                if vl in ("1", "yes", "true", "y", "x"):
                    flags.append(h)
                elif re.fullmatch(r"[1-9]\d*", v):
                    flags.append(f"{h}={v}")
            page = get("page")
            link = self._link(page, tbl, fn)
            if link:
                p, _, anc = link.partition("#")
                p = self._fix_case(root, p)
                link = p + ("#" + anc if anc else "")
            self.rows.append({
                "table": tbl, "function": fn, "full": full, "signature": get("signature"),
                "summary": get("summary"), "flags": " ".join(flags), "status": get("status"),
                "link": link, "page_raw": page, "line": ln, "extra": extra,
            })

    _dir_cache = {}

    @classmethod
    def _fix_case(cls, root, rel):
        """index.tsv may say soul.md while the page is Soul.md: resolve to the real file name."""
        d, base = posixpath.split(rel)
        if d not in cls._dir_cache:
            try:
                cls._dir_cache[d] = {x.lower(): x for x in os.listdir(os.path.join(root, *d.split("/")))}
            except OSError:
                cls._dir_cache[d] = {}
        return posixpath.join(d, cls._dir_cache[d].get(base.lower(), base))

    @staticmethod
    def _link(page, tbl, fn):
        anchor = slug_base(fn)
        if page:
            p, _, a = page.partition("#")
            if p:
                p = p.replace("\\", "/")
                if not p.startswith("docs/"):
                    p = posixpath.normpath(posixpath.join(API_DIR, p))
            else:
                p = f"{API_DIR}/{tbl}.md" if tbl else ""
            return p + "#" + (a or anchor) if p else ""
        return f"{API_DIR}/{tbl}.md#{anchor}" if tbl else ""


def index_api_tsv(rel, root):
    recs = []
    for r in ApiIndex(root).rows:
        weak = set()
        names = idents_of(r["full"], all_tokens=True, parts_out=weak)
        path, _, anchor = r["link"].partition("#")
        body = "\n".join(x for x in (r["signature"], r["summary"], r["flags"]) if x)
        recs.append(Rec(path or rel, 0 if path else r["line"], r["line"], anchor, r["full"],
                        r["full"], r["signature"], ident_str(names),
                        ident_str(idents_of(r["signature"] + " " + r["summary"]) | weak), body))
    return recs


def index_data_tsv(rel, path):
    header, rows = read_tsv(path)
    stem = posixpath.basename(rel).rsplit(".", 1)[0]
    recs = []
    low = [h.lower() for h in header]
    ni = next((low.index(n) for n in ("name", "cvar", "command", "bind", "key", "id") if n in low), 0)
    for ln, cells in rows:
        if not cells or ni >= len(cells) or not cells[ni]:
            continue
        name = cells[ni]
        weak = set()
        body = "  ".join(f"{header[i] if i < len(header) else i}: {c}" for i, c in enumerate(cells) if c and i != ni)
        recs.append(Rec(rel, ln, ln, "", f"{stem} > {name}", name, stem,
                        ident_str(idents_of(name, all_tokens=True, parts_out=weak)),
                        ident_str(idents_of(body) | weak), body))
    return recs


# ----------------------------------------------------------------------------------------------
# sources

def walk(root, rel_dir, exts, skip_dirs=()):
    base = os.path.join(root, *rel_dir.split("/"))
    if not os.path.isdir(base):
        return
    for dp, dns, fns in os.walk(base):
        rdp = os.path.relpath(dp, root).replace("\\", "/")
        dns[:] = sorted(d for d in dns if not d.startswith(".") and f"{rdp}/{d}" not in skip_dirs)
        for fn in sorted(fns):
            if fn.lower().endswith(exts):
                yield f"{rdp}/{fn}", os.path.join(dp, fn)


def iter_source(root, src):
    if src == "docs":
        yield from walk(root, "docs", (".md", ".txt"), skip_dirs=(API_DIR,))
    elif src == "api":
        yield from walk(root, API_DIR, (".md", ".tsv"))
    elif src == "data":
        yield from walk(root, DATA_DIR, (".tsv",))
    elif src == "wiki":
        yield from walk(root, WIKI_DIR, (".md",))
    elif src == "vanilla":
        for d, exts in VANILLA_DIRS:
            yield from walk(root, d, exts)
    elif src == "mod":
        for d, exts in MOD_DIRS:
            yield from walk(root, d, exts, skip_dirs=MOD_SKIP)


def default_kind_status(src):
    return {"api": ("reference", "current"), "data": ("reference", "current"),
            "wiki": ("guide", "current"), "vanilla": ("code", "current"),
            "mod": ("code", "current")}.get(src, ("", ""))


def index_file(root, src, rel, ab):
    """-> (file meta dict, [Rec])"""
    low = rel.lower()
    kind, status = default_kind_status(src)
    meta = {"title": posixpath.basename(rel), "summary": "", "tags": [], "kind": kind, "status": status,
            "scope": infer_scope(rel) if src in ("docs", "wiki", "api", "data") else
            ("mercenaries" if src == "mod" else "kcd2"), "verified": "", "has_fm": 0, "lines": 0}
    if low.endswith(".md"):
        lines = read_lines(ab)
        m, heads, body_start = md_file_meta(rel, lines)
        for k, v in m.items():
            if v or k not in meta:
                meta[k] = v
        if src == "wiki":
            d = posixpath.basename(posixpath.dirname(rel))
            if meta["title"] == "README.md" or not heads:
                meta["title"] = d
        meta["lines"] = len(lines)
        api_table = posixpath.basename(rel)[:-3] if src == "api" and not low.endswith("readme.md") else None
        return meta, index_md(rel, lines, meta, heads, body_start, api_table)
    if low.endswith(".txt"):
        lines = read_lines(ab)
        meta["lines"] = len(lines)
        meta["summary"] = first_paragraph(lines, 0)
        return meta, index_txt(rel, lines, meta)
    if low.endswith(".tsv"):
        meta["lines"] = sum(1 for _ in open(ab, "rb"))
        if src == "api":
            meta["title"] = "API index"
            return meta, index_api_tsv(rel, root)
        meta["title"] = posixpath.basename(rel)
        return meta, index_data_tsv(rel, ab)
    text = read_text(ab)
    meta["lines"] = text.count("\n") + 1
    return meta, index_code(rel, text, src)


# ----------------------------------------------------------------------------------------------
# database

class KB:
    def __init__(self, root, db_path=None, quiet=False):
        self.root = os.path.abspath(root)
        self.db_path = db_path or os.path.join(self.root, "tools", "out", "kb.sqlite")
        self.quiet = quiet
        self.db = None

    def log(self, *a):
        if not self.quiet:
            print(*a, file=sys.stderr)

    def open(self, create=True):
        if self.db is not None:
            return self.db
        exists = os.path.isfile(self.db_path)
        if not exists and not create:
            return None
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        db = sqlite3.connect(self.db_path, timeout=30)
        db.execute("PRAGMA journal_mode=WAL")
        db.execute("PRAGMA synchronous=NORMAL")
        ok = False
        if exists:
            try:
                v = db.execute("SELECT value FROM meta WHERE key='schema'").fetchone()
                ok = v is not None and int(v[0]) == SCHEMA
            except sqlite3.DatabaseError:
                ok = False
        if not ok:
            db.close()
            for suf in ("", "-wal", "-shm"):
                if os.path.exists(self.db_path + suf):
                    os.remove(self.db_path + suf)
            db = sqlite3.connect(self.db_path, timeout=30)
            db.execute("PRAGMA journal_mode=WAL")
            db.executescript(f"""
                CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
                CREATE TABLE files(path TEXT PRIMARY KEY, source TEXT, mtime REAL, size INTEGER,
                    title TEXT, summary TEXT, tags TEXT, kind TEXT, status TEXT, scope TEXT,
                    verified TEXT, lines INTEGER, has_fm INTEGER);
                CREATE TABLE chunks(id INTEGER PRIMARY KEY, src_file TEXT, path TEXT, source TEXT,
                    line INTEGER, end_line INTEGER, anchor TEXT, hpath TEXT, kind TEXT, status TEXT,
                    scope TEXT, tags TEXT);
                CREATE INDEX chunks_src ON chunks(src_file);
                CREATE VIRTUAL TABLE fts USING fts5(title, heading, names, ident, body,
                    tokenize = 'porter unicode61 remove_diacritics 2');
                CREATE VIRTUAL TABLE ftsc USING fts5(title, heading, names, ident, body,
                    tokenize = 'porter unicode61 remove_diacritics 2'{CONTENTLESS});
                INSERT INTO meta VALUES('schema', '{SCHEMA}');
                INSERT INTO meta VALUES('sources', '{",".join(DEFAULT_SOURCES)}');
            """)
            db.commit()
        self.db = db
        return db

    def meta(self, key, default=None):
        r = self.open().execute("SELECT value FROM meta WHERE key=?", (key,)).fetchone()
        return r[0] if r else default

    def set_meta(self, key, value):
        self.open().execute("INSERT OR REPLACE INTO meta VALUES(?,?)", (key, str(value)))

    def enabled_sources(self):
        return [s for s in (self.meta("sources") or ",".join(DEFAULT_SOURCES)).split(",") if s]

    def _drop_file(self, rel):
        db = self.db
        db.execute("DELETE FROM fts WHERE rowid IN (SELECT id FROM chunks WHERE src_file=?)", (rel,))
        db.execute("DELETE FROM ftsc WHERE rowid IN (SELECT id FROM chunks WHERE src_file=?)", (rel,))
        db.execute("DELETE FROM chunks WHERE src_file=?", (rel,))
        db.execute("DELETE FROM files WHERE path=?", (rel,))

    def _add(self, src, rel, st, meta, recs):
        db = self.db
        tags = " " + " ".join(meta["tags"]) + " " if meta["tags"] else ""
        db.execute("INSERT OR REPLACE INTO files VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)",
                   (rel, src, st.st_mtime, st.st_size, meta["title"], meta["summary"], tags, meta["kind"],
                    meta["status"], meta["scope"], meta["verified"], meta["lines"], meta["has_fm"]))
        for r in recs:
            cur = db.execute("INSERT INTO chunks(src_file, path, source, line, end_line, anchor, hpath, kind,"
                             " status, scope, tags) VALUES(?,?,?,?,?,?,?,?,?,?,?)",
                             (rel, r.path, src, r.line, r.end, r.anchor, r.hpath, meta["kind"], meta["status"],
                              meta["scope"], tags))
            db.execute(f"INSERT INTO {'ftsc' if src in CODE_SOURCES else 'fts'}(rowid, title, heading, names,"
                       f" ident, body) VALUES(?,?,?,?,?,?)", (cur.lastrowid, r.title, r.heading, r.names, r.ident, r.body))

    def scan(self, src):
        """-> (list of (rel, abs, stat) on disk, dict rel -> (mtime, size) in db)"""
        disk = []
        for rel, ab in iter_source(self.root, src):
            try:
                disk.append((rel, ab, os.stat(ab)))
            except OSError:
                pass
        have = {p: (m, s) for p, m, s in self.open().execute(
            "SELECT path, mtime, size FROM files WHERE source=?", (src,))}
        return disk, have

    def build(self, sources=None, full=False, verbose=True):
        db = self.open()
        sources = sources or self.enabled_sources()
        t_all = time.time()
        report = []
        for src in ALL_SOURCES:
            if src not in sources:
                n = db.execute("SELECT count(*) FROM files WHERE source=?", (src,)).fetchone()[0]
                if n and src not in self.enabled_sources():
                    for (p,) in db.execute("SELECT path FROM files WHERE source=?", (src,)).fetchall():
                        self._drop_file(p)
                    db.commit()
                    report.append(f"{src:<8} removed ({n} files)")
                continue
            t0 = time.time()
            disk, have = self.scan(src)
            seen, changed, errors = set(), 0, 0
            for rel, ab, st in disk:
                seen.add(rel)
                if not full and have.get(rel) == (st.st_mtime, st.st_size):
                    continue
                self._drop_file(rel)
                try:
                    meta, recs = index_file(self.root, src, rel, ab)
                except Exception as e:     # one bad file must not kill the build
                    errors += 1
                    self.log(f"kb: {rel}: {type(e).__name__}: {e}")
                    continue
                self._add(src, rel, st, meta, recs)
                changed += 1
                if changed % 500 == 0:
                    db.commit()
            removed = [p for p in have if p not in seen]
            for p in removed:
                self._drop_file(p)
            db.commit()
            nch = db.execute("SELECT count(*) FROM chunks WHERE source=?", (src,)).fetchone()[0]
            if not disk and not have:
                report.append(f"{src:<8} (missing: nothing to index)")
            else:
                report.append(f"{src:<8} {len(disk):>6} files  {changed:>6} indexed  {len(removed):>4} removed  "
                              f"{nch:>7} chunks  {time.time() - t0:6.1f}s" + (f"  {errors} errors" if errors else ""))
        if full or sum(1 for r in report if " indexed" in r) and len(sources) > 3:
            db.execute("INSERT INTO fts(fts) VALUES('optimize')")
            db.execute("INSERT INTO ftsc(ftsc) VALUES('optimize')")
        self.set_meta("built", time.time())
        db.commit()
        db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        if verbose:
            for r in report:
                print(r)
            size = os.path.getsize(self.db_path) / 1e6
            print(f"db {os.path.relpath(self.db_path, self.root)}  {size:.1f} MB  total {time.time() - t_all:.1f}s")

    def ensure(self):
        """Create the index if missing; refresh cheap sources whose files changed."""
        fresh = not os.path.isfile(self.db_path)
        db = self.open()
        if fresh:
            self.log("kb: no index yet, building (docs, api, data, wiki)...")
            self.build(verbose=False)
            return
        stale = []
        for src in self.enabled_sources():
            if src in STATIC_SOURCES:
                continue
            disk, have = self.scan(src)
            if len(disk) != len(have) or any(have.get(rel) != (st.st_mtime, st.st_size) for rel, _, st in disk):
                stale.append(src)
        if stale:
            n0 = db.total_changes
            self.build(stale, verbose=False)
            self.log(f"kb: index refreshed ({', '.join(stale)}; {db.total_changes - n0} rows touched)")


# ----------------------------------------------------------------------------------------------
# search

def split_query(q):
    """-> [(text, quoted, negated)]"""
    out = []
    for m in re.finditer(r'(-?)"([^"]*)"|(\S+)', q):
        if m.group(3) is not None:
            t = m.group(3)
            neg = t.startswith("-") and len(t) > 1
            out.append((t[1:] if neg else t, False, neg))
        else:
            out.append((m.group(2), True, bool(m.group(1))))
    return out


def term_expr(text, quoted):
    prefix = text.endswith("*") and not quoted
    words = [w.lower() for w in WORD_RE.findall(text)]
    if not words:
        return None
    if quoted:
        return '"' + " ".join(words) + '"'
    if len(words) == 1:
        return f'"{words[0]}"' + ("*" if prefix else "")
    alts = ['"' + " ".join(words) + '"', '{names ident} : "' + "".join(words) + '"']
    if len(words[-1]) >= 4:
        alts.append(f'"{words[-1]}"')
    return "(" + " OR ".join(alts) + ")"


def build_match(q, mode="AND"):
    pos, neg = [], []
    for text, quoted, negated in split_query(q):
        e = term_expr(text, quoted)
        if e:
            (neg if negated else pos).append(e)
    if not pos:
        return None
    expr = f" {mode} ".join(pos)
    if neg:
        expr = f"({expr}) NOT (" + " OR ".join(neg) + ")"
    return expr


def snippet_terms(q):
    terms = set()
    for text, _, negated in split_query(q):
        if negated:
            continue
        text = text.rstrip("*")
        words = WORD_RE.findall(text)
        if len(words) > 1:
            terms.add(text.lower())
            terms.add(words[-1].lower())
        terms.update(w.lower() for w in words if len(w) > 1 or len(words) == 1)
        for w in words:          # porter-ish stem for 'morale' ~ 'moral', 'interiors' ~ 'interior'
            if len(w) > 5:
                terms.add(w.lower()[:-2] if w.lower().endswith(("es", "ed")) else w.lower().rstrip("se"))
    return sorted((t for t in terms if t), key=len, reverse=True)


def make_snippet(body, base_line, terms, mark=(">>", "<<"), width=180, nlines=None):
    """-> (file line of best match or None, snippet text)"""
    lines = body.split("\n")
    # match at a word start only ('in' must not light up inside 'fighting'); a trailing stem is fine
    hterms = [t for t in terms if len(t) > 2] or list(terms)
    hl = re.compile(r"(?<![A-Za-z0-9_])(?:" + "|".join(re.escape(t) for t in hterms) + ")", re.I) if hterms else None
    best, best_i = -1, None
    for i, ln in enumerate(lines):
        if FENCE_RE.match(ln) or HR_RE.match(ln):
            continue
        score = len({m.group(0).lower() for m in hl.finditer(ln)}) if hl else 0
        if score > best:
            best, best_i = score, i
    if best <= 0:
        best_i = next((i for i, ln in enumerate(lines) if ln.strip() and not ln.lstrip().startswith("#")), 0)
    text = lines[best_i].strip() if lines else ""
    if len(text) < 70 and best_i + 1 < len(lines):
        nxt = next((ln.strip() for ln in lines[best_i + 1:best_i + 4]
                    if ln.strip() and not FENCE_RE.match(ln) and not HR_RE.match(ln)), "")
        if nxt:
            text = text + " / " + nxt
    m0 = hl.search(text) if hl else None
    first = m0.start() if m0 else 0
    if len(text) > width:
        s = max(0, first - width // 3)
        text = ("..." if s else "") + text[s:s + width] + ("..." if s + width < len(text) else "")
    if hl and best > 0:
        text = hl.sub(lambda m: mark[0] + m.group(0) + mark[1], text)
    if nlines is not None and best_i >= nlines:      # matched the appended summary/tags, not a file line
        best_i = 0
    line = base_line + best_i if base_line else None
    return line, text


def parse_list(v):
    return [x.strip() for x in v.split(",") if x.strip()] if v else []


def code_body(root, path, line, end):
    """Chunk text for a contentless (code) hit, rebuilt from the file."""
    try:
        lines = read_lines(os.path.join(root, *path.split("/")))[max(line - 1, 0):end]
    except OSError:
        return ""
    if not path.lower().endswith(".lua"):
        lines = [reduce_xml(ln) for ln in lines]
    return "\n".join(lines)


def search(kb, q, sources=None, tags=None, kinds=None, scopes=None, statuses=None, n=10, per_file=3,
           mark=(">>", "<<"), raw=False):
    db = kb.open()
    where, args = [], []
    for col, vals in (("c.source", sources), ("c.kind", kinds), ("c.scope", scopes), ("c.status", statuses)):
        if vals:
            where.append(f"{col} IN ({','.join('?' * len(vals))})")
            args += vals
    if tags:
        where.append("(" + " OR ".join("c.tags LIKE ?" for _ in tags) + ")")
        args += [f"% {t} %" for t in tags]
    cond = (" AND " + " AND ".join(where)) if where else ""
    enabled = kb.enabled_sources()
    tables = []
    if not sources or any(x not in CODE_SOURCES for x in sources):
        tables.append("fts")
    if any(x in enabled for x in CODE_SOURCES) and (not sources or any(x in CODE_SOURCES for x in sources)):
        tables.append("ftsc")
    w = ", ".join(str(x) for x in BM25_W)
    sf = "CASE c.source " + " ".join(f"WHEN '{k}' THEN {v}" for k, v in SOURCE_FACTOR.items()) + " ELSE 1.0 END"
    stf = "CASE c.status " + " ".join(f"WHEN '{k}' THEN {v}" for k, v in STATUS_FACTOR.items()) + " ELSE 1.0 END"
    note = ""
    exprs = [q] if raw else [build_match(q, "AND")]
    if not raw and len([t for t in split_query(q) if not t[2]]) > 1:
        exprs.append(build_match(q, "OR"))
    rows, total, by_src = [], 0, {}
    for k, expr in enumerate(exprs):
        if not expr:
            return [], 0, {}, "empty query"
        by_src, rows = {}, []
        try:
            for t in tables:
                for src, cnt in db.execute(
                        f"SELECT c.source, count(*) FROM {t} JOIN chunks c ON c.id = {t}.rowid WHERE {t} MATCH ?{cond}"
                        f" GROUP BY c.source", [expr] + args):
                    by_src[src] = by_src.get(src, 0) + cnt
                rows += db.execute(
                    f"SELECT c.id, c.path, c.line, c.end_line, c.anchor, c.hpath, c.source, c.kind, c.status,"
                    f" c.scope, c.tags, bm25({t}, {w}) * ({sf}) * ({stf}) AS r, {t}.body"
                    f" FROM {t} JOIN chunks c ON c.id = {t}.rowid WHERE {t} MATCH ?{cond} ORDER BY r LIMIT ?",
                    [expr] + args + [max(n * 6, 60)]).fetchall()
        except sqlite3.OperationalError as e:
            return [], 0, {}, f"bad query: {e}"
        total = sum(by_src.values())
        if total:
            if k:
                note = "no hit has every term; showing hits with any of them"
            rows.sort(key=lambda r: r[11])
            break
    terms = snippet_terms(q) if not raw else [w.lower() for w in WORD_RE.findall(q) if w.upper() not in ("AND", "OR", "NOT")]
    hits, seen, per = [], {}, {}
    for (cid, path, line, end, anchor, hpath, src, kind, status, scope, tagstr, r, body) in rows:
        key = (path, anchor) if anchor else (path, line)
        if key in seen:
            h = seen[key]
            if not h["line"] and line:
                h["line"] = make_snippet(body or "", line, terms, mark, nlines=end - line + 1)[0] or line
            continue
        if per_file and per.get(path, 0) >= per_file:
            continue
        if body is None:
            body = code_body(kb.root, path, line, end)
        mline, snip = make_snippet(body, line, terms, mark, nlines=(end - line + 1) if line else None)
        per[path] = per.get(path, 0) + 1
        h = {"path": path, "line": mline or line or 0, "anchor": anchor, "source": src, "kind": kind,
             "status": status, "scope": scope, "tags": tagstr.split(), "heading": hpath,
             "snippet": snip, "score": round(-r, 3), "section_line": line}
        seen[key] = h
        hits.append(h)
        if len(hits) >= n:
            break
    return hits, total, by_src, note


def fmt_hit(h):
    loc = h["path"] + (f":{h['line']}" if h["line"] else "") + (f"#{h['anchor']}" if h["anchor"] and not
                                                               h["anchor"].startswith("L") else "")
    tag = "/".join(x for x in (h["source"], h["kind"], h["status"]) if x)
    return f"{loc}  [{tag}]  {h['heading']}\n    {h['snippet']}"


# ----------------------------------------------------------------------------------------------
# path resolution / show

def resolve_path(kb, p):
    p = p.replace("\\", "/").strip()
    if os.path.isabs(p):
        try:
            p = os.path.relpath(p, kb.root).replace("\\", "/")
        except ValueError:
            pass
    p = p[2:] if p.startswith("./") else p
    cands = [p, "docs/" + p, "docs/kcd2/" + p, f"{API_DIR}/{p}", f"{DATA_DIR}/{p}"]
    cands += [c + ".md" for c in cands if not posixpath.splitext(c)[1]]
    for c in cands:
        if os.path.isfile(os.path.join(kb.root, c)):
            return c, []
    # suffix match over docs + wiki
    hits = []
    for src in ("docs", "api", "data", "wiki"):
        for rel, _ in iter_source(kb.root, src):
            if rel.endswith("/" + p) or rel.endswith("/" + p + ".md"):
                hits.append(rel)
    if len(hits) == 1:
        return hits[0], []
    return None, hits


def cmd_show(kb, a):
    target = a.target
    anchor, line = "", None
    if "#" in target:
        target, _, anchor = target.partition("#")
    m = re.match(r"^(.*?):(\d+)(?:-(\d+))?$", target)
    if m and not os.path.isfile(os.path.join(kb.root, target)):
        target, line = m.group(1), int(m.group(2))
        if m.group(3):
            anchor = f"L{line}-L{m.group(3)}"
    rel, amb = resolve_path(kb, target)
    if not rel:
        sys.exit(f"not found: {target}" + (f"  (ambiguous: {', '.join(amb[:8])})" if amb else ""))
    lines = read_lines(os.path.join(kb.root, rel))
    cap = a.max
    if not rel.lower().endswith(".md"):
        m = re.match(r"^L?(\d+)(?:-L?(\d+))?$", anchor or "")
        s = int(m.group(1)) if m else (line or 1)
        e = int(m.group(2)) if m and m.group(2) else (s + cap - 1 if (m or line) else len(lines))
        if a.all:
            s, e = 1, len(lines)
        e = min(e, len(lines), s + cap - 1)
        print(f"== {rel}:{s}-{e}  ({len(lines)} lines)")
        if rel.lower().endswith(".tsv") and s > 2:
            print(f"{'hdr':>5}  {lines[0]}")
        for i in range(s - 1, e):
            print(f"{i + 1:>5}  {lines[i]}")
        return
    fm, body_start, _ = parse_frontmatter(lines)
    heads = md_headings(lines, body_start)
    if a.all:
        print("\n".join(lines[:cap]))
        if len(lines) > cap:
            print(f"... ({len(lines) - cap} more lines; use -n)")
        return
    idx = None
    if anchor:
        anchor_l = anchor.lower()
        idx = next((i for i, h in enumerate(heads) if h.slug == anchor_l), None)
        if idx is None:
            sug = difflib.get_close_matches(anchor_l, [h.slug for h in heads], n=5, cutoff=0.5)
            sys.exit(f"no #{anchor} in {rel}" + (f"; did you mean: {', '.join('#' + s for s in sug)}" if sug else "")
                     + f"\n  (kb.py show {rel} lists its sections)")
    elif line:
        for i, h in enumerate(heads):
            if h.line < line and (h.level <= 3):
                idx = i
    if idx is not None:
        s, e = section_span(heads, idx, len(lines))
        path = []
        for h in heads[:idx + 1]:
            while path and path[-1].level >= h.level:
                path.pop()
            path.append(h)
        print(f"== {rel}:{s + 1}-{e}#{heads[idx].slug}  " + " > ".join(h.text for h in path))
        body = lines[s:e]
        while body and not body[-1].strip():
            body.pop()
        print("\n".join(body[:cap]))
        if len(body) > cap:
            print(f"... ({len(body) - cap} more lines; use -n)")
        return
    # outline
    meta, _, _ = md_file_meta(rel, lines)
    print(f"== {rel}  ({len(lines)} lines)  {meta['title']}")
    bits = [f"{k}: {meta[k]}" for k in ("kind", "status", "scope", "verified") if meta[k]]
    if meta["tags"]:
        bits.append("tags: " + ", ".join(meta["tags"]))
    if fm is None:
        bits.append("(no frontmatter)")
    print("   " + "  ".join(bits))
    if meta["summary"] and fm:
        print("   " + meta["summary"])
    first = next((h.line for h in heads if h.level >= 2), len(lines))
    pre = [ln for ln in lines[body_start:first] if not ATX_RE.match(ln) or ATX_RE.match(ln).group(1) != "#"]
    pre = [ln for ln in pre if ln.strip() and not HR_RE.match(ln)]
    if pre:
        print()
        print("\n".join(pre[:25]) + ("\n..." if len(pre) > 25 else ""))
    if heads:
        print("\nSections:")
        for h in heads:
            if h.level == 1:
                continue
            print(f"{h.line + 1:>6}  {'  ' * (h.level - 2)}{h.text}  #{h.slug}")


# ----------------------------------------------------------------------------------------------
# api / cvar

def load_annotations(root):
    """tools/api_annotations.tsv -> {(table, function) lowercased: [row dict, ...]} (hand-verified API notes)."""
    out = {}
    path = os.path.join(root, "tools", "api_annotations.tsv")
    if os.path.exists(path):
        header, rows = read_tsv(path)
        for _, cells in rows:
            r = dict(zip(header or [], cells))
            key = (r.get("table", "").lower(), r.get("function", "").lower())
            out.setdefault(key, []).append(r)
    return out


def print_annotations(notes, indent="  "):
    for n in notes:
        print(f"{indent}VERIFIED {(n.get('kind') or 'note').upper()}: {n.get('text', '')}")
        if n.get("source"):
            print(f"{indent}  source: {n['source']}")


def cmd_api(kb, a):
    notes = load_annotations(kb.root)
    idx = ApiIndex(kb.root)
    if not idx.rows:
        sys.exit(f"no API index at {os.path.relpath(idx.path, kb.root)} (generated into docs/kcd2/api/)")
    q = a.name.strip().replace(":", ".")
    ql = q.lower()
    rows = idx.rows
    hits = [r for r in rows if r["full"].lower() == ql]
    how = "exact"
    if not hits:
        hits = [r for r in rows if r["function"].lower() == ql]
    if not hits:
        hits = [r for r in rows if r["table"].lower() == ql]
        how = "table"
    if not hits:
        how = "match"
        try:
            pat = re.compile(q, re.I)
        except re.error:
            pat = re.compile(re.escape(q), re.I)
        hits = [r for r in rows if r["full"].lower().startswith(ql) or r["function"].lower().startswith(ql)]
        hits += [r for r in rows if r not in hits and pat.search(r["full"])]
    if not hits:
        known = [(k, v) for k, v in notes.items() if f"{k[0]}.{k[1]}" == ql or k[1] == ql]
        for (t, f), v in known:     # a correction for a function that does not exist in retail
            print(f"{v[0].get('table', t)}.{v[0].get('function', f)}  -- not in the API index")
            print_annotations(v)
        if known:
            return
        names = sorted({r["full"] for r in rows} | {r["function"] for r in rows})
        sug = difflib.get_close_matches(q, names, n=8, cutoff=0.6)
        sug += [x for x in names if ql in x.lower() and x not in sug][:8]
        sug += [x for x in names if len(ql) > 4 and ql[:5] in x.lower() and x not in sug][:4]
        print(f"no API function matches '{a.name}'" + (f"; did you mean: {', '.join(sug[:10])}" if sug else ""))
        print("  (full-text: kb.py search " + a.name + " --source api)")
        sys.exit(1)
    if len(hits) == 1 or (how == "exact" and len(hits) <= 3):
        for r in hits:
            print(r["full"])
            if r["signature"]:
                print(f"  signature: {r['signature']}")
            if r["summary"]:
                print(f"  {r['summary']}")
            if r["flags"]:
                print(f"  flags: {r['flags']}")
            for k, v in r["extra"].items():
                if v and k not in {f.split("=")[0] for f in r["flags"].split()} and not re.fullmatch(r"[0-9yYnN]|no|yes", v):
                    print(f"  {k}: {v}")
            print_annotations(notes.get((r["table"].lower(), r["function"].lower()), []))
            if r["link"]:
                print(f"  page:  {r['link']}    (kb.py show {r['link']})")
            if a.verbose and r["link"]:
                print()
                a2 = argparse.Namespace(target=r["link"], max=200, all=False)
                try:
                    cmd_show(kb, a2)
                except SystemExit as e:
                    print(e)
        return
    for r in hits[:a.max]:
        sig = r["signature"] if r["signature"] else ""
        s = r["summary"][:90] + ("..." if len(r["summary"]) > 90 else "")
        print(f"{r['full']:<44} {sig[:60]:<40}  [{r['flags']}]  {s}")
    print(f"{min(len(hits), a.max)} of {len(hits)} shown" + ("" if how != "table" else f"  (table {q})"))


def cmd_cvar(kb, a):
    ddir = os.path.join(kb.root, *DATA_DIR.split("/"))
    files = ([os.path.join(ddir, f) for f in sorted(os.listdir(ddir)) if f.endswith(".tsv")]
             if a.all_data and os.path.isdir(ddir) else [os.path.join(ddir, a.file)])
    files = [f for f in files if os.path.isfile(f)]
    if not files:
        avail = sorted(os.listdir(ddir)) if os.path.isdir(ddir) else []
        sys.exit(f"no {DATA_DIR}/{a.file}" + (f"  (have: {', '.join(avail)})" if avail else ""))
    try:
        pat = re.compile(a.pattern, re.I)
    except re.error:
        pat = re.compile(re.escape(a.pattern), re.I)
    out, total, notes = [], 0, []
    for f in files:
        header, rows = read_tsv(f)
        low = [h.lower() for h in header]
        ni = next((low.index(n) for n in ("name", "cvar", "command", "bind", "key", "id") if n in low), 0)
        hits = [(ln, c) for ln, c in rows if ni < len(c) and pat.search(c[ni])]
        wide = False
        if not hits:
            hits = [(ln, c) for ln, c in rows if pat.search("\t".join(c))]
            wide = bool(hits)
        total += len(hits)
        rel = os.path.relpath(f, kb.root).replace("\\", "/")
        first = ("help", "description", "desc", "default", "kind", "type")
        order = sorted(range(len(header)), key=lambda i: (low[i] not in first, first.index(low[i]) if low[i] in first else 0))
        if wide:
            notes.append(f"(no name matches in {rel}; matched other columns)")
        for ln, c in hits:
            rest = [f"{header[i]}={c[i]}" for i in order if i < len(c) and c[i] and i != ni]
            line = "  ".join(rest)
            if not a.verbose and len(line) > 150:
                line = line[:147] + "..."
            out.append(f"{c[ni]:<36} {line}" + (f"   ({rel}:{ln})" if a.verbose or len(files) > 1 else ""))
    for x in notes + out[:a.max]:
        print(x)
    print(f"{min(len(out), a.max)} of {total} shown")


# ----------------------------------------------------------------------------------------------
# toc / stats

def cmd_toc(kb, a):
    kb.ensure()
    where, args = ["source IN ('docs','api')"], []
    if not a.api:
        where.append(f"(source='docs' OR path='{API_DIR}/README.md')")
    for col, v in (("scope", a.scope), ("kind", a.kind), ("status", a.status)):
        if v:
            vals = parse_list(v)
            where.append(f"{col} IN ({','.join('?' * len(vals))})")
            args += vals
    if a.tag:
        tl = parse_list(a.tag)
        where.append("(" + " OR ".join("tags LIKE ?" for _ in tl) + ")")
        args += [f"% {t} %" for t in tl]
    rows = kb.open().execute(
        f"SELECT path, title, summary, tags, kind, status, scope, has_fm, lines FROM files WHERE {' AND '.join(where)}"
        f" ORDER BY path", args).fetchall()
    groups = {}
    for r in rows:
        path = r[0]
        if a.by == "dir":
            g = posixpath.dirname(path)
        else:
            g = f"{r[6] or '?'} / {r[4] or 'no kind (no frontmatter)'}"
        groups.setdefault(g, []).append(r)
    order = sorted(groups, key=lambda g: (g.startswith("?"), "no kind" in g,
                                          -1 if "index" in g else 0, g))
    for g in order:
        print(f"## {g}  ({len(groups[g])})")
        for path, title, summary, tags, kind, status, scope, has_fm, nl in groups[g]:
            st = f"[{status}] " if status and status != "current" else ""
            tg = ("  #" + " #".join(tags.split())) if tags.strip() else ""
            s = summary if len(summary) <= a.width else summary[:a.width - 3] + "..."
            print(f"{path}  {st}{title} -- {s}{tg}")
        print()
    print(f"{len(rows)} docs")


def cmd_stats(kb, a):
    kb.ensure()
    db = kb.open()
    built = float(kb.meta("built", 0) or 0)
    print(f"index {os.path.relpath(kb.db_path, kb.root)}  {os.path.getsize(kb.db_path) / 1e6:.1f} MB"
          f"  built {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(built)) if built else '?'}"
          f"  sources: {','.join(kb.enabled_sources())}")
    for src, nf, nl in db.execute("SELECT source, count(*), sum(lines) FROM files GROUP BY source"):
        nc = db.execute("SELECT count(*) FROM chunks WHERE source=?", (src,)).fetchone()[0]
        print(f"  {src:<8} {nf:>6} files {nl or 0:>9} lines {nc:>8} chunks")
    nfm = db.execute("SELECT sum(has_fm), count(*) FROM files WHERE source='docs' AND path LIKE '%.md'").fetchone()
    print(f"  docs with frontmatter: {nfm[0] or 0}/{nfm[1]}")


# ----------------------------------------------------------------------------------------------
# check

class Links:
    LINK_RE = re.compile(r"(!?)\[((?:[^\[\]]|\[[^\]]*\])*)\]\(\s*(<[^>]*>|[^()\s]*(?:\([^()]*\)[^()\s]*)*)(?:\s+[\"'(][^)]*[\"')])?\s*\)")
    REF_RE = re.compile(r"^ {0,3}\[([^\]]+)\]:\s*(<[^>]*>|\S+)")
    HREF_RE = re.compile(r"<(?:a|img)\s[^>]*?(?:href|src)\s*=\s*[\"']([^\"']+)[\"']", re.I)

    @classmethod
    def extract(cls, lines, start=0):
        """-> [(lineno 1-based, target)] outside code fences / code spans."""
        out, fence = [], None
        for i in range(start, len(lines)):
            line = lines[i]
            m = FENCE_RE.match(line)
            if fence:
                if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence) and not m.group(2).strip():
                    fence = None
                continue
            if m and not (m.group(1)[0] == "`" and "`" in m.group(2)):
                fence = m.group(1)
                continue
            if line.startswith("    ") and not line.strip().startswith(("*", "-", "+", "[")) and \
                    not re.match(r"\s*\d+[.)]", line) and i > 0 and not lines[i - 1].strip():
                continue       # indented code block (heuristic)
            s = re.sub(r"(`+).+?\1", "", line)
            for m in cls.LINK_RE.finditer(s):
                t = m.group(3).strip()
                out.append((i + 1, t[1:-1] if t.startswith("<") else t))
            m = cls.REF_RE.match(s)
            if m:
                t = m.group(2)
                out.append((i + 1, t[1:-1] if t.startswith("<") else t))
            for m in cls.HREF_RE.finditer(s):
                out.append((i + 1, m.group(1)))
        return out


class CaseFS:
    """Exact-case existence checks (Windows is case-insensitive, GitHub is not)."""

    def __init__(self, root):
        self.root = root
        self.cache = {}

    def listing(self, d):
        if d not in self.cache:
            try:
                self.cache[d] = set(os.listdir(os.path.join(self.root, *d.split("/"))) if d else os.listdir(self.root))
            except OSError:
                self.cache[d] = None
        return self.cache[d]

    def exists(self, rel):
        """-> True, False, or the correctly-cased path when only the case is wrong."""
        parts = [p for p in rel.split("/") if p]
        cur, fixed, wrong = "", [], False
        for p in parts:
            ls = self.listing(cur)
            if ls is None:
                return False
            if p not in ls:
                alt = next((x for x in ls if x.lower() == p.lower()), None)
                if alt is None:
                    return False
                wrong, p = True, alt
            fixed.append(p)
            cur = "/".join(fixed)
        return "/".join(fixed) if wrong else True


def cmd_check(kb, a):
    root = kb.root
    docs = [(rel, ab) for rel, ab in walk(root, "docs", (".md",))]
    if not docs:
        sys.exit("no docs/ found")
    fs = CaseFS(root)
    problems = []          # (severity, path, line, code, msg)

    def add(sev, path, line, code, msg):
        problems.append((sev, path, line, code, msg))
    cache = {}

    def load(rel):
        if rel not in cache:
            lines = read_lines(os.path.join(root, *rel.split("/")))
            fm, start, errs = parse_frontmatter(lines)
            heads = md_headings(lines, start)
            cache[rel] = (lines, fm, start, errs, {h.slug for h in heads} | html_ids(lines))
        return cache[rel]
    graph = {}
    for rel, ab in docs:
        lines, fm, start, errs, anchors = load(rel)
        generated = rel.startswith(API_DIR + "/")
        # frontmatter
        if not generated:
            for ln, msg in errs:
                add("E", rel, ln, "frontmatter", msg)
            if fm is None:
                if not errs:
                    add("E", rel, 1, "frontmatter", "no frontmatter (need: " + ", ".join(REQUIRED_FM) + ")")
            else:
                for k in REQUIRED_FM:
                    if k not in fm or fm[k] in ("", []):
                        add("E", rel, 1, "frontmatter", f"missing '{k}'")
                for k, allowed in (("kind", KINDS), ("status", STATUSES), ("scope", SCOPES)):
                    v = fm.get(k)
                    if v not in (None, "") and (not isinstance(v, str) or v not in allowed):
                        add("E", rel, 1, "frontmatter", f"{k}: '{v}' not one of {'|'.join(allowed)}")
                tags = fm.get("tags")
                if tags not in (None, "") and not isinstance(tags, list):
                    add("E", rel, 1, "frontmatter", "tags must be a [list]")
                elif isinstance(tags, list):
                    for t in tags:
                        if t not in TAGS:
                            add("W", rel, 1, "tag", f"unknown tag '{t}' (known: {' '.join(TAGS)})")
                for k in fm:
                    if k not in REQUIRED_FM + ["verified"]:
                        add("W", rel, 1, "frontmatter", f"unknown field '{k}'")
                if isinstance(fm.get("summary"), str) and len(fm["summary"]) > 300:
                    add("W", rel, 1, "frontmatter", "summary longer than 300 chars (one sentence, please)")
                if fm.get("scope") == "mercenaries" and rel.startswith("docs/kcd2/"):
                    add("W", rel, 1, "frontmatter", "scope: mercenaries page under docs/kcd2/")
        # size
        if rel.startswith("docs/kcd2/") and not generated and len(lines) > a.max_lines:
            add("W", rel, len(lines), "size", f"{len(lines)} lines (> {a.max_lines}; split it)")
        # links
        graph[rel] = set()
        for ln, target in Links.extract(lines, start):
            if not target or re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I) or target.startswith("//"):
                continue
            path_part, _, anchor = target.partition("#")
            path_part = urllib.parse.unquote(path_part.split("?")[0])
            anchor = urllib.parse.unquote(anchor)
            if path_part.startswith("/"):
                add("W", rel, ln, "link", f"absolute link '{target}' (use a relative path)")
                continue
            if not path_part:
                dest = rel
            else:
                dest = posixpath.normpath(posixpath.join(posixpath.dirname(rel), path_part))
                if dest.startswith("../") or dest == "..":
                    add("E", rel, ln, "link", f"'{target}' leaves the repo")
                    continue
                ex = fs.exists(dest)
                if ex is False:
                    sev = "W" if dest.startswith("references/") else "E"
                    add(sev, rel, ln, "link", f"broken link '{target}' ({dest} does not exist"
                        + (", references/ is local-only)" if sev == "W" else ")"))
                    continue
                if ex is not True:
                    add("E", rel, ln, "link", f"'{target}': wrong case, file is {ex}")
                    dest = ex
                if dest.startswith("references/"):
                    add("W", rel, ln, "link", f"'{target}' points into local-only references/ (dead on GitHub)")
            if dest.lower().endswith(".md") and os.path.isfile(os.path.join(root, *dest.split("/"))):
                if dest.startswith("docs/"):
                    graph[rel].add(dest)
                if anchor:
                    _, _, _, _, anchors = load(dest)
                    if anchor not in anchors:
                        sug = difflib.get_close_matches(anchor.lower(), sorted(anchors), n=1, cutoff=0.6)
                        add("E", rel, ln, "anchor", f"'{target}': no #{anchor} in {dest}"
                            + (f" (did you mean #{sug[0]}?)" if sug else ""))
    # api/index.tsv page column must point at real pages/anchors (exact case: GitHub is case-sensitive)
    tsv_rel = f"{API_DIR}/index.tsv"
    if os.path.isfile(os.path.join(root, *tsv_rel.split("/"))):
        for r in ApiIndex(root).rows:
            page = r["page_raw"]
            if not page:
                continue
            p, _, anchor = page.partition("#")
            dest = posixpath.normpath(posixpath.join(API_DIR, p)) if p and not p.startswith("docs/") else (p or "")
            if not dest:
                continue
            ex = fs.exists(dest)
            if ex is False:
                add("E", tsv_rel, r["line"], "link", f"page '{page}' does not exist")
                continue
            if ex is not True:
                add("E", tsv_rel, r["line"], "link", f"page '{page}': wrong case, file is {ex}")
                dest = ex
            if anchor and dest.endswith(".md") and anchor not in load(dest)[4]:
                add("E", tsv_rel, r["line"], "anchor", f"page '{page}': no #{anchor} in {dest}")
    # orphans
    roots = [r for r in ("docs/README.md", "docs/kcd2/README.md") if r in graph]
    if not roots and "docs/index.md" in graph:
        roots = ["docs/index.md"]
    if roots:
        seen, todo = set(roots), list(roots)
        while todo:
            for d in graph.get(todo.pop(), ()):
                if d not in seen:
                    seen.add(d)
                    todo.append(d)
        for rel, _ in docs:
            if rel not in seen:
                add("W", rel, 1, "orphan", f"not reachable from {' / '.join(roots)}")
    else:
        add("E", "docs/README.md", 1, "orphan", "missing docs/README.md (entry point)")
    errs = [p for p in problems if p[0] == "E"]
    warns = [p for p in problems if p[0] == "W"]
    problems.sort(key=lambda p: (p[0], p[1], p[2]))
    shown = 0
    for sev, path, line, code, msg in problems:
        if a.only and code not in parse_list(a.only):
            continue
        if shown >= a.max:
            print(f"... (use -n; {len(problems) - shown} more)")
            break
        print(f"{sev} {path}:{line}  {code}: {msg}")
        shown += 1
    counts = {}
    for p in problems:
        counts[f"{p[0]}:{p[3]}"] = counts.get(f"{p[0]}:{p[3]}", 0) + 1
    print(f"{len(docs)} docs checked: {len(errs)} errors, {len(warns)} warnings  "
          + "  ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    if errs or (a.strict and warns):
        sys.exit(1)


# ----------------------------------------------------------------------------------------------
# markdown -> html (for serve)

def esc(s):
    return html.escape(s, quote=True)


class MdRender:
    ALERT_RE = re.compile(r"^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*$", re.I)
    SAFE_TAGS = r"br|kbd|sub|sup|b|i|em|strong|u|s|del|details|summary|small|mark"

    def __init__(self, rel):
        self.rel = rel

    # links are rewritten into the viewer's hash routes: #p=<repo path>&a=<anchor>
    def href(self, url, image=False):
        url = url.strip()
        if url.startswith("<") and url.endswith(">"):
            url = url[1:-1]
        if re.match(r"^[a-z][a-z0-9+.-]*:", url, re.I) or url.startswith("//"):
            return url, True
        path, _, anchor = url.partition("#")
        path = urllib.parse.unquote(path)
        dest = posixpath.normpath(posixpath.join(posixpath.dirname(self.rel), path)) if path else self.rel
        if image:
            return "/raw/" + urllib.parse.quote(dest), False
        return "#" + urllib.parse.urlencode({"p": dest, "a": urllib.parse.unquote(anchor)}), False

    def inline(self, s):
        store = []

        def put(h):
            store.append(h)
            return f"\x00{len(store) - 1}\x00"
        s = re.sub(r"(`+)(.+?)(?<!`)\1(?!`)", lambda m: put("<code>" + esc(m.group(2).strip()) + "</code>"), s)
        s = re.sub(r"\\([\\`*_{}\[\]()#+\-.!|<>~])", lambda m: put(esc(m.group(1))), s)
        s = re.sub(r"<(https?://[^>\s]+)>", lambda m: put(f'<a href="{esc(m.group(1))}" target="_blank" rel="noopener">'
                                                           f'{esc(m.group(1))}</a>'), s)

        def img(m):
            u, _ = self.href(m.group(2), image=True)
            return put(f'<img alt="{esc(m.group(1))}" src="{esc(u)}">')
        s = re.sub(r"!\[([^\]]*)\]\(\s*(<[^>]*>|[^)\s]*)(?:\s+\"[^\"]*\")?\s*\)", img, s)

        def link(m):
            u, ext = self.href(m.group(2))
            inner = self.inline_fmt(m.group(1), put)
            return put(f'<a href="{esc(u)}"' + (' target="_blank" rel="noopener"' if ext else "") + f">{inner}</a>")
        s = re.sub(r"\[((?:[^\[\]]|\[[^\]]*\])*)\]\(\s*(<[^>]*>|[^()\s]*(?:\([^()]*\)[^()\s]*)*)(?:\s+\"[^\"]*\")?\s*\)", link, s)
        s = re.sub(r"(?<![\"'=])\bhttps?://[^\s<>()]+[^\s<>().,;:!?'\"]",
                   lambda m: put(f'<a href="{esc(m.group(0))}" target="_blank" rel="noopener">{esc(m.group(0))}</a>'), s)
        s = self.inline_fmt(s, put)
        while "\x00" in s:
            s2 = re.sub(r"\x00(\d+)\x00", lambda m: store[int(m.group(1))], s)
            if s2 == s:
                break
            s = s2
        return s

    def inline_fmt(self, s, put):
        s = esc(s)
        s = re.sub(rf"&lt;(/?(?:{self.SAFE_TAGS})\s*/?)&gt;", r"<\1>", s, flags=re.I)
        s = re.sub(r"\*\*(?=\S)(.+?)(?<=\S)\*\*", r"<strong>\1</strong>", s)
        s = re.sub(r"(?<![A-Za-z0-9_])__(?=\S)(.+?)(?<=\S)__(?![A-Za-z0-9_])", r"<strong>\1</strong>", s)
        s = re.sub(r"(?<![*\w])\*(?=[^\s*])(.+?)(?<=[^\s*])\*(?![*\w])", r"<em>\1</em>", s)
        s = re.sub(r"(?<![A-Za-z0-9_])_(?=\S)(.+?)(?<=\S)_(?![A-Za-z0-9_])", r"<em>\1</em>", s)
        s = re.sub(r"~~(?=\S)(.+?)(?<=\S)~~", r"<del>\1</del>", s)
        return s

    @staticmethod
    def indent(line):
        return len(line) - len(line.lstrip(" "))

    def is_block_start(self, lines, i):
        line = lines[i]
        s = line.strip()
        return (not s or FENCE_RE.match(line) or ATX_RE.match(line) or HR_RE.match(line) or s.startswith(">")
                or LIST_RE.match(line) or re.match(r"^<(div|details|table|p|pre|!--|h\d)\b", s)
                or (i + 1 < len(lines) and "|" in line and self.is_table_sep(lines[i + 1])))

    @staticmethod
    def is_table_sep(line):
        return bool(re.match(r"^\s*\|?\s*:?-{1,}:?\s*(\|\s*:?-{1,}:?\s*)*\|?\s*$", line)) and "-" in line and \
            ("|" in line or line.strip().count("-") > 0 and ":" in line)

    @staticmethod
    def row_cells(line):
        s = line.strip()
        if s.startswith("|"):
            s = s[1:]
        if s.endswith("|") and not s.endswith("\\|"):
            s = s[:-1]
        cells, cur, code = [], "", False
        i = 0
        while i < len(s):
            ch = s[i]
            if ch == "\\" and i + 1 < len(s) and s[i + 1] == "|":
                cur += "|"
                i += 2
                continue
            if ch == "`":
                code = not code
            if ch == "|" and not code:
                cells.append(cur.strip())
                cur = ""
            else:
                cur += ch
            i += 1
        cells.append(cur.strip())
        return cells

    def render(self, text):
        lines = [ln.expandtabs(4) for ln in text.replace("\r\n", "\n").split("\n")]
        fm, start, _ = parse_frontmatter(lines)
        heads = {h.line: h for h in md_headings(lines, start)}
        return fm, self.blocks(lines, start, len(lines), heads)

    def blocks(self, lines, i, end, heads=None):
        out = []
        heads = heads or {}
        while i < end:
            line = lines[i]
            s = line.strip()
            if not s:
                i += 1
                continue
            m = FENCE_RE.match(line)
            if m and not (m.group(1)[0] == "`" and "`" in m.group(2)):
                fence, lang = m.group(1), m.group(2).strip().split(" ")[0]
                ind = self.indent(line)
                j = i + 1
                body = []
                while j < end:
                    m2 = FENCE_RE.match(lines[j])
                    if m2 and m2.group(1)[0] == fence[0] and len(m2.group(1)) >= len(fence) and not m2.group(2).strip():
                        break
                    body.append(lines[j][min(ind, self.indent(lines[j])):])
                    j += 1
                cls = f' class="lang-{esc(lang)}"' if lang else ""
                out.append(f"<pre><code{cls}>{esc(chr(10).join(body))}</code></pre>")
                i = j + 1
                continue
            m = ATX_RE.match(line)
            if m:
                lvl = len(m.group(1))
                raw = re.sub(r"[ \t]+#+[ \t]*$", "", m.group(2) or "")
                h = heads.get(i)
                sid = h.slug if h else slug_base(strip_inline(raw))
                out.append(self.heading(lvl, raw, sid))
                i += 1
                continue
            if HR_RE.match(line):
                out.append("<hr>")
                i += 1
                continue
            if s.startswith(">"):
                sub = []
                while i < end and lines[i].strip().startswith(">"):
                    sub.append(re.sub(r"^\s*> ?", "", lines[i]))
                    i += 1
                cls = ""
                if sub and self.ALERT_RE.match(sub[0].strip()):
                    kind = self.ALERT_RE.match(sub[0].strip()).group(1).lower()
                    cls = f' class="alert alert-{kind}"'
                    sub[0] = f"**{kind.capitalize()}**"
                out.append(f"<blockquote{cls}>{self.blocks(sub, 0, len(sub))}</blockquote>")
                continue
            m = LIST_RE.match(line)
            if m:
                i = self.list_block(lines, i, end, out)
                continue
            if "|" in line and i + 1 < end and self.is_table_sep(lines[i + 1]):
                head = self.row_cells(line)
                aligns = []
                for c in self.row_cells(lines[i + 1]):
                    c = c.strip()
                    aligns.append("center" if c.startswith(":") and c.endswith(":") else
                                  "right" if c.endswith(":") else "left" if c.startswith(":") else "")
                j = i + 2
                rows = []
                while j < end and lines[j].strip() and "|" in lines[j]:
                    rows.append(self.row_cells(lines[j]))
                    j += 1

                def td(tag, c, k):
                    al = aligns[k] if k < len(aligns) and aligns[k] else ""
                    return f"<{tag}" + (f' style="text-align:{al}"' if al else "") + f">{self.inline(c)}</{tag}>"
                h = "".join(td("th", c, k) for k, c in enumerate(head))
                b = "".join("<tr>" + "".join(td("td", c, k) for k, c in enumerate(r[:max(len(head), 1)])) + "</tr>"
                            for r in rows)
                out.append(f'<div class="tw"><table><thead><tr>{h}</tr></thead><tbody>{b}</tbody></table></div>')
                i = j
                continue
            if s.startswith("<!--"):
                while i < end and "-->" not in lines[i]:
                    i += 1
                i += 1
                continue
            if re.match(r"^<(/?)(div|details|summary|table|p|pre|img|br|a|center|h\d)\b", s, re.I):
                raw = []
                while i < end and lines[i].strip():
                    raw.append(lines[i])
                    i += 1
                out.append(re.sub(r"<\s*script", "&lt;script", "\n".join(raw), flags=re.I))
                continue
            if line.startswith("    "):
                body = []
                while i < end and (lines[i].startswith("    ") or not lines[i].strip()):
                    body.append(lines[i][4:])
                    i += 1
                while body and not body[-1].strip():
                    body.pop()
                out.append(f"<pre><code>{esc(chr(10).join(body))}</code></pre>")
                continue
            # paragraph (+ setext heading)
            para = [s]
            j = i + 1
            setext = None
            while j < end:
                m2 = SETEXT_RE.match(lines[j])
                if m2 and lines[j].strip():
                    setext = 1 if m2.group(1)[0] == "=" else 2
                    break
                if self.is_block_start(lines, j):
                    break
                para.append(lines[j].strip())
                j += 1
            if setext:
                h = heads.get(j - 1)
                raw = " ".join(para)
                out.append(self.heading(setext, raw, h.slug if h else slug_base(strip_inline(raw))))
                i = j + 1
                continue
            text = "\n".join(para)
            text = re.sub(r"(  |\\)\n", "<br>\n", text)
            out.append(f"<p>{self.inline(text).replace('&lt;br&gt;', '<br>')}</p>")
            i = j
        return "\n".join(out)

    def heading(self, lvl, raw, sid):
        return (f'<h{lvl} id="{esc(sid)}">{self.inline(raw)}'
                f'<a class="hl" href="#{esc(urllib.parse.urlencode({"p": self.rel, "a": sid}))}">#</a></h{lvl}>')

    def list_block(self, lines, i, end, out):
        m = LIST_RE.match(lines[i])
        ordered = m.group(2)[0].isdigit()
        start_no = int(m.group(2)[:-1]) if ordered else None
        items, loose = [], False
        while i < end:
            m = LIST_RE.match(lines[i])
            if not m or m.group(2)[0].isdigit() != ordered:
                break
            content = m.group(4) or ""
            ci = len(m.group(1)) + len(m.group(2)) + (len(m.group(3)) if m.group(3) and len(m.group(3)) <= 4 else 1)
            item = [content]
            i += 1
            while i < end:
                ln = lines[i]
                if not ln.strip():
                    j = i
                    while j < end and not lines[j].strip():
                        j += 1
                    if j < end and self.indent(lines[j]) >= ci:
                        item += [""] * (j - i)
                        loose = True
                        i = j
                        continue
                    break
                if self.indent(ln) >= ci:
                    item.append(ln[ci:])
                    i += 1
                    continue
                if LIST_RE.match(ln) or self.is_block_start(lines, i):
                    break
                item.append(ln.strip())
                i += 1
            items.append(item)
            j = i
            while j < end and not lines[j].strip():
                j += 1
            if j > i and j < end and LIST_RE.match(lines[j]) and LIST_RE.match(lines[j]).group(2)[0].isdigit() == ordered:
                loose = True
                i = j
            elif j > i:
                i = j
                break
        parts = []
        for item in items:
            task = ""
            if item and re.match(r"^\[[ xX]\]\s", item[0]):
                task = '<input type="checkbox" disabled' + (" checked" if item[0][1] in "xX" else "") + "> "
                item[0] = item[0][4:]
            h = self.blocks(item, 0, len(item))
            if not loose:
                h = re.sub(r"^<p>(.*?)</p>", r"\1", h, count=1, flags=re.S)
            parts.append(f"<li>{task}{h}</li>")
        tag = "ol" if ordered else "ul"
        st = f' start="{start_no}"' if ordered and start_no not in (None, 1) else ""
        out.append(f"<{tag}{st}>" + "".join(parts) + f"</{tag}>")
        return i


def render_file(root, rel):
    ab = os.path.join(root, *rel.split("/"))
    low = rel.lower()
    info = {"path": rel, "title": posixpath.basename(rel), "meta": {}, "type": "code", "html": ""}
    size = os.path.getsize(ab)
    text = read_text(ab)
    if size > 3_000_000:
        text = text[:3_000_000]
    if low.endswith(".md"):
        r = MdRender(rel)
        fm, body = r.render(text)
        lines = text.split("\n")
        meta, heads, _ = md_file_meta(rel, lines)
        info.update(type="md", html=body, title=meta["title"], meta={k: meta[k] for k in (
            "title", "summary", "tags", "kind", "status", "scope", "verified", "has_fm")},
            headings=[{"level": h.level, "text": h.text, "slug": h.slug} for h in heads if 2 <= h.level <= 3])
        return info
    lines = text.split("\n")
    if low.endswith(".tsv"):
        rows = [ln.split("\t") for ln in lines]
        hdr = next((k for k, r in enumerate(rows) if any(c.strip() for c in r) and not r[0].startswith("#")), 0)
        h = "".join(f"<th>{esc(c)}</th>" for c in rows[hdr]) if rows else ""
        b = "".join(f'<tr id="L{k + 1}">' + "".join(f"<td>{esc(c)}</td>" for c in r) + "</tr>"
                    for k, r in enumerate(rows) if k > hdr and any(c.strip() for c in r))
        info.update(type="tsv", html=f'<div class="tw"><table><thead><tr>{h}</tr></thead><tbody>{b}</tbody></table></div>')
        return info
    body = "".join(f'<span class="ln" id="L{k + 1}">{k + 1}</span>{esc(ln)}\n' for k, ln in enumerate(lines))
    info.update(html=f'<pre class="code">{body}</pre>')
    return info


# ----------------------------------------------------------------------------------------------
# serve

PAGE = r"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>KCD2 KB</title>
<style>
:root{--bg:#fbfbfa;--fg:#1d1d1f;--muted:#6b6b70;--line:#e3e3e0;--panel:#fff;--acc:#8a4b12;--mark:#ffe58a;
--code:#f3f2ef;--hit:#f5efe6;--b1:#e8f0e3;--b2:#f7e9d7;--b3:#e7ebf5;--bad:#b3261e}
@media (prefers-color-scheme:dark){:root{--bg:#161617;--fg:#e6e6e3;--muted:#9a9a9f;--line:#2e2e31;
--panel:#1d1d1f;--acc:#e0a060;--mark:#6b5410;--code:#26262a;--hit:#2a2520;--b1:#23321d;--b2:#3a2c1a;--b3:#1f2638;--bad:#f28b82}}
*{box-sizing:border-box}html,body{margin:0;height:100%}
body{background:var(--bg);color:var(--fg);font:14px/1.5 system-ui,-apple-system,"Segoe UI",sans-serif;display:flex;flex-direction:column}
header{display:flex;gap:8px;align-items:center;padding:10px 14px;border-bottom:1px solid var(--line);flex-wrap:wrap}
header b{color:var(--acc);white-space:nowrap}
#q{flex:1;min-width:200px;font:inherit;padding:7px 10px;border:1px solid var(--line);border-radius:6px;background:var(--panel);color:var(--fg)}
select{font:inherit;padding:5px;border:1px solid var(--line);border-radius:6px;background:var(--panel);color:var(--fg);max-width:140px}
main{flex:1;display:flex;min-height:0}
#res{width:38%;min-width:280px;overflow:auto;border-right:1px solid var(--line);padding:6px 0}
#view{flex:1;overflow:auto;padding:18px 28px 80px}
.hit{padding:7px 14px;cursor:pointer;border-bottom:1px solid var(--line)}
.hit:hover,.hit.on{background:var(--hit)}
.hit .h{font-weight:600}.hit .p{color:var(--muted);font-size:12px;word-break:break-all}
.hit .s{font-size:13px;color:var(--fg);opacity:.9;overflow-wrap:anywhere}
mark{background:var(--mark);color:inherit;border-radius:2px;padding:0 1px}
.badge{display:inline-block;font-size:11px;padding:0 6px;border-radius:9px;margin-right:4px;background:var(--b3);color:var(--fg)}
.badge.source{background:var(--b1)}.badge.status{background:var(--b2)}
.note{color:var(--muted);padding:6px 14px;font-size:12px}
#view h1,#view h2,#view h3{line-height:1.25;margin:1.3em 0 .5em}#view h1{margin-top:0}
#view h2{border-bottom:1px solid var(--line);padding-bottom:4px}
.hl{margin-left:6px;color:var(--muted);text-decoration:none;opacity:0}h1:hover .hl,h2:hover .hl,h3:hover .hl,h4:hover .hl{opacity:1}
a{color:var(--acc)}code{background:var(--code);padding:1px 4px;border-radius:4px;font:12.5px ui-monospace,Consolas,monospace}
pre{background:var(--code);padding:10px 12px;border-radius:6px;overflow:auto}pre code{padding:0;background:none}
pre.code{font:12.5px/1.45 ui-monospace,Consolas,monospace}.ln{display:inline-block;width:4.5em;color:var(--muted);user-select:none}
.tw{overflow:auto}table{border-collapse:collapse;margin:8px 0;font-size:13px}th,td{border:1px solid var(--line);padding:4px 8px;vertical-align:top}
th{background:var(--code)}blockquote{margin:8px 0;padding:4px 14px;border-left:3px solid var(--line);color:var(--muted)}
blockquote.alert{border-left-color:var(--acc);color:var(--fg)}img{max-width:100%}
.target{background:var(--hit);outline:2px solid var(--mark)}
.meta{border:1px solid var(--line);border-radius:8px;padding:8px 12px;margin-bottom:14px;background:var(--panel)}
.meta .sum{margin-top:4px;color:var(--muted)}.crumb{color:var(--muted);font-size:12px;margin-bottom:8px;word-break:break-all}
.toc-g{padding:8px 14px 2px;font-weight:600;color:var(--muted);font-size:12px;text-transform:uppercase}
@media (max-width:760px){main{flex-direction:column}#res{width:auto;min-width:0;max-height:45%;border-right:0;border-bottom:1px solid var(--line)}#view{padding:14px 16px 60px}}
</style></head><body>
<header><b>KCD2 KB</b><input id="q" placeholder="Search  (/ to focus)  e.g. System.SetCVar, interior, morale" autocomplete="off">
<select id="source"></select><select id="scope"></select><select id="kind"></select><select id="status"></select><select id="tag"></select></header>
<main><div id="res"></div><div id="view"><p class="note">Type to search, or pick a page from the list.</p></div></main>
<script>
const $=s=>document.querySelector(s), FAC=["source","scope","kind","status","tag"];
const esc=s=>String(s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
let cur=null, timer=null, seq=0;
async function facets(){const f=await (await fetch("/api/facets")).json();
 for(const k of FAC){const el=$("#"+k);el.innerHTML=`<option value="">${k}: any</option>`+
  Object.entries(f[k]||{}).map(([v,n])=>`<option value="${esc(v)}">${esc(v)} (${n})</option>`).join("");
  el.onchange=run;}}
function params(){const p=new URLSearchParams({q:$("#q").value,n:"60"});for(const k of FAC)if($("#"+k).value)p.set(k,$("#"+k).value);return p}
function link(h){const a=h.anchor||(h.line?"L"+h.line:"");return "#"+new URLSearchParams({p:h.path,a:a}).toString()}
function snip(s){return esc(s).replace(/\u0002/g,"<mark>").replace(/\u0003/g,"</mark>")}
async function run(){const my=++seq;const p=params();
 if(!p.get("q").trim()){return toc()}
 const r=await (await fetch("/api/search?"+p)).json(); if(my!==seq)return;
 const counts=Object.entries(r.by_source||{}).map(([k,v])=>k+" "+v).join(", ");
 $("#res").innerHTML=`<div class="note">${r.hits.length} of ${r.total} hits${counts?" ("+counts+")":""}${r.note?" &mdash; "+esc(r.note):""}</div>`+
  r.hits.map(h=>`<div class="hit" data-href="${esc(link(h))}"><div class="h">${esc(h.heading)}</div>
  <div class="p"><span class="badge source">${esc(h.source)}</span>${h.kind?`<span class="badge">${esc(h.kind)}</span>`:""}${h.status&&h.status!=="current"?`<span class="badge status">${esc(h.status)}</span>`:""}${esc(h.path)}${h.line?":"+h.line:""}</div>
  <div class="s">${snip(h.snippet)}</div></div>`).join("");
 bindHits()}
function bindHits(){document.querySelectorAll(".hit").forEach(el=>el.onclick=()=>{location.hash=el.dataset.href.slice(1);
 document.querySelectorAll(".hit.on").forEach(x=>x.classList.remove("on"));el.classList.add("on")})}
async function toc(){const p=params();const r=await (await fetch("/api/toc?"+p)).json();let html="",g=null;
 for(const d of r.docs){if(d.group!==g){g=d.group;html+=`<div class="toc-g">${esc(g)}</div>`}
  html+=`<div class="hit" data-href="${esc("#"+new URLSearchParams({p:d.path,a:""}))}"><div class="h">${esc(d.title)}</div>
  <div class="p">${d.status&&d.status!=="current"?`<span class="badge status">${esc(d.status)}</span>`:""}${esc(d.path)}</div><div class="s">${esc(d.summary)}</div></div>`}
 $("#res").innerHTML=`<div class="note">${r.docs.length} pages</div>`+html;bindHits()}
async function route(){const h=new URLSearchParams(location.hash.slice(1));const p=h.get("p"),a=h.get("a")||"";if(!p)return;
 if(p!==cur){const r=await fetch("/api/page?path="+encodeURIComponent(p));
  if(!r.ok){$("#view").innerHTML=`<p class="note">Cannot open ${esc(p)} (${r.status})</p>`;return}
  const d=await r.json();cur=p;let m="";
  if(d.type==="md"){const x=d.meta;m=`<div class="meta">`+[x.kind,x.status,x.scope].filter(Boolean).map((v,i)=>`<span class="badge ${i==1?"status":""}">${esc(v)}</span>`).join("")+
   (x.tags||[]).map(t=>`<span class="badge source">#${esc(t)}</span>`).join("")+(x.verified?`<span class="badge">verified ${esc(x.verified)}</span>`:"")+
   (x.has_fm?"":`<span class="badge">no frontmatter</span>`)+(x.summary?`<div class="sum">${esc(x.summary)}</div>`:"")+`</div>`}
  $("#view").innerHTML=`<div class="crumb">${esc(p)}</div>`+m+d.html;document.title=d.title+" - KCD2 KB"}
 document.querySelectorAll(".target").forEach(x=>x.classList.remove("target"));
 let el=null;if(a){el=document.getElementById(a)||document.getElementById(a.toLowerCase());
  const lr=/^L(\d+)$/.exec(a);if(!el&&lr){el=document.getElementById("L"+lr[1])}}
 if(el){el.scrollIntoView({block:"start"});el.classList.add("target")}else $("#view").scrollTop=0}
$("#q").addEventListener("input",()=>{clearTimeout(timer);timer=setTimeout(run,160)});
document.addEventListener("keydown",e=>{if(e.key==="/"&&document.activeElement!==$("#q")){e.preventDefault();$("#q").focus()}});
window.addEventListener("hashchange",route);
facets().then(()=>{const q=new URLSearchParams(location.search).get("q");if(q)$("#q").value=q;run();route()});
</script></body></html>"""


def cmd_serve(kb, a):
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
    kb.ensure()
    kb.db.close()
    kb.db = None
    root = kb.root
    state = {"checked": time.time()}

    def conn():
        k = KB(root, kb.db_path, quiet=True)
        if time.time() - state["checked"] > 5:
            state["checked"] = time.time()
            k.ensure()
        else:
            k.open()
        return k

    def safe_rel(p):
        p = urllib.parse.unquote(p or "").replace("\\", "/").lstrip("/")
        rel = posixpath.normpath(p)
        if rel.startswith("..") or rel.startswith(".git") or ":" in rel or not rel or rel == ".":
            return None
        ab = os.path.join(root, *rel.split("/"))
        if not os.path.isfile(ab):
            return None
        return rel

    class H(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            if a.verbose:
                sys.stderr.write("kb serve: " + fmt % args + "\n")

        def send(self, code, body, ctype="application/json; charset=utf-8"):
            if isinstance(body, (dict, list)):
                body = json.dumps(body, ensure_ascii=False)
            if isinstance(body, str):
                body = body.encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            u = urllib.parse.urlparse(self.path)
            q = {k: v[0] for k, v in urllib.parse.parse_qs(u.query).items()}
            try:
                if u.path == "/":
                    return self.send(200, PAGE, "text/html; charset=utf-8")
                if u.path == "/api/search":
                    k = conn()
                    hits, total, by_src, note = search(
                        k, q.get("q", ""), parse_list(q.get("source")), parse_list(q.get("tag")),
                        parse_list(q.get("kind")), parse_list(q.get("scope")), parse_list(q.get("status")),
                        n=min(int(q.get("n", 30)), 200), per_file=int(q.get("per_file", 3)), mark=("\x02", "\x03"))
                    return self.send(200, {"query": q.get("q", ""), "total": total, "by_source": by_src,
                                           "note": note, "hits": hits})
                if u.path == "/api/facets":
                    db = conn().db
                    out = {}
                    for col in ("source", "scope", "kind", "status"):
                        out[col] = {v: n for v, n in db.execute(
                            f"SELECT {col}, count(*) FROM chunks WHERE {col} != '' GROUP BY {col} ORDER BY 2 DESC")}
                    tags = {}
                    for (t,) in db.execute("SELECT tags FROM files WHERE tags != ''"):
                        for x in t.split():
                            tags[x] = tags.get(x, 0) + 1
                    out["tag"] = dict(sorted(tags.items(), key=lambda kv: -kv[1]))
                    return self.send(200, out)
                if u.path == "/api/toc":
                    db = conn().db
                    where, args = ["(source='docs' OR path=?)"], [f"{API_DIR}/README.md"]
                    for col in ("scope", "kind", "status"):
                        if q.get(col):
                            where.append(f"{col}=?")
                            args.append(q[col])
                    if q.get("tag"):
                        where.append("tags LIKE ?")
                        args.append(f"% {q['tag']} %")
                    rows = db.execute(f"SELECT path, title, summary, kind, status, scope FROM files WHERE "
                                      f"{' AND '.join(where)} AND path LIKE '%.md'", args).fetchall()
                    docs = [{"path": p, "title": t, "summary": s, "kind": k, "status": st, "scope": sc,
                             "group": f"{sc or '?'} / {k or 'no frontmatter'}"} for p, t, s, k, st, sc in rows]
                    docs.sort(key=lambda d: ("no frontmatter" in d["group"], d["group"], d["path"]))
                    return self.send(200, {"docs": docs})
                if u.path == "/api/page":
                    rel = safe_rel(q.get("path"))
                    if not rel:
                        return self.send(404, {"error": "not found"})
                    return self.send(200, render_file(root, rel))
                if u.path.startswith("/raw/"):
                    rel = safe_rel(u.path[5:])
                    if not rel:
                        return self.send(404, {"error": "not found"})
                    import mimetypes
                    ctype = mimetypes.guess_type(rel)[0] or "application/octet-stream"
                    if ctype.startswith("text/html") or rel.lower().endswith((".svg", ".xml", ".html")):
                        ctype = "text/plain; charset=utf-8"
                    with open(os.path.join(root, *rel.split("/")), "rb") as f:
                        return self.send(200, f.read(), ctype)
                return self.send(404, {"error": "not found"})
            except Exception as e:     # keep serving
                return self.send(500, {"error": f"{type(e).__name__}: {e}"})

    srv = ThreadingHTTPServer(("127.0.0.1", a.port), H)
    print(f"kb: serving http://127.0.0.1:{a.port}/  (Ctrl+C to stop)", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        srv.server_close()


# ----------------------------------------------------------------------------------------------
# cli

def cmd_build(kb, a):
    db = kb.open()
    enabled = kb.enabled_sources()
    if a.only:
        sources = parse_list(a.only)
        bad = [s for s in sources if s not in ALL_SOURCES]
        if bad:
            sys.exit(f"unknown source(s): {', '.join(bad)} (have: {', '.join(ALL_SOURCES)})")
    else:
        for flag, src in ((a.with_vanilla, "vanilla"), (a.with_code, "mod")):
            if flag and src not in enabled:
                enabled.append(src)
        for flag, src in ((a.no_vanilla, "vanilla"), (a.no_code, "mod")):
            if flag and src in enabled:
                enabled.remove(src)
        kb.set_meta("sources", ",".join(s for s in ALL_SOURCES if s in enabled))
        db.commit()
        sources = enabled
    if a.full and not a.only:
        kb.db.close()
        kb.db = None
        for suf in ("", "-wal", "-shm"):
            if os.path.exists(kb.db_path + suf):
                os.remove(kb.db_path + suf)
        kb.open()
        kb.set_meta("sources", ",".join(s for s in ALL_SOURCES if s in enabled))
    kb.build(sources, full=a.full)


def cmd_search(kb, a):
    kb.ensure()
    q = " ".join(a.query)
    hits, total, by_src, note = search(kb, q, parse_list(a.source), parse_list(a.tag), parse_list(a.kind),
                                       parse_list(a.scope), parse_list(a.status), n=a.max, per_file=a.per_file,
                                       raw=a.raw)
    if a.json:
        print(json.dumps({"query": q, "total": total, "by_source": by_src, "note": note, "hits": hits},
                         ensure_ascii=False, indent=1))
        return
    if note and not hits:
        print(note)
    for h in hits:
        print(fmt_hit(h))
    src = ", ".join(f"{k} {v}" for k, v in sorted(by_src.items(), key=lambda kv: -kv[1]))
    missing = [s for s in OPTIONAL_SOURCES if s not in kb.enabled_sources()]
    print(f"{len(hits)} of {total} hits" + (f" ({src})" if src else "") + (f"  [{note}]" if note and hits else "")
          + (f"  (not indexed: {', '.join(missing)})" if not hits and missing else ""))


def main():
    try:
        if not sys.stdout.isatty():
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        else:
            sys.stdout.reconfigure(errors="replace")
    except (AttributeError, ValueError):
        pass
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=os.environ.get("KB_ROOT", DEFAULT_ROOT), help="repo root (default: this repo)")
    ap.add_argument("--db", default=None, help="index file (default: <root>/tools/out/kb.sqlite)")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("build", help="(re)index; incremental unless --full")
    p.add_argument("--full", action="store_true")
    p.add_argument("--with-vanilla", action="store_true", help="also index vanilla Scripts + Libs/Tables (large)")
    p.add_argument("--with-code", action="store_true", help="also index this mod's data/**/*.lua|xml")
    p.add_argument("--no-vanilla", action="store_true")
    p.add_argument("--no-code", action="store_true")
    p.add_argument("--only", help="rebuild just these sources, e.g. docs,api")
    p.set_defaults(fn=cmd_build)

    p = sub.add_parser("search", help="full-text search")
    p.add_argument("query", nargs="+")
    p.add_argument("--source", help="comma list: " + ",".join(ALL_SOURCES))
    p.add_argument("--tag", help="comma list (any of)")
    p.add_argument("--kind")
    p.add_argument("--scope")
    p.add_argument("--status")
    p.add_argument("-n", "--max", type=int, default=10)
    p.add_argument("--per-file", type=int, default=3, help="max hits per file (0 = no cap)")
    p.add_argument("--raw", action="store_true", help="pass the query to FTS5 MATCH verbatim")
    p.add_argument("--json", action="store_true")
    p.set_defaults(fn=cmd_search)

    p = sub.add_parser("api", help="ScriptBind function lookup")
    p.add_argument("name")
    p.add_argument("-v", "--verbose", action="store_true", help="also print the page section")
    p.add_argument("-n", "--max", type=int, default=60)
    p.set_defaults(fn=cmd_api)

    p = sub.add_parser("cvar", help="cvar lookup")
    p.add_argument("pattern")
    p.add_argument("--file", default="cvars.tsv", help="data table to search (default cvars.tsv)")
    p.add_argument("--all-data", action="store_true", help="search every docs/kcd2/data/*.tsv")
    p.add_argument("-v", "--verbose", action="store_true")
    p.add_argument("-n", "--max", type=int, default=40)
    p.set_defaults(fn=cmd_cvar)

    p = sub.add_parser("show", help="print one section (path#anchor, path:line) or a page outline")
    p.add_argument("target")
    p.add_argument("--all", action="store_true", help="whole file")
    p.add_argument("-n", "--max", type=int, default=400, help="max lines printed")
    p.set_defaults(fn=cmd_show)

    p = sub.add_parser("toc", help="map of the docs")
    p.add_argument("--scope")
    p.add_argument("--tag")
    p.add_argument("--kind")
    p.add_argument("--status")
    p.add_argument("--by", choices=["meta", "dir"], default="meta", help="group by scope/kind or by directory")
    p.add_argument("--api", action="store_true", help="include the generated api pages")
    p.add_argument("-w", "--width", type=int, default=140, help="summary width")
    p.set_defaults(fn=cmd_toc)

    p = sub.add_parser("stats", help="index contents")
    p.set_defaults(fn=cmd_stats)

    p = sub.add_parser("serve", help="local web UI")
    p.add_argument("--port", type=int, default=8765)
    p.add_argument("-v", "--verbose", action="store_true")
    p.set_defaults(fn=cmd_serve)

    p = sub.add_parser("check", help="docs lint (exit 1 on errors)")
    p.add_argument("--strict", action="store_true", help="warnings fail too")
    p.add_argument("--only", help="comma list of codes: frontmatter,tag,link,anchor,orphan,size")
    p.add_argument("--max-lines", type=int, default=600)
    p.add_argument("-n", "--max", type=int, default=300, help="max problems printed")
    p.set_defaults(fn=cmd_check)

    a = ap.parse_args()
    kb = KB(a.root, a.db)
    a.fn(kb, a)


if __name__ == "__main__":
    main()
