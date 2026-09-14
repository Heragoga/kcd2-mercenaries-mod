# Your own men stop shoving and trampling you

A company that follows you closely walks into you constantly, and a mounted one rides you
down. On foot it is a shove; from a horse at speed it is real damage. `merc_nobump 0`
turns the fix off, `merc_nobump 1` (the default) turns it on; the setting is saved.

The fix is **not** a damage setting. There is no such thing to set — the collision itself is
filtered out instead, and a collision that never happens deals nothing.

---

## What does not exist

Worth writing down, because all three look like the answer and none of them is:

* **`foreignCollisionDamageMult` / `vehicleCollisionDamageMult` / `collisionDamageThreshold`.**
  They sit right there in `references/Scripts/Entities/actor/player.lua:13` and
  `references/Scripts/Entities/AI/NPC.lua:156` and read exactly like the knob you want.
  Neither string occurs anywhere in `WHGame.dll` — grep the binary and you get zero hits.
  They are Crysis-era leftovers in Warhorse's copy of the stock scripts. Nothing reads them.

* **A Lua hit hook.** KCD2's actor scripts define no `Client.OnHit` and no collision
  callback at all. `SinglePlayer:CreateHit` (`references/Scripts/GameRules/SinglePlayer.lua:184`)
  only goes *into* C++ via `ServerHit`. Damage cannot be inspected, filtered or cancelled
  from script after the fact.

* **A cvar.** The only ones in the area are `g_debugCollisionDamage` ("Log collision damage")
  and the `wh_HitReaction_*` family (`wh_HitReaction_CollisionsEnabled`,
  `_PhysicalHitCoef`, `_EnvironmentCollisionScale`). They are global, they govern hit
  *reactions* and impulses, and none of them is per-actor or per-source.

## What does exist: the collision-class filter

`Entity.SetPhysicParams(PHYSICPARAM_COLLISION_CLASS, {...})` is a live bind, and the engine
exports the class vocabulary to Lua as the global table `g_PhysicsCollisionClass` (built in
`sub_1690428`, names assigned in `sub_1750264`). Two physical entities skip each other
entirely when either one's *type* bits intersect the other's *ignore* bits — the test is
symmetric, so setting the mask on **our** side is enough and the player entity is never
touched.

| class | bit | | class | bit |
| --- | --- | --- | --- | --- |
| `collision_class_terrain` | `0x1` | | `gcc_horse` | `0x10000` |
| `collision_class_wheeled` | `0x2` | | `gcc_ai` | `0x20000` |
| `collision_class_living` | `0x4` | | `gcc_interactive` | `0x40000` |
| `collision_class_articulated` | `0x8` | | `gcc_npc_reported_type` | `0x80000` |
| `collision_class_soft` | `0x10` | | `gcc_player_type` | `0x100000` |
| `collision_class_particle` | `0x40` | | `gcc_npc_ignored_type` | `0x200000` |
| `gcc_player_capsule` | `0x400` | | `gcc_ledge` | `0x400000` |
| `gcc_player_body` | `0x800` | | `gcc_animal` | `0x800000` |
| `gcc_vehicle` | `0x1000` | | `gcc_horse_bridle` | `0x1000000` |
| `gcc_ignore_z_correction` | `0x2000` | | `gcc_player_ghostable_type` | `0x2000000` |
| `gcc_ragdoll` | `0x4000` | | `gcc_decoy_projectile` | `0x4000000` |
| `gcc_rigid` | `0x8000` | | `gcc_item` | `0x8000000` |

Composites the engine also publishes: `gcc_player_all = 0xC00` (capsule + body),
`gcc_npc_avoiding_types = 0x280000`, `gcc_all_engine = 0x3FF`, `gcc_all_game = 0xFFFFFC00`.

> **Derive these yourself and you will be off by one.** `sub_1750264` stores each name at
> the bit index computed from the value loaded *before* it, so reading the disassembly
> straight down pairs every name with the next class's value. `gcc_player_all = 0xC00`
> and `GeomEntity.lua`'s own `gcc_interactive = 262144` are the two checks that pin the
> table above.

### The four keys

`PHYSICPARAM_COLLISION_CLASS` takes `collisionClass` / `collisionClassIgnore` to **OR bits
in**, and `collisionClassUNSET` / `collisionClassIgnoreUNSET` to **clear them**
(`references/Scripts/Entities/Default/GeomEntity.lua:143` is vanilla's own use of the pair).
So this is additive in both directions: it never disturbs whatever classes the entity was
physicalised with, and turning the setting off restores the previous state exactly.

## What the mod applies

| to | ignores | why |
| --- | --- | --- |
| every merc, archer, quartermaster | `gcc_player_capsule` + `gcc_player_body` — i.e. exactly `gcc_player_all` (`GhostMask`) | he cannot shove you, body-block a doorway, or push you off a wall |
| every `MercenaryHorse_*` | those two plus `gcc_horse` (`GhostHorseMask`) | a rider cannot run you down while you are on foot |

`gcc_player_type` is **not** in either mask, though it reads like it belongs. It sits at bit
20, between `gcc_npc_reported_type` (19) and `gcc_npc_ignored_type` (21), and those two are
what the engine unions into `gcc_npc_avoiding_types` — so that bit is an AI-avoidance
marker, not part of the player's physical body. It would buy nothing here and could reach
navigation.

### `gcc_horse` does not do what it was put there for — measured 2026-09-14

`gcc_horse` went into the mount mask on the reasoning that when you are mounted the body
that gets rammed is your horse, not you. **In play, merc mounts still collide with the
player's mount.** So either a ridden horse does not carry `gcc_horse`, or a rider's horse
is not the entity the contact resolves against. Do not repeat the assumption; measure what
class the player's mount actually carries before reaching for this again.

The bit is left in because it costs nothing and the failure is benign — being bumped by a
merc's horse while you are both mounted is a nudge, not the trampling this page is about.
Its only live effect is that merc mounts pass through other horses, which the horses' own AI
avoidance (`wh_horse_CollisionAvoidance`, untouched) mostly hides.

Everything else is unchanged: mercs still collide with the world, with enemies, with
NPCs, and arrows and blades still hit them normally. Only the player's own body is
transparent to them.

## Where it is applied

Physics params do not survive re-physicalisation, so the mask goes on at three points and
is re-applied on a sweep:

| point | file | covers |
| --- | --- | --- |
| `InjectInteraction` | `mercenaries_lookatinteraction.lua` | every merc-family spawn path — a new hire is ghosted the tick he appears |
| `MercInstantMount` | `mercenaries_target_selection.lua` | a mount, on the first tick it exists |
| the orphan-horse sweep | `mercenaries_target_selection.lua` | mounts that were re-physicalised, every third combat tick within 100 m |
| `RefreshRenderPins` | `mercenaries_util.lua` | the whole squad every 5 s — save/load, level change, anything that rebuilt the entity |

The sweeps only write while the setting is on. `merc_nobump 0` clears the mask on the live
squad and every mount within 150 m in one pass, so it is a usable A/B without a reload.

## If a bump still hurts

The mask covers the player's *body*. Two things it deliberately does not cover, and what to
add if either turns out to matter:

* **Being crushed against geometry.** If a merc cannot push you, he cannot pin you either,
  so this should be gone — but the damage in that case came from the world, not from him.
* **Your horse being hit by something that is not a merc mount** — a vanilla rider, a cart.
  Out of scope here; that is base-game behaviour and no merc entity is involved.
