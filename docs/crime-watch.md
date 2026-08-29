# The crime watchdog

Watch-only. It spawns nothing, changes no state and touches no vanilla table. It answers
two questions, in the log:

1. **Did the company just kill a guard or a townsman?**
2. **How does the town the player is standing in feel about him right now?**

Everything lives in [mercenaries_crimewatch.lua](../data/Scripts/mods/mercenaries_crimewatch.lua),
on a 1s `crimewatch` scheduler slot. `merc_dev` first, then:

> **Off by default**, with the town watch it feeds. `merc_dev` then
> `merc_townwatch_enable` turns the pair on for a session — see
> [town-watch.md](town-watch.md).

| Command | What it does |
|---|---|
| `merc_crime_status` | running tally, current standing, last 40 kill lines |
| `merc_crime_dump` | every vanilla NPC around you with name, class, relationship, faction id, metaroles |
| `merc_crime_reset` | zero the tallies |
| `merc_crime_on` / `merc_crime_off` | stop and start it |

---

## Telling a guard from a townsman

Three sources, in this order, each one measured against a live census of a Kutná Hora
tavern (release build, 2026-08-28).

**1. Script contexts — the engine's own answer.** `crime_isAuthority`,
`crime_isAuthorityOnDuty`, `crime_isAuthorityOnStationaryDuty`, `crime_isSecurity` and
`crime_isCivilian` are `Class="Entity"` contexts in `Libs/Tables/ai/ScriptContext.xml`,
which vanilla's crime AI branches on with `EntityContextCheck`
(`references/AI/crime/getAuthorityKindByContext.xml`). From Lua that is just
`soul:HasScriptContext`.

Measured: `crime_isAuthority` **does** fire on a real town guard (`kkut_man_302` was
caught by it and nothing else). `crime_isCivilian` fires on almost nobody, so it cannot
carry the civilian side on its own.

**2. The faction path — the workhorse.** `soul:GetFactionID()` returns the faction's
**name**, not an integer:

```
kutnohorsko_settlements_kutnaHora_commonFolk_peasants_additiveNPCs
```

That path is a taxonomy: `<region>_settlements_<place>_<estate>_…`, where the estate is
`commonFolk` (→ `peasants`, `tradersAndCraftmans`, `tavern`, `millers`), `nobility`, or
`soldiers` (→ `guards`, `militia`, `bodyguards`, `townHallGuards`). Guard is tested before
civilian, because a merchant's bodyguard sits under `…_commonFolk_…_bodyguards` and is a
guard, not a shopper.

**3. Entity names — the fallback.** Every level NPC is `<4-letter place>_<role>_<n>` and
the prefix maps 1:1 onto its editor layer (`kkut`=Kutná Hora, `ksta`=Stará Kutná,
`tvez`=Vezicko — 24 on Kuttenberg, 15 on Trosky, in `mercenaries.CrimePlaces`), which
still names the place for quest NPCs that carry no faction we recognise
(`rvacka_firstCzech_3`). For the ROLE, though, names only half work. Quest NPCs are named for their
job (`setkaniVRatbori1_ratiborGuard`, `prepadeniVlasskehoDvora_civilian` — ~167 such names
across both levels) but the everyday population is `kkut_man_412`; an ordinary city guard's
guard-ness lives in his schedule hub link `_@guard_day`, which is level data.

The first census left **5 of 9 kills `unknown`** on contexts and names alone — every one of
them a named tavern regular (`kkut_vepr`, `kkut_strnad`, `kkut_stulec`). The faction path
classifies all of them.

## Am I in a village or a town?

`_settlements_<place>` in the local faction name, and that is the whole test — it is the
**game's** definition, from its own faction tree, so nothing has to be authored. 31
settlement roots across both maps; `mercenaries.CrimeSettlements` lists them.

```lua
local inTown, place, isCity = mercenaries:CrimeInSettlement()
```

This is the gate anything that turns out a town watch must hang off. Three deliberate
rules:

- **`_enemies_` anywhere disqualifies.** `kutnohorsko_enemies_bandits_opatoviceEndgame`
  carries `Labels="settlement"` in the vanilla tree and is a bandit gang.
- **`zikmundovo` is excluded** despite being labelled a settlement. It is Sigismund's army
  camp — a siege camp has no town watch.
- **A quorum of 2** (`CrimeSettlementQuorum`). One Kutná Hora carter met on a forest road
  does not make the forest a town.

Crowd size is reported but is deliberately *not* the test: a battle in open country is a
big crowd and no settlement, and an empty hamlet at night is a small crowd that is still a
village. Kutná Hora is the only faction carrying `Labels="city"`, so `isCity` separates the
one real city from the thirty villages.

## Reading the player's crime rating

**There is no Lua bind for angriness.** The whole reputation surface is write-only from
Lua (`soul:ModifyPlayerReputation`) and readable only from a behaviour tree
(`CheckAngrinessInterval type="Violence" Faction=... Flag=...`, as used by
`references/AI/crime/so_crime_extraGuards.xml`). `angriness_flag.xml` defines the bands:
`low` 0–0.3, `mid` 0.3–0.6, `high` 0.6–0.9, `alerted` 0.9+, and `extraGuardsSpawn` at 0.8.
One witnessed killing is worth 0.8 (`auto_witness_death`).

So the watchdog measures the crowd instead, which is what angriness produces anyway:

- how many nearby townsfolk sit at the hostile floor (`soul:GetRelationship(player, "Current") <= -0.99`)
- `RPG.IsPublicEnemy(playerWuid)` / `player.soul:IsPublicEnemy()`
- `player.soul:HasScriptContext("crime_playerUnderArrestByAuthority")`
- crowd size and guard count, for context (the settlement itself comes from the faction, above)

It logs on **change**, not every tick — a market visit would otherwise fill the log.

## Attributing a kill

`SoulDeathTrigger` does not fire for NPCs the mod did not spawn, so there is no kill
callback to hook: a body is all we ever get. The pass keeps a census of the living, and
anyone alive last pass and a corpse this pass is a death. A corpse we never saw standing
is someone else's business and is ignored.

Attribution is then ordered by strength of evidence:

1. a merc held him as its combat target within the last 12s (`MercTargetOf`) — strongest
2. the behaviour tree confirmed he was fighting us (`IsRecentAttacker`)
3. the player is the nearest of ours, inside 25m, weapon drawn
4. anyone of ours inside 25m

Anything else is `unattributed` and only counted, not logged
(`CrimeLogUnattributed` turns those on).

## Known limits

- The census sphere is centred on the **player** (45m). A merc killing someone further out
  than that is missed. Widening it costs a second sphere query per second.
- Unconscious is not dead — a knocked-out townsman has health > 0 and does not count.
- Tallies are in memory only; they do not survive a save/load. `CrimeWatchOnLoad` clears
  the census on purpose, so a body in Kuttenberg is never pinned on a merc in Trosky.

## Related

- [enemies.md](enemies.md) — the enemy groups, and `enemiesFaction`'s deliberate silence
  about vanilla NPCs
- [combat-target-selection.md](combat-target-selection.md) — `MercTargetOf`, the
  relationship floor and the BT-confirmed attacker channel this reuses
