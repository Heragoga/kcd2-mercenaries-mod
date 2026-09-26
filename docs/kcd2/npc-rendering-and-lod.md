---
title: NPC rendering, LOD and invisible NPCs
summary: Why KCD2 NPCs pop in and out or go invisible while still fighting (AI LOD tiers, renderer view distance, clothing assembly, quest and battle mechanics, content errors), how to diagnose each, and what a mod can do.
tags: [ai, engine, combat]
kind: reference
status: current
scope: kcd2
verified: release_1_5
---

# NPC rendering, LOD and invisible NPCs

The results of about 44 test sessions (npc-lod, 2,700 lines of run log) plus the
Malešov experiments (malesov-structure, malesov-test,
merc-battle-rendering, quest-override-test,
quest-override-battles). Those logs stay as history; this page is
the result.

> **TL;DR**
> - Several **independent** systems decide whether an NPC is drawn and how well it is simulated: AI LOD tiers (simulation), renderer view distance and mesh LOD, the clothing-assembly scheduler, the combat/battle system's own LOD, and quest/dialogue hides. Fixing one says nothing about the others.
> - **Invisible but still fighting in a scripted main-quest battle** = the NPC is not a combat participant, because nothing in the battle targets it (faction relations are one-directional). It drops to MonsterLOD. No cvar fixes this. The only proven way to render it makes the battle attack it.
> - **Popping in and out at distance when there are many NPCs** = the AI Detail budget is a **count** (`WH_AI_LOD_MaxCountDetail`, 70 in busy areas). Raise it temporarily and re-assert it, because CVarOverride contexts re-apply their values.
> - Diagnose with the engine's own debug draws (`WH_AI_LOD_DebugDraw_Who`, `wh_cs_DebugDrawLods`, `wh_cs_BattleDebugDraw`), not with Lua `IsHidden`/`IsActive` probes.
> - Many "invisible NPC" reports are content errors: DLC-only heads, a bad `body_type`, a sheathed polearm, an empty weapon set.

## Symptom → cause

| Symptom | Likely cause | Section |
| --- | --- | --- |
| Invisible, still dealing damage, only in scripted main-quest battles | not a combat participant → MonsterLOD | [scripted battles](#scripted-battles-the-invisible-fighter) |
| Pops in/out or moves in jumps at distance, only with many NPCs | AI Detail/LOD count budget oversubscribed | [AI LOD tiers](#ai-lod-tiers), [crowd budget](#crowd-budget-recipe) |
| Visible but T-posed and "slideshow" teleporting | LOD-tier NPC force-unhidden (`Hide(0)` without animation/activation) | [AI LOD tiers](#ai-lod-tiers) |
| Low-poly "clay puppets" up close | `SetLodRatio` high on a character (uberlod swap) | [renderer](#renderer-view-distance-and-mesh-lod) |
| Culled at modest distance | `ViewDistRatio` too low (or set to 0 by accident) | [renderer](#renderer-view-distance-and-mesh-lod) |
| Nearby NPCs vanish during a conversation | `CreateDialogParams HideNearbyNPCs` defaults to true | [quest hides](#quest-and-dialogue-hides) |
| Never renders, from spawn, anywhere | content error | [content](#content-that-renders-nothing) |
| "30% of the battle just stands there", visible | empty weapon set, not LOD | [content](#content-that-renders-nothing) |

## AI LOD tiers

AI LOD decides how fully an NPC is **simulated**. It is independent of whether the renderer draws
it (verified in game: raising the Detail budget changed nothing visually).

| Tier | Simulation | Movement |
| --- | --- | --- |
| Detail | full | animated |
| LOD | reduced | fake jumps every `wh_ai_Lod_MoveIntervalLOD` s |
| MonsterLOD (ML) | coarse, virtual; hidden via an aspect-profile swap; skeleton not evaluated | "estimated location" teleports (`wh_am_LOD_LocatorPeriodicalUpdate`) |

(cvar help strings from the retail DLLs, npc-lod)

- **Budgets are counts as well as distances.** Measured live values: `WH_AI_LOD_MaxCountDetail`
  70, `WH_AI_LOD_MaxCountLOD` 400, `WH_AI_LOD_MaxDetailDistance` 120..150, `WH_AI_LOD_MaxNonMLDistance`
  600, `WH_AI_LOD_Areas` 2 (filtered by visibility areas). `performanceDemandingArea.cfg` clamps
  Detail to 70 / 150 m. Over budget, losers are chosen by distance with hysteresis, which looks like
  popping in and out.
- **Most of the world lives in ML.** The on-screen stats read `666 Forced to ML` vs `32 Forced from
  ML` (≈ the quest roster), and `2236 MonsterLOD / 32 LOD / 10 Detail` (verified in game, run 35).
  Quest behaviours wake their own NPCs. Engine warning: `Too many MonsterLOD wakeups! Script logic
  issue` (`WH_AI_LOD_MaxCountLODUnstealableByMLWakeUp`).
- **ML switching is scheduler-driven.** An NPC without a Scheduler subbrain is never switched to ML
  (engine string, see [brains](ai-brains-and-npcs.md#brains-and-subbrains)).
- **`PreventsMonsterLod="true"`** on a `SmartBehaviorTemplate` blocks only ML while that behaviour
  runs. It does **not** stop Detail→LOD demotion. Siblings: `HibernateInMonsterLod`, `SkipMLODMove`,
  `PostponeByPlayerInMonsterLod`, used by the "additive NPC" background crowds that sleep in ML and
  wake in waves (vanilla: `Libs/Tables/ai/smartEntity/SmartEntity__so_additiveNPCs.xml`).
- **Reading the tier in a tree:** `$__bodyInfo.isMonsterLod`; `DetailBehaviorBarrier` runs a child
  only while in Detail (a gate, it never promotes).
- **The hide is a tracked engine state that is re-applied** (`C_NPC::RequestHideByLOD`,
  `SwitchAIHide`, `SynchronizeAspectProfile`). A Lua watchdog calling `Hide(0)` even every ~16 ms
  only tied it, producing a strobe (retail binary + verified in game, runs 11 and 29). Run 29
  attributed the per-frame re-hide to `wh_ai_NPCHidePPU` ("executed in actor pre physics update"),
  but run 30 read that cvar as already 0, so the exact re-apply path is `(unverified)`.
- **Two halves:** [`Entity.IsHidden`](api/Entity.md#ishidden) (render) and
  [`Entity.IsActive`](api/Entity.md#isactive) (per-frame update). `Hide(0)` without
  [`Activate(1)`](api/Entity.md#activate) gives a visible bind-pose NPC. `IsActive()==false` does
  **not** mean the AI stopped: combat runs on its own scheduler.
- `wh_ai_LOD_Hide` is not registered at runtime (`GetCVar` → nil); `wh_ai_NPCHideCheck` 1→0 took
  but did not help (verified in game, run 30).
- Scheduler priority buys AI budget; the context `npcSchedulerPriorityBoostPrevention` opts out
  (vanilla: `Libs/Tables/ai/ScriptContext.xml`). Using this to favour an NPC is `(unverified)`.

## Renderer: view distance and mesh LOD

| Knob | Effect | Trap |
| --- | --- | --- |
| [`Entity.SetViewDistRatio`](api/Entity.md#setviewdistratio) (0..254) / [`SetViewDistUnlimited`](api/Entity.md#setviewdistunlimited) | draw distance, scaled by global `e_ViewDistRatio` | Calling `SetViewDistRatio(254)` then `SetViewDistRatio(0)` culls as hard as possible; this bug sat in the mod for months |
| [`Entity.SetLodRatio`](api/Entity.md#setlodratio) | mesh LOD selection | Right for static props (255). On a **character** it triggers the early swap to the merged low-poly "uberlod" outfit, giving puppets at arm's length |
| `wh_cc_LodForUberlod` | LOD index where the uberlod starts | `-1` **disables** the swap and can draw both versions at once |
| `wh_cc_UberlodLoadDistRatio` | ratio of max view distance at which outfits load | a lower view distance also shrinks where clothing loads |
| `e_ViewDistRatio`, `e_LodFaceAreaTargetSizeCharacterWH` | global; lowered by `Battle.cfg` and similar | re-applied on every context change |
| `wh_item_ViewDistRatio` | spawned items and weapons on characters | weapons can vanish separately from bodies |

- Set mesh LOD **once** to a fixed value, or leave it to the engine. Tracking a live crowd count
  re-triggers LOD selection on every change and brings back popping (verified in game).
- Re-apply view-distance pins on a slow tick; anything that rebuilds the entity drops them.
- For CPU cost, simulation (cloth/pendulum) dominates, not draw distance: `ca_ClothBypassSimulation`
  and `wh_ca_PendulumMaxLodToSimulate` (performance).

## Clothing assembly pipeline

Characters are assembled at runtime from body and clothing skins by a budgeted job scheduler
(`wh_cc_TotalUpdateBudget` 10, `wh_cc_MaxSkinLoaderJobs` 1, measured). Trap mechanism
(retail binary, cvar help):

- `wh_actor_DissolveTimeout` = **-1**: an actor can stay invisible **forever** waiting for its
  attachments.
- `wh_cc_HiddenInvisibleManagerPriorityDecrease` = 100: a hidden actor's clothing jobs are
  de-prioritised, so in a saturated scene it may never catch up.

This was ruled out as the cause of the battle bug (forcing priority 0 and widening budgets changed
nothing, run 3), but it is real. Re-dressing every NPC on each load floods the one job slot while
the level streams in; pick outfits deterministically from a stable id and dress only new NPCs.
[`IsSlotCharacter(0)`](api/Entity.md#isslotcharacter) true says nothing about whether skins are bound.

## Combat-system LOD and scripted battles

The combat module has its **own** LOD, separate from AI LOD:

- `wh_cs_ForceLod` (0 high, 1 med, 2 low). The Game context `ForceCombatSystemAmbientLOD` forces
  ambient LOD globally. It is part of the preset `crime_global_battleInProgress`
  (`Libs/Tables/ai/ScriptContextPreset.xml`: `Battle`, `NoDog`, eight `crime_global_*`
  suppressors, `ForceCombatSystemAmbientLOD`). That preset is set by `SetGameContextPreset` in
  exactly the **12 scripted main-quest battles**: utokNaMalesov, utokNaNebakov, oblehaniSuchdole,
  nebakovObrana, zoufalaObranaZaBohutu, pogrom, finale, prepadeniVlasskehoDvora, rutinaAVypad,
  setkaniVRatbori2, posledniPomazani, hladAZmar (quest-override-battles).
- A `<Quest>` with **no `Type` attribute** is a main-story quest (vs `Activity`/`Side`/`Micro`...).
  0 of 67 Activity quests use the battle preset.
- **Battle groups** hold full NPCs plus "lite souls" under an actor limit
  (`Battle groups NPC: %d, Lite: %d ...`). Rosters come from level-baked `battleGroupController`
  smart entities, which a runtime spawn can never join. `RequestBattleNPC` is controllers pulling
  from the pool, not enrolment.
- `wh_cs_BattleMaximumNPC`: npc-lod reads it as "maximum full and alive NPC on the
  battle field" and pinned it at 120 with no effect. combat-movement
  says its default is 2 and it belongs to the scripted-battle `C_BattleManager`. Either way it is not
  the lever.
- A soul-combat simulator exists (`wh_rpg_SoulCombatSimulator*`), but its debug draw showed nothing
  in the battle (run 33). Its role is `(unverified)`.
- Log lines `Removing skirmish soul X` / `Soul X disconnection from npc` / `Connected to the soul`
  mark an NPC's **actor** being destroyed and rebuilt. A count far above vanilla's (77 vs 1..7) means
  something keeps tearing that NPC down.

## Scripted battles: the invisible fighter

**Symptom:** an NPC renders in the open world, but in a scripted main-quest battle it is invisible
(or T-posed and sliding) while still fighting and dealing damage.

**Cause (settled by bisect, run 43 and merc-battle-rendering):**
rendering follows **combat engagement**, and engagement requires something to be hostile **toward**
the NPC. Faction relations are one-directional. The mod's faction declared `-1` toward vanilla
enemies, but no vanilla faction names the mod's faction. Measured: vanilla battle NPCs targeted the
mod's NPCs **0** times, and the mod's NPCs targeted them **40** times. An NPC nobody fights gets no
combat actor, no combat-LOD entry (`wh_cs_DebugDrawLods` shows everyone else) and no battle group,
and falls to ambient/MonsterLOD. It is not a rendering or LOD bug; 30+ sessions tuned systems that
were working as designed.

| Injection of a test soul into Malešov `SoulAsset`s | Who attacks it | Renders |
| --- | --- | --- |
| all 137 lists (both armies) | player side + garrison | **yes**, fights for the garrison |
| garrison lists only (`--group enemy`) | player side | **yes**, attacks the player |
| ally lists only (64) | nobody | no |
| 6 named companions (`EnableBehavior` targets) | nobody | no |
| zero-AI "isolation" NPC in garrison arrays | attackable, never fights back | no |
| normal hired NPC | nobody | no |

(verified in game: merc-battle-rendering, malesov-structure)

How a battle makes targets: Skald `AddFactionRelationBetweenArrays RelationValue="-1"` (6 in
Malešov) makes `SoulArray0` hostile toward `SoulArray1`. Only membership in `SoulArray1` gets you
attacked. `SetRelationContext combat_forcedTarget` is also one-way (named heroes → garrison).
Nothing in the 339-file quest hides anyone. `HideActorCommand`/`ShowActorCommand` compose dialogue
scenes by VO role.

Enrolment channels (malesov-structure):

| Channel | Keyed by | Reachable from a mod |
| --- | --- | --- |
| Soul membership in `SoulAsset` lists | soul GUID ↔ `guidSharedSoulId` | yes (by overriding the quest files) |
| Battle groups | level-baked `SmartObjectHolder` + `linktag="battleEntity"` | no |
| Level layers | `AssetProfiles` / `ProfileAsset` | no |

**Conflict, resolved by precedence.** quest-override-test and
quest-override-battles conclude "SoulAsset membership is the render
gate", and the latter ships a `noHostile` injection into all 12 battles. The later bisect
(`merc-battle-rendering`, `malesov-structure`) shows membership renders only where it makes the NPC a
**target**. Ally-side membership renders nothing, and the `noHostile` scope excludes exactly the
behaviour-forcing assets. The npc-lod run-43 fix (move souls to
`players_friends`) was later measured to do nothing.

**Options for a mod, best first:**

1. **Move the company out of the battle.** Stash NPCs 400 m away and bring them back afterwards.
   This works reliably (malesov-test). Automatic detection is the hard part:
   - `HasScriptContext` cannot see the CVarOverride game contexts (`Battle`, `utokNaMalesov_battle`)
     even while their `.cfg` loads.
   - `IsQuestStarted` never matched a running quest; there is no `QuestSystem` global in mod Lua.
   - The battle cvar footprint (`wh_e_HLodClusterSwitchingDistanceMin` 25→40,
     `e_MergedMeshesInstanceDist` 1→2, `e_MergedMeshesViewDistRatio` 15→20..22 at `sys_spec` 1) is
     detectable, but anything can push those cvars, so it was withdrawn.
   - `kcd.log` does show `Loading config file 'Config/CVarOverrides/utokNaMalesov_battle.cfg'`.
2. **Accept hostility.** Inject the soul into garrison `SoulAsset`s. It renders and attacks the
   player; pair it with damage immunity. This means shipping full-file quest overrides, which are
   version-pinned: every game patch to those quests is silently reverted.
3. **Untested:** inject into `towerAttackers` in the tower fight (`boj_ve_vezi_optional`), the one
   relation that points garrison → player side. Also untested: whether hand-written Skald nodes work
   at all. Two new `AddFactionRelationBetweenArrays` nodes loaded without error and did nothing,
   while data edits to existing lists always took effect.

**Ruled out** (each measured, do not retry): ~40 AI-LOD, skirmish and battle cvars, pinned budgets
(Detail 400, LOD 1200, non-ML 2000), `wh_cs_ForceLod=0`, `ca_ForceUpdateSkeletons`, clothing
budgets, entity flags, deterrent areas, dialogue twins, the battle render cvars (applied in open
play, NPCs stayed visible), quest `Type` change, a permanent `Battle` context (which **kills all
dialogue**), a `QuestVisual` node (which **kills the whole mod quest graph**), `deterrenceImmunity`,
and `players_friends` faction membership.

## Quest and dialogue hides

- `CreateDialogParams` port `HideNearbyNPCs` defaults to **true**. Vanilla sets it false 101 times,
  case by case (vanilla: `references/Libs/concept/definitions.xml`).
- Skald `HideActorCommand`/`ShowActorCommand` hide by dialogue role.
- Level-layer streaming (`ProfileAsset` + `Layer`) spawns and removes quest NPCs wholesale.
- Quest `SoulAsset` lists are **logical bindings** for other nodes, not a render whitelist. None of
  559 soul-taking Skald node types forces render.
- Skald module `HibernateMode` (`Script`/`EventPlace`/`DLC`/`ActivityType`/`Auto`) is quest-**graph**
  dormancy. It is unrelated to NPC `HibernateInMonsterLod`.

## Content that renders nothing

| Cause | Symptom | Source |
| --- | --- | --- |
| DLC-only head (e.g. `m_head_painter`, `m_head_zachary`) without the DLC | spawns and runs AI, draws nothing | companions |
| `body_type` copied from a vanilla character, paired with its quest `unique_assets` | fully invisible, no error | companions |
| Polearm in a sheathed slot | looks unarmed until drawn | companions |
| Spawn `class` ≠ archetype | T-pose | spawning-npcs |
| Spawned under a roof / above the player indoors | "nothing spawned" | [world and physics](world-and-physics.md) |
| Empty weapon set | visible, stands idle in battle; log: `explicit DrawAction ... contains no weapons` | npc-lod |
| Female NPC in combat | visible, inert | [brains](ai-brains-and-npcs.md#body-types-and-female-npcs) |

## Crowd budget recipe

To keep a large fight fully simulated, as the mod's shipped LOD boost does
(npc-lod, top of the file):

1. Trigger on **headcount** (your NPCs plus nearby hostiles), not on "in combat". A big company with
   no enemies already oversubscribes the budget.
2. Save the **live** values when raising them (contexts load different overrides), and restore them
   after a hold-over once the crowd shrinks.
3. **Re-assert** every tick while boosted. `Libs/Tables/CVarOverride.xml` re-applies a context's
   `.cfg` (with priority) every time that context becomes active, so a one-off
   [`System.SetCVar`](api/System.md#setcvar) is undone (performance). If you
   run your own re-assert loop, route hand-applied experiments through it too, or it will stomp
   them (the `CvarOverride` table in malesov-test is the mod's own, not an
   engine feature).
4. Keep it moderate: 150 Detail was measurably better than 300. Every Detail slot is full AI.
5. Keep view distance and mesh LOD separate from the AI boost. AI budget alone did nothing visually
   while the renderer was still culling at `e_ViewDistRatio` 50.

Whether a mod can ship its own `Config/CVarOverrides/*.cfg` is `(unverified)`: the `.cfg` files live
in `Engine/Engine.pak`. `mod.cfg` is the supported place for persistent cvars
([mod structure](mod-structure.md)). The `WH_AI_*` cvars are not in
[data/cvars.tsv](data/README.md) (registered outside the scanned `WHGame.dll` registrars); read
them live with [`System.GetCVar`](api/System.md#getcvar).

## Diagnostics

| Tool | Shows |
| --- | --- |
| `WH_AI_LOD_DebugDraw_Who` + `WH_AI_LOD_DebugDraw_WhoType` | cone per NPC (green Detail, red LOD); flags 4 desired LOD, 8 consumed LOD, 32 ML constraints, 64 text summary (108 = all four). Desired ≠ consumed means denied for budget; `(Forced)MonsterLOD` means deliberately forced |
| `WH_AI_LOD_DebugDraw_Constraints` | behaviours with ML constraints |
| `wh_cs_DebugDrawLods` | combat-LOD entry per NPC; **absence** means not a combat actor |
| `wh_cs_BattleDebugDraw` | battle groups: NPC vs Lite counts |
| `wh_rpg_SkirmishDebugDraw`, `wh_rpg_DebugSouls` (+ string filter) | skirmish membership, per-soul state |
| `wh_cc_SchedulerDebug 2` | clothing job queue |
| `wh_am_LOD_Debug <names>` | animation LOD per entity |
| Lua `ent:IsHidden()`, `IsActive()`, `GetViewDistRatio()`, [`Action.IsGameObjectProbablyVisible`](api/Action.md#isgameobjectprobablyvisible) | quick probes; not authoritative |
| Bounding box ~1.29 × 0.38 × 1.88 m | bind pose (T-pose) fingerprint; a standing human is ~1.05 × 1.05 × 1.82 |

- Do **not** use `es_DebugEvents`: it logged every entity event and hung the game (run 34).
- `OnHidden`/`OnUnHidden` Lua hooks are never called on NPC entities.
- Test quest changes with the **dev build** (`KCD2Mod\kcd.log`), and check the log's timestamp; a
  stale log misled runs 33–40. See [debugging](debugging.md).
- One `Empty soul collection` error at load also appears for vanilla quests. It is a timing transient,
  not a dead node.

## Gotchas

- **NPCs invisible only in main-quest battles**: nothing in the battle targets them. Not fixable
  with LOD cvars.
- **Force-unhiding gives T-posed, teleporting NPCs**: that fights the per-frame LOD hide. `Hide(0)`
  alone is only the render half.
- **"View distance fix did nothing"**: check that no later call resets the ratio (`254` then `0`).
- **Characters look like clay up close**: `SetLodRatio(255)` on a character, or crowd-driven mesh
  LOD bands.
- **Budget boost undone within ~300 ms or on entering a town**: CVarOverride re-applied the context
  `.cfg`. Re-assert while active.
- **A permanent `Battle` game context disables all NPC dialogue.**
- **One `QuestVisual` (or other non-instantiable node) takes down the entire mod quest graph**, and
  only the dev build names it.
- **Raising `MaxCountDetail` to 300+ hurts framerate** more than it helps.
- **A stuck-looking NPC may be in the LOD tier**, not buggy: with over 70 NPCs around, it moves in
  jumps by design.
- **Reading one behaviour's heartbeat as "the AI is dead"** is wrong while another branch (combat)
  runs.

## See also

Research logs (history): npc-lod, malesov-structure,
malesov-test, merc-battle-rendering,
quest-override-test, quest-override-battles,
performance. Cvars: [console variables](console-variables.md).
