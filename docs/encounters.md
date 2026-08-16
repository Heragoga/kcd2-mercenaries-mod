# Encounters

Random/placed encounters built on the AI modules (`docs/ai-modules.md`). The AI
restructure was done specifically so each of these is pure Lua: pick a group,
spawn it somewhere, point it at something.

| # | Encounter | Status |
|---|-----------|--------|
| 1 | **Camp raids** - small bandit bands hit the camp while the player is in it; a solo "armed Henry" variant | planned |
| 2 | **Ambushes** - preset archer/melee spots + trigger areas on the road | **done** (authoring + live triggers) |
| 3 | **Patrols** - enemy groups marching a road path in formation behind a leader | planned |
| 4 | **Large bandit camps** - a mod camp populated by bandits instead of mercs | **done** as the quartermaster's contract quest ([bandit-camp-quest.md](bandit-camp-quest.md)); needs a site + layout authored |
| 5 | **Siege of Raborsch** - one-off Kuttenberg quest, lift a Sigismund siege | planned |

The shared spawn primitive is `mercenaries:SpawnEnemyAt(groupKey, isArcher, pos, yaw)`
(`mercenaries_spawning.lua`) - one enemy of any group at an exact spot, souls
round-robined, tier baked into the name so the weapon/AI code picks it up.
`SpawnEnemyGroup` is built on it. Groups: `looter`, `bandit`, `sigi`, `prague`,
`cuman`, `knight`, `heinrich` (see `docs/enemies.md`).

---

## Ambushes

An ambush **scene** is a named set of positions on one level:

- **archer spots** - where enemy archers appear (high ground, treelines)
- **melee spots** - where enemy footmen appear
- **trigger areas** - boxes; the player entering one fires the ambush

### Authoring workflow

Positions are marked in-game with props, using the same aim-and-click loop as
tower/cart building (`mercenaries_tower.lua`, `StartPlacement`): **left-click
drops a marker, right-click discards every marker placed since the mode started.**
Nothing is kept until you save. Markers are spawned with `bPhysicalize = false`,
so they never block you while you work.

| Kind | Marker prop |
|------|-------------|
| archer | barrel of arrows |
| melee | plain barrel (`barrel_a`) |
| trigger | banded barrel (`barrel_c`) |

All barrels: they stand upright and read from a distance. Flags were tried first
and lie flat on the ground where they are easy to walk past. Markers carry **no
`Physics` property at all** - that is how the placement ghost gets a visible,
walk-through prop. Passing `Physics = { bPhysicalize = false }` instead is not a
recipe used anywhere in the mod and produced the wrong mesh.

```
merc_ambush_new forest_bend      -- start a scene (clears markers, records the level)
merc_ambush_archer               -- click out the archer spots, then:
merc_ambush_save
merc_ambush_melee                -- click out the melee spots, then:
merc_ambush_save
merc_ambush_trigger              -- FOUR barrels per area (8 = two areas), then:
merc_ambush_save
merc_ambush_test                 -- spawn it for real and judge the layout
merc_ambush_test_clear
merc_ambush_dump                 -- print the scene as pasteable Lua
merc_ambush_clear                -- remove all markers and test enemies
```

`merc_ambush_test [group]` defaults to `looter`: an archer of that group on every
archer spot, a melee fighter on every melee spot, all facing the player. Any group
name works (`merc_ambush_test cuman`).

Trigger corners are stored as the **axis-aligned box** containing each set of four,
so the four barrels only need to bracket the area - they do not have to be a neat
square. Leftover corners (a count not divisible by four) are ignored with a warning.

### Dump format

`merc_ambush_dump` prints to the game log; copy it into a scenes file:

```lua
mercenaries.AmbushScenes["forest_bend"] = {
    level = "kutnohorsko",
    archers = {
        { x = 1234.00, y = 567.00, z = 89.00 },
    },
    melee = { },
    triggers = {
        { minx = 1200.00, miny = 540.00, maxx = 1260.00, maxy = 600.00 },
    },
}
```

## Ambush runtime

Scenes live in `mercenaries_ambush_scenes.lua` (paste the dump there).
`AmbushMonitor` runs every second from `MonitorLoop` and springs a scene when the
player stands in one of its trigger boxes.

**The scene you are authoring is live too**, as soon as it has at least one saved
trigger and one saved spot - so marking a scene and walking into it works
immediately, without dumping and pasting first. (It only counts what
`merc_ambush_save` committed; unsaved markers are ignored.)

Rules:

- **One ambush at a time.** While enemies from the last one are still up, no new
  scene fires.
- A sprung scene is **disarmed until the player walks out** of all its boxes, so
  standing on the trigger does not respawn it.
- The active ambush clears itself once every spawned enemy is down - and if the
  player runs 250m away (`AmbushForgetRange`) it is despawned, so an ambush that
  was fled from can never block every future one.
- Triggers never fire while markers are being placed.
- `group` on a scene picks who springs it; default `looter`.

```
merc_ambush_status               -- live scenes, counts, armed/disarmed, what's active
merc_ambush_where                -- why isn't it firing? your position vs every box
merc_ambush_arm 0                -- disarm live triggers (1 to re-arm)
merc_ambush_despawn              -- remove the ambush currently on the ground
```

If a trigger does not fire, `merc_ambush_where` prints your position against every
box and flags the usual causes: still in placement mode, triggers disarmed, the
scene already sprung, or the draft not yet counting as live.

### Still to do

- Scale enemy count with squad size (and a difficulty setting), aiming at "hard
  but you don't lose half the company". Right now a scene spawns exactly what was
  marked.
- A broken-down cart blocking the road; the camp prop spawners
  (`mercenaries_camp.lua`) already know how to place props.

### Gotchas

- Console commands take arguments via `%line`, never `%1` - a `%1` body arrives as
  the literal string `"%1"`. See `reference_ccommand_arg_substitution`.
- The placement engine's `onCancel` spec hook is what makes right-click discard
  markers; tower/cart omit it and keep what they built.
