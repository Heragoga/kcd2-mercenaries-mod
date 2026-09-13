# Testing the Malesov battle stash

The last of the seven original bugs still unproven. The watchdog is supposed to notice a
scripted main-quest battle, put the company 400 m out of it, and bring them back when it
ends. **It has never once been observed to fire.**

Code: [mercenaries_mainquest_watchdog.lua](../data/Scripts/mods/mercenaries_mainquest_watchdog.lua).
Why the men are invisible in the first place: [quest-override-battles.md](quest-override-battles.md).

## Why it needs a plan rather than just playing the quest

There are **two independent failure modes**, and running the assault tests both at once — so
a failed run cannot say which one broke:

1. **Detection.** The tick needs a live battle quest *and* either the engine's `Battle`
   script context on Henry or a fight signal.
2. **The stash itself.** Even after detection, `MQWStash` insists specifically on the
   **context** and refuses without it. So `MAIN-QUEST BATTLE detected` can be followed by
   `no scripted-battle context on the player - the company stays`, and nothing happens.

That refusal is deliberate — a battle quest counts as started the moment it is accepted, so
detecting on quest+fight alone would empty the company out of any roadside ambush for the
hours that quest is open — but it means the two halves must be tested separately.

## Part 1: prove the stash works, before you go anywhere near Malesov

Anywhere quiet, with five or more men following. No `merc_dev` needed — all three commands
are player-tier.

```
merc_mqstash_now
```

Expect: `N men sent 400m out of the battle to behind the player (x, y) and told to hold`.
The company should vanish over the hill and **stay there** — the formation watch and the
straggler sweep must not drag them back. Watch for a minute.

```
merc_hire 3
```

The new men must join the ones waiting, not appear next to you (`MQWOnHire`).

```
merc_mqunstash_now
```

Expect: `forced by hand - N men brought back to the player and following`. All of them,
including the three new ones, back and following.

**Then save while stashed, reload, and wait 45 s.** Expect
`loaded with the company stashed ... they come back unless it is re-detected` and then the
company returning on its own.

If any of this fails, the assault will fail too, and you will have learned it in five minutes
on a hillside instead of mid-battle.

## What the 2026-09-04 run proved

* **The stash mechanism works.** `merc_mqstash_now` sent 5 men 400 m out; `merc_mqunstash_now`
  brought 10 back (5 hired while stashed joined them correctly). Part 1 is passed.
* **Detection could not have fired, whatever the battle did.** Entry required a
  `IsQuestStarted` match on one of twelve names *before anything else counted*, and
  `utokNaMalesov` never answered true. The log was silent because the trace was keyed to
  the same failed quest match.
* **The battle announces itself plainly in kcd.log:**
  `Loading config file 'Config/CVarOverrides/utokNaMalesov_battle.cfg'`, then `Battle.cfg`.

`Libs/Tables/CVarOverride.xml` (Data/Tables.pak) is what drives those lines - it binds a
**GameContext** to a cfg file:

| GameContext | Priority | File |
|---|---|---|
| `Battle` | 3 | Battle.cfg |
| `utokNaMalesov_battle` | 4 | utokNaMalesov_battle.cfg |
| `oblehaniSuchdole_Battle` | 5 | M48a_oblehaniSuchdole_Battle.cfg |
| `oblehaniSuchdole_nightAttackTargetingRange` | 4 | M48a_oblehaniSuchdole_nightAttack.cfg |

Those names *are* "a scripted battle is running" - so the quest list is now corroboration
only, never a gate, and a context match alone enters the state.

### The fallback, if HasScriptContext cannot see a GameContext

The cfg file's own footprint is still readable. Four cvars are set by every battle cfg, by no
other override (`performanceDemandingArea` sets only `e_ShadowsCastViewDistRatioLights`,
`kutnohorsko.cfg` sets nothing) and by none of the cvars the mod's LOD boost owns:

`wh_e_HLodClusterSwitchingDistanceMin` · `e_MergedMeshesInstanceDist` ·
`e_MergedMeshesViewDistRatio` · `wh_ca_ClothDisableSimulationAtDistanceCollMode1`

A baseline is taken from quiet play 20 s after each load; two or more of the four moving
counts as the battle profile. Combined with a fight signal, that enters the state too.

## Part 2: detection, WITHOUT the assault

`utokNaMalesov` cannot be replayed without redoing a very long quest, so the automatic path
cannot be proven against the real battle. It can be proven against the mechanism:

```
merc_mqsimulate
```

Anywhere quiet, company following. It moves the four watched cvars off their baseline exactly
as the battle cfg would, holds a fight signal for 30 s, then puts everything back. Expect:

```
[MQWatch] SIMULATION: 4 cvar(s) moved off baseline and a fight signal held for 30s.
[MQWatch] MAIN-QUEST BATTLE detected: battle cvar profile [4/4 cvars, e.g. ...]
[MQWatch] N men sent 400m out of the battle ... and told to hold
   ...30s...
[MQWatch] SIMULATION over: cvars restored ...
[MQWatch] main-quest battle over (state held 30s)
[MQWatch] the battle is over - N men brought back to the player and following
```

That proves signal -> entry -> stash -> exit -> unstash end to end.

**What it cannot prove** is whether the *engine* will raise a signal during the real assault.
Only the assault can, and if `merc_mqsimulate` reports `could only move 0 cvar(s)` then
`SetCVar`/`GetCVar` do not answer for these and the cvar route is dead on this build -
in which case the context probes are the only hope and the manual commands are the fallback.

## Part 3: detection during the assault, if it is ever replayed

Start the Malesov assault with the company following. The watchdog now narrates its near
misses, so **the log is informative even when nothing happens** — this is the part that was
missing before. Every 15 s while the quest is live but the state has not been entered:

```
[MQWatch] NOT entering: quest=nil context=nil fight=combat cvars=nil streak=0/2
```

It now traces on **any** signal, so the log is informative even when the quest probe fails.

| What the line says | What it means | What to do |
|---|---|---|
| `N men sent 400m out of the battle` | **It works.** | Fight it out; they must come back within 20 s of the end |
| No `[MQWatch]` line at all | Not one of the four signals is reading, or the tick is not running | `merc_mqwatch` mid-fight |
| `context=<name>` present but no entry | Only possible for one tick — `streak` must reach 2 | Wait two seconds |
| `context=nil` while `utokNaMalesov_battle.cfg` is in the log | `HasScriptContext` cannot see a GameContext on this build | Read the `battle cvars` block in `merc_mqwatch`: if they show `CHANGED`, the cvar route carries it |
| `context=nil cvars=nil` and the cvar block shows no change | The override was loaded but reverted, or the baseline was taken during the battle | The baseline line says when it was taken; reload and stay quiet 20 s first |
| `cvars=` set but no entry | The cvar path also needs a fight signal | Check `fight=` — if `nil` in a pitched battle, `IsInCombatDanger` and `QueryBattleStatus` both fail here |

At any point, `merc_mqwatch` prints the state plus all twelve quest probes, all four context
probes, `IsInCombatDanger` and `QueryBattleStatus`. It changes nothing, so it is safe to spam.

And if detection never fires but part 1 passed, `merc_mqstash_now` before the assault and
`merc_mqunstash_now` after is a working manual workaround — worth knowing before deciding how
much more to invest in automatic detection.

## Also on this run

* **Hiring during a stashed battle** (open item 3) is covered by the `merc_hire 3` step above.
* `merc_mqstash 0` turns the automatic stash off entirely if it misbehaves; it is saved.

---

# 2026-09-04, second run: what the real battle proved

The rehearsal passed end to end — detected, 5 stashed, exited after 49 s, 5 brought back. Then
the real assault ran in the same session, and settled two things.

## HasScriptContext cannot see a GameContext

```
866: Loading config file 'Config/CVarOverrides/utokNaMalesov_battle.cfg'
939: Loading config file 'Config/CVarOverrides/Battle.cfg'
943: [MQWatch] NOT entering: quest=nil context=nil fight=combat cvars=nil
```

The battle cfg is demonstrably loaded and **every** context probe still reads false. The
GameContexts in `CVarOverride.xml` are not script contexts on the player's soul. That closes
the context route: the cvar footprint is the only automatic signal available.

## The session baseline was the wrong instrument

```
957: [MQWatch] battle-cvar baseline taken from quiet play (wh_e_HLodClusterSwitchingDistanceMin=40)
```

40 is the **battle** value; normal is 25. The baseline was sampled during the battle, so the
signal recorded the battle as normal and could never fire. Replaced with **known values**:
`tools/gen_battle_cvars.py` reads the game's own cfg files and emits the per-`sys_spec`
numbers, and detection now asks "do all three anchors hold a battle value?". No baseline, so
it cannot be defeated by when it is sampled. At sys_spec 1 the anchors are:

| cvar | normal | battle |
|---|---|---|
| `wh_e_HLodClusterSwitchingDistanceMin` | 25 | 40 |
| `e_MergedMeshesInstanceDist` | 1 | 2 |
| `e_MergedMeshesViewDistRatio` | 15 | 20 or 22 |

`e_MergedMeshesLodRatio` is deliberately excluded — it reads 5 in and out of battle at that
spec, so it can never discriminate.

# The other hypothesis: is a battle cvar why they vanish at all?

Worth taking seriously. `e_LodFaceAreaTargetSizeCharacterWH` is a **character** LOD lever that
changes only when a battle cfg loads (0.003 at sys_spec 1), and the ~44-session investigation
in [npc-lod.md](npc-lod.md) ruled out the AI LOD system but never the battle override itself.

```
merc_battlecvar
```

Lists all 18 with `now=` and `battle=` for the live spec, marks which the LOD boost owns.

```
merc_battlecvar 9          apply entry 9's battle value
merc_battlecvar 9 0.02     apply an explicit value
merc_battlecvar all        the whole battle profile at once
merc_battlecvar off        put everything back
```

Method: company standing in front of you in ordinary play, apply **one at a time**, watch for
the moment they go. If `all` makes them vanish, bisect. If nothing does, the battle cvars are
not the cause and the soul-membership explanation stands.

Two things make this trustworthy where a bare `SetCVar` would not be:

* Values go through `CvarOverride`, so `LodBoostReassert` does not undo them 300 ms later —
  which it would for every cvar the boost owns, including the character LOD one.
* Applying any of them **suppresses the watchdog's cvar detection**, so the hand-applied
  profile is not mistaken for a real battle and the company is not teleported mid-experiment.
  `merc_battlecvar off` restores both.

---

# 2026-09-04, third run: battle cvars ruled out, and cvar detection withdrawn

**`merc_battlecvar all` did not make the mercenaries vanish.** The whole battle render profile
was applied in ordinary play with the company standing in view, and they stayed. So the
battle CVarOverride is **not** why they disappear, and the soul-membership explanation in
[quest-override-battles.md](quest-override-battles.md) stands unchallenged.

**Detection by cvar is withdrawn by decision, not by failure.** Those numbers can be pushed
by anything - a graphics preset, this mod's own LOD bench - so matching them is not evidence
that a battle is running, and a false positive teleports the company 400 m away in the middle
of ordinary play. `merc_battlecvar` remains as a bench; nothing reads the cvars to decide.

That leaves **no automatic detector**. `merc_mqsimulate` now stands in for one directly
(it flips the decision rather than faking a signal), so the stash half stays testable.

## The next idea: key on the active objective

If Lua can see which quest or objective is running, the fights that hide mercenaries can be
listed by name and the stash triggered on those. Whether it can is genuinely unknown:

* Nothing in the game's own 290 Lua files references a `QuestSystem` global.
* [lua-skald-communication.md](general/lua-skald-communication.md) states there is no direct
  Skald-to-Lua bridge, which is why this mod passes messages through the inventory.
* `IsQuestStarted` has never matched a name - including during an assault that was running.

```
merc_questprobe
```

Changes nothing. It enumerates `_G` for anything quest-shaped, lists the members of fifteen
candidate globals, calls sixteen plausible enumerators on each and prints what comes back,
then sanity-checks `IsQuestStarted` against a name that cannot exist - because if a bogus
name and a real one both answer `false`, that function is telling us nothing.

It ends with a verdict:

* **Something answered** - the fight list gets keyed on whatever stable identifier it returns.
* **Nothing answered** - no objective-driven stash is possible, and the fallback is the
  inventory-token bridge: a Skald node in each battle quest hands Henry a token the mod reads.
  That works, but it costs one quest edit per fight.

`merc_questprobe <GlobalName>` dumps every member of that one global, for following up on
whatever the first run turns out to show.

---

# SHELVED, 2026-09-04

Parked after the quest API turned out not to exist. Nothing here is broken; it is simply
blocked on a way to know a scripted battle is running.

**What works and is proven:** the stash mechanism itself. `merc_mqstash_now`,
`merc_mqunstash_now`, hiring while stashed, save/reload while stashed, and `merc_mqsimulate`
driving the whole chain. Those are the manual workaround and they are reliable.

**What is missing:** any automatic trigger. In order of what was ruled out —

| Route | Verdict |
|---|---|
| `IsQuestStarted` on twelve quest names | `QuestSystem` global does not exist; a name that cannot exist answers identically |
| `HasScriptContext` on the CVarOverride GameContexts | every probe false during a battle that was demonstrably running |
| Battle cvar footprint | matches, but is not evidence — anything can push those numbers |
| `RPG.GetLocations` + combat, by area | workable, judged too blunt |
| Skald inventory token per battle quest | exact, but one quest edit per fight |

`C_ScriptBindQuest` exists in the binary with `IsObjectiveActive` and `GetActiveObjectives`.
It is not bound into the mod Lua state. If a future patch exposes it, this becomes trivial:
put the fight list in `MQWBattleQuests` and let the tick ask.

**To resume:** `merc_questprobe` re-answers the API question in one run. If `QuestSystem`
ever stops reading ABSENT, the rest is already built.
