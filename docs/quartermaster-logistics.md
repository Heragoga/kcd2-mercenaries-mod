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
| Kills (mercs or player) | **+5** each (`MoralePerKill`), **uncapped** — `MoraleMax` is the only ceiling |
| Merc deaths | **−5** each, capped at **−50 per fight** (`MoraleDeathCapPerFight`) |
| Tiredness (>3 days out of camp) | **−10/day** |
| Starving | **−5/day** |
| Drink available | **+10/day** |
| Makeshift inn standing | **+10/day** (social) |
| Wages unpaid | **−10/day** |
| Passive drift toward 0 | **5/day** (negative morale only recovers while **camped**) |

- **Positive morale → combat boost.** Morale 100 ≈ +50% effectiveness ("150%").
- **≤ −50 → low-morale icon** on the player (warning only; see Status icons).
- **Negative morale → desertions**, but only **below −70** (one merc/day of
  continuous morale that low). Above that a sagging squad just fights a bit worse.
- **≤ −90 → mutiny**: instead of deserting, a merc turns on you — it's removed
  and reappears as a hostile **renegade** in the squad's current colours (reusing
  the renegade combat AI).

The drain rates and desertion thresholds above were softened in a balance pass
(deaths/tiredness/wages roughly halved, desertion pushed from −50 to −70) to make
the system more forgiving.

**Kills/deaths are polled**, not event-hooked: a drop in the live merc count we
didn't cause ourselves = deaths; enemies from `CachedEnemies` that later read
`actor:IsDead()` = kills. Best-effort (undercounts rather than inflates).

## Food / Drink

1 unit feeds `FeedRatio` (8) mercs/day, consumed each evening. **Passive food**
from upgrades (food cart, hunter's spots) is subtracted from the need first.
Short at the tally → **starving** (a −50% contribution to the combat number,
plus the morale drain); lifts the moment food is resupplied (`LogiReconcile`),
consuming a ration only at the evening tally. Drink is optional — having it just
feeds morale. Deliver any vanilla food/drink item (generated `FoodItemClasses` /
`DrinkItemClasses`), or buy food (100 gr → 5).

### Two ways to hand supplies over

| Where | What it does |
|---|---|
| **Quartermaster** → *Supplies* → "Here, take this food/drink for the men." | Opens the vanilla item-selection panel (`CreateItemDelivery`) so you pick exactly what and how much. Needs a camp standing — the panel delivers into his inventory, and `LogiPanelFood`/`LogiPanelDrink` count what he received. |
| **Any merc** → *Company management* → the same two lines | No panel, no camp, no quartermaster: `LogiDeliverFood`/`LogiDeliverDrink` take **everything** edible/drinkable you are carrying straight out of your pack. Potions are in neither `FoodItemClasses` nor `DrinkItemClasses`, so Saviour Schnapps and the decoctions are safe. |

The merc-side pair reuses the quartermaster's own tokens (`be68d` / `be69d`) and his
lines, so nothing new was added to the 16 localisation tables.

The **first camp you pitch** stocks `StartingSupplyDays` (3) days of food and
drink for the squad size at that moment (`LogiGrantStartingSupplies`, called from
`SpawnMercCamp`). A saved flag (`QMStartSupplies`) makes it once-only, so upgrade
rebuilds and save restores don't top the stores back up.

## Wages & the war chest

Deducted each evening by tier (5 / 10 / 20). Paid from the **coffer** (war chest)
first, then your purse. Via the quartermaster: **withhold** (→ unpaid morale
drain), **deposit** 500 gr into the war chest, or **withdraw** it. (Selling
arbitrary *loot* into the coffer isn't implemented — the engine gives no way to
enumerate inventory loot to sell — so the coffer is funded by deposit instead.)

## Battlefield spoils & the after-action report

Every **confirmed kill** strips supplies off the body, straight into the same pools the
quartermaster spends:

| Per kill | Amount | In plain terms |
| --- | --- | --- |
| Food | `LootPerKillFood` = 0.3 units | a unit feeds `FeedRatio` (8) mercs for a day, so ten bodies ≈ a day for 24 men |
| Drink | `LootPerKillDrink` = 0.1 units | same units as food |
| Wages | `LootPerKillWages` = 2.4 merc-days | priced at `WagePerTier.medium`, so 24 gr into the war chest |

Food and wages are tuned to buy the **same number of days** per body — the only comparison
the after-action report makes. A day of food is `FeedRatio` units per man and a day of wages
is one merc-day per man, so parity is `LootPerKillWages = LootPerKillFood * FeedRatio`
(0.3 x 8 = 2.4). Move one and move the other.

These are **fractions of a unit** — a body carries a bite and a swallow, not a day's rations
for two dozen men. `accrue()` banks them in `L.lootCarryFood / lootCarryDrink / lootCarryCoin`
and credits only whole units to the pools, so food/drink/coffer (and everything the
quartermaster prints off them) stay integers and nothing is lost to rounding. The carry is
runtime-only — a save loses at most a fraction of a unit.

It reuses the kill detection the morale system already runs (an enemy we were *engaged* with,
now confirmed dead) rather than adding a second one, so the two can never disagree about what
counted as a kill.

Spoils are **not capped per fight**, and neither is the morale gain — both scale with bodies,
because a long fight should both feed the squad and feel like a win. Fresh supplies also clear
the `starving` / no-drink flags immediately, exactly as a delivery does.

When the last engaged enemy goes down, `LogiAfterActionReport` prints **three numbers and
nothing else**: the days of food, drink and wages *this fight* added, at the squad's current
burn rate (`ceil(MercCount / FeedRatio)` per day for supplies, `LogiWageTotal` per day for
coin). The per-fight haul is tallied in `L.fightLootFood / fightLootDrink / fightLootCoin`,
reset on the rising edge of the fight alongside the morale cap.

It used to also print kills, stock totals and the full wage runway; that is the
quartermaster's job (`LogiAskStats`), and on-screen it was a wall of text. Anything under ten
days shows one decimal, so a small haul doesn't read as "0".

Note this is not the "sell loot into the coffer" feature described below as unimplemented — no
inventory enumeration is involved. The supplies are credited directly.

## Combat effectiveness

A single net % is computed per squad — `morale*0.5 (if positive) + smithy 20 +
practice trainLevel×8 − starving 50` — and the **closest** of the bucketed combat
buffs (−50 / −25 / +15 / +30 / +50 / +75 %) is applied to each merc, plus the
alchemy survivability buff if built. `LogiApplyBuffs` only touches a soul when
its signature changes, so it's cheap every tick and new mercs inherit the state.
Magnitudes (buff params) are first-pass.

## Status icons (player HUD)

Six red debuff icons on the player's soul mirror the squad's state, so the
management layer is legible without opening a dialog. They carry **no stats** —
purely visual. Defined in
[buff__mercenaries.xml](../data/libs/tables/rpg/buff__mercenaries.xml) with
custom art in `data/libs/UI/textures/icons/buffs/` (`<name>_icon.dds`, referenced
without the `_icon` suffix); registered and driven in
[mercenaries_management.lua](../data/Scripts/mods/mercenaries_management.lua)
(`LogiUpdateStatusBuffs`, called each logistics tick).

| Icon | Triggers when |
|---|---|
| Low morale | morale **≤ −50** |
| Exhausted | **3 days** out of camp (`tiredness`) |
| Wounded | any live merc **< 50% health** |
| No drink | drink stock **0** and no inn covering |
| Short rations | **1 day** of food left (`LogiSupplyDays == 1`) |
| Starving | **0 days** of food left |

`SetStatusBuff` only touches the soul on a state change, so the once-per-tick
evaluation never replays the buff-appeared animation. The icons use a week-long
`Cpp:Fading` duration purely so the disk renders a full-red ring rather than a
flat icon; the duration is a drain rate, not a lifetime — the evaluator owns
on/off. Testing: `merc_buff_all` / `merc_buff_1..6` freeze the evaluator
(**test mode**) so a forced icon isn't overwritten within 5 s; `merc_buff_auto`
hands control back. `merc_buff_list` shows the mapping and current mode.

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

### Taking one back down

*Camp upgrades → "Take one of the improvements down."* removes a single upgrade instead
of the whole layout (`LogiRemoveUpgrade`; the older "tear it all down" option is still
there). Eleven entries, listed in `UpgRemovable`, covering the stations above plus the
placed defences (archer towers, archer carts, palisade, gates). No refund — it undoes a
layout, it does not sell. The stations come down by clearing their flag and rebuilding
the camp; the defences are cleared out of the world **and** out of the saved layout, or
the next restore would put them straight back. See
[camp.md → Taking one improvement down](camp.md#taking-one-improvement-down) for the
mechanics, and for why a rebuild no longer moves the upgrades that stay.

Console: `merc_camp_remove` (no argument lists the eleven).

## Dialog / persistence

The dialog (`quartermaster_dialog.xml`, both region quests) exposes Supplies,
Wages & war chest, Camp upgrades, a **status** readout (food / drink / wage
runway / morale, all bucketed since `SendInfoText` can't print raw numbers), and
a **tutorial**. Each leaf → Out port → token → `mercenaries.lua` → the matching
`Logi*` function. The two supply hand-overs are mirrored onto every merc's
`dismissal_dialog.xml` (`mercenary_give_food` / `mercenary_give_drink`) so the
squad can be fed with no camp pitched. State is stored field-by-field via `SaveString`/`LoadString`
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
