---
title: KCD2 Lua ScriptBind API reference
summary: Generated reference of every Lua ScriptBind function, cross-checked against the retail binary and the runtime Lua state dump.
tags: [lua, engine]
kind: reference
status: current
scope: kcd2
verified: release_1_5
---

# KCD2 Lua ScriptBind API reference

Generated on 2026-09-26 by `tools/gen_api_reference.py`. Rerun that script after a game patch
to refresh this directory; it is stdlib-only Python 3, no dependencies.

## Inputs and dates

| Input | Path (local) | Notes |
| --- | --- | --- |
| Official ScriptBind HTML docs | `references/script_bind_2025_01_14/` | Doxygen/Doc-O-Matic dump, 4963 files, dated 2025-01-14 |
| Retail binary corpus | `E:\kcd2_disasm\whgame.sqlite` | build `release_1_5_1308617_856`, 1382 bind registrations, 1336 distinct names |
| Runtime Lua state dump | `references/kcd2-mod-docs-main/lua_dump_state/LuaState_Sorted.txt` | 4816 table.function pairs, 1958 distinct names overall |
| Editor autocomplete list | `.../KCD2Mod/Editor/UI/LuaAutocompleteTokens.txt` | 1332 flat names (no table context); used only for corroboration, not a column here |
| Vanilla Lua usage | `references/kcd2-mod-docs-main/Scripts/` | 290 `.lua` files, extracted retail `Scripts.pak` |
| Mod's own Lua usage | `data/` | 1140 `.lua` files |

## What's in here

- `index.tsv` -- one row per function, machine-greppable. Columns: `table`, `function`, `cpp_class`,
  `signature`, `summary`, `in_docs`, `in_binary`, `in_runtime_dump`, `retail`, `vanilla_uses`,
  `mod_uses`, `vanilla_example`, `page`, `annotated`.
- `<Table>.md` -- one page per Lua-facing table (e.g. `AI.md`, `Entity.md`, `System.md`), alphabetical
  function list with signature, description, params, returns, remarks, a status line, and (where
  `tools/api_annotations.tsv` has one) a verified-note blockquote -- see "Verified annotations" below.
- [`undocumented.md`](undocumented.md) -- every function seen in the retail binary and/or runtime
  dump but missing from the official docs, grouped by table.
- [`unresolved-binds.md`](unresolved-binds.md) -- binary binds that couldn't be attached to *any*
  table at all (see below); `table` is `?` for these in index.tsv.

## Status line legend

Each function on a `<Table>.md` page ends with a line like:

```
docs: y · retail: confirmed (binary, runtime dump, vanilla×37 (e.g. `Scripts/...`))
```

- **docs** -- documented on an official `script_bind` HTML page.
- **retail** -- `confirmed` if *any* of the following turned up evidence the function actually exists
  in the retail game, listed in parentheses; `unconfirmed` if none did. This is **not** a claim the
  function was removed -- it means this generator found no trace of it in these particular,
  incomplete sources:
  - *binary* -- the exact Lua-visible name appears in `whgame.sqlite`'s `binds` table (built by
    `tools/disasm_build.py` from `WHGame.dll` build `release_1_5_1308617_856`). This is mostly a name-only match;
    the disassembly rarely recovers which C++ class registered a given name on its own (`tbl` is
    populated for only 377 of 1336 names, since
    registration happens through non-virtual `RegisterMethods` calls with no RTTI). The generator
    additionally groups binds by their registering C++ function and borrows the table from any other
    name registered by the *same* registrar that's already resolved -- see "Registrar-based
    resolution" below.
  - *runtime dump* -- the `table.function` pair (or bare name) appears in a retail Lua state dump
    taken from a running game. Carries real table context, so it's stronger evidence than the binary
    check alone.
  - *vanilla×N* / *mod×N* -- called N times in vanilla or mod Lua source (see below). Even
    one real call site is solid proof the function exists, so this alone is enough to confirm.
  - **binds/runtime coverage may be incomplete** -- treat `unconfirmed` as "no evidence found yet", not
    "doesn't exist". ~44% of documented functions currently come back unconfirmed, which given how
    small the binary's bind-name extraction is relative to the doc set is almost certainly a coverage
    gap, not 44% of the API having been removed.
- **vanilla / mod uses** -- how many times `Table.Function(` or `:Function(` appears in vanilla or mod
  Lua source. This is a text-pattern count, not an AST match: it can double-count a call site (dot form
  and colon form both match the same underlying binding), can miss calls made through an aliased
  variable, and -- because the colon form is receiver-type-blind -- can attribute the *same* count to
  several unrelated tables that happen to define a same-named method (e.g. a generic `OnReset`).
  Treat it as a rough popularity signal, not ground truth.

## Registrar-based resolution

Most binary binds have no `tbl` and register through an anonymous `sub_XXXXXX` function, but that
function still registers *every* method of one class in a single call. So the generator groups bind
names by their registering function and, whenever at least one name in a group is already resolved to
a table (from the docs or the runtime dump) and every resolved name in that group agrees on the same
table, propagates that table to the rest of the group. This resolved 5
additional names this run (16 registrar groups had names resolving to more
than one table and were left alone rather than guessed). Names that still can't be attached to any
table end up in `unresolved-binds.md` with `table` = `?` -- many of those read like entity
property/schema field names (`ConeAngle`, `Damping`, `Gravity`, ...) rather than callable functions,
i.e. likely a different kind of binary registration entirely, not a missed ScriptBind function.

## Verified annotations

Hand-verified corrections and notes -- the kind of thing found by actually calling a function in
game, or by reading vanilla/mod Lua that contradicts the official docs -- live in
`tools/api_annotations.tsv` (columns: `table`, `function`, `kind`, `text`, `source`) instead of
being hand-edited into a generated page, so they survive the next regeneration. `kind` is one of:

- `correction` -- the documented behaviour is wrong or misleading.
- `note` -- a fact worth knowing that isn't a correction (e.g. a persistence detail).
- `signature` -- the documented Lua signature doesn't match retail. Rendered as a `**Retail:**`
  line *above* the documented ```` ```lua ```` signature block, so both are visible.
- `warning` -- the function exists but is inert, unreliable, or dangerous to rely on.

Every row renders on its function's section as `> **Verified note:** <text> -- <source>`. A row
whose `function` doesn't correspond to any real bind/doc entry for that `table` (e.g. a name from
an old guide that turned out not to exist at all) still renders, under a
"Verified corrections (not a real function here)" heading at the bottom of that table's page,
rather than being silently dropped. `index.tsv`'s `annotated` column is `y` for any function with
at least one row here. Regenerating with a missing or malformed `tools/api_annotations.tsv` is not
fatal -- problems are printed as warnings and the run continues with whatever parsed.

## Tables

- [AI](AI.md) -- 305 functions, +11 undocumented
- [AI2](AI2.md) -- 1 functions
- [Action](Action.md) -- 56 functions, +1 undocumented
- [ActionMapManager](ActionMapManager.md) -- 13 functions
- [Actor](Actor.md) -- 149 functions, +2 undocumented
- [ActorSystem](ActorSystem.md) -- 3 functions
- [Alchemy](Alchemy.md) -- 10 functions, +1 undocumented
- [AlchemyTable](AlchemyTable.md) -- 3 functions, +17 undocumented
- [AnimDoor](AnimDoor.md) -- 9 functions, +53 undocumented
- [Backgammon](Backgammon.md) -- 7 functions
- [BindingTool](BindingTool.md) -- 2 functions
- [Blacksmithing](Blacksmithing.md) -- 2 functions
- [Boids](Boids.md) -- 9 functions
- [Building](Building.md) -- 5 functions
- [C_PlayerStateHandlerScriptBind](C_PlayerStateHandlerScriptBind.md) -- 7 functions
- [Calendar](Calendar.md) -- 14 functions
- [CarryItemPile](CarryItemPile.md) -- 5 functions, +3 undocumented
- [CarryableItem](CarryableItem.md) -- 4 functions, +12 undocumented
- [Cart](Cart.md) -- 2 functions, +2 undocumented
- [Database](Database.md) -- 5 functions
- [Dialog](Dialog.md) -- 2 functions
- [DialogModule](DialogModule.md) -- 12 functions
- [DialogSystem](DialogSystem.md) -- 2 functions
- [Dice](Dice.md) -- 9 functions
- [Dog](Dog.md) -- 4 functions, +50 undocumented
- [Editor](Editor.md) -- 4 functions
- [Entity](Entity.md) -- 307 functions, +6 undocumented
- [EntityModule](EntityModule.md) -- 21 functions, +1 undocumented
- [Environment](Environment.md) -- 4 functions
- [EnvironmentModule](EnvironmentModule.md) -- 5 functions, +2 undocumented
- [Experimental](Experimental.md) -- 6 functions
- [FSM](FSM.md) -- 27 functions
- [Framework](Framework.md) -- 6 functions
- [Game](Game.md) -- 57 functions, +1 undocumented
- [GameCodeCoverage](GameCodeCoverage.md) -- 8 functions
- [GameRules](GameRules.md) -- 135 functions
- [GameStatistics](GameStatistics.md) -- 10 functions
- [GameToken](GameToken.md) -- 5 functions
- [Group](Group.md) -- 4 functions
- [HitDeathReactions](HitDeathReactions.md) -- 9 functions
- [HoleDigging](HoleDigging.md) -- 1 functions
- [Horse](Horse.md) -- 6 functions, +47 undocumented
- [Human](Human.md) -- 87 functions
- [IKInteractions](IKInteractions.md) -- 3 functions
- [InteractionPoint](InteractionPoint.md) -- 6 functions
- [InteractionTrigger](InteractionTrigger.md) -- 9 functions, +36 undocumented
- [InteractiveObject](InteractiveObject.md) -- 8 functions
- [Inventory](Inventory.md) -- 49 functions
- [Item](Item.md) -- 32 functions
- [ItemManager](ItemManager.md) -- 11 functions
- [ItemSystem](ItemSystem.md) -- 11 functions
- [LockBase](LockBase.md) -- 2 functions
- [MaterialEffects](MaterialEffects.md) -- 2 functions, +4 undocumented
- [Minigame](Minigame.md) -- 13 functions, +2 undocumented
- [Movie](Movie.md) -- 9 functions
- [MusicLogic](MusicLogic.md) -- 5 functions
- [Network](Network.md) -- 4 functions
- [Particle](Particle.md) -- 11 functions
- [Physics](Physics.md) -- 7 functions
- [PickableItem](PickableItem.md) -- 39 functions
- [Player](Player.md) -- 51 functions, +28 undocumented
- [Quest](Quest.md) -- 1 functions
- [QuestSystem](QuestSystem.md) -- 37 functions
- [RPG](RPG.md) -- 34 functions, +1 undocumented
- [Script](Script.md) -- 12 functions
- [Sharpening](Sharpening.md) -- 14 functions
- [ShootingContest](ShootingContest.md) -- 8 functions
- [Shop](Shop.md) -- 22 functions
- [Shops](Shops.md) -- 4 functions, +11 undocumented
- [SkipTime](SkipTime.md) -- 2 functions, +1 undocumented
- [SmartObject](SmartObject.md) -- 7 functions, +5 undocumented
- [Soul](Soul.md) -- 94 functions
- [Sound](Sound.md) -- 74 functions
- [Stash](Stash.md) -- 6 functions
- [Statistics](Statistics.md) -- 2 functions, +3 undocumented
- [StoneThrowing](StoneThrowing.md) -- 2 functions
- [System](System.md) -- 130 functions, +5 undocumented
- [Trace](Trace.md) -- 7 functions, +8 undocumented
- [Tutorial](Tutorial.md) -- 6 functions
- [UI](UI.md) -- 4 functions, +2 undocumented
- [UIAction](UIAction.md) -- 38 functions
- [UberLodTool](UberLodTool.md) -- 1 functions
- [Variables](Variables.md) -- 11 functions
- [Vehicle](Vehicle.md) -- 60 functions
- [VehicleSeat](VehicleSeat.md) -- 15 functions
- [VehicleSystem](VehicleSystem.md) -- 9 functions
- [XGenAIModule](XGenAIModule.md) -- 45 functions, +3 undocumented
- [customer](customer.md) -- 1 functions
- [locpickable](locpickable.md) -- 4 functions

## Dedupe notes

The docs directory ships two (sometimes three) HTML spellings of several ScriptBind classes, e.g.
`CScriptBindAI.html` (older Doc-O-Matic render, has a clean `Syntax: AI.Foo(...)` line per method) and
`CScriptBind_AI.html` (newer/rawer render pulled closer to the `//!` source comments, more methods but
messier text). Functions are keyed by `(table, function)` derived primarily from that `Syntax:` /
`Table.Func(...)` line inside each method page's Description section (the actual thing a modder would
type), not from the file name. When the same `(table, function)` pair is documented on more than one
page, the page with the richer content (longer description, present Params/Returns/Remarks) wins; the
other variant's methods that don't overlap are still included (this is why, e.g., `AI` has more
documented methods than the old `CScriptBindAI.html` page alone would suggest).

## Regenerating

```
python tools/gen_api_reference.py
```

All input paths take `--flag` overrides; run with `--help` for the full list. Safe to rerun any time;
it only writes inside `--out-dir` (default `docs/kcd2/api/`).

## Caveats

- Binary bind coverage is one build's static analysis (`release_1_5_1308617_856`) and is known incomplete for
  registrar->class attribution (see status line legend above). A function marked `retail: unconfirmed`
  has simply not turned up in these particular sources yet -- do not describe it in KB prose as
  "removed" or "stripped"; say it's unconfirmed and why.
- The runtime Lua state dump reflects whatever was loaded when it was captured; it will not contain
  functions gated behind content that wasn't touched in that session.
- Vanilla/mod usage counts are regex-based text matches, not a real Lua parse; see legend above.
- Parameter tables in the official docs are occasionally malformed at the source (adjacent parameters'
  descriptions run together in one cell); this generator does not attempt to re-split them.
- `unresolved-binds.md` mixes genuinely unattributable ScriptBind functions with what look like
  CryEngine entity property/schema field names picked up by the same binary scan; skim before citing.
