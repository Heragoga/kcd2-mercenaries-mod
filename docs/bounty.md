# The standing bounty

The quartermaster's second job: **clear a bandit camp, come back, get paid.** No letter, no
story, no end to it. It runs alongside the Kleinkrieg arc rather than instead of it, because
the arc chains straight from one contract into the next (`BanditCampChainNext`) and a job
gated on "nothing else running" would practically never be offered.

| Piece | File |
|---|---|
| Everything the bounty decides | `data/Scripts/mods/mercenaries_bounty.lua` |
| Everything the camp *does* | `data/Scripts/mods/mercenaries_banditcamp_quest.lua` (shared with Kleinkrieg) |
| Quest graph: two objectives, two markers | `data/Quests/mercenaries/kutnohorsko/bounty_quest.xml` |
| Registration | `data/Quests/mercenaries/kutnohorsko.xml` |
| Dialog lines | `.../mercenaries_background_quest/quartermaster_dialog.xml` (`seq_qm_bounty_yes`, `seq_qm_bounty_report`) |
| Ports → tokens, and the two gates | `.../mercenaries_background_quest.xml` (`exec_qm_bounty*`, `bo_open`, `bo_ready`) |
| Its own leader soul | `soul__mercenaries.xml`, `skald_character__mercenaries.xml`, `enemiesappearance.xml` |

---

## Two camps at once

`mercenaries_banditcamp_quest.lua` was written around one contract: two dozen functions open
with `local S = self.BCQ`. Rather than thread a state table through all of them, **`self.BCQ`
is now a slot pointer**:

```
mercenaries.BCQ_KK   the Kleinkrieg arc's camp
mercenaries.BCQ_BO   the bounty's camp
mercenaries.BCQ      whichever one is being serviced right now
```

`BanditCampWith(S, fn)` binds a slot for the length of `fn` and puts the pointer back
afterwards — including when `fn` throws, because a slot left bound would hand the next caller
the wrong camp. `BanditCampMonitor` now does the mod-wide work once (the token sweep, both
pairs of dialog gates) and then calls `BanditCampService` once per **live** slot, bound.

Everything inside that pass is unchanged and knows nothing about slots. What had to change is
everything reached from *outside* it:

| Caller | Fix |
|---|---|
| `BanditCampSuppressed` (the target selector, at arbitrary times) | walks `BanditCampSlots()` — a bounty bandit is gated by the *bounty* camp's alert flag |
| `BanditCampAccept`, `BanditCampDeliverLetter`, `BanditCampChainNext`, `BanditCampAbandon`, `BanditCampResync` | pin `self.BCQ = self.BCQ_KK` first; they are the arc's, always |
| `KleinkriegSyncGates` | reads `self.BCQ_KK` by name, never the pointer |
| `BanditCampSave` / `BanditCampRestore` | one blob per slot (`BCQuest` / `BOQuest`); restore runs bound, once each |

Three things are keyed per slot rather than shared, and each one was a real bug waiting:

- **`S.actorSet`.** `BanditCampActors` is the mod-wide "belongs to a foreign camp" set —
  Aleksej's camps and the siege write to it too — so it cannot say *which* camp, and the alert
  gate needs exactly that. Each slot keeps its own copy. The shared set still gets written,
  because `IsForeignCampActor` is what keeps these men in `camp_actor` at all.
- **`S.leaderSoul`.** A `SoulAsset` marker resolves to whichever NPC carries the guid. Two
  leaders sharing one soul would leave both quests' markers pointing at an arbitrary one of
  them, so the bounty camp's leader has his own soul (`soul_bounty_leader`).
- **`c.slot` on a gossip pair.** `ClearBanditCampChats` used to wipe every foreign pair, which
  would have silenced one camp every time the other unloaded; the age-out ran on all of them
  too, so a second camp would have expired the first's conversations at double rate.

`S.borrowed` (the smithy and alchemy bench, which are real world objects moved into place) was
already per-camp and needed nothing — the singleton slot is saved and restored around each
borrow, so the second camp simply scans for a different loaded one, or logs that there was
none.

## Which camp

`BountyPickSite` draws at **random** from `BanditCampSites`, which is the opposite of the arc's
fixed run. What it will not take:

- **Patrol sites** (`layout = "patrol"`, or anything with a `route`). Those are columns on a
  road, not somewhere to pitch a camp.
- **`raborsch`** — the siege. It carries the patrol layout so it is already excluded, and it is
  named out as well so a future layout rename cannot quietly hand the siege to a bounty.
- **Anything Kleinkrieg has claimed.** `BountyReservedSites` holds both the site the arc's live
  contract stands on *and* the one it will hand out next, so a bounty is never pitched where
  the arc is about to need it.

Two softer preferences are applied first and dropped if they leave nothing: the site the last
bounty used, and anything within `BanditCampForgetRange` (300 m) of the player, so a camp is
never pitched underfoot. A repeat beats refusing the job.

### Kleinkrieg still wins

The reservation only covers the *next* arc contract. Paying one advances the run, and the arc
chains immediately into the one after — whose site was never reserved. So `BanditCampAccept`
calls **`BountyYieldSite(site.name)`** once it has settled on its ground, and the bounty is the
one that moves:

| Bounty state | What happens |
|---|---|
| camp still standing | it is torn down and the bounty re-picks a different site; the leader, the dead and the alert flag all reset, and the player is told |
| already cleared, not yet reported | the props simply come down (`DespawnBanditCamp(true)`) — nothing is left but the walk home |
| nowhere else to put it | the bounty is **called off** unpaid and its journal entry closes. Two contracts counting kills at one camp would pay out both on one fight |

## What it pays

`BountyTiers` picks a tier from `BanditCampFollowerCount()` — the men who will *actually* turn
up, not the payroll asleep in camp — and hands `BanditCampScale` a contract descriptor, which
is what `KleinkriegContract()` returns for the whole time the bounty slot is bound. The scaling
maths, the group pools, the gear and the archers are therefore the arc's, unchanged.

| Followers | Group | Ratio | Floor | Archers | Pay |
|---|---|---|---|---|---|
| 0–3 | looters | 1.1 | 4 | — | ×1.3 |
| 4–7 | bandits | 1.0 | 5 | 15% | ×1.3 |
| 8+ | Sigismund's men | 1.1 | 7 | 20% | ×1.4 |

Per head comes from `KleinkriegPerHead`; the multiplier is a little over the arc's rate,
because it is piecework and nobody hands over a letter at the end of it.

## The two dialog gates

Exactly the shape Kleinkrieg's use, and for the same reason — Lua owns them outright, so they
cannot go stale across a reload or ride on a token whose lifetime belongs to something else.
Each has its own set and clear token, pushed by `BountySyncGates` on the 1 Hz tick whenever the
value changes. `_boOpen`/`_boReady` start nil, so the first tick after a load re-asserts both.

- **`bo_open`** hides the offer. It tracks `B.active`, **not** "unpaid": a paid bounty stays
  active until its camp has been torn down (the props wait for the player to walk
  `BanditCampDespawnRange` away), and offering a new one before then would repoint the slot and
  strand the old camp's props in the world with nothing tracking them. `BountyAccept` guards on
  the same thing, so the dialog and Lua can never disagree about whether a job can be taken.
- **`bo_ready`** shows the report line, and only while the camp is cleared and unpaid.

Neither is wired to `kk_open`/`kk_ready`. Both jobs can be live at once, in either order.

## Deliberately not done

- **No `QuestGiver` icon of its own.** `bandit_camp_quest.xml` already hangs one on the
  quartermaster gated on "no arc contract running". A second one gated on "no bounty running"
  would be lit almost permanently and would compete with whichever camp marker is up.
- **Trosky.** Three separate layers keep it off: the quest is registered only in
  `kutnohorsko.xml`, only the Kuttenberg quartermaster dialog carries the two options, and
  `BountyLevelOK` names the one map that is allowed rather than the one that is not — the level
  bindings are unreliable enough to answer `"unknown"`, and a wildcard match there would drop a
  camp at Kuttenberg coordinates on the wrong map.
- **No voice lines.** Henry's two halves point at vanilla lines that already say the right
  thing; the quartermaster's are the mod's own and unvoiced, like the rest of his menu.
- **`B.lastSite` is not persisted.** It only stops the same camp being offered twice running,
  and a reload forgetting it costs nothing.

## Console

```
merc_bounty_start     take a bounty without talking to anyone
merc_bounty_status    site, group, kills, reward, and what Kleinkrieg has reserved
merc_bounty_report    report it in and collect
merc_bounty_clear     force-complete the camp
merc_bounty_abandon   drop it and remove the camp
merc_bounty_reset     zero the paid-bounty counter
```

`merc_banditcamp_status` prints the bounty's line first, then the arc's.
