# The bandit-camp contract

> **The quartermaster no longer issues this run.** Aleksej's nine beats (`docs/aleksej.md`) are
> the Kleinkrieg quest and replace the twelve-contract cycle; his accept lines are gone and the
> hand-in no longer chains into the next contract. What he offers now is the repeatable
> [bounty](bounty.md). Everything below still describes the **camp machinery**, which both the
> bounty and Aleksej's beats are built on, and the hand-in half of the arc, which is kept so a
> contract taken before the change can still be closed out. `merc_banditcamp_start` is the only
> way left to begin one.

The quartermaster's "destroy the bandit camp" job. It is the mod's **first real journal
quest** — everything before it (134 `CreatePlayerReward` tokens, the delivery panels) only
used Skald as a dialog-to-Lua wire. This one puts an entry in the journal, a marker on the
map, and closes itself when the last bandit falls.

| Piece | File |
|---|---|
| Quest graph: objective, journal text, marker | `data/Quests/mercenaries/kutnohorsko/bandit_camp_quest.xml` |
| Registration | `data/Quests/mercenaries/kutnohorsko.xml` |
| Dialog branch ("Any work going?") | `.../mercenaries_background_quest/quartermaster_dialog.xml` |
| Dialog port → token | `.../mercenaries_background_quest.xml` (`exec_qm_banditcamp`) |
| Everything that actually happens | `data/Scripts/mods/mercenaries_banditcamp_quest.lua` |
| Camp leader soul / face | `soul__mercenaries.xml`, `skald_character__mercenaries.xml`, `enemiesappearance.xml` |
| Layout authoring tool | `data/Scripts/mods/mercenaries_banditcamp.lua` (the F5–F11 builder) |

Everything below is Kleinkrieg's. The quartermaster's **second**, repeatable job runs on the
same camp machinery from its own slot — see [the standing bounty](bounty.md), which also
documents the slot pointer that lets two contracts be live at once.

---

## Authoring a camp

The builder places props; the quest replays them. Two steps:

```
merc_bcamp_site_here     -- stand where the camp centre should be; prints a BanditCampSites row
merc_bcamp_binds         -- F5-F8 pick a category, same key again cycles variants
                         -- left-click places, right-click undoes (weapon must be drawn)
merc_bcamp_dump          -- prints the layout as a pasteable Lua table
```

Paste the site row into `mercenaries.BanditCampSites` and the layout into
`mercenaries.BanditCampLayouts` in `mercenaries_banditcamp_quest.lua`.

**The dump is relative.** Coordinates come out as offsets from the first piece you placed,
and the loader rotates the whole layout by the site's `yaw` before adding the site origin —
so one layout can be dropped at any number of sites, facing any direction. `yaw` is radians.

**The site origin is the layout's FIRST piece**, not wherever you were standing.
`merc_bcamp_dump` prints a matching site row using that piece's real position — use that one.
`merc_bcamp_site_here` is only for scouting a spot *before* you build.

Plain props, furniture, campfires, the lootable chest, the `(light)` lamp variants and
**archer towers** all replay. Camp upgrades and archer carts do not — the loader logs and
skips them.

| Piece | Status |
|---|---|
| `archer tower` | **Works.** See below. |
| `smithy`, `alchemy bench` | **Work**, and the labels' "(needs X nearby)" is the builder's wording, not a real constraint — `ForgeFindNearest` searches *loaded* entities, so the camp's distance from a village does not matter. These two are built by their own spawners rather than replayed, because each **borrows a real Smithery / AlchemyTable from the world and moves it** (`BanditCampBorrowed`). Two consequences: the authored spot is pinned by seeding the station tile first (called cold they scan for their own flattest patch and wander metres off), and the record is then taken off the player-camp singleton into this camp's state so the two do not share one slot. **`DespawnBanditCampBorrowed` must run whenever the camp comes down** — those are moved world objects, and deleting them instead would strand a village's anvil at a dead bandit camp. |
| `archer cart` | **Works**, same treatment as the watchtowers: `SpawnArcherCart(pos, yaw, {mode="hostile", group=...})` puts three enemy archers on a wagon. They join the kill count when they spawn (deferred, like the tower archers) but are *not* marked as tower archers, so the ground-cleared descent leaves them alone — a cart is at ground level already. |
| `makeshift inn`, `food cart`, `hunter's spot` | **Work**, but not through their own spawners. Each of those sets a singleton (`CampInn` / `CampFoodCart` / `CampHunt`), needs `self.CampCenter`, and pushes anything sittable into the **player's** `CampSeats` pool — so a bandit camp built through them fights the player's own upgrades. What is reusable is their **layout tables**, which all share one shape (`{n, m, fwd, lat, up, rx, ry, rz}`), so `BanditCampReplayStation` replays them into the camp's own entity and seat lists. Add another by putting a row in `BanditCampStations`. Matched by label, since the builder's catalogue entries point at the player-camp functions. |

### Sites and layouts

`BanditCampLayouts` holds named layouts; `BanditCampSites` holds where they can stand, each
naming the layout it uses. Two ship:

In run order:

| # | Site | Layout | Pieces | Beds | Seats | Towers/Carts | Reads as |
|---|---|---|---|---|---|---|---|
| 1 | `woodland_camp` | `default` | 25 | 5 | 4 | 2 towers | a small roadside camp, ~9 men |
| 2 | `hillside_camp` | `hillside` | 48 | 11 | 12 | — | two hearths and a mess table, a full 20-man band |
| 3 | `hillfort_camp` | `hillfort` | 52 | 6 | 7 | 3 towers | broken ground, torch-lit approach, a smithy |
| 4 | `ring_camp` | `ringcamp` | 49 | 9 | 7 | 1 cart | nine tents round one fire, alchemy bench, archer cart |
| 5 | `hideout_camp` | `hideout` | 75 | 11 | 18 | 2 towers | built round the player HOUSE as the leader's quarters |
| 6 | `south_camp` | `southcamp` | 62 | 13 | 8 | 2 towers | three clusters over 30m, food cart and inn |
| 7 | `mining_camp` | `mining` | 57 | 8 | 14 | — | a working camp, not a fortified one: no towers, no borrowed upgrades, the most compact of the set |
| 8 | `roman_fort` | `romanfort` | 74 | 13 | 8 | 4 towers | **last before Raborsch** — thirteen tents walled round two hearths, two benches, a smithy, four corner towers |

### Kleinkrieg

The run is now a **story arc**: twelve contracts alternating camps and patrols, following
stolen Kuttenberg silver from peasant raids up to Kanizsai, the archbishop buying an army
with ore he cannot spend. The design rule is the spec's own: *nobody reads the letters* —
every plot beat lands through the quartermaster's accept and turn-in lines (shown as info
text; per-contract spoken dialog would need twelve Skald sequences and is future work). The
letters on the leaders are proof and flavour for whoever opens them; the seal clue between
Letters 1 and 3 lives in the item descriptions.

`KleinkriegContracts` is the whole arc: per contract a site, an enemy group (Rabble=looter,
Trained=bandit, Veteran=sigi, Elite=knight), a **ratio against the followers actually in
tow** (sometimes outnumbered, sometimes not — the spikes and dips are the storytelling), a
letter, the two dialog keys, and specials: `wounded` (hillfort's survivors start hurt),
`patrol` (no props; the whole band paces a wide loop), `disperse` (the looter column scatters
if approached with steel sheathed — the flag is saved in `KKDispersed` for Raborsch's first
wave), `leaderClothing`/`leaderHealthMult` (Sigi scraps on the hillside leader, the captain
in knight's kit at the convoy and the swamp). A lone player gets every contract, floored at
`min`, capped at 10 on the field. Contracts without a letter close the search objective on
the last kill. Raborsch slots in between the fort and the swamp when it is built.

### The quartermaster's dialog changes per contract

His lines are **spoken dialog gated per contract**, not one generic "any work?" repeated
twelve times. Twelve accept options and thirteen report options (contract 10 has a second
version for a dispersed column) live in `quartermaster_dialog.xml`, each with its own
`EntryCondition`.

The mechanism is vanilla's own — `EntryCondition="Port('x')"` on a `<Sequence>`, with bool
In-ports on the dialog (4700 vanilla dialogs do this):

- **`kk1`..`kk12`** latch as the run reaches each contract. They are monotonic, so
  `Port('kkN') AND !Port('kkN+1')` isolates exactly the contract in hand.
- **`kk_open`** (a contract is running) hides the accept lines, **`kk_ready`** (the job is
  done and nothing is outstanding) shows the report lines. Each has its own **set and clear
  token**, pushed by `KleinkriegSyncGates` on the 1 Hz tick whenever the value changes.

  These originally piggybacked on the flow tokens — accept sets open, letter-taken sets ready,
  paid clears both. That broke the hand-in outright: **a contract carrying no letter never
  creates a letter-taken token**, so `ready` was never set and the report line could not be
  selected. Six of the twelve contracts are letterless, including the first. Riding on tokens
  whose lifetime belongs to something else also left the gates stale across a reload.
  `_kkOpen`/`_kkReady` start nil, so the first tick after a load re-asserts both.
- **`kk10alt`** picks his alternate line when the peasants were dispersed rather than killed.

The states live in `mercenaries_background_quest.xml`, because a dialog's In-ports can only
be driven by the module that instantiates it; Lua latches them by dropping a phase token
(`KleinkriegSyncPhase`, catching up from 1 so an older save lands on the right lines) which
`BanditCampSweepTokens` then removes. The latched state is what persists, not the token.

Both halves keep a **generic fallback gated on `!Port('kk1')`** — if no phase is set at all,
the original offer and hand-in still work, so a gating bug can never leave the player unable
to take or complete a contract.

The accept and report lines are no longer info-text toasts; those are back to a plain "job
taken" / "paid" receipt, since the story is now spoken.

### One continuous quest

Kleinkrieg is **a single journal entry that stays open across the whole arc**, not twelve
errands. `bc_quest_state` opens on the first contract and closes only on `bc_arcdone_trigger`,
which Lua fires when the last contract is paid. Wiring quest-Done to the per-contract hand-in
— which is what it originally did — made the entry close and reopen twelve times, so the arc
read as unrelated jobs.

Two things make that work rather than leaving a quest sitting open doing nothing:

- **`bc_contract_state`** tracks one contract, start to hand-in. It is what the quartermaster's
  QuestGiver icon gates on, so he lights up between contracts (covering both "never taken" and
  "just finished") and goes dark while one is running.
- **`next_contract`** is a fourth objective, Active between contracts with a marker on the
  quartermaster. `find`/`deliver`/`next` all take `SetNone` from the accept trigger, so each
  contract resets the legs and the open quest shows one live objective at a time instead of
  accumulating ticks.

The state machine, per contract: accept → quest Active, contract Active, *destroy* Active,
the rest None. Clear → *destroy* Done, *find* Active. Loot → *find* Done, *deliver* Active.
Pay → *deliver* Done, contract Done, *next* Active. On the final pay, arc-done closes the
quest. The quest stays `Repeatable`, so replaying a contract afterwards reopens it.

The arc-done token joins `BanditCampSweepTokens`, which deletes a signal token one tick after
Skald has seen it — otherwise it lingers in the pack as a stray sack of nails.

### Patrols walk the real roads

The three patrol contracts sit on the **recorded patrol routes**
(`mercenaries_patrol_routes.lua`, captured in game with the F5–F8 recorder), not on invented
coordinates. A patrol site names `route` + `pt` instead of a position:

| Contract | Route | Point | Where |
|---|---|---|---|
| 4 company | `route3` | 80 | mid-map, ~950m from the nearest camp — soldiers where none should be |
| 7 convoy | `route21` | 50 | the ore road, ~770m out from the mine just taken |
| 10 looters | `route2` | 150 | west of the southern camp — the unpaid half walking home |

`BanditCampSiteAnchor` resolves a site's position from the road point, so **the recorded route
is the single source of truth**: re-record the routes and the contracts move with them. The
`x/y/z` on the row are the resolved point, kept only as a fallback if a road is re-recorded
shorter than the stored index. Every consumer goes through the anchor — spawn, the marker
leader, the picker's distance test, and the despawn range.

### The column marches as one unit

A patrol contract is a column, not a scattered picket. **One man walks the recorded road**;
everyone else follows the man ahead, so they travel and arrive together. Giving each man his
own slice of road — the first attempt — let them drift apart and trickle into the fight.

The follow chain is `mercenaries.BanditCampColumn` (`[followerWuid] = the man ahead`),
consumed by a new **first** branch in `camp_actor.xml`. Three things made that the right place:

- `camp_actor` **already fires** for these bandits, so no scheduler XML needed touching.
  `IsCampActor` gained a column check, since that is what decides whether the tree runs at all.
- `CrimeFollower` may only run inside a **fired interrupt behaviour** — see
  [[reference_follower_nodes_need_behaviour]]. `camp_actor`'s root is one, same as
  `patrol_follow.xml`, which this arm is copied from.
- The arm ends on a **change, not a timer**. `CrimeFollower` never returns on its own, and
  restarting it makes the follower dash to re-acquire his station, so a short time-box would
  produce a catch-up sprint forever.

`ColumnFollowRole` walks up the chain past any dead man, so the column closes up instead of
trailing behind a corpse. `BanditCampColumn` is the mod's own table, deliberately not one of
the shared camp tables — those get replaced wholesale when the player's camp is rebuilt, which
is exactly how the bandit patrol records were trampled before.

Behaviour binds by **soul → brain → scheduler**, never by name prefix, so the bandits could not
simply be renamed onto the roaming-patrol tree. Moving them onto `patrol_brain` was also ruled
out: `patrol_scheduler.xml` has a melee-only combat arm, and the company and convoy contracts
both field archers.

The band **strings out along the road**: `bandPos` places each man a few points apart,
alternating sides of the centreline (perpendicular to the road's own heading), across a
**fixed ~90m window** regardless of band size — a fixed per-man gap would trail a big band
over a hundred metres and feed it into the fight one at a time. Each man then walks his own
overlapping there-and-back stretch (`BanditCampRoadWalk`, ±5 points ≈ 105m), so the column
drifts apart and closes up rather than marching in lockstep. The return leg matters: the
patroller cycles its waypoint list, so a one-way slice would send him back through every
point to reach the start again.

Both fall back to the old ring pacing if the road is missing — and `route`/`pt` are restored
from the site table on load alongside `layout`, since the save blob carries only coordinates.

**The camps are an ordered run, not a random draw.** `BanditCampSites` is in the order they
are meant to be fought and ends at the **roman fort — the last camp before Raborsch**. A
contract hands out the next site the player has not finished; past the end it stays on the
fort, since the quest is repeatable and re-running it is better than refusing the job.

Progress is the count of contracts **paid for**, persisted separately from the contract itself
(`SaveString("BCampDone")`) because it has to outlive each one. It advances on payment, not on
the last kill: a camp you cleared but never collected on is not finished, and should still be
the one you are offered. `merc_banditcamp_reset` restarts the run; `merc_banditcamp_status`
prints where you are in it.

The one exception to the order: if the next camp in the run is closer than
`BanditCampForgetRange`, the contract falls through to the furthest site instead, so a camp is
never pitched on top of the player.

### Bandit watchtowers

`SpawnTowerStation(pos, yaw, {mode="hostile", group="bandit"})` builds one.

The mode was the easy half — `"hostile"` ("the player and their mercs") was already
implemented in `FindStaticArcherTarget`. **The soul was the half that mattered.** The first
version reused the merc `StaticArcherSouls`, which are `factionName="mercenariesFaction"` on
`char_static_archer_*`, and that produced exactly two bugs: the camp's own bandits attacked
their tower (enemies vs mercenaries faction hostility), and the archer's UI name came from
`char_mercenary_archer_uiName` — a "mercenary archer" manning a bandit watchtower.

So `group` now switches the **soul** as well as the clothing, to
`StaticArcherEnemySouls`: same `static_archer_brain`, but `enemiesFaction` and a
`char_enemy_bandit_*` character. Note `soul_vip_class_id="0"`, **not** the `16` the merc
towers carry — an enemy tower archer has to be killable or the contract can never complete.

His clothing is a **fixed two-outfit set** (`StaticArcherEnemyOutfits`, both light looter
kit), not a roll from a group pool — a bowman on a platform should read as a lookout in rags
rather than a man-at-arms. Pinning it is what makes the descent below seamless: the chosen
preset is recorded on his `StaticArchers` record so the man who comes down is wearing what
the man on the platform was wearing. Roll it randomly at either end and he changes clothes
mid-fight.

Naming carries the rest. An enemy tower archer is
`SpawnedEnemy_towerarcher_archer_<tier>_<n>_<guid>`, which satisfies four separate tests at
once: `SpawnedEnemy_` makes `SideOf()` give him enemy combat rules instead of the merc leash
to the player and lets `IsModEnemyName` route the squad's fire at him; `_archer_` gets him
the bow and 40 arrows; and `_towerarcher_` is what `IsStaticArcherName` now also matches, so
the drop-to-spot keeper still holds him on the deck and towers still never shoot each other.

Two consequences worth knowing:

- **A tower archer joins the kill count**, so the contract cannot be paid while a tower is
  still manned. He arrives on a delay (`TowerArcherSpawnQueue`), so he is *adopted* on the
  first tick he exists and `S.target` goes up with him — counting at build time would count
  a bandit who does not exist yet.
- **They come down once the ground is cleared.** With every non-tower bandit dead,
  `BanditCampBringArchersDown` swaps each remaining tower archer for an ordinary bandit
  archer of the same group at the foot of his tower, keeping the roster slot. He is *swapped*
  rather than walked down because the deck has no navmesh and `static_archer_brain` is
  "stand and shoot" — a brain cannot be changed at runtime — so a real climb is not
  available. The replacement runs the normal enemy archer AI and will close and kite, and
  **wears the same outfit** — his preset is read off the `StaticArchers` record before
  `RemoveStaticArcher` clears it, then pinned on the replacement via `BanditCampDressUp`'s
  third argument. It reads as him having come down while you were busy; watch it happen in
  the open and it is a pop. It runs *before* the death count each tick, so the swap is never
  banked as a kill.
- **Bandit towers consume the player's tower allowance.** `TowerMaxCount` is 5 for all
  towers, everywhere. A camp with two towers therefore fails to build them if the player
  already has four of their own; the loader logs `tower refused (cap reached)` and the camp
  spawns without them. Raise `TowerMaxCount` if that bites.
- `EquipEnemy(ent, group, true)` gives clothing and deliberately **no weapon**, so
  `EquipArcherWeapon` still has to run afterwards for the bow and its 40 arrows. An archer
  with no ammo looses once and then stands there.

Furniture placed with a smart object (chairs, stools, logs, beds) automatically becomes a
claimable seat or bed, which is what gives you a camp where people are actually sitting
rather than standing in a ring. The number of beds and seats therefore sets how many bandits
can loaf convincingly; beyond that they eat, gather herbs and walk the perimeter instead.

---

## How the quest runs

```
quartermaster dialog "I'll take it"
  └─ port quartermaster_banditcamp
      └─ CreatePlayerReward token be81d              (Skald → Lua)
          └─ mercenaries.lua MonitorInventory → BanditCampAccept()
              ├─ BanditCampScale()  picks group, headcount, archers, purse
              ├─ records the contract + saves it
              └─ creates token be83d                 (Lua → Skald)
                  └─ ItemDescriptorTrigger → SetActive on both states
                      └─ journal entry + map marker appear

... player travels; the monitor builds the camp when they get within 300 m ...

last bandit dies
  └─ BanditCampComplete(): token be82d                  (Lua → Skald)
      └─ objective 1 SetDone, objective 2 SetActive
          └─ "Take the letter to the quartermaster", marker moves to him

player loots the letter (be84d) from the camp chest

quartermaster dialog "I found a letter in that camp."
  └─ port → token be85d                                 (Skald → Lua)
      └─ BanditCampDeliverLetter(): checks the letter is really in the pack,
         consumes it, AddMoney, then token be86d         (Lua → Skald)
          └─ objective 2 SetDone + quest SetDone
              └─ quest leaves the active journal

player walks 50 m away  →  props and bodies despawn
```

### The letter

The bandit leader keeps a letter in the camp's chest, and the contract is not paid until it
reaches the quartermaster. It is a **real readable `Document`** (`Type="5"`, the vanilla
letter type, modelled on `letter_huntsmanRenes`), not one of the invisible tokens — the
player can open and read it, and `IsQuestItem` keeps it out of the merchants. Its body is
three `DocumentContent` `Parts`, one per paragraph; that is how vanilla breaks up document
text, and embedding newlines in a single localization row instead produces multi-line `<Row>`
entries that do not match the format the rest of the file uses.

It gets into the chest through the Stash's **`Database.sInventoryPreset`** property at spawn
(`inventory_banditcamp_chest` → `<PresetItem Name="merc_banditcamp_letter" Amount="1"/>`),
which is the hook vanilla fills its own containers through — see
`references/kcd2-mod-docs-main/Libs/Tables/item/InventoryPreset__stashes.xml`. Only the
**first** chest in a layout gets it (`S.letterChestPlaced`).

Two rules keep the letter reachable:

- **A cleared camp is never torn down while the letter is still in its chest.** The despawn
  is gated on the player actually holding it; leave without looting and you come back to a
  standing, lifeless camp. Tearing it down then would make the contract uncompletable.
- **A cleared camp never unloads and rebuilds**, because that branch of the monitor returns
  early — so the chest can never be respawned with a second letter. On a *live* camp the flag
  does reset, since the old chest was destroyed with the rest of the props.

Handing in without the letter is refused with a message rather than half-completing, so the
dialog option can be listed unconditionally instead of wiring an inventory condition into
Skald.

### Gear

A camp of twelve drawn from one group's ten outfits reads as a uniform. `BanditCampDressUp`
re-dresses every member from `BanditCampClothingGroups` — bandits, looters and Sigismund's
men merged, 34 presets — and re-rolls each footman's melee category through the
`preset = 1` "random" path so they aren't all carrying the same thing. Archers are left
alone: `EquipMercenaryWeapon` routes `_archer_` names straight to the bow set, so re-rolling
one only produces the same bow again.

This deliberately draws on pools the mod already ships (`docs/enemies.md`) rather than
defining new ones. Sigismund's kit is in there as plausibly stripped off bodies; drop it from
the list if a camp should look purely ragged.

### Alertness

A camp does not fight the moment it can see you. Until it is **alerted**, its bandits take no
targets at all: `BanditCampSuppressed` short-circuits `FindEnemyTarget` (the footmen) and
`FindStaticArcherTarget` (the towers). The tower guard matters most — a watchtower reaches
90 m and would otherwise open fire long before anything got near.

The merc side needs its **own** copy of the gate, and the reason is worth spelling out because
the obvious assumption is wrong: `IsValidEnemy` does *not* fall back on the weapon-drawn check
here, because `UpdateEnemyCache` deliberately calls it with `skipWeaponCheck=true` so that a
hostile who has drawn but not yet swung is still cached. Without the explicit suppression a merc
could lock onto a still-docile bandit from `EnemyScanRadius` (18 m) — well outside the 10 m the
camp itself would notice at — and stand there flapping his weapon at a man who would neither
alert nor fight back.

It wakes on any of:

| Trigger | Notes |
|---|---|
| Someone within `BanditCampAlertRange` (10 m) | Player or any living merc, measured per bandit |
| A bandit loses health | Any range — shooting a sleeper from a hilltop has to start a fight |
| A bandit dies | Catches a kill the health poll didn't see |
| **A bandit takes one of ours as his target** | Any range. The authoritative one — the other three are early warnings |

The last trigger closes the hole the first three left: a camp could be mid-brawl and still read
as asleep, which suppressed every one of its members out of the squad's target cache — so the
mercs stood and watched. It is checked from two places. `BanditCampAlertTick` polls it once a
second like the others, and the squad's own target cache calls `BanditCampAlertFor` the instant
it sees a lock-on, which wakes the camp **that owns that man** without waiting for the tick.
`BanditCampAlert` reads `self.BCQ`, so any caller from outside the monitor's per-slot pass has to
bind the slot around it — the pointer is whatever the last bind left behind, and for a call
arriving off the target selector that is usually the wrong camp. See
[combat-target-selection.md](combat-target-selection.md), "An unalerted bandit camp cannot hide a
fight it has started".

Waking the camp rather than exempting the one man who is fighting is deliberate: the rest of them
are in it too, and the squad is supposed to engage the camp.

Alertness is per-standing-camp: walking far enough to unload the camp and coming back gives
a calm one, since the men who saw you were the ones unloaded. `merc_banditcamp_alert` wakes
it from the console.

### Conversations

Bandits hold the **same real conversations the camp mercs do**: `camp_actor.xml` reads
`_G.MercCampChats`, and `BanditCampChatTick` pairs them with an alias from the mod's own
`CampGossipAliases` (`gossip_merc_*.xml`) rather than leaving them to the vanilla fallback.
Nobody chats once the camp is alerted.

An earlier note here claimed bandits could only use the vanilla `GOSSIP` pool because their
souls "use vanilla voice 106". That was wrong on both halves. The gossip dialogs are built
from **harvested vanilla lines** — vanilla roles (`GOSSIP_OBECNY_MUZ_1/2`) over the 660 oggs
in `voice/gossip` — so there is nothing merc-specific in them; and the bandit skald characters
already carry exactly the same three voice ids as the mercs (106 / 132 / 239), so the audio
resolves for them identically. No new recordings, no new characters.

Their entries carry `foreign = true`, and **every merc-side loop over that table has to honour
it** — there are four:

- the blanket wipes (`CampChatTick`'s no-camp branch plus `BreakMercCamp` and friends) now go
  through `ClearMercCampChats`, which drops merc entries only;
- the stuck-pair age-out skips foreign pairs — it runs on a 5 s tick and would expire them at
  the wrong cadence;
- the `activePairs` cap counts merc pairs only, or three bandit conversations would consume
  the squad's entire chat budget (`CampMaxConcurrentChats` is 2) and silence the camp.

Tick rates differ and the constants are **not** interchangeable: `CampChatHoldTicks` is 72 on
a 5 s tick (~6 min), while this tick is 1 Hz, so the bandit side has its own
`BanditCampChatHoldTicks = 360`. Reusing 72 here would have cut conversations off after 72
seconds — inside the BT's own 5-minute dialog `Timeout`, so it would have killed gossip that
was still playing.

### Scaling

`BanditCampScale()` reads `_G.MercCount`:

| Squad | Group | Bandits | Archers | Purse |
|---|---|---|---|---|
| 0 | looters | 5 | 0 | 275 |
| 6 | bandits | 9 | 1 | 810 |
| 20 | bandits | 20 | 3 | 1800 |

Headcount is `5 + 0.75 × mercs`, clamped to 5–20. Looters below six mercs, bandits above.

### Coming and going

The camp is never spawned at accept time — it is somewhere else on the map. The monitor
builds it when the player comes within `BanditCampForgetRange` (300 m) and unloads it when
they leave, **remembering the body count**, so returning does not hand you a fresh camp.
The leader is not resurrected if he already died (`S.leaderDead`).

After the contract is paid out the props stay until the player is
`BanditCampDespawnRange` (50 m) away, so nothing vanishes on screen.

---

## The two things worth knowing

### The map marker rides a soul

`<EnumLog Marker="...">` on an objective log points at an entry in the quest's `<Assets>`.
Vanilla feeds it either a `SoulAsset` or a `TagPointAsset`/`TriggerAreaAsset`. **The
tag-point and area kinds are level-editor-placed and therefore dead to this mod** — the
same wall that killed cutscenes (`docs/cutscenes.md`). A `SoulAsset` resolves straight from
the Skald database, which the mod controls, so the marker is hung on a soul:

```xml
<SoulAsset Name="banditcamp_leader" SharedSoulGuids="7a1c9e40-5d2b-4f83-9c16-8e5a3b7d0f21" />
```

`SpawnEnemyAt` already spawns NPCs with `properties.guidSharedSoulId`, which is exactly what
a `SoulAsset` matches — so a Lua-spawned NPC is visible to Skald. The camp leader has his
**own** soul rather than borrowing one of the ten shared bandit souls, because those are
round-robined and several NPCs can share one, leaving the marker ambiguous.

### The quest-giver icon

The quartermaster carries a `ShowMapMarker` of `MarkerType="QuestGiver"`, so the camp reads
as a place with work going rather than one you have to go and ask at. It is driven by
`math::boolean::Not` off `bc_quest_state.Active`, which means it shows whenever a contract is
**not** running — covering both "never taken" and "finished", since the quest is repeatable —
and hides while one is in progress so it does not compete with the camp's own objective
marker.

`not` is the second-commonest `IsActive` source for `ShowMapMarker` in vanilla (17 uses,
behind `and`), and the chain still traces back to a State, which is what that port's
validation requires. He resolves through the same `SoulAsset` mechanism as the camp leader —
Lua-spawned with a matching `guidSharedSoulId` — so no level data is involved.

### The objective marker

**The anchor has to exist before the player gets there.** This was the first version's bug:
the leader spawned with the rest of the camp, which only builds within
`BanditCampForgetRange` (300 m) — so the marker had nothing to point at until the player was
already standing in the camp, which is the one moment they no longer need it. The log said it
plainly: contract accepted and saved, and not one `SpawnedEnemy_` in the world.

`BanditCampEnsureLeader` now runs every tick while a contract is live: the leader is spawned
the moment the job is taken, **survives the camp being unloaded** when the player wanders
off, and is re-spawned after a reload (spawned NPCs are not saved). He is never re-spawned
once killed (`S.leaderDead`), and the death count only runs while the camp is loaded, so a
distant leader can never be mistaken for a dead one.

Consequence: the marker sits on the leader and dies with him. In practice he is one of the
last things you kill, and the objective completes moments later.

`MarkerType` on `ShowMapMarker` is a closed enum (`QuestGiver`, `PoiTipster`,
`ActivityGiver`, `FightArena`, `Dog`, `Barber`, …) with no generic "objective" entry, which
is why the marker comes from the objective log rather than a `ShowMapMarker` node.

### Namespace is the thing that bricks the graph

A node carrying `Namespace="folder.path"` resolves into a vanilla-authored module the mod's
compiled database does not contain, and it kills the **entire** mod quest graph — every
dialog dies (`reference_mod_quests_primitives_only`). Every node in `bandit_camp_quest.xml`
is a primitive with no `Namespace` attribute.

`TypeT="wh::questmodule::QuestProgress"` is **not** an exception: that is a fully-qualified
engine C++ type string passed as a value, categorically different from the `Namespace` XML
attribute. Same for `Progress`, which is a built-in objective type (2150 vanilla uses, never
declared in XML) with states `None` / `Active` / `Done`.

This ruled out `ItemClassTrigger_SoulInventory` (`Namespace="utils.item"`) for the Lua→Skald
signal; the primitive `ItemDescriptorTrigger` + `CreateItemClassDescriptor` pair is used
instead.

---

## Gotchas

- **`IsActive` takes a bool, never a raw trigger.** Feeding a trigger port into it silently
  does nothing. `bc_awake` is a `TypeT="bool"` State with `DefaultValue="true"` for this.
- **An effect node's data ports are only valid on the tick its trigger fires.** The player's
  inventory therefore comes from `ObjectProperties` fed by `<Asset Name="I_Soul"
  Alias="player"/>`, not from a `ForEach` that ran once at `OnWake`.
- **The signal tokens must be swept, but not immediately.** `ItemDescriptorTrigger` fires
  `OnAcquire`; a leftover be82d sitting in the inventory would instantly complete the *next*
  contract, and this quest is `Repeatable="true"`. `BanditCampSweepTokens` gives each token a
  **one-tick grace** before deleting it: Skald triggers are documented as synchronous, but
  `MonitorInventory` and `BanditCampMonitor` run in the same 1 Hz pass, so a same-tick delete
  would be betting on that. One extra tick costs nothing.
- **Spawned entities are not saved by the engine.** What persists is the contract — site,
  group, headcount, kills, whether the leader is down — and the camp is rebuilt from it.
- **Kill counting is death-strict**, not the conscious-strict `IsCombatViable` the combat
  modules use: a knocked-out bandit is not a dead bandit and the contract says dead. If you
  ever want KOs to count, that is the line to change (`BanditCampCountDead`).
- **A missing entity is not a dead one.** `System.GetEntity` can hand back nil for a tick
  while the NPC is alive and well — the engine streams and despawns on its own
  (`docs/npc-lod.md`). Since `S.killed` only ratchets upward, counting one nil lookup as a
  kill would let a streaming blip inflate it permanently and eventually pay the contract out
  with bandits still standing. A body must be un-findable for `BanditCampMissingTicks` (5)
  consecutive polls before it counts.
- **`S.alerted` is saved with the contract.** Without it, quicksaving next to a camp you had
  already woken and reloading handed it back its calm — a free way to un-alert a camp.
- Camp-role accessors in `mercenaries_camp.lua` used to be gated on `_G.MercInCamp`, which
  would have meant bandits only idled while the *player's* camp was pitched.
  `IsForeignCampActor` now exempts anyone in `BanditCampActors`.
- **The three camp-role tables are shared with the player's camp, and it replaces them
  wholesale.** `CampFurniture` / `CampActivities` / `CampPatrollers` are reassigned to `{}` in
  about a dozen places in `mercenaries_camp.lua` (break camp, rebuild, recall, restore). That
  strips every bandit of its role and drops the camp out of `camp_actor` with nothing to put
  it back, so `BanditCampRepairRoles` re-asserts them each tick from the camp's own
  `S.spots` record.
- **A patrol record's index field is `index`, not `idx`.** `GetPatrolWaypoint` reads
  `rec.waypoints[rec.index]`; get the name wrong and the guard silently stands still forever.
- **Bandit patrol records carry `foreign = true`.** `NavRefreshPatrolRings`
  (`mercenaries_navmesh.lua`) walks *all* of `CampPatrollers` and re-points them at the
  player wall's gate posts — which would march the bandit guards across the map to it.
- **Appearance asset names must be checked against
  `references/Libs/Tables/Character/CharacterComponent.xml`**, which is the actual list.
  Grepping the mod's own `enemiesappearance.xml` proves nothing: an invented name you just
  added will match itself. `m_beard_21` and `m_hair_007_brown` do not exist; the highest
  beard is `m_beard_19` and hair is `m_hair_NNN_<colour>` with no plain `brown`.

---

## Console

```
merc_banditcamp_start     take the contract without talking to anyone
merc_banditcamp_status    site, group, kills, reward, spawned/cleared
merc_banditcamp_abandon   drop it and remove the camp
merc_banditcamp_clear     force-complete (pays out)
merc_banditcamp_alert     wake the camp up now
merc_bcamp_site_here      print a BanditCampSites row for where you stand
```

## Not done yet

- Only `kutnohorsko` is wired. Trosecko needs the quest file mirrored and registered in
  `trosecko.xml`, exactly as the background quest is.
- The one shipped site, `woodland_camp`, has an **approximate origin** — it was captured from
  where the player stood rather than from the layout's first tent, so the camp lands near,
  not exactly on, where it was built. Re-dump with the camp standing to correct it.
- Bandit towers share `TowerMaxCount` (5) with the player's own towers, so a player who has
  built four of their own will get a camp with no towers and only a log line to say why.
- No voice lines: the quartermaster's new dialog is text-only, like the rest of his menu.
- The bandits do not gossip. `_G.MercCampChats` pairing is merc-specific and bandit souls
  use vanilla voice 106, so they would need the generic vanilla gossip pool wiring.
