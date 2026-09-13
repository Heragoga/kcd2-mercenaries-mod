# Combat movement

How an NPC decides **where to stand and how fast to get there** while fighting, read
out of `WHGame.dll` (build `release_1_5_1308617_856`) — and how much of it a plain
data mod can change. The combat movement system is almost entirely data-driven through
console variables, about a thousand of them, and `System.SetCVar` reaches every one
from Lua.

**The headline result is negative.** Turning all of it towards a Bannerlord-shaped
melee — everyone engages at once, nobody queues, charges instead of a walk-up — was
built, run in a real fight, and made **no perceptible difference**. The parameters are
reachable and genuinely read; they are not what produces the feel. Read
[It was built, measured, and pulled](#it-was-built-measured-and-pulled--read-this-before-rebuilding-it)
before spending time on this again. Everything above that section is still accurate as a
map of the system, and the cvar tables are still the reference for what each knob is.

This is the movement half only. Who an NPC picks to fight is
[combat target selection](combat-target-selection.md); which tree fires is
[AI modules](ai-modules.md).

---

## The five layers

An NPC in a fight is being driven by five systems stacked on top of each other. Naming
them is most of the battle, because the tuning knobs are split across them and each
layer uses its own vocabulary.

| Layer | Owner | What it decides |
|---|---|---|
| Behaviour tree | `CombatMoveDecorator`, `CombatFollowerDecorator`, `CombatAction` | *that* this NPC is in combat locomotion at all, and against whom |
| Combat automation | `wh::combatmodule::C_CombatAutomation*` — `Guard`, `Attack`, `Defense`, `ZoneChange`, `Weapons` | when to swing, when to raise guard, when to change attack zone; caps combat speed |
| Combat movement | `wh::xgenaimodule::C_CombatMove` | the **sweet spot** — a point on an arc around the target — plus circling, repulsion, slope cuts, speed tier |
| Follower / path | target follower, formation follower, MNM pathfinding | actually walking to the point |
| Locomotion | Mannequin `CombatMovement` fragments, `combat_action_guard_movement` table | which animation plays for that velocity |

The mod already touches layers 1 and 4 (`combat_melee.xml`, `docs/formations.md`).
Layers 2 and 3 are where the "feel" lives and neither had ever been looked at.

### The sweet spot

The single concept worth understanding. Every combat mover holds a **sweet spot area**:
a point at a preferred distance from its target, on an arc `MinArcRange`..`MaxArcRange`
(35°–50°) to one side of the target's facing, not on top of it. The follower walks to
that point; the NPC attacks when it is in it.

Multiple attackers do **not** queue for one spot. Each gets its own arc position, and
`ForeignTargetRepulsion` pushes attackers apart so they spread around the target rather
than stack. Past `TacticalSurround` attackers on one victim, the ring is widened by
`TacticalRangeGain` so the extra bodies fan out instead of jamming. So the engine will
already surround — the reason it does not *look* like a mob is the next section.

The BT nodes that read this: `IsInSweetSpotRange` (used by vanilla), and
`ManualSweetSpotBias`, `SweetSpotLockPolicy`, `SweetSpotLateralBounce`,
`SweetSpotDorsalBounce` — which exist in the binary and are **used by nothing in the
shipped trees**, so they are untested but available.

---

## Why vanilla combat feels polite

Four separate mechanisms, all data:

**1. Attackers throttle each other, on purpose.** Two RPG constants:

| Constant | Effect |
|---|---|
| `CombatAutoAttackDelayIncreasePerAttacker` | every extra attacker on a target adds to *everyone's* delay before their next swing |
| `CombatAutoMoveActivityDecreasePerAttacker` | every extra attacker lowers each attacker's **movement activity** |

That is the "wait your turn" rule, and it is explicitly scaled by crowd size. The more
of your men pile onto one bandit, the slower each of them fights.

**2. Movement activity gates circling.** Activity is a 0–1 per-fighter scalar (from
combat level / skill / HP, then decreased by rule 1). Below
`CirclingLowestMovementActivity` (0.25) there is **no lateral movement at all** — the
NPC just stands. Above it, activity scales the probability of choosing to move rather
than wait, capped at `CirclingChooseMoveMaxProb` (0.6). When "wait" wins, the NPC holds
still for `CirclingWaitingDurationMin`..`Max` — **1.2 to 5.0 seconds**. That is the
standing-around.

**3. Guard caps the speed.** Once in guard (weapon up, opponent locked)
`wh_cs_AutomationAction_GuardMaxSpeed` clamps movement to **2.9 m/s**, and
`ToGuardFactor` feeds a further slowdown as they enter it. Guard engages
`GuardEnableTimeout` = 300 ms after it is requested and takes `GuardDisableTimeout` =
1000 ms to let go. NPCs approach at a jog, never a charge, and once guard latches they
cannot accelerate out of it for a second.

**4. Repulsion keeps them apart.** `ForeignTargetRepulsion` (0.6) is an explicit
repulsor placed between the target and every *other* attacker;
`DestinationRepulsionThreshold` will stop a path outright if the destination is too
crowded. Tuned for duels, it reads as reluctance in a melee.

---

## The control surface

### Console variables — the big one

**Every `WH_AI_*` "AI attribute" is a real console variable.** They are registered
through `IConsole::Register` (slot `0x48` for float, `0x40` for int) from
`sub_14DF3B8`, the XGenAI module init; the registration takes the compile-time value
sitting in `.data` as the default. They carry `VF_CHEAT` (flags = 2), and in practice
that does not stop a write — but **not** because nothing checks. `System.SetCVar`
(`CScriptBind_System::SetCVar`, `sub_39ABA78`) resolves the name with `GetCVar` and calls
`ICVar::Set`; the check lives *inside* `Set`, which asks `CXConsole::vf74`
(`OnBeforeVarChange`) for permission and skips the write if refused. That gate tests
`flags & 0x3000002` (cheat), `0x800` (readonly) and `0x40000000` (deprecated), and is
bypassed wholesale when `CXConsole+0x1DE` is set. On this build it does not fire: a
session that set 20 of these cvars produced **zero** `[CVARS]: [IGNORED CHANGE]` lines,
which is what a refusal logs (`sub_5F99B8`). The mod sets cvars routinely — see
`mercenaries_lodboost.lua`, which reads back with `GetCVar` and only writes on a
difference.

Same for the ~400 `wh_cs_*` combat-system cvars (`sub_10A8DA0`) and the ~330
`ai_*` / `wh_ai_*` CryAI ones (`CAISystem_RegisterCVars`).

Movement knobs that matter, with **stock values read out of the DLL image**:

| Cvar | Stock | What it does |
|---|---|---|
| `WH_AI_CombatMove_CirclingWaitingDurationMin` | 1.2 | shortest stand-still during circling (s) |
| `WH_AI_CombatMove_CirclingWaitingDurationMax` | 5.0 | longest stand-still during circling (s) |
| `WH_AI_CombatMove_CirclingChooseMoveMaxProb` | 0.6 | max probability of moving instead of waiting |
| `WH_AI_CombatMove_CirclingLowestMovementActivity` | 0.25 | below this activity, no lateral movement at all |
| `WH_AI_CombatMove_CirclingDirectionDurationMin` / `Max` | 0.6 / 1.5 | how long one circling direction is held (s) |
| `WH_AI_CombatMove_TacticalSurround` | 5 | how many attackers before the ring is grown |
| `WH_AI_CombatMove_TacticalRangeGain` | 1.0 | how much is added to the ring |
| `WH_AI_CombatMove_TacticalFollowersUpdate` | 1000 | how often the ring is recomputed (ms) |
| `WH_AI_CombatMove_ForeignTargetRepulsion` | 0.6 | repulsor between the target and each other attacker |
| `WH_AI_CombatMove_DestinationRepulsionThreshold` | 2.0 | repulsion that stops a path-follow outright |
| `WH_AI_CombatMove_DestinationRepulsionAlliesOnly` | 1 | only count our allies as repulsors |
| `WH_AI_CombatMove_MinArcRange` / `MaxArcRange` | 35 / 50 | sweet-spot arc angle range (deg) |
| `WH_AI_CombatMove_ApproachOffset` | 6.0 | distance from the sweet spot where approach becomes engage (m) |
| `WH_AI_CombatMove_AccelerationLimit` | 5.0 | how fast combat velocity may change (m/s²); horse 14.0 |
| `WH_AI_CombatMove_ToGuardFactor` | 1.0 | factor in the guard slowdown equation |
| `WH_AI_CombatMove_GuardEnableTimeout` | 300 | delay before guard turns on (ms) |
| `WH_AI_CombatMove_GuardDisableTimeout` | 1000 | delay before guard turns off (ms) |
| `WH_AI_CombatMove_ReactionMinTime` / `MaxTime` | 100 / 400 | smoothing of the target's position per attacker skill (ms) |
| `WH_AI_CombatMove_ForceKeepDistance` | 0 | force keep-distance mode |
| `WH_AI_CombatMove_InfrontCut` / `BehindCut` | 1 / 1 | cut movement in front of / behind the target |
| `WH_AI_CombatMove_TurnAngleRotationMax` | 1.9 | max turn rate while following (rad/s) |
| `wh_cs_AutomationAction_GuardMaxSpeed` | 2.9 | **hard speed cap while in guard (m/s)** |
| `wh_cs_AutomationAction_GuardMinAtkDist` | 2.0 | min attack distance for guard automation (m) |
| `wh_cs_AutomationAction_GuardUpdateInterval` | 0.1 | guard decision tick (s) |
| `wh_cs_AutomationAction_AttackImmediateDistance` | 0.8 | inside this, attack immediately (m) |
| `wh_cs_AutomationAction_AttackUpdateInterval` | 0.2 | attack decision tick (s) |
| `wh_cs_AutomationAction_MaxDistanceForTarget` | 60.0 | beyond this a target is dropped (m) |
| `wh_cs_AutomationAction_HuntAttackDist` | 10.0 | running attack ("hunt attack") trigger distance (m) |
| `wh_cs_EnableCombatGroups` | **0** | combat groups, shipped off — unexplored |

Two cautions on the values above:

* About a dozen `WH_AI_CombatMove_SweetSpotArea_*` params sit in the **uninitialised**
  tail of `.data`, so they read as 0 in the image. Their real defaults are assigned at
  runtime and are **unknown** — read them back with `System.GetCVar` before touching
  them.
* The `WH_AI_CombatMove_SprintFactorMax` / `RunFactor*` / `WalkFactor*` / `ObstacleWeight`
  / `HistoryWeight` / `TConstant` family appears **only in the shutdown path**
  (`sub_30AAFF0` calls `IConsole::UnregisterVariable` on them) with no registration
  anywhere. They are probably dead names from an older build. Check with `GetCVar`
  before planning around them.

### RPG constants — `rpg_param`

`wh::rpgmodule::Constants` is a reflected struct: `sub_CE3F40` binds each constant name
to a field offset, and `Libs/Tables/rpg/rpg_param.xml` fills them in by name. Keys
absent from the table keep a compiled default. These four are **absent**, so they run on
compiled defaults today and a mod row would be a clean insert:

```
CombatAutoAttackDelayIncreasePerAttacker
CombatAutoAttackDelayIncreasePerAttackerHorse
CombatAutoAttackDelayIncreasePerAttackerMissile
CombatAutoMoveActivityDecreasePerAttacker
```

Also there: `CombatAutoMoveProficiencyHPCoef` / `SkillCoef` (what feeds movement
activity), `CombatMoveApproachSprintMinStamina` (stamina needed to sprint an approach),
`CombatMovePlayerSecondaryAttackerSpeedMultiplier` / `HuntMultiplier` /
`OuterCircleTolerance` (how the *second* attacker on the player behaves). `CombatAutoMaxAttackDelay`
(= 2) **is** authored, which is the proof the route works.

The mod's table convention is the `__mercenaries` suffix — a
`data/Libs/Tables/rpg/rpg_param__mercenaries.xml` merges rows into the base table
exactly like `soul__mercenaries.xml` does. **Unverified for `rpg_param` specifically**:
confirm in game before relying on it.

### Behaviour tree

`CombatMoveDecorator` is what puts an NPC into combat locomotion — the mod learned this
the hard way, see the comment block in `data/AI/combat_melee.xml`. Below it,
`CombatFollowerDecorator ProbablisticDrivenSweetSpot="true" RPGSweetSpotArcDriver="true"`
is the only shape vanilla ever uses (37 occurrences, always identical). Setting either
to `false` hands the sweet spot to a non-probabilistic / non-RPG driver — untested, and
the most interesting single experiment available, because `RPGSweetSpotArcDriver` is the
hook through which combat level reaches positioning.

`MeleeGuardAutomationDecorator GuardMode=` takes `automate` or `forceEnable` (those are
the only two values vanilla uses). There is no `forceDisable` in shipped data, so
"charge with the weapon down" is not obviously available from the enum.

### Mod Lua

Worth remembering before blaming the engine: the mod adds **its own** politeness on top.
`TryClaimTarget` in `mercenaries_target_selection.lua` refuses a claim past
`EffectiveSwarmCap`, and on the default `balanced` aggression preset that is 2 men per
enemy with a hard ceiling of 10. Any Bannerlord experiment has to lift that first or the
engine changes will not be visible on the company — set the aggression preset to **"Swarm
them"** (`loose`: 3 / 7 / 16) from the order wheel. Enemy-side AI is unaffected by it, so
an engine change shows up on *them* either way, which is a useful A/B in itself.

---

## Making it Bannerlord-shaped

The plan, in order of expected impact. None of it needs native code — and **all of it was
tried and none of it was felt**; see the postmortem straight after. It is kept here
because it is still the correct reading of which knob does what, and because the next
person to have this idea should be able to see exactly what was already swung at.

**1. Kill the crowd throttle** (`rpg_param__mercenaries.xml`): set
`CombatAutoAttackDelayIncreasePerAttacker` and `CombatAutoMoveActivityDecreasePerAttacker`
to 0. This alone is the difference between "three men take turns" and "three men all
swing".

**2. Stop the standing about** (cvars): `CirclingWaitingDurationMax` 5.0 → ~1.0,
`CirclingWaitingDurationMin` 1.2 → ~0.3, `CirclingChooseMoveMaxProb` 0.6 → ~0.9,
`CirclingLowestMovementActivity` 0.25 → ~0.05.

**3. Let them charge** (cvars): `wh_cs_AutomationAction_GuardMaxSpeed` 2.9 → 4.5–5.5,
`AccelerationLimit` 5 → 8, `ToGuardFactor` 1.0 → ~0.5, `GuardEnableTimeout` 300 → ~800
so guard latches late and the approach stays fast. Consider
`CombatMoveApproachSprintMinStamina` for a real sprint-in.

**4. Let them mob** (cvars): `TacticalSurround` 5 → 8–10, `ForeignTargetRepulsion`
0.6 → ~0.25, `DestinationRepulsionThreshold` 2.0 → ~4.0 — and set the company's own
aggression preset to "Swarm them", or its anti-swarm cap will keep refusing the claims.

**5. Tighten reactions** (cvars): `ReactionMaxTime` 400 → ~200,
`wh_cs_AutomationAction_AttackUpdateInterval` 0.2 → ~0.1,
`GuardUpdateInterval` 0.1 → ~0.05. Costs CPU; measure.

**6. Formations for the approach.** Line up and walk in as a formation, break to
`combat_melee` on contact. The formation half is already built and documented in
[Formations](formations.md); `WH_AI_CombatMove_Formation*` (facing, repulsion overrides
tight/relaxed, speed-gap tolerance) tunes how tight the line holds while moving.

### It was built, measured, and pulled — read this before rebuilding it

**All of the above was implemented and it changed nothing you can feel.** The module
(`mercenaries_combatfeel.lua`, three presets, 20 cvars, saved + revertible) and the perk
carrying the crowd-throttle overrides were both written, run in a real fight on the most
aggressive preset, and removed again. What the session log proves:

* **Every one of the 20 cvars exists and was written.** No "not registered" warning, and —
  decisively — **zero `[CVARS]` lines in `kcd.log`**. The engine logs
  `[CVARS]: [IGNORED CHANGE] variable [x] from [a] to [b]; Marked as [VF_CHEAT]` every time
  it refuses a protected write (`CXConsole::vf74` → `sub_5F99B8`). Nothing was refused.
* **The table route works.** `Table 'perk_rpg_param_override' is patched by
  'perk_rpg_param_override__mercenaries', lines added: 2` — a `__mercenaries` suffix file
  *does* merge into `perk_rpg_param_override`, which had been the main doubt about it.
* **A real fight ran with the `brutal` preset live**, and the melee looked the same.

So the footwork layer — circling cadence, guard speed cap, repulsion, sweet-spot geometry,
reaction smoothing — is reachable, is genuinely read by the movement code (15 of 16
checked parameters have live readers; only `ToGuardFactor` has none), and **is not what
produces the feel**.

The layer that would produce it is attack *cadence*, and that one looks computed rather
than configured: `CombatAutoMaxAttackDelay`, `CombatAutoNPCOpponentAtkDelayCoef` and
`CombatAutoAttackDelayIncreasePerAttacker` live at Constants offsets `0xC8C`/`0xC90`/`0xC94`,
and those offsets are written by a **runtime blend** at `0x50D658` — values computed as
lerps out of another struct, not just loaded from the table. If that blend runs after a
perk override resolves, it overwrites it, which would explain the crowd-throttle perk
doing nothing at all. Inferred from the write pattern, not traced to its inputs — that
trace is the one piece of work left if anyone wants to reopen this.

Two things worth keeping from the attempt, both already corrected above: `ICVar::Set`
**does** gate writes on a flags mask before writing (an earlier note here claimed there
was no check anywhere in the path — wrong, it is inside `Set`, it simply is not firing on
this build), and the `wh_cs_Automation1_*` / `Automation2_*` families are the combat test
room's **debug opponent** harness ("Enables debug AI on given entity"), not the live AI.

### What is not reachable without native code

* **Army-level tactics.** Bannerlord's formation orders — shieldwall, flanking, cavalry
  held in reserve, a captain re-tasking a formation mid-battle — have no engine
  equivalent. Formations here are follow-spots around an anchor, nothing more. It can be
  *built* in Lua + BT on top of the existing pieces, but the engine will not do it.
* **The 5-zone duel model.** Directional zones, master strikes, clinches, perfect
  blocks are hardwired; the `combat_action_*` tables change *which animation and how
  much damage*, not the model.
* **Agent shoving.** No push-through-the-crowd like Bannerlord's agent collisions;
  crowding here is avoidance (ORCA) plus repulsion, and `ac_disableLivingVsRigidCollisions`
  ships on (see [NPC wall collision](walls-and-sieges.md)).
* **Scale.** More simultaneous fighters runs into the AI-LOD count budget long before
  the movement system complains — see [Performance](performance.md) and
  [NPC LOD](npc-lod.md). `wh_cs_BattleMaximumNPC` (= 2) is *not* that cap; it belongs to
  the scripted-battle background system (`C_BattleManager`), not to real combatants.

---

## Re-deriving this after a patch

Nothing above was read from a running game, and no RVA in it is stable across builds.
The recipe, from the [disassembly corpus](disassembly.md):

```bash
python tools/disasm_query.py strings "^WH_AI_CombatMove" -n 300     # the names
python tools/disasm_query.py cvar "^wh_cs_AutomationAction_" -n 400 # the combat-system half
```

The defaults come from parsing the registration calls in the listing and reading the
bound `.data` address out of the DLL image — the registrars are `sub_B95298` /
`sub_14DF354` (WH_AI style, storage is rip-relative, default = the value at that
address) and `sub_23D8B0C` / `sub_23D8168` (wh_cs style, storage is struct-relative,
default arrives in `xmm2` / `r8d`). All five are thin wrappers over `gEnv->pConsole`
vtable slots `0x40` / `0x48`, so re-finding them after a patch means finding the
functions that call those slots with a name and a help string.
