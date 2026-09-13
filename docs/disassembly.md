# Disassembling WHGame.dll: finding `gEnv`

Everything the mod does today goes through Lua, XML, Skald and Behaviour Trees — channels the
game hands us. Native code is the channel it doesn't. An ASI plugin that wants to add a
scriptbind, register a console variable from C++, or hook a frame callback needs one thing
first: the address of **`gEnv`**, CryEngine's global environment struct. Every other engine
subsystem hangs off it.

This guide follows the procedure in [muyuanjin/kcd2-mod-docs](https://github.com/muyuanjin/kcd2-mod-docs)
(`DISASSEMBLY.md`), but does it without IDA and re-derives every number from the binary, so it
still works after a patch moves the addresses — which patches do, every time.

> **Nothing in the mod depends on this yet.** This is reconnaissance. It is written down because
> the analysis is cheap to re-run and expensive to reconstruct from memory.

---

## Running it

```bash
python tools/disassemble_whgame.py genv
```

Defaults to the Steam retail DLL at
`C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2\Bin\Win64MasterMasterSteamPGO\WHGame.dll`.
Pass a path to analyse a different build. Needs `pefile` and `capstone`.

Three subcommands:

| Command | What it does |
| --- | --- |
| `genv` | Finds `gEnv`, prints the call site, cross-checks the result |
| `validate` | Checks the guide's vtable offset table against the binary |
| `builds <dll...>` | Tabulates `gEnv` across several builds, and which signature matches each |

---

## The procedure

CryEngine runs `exec autoexec.cfg` through the console during startup. That one call site is
enough to find everything:

1. Find the string `exec autoexec.cfg` in `.rdata`. There is exactly one.
2. Find the instruction that references it. There is exactly one — a RIP-relative `lea`.
3. The console pointer being called through is loaded a few instructions above it.
4. That pointer's *storage address* is `&gEnv->pConsole`. `pConsole` is the 22nd member of
   `SSystemGlobalEnvironment`, so `gEnv = &gEnv->pConsole - 21*8 = -0xA8`.

On the current retail build the site looks like this:

```
0x0001808641A9  48 8b 0d f8 96 0c 04   mov   rcx, qword ptr [rip + 0x40c96f8]   <- gEnv->pConsole
0x0001808641B0  45 33 c9               xor   r9d, r9d
0x0001808641B3  45 33 c0               xor   r8d, r8d
0x0001808641B6  48 8b 11               mov   rdx, qword ptr [rcx]               <- vtable
0x0001808641B9  4c 8b 92 18 01 00 00   mov   r10, qword ptr [rdx + 0x118]       <- ExecuteString
0x0001808641C0  48 8d 15 d1 26 83 03   lea   rdx, [rip + 0x38326d1]             <- 'exec autoexec.cfg'
0x0001808641C7  41 ff d2               call  r10
```

Result for `release_1_5_1308617_856`:

| | RVA | VA |
| --- | --- | --- |
| `&gEnv->pConsole` | `0x0492D8A8` | `0x18492D8A8` |
| **`gEnv`** | **`0x0492D800`** | **`0x18492D800`** |

`IConsole::ExecuteString` sits at vtable slot `0x118` (index 35) — and that has been stable
across every build from 1.1.1 to 1.5.

### Why it's believable

A single derived address is easy to get wrong quietly. The cross-check counts how many
RIP-relative instructions in the whole image reference each slot of the struct:

```
gEnv+0x28  pScriptSystem     756 refs
gEnv+0x90  pGame             434 refs
gEnv+0xA8  pConsole         2472 refs
```

The struct is a contiguous run of ~50 heavily-referenced 8-byte pointer slots from `+0x00` to
about `+0x190`, and the base lands on an 8-byte boundary. Those are exactly the fingerprints of
`SSystemGlobalEnvironment`, and the three offsets the guide names fall on the busiest slots in
it. Running the same pipeline against the guide's own V1.2.2 DLL reproduces its published
`0x48A7C68` exactly, which is the strongest check available: the method agrees with the guide
where the guide has ground truth.

---

## Do not hardcode the RVA

This is the whole reason the tool exists. `gEnv` moves on almost every patch, including between
two builds that both call themselves `release_1_5`:

| Build | Size | Version tag | `gEnv` RVA |
| --- | --- | --- | --- |
| Steam retail (current) | 89,180,672 | `release_1_5_1308617_856` | `0x0492D800` |
| repo snapshot | 89,176,576 | `release_1_5_1164953_841` | `0x0492B800` |
| GamePass v1.4+ | 89,991,680 | `release_1_5_1164953_38` | `0x049D6F00` |
| V1.2.2 | 88,477,696 | `release_1_2_949874_572` | `0x048A7BC0` |
| V1.2.1 | 88,482,816 | `release_1_2_948129_567` | `0x048A8B80` |
| V1.2 | 88,492,544 | `release_1_2_944553_564` | `0x048ABB80` |
| V1.1.1 | 88,472,576 | `release_1_1_933032_526` | `0x048B0700` |

The installed game and the guide's `release_1_5` snapshot share a version *name* and differ by
8 KB in where `gEnv` lives. Anything that hardcodes an RVA and checks the version string will
read a wrong pointer and look like a random crash.

### The signature is also stale

The guide gives a byte pattern for runtime scanning:

```
48 8B 0D ?? ?? ?? ?? 48 8D 15 ?? ?? ?? ?? 45 33 C9 45 33 C0 4C 8B 11 41 FF 92 ?? ?? ?? ?? 48 85 FF
```

It is unique on 1.1.1 / 1.2 / 1.2.1 / 1.2.2 and **matches nothing from 1.4 onward**. The PGO
build reordered the call setup and split the vtable load into two instructions, so the byte
sequence no longer exists. The replacement for 1.4/1.5:

```
48 8B 0D ?? ?? ?? ?? 45 33 C9 45 33 C0 48 8B 11 4C 8B 92 ?? ?? ?? ?? 48 8D 15 ?? ?? ?? ?? 41 FF D2 48 85 FF
```

Unique on all three 1.4/1.5 builds, absent from all four older ones. The two together cover
every build tested — scan for both and take whichever hits. In both, `gEnv->pConsole` is the
disp32 of the leading `48 8B 0D`, resolved RIP-relative.

The tool doesn't rely on either signature to find `gEnv`; it decodes backwards from the string
xref, which survives reordering. The signatures are only reported so you know which one to ship
in a plugin that has to scan at runtime.

---

## The vtable offsets, re-validated

The guide's offset table was verified on V1.2.2 and warns it must be re-checked. `validate`
does that by finding every virtual call the game makes through each `gEnv` member and
histogramming the slots, then confirming the semantics from RTTI and string constants.

| Guide item | Slot | Status on `release_1_5` |
| --- | --- | --- |
| #1 `gEnv->pScriptSystem` = `+0x28` | — | confirmed, 756 refs |
| #2 `gEnv->pGame` = `+0x90` | — | confirmed, 434 refs |
| #3 `gEnv->pConsole` = `+0xA8` | — | confirmed, 2472 refs |
| #4 `IScriptSystem::CreateTable` | `0x68` | confirmed, called 22× |
| #5 `IScriptTable::SetValueAny` | `0x38` | in-bounds, not independently confirmed |
| #6 `IScriptTable::AddFunction` | `0xB0` | confirmed — the function references `"%s.%s(%s)"` |
| #7 `IGame::CompleteInit` | `0x20` | confirmed — references `"C_Game"`, called once |
| #8 `IGame::GetLongName` | `0x60` | confirmed — returns `"Kingdom Come: Deliverance II"` |
| #9 `IGame::GetName` | `0x68` | confirmed — returns `"KCD2"` |
| #10 `IGame::GetIGameFramework` | `0x80` | confirmed — 379 calls, by far the busiest slot |
| #11 `IGameFramework::RegisterListener` | `0x320` | in-bounds (`CCryAction` vtable has 143 slots) |
| #12 `IScriptSystem::ExecuteBuffer` | `0x30` | **the guide was right**: slot 6 is `lua_load` + `pcall` over a buffer; 5 is `ExecuteFile`, 7 is `UnloadScript` (see below) |

Every claim in the table still holds. Two things worth adding.

**The IGame vtable is at RVA `0x04095688`** (41 slots) on the current build. The guide doesn't
give it, and it can't be found the usual way: KCD2 ships RTTI for only ~1731 classes and the
`IGame` implementation isn't one of them — there is no `.?AVCGame@@` type descriptor. The way in
is `GetName`: find the `lea rax, [rip+"KCD2"]; ret` stub and look for a `.rdata` pointer to it.
Index 12 next to it returns `"Kingdom Come: Deliverance II"`, which pins `GetLongName` and
`GetName` beyond argument. `find_igame_vtable()` in the tool does exactly this.

**Item #12: the guide's ordinal was right and its reasoning was wrong — and so was this doc's
first reading of it.** The string `"[Lua Error] Failed to execute file %s: %s"` sits in slot 6
(`0x30`), and that slot is **`ExecuteBuffer`**, not `ExecuteFile`: its body is `lua_load` with a
reader over `(buffer, size)` followed by `pcall`, and the `%s` is the chunk *description* — Warhorse
just worded the message as "file". The real layout, read from the bodies:

| slot | offset | function | how it was pinned |
| --- | --- | --- | --- |
| 5 | `0x28` | `ExecuteFile(name, bRaiseError, bForceReload, pEnv)` | normalises a path, `tolower`s it, looks it up in the loaded-script set at `this+0x60` |
| 6 | `0x30` | `ExecuteBuffer(buf, size, desc, pEnv)` | `lua_load` over `(rdx, r8)`, `pcall`, the error string above with `desc` |
| 7 | `0x38` | `UnloadScript(name)` | finds the name in the same set and erases it |

The plugin in `native/mercnav/` was first built against `0x38` on the strength of the earlier
paragraph, and every Lua write it made silently unloaded a script that did not exist. The
histogram cannot catch this: `ExecuteBuffer` shows "no direct gEnv call site" because the game
caches the `IScriptSystem` pointer rather than re-reading `gEnv` at each call. Absence there
means unverified, not wrong — and "verified by adjacency" is not verified.

---

## Useful vtable addresses on `release_1_5_1308617_856`

Located via MSVC RTTI (`.?AV<class>@@` type descriptor → complete object locator → vftable).
Re-derive these after any patch; they are listed to save the lookup, not to be pasted into code.

| Class | vftable RVA | Slots |
| --- | --- | --- |
| `CScriptSystem` | `0x03B8C610` | 69 |
| `CScriptTable` | `0x03A4A700` | 25 |
| `CXConsole` | `0x03DCF850` | 76 |
| `CCryAction` | `0x040472D0` | 143 |
| `IGame` (no RTTI, found via `GetName`) | `0x04095688` | 41 |

---

## The corpus: the whole binary, queryable

Finding `gEnv` answers one question. The rest of the engine — 291,812 functions across 58 MB
of code — is too big to hand to an agent as text (a full listing is ~2 GB), so instead
`tools/disasm_build.py` decodes every function once and stores the *facts* in SQLite, and
`tools/disasm_query.py` answers questions against it. The corpus lives **outside the repo** at
`E:\kcd2_disasm\` (`whgame.sqlite`, `manifest.json`, `AGENTS.md`) — set `KCD2_DISASM_DIR` to
move it. It is never committed: it is derived from the game binary and it is 245 MB.

```bash
python tools/disasm_build.py            # ~30 s; only needed after a game patch
python tools/disasm_query.py fn gEnv->pConsole
python tools/disasm_listing.py          # ~30 s; rewrites listing/ to match
```

### Where the disassembled code actually is

The database holds *facts*, not instructions — `disasm_query.py dis <fn>` disassembles one
function on demand. When you want the code itself on disk, `tools/disasm_listing.py` renders
all 291,812 functions to `E:\kcd2_disasm\listing\`: **15.8 M lines, 990 MB, 59 shards** of 1 MB
of code each, annotated exactly like `dis` (strings, call targets, symbols, vtable slots inline),
plus `INDEX.tsv` mapping every function to its shard and line so you can `sed` straight to it
instead of scanning a 17 MB file. Use `dis` when you know the function; use the listing to grep
the whole binary for an instruction pattern, or to diff two builds.

Names added with `disasm_query.py name` survive a rebuild of the same binary. If the DLL has
changed they are dumped to `symbols_<oldbuild>.json` and deliberately **not** carried over — the
RVAs they are keyed on no longer mean anything. Regenerate the listing after any rebuild, or it
will quietly disagree with the database.

`E:\kcd2_disasm\AGENTS.md` is the guide written for whichever agent is asked to analyse the
engine next: every command, what the recovered names mean, verified anchors, recipes and the
limits. Read that before pointing an agent at the DLL; the summary here is what is in it and
how it was recovered.

| Table | Rows | Where it comes from |
| --- | --- | --- |
| `functions` | 291,812 | `.pdata` `RUNTIME_FUNCTION` entries (94.8 % of `.text`); chained unwind fragments resolved to their primary |
| `xrefs` | 2.0 M | every RIP-relative operand and direct call, decoded per function from its own boundary — no byte-pattern scanning, so no false positives |
| `calls` | 815 k | direct `E8`/`E9` edges between known functions. **Virtual calls are absent** |
| `strings` | 136 k | NUL-terminated printable runs in `.rdata`/`.data` |
| `rtti` / `vtable_slots` | 25,953 / 360 k | MSVC RTTI: type descriptor → complete object locator → vftable. Names 61,574 functions as `Class::vfN`; `IGame` injected by hand since it ships no RTTI |
| `binds` | ~1,400 | Lua-style `"Name" → function` registrations recovered from the registration code (below) |
| `cvars` | 5,321 | strings shaped like a cvar that code references |
| `symbols` | 15 + | verified names: `gEnv` and its members, the vtable slots this doc confirms. The one table agents write to (`name`) |
| `imports` | 1,103 | IAT |

### How the Lua API was recovered

Three registration paths coexist, and none of them is a single function you could list the
callers of:

* CryEngine's `SCRIPT_REG_*` macros: `lea r8,[impl]` → functor-building call → `lea rdx,[name]`
  → `call CScriptableBase::RegisterFunction` (17 registrars, ~500 names).
* Warhorse's own template registrars: `lea rax,[impl]` → `lea rdx,[name]` → `call <helper>`,
  where the helper is a fresh template instantiation per signature (`Game.*`, `ItemManager.*`,
  `Soul.*` …).
* Per-entity method tables with no global name.

What they share is *shape*: a string in `rdx`, a function pointer in some register, then a
call. The extractor walks every function that references ≥ 3 identifier-like strings and ≥ 3
function pointers, pairs a name with the nearest function pointer within 96 bytes at each
call, and keeps functions that yield ≥ 3 pairs. The **table name** (`System`, `Entity`) is the
string handed to the callee that every registrar calls *exactly once* — that is what
separates `SetGlobalName("System")` from `SetGlobalValue("SCANDIR_ALL", n)`, which the same
registrar calls three times. Where no such callee exists the table is NULL and the pairs are
still right; `Game.SaveGameViaResting`, `ItemManager.GetItemUIName` and `Soul.IsInCombatDanger`
all resolve to their C++ implementation.

---

## Caveats

* **This is static analysis only.** Nothing here was tested against a running game. The
  addresses are consistent with the binary and with each other; that is not the same as having
  read a live pointer.
* `slots=N` is measured by walking the vtable until a pointer stops landing in an executable
  section. It's a lower bound that happens to be exact when the next `.rdata` word is data.
* The dev build under `KCD2Mod/Bin/Win64ReleaseSteamLTO_DLL/` is a different, much smaller DLL
  and is not what the retail game loads — see [Dev build logging](performance.md) before drawing
  any conclusion from it.
* Whether an ASI plugin is worth building at all is a separate question this doesn't answer.
