# Invisible mercenaries in scripted battles — findings

Status: **unsolved, but with one reproducible working configuration and a clear model.**

Companion docs: [npc-lod.md](npc-lod.md) (the 35-run LOD dead end),
[malesov-structure.md](malesov-structure.md) (quest structure),
[quest-override-battles.md](quest-override-battles.md) (the override tooling).

---

## THE ONE CONFIGURATION THAT WORKED

**Inject a merc's soul GUID into the Malešov quest's existing garrison `SoulAsset`s. The merc
renders, permanently and consistently, for the whole battle.**

```bash
python tools/OverrideMalesovQuest.py --group enemy      # 45 lists, 13 files
# or --group all                                        # 137 lists, 31 files
PackageModDev.bat
# in game:
merc_testmerc
```

Observed both times it was run (`--group all`, then `--group enemy`):

* **renders** — solidly, not the flicker/T-pose of any LOD-cvar attempt
* **attacks the player**
* garrison attacks it too under `--group all`; does not under `--group enemy`

**Why it attacks the player, and why that matters.** The garrison aliases feed `SoulArray1` of
`AddFactionRelationBetweenArrays`, whose `SoulArray0` is `player + innerCourtyardZizkaband`. The
node is **directional** — Array0 becomes hostile toward Array1. So injecting into the garrison
makes *the player's side attack the merc*. The merc then defends itself, which is the whole
reason it renders: **it is in a genuine two-way fight.**

That is the single most important observation in this investigation. The player-hostility is not
a side effect to be filtered out — on current evidence it is *the mechanism itself*. Nothing has
yet produced rendering without something actively attacking the merc.

---

## The model

**Rendering requires something to be hostile TOWARD the merc — being attacked, not attacking.**

An NPC nobody fights is not a combat participant, never gets a combat actor, has no combat-LOD
entry (measured, run 26), sits in no battle group (run 32), and falls to ambient/MonsterLOD.

| test | merc's position | who attacks it | renders |
| --- | --- | --- | --- |
| all 137 assets | both arrays | player side + garrison | **yes** (attacks player) |
| enemy-only (45) | garrison = `SoulArray1` | player side | **yes** (attacks player) |
| ally-only (64) | `innerCourtyardZizkaband` = `SoulArray0` | nobody | no |
| 6 named companions | `SoulArray0` / forced-target `From` | nobody | no |
| `villageReinforcements` only | Array1 of the *village* fight | player side | no |
| isolation NPC, no AI, merc faction | garrison arrays | attacked, never fights back | no |
| regular hired mercs | in no array | nobody | no |

Root cause of the base bug, measured in the dev log: **0 attacks on mercs vs 40 by them.**
Faction relations are one-directional and no vanilla faction declares anything toward
`mercenariesFaction`, so mercs attack a garrison that ignores them.

---

## The isolation-NPC result (rules out our own AI)

`merc_isotest` spawns a soul on `isolation_test_brain`: a no-op heartbeat scheduler, **no combat
AI of ours at all** — no target selection, no `combat_melee`, no interrupts, no follow.

* renders in the open world
* **vanishes in the battle**, even with merc faction and its GUID in the garrison arrays

**This reproduces the invisibility bug with none of our code involved.** Our AI stack is
definitively cleared. It also shows hostility on paper is not sufficient: the NPC was attackable
but never fought, and stayed invisible.

Our merc targeting was separately verified clean — `IsValidEnemy` opens with
`if ent.id == player.id then return false end`, `CachedEnemies` is built through it, and
`PickCombatTarget` filters through it again. **Three independent guards; the player can never be
selected by our code.** When an injected merc attacks the player, that is vanilla reactive combat.

---

## What does NOT work — do not retry

| approach | result |
| --- | --- |
| ~40 LOD/skirmish/battle cvars | nothing (see npc-lod.md) |
| quest `Type` change (Activity → main-quest shape) | nothing |
| permanent battle context preset | **breaks all NPC dialog**, no render |
| `QuestVisual` node | **kills the entire mod quest tree** — never use |
| `deterrenceImmunity` (grant + 5s pulse, in our own quest) | nothing |
| merc souls → `players_friends` faction | nothing |
| reverse relation, 6 mirrored nodes (Edge form) | nothing |
| reverse relation, tower-pattern twin in `boj.xml` (Asset form + player in Array1) | nothing |
| reverse faction relation on the garrison's own leaf faction | nothing |

### The pattern in those failures

**Data edits work. New nodes do not.** Adding GUIDs to an existing `SharedSoulGuids` list has
taken effect every single time. Two hand-authored `AddFactionRelationBetweenArrays` nodes — in
two different shapes, one copying a working vanilla node literally — had no observable effect,
despite loading without a single error. Ruled out as explanations: alias scope (`boj.xml`
declares no assets at all and inherits everything), activation source
(`obranci_jdou_bojovat` is a sustained bool In port driving 9 vanilla nodes), and node form
(`<Asset Name="SoulArray0"/>` is used by 132 of 147 vanilla instances).

**Working hypothesis, untested:** hand-authored Skald nodes may be syntactically accepted but
functionally inert — carrying no build-time state the real Skald editor would generate. If true,
only data edits to existing structures are viable, and the whole "add a relation node" family is
a dead end regardless of shape.

---

## Where to go next

1. **Ship the imperfect win.** `--group enemy` renders mercs in the battle. The cost is that they
   fight the player. Pair it with something that stops the merc actually harming you (a buff or
   damage-immunity while the battle context is live) and it may be shippable without solving the
   mechanism.
2. **Test the tower fight** (`boj_ve_vezi_optional`). It has the one vanilla relation pointing the
   right way — `SoulArray0 = towerDefenders` (garrison) → `SoulArray1 = player + towerAttackers`,
   with the player *inside* Array1. Injecting into `towerAttackers` should give render + engaged +
   loyal all at once. Generated and validated but **never testable** — that sequence could not be
   reached in-game. If it is ever reachable, this is the highest-value single test remaining.
3. **Settle the inert-node hypothesis.** Add a trivially observable hand-authored node to a
   vanilla quest (e.g. a `BuffEffect` with a visible buff) and see whether it fires at all. That
   single result decides whether any node-based fix can ever work.

---

## Tooling

| tool | purpose |
| --- | --- |
| `tools/OverrideMalesovQuest.py` | single-quest injection. `--group all\|enemy\|ally\|villager`, `--assets REGEX`, `--extra-soul GUID`, `--list`, `--revert` |
| `tools/OverrideMainQuestBattles.py` | all 12 main-quest battles. `--scope all\|noHostile`, `--revert` |
| `tools/MalesovMercHostility.py` | 6 mirrored reverse-relation nodes (**no effect**) |
| `tools/MalesovCourtyardHostility.py` | tower-pattern twin in `boj.xml` (**no effect**) |
| `tools/MalesovDeterrenceImmunity.py` | `deterrenceImmunity` via `joinarrays52` (**no effect**) |
| `merc_testmerc` | spawn one merc on the fixed test soul |
| `merc_isotest` | spawn the zero-AI isolation NPC |

**`side_of()` in `OverrideMalesovQuest.py` classifies by alias name and is wrong on ~25 of 67
"ally" assets** — `villageReinforcements*` is garrison by GUID. Classify by GUID set instead; the
garrison (36 souls) and Žižka (14 souls) unions are disjoint, so the partition is exact.

Always use `PackageModDev.bat`, never `PackageMod.bat`, when testing quest changes — the release
build silently swallows rejected Skald nodes, and `KCD2Mod\kcd.log` is the only place failures
appear. Check the log's mtime before trusting it.
