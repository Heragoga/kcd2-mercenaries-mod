# Post-battle loot sweep

After a fight ends near the player, the mercs wander the bodies, kneel over them and rummage. **Nothing is transferred** — no items move, no inventories are touched. It is set dressing.

Everything lives in [mercenaries_lootsweep.lua](../data/Scripts/mods/mercenaries_lootsweep.lua). No behaviour tree, scheduler or table was changed for it.

## It rides the camp activity pipeline

There is no `loot_sweep` behaviour module and no new branch in `mercenary_scheduler.xml`. The sweep publishes **camp activity records** and lets the existing machinery run them:

```
LootSweepTick  ->  mercenaries.LootActivities[mercWuid] = { unstance="Loot", mode=2, pos, facePos }
GetCampActivity  ->  returns the loot record ahead of any real camp role
IsCampActor      ->  true, so the scheduler fires camp_actor
camp_actor.xml   ->  mode 2: Move to pos, Turn to facePos, UnstanceAction "Loot", hold
```

This is deliberate. [camp-forge.md](camp-forge.md) records that a hand-added first case in that `ContinuousSwitch` "was never entered reliably even with its flag verifiably true; only the existing CampActivities pipeline (`campActMode`) preempts dependably. New behaviours should always ride that pipeline." `Loot` was already a catalogued, confirmed-working mode-2 unstance.

Riding it also buys three things for free:

- **Formation membership.** `IsFormationEligible` already excludes camp actors, so a looter drops out of the marching formation — and out of the running for formation leader — exactly the way an in-camp merc does. One shared rule, no divergence.
- **The return trip.** When the record is cleared, `IsCampActor` flips back and the scheduler's existing `firedCampActor` mismatch check re-fires `follow` (or the merc's real camp role). No new state.
- **Archers.** `archer_scheduler.xml` has identical camp_actor wiring, so archers sweep too with no extra work.

`GetCampActivity` returns loot records **before** its `IsCampOut` gate, because the bodies are wherever the fight was and the mercs working them are usually the sortie party.

## The trigger

| Stage | Rule |
|---|---|
| Fighting | `CachedEnemies` non-empty. The centroid of the live enemies is tracked each tick as `_lootAnchor`; any open sweep is torn down. |
| Fight ends | The tick `CachedEnemies` drains. One `System.GetEntitiesByClass('NPC')` scan captures every mod-enemy corpse within `LootCorpseRadius` (30 m) of the anchor, and the sweep re-anchors on the centroid of the **bodies**. |
| Settle | Nothing happens for `LootSettleDelay` (5 s) — weapons go away first. |
| Open | Bodies are handed out for `LootWindow` (150 s), or until the field is picked over. |
| Close | Window expires, the field is clear, the player leaves `LootPlayerRadius` (20 m) of the battle site, the player mounts, or a new fight starts. |

The corpse scan is a full-class scan, so it runs **once per battle**, never per tick. `GetEntitiesByClass('NPC')` is the call confirmed to enumerate corpses (see the world census in [npc-lod.md](npc-lod.md)); the physics box query used on the 300 ms combat path is not confirmed to return ragdolls.

Corpse liveness is tested **positively** (`actor:IsDead()` or `health <= 0`). `not IsAliveAndWell(ent, true)` is not a corpse test — it also catches a missing actor/soul or a failed `GetState`, which would put half-loaded entities on the list.

Enemy corpses are never despawned by this mod, so the window is bounded only by the timer. Merc corpses are removed ~10 s after death, so your own dead are gone before the sweep starts.

## Distance is the whole safety story

A body is only handed out if it is within **`LootMercRange` (18 m) of the player**, not merely within the battle radius. Every way this feature can look broken is a distance problem:

- past 20 m from the player `UpdateMeleeCombatData` sets `disengage`, so a looter jumped by a straggler sheathes instead of fighting
- past 35 m the scheduler's stuck-follower self-heal re-fires the behaviour, killing the animation mid-play
- past 50 m `MonitorDistanceAndTeleport` yanks the merc, and a periodic `SetPos` resets its AI
- the enemy cache is an 18 m box **around the player**, so a merc further out never even sees an approaching hostile

Keeping the assignment radius at the scan radius makes all four moot. The 20 m gate is about the *player* staying near the battle; 18 m is about the *mercs* staying near the player.

`standSpotFor` deliberately does **not** ground-validate its stand spot. It called `FindValidGround` at first, which spirals out to 2 m in 0.5 m rings at nine raycasts a probe — ~80 casts per assignment, each logging a `RayWorldIntersection` parameter warning, which buried the log during a sweep. A body lies on walkable ground by definition, and `Move` pathfinds the last stretch anyway.

## Handing a sweeper back to the squad

A man coming off loot duty stops being a camp actor, and the scheduler is *supposed* to notice the
role change by itself and re-fire `follow`. It cannot always. `camp_actor` is an infinite loop that
owns the interrupt slot once it has it, and a merc inside the rummage unstance can swallow the
`follow` interrupt while the scheduler latches `$isFollowingActive = true` anyway — so he stands
over the body for the rest of the session. **That is the one-in-fifty who never comes back after a
battle**, and it is why the report always points at the loot sweep.

`LootReleaseFinished` runs at the end of every sweep tick, diffs `LootActivities` against
`LootWasSweeping`, and raises `FollowStalled` on anyone who dropped off the list. That is the signal
that evicts a running tree *properly* — `teleport` first, then `follow` — and it is queued, staggered
and race-guarded, so kicking a handful of men costs nothing. See
[formations.md](formations.md), "The eviction race".

The diff is taken **after** `LootAssign`, so a merc who finished one body and was handed another on
the same tick is not kicked; only a man genuinely leaving the sweep is. Releasing anyone also opens
a `BeginFollowVerify` window, which re-fires anyone who still fails to start walking.

The end of a fight opens that window too, independently of the sweep: `UpdateEnemyCache` calls it
when the squad alert drops. Combat replaces `follow` for every merc who fought, and whatever ran
next did not always give it back.

## Commands

```
merc_loot_force     open a sweep on the bodies around you right now, no fight needed
merc_loot_stop      cancel the running sweep and recall the mercs
merc_loot_status    report state: bodies, sweepers, time to open/expire
```

Tuning constants are all at the top of the Lua file: `LootPlayerRadius`, `LootCorpseRadius`, `LootMercRange`, `LootWindow`, `LootSettleDelay`, `LootMaxSweepers`, `LootStandOff`, `LootArriveDist`, `LootDwell`, `LootWalkTimeout`.

**`LootDwell` (9 s) must NOT exceed mode 2's hold** (`Wait 8s ± 3s`, so 5–11 s). It was 15 s at first, on the theory that the task should outlast the animation so nobody gets rotated off mid-rummage. That is backwards: once the hold ends the merc has nothing left to do, and **re-entering an unstance he is already in does not replay it**, so he stood over the body for the remainder — 10 s or more of visible nothing. Cutting the tail off a long roll is the better trade; the sweep is scenery, and standing still reads as broken.

`LootWalkTimeout` (12 s) is short for the same reason: a merc pathing at something unreachable looks identical to the bug it exists to prevent.

Returning to the player needs no code of its own. Clearing the record makes `GetCampActivity` return nil, `IsCampActor` flips false, and the scheduler's existing `firedCampActor` mismatch check re-fires `follow` — about 1–2 s, being the camp_actor refresh (1 s) plus the scheduler switch (500 ms). A merc with no reachable body left is therefore already following; it was only ever the dwell holding him.

---

# Mercs finishing bodies off: impossible

A merc executing a wounded enemy was pursued hard and does not work. **Do not retry it.** Every line below is a measurement, not a guess.

## The mercy kill is player-only

`CanDoMercyKill` on the same body, at the same moment:

```
player=2 @7.7m | merc=0 @6.0m
player=2 @3.0m | merc=0 @1.4m     <- merc practically on top of him
player=2 @0.7m | merc=0 @2.6m
```

The player is allowed at 7.7 m; a merc is refused at 1.4 m. Health made no difference (tested at 100 and at 5). It is an **actor restriction** — not distance, not victim state, not animation. `MKS_Undefined=0, MKS_Disabled=1, MKS_Enabled=2`; only 2 may fire.

The route there, each step killing a plausible theory:

| Attempt | Result |
|---|---|
| Mercy-kill a corpse directly | `0` — and **the player is refused too**. Not a corpse action; it wants someone unconscious and alive, per the vanilla hint `@ui_hud_mercy_kill_unconscious`. |
| `Revive()` the corpse to make a live victim | **No effect whatsoever.** `dead=true health=0` before and after; `soul:SetState('health', 40)` ignored. A corpse cannot be resurrected from Lua. |
| `soul:DealDamage(9999 stamina, 0 health)` on a live enemy | Never touches consciousness. At `hp=100` and `hp=59`, nothing. At `hp=16` it **killed** — stamina damage overflows into health once stamina is gone, so it can only ever kill. |
| `RequestKnockOut` | No effect, and `CanKnockOut` **raises** — not callable on this build. |
| `soul:AddBuff("unconscious_permanent")` | **Works.** `unconscious=true health=100`, via the engine's own `Cpp:Unconscious` implementation. |
| `CanDoMercyKill` on that downed body | `0` from a merc at any distance, `2` from the player. Dead end. |

Worth keeping from all that: **`soul:AddBuff("c75aa0db-65ca-44d7-9001-e4b6d38c6875")` reliably knocks a live NPC unconscious.** That is a useful primitive well beyond this feature. The 60 s variant is `f8d60fe4-e2c1-420a-946a-213e1cd09264`.

Also note `AcceptStealthActionByVictim` ("called by victim to accept stealth action") has **no Lua callers anywhere in the game** — the victim half of these interactions is engine-driven, so there is no handshake a mod can complete by hand.

## No animation substitutes for it either

A mercy kill is inherently **two-actor**, and the paired-animation path (`camp_actor` mode 4) is confirmed dead in this mod — paired fragments never played. Searching `anim_fragment.xml` for kill fragments turns up exactly six, and the three tempting ones are all unusable:

| Fragment | Why not |
|---|---|
| `Quest_GroundDaggerKill` | `aligned="true"`, 41.9 s, `looped="false"`, ~2 m of baked root motion, has a `…Slave` counterpart |
| `Quest_StandByObstacleDaggerKill` | `aligned="true"`, 11.3 s one-shot, also has a `…Slave` |
| `Quest_StandHlbrdKill` | `aligned="true"`, 8 s one-shot, `r_halberd`, `…Slave` + a `…KilledFallDown` for the victim |

They are authored two-actor quest scenes needing a location object and a slave actor, and the baked root motion would walk the merc off the body.

The two that *are* standalone both failed in play:

- **`Quest_CruelPikeman`** — T-posed bare-handed, and T-posed again holding the halberd its fragment tags demand (`mn_tags="l_halberd+r_halberd"`, both hands on manipulator 36). Conjuring the polearm the way the camp smith conjures his sword did not help; the log showed `Ignoring draw of item in DrawItemLogic` and `ForceIdleState sets '' tags`.
- **`Quest_UnsureKiller`** — the only kill fragment that is `aligned="false" looped="true"` (~4 s), and its `UnstanceData` pins `Tags="r_sword"`. Lending the merc a shortsword via `EquipMercenaryWeapon` got the sword drawn and then **nothing played**.

Everything else tried (`noob_sword_training`, `PickingHerbsNPC`, `Loot`, `Stretching`) played correctly but read as an unrelated activity, not a killing blow.

**The generalisable lesson: whether an unstance works on a plain merc cannot be read off the tables.** Tag requirements explain a failure after the fact but never predict a success. Note also that both `Quest_CruelPikeman` and `Quest_UnsureKiller` have empty `<In />` and `<Out />` with all the work in the `Loop` — that shape is what turns a failed tag match into a bind pose, so **a T-pose is the signature of an unresolved Loop fragment**.

## Two bugs it caused on the way out

Both are gone with the finisher, and both are worth recognising if similar code appears again:

- **Mercs drawing and sheathing all over the battlefield.** The sword-lending called `EquipMercenaryWeapon` twice per body (lend, then return), and every swap is a draw/sheathe.
- **Mercs standing around after combat, not even following.** The mercy-kill activity mode was `Move` → `Turn` → ~5.5 s of Lua calls with **no animation**, relying entirely on the engine interaction to be the visible act. Once `RequestMercyKill` refused, it became literally "walk to a body and stand still", looping for the full 15 s dwell, per body.
