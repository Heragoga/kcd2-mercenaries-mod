# Quartermaster Logistics (morale-centric)

The camp-management systems the [quartermaster](quartermaster.md) fronts, all
routed through one central stat: **morale**. Everything lives in
[mercenaries_logistics.lua](../data/Scripts/mods/mercenaries_logistics.lua),
ticked every 5 s (real) off in-game world time (`Calendar.GetWorldTime()`), so
sleeping/waiting/fast-travel advance it. The daily "upkeep" fires when a new
**evening** (18:00) is crossed. All state is save-persistent and **persists
across breaking camp**. Every number is a first-pass tunable.

## Morale (−100 … 100, default 0)

The throughput variable. Every other system feeds it; combat effectiveness,
desertion and mutiny all read off it.

| Input | Effect |
|---|---|
| Kills (mercs or player) | up to **+20 per fight** (`MoralePerKill` each, capped) |
| Merc deaths | **−10** each |
| Tiredness (>2 days out of camp) | **−20/day** |
| Starving | **−10/day** |
| Drink available | **+10/day** |
| Makeshift inn standing | **+10/day** (social) |
| Wages unpaid | **−20/day** |
| Passive drift toward 0 | **5/day** (negative morale only recovers while **camped**) |

- **Positive morale → combat boost.** Morale 100 ≈ +50% effectiveness ("150%").
- **Negative morale → desertions** (one merc/day of continuous negative morale).
- **≤ −80 → mutiny**: instead of deserting, a merc turns on you — it's removed
  and reappears as a hostile **renegade** in the squad's current colours (reusing
  the renegade combat AI).

**Kills/deaths are polled**, not event-hooked: a drop in the live merc count we
didn't cause ourselves = deaths; enemies from `CachedEnemies` that later read
`actor:IsDead()` = kills. Best-effort (undercounts rather than inflates).

## Food / Drink

1 unit feeds `FeedRatio` (5) mercs/day, consumed each evening. **Passive food**
from upgrades (food cart, hunter's spots) is subtracted from the need first.
Short at the tally → **starving** (a −50% contribution to the combat number,
plus the morale drain); lifts the moment food is resupplied (`LogiReconcile`),
consuming a ration only at the evening tally. Drink is optional — having it just
feeds morale. Deliver any vanilla food/drink item (generated `FoodItemClasses` /
`DrinkItemClasses`), or buy food (100 gr → 5).

## Wages & the war chest

Deducted each evening by tier (5 / 10 / 20). Paid from the **coffer** (war chest)
first, then your purse. Via the quartermaster: **withhold** (→ unpaid morale
drain), **deposit** 500 gr into the war chest, or **withdraw** it. (Selling
arbitrary *loot* into the coffer isn't implemented — the engine gives no way to
enumerate inventory loot to sell — so the coffer is funded by deposit instead.)

## Combat effectiveness

A single net % is computed per squad — `morale*0.5 (if positive) + smithy 20 +
practice trainLevel×8 − starving 50` — and the **closest** of the bucketed combat
buffs (−50 / −25 / +15 / +30 / +50 / +75 %) is applied to each merc, plus the
alchemy survivability buff if built. `LogiApplyBuffs` only touches a soul when
its signature changes, so it's cheap every tick and new mercs inherit the state.
Magnitudes (buff params) are first-pass.

## Upgrades (stat-only; no visuals yet)

Bought through the quartermaster, all save-persistent:

| Upgrade | Cost | Effect |
|---|---|---|
| Food cart | 500 | feeds 10 mercs for 10 days, then gone |
| Makeshift inn | 1000 | drink for 3 days + a morale (social) bonus while it stands |
| Hunter's spot | 2000 | feeds 5 forever (needs ≥2 mercs in camp); **stackable** |
| Portable smithy | 3000 | permanent +20% combat |
| Alchemy bench | 3000 | permanent survivability buff |
| Practice yard | 1000 | permanent; +1 training level/day (each ≈ +8% combat, cap 6) |

**Practice yard is an abstraction:** rather than literally renaming weak→strong
mercs (their tier is baked into the entity name and drives wages/equipment), it
raises a squad-wide *training level* that feeds the combat number — so a cheaply
hired, low-wage squad becomes effective over time, which is the intended
"save on recruitment" payoff.

## Dialog / persistence

The dialog (`quartermaster_dialog.xml`, both region quests) exposes Supplies,
Wages & war chest, Camp upgrades, a **status** readout (food / drink / wage
runway / morale, all bucketed since `SendInfoText` can't print raw numbers), and
a **tutorial**. Each leaf → Out port → token → `mercenaries.lua` → the matching
`Logi*` function. State is stored field-by-field via `SaveString`/`LoadString`
(de-duplicated; tiredness quantised); `lastTick` is not persisted (reset on load
so a reload doesn't count as elapsed time).

## To verify / tune in-game

- Buff magnitudes, all costs, and the morale rates are first-pass balance.
- Kill/death polling is approximate (fights far from the player, fast corpse
  despawns, etc. can miss).
- Mutiny renegades wear the squad's outfit but are renegade *entities*, not the
  literal merc.
- `AddMoney` (coffer withdraw) is guarded — if the API differs the coffer is
  kept rather than the coin vanishing.
