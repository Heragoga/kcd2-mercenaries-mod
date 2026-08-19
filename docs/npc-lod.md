# NPC LOD, hiding, and invisible mercenaries

Research notes for the two long-standing bugs: **mercs popping in and out at distance when
there are many of them**, and **mercs going fully invisible (but still fighting) during
scripted main-quest battles**.

> ## Shipped: the renderer view-distance pin — and a retracted result
>
> **`EnsureMercIsAlwaysRendered` never did what its name said.** For most of this
> research it was, verbatim:
>
> ```lua
> ent:SetViewDistRatio(254)
> ent:SetViewDistRatio(0)
> ```
>
> Maximum, then **minimum** on the very next line. The function called at every merc
> spawn site was culling mercs as hard as the engine allows. It was later replaced by an
> explicit no-op on the grounds that "forcing RenderAlways caused more trouble than it
> solved" — a verdict drawn entirely from that broken body. **Retract it.** This doc's own
> note that "a genuinely clean retry with no follow-up zeroing has never been attempted"
> is the accurate statement.
>
> It now applies **`SetViewDistUnlimited()` + `SetViewDistRatio(255)`** — separate `pcall`s,
> since a method missing on the NPC class must not skip the others. No `RenderShadow`: fifty
> extra shadow casters is a real cost and shadows are not the symptom. Re-applied on the slow
> tick as well as at spawn, because anything that rebuilds an entity can drop it.
> `merc_render_pin 0|1` to A/B it.
>
> **`SetLodRatio` is deliberately NOT applied to mercs.** The wall code sets it to 255 and that
> is correct *for a wall*; on a character it is a different thing entirely, because KCD2
> assembles characters from clothing skins and swaps in a merged "uberlod" from a configurable
> LOD number. At 255 mercs were low-detail puppets at arm's length.
>
> Driving it from a crowd count was then tried — a ratio interpolated 100‥130 from
> (mercs + nearby hostiles), re-applied on the 5 s sweep — and it **brought back the popping
> in and out that the view-distance pin had just fixed**. Two causes, both of which apply to
> any variant of the idea: the crowd count moves constantly so the ratio moves with it, and
> every change makes every merc re-evaluate which mesh LOD to draw; and it was re-applied on a
> timer even when unchanged, giving the churn a floor. **Mesh LOD is left to the engine.** If
> it ever has to be cut for performance, use a *fixed* value set once (`merc_render_lod <n>`,
> `0` to hand it back) — never one that tracks a live count.
>
> **This is the renderer, not the AI tier.** The LOD budget below decides how much an NPC is
> *simulated*; this decides whether he is *drawn*. They are independent, which is why run 13
> ruling out the AI tier never ruled this out.
>
> ## Shipped: the crowd LOD budget boost (`mercenaries_lodboost.lua`)
>
> One thing from this research **is** in the mod, and it is not a fix for either bug above.
>
> The Detail/LOD/MonsterLOD split is a **budget** — `WH_AI_LOD_MaxCountDetail` is 70 — and an
> NPC that loses its Detail slot moves in fake jumps (`wh_ai_Lod_MoveIntervalLOD`) and is
> coarsely simulated. The mod can now field a squad, an enemy group, a wall battle and a
> roaming patrol at once, comfortably past 100 NPCs, so in a real fight that budget is
> oversubscribed and the losers are chosen by distance with hysteresis.
>
> `LodBoostTick` (from `CombatScanLoop`) raises the budget while the **crowd**
> (`MercCount + nearby hostiles`) is at least `LodBoostMinCrowd`, and puts it back
> `LodBoostHoldSecs` after it drops. It triggers on **headcount, not combat**: the first
> version fired only on ≥3 live hostiles, and a log with ~50 mercs and no enemies showed it
> never engaging — yet that is exactly the case that oversubscribes the budget, because the
> budget is a count and the mod's own mercs consume it.
> It **saves whatever is live when the fight starts** rather than a hardcoded stock table,
> because the game loads different overrides per context (`Battle.cfg`,
> `performanceDemandingArea.cfg`). Values are below the 300/400 the research bundle used —
> every Detail slot is full AI simulation, and the goal is to cover ~150 NPCs around a fight,
> not to disable the system. `merc_lod_boost 0|1` and `merc_lod_status` to control and inspect.
>
> ### Crowd-scaled mesh LOD (`LodRatioBands`) — softened
>
> The boost also pushes a **mesh** LOD ratio onto every mod NPC, banded by crowd size (higher
> ratio = detail drops sooner = cheaper). That is the affordable half of the trade that lets the
> AI Detail budget go to 260.
>
> The first ladder was far too aggressive for ordinary play: it started at crowd **30** and
> topped out at **300** — past the 255 this doc already records as *puppets at arm's length*.
> A fifty-man company hits crowd 50 on its own, so simply **hiring** a big squad turned the
> whole company into clay figures, and it never came back: the boost's own threshold is 8, so
> the crowd never falls back through the lower bands with a squad that size, and the band is
> only re-pushed when it **changes**. Reported as "the LOD is extreme when there are a lot of
> mercs", and correctly so.
>
> | Crowd | Was | Now |
> | --- | --- | --- |
> | 150+ (full siege) | 300 | 200 |
> | 100+ | 300 | 160 |
> | 70+ | 300 | 130 |
> | 50 | 300 | engine default |
> | 30–40 | 150–250 | engine default |
>
> The ladder now starts where a real battle does and stops below 255, so a company on the road
> draws at the engine's own mesh LOD.
>
> **`LodBoostOff` now hands mesh LOD back** (`LodRatioReset`). `LodRatioAutoApply` only runs
> from `LodBoostReassert`, i.e. while the boost is on, so nothing used to undo the last band —
> whatever ratio a fight settled on stayed on the squad for the rest of the session. Same for
> `merc_lod_auto 0`, which now takes effect immediately instead of only on the next band change.
>
> `merc_lod_auto 0` disables crowd-scaled mesh LOD outright; `merc_lod_lodratio <n>` sets one
> by hand to A/B it.

> `wh_ai_LOD_Hide` is deliberately **not** in the set: run 13 showed it is unreachable through
> `GetCVar`/`SetCVar` (`nil -> nil <-- DID NOT TAKE`).
>
> **Do not read this as a fix for merc invisibility.** Run 13 applied this exact tier and ruled
> it out: mercs standing at 3 m cannot be evicted from a 400 m / 300-slot Detail budget, and
> they were demoted anyway. This is only about keeping a big battle properly simulated.

There is no single "NPC LOD". KCD2 has **four** independent systems that can each make an
NPC stop rendering while it keeps existing and fighting. They are listed below with the
evidence for each, then applied to the two bugs.

> **Live lead (run 27): skirmish *passive-soul* add/remove churn.**
>
> Our mercs connect to a skirmish LOD state **77 times** in one session; every vanilla NPC connects
> 1–7 times. Souls are added to and removed from a skirmish **by distance**, as *passive*
> participants, and the thresholds are named cvars —
> `wh_rpg_SkirmishPassiveMinDistance` / `MaxDistance` (plus `…FromBattleManager` variants) and
> `wh_rpg_SkirmishSoulUpdateBudget` ("count of souls which will update per frame").
>
> Test: **`merc_lod_skirmish`** to widen the band, **`merc_lod_skdebug`** to watch the skirmish
> system's own debug draw on a merc.
>
> ---
>
> **Superseded (run 26/27): "we evict our own mercs via the follow interrupt."** Disproved —
>
> `wh_cs_DebugDrawLods` draws LOD info on every NPC in the battle **except our mercs** — they have
> no entry in the combat LOD manager at all. And in the entire dev log, `Removing skirmish soul`
> fires for **all ten mercs** and for exactly **two** vanilla NPCs, both of which had just died.
> Every living-soul eviction from a skirmish is one of ours.
>
> `merc_lod_noreissue` blocked the follow re-issue completely and **58 skirmish evictions still
> followed**. The scheduler churn is not what removes them.


>
> * **Run 1, stock cvars** — all 10 mercs `hidden=Y char=Y/Y vdr=100`. Force-unhiding them
>   produced **T-posing mercs snapping around**: animation off plus fake movement jumps, i.e.
>   the AI LOD state. `Hide()` is only the render half of a LOD demotion.
> * **Run 2, with the AI-LOD cvar set applied** — all 10 mercs now `hidden=n`, so the LOD hide
>   was genuinely gone, **and they were still invisible**, with no state change for the entire
>   battle. That is the §2 failure mode: actor present, unhidden, fighting, with **no clothing
>   attachments built**. `char=Y/Y` does *not* rule this out — see the caveat below.
>
> The Detail count budget is **not** involved: run 2's census found 1429 living NPCs in the
> level but only **35 within 120 m**, against `MaxCountDetail` = 200.
>
> See [Measured values](#measured-values-live-game) below.

> **`char=Y/Y` caveat.** `IsSlotCharacter(0)` / `GetCharacter(0)` only prove a character
> occupies slot 0. They say nothing about whether that character has any body/clothing skins
> bound to it. Ten invisible mercs read `char=Y/Y` in run 2. There is no Lua bind that counts
> attachments, so use `merc_lod_attach` (forces `HideAttachmentMaster` / `HideAllAttachments`
> off) to tell "skins exist but are hidden" from "skins were never built".

## Where the evidence lives

| Source | What it gives you |
| --- | --- |
| `Engine/Engine.pak` → `Config/CVarOverrides/*.cfg` | Per-game-context cvar overrides, incl. `Battle.cfg` and `utokNaMalesov_battle.cfg` |
| `Engine/Engine.pak` → `Config/CVarGroups/sys_spec_*.cfg` | Graphics-preset cvar tiers |
| `Libs/Tables/CVarOverride.xml` | Maps a **game context** → an override file |
| `Libs/Tables/ai/ScriptContext.xml` | Authoritative list of entity/game contexts and their C++ side effects |
| `Libs/Tables/ai/smartEntity/SmartEntity__*.xml` | Per-behaviour LOD flags |
| `Bin/Win64.../WHGame.dll` | Every cvar name **and its help string** (plain ASCII; dump with a strings script) |

Everything below that is quoted in `"..."` is the literal cvar help text out of `WHGame.dll`.

---

## 1. AI LOD — `WH_AI_LOD_*`

Three tiers, budgeted by **count** as well as distance:

* **Detail** — full simulation.
* **LOD** — reduced; movement becomes teleport steps (`wh_ai_Lod_MoveIntervalLOD`,
  *"Time between fake movement jumps in LOD (in seconds)"*).
* **MonsterLOD (ML)** — cheapest; behaviour is coarsely simulated
  (`wh_ai_Lod_MoveIntervalMonsterLOD`).

Key cvars:

| cvar | Help text |
| --- | --- |
| `WH_AI_LOD_MaxCountDetail` | "The maximal amount of NPCs in Detail." |
| `WH_AI_LOD_MaxCountLOD` | "The maximal amount of NPCs that are in LOD (NPCs in Detail don't count to this limit, their budget is separate)." |
| `WH_AI_LOD_MaxDetailDistance` | "Maximal distance at which npc is not yet switched from Detail to LOD..." |
| `WH_AI_LOD_HysteresisMultiplierDetail` / `...MonsterLOD` | Distance hysteresis on each switch |
| `WH_AI_LOD_Areas` | "0 - only distance is used for NPC LOD resolution, 1 - filtered by LOD areas, 2 - filtered by Visibility areas" |
| `wh_ai_LOD_Hide` | **"NPC Hide (Aspect Profile change) because of LOD will be executed in actor pre physics update."** |
| `wh_actor_MonsterLODSwitch` | "Budget for switching Actors to and from MonsterLOD (budget is shared)." |

Two things matter here:

1. **`wh_ai_LOD_Hide` proves the AI LOD system hides actors.** A hidden actor still exists,
   still has AI, still deals damage.
2. **The budget is a count, not just a distance.** `performanceDemandingArea.cfg` sets
   `WH_AI_LOD_MaxCountDetail=70` / `WH_AI_LOD_MaxDetailDistance=150`; the Xbox Series S tier
   sets `WH_AI_LOD_MaxCountLOD=300`. Add 20–30 mercs to a 100-NPC scripted battle and the
   Detail budget is oversubscribed — the losers are chosen by distance with hysteresis,
   which is exactly what "popping in and out" looks like.

### Control points we already use

`PreventsMonsterLod="true"` is an attribute on `<SmartBehaviorTemplate>` (465 uses in vanilla).
All six of our behaviours in
[SmartEntity__so_interrupt__mercenaries.xml](../data/libs/tables/ai/smartEntity/SmartEntity__so_interrupt__mercenaries.xml)
already carry it. Sibling attributes that exist in vanilla: `HibernateInMonsterLod`,
`SkipMLODMove`, `PostponeByPlayerInMonsterLod`.

**Note the gap:** `PreventsMonsterLod` blocks ML only. Nothing we ship prevents the
**Detail → LOD** demotion, and `wh_ai_LOD_Hide` is about *LOD*, not ML.

Readable from a behaviour tree: `$__bodyInfo.isMonsterLod` (vanilla uses it in
`AI/profession/camper/so_campBuffable.xml`, `AI/world/so_fireplace.xml`).

Related entity context: `npcSchedulerPriorityBoostPrevention` — *"NPC with this context won't
get AI budget boost due to scheduler priority of his current behavior"*, i.e. scheduler
priority normally **does** buy AI budget. Worth exploring as a way to bias mercs upward.

---

## 2. Character-clothing pipeline — `wh_cc_*` (disproved in run 3, kept for reference)

KCD2 characters are **assembled at runtime** from body/clothing skin attachments. That
assembly is a **budgeted, prioritised job scheduler**:

| cvar | Help text |
| --- | --- |
| `wh_cc_TotalUpdateBudget` | per-frame budget for the clothing update scheduler |
| `wh_cc_SchedulerBudgetPerLayer`, `wh_cc_SchedulerLayer0Count`, `wh_cc_SchedulerPostLoadBudgetPerLayer` | per-layer job budgets |
| `wh_cc_MaxSkinLoadingInProgress` | "maximum count of scheduled skin jobs. Limits the amount of temp memory allocated" |
| `wh_cc_MaxSkinLoaderJobs` / `wh_cc_MaxSkinLoaderJobQueueSize` | "maximum count of simultaneously running loader jobs" / "maximal count of queued jobs" |
| `wh_cc_HiddenInvisibleManagerPriorityDecrease` | **"how much is the priority decreased when the owner entity is hidden or invisible"** |
| `wh_cc_CutsceneManagerPriorityBoost` | "how much is the priority increased when the owner entity is in cutscene" |
| `wh_cc_LRUCache` | "ability to turn on/off LRU cache for clothing system" |
| `wh_cc_SchedulerDebug` | **"debug draw of the update scheduler, 1 - per layer debug, 2 - sorted jobs"** |

And the distance side (the Uberlod = merged single-mesh version of an outfit):

| cvar | Help text |
| --- | --- |
| `wh_cc_LodForUberlod` | "a LOD number from where we start showing the uberlod (-1 disables the feature)" |
| `wh_cc_UberlodLoadDistRatio` | **"ratio of max view distance where uberlods are loaded [%]"** |
| `wh_cc_UnloadHysteresisDist` | **"hysteresis distance for unloading uberlod and attachments [m]"** |
| `wh_r_UberlodRatio` / `wh_r_UberlodMode` | set in `system.cfg` (3 / 0) |

### The decisive string

`wh_actor_DissolveTimeout`:

> **"Maximal amount of time the actor is invisible waiting for attachments before dissolve
> starts. Negative value represents infinite timeout, 0 represents no waiting."**

and `wh_actor_Dissolve`: *"Enable dissolve of actor on unhide instead of pop-in."*

So the engine has a first-class state: **actor present, unhidden, alive, fighting — and
rendering nothing because its attachments have not been built yet.** That is a literal
description of the reported bug. If the timeout is negative (infinite) and the clothing
scheduler never gets round to this actor, it stays invisible indefinitely.

`wh_cc_HiddenInvisibleManagerPriorityDecrease` makes this self-reinforcing: once an actor is
hidden/invisible its clothing priority is *lowered*, so in a saturated battle it never
catches up.

---

## 3. Explicit hides from quest logic

* `CreateDialogParams` (Skald, `Libs/concept/definitions.xml`) has a port
  **`HideNearbyNPCs`, type bool, `DefaultValue="true"`**. Vanilla quests explicitly set it
  to `false` **101 times** — i.e. hiding nearby NPCs during a dialogue is the *default* and
  designers opt out case by case. Scripted battles are dense with dialogue/scene nodes.
* Skald also has `HideActorCommand` / `ShowActorCommand`.
* Level-layer streaming (`streamprofileshandling`, `ProfileAsset`) spawns/removes level
  NPCs wholesale — see `Quests/Final/Barbora/klaster/klaster_hibernate_mode/artefakt/streaming.xml`.

### On the "quest asset folder" lead

Quest `<Assets><SoulAsset .../></Assets>` entries are **logical bindings** (this quest node
acts on these souls), not render pins or precache lists — they do not turn other NPCs off.
The things that actually turn NPCs off during a quest are `HideNearbyNPCs`, layer streaming
profiles, and the cvar overrides below. Likewise `hibernovaná_část` in the quest tree is
**Skald module hibernation** (`wh::conceptmodule::E_HibernateMode`), i.e. quest logic going
to sleep, not NPC rendering.

---

## 4. Renderer-side view distance, and the per-battle cvar overrides

`Libs/Tables/CVarOverride.xml` maps game contexts to override files:

```
Battle                     → Battle.cfg                     (priority 3)
utokNaMalesov_battle       → utokNaMalesov_battle.cfg       (priority 4)
oblehaniSuchdole_Battle    → M48a_oblehaniSuchdole_Battle.cfg (priority 5)
performanceDemandingArea   → performanceDemandingArea.cfg   (priority 2)
kutnohorsko / klaster ...  → ...                            (priority 1)
```

`Battle.cfg` and `utokNaMalesov_battle.cfg` are near-identical and, at the default spec,
tighten:

```
e_ViewDistRatio = 80
e_LodFaceAreaTargetSizeCharacterWH = 0.00185     ; character LOD selection metric
e_ShadowsCastViewDistRatioLights = 0.04
```

`performanceDemandingArea.cfg` additionally clamps `WH_AI_LOD_MaxDetailDistance=150`,
`WH_AI_LOD_MaxCountDetail=70`, `e_ViewDistRatioCustom=80`.

An entity's max view distance is derived from its own `ViewDistRatio` (0–254) scaled by the
global `e_ViewDistRatio`. Because `wh_cc_UberlodLoadDistRatio` is *"ratio of max view
distance where uberlods are loaded"*, **shrinking an NPC's max view distance also shrinks
the range at which its clothing is loaded at all**. That couples §4 straight into §2.

Also relevant: `wh_item_ViewDistRatio` — *"ViewDistRatio used for spawned items and weapons
on characters"* (weapons vanishing separately from bodies).

Character render floors: `e_CharRenderLodMin` (*"Min LOD for character objects (used for
rendering)"*), `e_CharLodMin`, `ca_AttachmentCullingRation` (*"ration between size of
attachment and distance to camera"*; `system.cfg` raises it to 1000 with the comment
*"missing eyes fix"*).

---

## What we already tried, and why it can't have worked

`mercenaries:EnsureMercIsAlwaysRendered` (now a no-op in
[mercenaries_util.lua](../data/Scripts/mods/mercenaries_util.lua)) used to be:

```lua
ent:RenderAlways(1)
ent:SetViewDistRatio(254)
ent:SetViewDistRatio(0)   -- <-- immediately overwrites the line above
```

`SetViewDistRatio` is documented as *"0..254 (value is automatically clamped to this range)"*.
The second call sets the ratio to the **minimum**, i.e. it made the merc's view distance as
short as possible — the opposite of the intent, and (per the coupling above) it would also
have collapsed the distance at which its clothing loads. Any conclusion of the form "view
distance calls don't help" drawn from that experiment is void; the experiment was
sabotaged by its own last line.

---

## Diagnostics to run before changing anything

The point of these is to separate "**hidden**" from "**unhidden but skinless**" — different
systems, different fixes.

**Lua probe** (per merc, log once a second while the bug is visible):

```lua
ent:IsHidden()              -- 1 => something called Hide(): AI LOD or HideNearbyNPCs
ent:GetViewDistRatio()      -- what the entity actually ended up with
ent:IsSlotCharacter(0)      -- is there a character in the slot at all
Action.IsGameObjectProbablyVisible(ent.id)
```

If `IsHidden()` is 1 → §1 or §3. If it is 0 and the merc is still not drawn → §2 (attachments).

**Console** (values print when a cvar is typed with no argument):

```
wh_cc_SchedulerDebug 2
wh_actor_info 1
WH_AI_LOD_MaxCountDetail
WH_AI_LOD_MaxDetailDistance
wh_actor_DissolveTimeout
wh_cc_TotalUpdateBudget
wh_cc_MaxSkinLoaderJobs
e_ViewDistRatio
```

`wh_cc_SchedulerDebug 2` ("sorted jobs") should directly show whether merc clothing jobs are
queued behind the battle's NPCs.

---

## Measured values (live game)

Read with `merc_lod_cvars` inside the Maleshov battle, graphics spec 1, with
`kutnohorsko.cfg` + `utokNaMalesov_battle.cfg` + `Battle.cfg` all loaded:

| cvar | live value | note |
| --- | --- | --- |
| `WH_AI_LOD_Areas` | **2** | "filtered by **Visibility areas**" — mercs are spawned at runtime and may not belong to one |
| `WH_AI_LOD_MaxCountDetail` | 70 | |
| `WH_AI_LOD_MaxCountLOD` | 400 | |
| `WH_AI_LOD_MaxDetailDistance` | 120 | mercs were demoted at **2–3 m**, so raw distance is not the trigger |
| `WH_AI_LOD_HysteresisMultiplierDetail` | 0.8 | |
| `wh_actor_DissolveTimeout` | **-1** | infinite wait-for-attachments; a stuck merc would never recover |
| `wh_actor_Dissolve` | 1 | |
| `wh_ai_LOD_Hide` | *(nil)* | not readable through `System.GetCVar` |
| `wh_cc_TotalUpdateBudget` | 10 | |
| `wh_cc_MaxSkinLoaderJobs` | 1 | |
| `wh_cc_MaxSkinLoadingInProgress` | 40 | |
| `wh_cc_HiddenInvisibleManagerPriorityDecrease` | 100 | |
| `wh_cc_LodForUberlod` | 4 | |
| `wh_cc_UberlodLoadDistRatio` | 1.1 | a **ratio**, not a percentage, despite the `[%]` in the help text |
| `wh_cc_UnloadHysteresisDist` | 3 | |
| `e_ViewDistRatio` | 40 | `Battle.cfg` `[1]` — low spec |
| `e_LodFaceAreaTargetSizeCharacterWH` | 0.003 | `Battle.cfg` `[1]` |
| `ca_AttachmentCullingRation` | 1000 | as set in `system.cfg` |

The two numbers that matter: mercs were demoted **2–3 m from the player** while
`MaxDetailDistance` is 120, and `WH_AI_LOD_Areas` is **2**. Distance did not demote them, so
either the Detail count budget was exhausted or the **visibility-area filter** excluded them.
`merc_lod_probe`'s census line (living NPCs within 120 m vs `MaxCountDetail`) separates those
two, and `merc_lod_areas0` tests the second directly.

### Run 3: the clothing pipeline is ruled out too

With the AI-LOD set still applied, all three clothing-layer interventions changed nothing:

| test | result |
| --- | --- |
| `merc_lod_attach` — force `HideAttachmentMaster` / `HideAllAttachments` off | no change |
| `merc_lod_cc` — priority penalty → 0, loader jobs 1 → 4, budgets widened | no change |
| `merc_lod_reequip` — fresh `EquipClothingPreset` on all 10, mid-battle | calls succeeded, no change |

Meanwhile **vanilla NPCs a few metres away render normally** under the exact same cvars. So it
is not a global graphics-settings effect, and it is not the clothing scheduler: the geometry is
present, unhidden, re-equipped, and still never drawn. Whatever is left is specific to *our*
entities' render state.

> **Methodology warning.** `merc_lod_lod` bundles four cvars, so runs 2 and 3 cannot attribute
> their result to any one of them. In particular `wh_actor_DissolveTimeout 0` flips the actor
> from *"stay hidden until attachments arrive"* to *"start dissolving immediately"* — with
> `wh_actor_Dissolve = 1`, a dissolve that never completes would leave exactly what we see:
> unhidden, geometry present, invisible. **The bundled set may itself be producing run 2/3's
> state.** Always `merc_lod_revert` first and change one cvar at a time.

### The priority inversion (was the run-2 suspect; disproved in run 3)

Two measured values combine badly:

* `wh_cc_MaxSkinLoaderJobs` = **1** — one skin loader job at a time, for a level holding
  ~1500 NPC entities.
* `wh_cc_HiddenInvisibleManagerPriorityDecrease` = **100** — *"how much the priority is
  decreased when the owner entity is hidden or invisible"*.

So the scheduler de-prioritises an actor **because it is currently invisible**, and there is
one job slot to win back. An invisible merc is pushed to the back of the queue precisely
because it is invisible, and never returns. That matches run 2 exactly: invisible for the
whole battle with zero state changes. `merc_lod_cc` sets the penalty to 0 and widens the pipe.

### Our own contribution: the load-time clothing burst

`RebuildMercCache` ([mercenaries_util.lua](../data/Scripts/mods/mercenaries_util.lua)) calls
`EquipMercenary` on **every** cached merc, and it runs on every save load
(`RebuildMercCacheDelayed`, 2 s after `OnGameplayStarted`). `EquipMercenary` ends in
`ent.actor:EquipClothingPreset(...)`, a full clothing rebuild per merc.

That means **10 simultaneous full clothing rebuilds pushed through a 1-job loader at load
time**, while the level is streaming in ~1400 other NPCs. It is the worst possible moment.

Worse, the preset is re-rolled at random each time:

```lua
finalPresetId = tierOutfits[math.random(1, #tierOutfits)]
```

so a merc gets a **different outfit variant on every save load** (visible in the session log:
merc `_99851` went from `22138336-…` to `41a63950-…` across two loads), plus a fresh 1-in-300
clown roll each time. Two separate problems: cosmetic instability, and guaranteed full-rebuild
work on a load that could otherwise have been a no-op.

`merc_lod_reequip` tests the other half of this — if a manual re-equip mid-battle makes them
appear, the pipeline is fine and only the load-time burst is at fault.

### Why `merc_lod_unhide` is not a fix

Un-hiding a demoted merc gives you a **T-posing puppet that teleports**. `Hide()` is only the
render half of the LOD demotion — animation and real movement stay off, which is exactly
`wh_ai_Lod_MoveIntervalLOD` / `...MonsterLOD` ("fake movement jumps"). Any fix has to keep the
merc **out of LOD**, not paper over the hide.

## Run 4: the property diff

`merc_lod_diff` at **stock cvars** (so this is the baseline demoted state, not run 2's
mystery state), merc vs the living vanilla NPC beside it. Only the differing rows:

| field | merc | vanilla |
| --- | --- | --- |
| `IsHidden` | **true** | false |
| `IsActive` | **false** | true |
| `flags` | 17064962 | 287746 |
| `flagsExtended` | **4194304** | **8320** |
| `bboxSize` | **(1.29, 0.38, 1.88)** | (1.05, 1.05, 1.82) |

Everything else matched exactly: scale 1, no parent, 1 slot, slot 0 valid + character +
geometry, `viewDistRatio` 100, `lodRatio` 100, no entity material, no archetype.

Three things fall out:

* **`IsActive = false`.** An inactive entity receives no update events, so its character never
  animates. That is the other half of the AI LOD demotion, and it explains run 1's T-pose
  directly — `Hide(0)` restored rendering but not updating. `IsActive` is now in the probe
  line and in the watcher's change key.
* **The bbox is a T-pose.** (1.29 wide × **0.38 deep** × 1.88 tall) is arms-out, body-flat —
  bind pose. The vanilla NPC's (1.05 × 1.05 × 1.82) is a normal standing human. Independent
  corroboration that the merc's character has never had an animation update.
* **`flags` differ by exactly `16777216` = bit 24**, which is `ENTITY_FLAG_SPAWNED` in
  CryEngine — expected, since our mercs are spawned at runtime and vanilla ones are
  level-baked. Probably benign, but it is the one structural marker separating them.
  `flagsExtended` are **disjoint**: merc has bit 22 only, vanilla has bits 7 and 13. Only
  three `ENTITY_FLAG_EXTENDED_*` names exist as strings in `WHGame.dll`
  (`FORCE_UPDATE`, `NEEDS_MOVEINSIDE`, `CAN_COLLIDE_WITH_MERGED_MESHES`) and none are exported
  to Lua, so these bits cannot be decoded to names — but the disjointness is a real lead.

### What run 4 did not answer

The three bisect cvars (`areas0`, `dissolve0`, `uberlodoff`) were applied **without a probe
between them**, and `merc_lod_unhide` was never run, so we do not know whether the mercs were
even unhidden during that part — "they didn't show up" may just mean they stayed LOD-demoted.
`merc_lod_probe` now prints a one-line `SUMMARY` (`sets=… hidden=N inactive=N`) so it is cheap
to re-run after every single change.

This also sharpens the **dissolve confound**: at stock cvars (run 1) `Hide(0)` produced a
visible T-pose, but in run 2 with `wh_actor_DissolveTimeout = 0` the mercs were unhidden by the
engine and stayed invisible. Same unhidden state, different visibility, and the dissolve
timeout is the only relevant difference between them.

## Run 5: the state oscillates, and it tracks our own idle flag

The single most useful line in run 5's log is the ordering:

```
[Mercenary] Fast Travel/Teleport detected! Temp idling mercs.
[MercLOD] watch ON
[MercLOD] CHANGE merc ... hidden=Y act=n     <- all ten, same tick
```

Before that line every merc read `hidden=n act=Y`; after it, all ten read `hidden=Y act=n`.
Then, as the player moved, the mercs **drifted 2.3 m → 14 m** while vanilla NPCs stayed close.

That is `_G.MercIdle`, and it is ours:

* `data.isIdle = _G.MercIdle` is read by both `mercenary_scheduler.xml` and
  `archer_scheduler.xml`, so an idled squad stops following.
* `MonitorDistanceAndTeleport` ([mercenaries_teleport.lua:5](../data/Scripts/mods/mercenaries_teleport.lua:5))
  early-returns on `_G.MercIdle`, so the catch-up teleport is disabled too.
* A squad that neither follows nor catches up gets left behind — and a straggler is exactly
  what AI LOD demotes to hidden + inactive.

`MonitorMainQuestLoop`'s ghost-movement heuristic (`distanceMoved > 0.5` with
`playerSpeed < 0.1`) is a very plausible false positive in a scripted battle, where the quest
repositions Henry. That would make this **specific to main-quest battles**, which is exactly
the reported symptom.

Two more observations from the same run:

* `merc_lod_activate` (`Activate(1)` + `Hide(0)`) **did make them visible** — but T-posing.
  So deactivation is indeed the other half of the demotion, and forcing both back on restores
  rendering without restoring animation.
* During the flip, two mercs transiently read `char=?/n vdr=0 lod=0` — every render property
  zeroed at once. Worth watching for again; it looks like a render-proxy teardown.
* `WH_AI_LOD_Areas 2 → 0` was applied while `hidden=0 inactive=0` already, so it still has
  not had a fair test.

### Instrumentation added for this

`merc_lod_probe` now prints a `mod state:` line (`MercIdle`, `PersistentIdle`, `Dismissed`,
`CampActive`, and how long ago the fast-travel detector last fired), and `merc_lod_watch` logs
`MercIdle` transitions on the same timeline as the render-state changes. `merc_lod_ft_off`
clears the flag and stops `MonitorMainQuestLoop` re-setting it (guarded by
`_G.MercDebugDisableFastTravelDetect`), which is the direct test.

## Run 6: MercIdle is not the cause — and the real signal is a restart loop

`merc_lod_ft_off` was run and **changed nothing**. Both probes read
`MercIdle=false PersistentIdle=false Dismissed=false CampActive=false`, and the mercs still
went `hidden=Y act=n` (SUMMARY: `hidden=10 inactive=10`). The run-5 correlation was
coincidental — the fast-travel line happened to sit near the flip in the log, but the flag was
already back to false. **The idle theory is dead.**

Two things in run 6 are worth much more.

### 1. The transition is an entity-slot teardown

Eight mercs flipped simultaneously to:

```
hidden=Y act=n char=?/n vdr=0 lod=0
```

Every render property zeroed at once — `IsSlotCharacter(0)` erroring, `GetCharacter(0)` nil,
**`viewDistRatio` and `lodRatio` both 0** — then a second later back to `char=Y/Y vdr=100
lod=100`, still hidden and inactive. `viewDistRatio`/`lodRatio` live on the render proxy, so
zeroing and restoring them means the proxy was **destroyed and rebuilt**.

That is what `wh_ai_LOD_Hide` describes: *"NPC Hide (**Aspect Profile change**) because of
LOD"*. An aspect-profile change on a GameObject tears down and recreates the character and
physics. So the demotion is: aspect profile change → slot teardown → rebuild → hidden +
inactive. This is the second run in which that exact signature appeared.

And it happens at **2.5–3.7 m** from the player, with **34 living NPCs within 120 m** against a
Detail budget of 70. Neither distance nor count selects these mercs.

### 2. The follow order is being re-issued continuously

`mercenary_scheduler.xml` issues the follow order only when `~$isFollowingActive` and sets the
flag true immediately after, so it should fire **once per merc**. The log has it firing
non-stop, all battle.

The combat branch is the suspect — it clears the flag unconditionally:

```
<IfCondition condition="$inCombat | $mercTarget ~= $__null">
    ... <Expression expressions="$isFollowingActive = false" /> ...
```

A merc whose combat state flickers therefore thrashes: clear flag → re-issue follow → clear
flag. **Every re-issue is an `AddInterrupt_attack`, i.e. a behaviour-tree restart.** A tree
restarting every cycle never gets an animation going (T-pose), and never holds a stable
behaviour — so the `PreventsMonsterLod` flag on our modules never takes effect and AI LOD is
free to demote. This codebase has been bitten by restart-thrash before; see the "mercs stand
around and twitch" entry in `TODO.txt`.

This is the first hypothesis that explains **all** the observations at once: the T-pose, the
demotion at 3 m, the aspect-profile teardown, and why it is worst in big scripted battles
(where combat state flickers hardest).

**Instrumentation:** the raw log line is now
`mercenaries:LodFollowOrderTick(entity, data)`, which counts re-issues per merc and records
`inCombat` / `mercTarget` / `isIdle` / `isCampActor` at the moment of each. `merc_lod_probe`
prints re-issues per merc per second since the last probe. One per merc total is healthy;
anything near one per second is the thrash. The raw line is still available via
`mercenaries.LodFollowVerbose = true`.

## Run 7: the mercs are being left behind, and it is a one-way trap

Three probes across ~45 s in the battle:

| probe | merc distances | merc state | nearest vanilla |
| --- | --- | --- | --- |
| 1 | 2.4 – 3.5 m | `hidden=n act=Y` | 12 – 13.6 m |
| 2 | 7.3 – 21.9 m | `hidden=Y act=n` | 0.7 – 3.6 m |
| 3 | 3.7 – 25.3 m | `hidden=Y act=n` | 2.0 – 14.1 m |

The player walked on; the mercs did not. Once they are `act=n` they have no AI at all, so they
**cannot** catch up — and `MonitorDistanceAndTeleport` only rescues stragglers beyond **50 m**,
which they never reach. It is a one-way trap: fall behind → demote → cannot follow → stay
demoted.

Follow re-issue rates came out at **0.12 – 0.61/s per merc** — real churn against an expected
*one per merc, ever* — but the `last:` field says `inCombat=false target=null idle=false`
at every single re-issue. **The combat branch is not what clears `isFollowingActive`.**
(In the first probe, 9 of 10 mercs reported `campActor=true` while mod state said
`CampActive=false`; the "camp role changed" branch does clear the flag, so that inconsistency
is worth a look on its own — but by probes 2 and 3 `campActor=false` and the re-issues
continued.)

### The measurement that decides direction

`follow.xml`'s formation loop now calls `mercenaries:LodFollowHeartbeat(entity.this.id)` once a
second, so `hb=` in every probe/watch line is *seconds since that merc's follow behaviour last
actually ran*. Because `merc_lod_watch` prints the whole line on each CHANGE, the value at the
**moment of the flip** to `hidden=Y act=n` answers the causality question:

* **`hb` already stale at the flip** → the behaviour died first, and LOD demoted a merc whose AI
  had already stopped. The bug is ours, in the scheduler.
* **`hb` fresh at the flip** → LOD demoted a healthy, running merc. The bug is the engine's LOD
  selection, and the scheduler churn is a symptom rather than the cause.

After the flip `hb` necessarily goes stale (an inactive entity does not tick its tree), so only
the value at the transition is meaningful.

Also fixed: `System.GetCurrTime()` is not monotonic across a save load, which is why run 7
printed `over -39900.7s`. A negative window now reports as unmeasurable instead of a bogus rate.

## Run 8: the heartbeat verdict — the demotion is external

At the moment of the flip to `hidden=Y act=n`, **6 of 9 mercs read `hb=0.7`–`0.8`**: their
follow behaviour had ticked within the last second. (The other three read `hb=-`, never having
heartbeated at all — the watch had only just started.)

**LOD/hiding is taking down healthy, running mercs.** The scheduler churn measured in run 7 is
a symptom, not the cause. That closes six runs of ambiguity.

And the timing is exact — all on one tick:

```
[Mercenary] Fast Travel/Teleport detected! Temp idling mercs.
[MercLOD] CHANGE mod state: MercIdle=true
[MercLOD] CHANGE merc ... hidden=Y act=n   (all ten)
```

Our fast-travel detector fires on *"player moved >0.5 m at ~zero speed"* — i.e. **the player
was repositioned**. That is not a coincidence with the hide; both are effects of the same
event.

## The quest-side hypothesis

Skald's `CreateDialogParams` node carries exactly that pair of ports:

| port | type | default |
| --- | --- | --- |
| `MovePlayer` | bool | false |
| `RotateParticipants` | bool | false |
| **`HideNearbyNPCs`** | bool | **true** |
| `UseTwins` | bool | true |
| `IncludePlayer` | bool | true |

So the chain is: a dialogue/scene starts → the player is moved into position (our detector
trips) → **every NPC near the dialogue is hidden** → our mercs, following at 2–3 m, are the
nearest NPCs in the level.

Supporting evidence:

* **The Maleshov quest contains 18 `CreateDialogParams` usages and overrides `HideNearbyNPCs`
  in none of them** — every one of them runs with the default `true`. (Across all vanilla
  quests the port is explicitly set to `false` 101 times, so opting out is a deliberate,
  case-by-case act that this quest never performs.)
* Vanilla NPCs at 12 m+ were **not** hidden in the same instant, which fits a radius.
* The heartbeat proves the mercs were healthy when hidden — consistent with an external
  system hiding them rather than their AI dying.
* The `char=?/n vdr=0 lod=0` teardown fits a hide that also changes the aspect profile.
* It is specific to main-quest scripted battles, which is where dialogue density is highest —
  matching the original report exactly.

### Caveats that weaken it

Two, both worth holding in mind before treating this as settled:

* **`HideActorCommand` is not the mechanism here.** A full-tree scan finds it in five files, all
  in the *klaster* quests; Maleshov never uses it. So if a quest is hiding our mercs it is doing
  it through the dialogue system, not an explicit hide node.
* **The 18 Maleshov dialogues are discrete, named conversations** — Čertovka camp flavour
  dialogues, the planning polylogs, Žižka before/after the raid, the Bergov negotiation. Only
  two sit inside the final fight, and none of them plausibly fires repeatedly during the
  courtyard battle. Meanwhile the observed flips cluster **a couple of seconds after a save
  load**, where the player is repositioned by the load itself and our ghost-movement detector
  would trip with no dialogue involved at all. The dialogue theory may be over-fitted to the
  load event.

That is precisely what the dialogue-context readout discriminates: if no `speech_*` context
lights up on the player at the flip, the theory is dead. It is also worth reproducing the bug
**without** a fresh load — walk into the battle from outside and play for a minute — to
separate a load artefact from a battle artefact.

### No cvar escape hatch

There is no dialogue hide-radius or hide-disable cvar: the full `wh_dlg_*` set contains nothing
of the sort, and the only `*Hid*` cvars in the binary are unrelated
(`wh_cc_HiddenInvisibleManagerPriorityDecrease`, `wh_ai_LOD_Hide`, `wh_ai_NPCHidePPU`,
`wh_horse_HideReinsWhenMounted`, `wh_sys_HideLoadingScreen`, …). Nor is there a script context
that exempts an NPC from it. If this is confirmed, the fix has to be a **watchdog on our side**
— detect mercs hidden while they should not be, and `Hide(0)` + `Activate(1)` + let the
scheduler re-fire the behaviour. Runs 5 and 6 proved that restores rendering.

### Confirming it

`soul:HasScriptContext` is the only context query Lua has, and it reads **entity-class**
contexts. Four dialogue contexts are entity-class and set **on the player**:

```
speech_playerWasRecentlyInNormalDialog   (set during a fader dialogue + ~10s after)
speech_switchDialogRunning
speech_npcToNpcDialogActive
crime_inCrimeDialog
```

`merc_lod_probe` now prints these, and `merc_lod_watch` includes them in its change key, so a
dialogue starting or ending produces a CHANGE line on the same timeline as the hides. If the
flip lands on a dialogue context turning on, the hypothesis is confirmed.

(`cutsceneIsRunning` is `Class="Game"` and therefore **not** readable through
`soul:HasScriptContext` — a gap in what we can observe.)

## How quest asset lists actually control NPC presence

Worth writing down properly, because the shape of it is right even though the mechanism is not
the one it looks like. Take `utokNaMalesov/nehibernovana_cast/posadka_na_vnejsim_nadvori.xml`
("garrison on the outer courtyard") — the clearest example in the quest:

```xml
<Layer Name="profile3_1">
    <Asset Name="Profiles" Alias="outerCourtyard_basicCrewProfile" />
    <Edge From="outerCourtyard_basicCrewStreaming.State" To="IsActive" />
</Layer>
...
<Assets>
    <ProfileAsset Name="additionalVillageReinforcementsProfile"
                  AssetProfiles="utoknamalesov_additionalvillagereinforcements" />
    <SoulAsset   Name="additionalVillageReinforcements"
                  SharedSoulGuids="0b1f4cfe-… b76dc62d-… 9e0f3b55-… a2d23450-… …" />
    <SoulAsset   Name="villageReinforcements" SharedSoulGuids="…" />
</Assets>
```

Every NPC group carries **two** assets, and they do different jobs:

| asset | drives | job |
| --- | --- | --- |
| **`ProfileAsset`** | a `<Layer>` node (really `TypeName="Layer" Name="Profile"`, `wh::entitymodule`, ports `IsActive` + `Profiles`) | **the existence/render switch** — streams the level layer holding those NPCs in and out |
| **`SoulAsset`** | `PermaDeath`, `SetEntityContext`, `EnableBehavior`, `JoinArrays` | the **logical handle** — "apply this to those souls" |

So the intuition is right that these lists are what decides which NPCs are present — but it is
the **`ProfileAsset` + `Layer`** pair that does it, not the `SoulAsset`. In the file above the
`SoulAsset` lists feed `PermaDeath` and `SetEntityContext(crime_ignoredCorpse)`; the
`ProfileAsset` lists feed the `Layer` nodes that stream the crew in and out
(`nastreamovat_posadku…` / `odstreamovat_posadku`).

**And these are opt-in, per-group, additive.** A full pass over the quest tree found no global
"render only these souls, turn everything else off" whitelist. Every unstream port names a
specific profile. `Migration_*_StreamingSafeguard` is about migrating NPC crime state gated on
`loadedprofilestate`, not about enforcing a roster.

### Why it is still worth chasing

A `Layer`/`Profile` deactivation produces **exactly** the state we measured on the mercs:
hidden **and** deactivated **and** render proxy freed (`char=?/n vdr=0 lod=0`). No other
mechanism we have looked at produces all three at once. If our runtime-spawned mercs can somehow
be caught by a profile toggle, that is the bug.

### On hibernation

`hibernovana_cast` carries `HibernateMode="Script"` on the Skald **`<Module>`** tag;
`nehibernovana_cast` carries none. Across all quests: `Script` 1083×, `DLC` 18×, `ActivityType`
8×, `Auto` 3×. This is `wh::conceptmodule` machinery — quest *module logic* being suspended, as
confirmed by the engine error string *"module has hibernate flag but contains input trigger port
'%s'"* and by the port attribute `IsTriggerableWhenHibernated`. It suspends quest graph
evaluation, not NPC rendering.

It is not unrelated, though: a hibernated module stops driving its `Layer` nodes, so hibernation
is one of the things that can *cause* a profile to go inactive. Note also `ActivityType` is a
quest node (`wh::questmodule`, ports `IsEnabled`/`Weight`/`Cooldown`) with its own hibernate
mode — hence the engine string *"ActivityType %s is set to incorrect hibernate mode %s"* — and
`wh_ai_ActivitySystemSleepOutsideMLOD` ("Enables sleeping of activity system outside of MLOD if
there is nothing to do") links the activity system to LOD.

### No exemption exists

Of every `SideEffect` in `ScriptContext.xml`, exactly one is relevant to any of this:
`crime_preventDespawn` → `disableDespawn`. There is no context for "do not hide", "do not
unstream", or "keep rendered". Our behaviour trees *can* set contexts (they already use
`<EntityContext context="crime_suppressBehavioralReaction" target="$this.id">`), so
`crime_preventDespawn` is cheap to try, but it targets despawn rather than hiding.

### The test

`merc_lod_watch` now takes a **world census at the exact tick our mercs flip** and logs the
delta against the previous one:

* `WORLD MOVED at this flip: entities ±N living ±N living+hidden ±N` — a batch beyond our ten
  moved, so a quest profile toggled and our mercs are collateral. **Hypothesis confirmed.**
* `WORLD UNCHANGED at this flip` — nothing global moved; our mercs were singled out.
  Hypothesis dead.

## Can the mod's own quest force its NPCs to render? No.

The mod already has the hook: `data/quests/mercenaries/{kutnohorsko,trosecko}/mercenaries_background_quest.xml`
is a `<Quest Type="Activity" Repeatable="true">` — always running — and it already declares

```xml
<SoulAsset Name="mercs" SharedSoulGuids="96371224-… 59feed61-… …" />   <!-- 80+ merc souls -->
```

and the binding demonstrably works, since the gossip/bark system drives those souls through it.

But of the **559 Skald node definitions that take `Souls`**, filtering for anything that
controls streaming, rendering, hibernation, LOD, visibility or activation returns exactly
**two**, and both are irrelevant (`EnableAllowedWeaponsInQAM`, `EnableBehavior`). The only
presence control in Skald is the `Layer`/`Profile` node, and that needs a
`wh::entitymodule::LayerProfiles` asset — a **level-baked** asset profile a mod cannot author.
`utils/streaming/npcstreamedifnotdead` confirms it: even the vanilla "keep this NPC streamed"
helper takes a `profile` port.

So there is no Skald route to "force render these souls".

### What was added anyway

`SetEntityContext` with `crime_preventDespawn` on the `mercs` asset, in both quest copies.
`IsActive` is `IsAutoTriggerable`, so leaving it unwired means always-on:

```xml
<SetEntityContext Name="merc_preventDespawn" PositionY="4200" PositionX="300">
    <Constant Name="Context" Value="crime_preventDespawn" />
    <Asset Name="Souls" Alias="mercs" />
</SetEntityContext>
```

**Low confidence.** Its side effect is `disableDespawn`, and our mercs are not being despawned —
the entities persist and the character slot comes back. It is the only presence-adjacent context
that exists, so it is worth having, but it is not aimed at the hide.

### The better experiment: copy the flags

Run 4's diff found exactly one structural difference that is not itself a symptom:
`flagsExtended` were **disjoint** — merc bit 22, vanilla bits 7 and 13. `SetFlagsExtended(flags,
mode)` exists with mode 0 = or, so `merc_lod_copyflags` reads the nearest living vanilla NPC's
extended flags and ORs them onto every merc. If the mercs then stop being hidden, the missing
flag is the discriminator and the fix is simply to set it at spawn time.

`ENTITY_FLAG_EXTENDED_NEEDS_MOVEINSIDE` is one of only three extended-flag names in the binary,
none exported to Lua — and the game's own scripts call
`SetFlagsExtended(ENTITY_FLAG_EXTENDED_NEEDS_MOVEINSIDE, 0)` on entities it spawns (Boids,
`ViewDist.lua`). A runtime-spawned entity missing a flag that level-baked NPCs carry is a very
plausible reason for being treated differently by area/visibility resolution — which is also
what `WH_AI_LOD_Areas=2` ("filtered by Visibility areas") keys off.

The command is one-way; reload the save to undo.

## Watch sampling rate

1000 ms was too coarse: every merc flip and the env change landed in one bucket, so the log
could not say what moved first. The watcher now samples at **250 ms by default**, with
`merc_lod_watch_50` / `_100` / `_250` / `_1000` to change it live (the loop restarts
immediately rather than waiting out the pending timer).

Every watch line now carries a **`t=` timestamp** in seconds since the watch started, so
sub-second ordering at a flip is readable — whether the dialogue/env state, the mercs, or the
world census moved first.

Two costs are decoupled from the sample rate so raising it does not multiply them:

| what | cadence | why |
| --- | --- | --- |
| full `GetEntitiesByClass` scan (~1500 entities), picks up new spawns | `LodWatchRescanSec` = 5 s wall clock | was every 10 *ticks*, which would have become every 0.5 s at 50 ms |
| world census logged at a flip | `LodCensusMinGapSec` = 1 s | a second full scan; a burst of flips would otherwise run it repeatedly for no new information |

The timer callback carries a generation token, so changing the rate retires the pending
callback instead of leaving two loops running in parallel.

## Run 10: extended entity flags ruled out

`merc_lod_copyflags` applied cleanly — `flagsExtended 4194304 → 4202624`, i.e. exactly
`+8320`, the vanilla NPC's bits 7 and 13 ORed on — and made **no difference**. The one
structural difference run 4 found between our mercs and a vanilla NPC that renders is
**not** the discriminator. Closed.

The watch collected nothing that run: `merc_lod_watch_50` only *stored* the rate and never
started the loop. Fixed — the rate commands now start the watch if it is not running. Also
fixed: `%g` was printing bitmasks as `4.1943e+06`, and `fmtval` was declared below its first
use (a file-local, so it would have been nil at runtime).

### Where that leaves the search

Ruled out so far, each by direct measurement:

| candidate | killed by |
| --- | --- |
| clothing/attachment pipeline | run 3 — attach, cc budgets and re-equip all no-ops; `char=Y/Y` |
| AI Detail count budget | census — 24–35 living NPCs within 120 m vs a budget of 70 |
| distance | demotions happen at 2.5–3.7 m |
| our scheduler killing the behaviour | run 8 — `hb=0.7–0.8` at the flip |
| `_G.MercIdle` / fast-travel false positive | run 6 — `ft_off` changed nothing, flag false throughout |
| extended entity flags | run 10 — copied, no change |
| `MonsterLOD` | all six modules carry `PreventsMonsterLod` and the follow behaviour was running |

Still open: the dialogue-context correlation and the `WORLD MOVED`/`WORLD UNCHANGED` census —
**neither has yet been captured at an actual flip**, because the watch has not been running at
the right moment.

## merc_lod_guard: continuous restore

`merc_lod_activate` proved `Hide(0)` + `Activate(1)` brings a demoted merc back (visible, though
T-posing), but it was one-shot and whatever demoted them simply did it again. `merc_lod_guard`
runs the same restore on a 250 ms loop and counts interventions; `merc_lod_probe` reports the
rate.

It is a diagnostic first and a candidate fix second, and the rate is the answer:

* **A handful of restores, then quiet** — the demotion is a one-off per event. Holding the mercs
  up long enough for the behaviour tree to re-establish would make this a viable shipping
  workaround.
* **Sustained, every tick** — something is re-hiding them continuously. A watchdog can never win
  that, and the real cause has to be found.

It skips corpses, so a dead merc is not visually resurrected.

## Run 11: the guard holds them visible — the bug is now the T-pose

With `merc_lod_guard` running, the watch logged its t=0 baseline and then **no CHANGE lines for
the rest of the session**. The mercs never reached `hidden=Y`: the guard is winning, and they
stay rendered. That is half the bug gone.

What remains is that they stand in **bind pose**. And there is a clean explanation:

`Hide(0)` + `Activate(1)` restores the *entity* flags, but the LOD hide is an **aspect-profile
change** (`wh_ai_LOD_Hide`: *"NPC Hide (Aspect Profile change) because of LOD"*), which tears
down the character and physics setup. Nothing in Lua puts an aspect profile back — there is no
such bind. So the guard restores rendering and leaves the character un-updated.

What Lua *does* have is the character-update controls:

| bind | signature |
| --- | --- |
| `CharacterUpdateAlways(slot, bool)` | update the character regardless |
| `ForceCharacterUpdate(slot, bool)` | force an update this frame |
| `CharacterUpdateOnRender(slot, bool)` | tie updating to being rendered — turning this **off** is what keeps an off-screen character updating |

The guard now applies the first two on every restore (`LodGuardAnim`, on by default), and
`merc_lod_anim` applies all three on demand so the animation half stays separable from the
un-hide.

The guard also **self-reports every 10 s** now rather than waiting for a probe — the rate is the
whole point of it and three sessions ended without the number being captured.

### If the character-update binds do not fix the T-pose

Then the animation is driven by the behaviour tree rather than the character update, and the
merc needs its behaviour genuinely restarted after a restore — not just re-issued by the
scheduler, which we know already happens at 0.12–0.61/s without helping. That would point at
the aspect-profile teardown being unrecoverable from Lua, and the honest conclusion would be
that this cannot be fixed from a mod without preventing the hide in the first place.

## Run 12: the symptom names the system

> *"it's like a slide show, sometimes they show up mid animation, sometimes teleporting
> t-poses"*

That is the literal description of an NPC in the **LOD tier**:

* `wh_ai_Lod_MoveIntervalLOD` — *"Time between fake movement jumps in **LOD** (in seconds)."*
* `wh_ai_Lod_MoveIntervalMonsterLOD` — *"…in MonsterLOD."*

Position advances in discrete jumps (the teleporting) while the character is not animated
between them (the frozen mid-animation poses and bind poses). The guard un-hides them, so we now
*see* the LOD state instead of it being invisible — the slideshow is the demotion made visible.

### The gap this exposes

`PreventsMonsterLod`, which all six of our modules carry, blocks **MonsterLOD only**. Nothing we
ship blocks the **Detail → LOD** demotion, and the LOD tier has its own fake movement and its own
hide. Every earlier "it can't be LOD" argument was really an argument about *MonsterLOD*:

* `PreventsMonsterLod` is set → blocks ML, not LOD.
* Detail count budget not exceeded (34 vs 70) → but `WH_AI_LOD_Areas=2` filters by **visibility
  areas**, not count.
* Demotion at 2.5–3.7 m → consistent with area filtering, not distance.
* Fresh heartbeat at the flip → the behaviour still ticks in LOD, just degraded.

### `merc_lod_tier`

| cvar | → | why |
| --- | --- | --- |
| `wh_ai_Lod_MoveIntervalLOD` | 0.05 | turns fake movement jumps back into continuous motion |
| `wh_ai_Lod_MoveIntervalMonsterLOD` | 0.05 | same for the ML tier |
| `wh_ai_LOD_Hide` | 0 | stop LOD hiding the NPC at all (could not be read via `GetCVar`; setting it may still work) |
| `WH_AI_LOD_Areas` | 0 | *"only distance is used for NPC LOD resolution"* |
| `WH_AI_LOD_MaxCountDetail` | 300 | make Detail large enough that nothing is evicted |
| `WH_AI_LOD_MaxDetailDistance` | 400 | same |
| `WH_AI_LOD_HysteresisMultiplierDetail` | 1.0 | stop the multiplier biasing them out of Detail |

This is deliberately a bundle, against the earlier methodology note — after eleven runs without a
positive result, the priority is a yes/no on whether *any* of the LOD-tier levers work. If it
helps, bisect with `merc_lod_moveint` (fake movement alone) and `merc_lod_hideoff` (the LOD hide
alone), which are the two that map directly onto the reported symptom.

## Run 13: the LOD tier is ruled out, and the slideshow was misread

`merc_lod_tier` applied cleanly — `MoveIntervalLOD 1 → 0.05`, `MoveIntervalMonsterLOD 10 → 0.05`,
`Areas 2 → 0`, `MaxCountDetail 70 → 300`, `MaxDetailDistance 120 → 400`,
`HysteresisMultiplierDetail 0.8 → 1` — and changed nothing. With distance-only resolution, a
400 m Detail radius and 300 Detail slots, mercs standing at 3 m **cannot** be evicted from
Detail. **The AI LOD system is not doing this.**

`wh_ai_LOD_Hide` reported `nil -> nil  <-- DID NOT TAKE`: it is not reachable through
`GetCVar`/`SetCVar` at all.

### Correcting the previous reading

I attributed the slideshow to `wh_ai_Lod_MoveInterval*` fake movement jumps. That was wrong, and
the cvar result disproves it. The real explanation is simpler:

**The slideshow is the guard.** It runs at 250 ms; something re-hides the mercs on a much
shorter cycle. So the merc is visible for one frame per guard tick and hidden the rest — a 4 Hz
strobe. It has moved while hidden, so each reappearance is at a new position (the "teleporting"),
in whatever pose it held (the "mid animation" and bind poses).

That tells us something the earlier runs could not: **the hide is re-applied continuously, not
once per event.** A watchdog can never win against it.

## The dialogue twin system

KCD dialogues do not animate the NPC in place. They freeze it and show a **duplicate actor**,
named `DialogTwin_%s`. And the twin cvar's help text says what happens to the original:

> `wh_dlg_ShowOrigActor` — **"Do not hide original actor when freezing its twin."**

So the twin system **hides the original actor** for as long as the twin is up, and there is a
single cvar to stop it. `CreateDialogParams.UseTwins` defaults to `true`, exactly like
`HideNearbyNPCs`.

This is the best remaining fit for a hide that is re-applied continuously rather than once.

### Instrumentation

* **`merc_lod_twins`** — sets `wh_dlg_ShowOrigActor = 1`.
* **`dlg=`** in every probe/watch line — `Dialog.IsSoulInDialog(soul)`, a real Lua bind. A hidden
  merc reading `dlg=Y` means the dialogue system is holding it, not LOD. It is in the watcher's
  change key too.
* **`DialogTwin_ entities=N`** in the census — twins are ordinary entities with a known name
  prefix, so they are directly countable. Any non-zero count means the twin system is live.

Related twin cvars, if `ShowOrigActor` alone is not enough: `wh_dlg_TwinPlayerOverlapQueryCount`,
`wh_dlg_TwinKeepPoseFrontConeAngle`, and the entity context `speech_disableTwins`
(*"Vypne na NPC twiny"* — disables twins on an NPC), which the mod's background quest could set
on the `mercs` SoulAsset the same way `crime_preventDespawn` now is.

## Run 14: inconclusive, and why

`wh_dlg_ShowOrigActor 0 → 1` took. But the probe was taken while **all ten mercs read
`hidden=n act=Y`** — they were not hidden at that moment, so nothing about the twin hypothesis
was actually exercised. `DialogTwin_ entities=0` at a moment with no hide says nothing either.

And `dlg=?` on *every* row, vanilla included, means the bind call was wrong, not that the answer
was no. The documented signature is:

```
DialogModule.IsSoulInDialog(soulWuid)
```

— the global is **`DialogModule`**, not `Dialog`, and it takes a **WUID**, not the soul object.
Fixed, with a fallback to `XGenAIModule.GetMyWUID(ent)` if `ent.this.id` is not the right handle.

### `merc_lod_selftest`

Too many runs have been spent collecting `?` columns from binds that do not exist or were called
wrongly — `Action.IsGameObjectProbablyVisible` (never worked), `GetCurAnimation` (always nil),
`Dialog.IsSoulInDialog` (wrong global), plus a `fmtval` that would have thrown and a rate command
that silently did not start the watch.

`merc_lod_selftest` calls every bind the probe depends on against a real merc and prints OK/FAIL
per bind. **Run it once after any probe change**, before spending a play session on the output.

### What run 14 did not test

The twin hypothesis needs a probe taken **while the mercs are actually hidden**. The `dlg=` column
and the `DialogTwin_` count only mean something at that moment.

## Run 15: dialogue/twins ruled out — and the deterrent area found

First clean measurement taken **while the mercs were actually hidden**:

```
merc … hidden=Y act=n dlg=n hb=6.5  char=Y/Y vdr=100 lod=100
VANIL kkut_samuel  hidden=n act=Y dlg=Y
census: … DialogTwin_ entities=0
```

All ten hidden mercs read `dlg=n` with `wh_dlg_ShowOrigActor=1` applied and zero twins in the
level. And the bind is genuinely working now — the vanilla `kkut_samuel` reads `dlg=Y`. **The
dialogue and twin systems are out.**

### The deterrent area

`utokNaMalesov/hibernovana_cast/deterrent_area.xml` — "Deterrent area u tvrze" — runs during the
battle and does three things:

```xml
<Layer Name="profile8">  <Asset Name="Profiles" Alias="malesovFortressDeterrentArea" />  </Layer>
<SetGameContext>         <Constant Name="Context" Value="global_deterrentAreasActive" />   </SetGameContext>
<SetEntityContext>       <Constant Name="Context" Value="deterrenceImmunity" />
    <Edge From="joinarrays52.Array" To="Souls" />
</SetEntityContext>
```

where `joinarrays52` is `zizkaband` + `outerCourtyardDefendersAndShooters` +
`malesovTowerShooters` + `innerCourtyardDefenders_basicCrew` + `towerDefenders` + `roza`.

So the quest **switches on a deterrent area over the fortress and hand-lists the souls that are
exempt from it**. That is precisely the "quests list the NPCs that are allowed" intuition this
investigation started from — the list is a `deterrenceImmunity` grant, not a render pin.

Our mercs are not on it. Per `mercenaries_deterrent.lua`, `sa_deterrentArea`'s onEnter tree fires
`AddInterrupt 'interrupt_beDeterred'` at **priority 200**; our follow is issued at **160**, so the
deterrent wins, overrides follow, and pushes the merc out toward `deterredSpots`.

This accounts for a lot of what was measured and never explained:

* mercs stop following and drift 2 m → 14 m → 20 m while the player moves on
* the follow order is re-issued repeatedly (0.12–0.61/s) but never sticks — 200 outranks 160
* `hb` fresh at the flip, stale afterwards — follow is running, then overridden
* battle-specific, and only *our* NPCs: every vanilla NPC in the fight holds `deterrenceImmunity`

### The fix

`deterrenceImmunity` is the standard exemption — **69 usages across vanilla quests**. The mod's
always-running background quest already carries a working `SoulAsset Name="mercs"`, so granting it
is the same one-node pattern the vanilla quest itself uses, now added to both copies:

```xml
<SetEntityContext Name="merc_deterrenceImmunity" PositionY="4350" PositionX="300">
    <Constant Name="Context" Value="deterrenceImmunity" />
    <Asset Name="Souls" Alias="mercs" />
</SetEntityContext>
```

**Caveat, stated plainly:** this explains the *not-following and drifting*. It does not by itself
explain `hidden=Y act=n`, and the earlier LOD-cvar test argues against distance alone causing the
hide. It may be that being deterred out of the area is what puts them somewhere the hide applies,
or the hide may still be a separate mechanism. Worth testing on its own merits either way — it is
a real, verified defect against this quest.

## Run 16: `act=n` does not mean the AI stopped

The second probe caught this:

```
merc _39657  d=21.3  hidden=Y act=n dlg=n hb=0.1
merc _68852  d= 6.8  hidden=Y act=n dlg=n hb=0.0
```

**`hb=0.0–0.9` on entities reporting `act=n`.** The follow tree's one-second loop is ticking
right then, on an entity the engine says is not active. So `IsActive()==false` does **not** mean
the AI has stopped — KCD's AI runs on its own scheduler, independent of the CryEngine entity
update flag. `act=n` means no per-frame *entity* update, which is why the character does not
animate.

That is precisely the original report — *"invisible fighters, continuing to deliver damage"* —
and it retires a reading I had been carrying since run 4, where I treated `act=n` as "AI is
dead".

`deterrenceImmunity` did not stop the hide (as flagged when it was added — it addresses the
drift, not the hide). Lite souls were checked and are irrelevant: the only strings are
`wh_rpg_LiteSoulTargetPriorityBoost`, `combatDisabledLiteSoulsAsTarget` and
`combatShooterPreferringLiteSouls`, all targeting-priority, nothing about rendering.

## The discriminator that has never been run

Every measurement is "all ten mercs, always, and never a vanilla NPC". Two very different causes
produce that:

* **(a)** something about entities *we spawn at runtime*, whoever they are
* **(b)** something about *our souls / brain / faction* specifically

`merc_lod_spawntest` settles it: it hires a fresh merc **and** spawns a fresh enemy in place, then
auto-probes them 8 s later (scheduled, because sessions keep ending with the spawn done and no
probe taken). The enemy shares the spawn path but has a different soul, brain, faction and
SmartEntity.

| result | meaning |
| --- | --- |
| both `hidden=Y` | (a) any runtime-spawned NPC in this battle — the brain is irrelevant |
| merc only | (b) our soul/brain/faction — that is where to look |
| neither | it is state the *existing* mercs accumulated, not how they spawn |

If it comes out (a), the next step is spawning a **vanilla** soul at runtime — the Maleshov
`towerDefenders` GUIDs are known (`89fd30c0-a444-407c-aea4-ad2fa2d391ad` and five others) — but
duplicating quest NPCs in a live save can break the quest, so that one is a last resort on a
throwaway save.

## Run 17: it is not accumulated state — it is runtime spawning

`merc_lod_spawntest`:

```
NEW enemy SpawnedEnemy_looter_weak_12714…  d=14.2 hidden=Y act=n  dead=Y hp=0
NEW merc  SpawnedFriend_strong_78371…      d= 7.4 hidden=Y act=n  dead=n hp=100  hb=1.6
```

A merc **spawned eight seconds earlier** is already hidden, with its follow tree ticking
(`hb=1.6`). So this is not something the existing mercs accumulate — **anything we spawn in this
place is hidden essentially from birth.** (The enemy sample is weaker: it reads `dead=Y hp=0`,
killed inside the 8 s window, and corpses may hide for their own reasons.)

That collapses the search to one distinction: **level-baked / quest-streamed NPCs render; NPCs
created at runtime do not** — here, in this enclosed fortress, while every render property on
ours reads normal and their AI keeps running.

## Current hypothesis: VisArea registration

`ENTITY_FLAG_EXTENDED_NEEDS_MOVEINSIDE` is literally the *"put this entity inside the right
area"* request, and **the game's own scripts set it on entities they spawn at runtime** —
`Scripts/Entities/Boids/*.lua` and `Render/ViewDist.lua` all call
`SetFlagsExtended(ENTITY_FLAG_EXTENDED_NEEDS_MOVEINSIDE, 0)`. That is exactly our situation and
we have never done it.

A runtime-spawned entity never registered into the VisArea it stands in would be culled inside an
enclosed structure like the Maleshov fortress, while `IsHidden` and the render properties all
still read normal — which is what we measure. Supporting hints: `WH_AI_LOD_Areas=2` is *"filtered
by Visibility areas"*, and the binary carries a `C_VisibilityAreaManager`. There is **no Lua bind
to set an entity's VisArea** (`ActivatePortal` is the only VisArea-adjacent bind); this flag is
the only handle.

`merc_lod_copyflags` did **not** already cover this. It ORed a nearby vanilla NPC's mask, and that
NPC did not have the flag set either — nothing decoded for bit 22 or bits 7/13, and the flag was
absent from both.

* **`merc_lod_moveinside`** — sets the flag on every mod NPC, mode 0 (or), the same call the
  game makes.
* **`merc_lod_flagdump`** — lists every `ENTITY_FLAG*` global the engine exports, with values and
  bit numbers. This is the gap that made `copyflags` a blind shot: we never knew which constants
  exist or what they are worth.

## Run 18: consolidation

### The flag dump, and a decoder correction

The engine exports 20 `ENTITY_FLAG*` globals. Re-decoding run 4's masks against the real values:

| | bits set |
| --- | --- |
| merc `flags` = 17064962 | 1, 10, 13, 14, 18, **24** |
| vanilla `flags` = 287746 | 1, 10, 13, 14, 18 |
| merc `flagsExtended` = 4194304 | 22 |
| vanilla `flagsExtended` = 8320 | 7, 13 |

The **only** regular-flag difference is bit 24 (16777216, not exported; `ENTITY_FLAG_SPAWNED` in
stock CryEngine) — expected for a runtime spawn.

**Correction:** run 4's decode reported `ENTITY_FLAG_AI_HIDEABLE` as set on both entities. It was
not. `AI_HIDEABLE` is **-2147483648**, and the division-based bit test evaluates
`floor(mask / negative) % 2 == 1` as true against any mask. Fixed with a `v > 0` guard.

`ENTITY_FLAG_EXTENDED_NEEDS_MOVEINSIDE` does exist (= 4, bit 2), was absent from both entities,
was applied via `merc_lod_moveinside`, and changed nothing. **VisArea registration is ruled out.**

Also ruled out this run: **mod conflict.** Across all 19 installed mods, `:Hide(` appears in
exactly one pak — ours (2 in the deterrent probe, 3 in the debug module). Nothing else in the
load order hides entities.

### The one useful find: `ENTITY_FLAG_UPDATE_HIDDEN`

`ENTITY_FLAG_UPDATE_HIDDEN = 2097152` (bit 21) — *update the entity even while hidden*. It does
not make anything visible, but it addresses the frozen pose directly, and it is the only flag in
the dump that bears on the symptom. `merc_lod_updatehidden` applies it; the guard now sets it too.

### Everything known about the T-pose

| observation | run |
| --- | --- |
| `Hide(0)` alone → visible, T-posing, snapping around | 5 |
| guard (`Hide(0)`+`Activate(1)` at 250 ms) → visible, still T-posing | 11 |
| "slideshow, sometimes mid animation, sometimes teleporting T-poses" | 12 |
| bbox (1.29, **0.38**, 1.88) vs vanilla (1.05, 1.05, 1.82) — arms out, body flat = bind pose | 4 |
| `hb=0.0–0.9` while `act=n` — the behaviour tree is ticking | 16 |

Read together these say one thing: **the character is fully renderable.** Force `Hide(0)` and it
draws. So there is no VisArea culling, no missing clothing, no LOD render suppression, no material
problem — the *only* thing keeping them off screen is the repeated `Hide(1)`.

The pose is frozen because the entity gets no per-frame update (`act=n`), **not** because the AI
died (`hb` fresh). "Sometimes mid animation" is each merc frozen at whatever pose it held when the
hide landed. "Teleporting" is the AI still moving them while nothing renders, so each un-hide
shows them somewhere new.

So the T-pose is **not an independent lead** — it is the same single cause seen from another
angle. One actor: something calls `Hide(1)` + deactivate on our runtime-spawned NPCs, repeatedly,
in this quest area. Everything else is downstream of that.

### What has been ruled out, and how

| candidate | ruled out by |
| --- | --- |
| clothing / attachment pipeline | `merc_lod_attach`, `merc_lod_cc`, `merc_lod_reequip` all no-ops; `char=Y/Y` |
| AI LOD (all tiers) | `merc_lod_tier`: MoveInterval→0.05, Areas→0, MaxCountDetail→300, MaxDetailDistance→400, no change |
| Detail count budget | 24–35 living NPCs within 120 m against a budget of 70 |
| distance | hides happen at 2.3–3.7 m |
| MonsterLOD | `PreventsMonsterLod` on all six modules; follow was running |
| our scheduler killing the behaviour | `hb=0.7–0.8` at the flip |
| `_G.MercIdle` / fast-travel false positive | `merc_lod_ft_off` changed nothing |
| dialogue system | `dlg=n` on all hidden mercs, with a working bind (vanilla read `dlg=Y`) |
| dialogue twins | `wh_dlg_ShowOrigActor=1` applied; `DialogTwin_ entities=0` |
| deterrent areas | `deterrenceImmunity` granted via the background quest; still hidden |
| extended entity flags | vanilla's mask copied on; no change |
| VisArea registration | `NEEDS_MOVEINSIDE` applied; no change |
| lite souls | strings are targeting-priority only, nothing about rendering |
| accumulated state on old mercs | a merc 8 s old is already hidden |
| another mod | `:Hide(` exists in no other mod's pak |
| Skald forcing a render | none of 559 Soul-taking nodes can; `Layer`/`Profile` needs a level-baked asset |

### What has not been tried

* A **different scripted battle** (the Suchdol siege has its own `Battle` cvar override and
  deterrent setup) — would say whether this is Maleshov-specific or general to scripted battles.
* **All other mods disabled** — the pak scan clears them of calling `Hide`, but not of changing
  quest/AI data that might.
* Spawning a genuine **vanilla soul** at runtime (Maleshov `towerDefenders` GUIDs are known) —
  would separate "runtime-spawned" from "our souls" for certain. Risky on a live save.
* `merc_lod_guard` + `UPDATE_HIDDEN` together, which is the best available cosmetic mitigation
  rather than a fix.

## The animation module has its own LOD — and its own time budget

It happens in **all** scripted events, not just Maleshov, which rules out anything specific to
one quest's setup.

`wh_am_*` is the animation module, and two of its cvars matter:

| cvar | help text |
| --- | --- |
| **`wh_am_AnimationControllerManagerUpdateAll`** | **"Force update of all registered controllers. Regardless of the actual pre physics update duration!"** |
| `wh_am_AnimationControllerManagerUpdateEndsBeforeStartAnimProc` | "Force update of all registered controller during skiptime. Regardless of the actual pre physics update duration!" |
| `wh_am_LOD_Debug` | "Debug animation controller and anim LODs for given entities (comma separated)" |
| `wh_am_LOD_Test`, `wh_am_LOD_LocatorPeriodicalUpdate`, `wh_am_LOD_ForceEmitAllAnimEvents` | the rest of the anim-LOD surface |

The controller manager updates registered controllers **within a pre-physics time budget**, and
those that do not fit are not updated that frame. A character whose controller is skipped is
exactly what we see: correct geometry, correct position, no posing. In a crowded scripted battle
our NPCs are plausibly last in that update order.

### Reproducing it on demand

`merc_lod_tpose` calls `Activate(0)` on the squad — the same `act=n` measured on hidden mercs —
which freezes the entity update while leaving them rendered. **The T-pose can now be reproduced
anywhere, without being in a battle**, which makes every fix below testable in seconds instead of
per play session. `merc_lod_unfreeze` undoes it.

### `merc_lod_animseq`

Eight candidate fixes, 5 s apart, each followed by a state line so the log alone shows what moved:

1. `wh_am_AnimationControllerManagerUpdateAll=1` (+ the skiptime variant) — ignore the budget
2. `CharacterUpdateAlways` + `ForceCharacterUpdate` + `CharacterUpdateOnRender(false)`
3. `ENTITY_FLAG_UPDATE_HIDDEN` + `SetAnimateOffScreenShadow(true)`
4. `ResetAnimation(0,-1)` then `StartAnimation` — five candidate names probed individually and
   logged, since KCD drives characters through Mannequin and a raw `.chrparams` name may not
   resolve at all
5. `SetAnimationDrivenMotion` + `AwakeCharacterPhysics` + `AwakePhysics`
6. `ResetPhysics` — re-`PhysicalizeSlot` only if `PE_LIVING` is actually defined, because
   physicalizing a living actor with a nil type can leave it worse than the T-pose
7. `Activate(1)` — the control, known to restore rendering
8. `RagDollize(0)` — **destructive**, they collapse; reload to undo

Standalone: `merc_lod_animall` (step 1 alone) and `merc_lod_ragdoll` (step 8 alone).

## Run 19: three findings, one of them a tooling bug

**The sequence never advanced.** It logged step 1 about thirty times. `LodAnimSeqRun(step)` took
the next step through `Script.SetTimerForFunction`'s third parameter, and **that argument never
arrives in KCD** — so `tonumber(step) or 1` fell back to 1 forever. Only step 1 was ever tested.

The step counter now lives on the table (`LodAnimSeqStep`) instead of the timer argument. The same
unreliable parameter was being used for the watch and guard generation tokens, which means those
guards were inert the whole time; they are removed, and a rate change now just updates
`LodWatchIntervalMs`, which the loop reads every tick anyway.

**`merc_lod_tpose` did nothing.** `Activate(0)` on a healthy merc does not freeze it. So `act=n`
is a **symptom** of whatever the scripted event does, not the cause of the frozen pose — and the
T-pose cannot be reproduced synthetically this way. Setting the entity-update flag off is not
sufficient; something else in the same operation stops the posing.

**They recover on their own when the event ends.** Partway through the log the merc flips from
`hidden=Y act=n` to `hidden=n act=Y hb=0.x` and stays healthy for the remaining ~20 samples,
matching "the battle was kinda over". Whatever holds them is released with the scripted event, and
it is fully reversible.

Also worth noting from the same log: `wh_am_AnimationControllerManagerUpdateAll` was **already 1**
(`1 -> 1`), so the animation-controller budget was never throttling anything. That hypothesis is
dead on arrival — the cvar was already at the value I wanted to test.

## Run 20: ragdoll restored the animation

Two results that change the approach:

* **Step 7, `Activate(1)` + `Hide(0)`, "did what it was supposed to do"** — and one merc came back
  **fully functional** (following, animating). Visibility is a solved problem.
* **Step 8, `RagDollize(0)`, did not collapse them.** They flew around the sky *"while playing the
  correct animation"*. So re-physicalising the character **restored the animation layer** and broke
  only the physics.

The animation can therefore be kicked back to life on a live merc. The problem is doing it without
wrecking the physics.

### `merc_lod_animfix`

Separates the two halves, which `merc_lod_animseq` conflated. Every step **re-asserts
`Activate(1)` + `Hide(0)` first** — otherwise the event re-hides them between steps and the
animation result is invisible — and the guard runs throughout to hold visibility between steps.
Ordered least to most invasive:

1. baseline: visibility restore only — are they already animating?
2. `ResetAnimation(0,-1)`
3. `StopAnimation(0,-1)` then `ResetAnimation(0,-1)`
4. `SetAnimationDrivenMotion(0,1)` + `AwakeCharacterPhysics` + `AwakePhysics`
5. `CharacterUpdateAlways` + `ForceCharacterUpdate` + `CharacterUpdateOnRender(false)`
6. `ResetPhysics()` alone — a physics re-init without the ragdoll
7. **`RagDollize(0)` then `ResetPhysics()` + `AwakePhysics`** — the run-20 fix with physics restored
8. `RagDollize(0)` then `ResetPhysics` + `AwakeCharacterPhysics` + `SetAnimationDrivenMotion` + `Activate(1)`

Steps 6–8 are the interesting ones: if `ResetPhysics()` alone restores the animation, that is a
clean fix. If only the ragdoll variants work, the question becomes whether the physics can be put
back afterwards.

`merc_lod_hold` is the visibility restore on its own; `merc_lod_animfix_stop` halts the walk.

## Run 21: the behaviour tree is dead, not just un-posed

The `hb` column across the eight animfix steps:

```
4.9 → 9.9 → 14.9 → 19.9 → 25.0 → 30.0 → 35.0     (exactly +5.0 per step)
d =  7.2 → 7.2 → 7.2 → 7.2 → 7.2 → 7.2 → 7.2
```

**The follow tree's one-second loop did not fire once in 35 seconds**, and the merc did not move a
centimetre. Nothing about rendering explains that.

This **corrects run 16**, where a snapshot caught `hb=0.0–0.9` on hidden mercs and I concluded "the
AI is alive, KCD's AI runs on its own scheduler". Those were mercs briefly recovering. Held in the
broken state, the BT is simply **not running**.

None of the animation interventions did anything — `ResetAnimation`, `StopAnimation`,
`SetAnimationDrivenMotion`, the `CharacterUpdate*` family, `ResetPhysics`. Only `RagDollize` moved
them, still T-posing, some floating. Run 20's "playing the correct animation" was almost certainly
a merc that had already recovered as that battle ended.

The guard log is also informative: `16 restore(s) over 10.2s (1.57/s)`, then **`0 restore(s)`** for
the rest. The re-hiding stops after a few seconds — they stay visible — and they *still* do not
animate or move. So the hide and the dead AI are two consequences of one upstream event, not cause
and effect.

## Current hypothesis: NPC registration

Around `wh_ai_NPCDryUpdateMode` the binary carries `C_NPCManager` and two assert strings:

> "Registering NPCs is not allowed during this time"
> "Unregistering NPCs is not allowed during this time"

and the cvar's own help:

> `wh_ai_NPCDryUpdateMode` — *"Mode of executing dry update for NPCs 0 - all NPCs are dry updated,
> 1 - only **registered** NPCs are dry updated, 2 - only **registered** NPCs are update (but extra
> assert code for validation is executed)"*

So there are windows during which NPC registration is **forbidden**, and on modes 1 and 2 only
**registered** NPCs get updated at all. An NPC spawned into — or caught by — such a window would
never register, and would then get no update: no behaviour tree, no animation, no movement.

That fits every surviving observation: only runtime-spawned NPCs, every scripted event, recovery
when the event ends, BT dead, vanilla NPCs unaffected.

* **`merc_lod_dryupdate`** — `wh_ai_NPCDryUpdateMode = 0`, update everything regardless of
  registration. If they come back, the bug is that our NPCs are not registered with `C_NPCManager`.
* **`merc_lod_npchistory`** — points the engine's own `wh_ai_DumpNPCHistory` /
  `wh_ai_DisplayNPCHistory` at a merc. Their help is *"Dump/Display the complete history of
  selected NPC properties"*, which should show whether the merc was ever registered and when its
  state last changed.

## Run 22: the heartbeat reading was wrong, and the bodies are decoupled

`wh_ai_DumpNPCHistory` and `wh_ai_DisplayNPCHistory` both reported `nil -> nil  DID NOT TAKE` —
neither is reachable through `GetCVar`/`SetCVar`, so the engine's own NPC diagnostic is
unavailable. `wh_ai_NPCDryUpdateMode = 0` changed nothing.

**Correction to run 21.** `hb` only ticks inside `follow.xml`. A merc in combat is running
`combat_melee`, not follow, so a stale heartbeat is *expected* and says nothing about the AI. The
run-21 conclusion "the behaviour tree is dead" was built on that and is withdrawn — the mercs
"participated in the battle", so their AI is running fine.

What is actually true is sharper and stranger: **the acting merc and the drawn merc are
decoupled.** The logical actor fights; the entity we probe reports a fixed position and, when
forced visible, a frozen body. Fixing visibility (`Activate(1)` + `Hide(0)`) yields a statue;
leaving it alone yields an invisible combatant. Two views of one NPC that no longer agree.

### Testing the decoupling

`merc_lod_track` samples every merc's `GetWorldPos` at 250 ms for 10 s and reports total distance
moved, plus how many samples it was hidden for. Run it during a fight:

* **~0 m while they are visibly fighting** — the entity transform really is frozen, and the combat
  is being driven from somewhere the entity is not following.
* **metres moved** — the entity is fine and `d=7.2` was a sampling artefact, which would retire a
  chunk of the last few runs' reasoning.

### Rebinding the visual form

`merc_lod_reloadchar` does the literal version of the idea: `FreeSlot(0)` to drop the character
slot entirely, then `LoadCharacter(0, "Objects/characters/humans/skeleton/male.cdf")` to build a
fresh one. That CDF is the base skeleton named in `system.cfg`'s `ca_CharEditModel`, chosen
because it certainly exists and looks obviously wrong — so there is no ambiguity about whether the
reload happened.

| outcome | meaning |
| --- | --- |
| base figure appears **and animates** | the visual can be rebound; the original binding is what is broken |
| appears but still frozen | the break is upstream of the character |
| nothing appears | the slot cannot be rebuilt from Lua at all |

Destructive — those mercs will not look like themselves again until the save is reloaded.

## Run 23: the entities are fine. They are only hidden.

`merc_lod_track`, 10 s, 40 samples:

```
67796   moved 14.75m   hidden 39/40
19189   moved 18.29m   hidden 37/40
33570   moved  0.58m   hidden 39/40
94044   moved  0.29m   hidden 39/40
14150   moved  0.24m   hidden 37/40
16473   moved  0.20m   hidden 38/40
50547   moved  0.13m   hidden 37/40
46179 / 99910 / 50633   moved 0.00m   hidden 39/40
```

**Two mercs moved 14.75 m and 18.29 m in ten seconds while hidden** — 1.5–1.8 m/s, ordinary
walking and running. Their transforms are live and updating. The eight reading ~0 m were simply
standing still.

So the decoupling theory is **wrong**, and so is most of what runs 21–22 built on it. There is no
frozen transform, no detached logical body, and very likely no animation bug at all: the
"T-posing statues" were the stationary mercs, glimpsed for one frame in four through the guard's
strobe, with no animation update while hidden.

**What is left is a single defect: something hides them ~97% of the time during scripted events.**
Everything else — position, movement, combat participation — is working.

That is a much better place to be than it sounds, because the guard already demonstrably un-hides
them, and if the entity underneath is fully functional then holding it un-hidden fast enough is
not a cosmetic patch but an actual fix. At 250 ms it produced a 4 Hz strobe; `merc_lod_guard_16`
runs it at roughly frame rate.

### `merc_lod_reloadchar` removed — it crashed the game

It called `FreeSlot(0)` and then `LoadCharacter(0, "Objects/characters/humans/skeleton/male.cdf")`,
a path taken from `system.cfg`'s `ca_CharEditModel`. The log says
`CryAnimation: character-definition not found`, and the game crashed in `WHGame!00e7102c`.

The path does not merely have a typo: **KCD2 ships no `.cdf` or `.chr` files at all.**
`Characters.pak` contains 258 `.skin` files and nothing else, because characters are assembled at
runtime by the clothing system. `LoadCharacter` had nothing valid to load, and `FreeSlot(0)` had
already destroyed the live character. The command has been deleted rather than repaired — there is
no asset for it to use, and it is destructive with no recovery path.

## Run 28: the two debug draws disagree, and that is the last unexplained fact

| debug draw | on vanilla NPCs | on our mercs |
| --- | --- | --- |
| `wh_rpg_SkirmishDebugDraw` (skirmish) | yes | **yes** — cylinders overhead |
| `wh_cs_DebugDrawLods` (combat LOD) | yes | **nothing** |

Both are the engine drawing its own state, not us inferring it. **Our mercs are skirmish
participants with no combat-LOD entry.** That is the single structural fact still unexplained, and
everything else measured is consistent with it.

### The shipped skirmish defaults

Read via `merc_lod_cvars` before the set was applied:

| cvar | default |
| --- | --- |
| **`wh_rpg_SkirmishSoulUpdateBudget`** | **1** — *one* soul updates per frame |
| **`wh_rpg_SkirmishPassiveMaxDistance`** | **15** m — passive souls dropped beyond it |
| `wh_rpg_SkirmishPassiveMinDistance` | 10 m |
| `wh_rpg_SkirmishPassiveMaxDistanceFromBattleManager` | 110 m |
| `wh_rpg_SkirmishPassiveMinDistanceFromBattleManager` | 100 m |
| `wh_rpg_VirtualSkirmishRadius` | 15 |
| `wh_rpg_SkirmishMergeDistance` | 20 |

A squad following the player around a battlefield crosses 15 m constantly, which fits the churn
exactly. But widening the whole band still left **13 removals and 20 connects** in the remaining
4,596 log lines, so the band is not the whole story.

`merc_lod_skirmish` changes seven cvars at once — my own "never bundle" rule broken again.
`merc_lod_soulbudget` and `merc_lod_passivedist` isolate the two standouts.

### Soul type: checked and cleared, without a play session

The engine string `Combat actor cannot be created on this type of soul` suggested a soul-type gate.
Comparing our merc souls against vanilla human combat NPCs (`pogrom_synagogueDefender3/4/5`):

| column | our mercs | vanilla human combatant |
| --- | --- | --- |
| `soul_class_id` | absent | absent |
| `soul_archetype_id` | 0 | 0 |
| `ai_body_id` | absent | absent |
| `combat_level` | 0.5 | 0.5 |

Identical. Archetype 0 is human (3 is horse), so the type gate is about human/horse/dog, not us.
**Closed at zero cost to testing time** — the right outcome, and the model for how the remaining
leads should be triaged.

## Run 27: the follow-interrupt theory is dead, and the log lines decode

`merc_lod_noreissue` blocked the follow re-issue and **58 more skirmish evictions followed**. Our
scheduler is not what removes them. (Run 7 measured that churn, run 26 promoted it to cause, run 27
killed it — it was a symptom after all.)

### What those log lines actually are

Matching the format strings against `RPGModule.dll` gives the real symbols:

| log line | symbol |
| --- | --- |
| `Removing skirmish soul '%s' from the skirmish (threadId: %ld).` | `wh::rpgmodule::C_Skirmish::RemoveSoul` |
| `Soul %s disconnection from npc %d` | `wh::rpgmodule::C_SkirmishSoul::DisconnectFromLODState` |
| `Soul %s connected from npc %d` | `wh::rpgmodule::C_SkirmishSoul::ConnectToLODState` |
| `Soul NPC was created %s` / `was removed %s` | `C_SkirmishSoul::OnNPCCreated` / `OnNPCRemove` |

So **"npc %d" is a skirmish LOD-state index, not an NPC body** — I had been reading it as the
soul↔body binding. Source files: `rpgmodule/Skirmish/Skirmish.cpp`, `SkirmishSoul.cpp`.

### The churn, counted

`connected from npc 0`, one session:

| soul | connects |
| --- | --- |
| **`SpawnedFriend_strong_`** | **77** |
| `utokNaMalesov_innerCourtyardDefender_` | 7 |
| `utokNaMalesov_outerCourtyardShooter_` | 5 |
| `utokNaMalesov_malesovTowerShooter_` | 3 |
| `kcer_brabantSoldier_` | 2 |
| every named NPC (žižka, bohuta, ptáček, komár, samuel, …) | 1 each |

Vanilla NPCs join a skirmish and stay. Ours join, leave and rejoin dozens of times.

### And the thresholds are named cvars

| cvar | help |
| --- | --- |
| **`wh_rpg_SkirmishPassiveMinDistance`** | **"Minimal distance from skirmish to add passive soul."** |
| **`wh_rpg_SkirmishPassiveMaxDistance`** | **"Maximal distance from skirmish to remove passive soul from skirmish."** |
| `wh_rpg_SkirmishPassiveMinDistanceFromBattleManager` / `Max…` | same for souls added by the battle manager |
| **`wh_rpg_SkirmishSoulUpdateBudget`** | **"Budget for updating active souls in skirmish = count of souls which will update per frame."** |
| `wh_rpg_VirtualSkirmishRadius`, `wh_rpg_SkirmishMergeDistance`, `wh_rpg_SkirmishTemporalJoinCooldown` | related |
| `wh_rpg_SkirmishDebugDraw`, `wh_rpg_SkirmishDebugDrawFilter` | *"Filters skirmish debug draw for given combatant."* |

Souls are added to and removed from a skirmish **as passive participants, by distance**. A merc
hovering around that boundary is added and removed repeatedly, and each cycle tears down and
rebuilds its skirmish LOD state and NPC — so the character never finishes building.

`merc_lod_skirmish` widens the band and raises the per-frame budget. `merc_lod_skdebug` turns on
the skirmish system's own debug draw, filtered onto a merc.

**No PDBs ship with the dev build**, so symbol breakpoints are not available; these cvars and the
debug draw are the substitute.

## Run 26: the mercs are not in the combat LOD manager at all

`wh_cs_DebugDrawLods` drew LOD info on every NPC in the battle **except the mercs**. Not "ambient
LOD" — **no entry whatsoever** in the combat LOD manager. `merc_lod_cs` confirmed the manager
itself works: it moved every registered NPC to normal, including ones sitting on near. Ours simply
are not in it.

That turns run 24's log lines from noise into the mechanism:

```
Removing skirmish soul 'SpawnedFriend_strong_50615_…' from the skirmish
Soul … disconnection from npc 1
Soul … disconnection from npc 0
Connected to the soul NPC was created …
```

And the distribution of those lines across the whole log settles who it happens to:

| soul | `Removing skirmish soul` count | |
| --- | --- | --- |
| `SpawnedFriend_strong_` | **10** | every merc |
| `utokNaMalesov_outerCourtyardShooter_` | 2 | both had just died (`DR_Combat`) |

**Every living-soul eviction from a skirmish is one of ours.**

### The suspect is our own scheduler

`mercenary_scheduler.xml` re-issues the follow behaviour as `AddInterrupt_attack` at **priority
160** — measured in run 7 at **0.12–0.61 per second per merc**, against an expected *once ever*. An
interrupt at that priority evicts the soul from its skirmish; the eviction tears down the soul↔NPC
binding (`disconnection from npc 1` / `npc 0`), a new NPC is built, and while that is happening
there is no combat-system presence: no LOD entry, no rendered body, no animation.

Run 7 measured this churn and I dismissed it as a symptom. It looks like the cause.

It also explains the whole shape of the bug in a way no engine mechanism did:

* only our NPCs — only ours get a follow interrupt re-fired
* only in battles — outside combat there is no skirmish to be evicted from
* invisible but still fighting — the soul keeps its combat role between evictions
* no combat LOD entry — not currently in a skirmish
* recovers when the battle ends — nothing left to evict from
* every engine-side fix failed — none of them was ever involved

### `merc_lod_noreissue`

`mercenary_scheduler.xml` now gates the re-issue on `$noReissue`, fed from
`_G.MercNoFollowReissue`, so the re-issue can be switched off at runtime:

* **mercs become visible and stay in the fight** → we were evicting them, and the fix is to not
  re-fire follow while the merc is in a skirmish
* **no change** → the eviction comes from somewhere else

While it is on, mercs will not re-acquire follow and so will not catch up after combat. It is a
test switch, not a fix.

## Run 25: the battle cap was not it — and a whole LOD system had been missed

`wh_cs_BattleMaximumNPC 30 → 60` and `wh_cs_BattleMaximumDeadNPC 15 → 60` both applied cleanly and
changed nothing. The cap is not the cause. The soul disconnect/reconnect cycling in run 24's log is
real but is a symptom, not the mechanism.

### The combat system has its own LOD

Everything ruled out under the heading "LOD" was **`WH_AI_LOD_*`** — the AI module's
Detail/LOD/MonsterLOD tiers. `CombatModule.dll` has a **separate** one:

| cvar | help |
| --- | --- |
| **`wh_cs_ForceLod`** | **"Forces combat LOD: 0..high, 1..med, 2..low"** |
| `wh_cs_LodNearDistance` | "Distance limit for near lod." |
| `wh_cs_LodFarDistance` | "Distance limit for far lod." |
| `wh_cs_LodAmbientDistance` | "Distance limit for ambient lod." |
| **`wh_cs_LodBattleDistanceModifier`** | **"Distance modifier for lod distances in battle."** |
| `wh_cs_LodLowDetailsDistance`, `wh_cs_LodMediumDetailsDistance` | detail tiers |
| **`wh_cs_DebugDrawLods`** | **"Enables lod manager debug draw"** |

"Ambient lod" is the cheapest tier, and it matches the `ForceCombatSystemAmbientLOD` game context
noted in the very first research pass and never followed up. A soul in ambient combat LOD fights
without being fully simulated — the symptom exactly. And there is a distance modifier that applies
**only in battle**, which is the one qualifier every observation shares.

`merc_lod_cs` forces high LOD, neutralises the battle modifier, and pushes every distance tier to
500. `merc_lod_forcelod` is `wh_cs_ForceLod 0` alone.

### Stop inferring, start looking

`merc_lod_csdebug` enables `wh_cs_DebugDrawLods`, the LOD manager's own on-screen draw. Every
conclusion in this document so far has been inferred from Lua binds — `IsHidden`, `IsActive`,
heartbeats, position sampling — and several of those inferences were wrong. This renders the
engine's own view of each combat soul's LOD.

## Run 24: the dev build and the battle NPC cap

The dev build's log shows, dozens of times, a cycle that never appears in the release log:

```
Removing skirmish soul 'SpawnedFriend_strong_50615_…' from the skirmish
Soul SpawnedFriend_strong_50615_… disconnection from npc 1
Soul SpawnedFriend_strong_50615_… disconnection from npc 0
Connected to the soul NPC was created SpawnedFriend_strong_50615_…
Skirmish event: SoulAdded on SpawnedFriend_strong_50615_…
```

Our mercs' souls are repeatedly **disconnected from their NPC body and reconnected** — up to ten
cycles each in a single fight. `Changing skeleton for SpawnedFriend_… - will create new weapon
collisions` fires for all ten at once.

And the other side of the same mechanism, on a vanilla NPC:

```
Soul 'utokNaMalesov_malesovTowerShooter_2' is transformed to NPC.
Soul 'utokNaMalesov_malesovTowerShooter_2' is unregistered from battle automation.
Entity 'utokNaMalesov_malesovTowerShootersGroupController' has NO battle npc which can be transformed. Request is cancelled.
```

`CombatModule.dll` (the dev build ships separate module DLLs — far easier to search than the
monolithic release binary) contains:

| symbol / string | |
| --- | --- |
| `wh::combatmodule::C_BattleManager::RegisterNPC` / `UnregisterNPC` | the registry |
| **`wh_cs_BattleMaximumNPC`** | **"Maximum full and alive NPC on the battle field excluding player."** |
| `wh_cs_BattleMaximumDeadNPC` | "Maximum count of dead NPCs on the scene. When there is more the oldest will disappear." |
| `wh::combatmodule::SetBattleActualNPCLimit` | "Set NPC limit for battle. It is limit only for normal requests." |
| `wh::combatmodule::ResetBattleActualNPCLimit` | "Actual limit for battle NPC is reset so maximum allowed by cvar is used." |
| `C_BattleAutomationMissile::RegisterSoul` / `UnregisterSoul` | the lite-soul side |

So a battle has a hard cap on **full** NPCs. Souls beyond it live in battle automation: they
fight, deal damage and move, but have no NPC body — no render, no animation, no per-frame entity
update.

### This retro-explains every measurement

| observation | explained by |
| --- | --- |
| invisible but dealing damage | lite soul in battle automation |
| only in scripted battles | `C_BattleManager` only runs there |
| only *our* NPCs | we are the ones over the cap; quest NPCs registered first |
| a merc 8 s old is already hidden | it joins over the cap immediately |
| positions live, two mercs moved 14–18 m | the automation moves the soul |
| `Hide(0)`+`Activate(1)` gives a statue | un-hiding a body with no NPC driving it |
| recovers when the battle ends | the cap stops applying |
| LOD/clothing/dialogue/twins/deterrent/flags/VisArea all no-ops | none of them was ever involved |

`merc_lod_battle` raises `wh_cs_BattleMaximumNPC` (and the dead-NPC cap) to 60.

## Run 24b: a quest node that never ran

Running under the dev build (`KCD2Mod`) turns on `[Error]`/`[Warning]` logging, and it immediately
caught something the release build swallows:

```
[Error] <SetEntityContext> name:'mercenaries.kutnohorsko.mercenaries_background_quest.merc_preventDespawn'    required port 'IsActive' is missing
[Error] <SetEntityContext> name:'mercenaries.kutnohorsko.mercenaries_background_quest.merc_deterrenceImmunity' required port 'IsActive' is missing
```

**Both context nodes were rejected outright and never ran.** `IsActive` is marked
`IsAutoTriggerable="true"` in `definitions.xml`, from which I concluded it could be left unwired.
It cannot — it is `IsOptional="false"` and the engine requires an edge.

So **`deterrenceImmunity` was never granted**, and the run-15 conclusion that deterrent areas are
ruled out is void. That hypothesis is untested, not disproven — and it remains the only mechanism
found that specifically targets NPCs absent from a quest's hand-written soul list.

The fix is a bool `State` defaulting to true, wired into both nodes (the pattern vanilla uses, e.g.
`utils/general`'s `isA`):

```xml
<State Name="merc_alwaysOn" TypeT="bool">
    <Constant Name="DefaultValue" Value="true" />
</State>
...
<Edge From="merc_alwaysOn.State" To="IsActive" />
```

A bool `State`'s output port is `.State`. Applied to both quest copies.

### Always develop against the dev build

The release build logs none of this. Every Skald node the engine rejects, every malformed table,
fails silently. Other real defects it surfaced in the mod, unrelated to this bug:

| diagnostic | |
| --- | --- |
| `Missing column 'perk_name' in 'Libs\Tables\rpg\perk__mercenaries.xml'` ×2, `2 values are missing` | a genuine data error |
| `The attribute 'version' is missing in tag 'table' ('role__mercenaries.xml')` | malformed table header |
| `Config file 'mods/mercenaries/mod.cfg' not found!` | harmless, but easy to add |
| `STORM: Rule name 'rpg_socialClass_mercenary_extraMod' has no operations` ×2 | empty STORM rules |

## Open questions after run 3

Ranked by how much they would narrow things, all answerable in one session:

1. **`merc_lod_diff`** — every readable Entity property, merc beside a vanilla NPC that
   renders. Rows marked `**` are the entire remaining search space. Particularly: `flags` /
   `flagsExtended` (the `ENTITY_FLAG_*` bitmask, decoded from `_G` at runtime), `IsActive`,
   `GetScale` / `GetWorldScale`, `parent`, `bboxSize` — a degenerate world bbox is culled
   before any LOD logic runs — and `curAnimation`, since the run-1 T-pose says no animation
   was playing.
2. **Is a *freshly hired* merc visible in the battle?** `merc_lod_revert` then `merc_hire_p1`
   while standing there. Visible → the existing mercs carry broken state (stale area
   registration after a teleport, a leftover parent, a save/load artefact) and the fix is
   mod-side. Invisible → it is environmental and about how we spawn, not what happens later.
3. **Do they render if you walk out of the battle area and back?** Separates "this location"
   from "this quest state".
4. **`merc_lod_uberlodoff`** (`wh_cc_LodForUberlod` -1) — tests whether mod-assembled outfit
   combinations simply have no baked uberlod, so the character renders nothing once it
   switches to uberlod. Weakened by the fact that the battle's character-LOD cvars are
   effectively identical to the non-battle ones at this graphics spec
   (`e_LodFaceAreaTargetSizeCharacterWH` 0.003 vs 0.00305), but it is one cvar to rule out.
5. **`merc_lod_dissolve0`** — tests the confound introduced above.

## Candidate fixes, in order of expected payoff

Superseded by the open questions above — none of the render-side entries is actionable until
the diff narrows the search space. Items 1 and 2 below stand on their own merits regardless of
what causes the invisibility.

1. **Stop the load-time clothing burst.** Make `RebuildMercCache` *not* re-equip every merc on
   every load, or at minimum stagger the `EquipClothingPreset` calls over several seconds
   instead of firing all of them in one frame. Verify first whether clothing survives a
   save/load on a dynamically spawned NPC — if it does, the re-equip can go away entirely.
2. **Make the outfit variant deterministic** — hash the merc's entity name instead of
   `math.random`, the same trick already used for horse assignment. Fixes mercs changing
   clothes on every load, and lets step 1 skip work that is genuinely redundant.
3. **AI LOD**: `WH_AI_LOD_Areas` 2 → 0 is the interesting line ("0 - only distance is used for
   NPC LOD resolution"). The count-budget lines can be dropped given the census. Needs an
   isolating run with `merc_lod_areas0` alone to confirm it was the line that cleared
   `hidden=Y` in run 2.
4. **Behaviour flags**: all six modules already carry `PreventsMonsterLod`, which blocks
   MonsterLOD but **not** the Detail → LOD demotion. Worth confirming the mercs are running
   one of our behaviours mid-battle rather than a vanilla one, and investigating whether
   scheduler priority (see `npcSchedulerPriorityBoostPrevention`) biases them into Detail.

Only #1 and #2 are permanent, mod-side fixes; everything else is a cvar we would have to keep
re-applying.

**Caveat for anything cvar-based:** the CVarOverride system re-applies its `.cfg` whenever
the game context changes — the session log shows `Battle.cfg` loading mid-session — so
anything we set must be re-applied on a tick. The test sets do this every 5 s and log when
they catch a reset.

## Run 29: `merc_lod_guard_16` names the mechanism — AI LOD hides NPCs on purpose

`merc_lod_guard_16` (re-hide fight at ~every frame) produced: **visible, moving, but always
T-posed, sliding between positions like a fast slideshow.** Three symptoms in one, and each is
a documented engine behaviour. Found in `XGenAIModule.dll` and `AnimationModule.dll`:

| engine symbol | what it establishes |
| --- | --- |
| `wh::xgenaimodule::C_NPC::RequestHideByLOD` | the AI LOD system has a first-class *hide this NPC* path |
| `NPC::SwitchAIHide`, `"Changing hide to %s"`, `"Hide switching:"` | it is a tracked state transition, not a side effect |
| `NPC::SynchronizeAspectProfile` | the hide is applied as an **aspect profile** swap |
| `C_LODHideStatsDebug`, `E_LODState` | it is instrumented, so it is a normal operating mode |
| `C_LODAnimationController::SetLOD`, `S_LODScope`, `C_LODAnimationLocator` | a **fifth** LOD system: animation LOD, previously undocumented here |

The three cvars that gate it — none of which had been tested before run 29:

| cvar | help string |
| --- | --- |
| `wh_ai_LOD_Hide` | (help not positionally pairable; by name + `RequestHideByLOD`, the master switch) |
| `wh_ai_NPCHideCheck` | "Enables entity hide check in NPC in game. 0 - disabled, 1 - enabled, 2 - fully enabled (in editor as well)" |
| `wh_ai_NPCHidePPU` | "NPC Hide (Aspect Profile change) because of LOD will be executed in **actor pre physics update**." |

**Why this explains all three symptoms at once:**

* **Invisible** — `RequestHideByLOD` swaps the aspect profile; the render aspect goes away.
* **T-pose** — the animation LOD tier stops evaluating the skeleton. `ca_ForceUpdateSkeletons`
  exists precisely to override that for characters the engine believes are not visible.
* **Slideshow** — `wh_am_LOD_LocatorPeriodicalUpdate` is "Time period for updating **estimated
  entity location**", and `WH_AI_LOD_MLUseFakeMovementMinimalDistance` is "the minimal distance
  in which the **fake movement** is used in monster LOD". A LOD'd NPC is not animated and moved;
  it is teleported periodically to an estimate. That *is* a T-pose sliding between positions.
* **Still fights** — only the render and animation aspects are dropped. AI and combat are untouched.
* **`Hide(0)` will not stick** — `NPCHidePPU` re-applies it in the actor pre-physics update,
  i.e. every frame. Lua cannot win that race; at 16 ms we are merely tying it.

### `MaxCountLOD`, and a methodology note

`WH_AI_LOD_MaxCountLOD` = "The maximal amount of NPCs that are in LOD (NPCs in Detail don't count
to this limit, their budget is separate)." Warhorse's **own** anim-LOD test harness
(`InitLodAnims` / `TestLodAnimsHelper`) forces NPCs into LOD by doing exactly
`SetCVar WH_AI_LOD_MaxCountLOD` — it is the engine's canonical lever for this. Earlier runs
tested `MaxCountDetail` and `MaxDetailDistance`; **`MaxCountLOD` was never tested.**

Note the help strings in these DLLs are **not** positionally adjacent to their cvar names — the
two string runs are interleaved in different orders. Pair them semantically, and never quote a
help string as belonging to a name on adjacency alone. `wh_ai_NPCHidePPU` (PPU = pre-physics
update) claims the aspect-profile string; `wh_ai_LOD_Hide`'s own help is still unpaired.

### The diagnostic that ends the guessing

`WH_AI_LOD_DebugDraw_Who` = "NPCs who are drawn in LOD debug (they have colored cone above head
indicating their status: **green = detailed, red = LOD**)", with `WH_AI_LOD_DebugDraw_WhoType`
as flags: 1 SmartObjects, 2 PerceptibleVolumes, **4 NPC desired LOD**, **8 NPC consumed LOD**,
16 last streaming time, **32 MonsterLOD constraints**, **64 text summary on screen** (108 = all
four useful ones). Desired vs consumed is the decisive pair: a merc that *desires* Detail but
*consumes* LOD was **denied the tier for budget reasons**, which points at `MaxCountLOD`. Equal
values mean the tier was never requested, which points at our spawn path instead.

`wh_am_LOD_Debug` takes a comma-separated entity list and draws `AnimControllerLOD - <name> [n]`.

Commands: `merc_lod_nohide`, `merc_lod_hidecheck`, `merc_lod_hideppu`, `merc_lod_maxcountlod`,
`merc_lod_forceskel` (all single-cvar), and `merc_lod_aidraw` / `merc_lod_amdebug` to read tiers.

### Also cleared this run, at zero test cost

`combat_invisible` (script context, `SideEffect="combatInvisible"`) sounded decisive but all 75
vanilla uses are duel/fight-setup files (`duelspravidly.xml`, `arrangedduel.xml`,
`nastaveni_souboje_externi.xml`). It means invisible *to* the combat system — ignored as a
target. Our mercs deal damage, so it is not involved.

## Run 30: the red cone — AI LOD demotion confirmed by the engine's own draw

Session results (`merc_lod_aidraw` during utokNaMalesov):

* The merc's cone was **red (LOD tier) with occasional green flickers (Detail)**. Direct engine
  evidence: the AI LOD system demotes the mercs, and it is a *competition* they occasionally
  win — a green flicker is a freed slot. This **voids run 3's "AI LOD ruled out"** (bundled
  cvars, no pinning, no way to know the values survived).
* `wh_ai_LOD_Hide` is **not registered at runtime** (`nil -> nil DID NOT TAKE`) even in the dev
  build — string exists in the DLL, cvar does not exist in game. Dead end.
* `wh_ai_NPCHidePPU` was **already 0**. `wh_ai_NPCHideCheck` 1→0 took but was a one-shot with no
  pin and did not visibly help (already-hidden NPCs may simply stay hidden).
* `WH_AI_LOD_MaxCountLOD` shipped value is **400** — the run-29 command set 300, i.e. *lowered*
  it. Botch, fixed.
* The spawn-time equip storm (10 mercs re-equipped → 23 `Changing skeleton` lines) is confined
  to the spawn window; zero skeleton churn during the battle itself. Not the battle cause.

### The battle cfgs are innocent

`Battle.cfg`, `utokNaMalesov_battle.cfg`, `performanceDemandingArea.cfg`, `kutnohorsko.cfg`
contain **only renderer cvars** (merged meshes, LOD face area, shadows, cloth). Not one
`WH_AI_LOD_*` / `wh_cs_*` / `wh_rpg_*` line. Scripted battles do not demote NPCs via
CVarOverrides — the pressure is the shipped budgets themselves being saturated by the armies.

### The Skald theory, resolved

The full utokNaMalesov context census (42 `SetEntityContext` nodes) grants its soldiers
*nothing* render- or LOD-related — no such Skald node exists (consistent with the run-14 sweep
of all 559 soul-taking node types). The only "importance" context is `PerceptionPriorityBoost`
(Class="Relation", perception stimuli only). `ForceCombatSystemAmbientLOD` forces *down*, not
up. What quest soldiers actually have that mercs don't is structural: level-baked ProfileAsset
layers and battle-system membership give them standing claims on the Detail budget. "The game
renders the quest's souls and turns everything else off" is what a saturated Detail budget looks
like from the outside. `RequestBattleNPC` (the one battle BT node) is controllers *pulling* NPCs
from the pool, not a way to enrol one.

### The fix candidate: pinned budgets

`merc_lod_fix` pins (1 s enforcement loop, `LodPin`/`LodPinLoop`, logs every external reset):

| cvar | pinned | why |
| --- | --- | --- |
| `WH_AI_LOD_MaxCountDetail` | 400 | the Detail competition mercs are losing |
| `WH_AI_LOD_MaxCountLOD` | 1200 | LOD-tier overflow lands in MonsterLOD = virtual/invisible (matches the soul connect/disconnect cycling in the log) |
| `WH_AI_LOD_MaxNonMLDistance` | 2000 | distance that force-virtualizes regardless of budget |
| `ca_ForceUpdateSkeletons` | 1 | the T-pose: skeletons of "not visible" characters stop evaluating |

Singles for attribution: `merc_lod_detail`, `merc_lod_maxcountlod`, `merc_lod_nonml`,
`merc_lod_forceskel`, `merc_lod_areas` (LOD areas off), `merc_lod_hidecheck` (now pinned).
`merc_lod_pins` shows wanted vs current vs original; `merc_lod_fix_off` reverts all pins.

If `merc_lod_fix` works, the shippable version is a mod-side loop that pins these only while
mercs are deployed (and ideally scales with squad size), not a global forever-change.

## Run 31: budgets acquitted; the lite-soul model

`merc_lod_fix` pinned cleanly (`MaxCountDetail 70→400`, `MaxCountLOD 400→1200`,
`MaxNonMLDistance 600→2000`, `Areas 2→0`, `ca_ForceUpdateSkeletons 0→1`; **zero re-pin fights**)
and changed nothing. Decisive: with budget 400 vs 70 shipped, a merc merely losing a slot
competition would have been promoted. **AI LOD budgets, distances, and areas are all acquitted.**
Shipped values learned: MaxCountDetail 70, MaxNonMLDistance 600, Areas 2.

`DetailBehaviorBarrier` (18 vanilla uses) turned out to be a *gate* — vanilla wraps greetings/
dialog in it so they only run when already Detail. It reads `GetBehaviorLOD()`, never writes it.

### The lite-soul model (current best; explains everything)

`CombatModule.dll`:

| string | meaning |
| --- | --- |
| `Battle groups NPC: %d, Lite: %d (dead: %d), NPC Limit: Actual %d / Max %d, Requests: %d` | battle groups hold full **NPC**s and **Lite** souls, under an actor limit |
| `wh::combatmodule::C_LiteSoulBase::InternalHide`, `"Internal hide for lite soul %s with %d"` | **lite souls have their own dedicated hide path** |
| `"Actor for lite soul %s is destroyed."`, `OnBeforeActorRemove` | lite souls' actors are destroyed/recreated on demotion/promotion |

Model: in a battle-managed area the combat system owns rendering. Battle groups keep `NPC Limit`
full actors (roster members, level-baked via `battleGroupController` smart entities); every other
combatant soul is a **lite soul** — simulated, fighting, hidden by `InternalHide`. Our mercs are
`System.SpawnEntity` **shared-soul** spawns (`guidSharedSoulId`), on nobody's roster → lite.

Why it fits: invisible only in battle-managed areas (no battle manager elsewhere); still fight
(lite souls simulate); `Hide(0)` loses (InternalHide is authoritative); **soul
connect/disconnect cycling** on mercs (77× vs 1–7× vanilla) = lite-soul actor destroy/recreate;
no combat-LOD entry (run 26) = no full combat actor; `RequestBattleNPC` exists precisely to
promote ("Requests: %d").

Diagnostics/bisects added: `merc_lod_bdraw` (`wh_cs_BattleDebugDraw` — battle groups with NPC vs
LITE counts on screen, never used before), `merc_lod_battlemax` (**pin** `wh_cs_BattleMaximumNPC`
120 — run 25's 30→60 was unpinned and possibly stomped), `merc_lod_battledead` (dead-NPC budget).

On "replicate the level data": the battle roster lives in level-baked `battleGroupController`
smart entities — same class of dead end as cutscene assets (links bind at level bake). The
promotion path (`RequestBattleNPC`, NPC Limit) is the realistic lever, not roster membership.

## Run 32: the battle roster screenshot, and the soul combat simulator

`wh_cs_BattleDebugDraw` (screenshot) settled the lite-soul theory: **the mercs are in no battle
group at all** — not NPC, not Lite. The Lite bucket is roster members demoted (7 dead + one
distant tower shooter animated by trackview). `wh_cs_BattleMaximumNPC` pinned to 120 read
`Actual -1 / Max 120` — took, irrelevant. The battle system simply does not know our mercs exist.

Reading the log around the soul disconnects then produced the real model:

* The "new" merc names mid-battle are **not respawns** — no top-up spawner exists in the mod;
  names are baked at hire. `Connected to the soul NPC was created X` = the **engine destroying
  and recreating the actor** of a persistent entity.
* The message pair belongs to `wh::rpgmodule::C_SkirmishSoul::ConnectToLODState` /
  `DisconnectFromLODState` (SkirmishSoul.cpp) — skirmish souls bind/unbind an LOD state.
* RPGModule has a **soul combat simulator**: `wh_rpg_SoulCombatSimulatorMeleeTimeout` ("minimal
  timeout between attacks for melee weapon"), `MissileTimeout`, `MeleeMaxDistance`,
  `MinTimeout`, and `wh_rpg_SoulCombatSimulatorDebugDraw`. Souls without actors fight on timers.

**Model:** in scripted battles the mercs' skirmish souls run disconnected from their actors and
are fought by the simulator — hence real damage with no rendering, ragdoll (physics) working
while animation doesn't, and the T-posed mesh under the guard: the character render slot
survives (`char=Y` since run 2) while the actor behind it is torn down. Vanilla battle NPCs
are realized through the battle manager instead — which is what their combat-LOD entries
(run 26) actually are.

Open question, now measurable: *why* do merc souls keep choosing/being assigned the
disconnected state at 3 m from the player. Diagnostics added: `merc_lod_simdraw`
(`wh_rpg_SoulCombatSimulatorDebugDraw` — draws on simulator-fought souls) and
`merc_lod_souldraw` (`wh_rpg_DebugSouls` + `DebugSoulsStringFilter=SpawnedFriend` — per-soul
state incl. actor connection). If simdraw marks the mercs, the simulator is confirmed as the
fighting path and the fix hunt narrows to the connect decision in `ConnectToLODState`.

**Mod fix landed this run:** `PruneMercCache` now requires *confirmed* death (actor gone,
`IsDead()`, or a successful health read ≤ 0). Previously an unreadable soul — exactly what the
battle disconnect produces on a living merc — counted as dead, queueing a 10 s despawn of a
healthy fighter.

## Run 33: simulator unconfirmed; switching from theories to event tracing

`wh_rpg_SoulCombatSimulatorDebugDraw=1` took and drew **nothing** (on anyone), and
`wh_rpg_DebugSouls` showed merc soul stats indistinguishable from vanilla NPCs. The
soul-combat-simulator model joins the graveyard — or at least its debug draw doesn't fire in
this scenario, and there is nothing merc-specific at soul level that the soul debug surfaces.

Theory count now: AI LOD (budgets, areas, distances, hide gates), combat LOD, battle groups /
lite souls, skirmish passive bands, soul combat simulator, dialogue twins, deterrents, flags,
clothing, soul tables, Skald contexts — all measured, all acquitted for the *hide* itself.

**New approach: trace the event, not the system.**

> **Run 34 warning: `es_DebugEvents` hung the game** — it logs every event of every entity in
> the world and the I/O flood froze the process. Command removed; do not use the cvar directly.

Replacement, per-entity and safe: the engine dispatches `ENTITY_EVENT_HIDE`/`UNHIDE` to the
entity's own Lua script table as `OnHidden` / `OnUnHidden` (vanilla defines these in
`Scripts/Entities/…`; also on the `Client`/`Server` sub-tables, which we hook too).
`merc_lod_hidehook` installs loggers on every merc. Protocol for next battle session:

1. `merc_lod_hidehook` once the mercs exist (can be before the battle).
2. Enter the battle; let it run 30 s.
3. Optionally `merc_lod_guard_16` for one stretch: the guard's unhides force the hider to
   re-hide at frame rate, multiplying the logged events.
4. Grep the log for `OnHidden` — the engine lines immediately around each hit (same `<time>`
   prefix) fingerprint the hiding system directly.

Caveat: if the NPC entity class doesn't route hide events to script (possible — the vanilla
usages are props/audio entities), the hook logs nothing at all — that itself is a result, and
the fallback is `merc_lod_lodstats` (`wh_ai_LodChangeFrameStatsDebugDraw`, the draw
`C_LODHideStatsDebug` feeds — hide/LOD switch counts on screen).

**Run 34 result: exactly that caveat.** Hook installed on all 10 mercs, a full battle ran,
zero `OnHidden`/`OnUnHidden` events. The NPC class does not dispatch hide events to entity Lua
(script event masks are typically fixed at class registration, so instance-added handlers are
never called). Path closed; nothing learned about the caller.

## Run 35 (pending): read the AI LOD text panels, not just the cone

The aidraw session reported the cone colours but never the two readings that actually decide
things, both on-screen text that needs a **screenshot**:

* **desired vs consumed LOD** per NPC (`WhoType` flags 4+8, part of the existing 108) — desired
  ≠ consumed means the tier is denied (by what, the constraints panel may say); equal means the
  merc never requests Detail, pointing at our spawn/brain path.
* **`WH_AI_LOD_DebugDraw_Constraints`** — "statistics for active behaviors with MonsterLOD
  constraints" — newly added to `merc_lod_aidraw`.
* **`merc_lod_movedraw`** (`wh_ai_Lod_MoveDebugDraw` + `_FilterName` onto a merc) — draws the
  LOD/ML *fake movement* path. If it draws on a merc, MonsterLOD is confirmed as the state and
  the slideshow is exactly its estimated-location teleports.

## Run 35: the screenshot — MonsterLOD named, and the hibernation/wake machinery found

The (overlapping) panels delivered:

* Merc `SpawnedFriend_strong_10422…`: **`DesiredLOD: (Forced)MonsterLOD`, `MLConstraint: None`,
  `MLConstraintCause: N/A`** — the AI LOD system itself wants this NPC in MonsterLOD, and not
  via a behavior constraint. MonsterLOD = the virtual tier: hidden, fake movement, no skeleton —
  every symptom in one state. (Panels for desired/consumed/constraints stack at one anchor and
  overlapped; the `sleep`/`wakeUp`/`dummyWandererHorse` lines belong to a different NPC's panel.)
* Global stats: **`666 Forced to ML`** vs **`32 Forced from ML`** — 32 ≈ the battle roster.
  Something forces the region into ML and explicitly wakes only the quest's own souls. This is
  the original "the quest renders its souls and turns everything else off" theory, mechanised.
* `2236 MonsterLOD / 32 LOD / 10 Detail` — ML is where almost the whole world lives.

Engine strings pin the machinery (XGenAIModule):

* `NPC %s doesn't have scheduler subbrain! It will never be switched to MonsterLOD` — ML
  switching is scheduler-subbrain-driven.
* `NPC %s has requested Hibernation in MonsterLOD, but is also requested to be woken up…` —
  hibernate requests vs wake requests are the force pair.
* `HibernateInMonsterLod` / `PostponeByPlayerInMonsterLod` are **SmartBehaviorTemplate**
  attributes (`SmartEntity__so_additiveNPCs.xml`: `sleep` enabled-by-default, `wakeUp`
  disabled) — the "additive NPCs" (battle extras, cf. `kkut_additive_man_N` in the log) sleep
  hibernated in ML and are woken in waves. This is the background-army system.
* Our brain/AI tables contain **no** hibernate/additive/sleep behaviors (verified) — the force
  on mercs comes from outside their brain.
* Skald `HibernateMode="Script"` on Module/Gameplay nodes is quest-**graph** hibernation
  (`hibernovana_cast`), unrelated to NPC ML hibernation.

Next reads (split panels, one flag each): `merc_lod_aid_want` (desired), `merc_lod_aid_have`
(consumed), `merc_lod_aid_ml` (ML constraints) — screenshot each with a merc in frame, ideally
once **inside** the battle and once **in open world with mercs visible**. The contrast decides
whether the ML-desire is battle-scoped or permanent-but-overridden-elsewhere.

## Run 36: SOLVED IN PRINCIPLE — quest SoulAsset membership is the render gate

A merc soul injected into the Malesov quest's SoulAssets **rendered in the scripted battle**.
See [quest-override-test.md](quest-override-test.md) for the experiment, the result, and the
remaining bisect.

This vindicates the hypothesis stated in the very first message of the investigation — "in
quests, a lot of main quests have a sort of asset folder where souls of specific NPCs are listed,
it always seems that the game renders them and turns all other NPCs off" — which run 14 wrongly
dismissed. **Correction to run 14:** its sweep of 559 soul-taking node types asked "does any node
*force render*", found none, and concluded quests could not be responsible. Wrong question. No
node forces render; membership changes which souls the quest's *other* nodes act on, and that
(most likely via a MonsterLOD wake-up) produces the render. A negative result from a sweep bounds
what the sweep asked, not what the system does.

Lesson for this document: every "ruled out" above was ruled out against a specific mechanism.
None of them ruled out *quests*, and the run-14 entry should never have been written as though it
had.

## Run 37: the quest-TYPE mechanism — `ForceCombatSystemAmbientLOD`

The user's second hypothesis ("it's the quest *type*: mercs work in side quests that spawn
fighters, and break only in main quests") is **confirmed, with the mechanism**.

**Quest types.** The `<Quest>` node carries an optional `Type`: `Activity` (67), `Side` (66),
`Micro` (56), `Event`/`Main` (2 each, both dev test files), `Racing` (1) — and **100 with no
`Type` attribute at all, which is what a main story quest is** (`finale`, `pogrom`,
`kralovskeStribro`, `oblehaniSuchdole`, `sedmStatecnych`, `utokNaMalesov`…). Our
`mercenaries_background_quest` is `Type="Activity"`.

**The discriminating node is `SetGameContextPreset`** — used by 15% of main quests, 2% of Side,
**0% of Activity**. Malesov calls it 4× with the preset **`crime_global_battleInProgress`**,
which `Libs/Tables/ai/ScriptContextPreset.xml` expands (Class="Game") to:

```
crime_global_ignoreCombatSounds      crime_global_dontGreetPlayer
crime_global_ignorePlayersDrawnWeapon    NoDog
crime_global_ignorePlayerAiming      Battle                        <- loads Battle.cfg
crime_global_disableArrowTouchdownReaction
crime_global_disableArrowFlyByReaction   ForceCombatSystemAmbientLOD   <- THE ONE
crime_global_disablePlayerBioBarks
```

`ForceCombatSystemAmbientLOD` (Class="Game", SideEffect `forceCombatSystemAmbientLOD`) forces the
combat system to its **lowest** LOD tier, globally. Its cvar counterpart is `wh_cs_ForceLod` —
*"Forces combat LOD: 0..high, 1..med, 2..low"*.

**Usage is exactly the set of scripted battles**, and exactly matches "it's the same with all
scripted events":

| quest type | quests using `crime_global_battleInProgress` |
| --- | --- |
| main (no Type) | **12 of 100** — utokNaMalesov, utokNaNebakov, oblehaniSuchdole, nebakovObrana, zoufalaObranaZaBohutu, pogrom, finale, prepadeniVlasskehoDvora, rutinaAVypad, setkaniVRatbori2, posledniPomazani, hladAZmar |
| Activity | **0 of 67** |
| Micro | **0 of 56** |
| Side | 1 of 66 (predaniVChramu) |

**Why this explains everything.** Battle context → global ambient combat LOD. The battle's own
registered participants stay rendered (battle-manager roster, `wh_cs_LodBattleDistanceModifier`);
everything else falls to ambient. Our mercs were never battle-registered — run 26 found they have
no combat-LOD entry at all, and the run-32 battle-roster screenshot showed them in no battle
group. Side-quest brawls never set the preset, so mercs behave there. And the quest-override
experiment worked because SoulAsset membership made them quest participants.

**Next test:** `merc_lod_forcehigh` pins `wh_cs_ForceLod=0`. Unlike the ~40 cvars tried before,
this one is aimed at the exact named mechanism rather than at a guess. Caveat: if mercs are not
registered combat actors at all, forcing the tier may not reach them — which is itself the
answer, and points the fix at battle registration instead.

## Run 38: the quest-type change (current build)

`merc_lod_forcehigh` (`wh_cs_ForceLod=0` pinned) did **not** work, which retires the cvar approach
entirely — including the ambient-LOD counter that run 37's mechanism suggested. Knowing the
mechanism did not make a cvar able to reach an NPC the combat system never registered.

**Change made:** `mercenaries_background_quest` is no longer an Activity.

```xml
<!-- was --> <Quest Name="mercenaries_background_quest" Type="Activity" Players="0" Repeatable="true">
<!-- now --> <Quest Name="mercenaries_background_quest" IsLocked="false" Difficulty="22" ProductionCode="MERC1">
```

Applied to **both** region copies (`kutnohorsko/`, `trosecko/`); both still parse, as do all
parent files. This matches the vanilla main-quest shape exactly (cf. `utokNaMalesov`
`IsLocked/Difficulty/ProductionCode`, `pogrom` likewise) — main story quests carry **no `Type`
attribute at all**; `Type` is what marks Activity/Side/Micro/Racing.

No extra nodes were added, deliberately: the parent instantiation already matches vanilla
(`RequiredForOutput="kutnohorsko"`, same as `utokNaMalesov`), and — the point of the whole change
— **our quest already has a `mercs` SoulAsset listing all ~80 merc souls.** If quest *type* is
what makes SoulAsset membership count for rendering, that asset becomes a main-quest SoulAsset the
moment the `Type` attribute is gone, and no new nodes are required.

This unifies both experiments:

| quest | type | merc souls in a SoulAsset | mercs render |
| --- | --- | --- | --- |
| utokNaMalesov | main (untyped) | yes (injected) | **yes** |
| mercenaries_background_quest | `Activity` | yes (always had) | no |
| mercenaries_background_quest | main (untyped) | yes | **← this build tests it** |

The Malesov override was reverted so the test is clean; restore it with
`python tools/OverrideMalesovQuest.py --group ally` if a fallback is wanted.

**Watch for:** an untyped quest may now surface in the journal. Ours has no localized quest title,
so expect either no entry or a blank one — cosmetic, and fixable with a `Type`-less quest that is
never "started", but worth checking on the first load.

## Run 39: permanently in battle

Run 38's type change alone did not render the mercs. Retained anyway — it is a prerequisite, not
the whole mechanism, and it costs nothing.

**Added: the quest is now permanently in battle.** Main-quest battles are the only quests that
call `SetGameContextPreset` (15% of main quests, 2% of Side, **0% of Activity**), which is exactly
the line between "main quest battles where mercs vanish" and "side quest fights where they work".
Our background quest now sets a battle preset always-on:

```xml
<SetGameContextPreset Name="merc_permanentBattle" PositionY="4500" PositionX="300">
    <Constant Name="Preset" Value="mercenaries_permanentBattle" />
    <Edge From="merc_alwaysOn.State" To="IsActive" />
</SetGameContextPreset>
```

`IsActive` is wired to the existing always-true `merc_alwaysOn` bool State — an unwired `IsActive`
is silently rejected, which is how the two `SetEntityContext` nodes did nothing until run 24.

**We do not reuse vanilla's `crime_global_battleInProgress`.** It bundles
`ForceCombatSystemAmbientLOD` — the ambient-LOD force we identified in run 37 as what hides
mercs — plus `NoDog` and eight `crime_global_*` reaction suppressors. Set *permanently* those
would kill the dog companion and stop NPCs reacting to drawn weapons or greeting the player,
everywhere, forever. Instead `data/libs/tables/ai/ScriptContextPreset__mercenaries.xml` defines:

| preset | contents |
| --- | --- |
| `mercenaries_permanentBattle` | `Battle` only — the battle-mode context itself |
| `mercenaries_permanentBattleFull` | + the 5 harmless reaction suppressors, still **no** ambient-LOD force. Fallback if the minimal one is too little |

Applied to both region copies; all three files parse.

### Why the quest does not appear in the journal

A quest shows in the journal via a **`QuestVisual`** node fed by a **`State` of type
`wh::questmodule::QuestProgress`** (whose `SetActive`/`SetDone` triggers drive it). Ours has
neither, and no localized quest title. `QuestVisual` is used by ~8% of main quests and 0% of Side
quests, so its absence is why nothing shows — not the quest type.

The trigger source exists: the parent wires `<Edge From="OnWake" To="run" />` into our `run` In
port. So this would make it visible:

```xml
<State Name="merc_questProgress" PositionY="4650" PositionX="100" TypeT="wh::questmodule::QuestProgress">
    <Edge From="run" To="SetActive" />
</State>
<QuestVisual Name="merc_questVisual" PositionY="4650" PositionX="300">
    <Edge From="merc_questProgress.State" To="Progress" />
</QuestVisual>
```

**Deliberately not shipped in this build.** Two untested Skald changes at once means a failure
cannot be attributed — the same bundling mistake that made runs 26–29 unreadable. Add it once the
battle-context build is confirmed to load. Expect a blank journal title until a localized quest
name is added.

## Run 40: `Empty soul collection` — our quest's soul list is empty at runtime

The dev log carries two errors that reframe everything above:

```
[Error] <SetEntityContext> name:'...mercenaries_background_quest.merc_preventDespawn'    Empty soul collection.
[Error] <SetEntityContext> name:'...mercenaries_background_quest.merc_deterrenceImmunity' Empty soul collection.
```

> **Correction, same run.** I first read this as proof that our soul nodes never resolve. It is
> not. **Vanilla produces the identical error two lines above ours** —
> `Barbora.trailers.fightconfiguration_surrendering.setentitycontext1_1  Empty soul collection.`
> — and each message appears exactly **once**, during load. It means "this collection was empty at
> this instant", not "this node is permanently dead". Vanilla ships with it. Treat the rest of
> this section as a hypothesis about *timing*, not an established defect.

The GUID list is not malformed — **79 of the 83 GUIDs in the `mercs` SoulAsset resolve to real
`soul_id` rows** in `soul__mercenaries.xml` (the 4 strays are custom-companion souls defined
elsewhere). The plausible reading is a timing one: a `SoulAsset` resolves against souls that exist
when the node evaluates, the quest evaluates at `OnWake` (level load), and our mercs are spawned
at runtime long after. Vanilla quest souls are level-baked and already exist at that moment.

If that timing story is right it would also explain why the Malesov override worked — that quest
is long-running and re-evaluates *during* the battle, when the merc does exist.

**Addressed by re-resolution, not by a Lua bool.** There is no clean Lua→Skald channel: the mod's
own [bridge guide](general/lua-skald-communication.md) documents inventory tokens for
Skald→**Lua** only, and the console-execution node is vestigial. The vanilla-idiomatic equivalent
is a self-restarting `Timer` whose `Running` bool drives `IsActive`, so it drops and rises instead
of latching once:

```xml
<Timer Name="merc_resolveTimer">
    <Constant Name="Duration" Value="30s" />
    <Constant Name="TimeType" Value="GameTime" />
    <Edge From="run" To="SetRunning" />
    <Edge From="merc_resolveTimer.OnFinished" To="SetRunning" />   <!-- self-restart -->
</Timer>
```

Both `SetEntityContext` nodes now take `IsActive` from `merc_resolveTimer.Running`;
`SetGameContextPreset` deliberately stays on the latched `merc_alwaysOn` (the battle context
should not flicker). Port names verified against vanilla usage: Timer exposes `OnFinished` (910
uses) and `Running` (422); bool States expose `SetTrue`/`SetFalse`.

**Unverified:** whether `Running` actually dips observably when `OnFinished` restarts the timer in
the same frame. If it does not, the pulse is a no-op — visible as the `Empty soul collection`
error never recurring, versus recurring every 30s while no mercs exist. That log line is now a
useful probe rather than a red herring.

**Tradeoff:** a momentary gap in `crime_preventDespawn` / `deterrenceImmunity` each cycle.

### Journal visibility (shipped this build)

Added to both region copies:

```xml
<State Name="merc_questProgress" TypeT="wh::questmodule::QuestProgress">
    <Edge From="run" To="SetActive" />
</State>
<QuestVisual Name="merc_questVisual">
    <Edge From="merc_questProgress.State" To="Progress" />
</QuestVisual>
```

`run` is fed by the parent's `<Edge From="OnWake" To="run" />`. The bare-port edge form is vanilla
syntax (15 uses of `<Edge From="activate" To="SetActive">`). Expect a blank title until a
localized quest name exists — the entry appearing at all is the signal that the quest loads and
its `run` port fires, which also confirms whether `SetGameContextPreset` ran.

## Run 41: we have been reading a stale log — and the revert

**The quest stopped running entirely after the run-40 build, and there was no diagnostic, because
`KCD2Mod\kcd.log` had not been written since 26 July.** Cause:

* `PackageMod.bat` deploys to `KingdomComeDeliverance2\Mods\` and launches the **release** exe
  (`Win64MasterMasterSteamPGO\KingdomCome.exe`).
* The release build **silently swallows rejected Skald nodes** — a broken quest simply stops
  working, logging nothing.
* The dev build's copy of the mod (`KCD2Mod\Mods\mercenaries`) was last updated **26 July**, so
  every "check the log" round since then read an artefact of that old session.

Several conclusions in runs 33–40 were drawn from that stale file. Anything cited from a log
between those runs should be re-verified.

**Fix: `PackageModDev.bat`** — same pak, deployed to `KCD2Mod\Mods\`, launches the dev exe, and
deletes the old `kcd.log` first so the next run is unambiguous. Use it whenever a quest change
misbehaves; the dev build names the failing node.

### Reverted this run

The run-40 additions are removed from both region copies (files re-validated):

* `QuestVisual` + `State TypeT="wh::questmodule::QuestProgress"` — the likelier culprit. It only
  ever appeared in `Testing/` quests, which was a weak basis to ship on.
* The `merc_resolveTimer` pulse; both `SetEntityContext` nodes are back on latched
  `merc_alwaysOn.State`.

**Kept** (these loaded in the previous build): the quest-type change and the `SetGameContextPreset`
+ `ScriptContextPreset__mercenaries.xml` battle preset.

If the quest still does not run, the remaining suspect is the battle-preset node — most likely
because the `__mercenaries` suffix-merge convention may not apply to `ScriptContextPreset.xml`,
leaving `mercenaries_permanentBattle` undefined. Deleting the `<SetGameContextPreset
Name="merc_permanentBattle">` block from both quest files isolates that.

## Run 42: the `Battle` context kills all dialog — and that was the earlier "breakage" too

Dev-build run of the permanent-battle build reported: **all NPC dialog disabled**, quest otherwise
loading fine.

**This retro-explains run 41.** "The quest no longer runs at all" was almost certainly this same
dialog kill, not a syntax error — hire dialog, quartermaster and the gossips all go dead, so the
mod *reads* as broken while the quest is loading perfectly. `QuestVisual` and the resolve-timer
were probably innocent, and run 41 reverted them on a wrong hunch. Restored this run.

**What it proves (new capability, worth keeping):** the preset resolved and the context applied, so
a mod **can** define its own Game-class context preset and set it from its own quest —
`ScriptContextPreset__mercenaries.xml` merged via the `__modname` convention, and
`SetGameContextPreset` executed. That is a reusable tool.

**Why it is not usable here:** `Battle` (Class="Game", SideEffect="battle") suppresses dialog
globally — correct behaviour for a real battle, unacceptable as a permanent state. And it did not
render the mercs, so the battle-context theory is dead for this problem regardless.

**Current state of `mercenaries_background_quest`:**

| change | status |
| --- | --- |
| quest type: `Type="Activity"` removed → main-quest shape | kept |
| `SetGameContextPreset` / permanent battle | **removed** (killed dialog) |
| `ScriptContextPreset__mercenaries.xml` | kept, unused, documented as a working reference |
| `QuestVisual` + `QuestProgress` state | restored |
| `merc_resolveTimer` pulse | still out — re-add only if a specific need appears |

Diagnosis is now cheap: `PackageModDev.bat` gives a fresh `kcd.log` that names any failing node.

**The one lead with a proven result remains the SoulAsset injection.** Next concrete step is the
bisect that identifies *which* node grants the render:

```
python tools/OverrideMalesovQuest.py --assets "^(zizka|sam|hans|komar|ptacek|cert)$"
```

## Run 43: it is not a rendering bug — the battle never engages our mercs

The bisect closed the question and pointed somewhere else entirely.

| injection scope | result |
| --- | --- |
| all 137 SoulAssets | **rendered**, and fought for the garrison |
| 6 named companions (ally) | invisible |
| 64 ally-side assets | invisible |

Ally membership is not sufficient. What rendered him in the first run was ending up on the
**garrison** side — i.e. being someone the battle actually fights.

**Measured from the existing logs, at no cost:**

| | count |
| --- | ---: |
| vanilla battle NPCs targeting our mercs | **0** |
| our mercs targeting vanilla battle NPCs | **40** |

The defenders only ever target the quest's own souls and the player — `Dude`, `tneb_zizka`,
`tkop_ptacek`, `tneb_bohuta`, `kkut_samuel`, `kcer_brabantSoldier_*`, `kcer_suchyCert`,
`kpri_komar`. **The combat is one-sided: our mercs attack the battle, and the battle cannot see
them as targets at all.**

That single fact explains every measurement in this document. An NPC nobody is fighting is not a
combat participant, so it never gets a combat actor — which is exactly run 26's finding that mercs
have **no combat-LOD entry**, and run 32's finding that they are in **no battle group**. No combat
actor means no combat LOD tier, which means ambient/MonsterLOD, which means invisible. The
invisibility is a *symptom of never being engaged*, not a LOD bug. Thirty-odd runs were spent
tuning LOD systems that were behaving correctly.

### Why the battle cannot see them: faction relations are one-directional

`FactionTree__mercenaries.xml` declares `mercenariesFaction` hostile (`-1`) toward
`kutnohorsko_enemies`, `players_enemies`, `trosecko_enemies` and so on — so our mercs attack them.
**No vanilla faction declares any relation to `mercenariesFaction`: zero references in the entire
vanilla `FactionTree.xml`.** The hostility exists only in our direction.

The corroborating detail: our own `enemiesFaction` *does* declare
`<Relation target="mercenariesFaction" reputation="-1" />`, which is precisely why mercs work
against the mod's own enemy groups and in side-quest brawls, but not against a vanilla army.

### The fix under test

`FactionTree.xsd` has no `parent` attribute, so nesting our faction under a vanilla one would mean
re-declaring the vanilla faction and risking the loss of its children. The safe lever is the
soul's own `factionName`:

* **84 merc souls** moved from `mercenariesFaction` to **`players_friends`** — the faction whose
  members (`players_friends_zizka`, `_bohuta`, `_ptacek`) the Malesov garrison demonstrably *does*
  target.
* `enemiesFaction`'s stance toward `players_friends` flipped `1` → `-1`, so the mod's own enemy
  groups still engage the mercs.

No vanilla table is modified. Revert by swapping `factionName="players_friends"` back to
`factionName="mercenariesFaction"` in `soul__mercenaries.xml` and restoring the `1`.

**Watch for:** `players_friends` membership may carry side effects (companion or quest-specific
handling) for 84 souls. If mercs start being treated as story companions, a dedicated faction with
explicit reverse relations is the fallback — at the cost of having to re-declare vanilla factions.

## Run 44: `QuestVisual` kills the entire mod quest tree

The dev build named it in one line, which is the whole argument for `PackageModDev.bat`:

```
[Error] Object factory was not able to create new '...mercenaries_background_quest::QuestVisual'
DeserializeObject returned invalid object for node 'mercenaries_background_quest' of type 'Quest'
[Error] Object factory was not able to create new '...mercenaries_background_quest'
[Error] Object factory was not able to create new '...kutnohorsko'
[Error] Unable to load concept graph xml Quests/mercenaries.xml
```

**`QuestVisual` cannot be instantiated at runtime, and the failure cascades: node → quest → level
→ the whole `Quests/mercenaries.xml` graph.** One unusable node takes down every dialog, bark and
context the mod has. It appears only in `Testing/` quests in the shipped data, which was the clue
— it is editor/test-only. **Do not use `QuestVisual`. There is no known way to give a mod quest a
journal entry.**

This also settles the run 41/42 confusion: run 41 blamed `QuestVisual`, run 42 talked itself out of
that and re-added it, and the quest died again. Removed for good from both region copies.

### State after this run

| change | status |
| --- | --- |
| quest type → main-quest shape (no `Type`) | kept — loads fine |
| `SetGameContextPreset` permanent battle | removed (run 42: disabled all dialog) |
| `QuestVisual` + `QuestProgress` | **removed — this was killing the quest tree** |
| souls `mercenariesFaction` → `players_friends` | **in place, still untested** |

The faction test from run 43 was never validly exercised: with the quest tree dead there were no
hire dialogs, so the engagement change could not be judged. Retest now.

### Also fixed

`mod.cfg` was missing, logging `[Error] Validator: Config file 'mods/mercenaries/mod.cfg' not
found!` on every launch for the whole investigation. Added at repo root and both packagers now copy
it. It is also the supported place to set cvars persistently — the thing that would have survived
the CVarOverride re-application that defeated console changes — though no cvar ever fixed this bug.

## Untested / unknown

* Whether a mod can ship its own `Config/CVarOverrides/*.cfg`. `CVarOverride.xml` lives in
  `Data/Libs/Tables/` (moddable) but the `.cfg` files live in `Engine/Engine.pak` under the
  engine root, not under `Data/`. Unverified whether the loader resolves the override file
  through the mod-mounted filesystem.
* Whether any of these cvars are flagged `VF_CHEAT` / require a level reload — `System.SetCVar`
  may silently fail on some of them.
* The engine defaults for the `wh_cc_*` and `WH_AI_LOD_*` cvars: they are compiled in, not in
  any shipped `.cfg`, so they can only be read from the in-game console.

---

## Why the AI-LOD boost alone "did nothing"

Two things, found together on a live dev log during the siege of Raborsch.

**1. `WH_AI_LOD_*` is simulation, not rendering.** The boost raised the AI Detail budget and
the log confirmed it took (`Detail 70 -> 300`), yet nothing looked different — because how
well an NPC is *simulated* has no bearing on whether he is *drawn*. The same log measured
`e_ViewDistRatio = 50` and `e_LodFaceAreaTargetSizeCharacterWH = 0.00305`: the renderer was
culling and coarsening the men on the far wall regardless of how many Detail slots the AI had.
Section 4's levers are now in `LodBoostCvars` alongside the AI ones.

**2. Setting a cvar once is not enough.** `Libs/Tables/CVarOverride.xml` maps a game context to
an override file *with a priority*, and entering one re-applies its numbers over the top of
ours — `performanceDemandingArea.cfg` alone clamps `MaxDetailDistance=150`, `MaxCountDetail=70`
and `e_ViewDistRatioCustom=80`. A boost applied once survives only until the next context
change, which in a battle is immediately. `LodBoostReassert` now re-applies every tick while
boosted.

**Raising the numbers is not the fix.** 300/1000/400 was tried and was visibly *worse* than
150/600/250: every Detail slot is full AI simulation, and the framerate cost exceeded what the
demotions cost in fidelity.

---

## Not everything that looks like LOD is LOD

A long hunt for "30% of a battle just stands there" ended nowhere near this document. The
cause was in the log, in plain words:

```
[DrawAction]: Can't execute explicit DrawAction for selected weapon set which contains no weapons!
```

`EquipEnemy` picks a weapon CATEGORY and lets the engine fill it. When the category yields
nothing for that character the man gets an EMPTY weapon set, `combat_melee` dies at the draw,
and he stands in the open being hit — with a valid target, fully simulated, perfectly visible.
23 such errors against 75 men is the 30%.

Wrong turns worth not repeating:

* **`npc_basic_scheduler` in an AI error path is not a bug.** It is the base subbrain every NPC
  runs under, mercs included. It does not mean the mod's scheduler was bypassed.
* **Raising `MaxCountDetail` does not fix responsiveness** and 300 measurably hurt.
* **Mesh detail and AI tier are different systems.** `wh_cc_LodForUberlod` = -1 does not force
  the cheap mesh, it disables the swap, and with one already loaded both versions draw at once.
* **Read the error text before theorising.** Four rounds of LOD, camp-role and targeting work
  went by while the answer sat in one line of the dev log.
