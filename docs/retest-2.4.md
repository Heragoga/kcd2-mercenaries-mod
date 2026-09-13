# 2.4 hotfix — what to check

Five of the six reports were one bug. The travel watcher fires on **fast travel, sleeping and
waiting alike** (one "the player moved without walking" detector), and on every one of them
2.3 stowed the whole company through the roster and put it back around the player. That
single call caused: camp men teleported to you, men told to wait following anyway, the camp
coming down, and — because the roster only stored `tier,hp` — companions and archers coming
back as generic mercs.

Nothing is stowed any more. The men who were **with you** are teleported to you at the far
end; the same entities, so identity, gear and orders are untouched. Everyone else is left
exactly where they stand.

## The three-minute pass

Hire a few men, take one named companion, pitch a camp, then:

| # | Do this | Expect |
|---|---|---|
| 1 | Leave some men in camp, take the rest, **fast travel** | Log: `crossing begins (...): N man/men come along, the rest stay where they are`. Camp men still in camp; camp still standing |
| 2 | Check the companion after arriving | Still himself — name, face and gear unchanged, not a generic merc |
| 3 | `merc_wait`, then fast travel | Nobody moves. `N` in the log is 0 |
| 4 | **Sleep** in a bed, then **wait** an hour | Same as fast travel: camp intact, nobody dragged |
| 5 | Buy a second palisade stretch, stand at the existing wall, click the first corner | A corner is marked and the run starts. It must **not** say the gate is hung |
| 6 | Walk the new run into the old palisade and click | *Now* the gate hangs and the run finishes |

## Why each fix works

- **Travel** (`mercenaries_travelwatch.lua`) — `TravelTakesAlong` decides per man from the
  mod's own state, not distance: a camp resident (`_G.MercInCamp` and not in the sortie party)
  stays; if the company is holding ground (`HoldAnchor`, which is what "wait here" sets)
  nobody moves at all. Distance would have been wrong, since the player often fast travels
  *from* his camp.
- **Identity** (`mercenaries_roster.lua`) — the roster blob now carries each man's entity
  name, and `RosterRespawnNamed` rebuilds him from the soul GUID that name ends with. This
  also fixes `merc_stow` and the main-quest battle stash, which had the same flaw. An older
  save's blob has no names, so men already stowed under 2.3 still come back generic once.
- **Palisade** (`mercenaries_wall.lua`) — the gate snap is only tested when a run is already
  being drawn (`#WallMarks > 0`). The first corner of a new stretch is always just a corner.
