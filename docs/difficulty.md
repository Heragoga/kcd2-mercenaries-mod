# Difficulty and company settings

Everything the player can retune about the mod itself. All of it lives in
`mercenaries_difficulty.lua` and is reached from the quartermaster under **"Let's talk
about how the company runs"**, or from the console.

| Setting | Console | Options |
|---|---|---|
| Threat level | `merc_difficulty <tier>` | easy / medium / difficult / extreme / impossible / horde |
| Random encounters | `merc_encounters 0\|1` | on / off |
| Company survival | `merc_upkeep <mode>` | off / lenient / standard / harsh |
| Status HUD icons | `merc_status_icons 0\|1` | on / off |

`merc_difficulty_status` prints the tier and the ceilings it implies.

**Encounters** is the master switch for everything the mod puts in the player's way
uninvited — camp raids, roaming patrols and roadside ambushes. Contracts he accepts
himself are not encounters and keep working. Gated at each tick's own entry point
(`RaidTick`, `LivePatrolTick`, `AmbushMonitor`).

**Company survival** scales two things and can be switched off entirely:

| Mode | `FeedRatio` × | spoils × |
|---|---|---|
| lenient | 1.4 (stores stretch further) | 1.25 |
| standard | 1.0 | 1.0 |
| harsh | 0.65 (they eat more) | 0.7 |
| off | — `LogiProcessUpkeep` returns immediately: no rations, no wages, no morale drift |

The rates are read straight off `mercenaries.*` by the logistics tick, so a mode is
applied by **rewriting them from a pristine copy** taken the first time through
(`UpkeepApply`) — setting a mode twice would otherwise compound. `UpkeepLoad` runs
from `OnGameplayStarted`, before the first logistics tick.

**Status icons** off clears the row and stops `LogiUpdateStatusBuffs` driving it. The
"no drink at all" icon has been removed outright — drink is optional and carries no
penalty, so it was reporting a non-problem.

---

## The difficulty tier itself

| Tier | Enemies per man | Armour |
|---|---|---|
| easy | 0.8× | favour the ragged half |
| **medium** (default) | 1.2× | as authored |
| difficult | 1.4× | as authored |
| extreme | 1.5× | favour the good half |
| impossible | 2.0× | favour the good half |
| horde | 4.0× | favour the ragged half |

Lives in `mercenaries_difficulty.lua`; persisted with `SaveString("MercDifficulty")`
and lazily loaded on first read, the same idiom as `RaidNextDay`.

---

## Counts

`countMult` is a **cap relative to the player's own strength**, not a flat headcount,
so one setting means the same thing to a four-man company and a fifty-man one.

```lua
mercenaries:DifficultyCount(want, base, floorMin)
```

`want` is whatever the caller already rolled; `base` is that caller's own notion of
the player's strength. Each system keeps its own `base`, because they disagree for
good reasons:

| System | base | why |
|---|---|---|
| raids | `LogiAliveCount()` | a raid is fought by the whole company, including the men asleep in camp |
| patrols | `PatrolPartySize()` (1 + alive) | the player is on the road himself |
| bounty / Kleinkrieg | `BanditCampFollowerCount()` | only the men who actually walked out |

### The ceilings, and why they had to move

Every one of these systems has a hard cap that was tuned for the old fixed
difficulty, and each would silently swallow a harder tier:

| Cap | Was | Where |
|---|---|---|
| `RaidMaxCount` | 14 | `mercenaries_raids.lua` |
| `PatrolMaxMen` | 16 | per gang |
| `PatrolMaxLiveMen` / `PatrolMaxLiveGangs` | 36 / 3 | total live population |
| bandit-camp `cap` | 10 (solo) / 20 | inline in `BanditCampScale` |

`DifficultyCeil(base)` scales them in step with the tier. Note that raising the
per-gang patrol size alone would have been a **no-op** — the population budget in
`PatrolBudgetFor` would have swallowed the extra men on the way out.

`DifficultyBaseMult` is 1.2, i.e. medium. Anything at or below it leaves every
ceiling exactly as authored, so the default tier changes nothing.

---

## Armour quality

There is **no per-item quality metadata anywhere in this mod** — `EquipEnemy` picked
a clothing preset with a flat `math.random` into `EnemyGroups[group].clothing`, and
no quality field is read anywhere.

But the ladder already exists as authored data, in two independent forms:

1. **`mercenaries.Outfits` grades the same GUIDs.** `EnemyGroups.looter.clothing` is
   exactly `Outfits[2].weak ++ Outfits[2].medium`; `EnemyGroups.bandit.clothing` is
   `Outfits[2].medium ++ Outfits[2].strong`; `cuman` is `Outfits[3]` weak→strong.
   So a GUID → `weak|medium|strong` index built from `Outfits` covers most groups
   exactly, with no manual auditing.
2. **Every group's `clothing` array is authored worst-first.** That is the fallback
   ordinal for the GUIDs `Outfits` does not know (sigi, prague, ruthenian, recruit).

`DiffWardrobe(group)` merges the two into a `low`/`high` half per group, and
`DiffPickClothing` draws from the favoured half `DifficultyQualityBias` (70%) of the
time. Not 100%: "favour poor armour" should still put the odd decent breastplate in
the line, or every easy fight looks identically ragged.

**A `mixed` tier returns `nil`**, so `EquipEnemy` keeps its own uniform draw and
nothing about the old behaviour changes. Only easy / extreme / impossible / horde
shift the wardrobe at all.

This deliberately does **not** bias which *group* turns up. Swapping looters in for
knights would change the fiction and would fight the per-group `share` values that
already balance the raid roster; biasing the wardrobe within the group the fiction
already chose is the narrower, safer knob.

---

## Adding a consumer

Read the tier at runtime, never at file-load time — `SaveString`/`LoadString` need a
loaded save to mean anything, so everything here is lazy:

```lua
local n = <your own roll>
pcall(function() n = self:DifficultyCount(n, <your base>, <your floor>) end)
local ceil_ = self.MyCap
pcall(function() ceil_ = self:DifficultyCeil(self.MyCap) end)
if n > ceil_ then n = ceil_ end
```

`mercenaries_difficulty.lua` loads right after `mercenaries_spawning.lua` and before
every consumer.
