---
title: AI brains, souls and NPCs
summary: How a KCD2 NPC is assembled (soul, brain, subbrains, SmartEntity, factions, Storm), how to spawn one, and the traps in factions, smart objects, followers, equipment, appearance and female NPCs.
tags: [ai, bt, data, lua]
kind: reference
status: current
scope: kcd2
verified: release_1_5
---

# AI brains, souls and NPCs

The data side of an NPC and the rules for spawning and running one. Tree syntax is in
[behaviour trees](behavior-trees.md); fighting is in [combat and perception](combat-and-perception.md).
The public step-by-step guides are [add a new NPC](../xml/add-new-npc.md),
[make an NPC brain](../xml/make-npc-brain.md) and spawning NPCs.
Table formats and merge rules are in [data tables](data-tables.md) and
[mod structure](mod-structure.md).

> **TL;DR**
> - An NPC is a **soul** (a table row) plus an entity spawned with `properties.guidSharedSoulId = <soul guid>`. The soul's `brain_id` selects the brain, the brain's subbrains select the trees.
> - Minimum brain: one Switching subbrain (type 6, your tree) plus one Scheduler subbrain (type 9); reusing vanilla `npc_basic_scheduler` is fine.
> - Interrupt behaviours (combat etc.) go in vanilla's `so_interrupt` SmartEntity via a `SmartEntity__so_interrupt__<modid>.xml` merge.
> - Faction relations are **one-directional**: your faction hating theirs does not make them hate yours.
> - Spawn class must match `soul_archetype_id` (`NPC` = 0, `NPC_Female` = 1). Female NPCs have no armour and no combat animations at all.

Vanilla paths are relative to `references/kcd2-mod-docs-main/`.

## Anatomy of an NPC

| Piece | Where | Links by |
| --- | --- | --- |
| Soul | `Libs/Tables/rpg/soul*.xml` | `soul_id` (GUID); spawn uses it as `guidSharedSoulId` |
| Brain | `Libs/Tables/ai/brain.xml` | soul `brain_id` |
| Subbrains + trees | `brain2subbrain`, `subbrain`, `subbrain_switching` | `subbrain_id`, `file_name` + `tree_name` |
| Mailboxes | `brain2mailbox`, `mailbox_group`, `mailbox_group2mailbox` | copied from vanilla in practice |
| Interrupt behaviours | `Libs/Tables/ai/smartEntity/SmartEntity__*.xml` | behaviour `Name` |
| Faction | `Libs/Tables/rpg/FactionTree.xml` | soul `factionName` |
| Appearance, inventory, dialogue roles | Storm rules `Libs/Storm/...` (official wiki KM-A-32) | soul name selectors (`hasName`) |
| Dialogue identity | `role`, `skald_character*` tables | see [add-new-npc](../xml/add-new-npc.md) and [skald](skald-quests-dialog.md) |
| Clothing / weapons / inventory | `clothing_preset`, weapon/inventory presets | Storm `setInventory` |

## Souls

Key soul attributes (vanilla: `Libs/Tables/rpg/soul.xml`, `soul_archetype.xml`, `soul_vip_class.xml`,
`social_class.xml`; community guide: [add-new-npc](../xml/add-new-npc.md)):

| Attribute | Values / meaning |
| --- | --- |
| `soul_archetype_id` | `0` NPC (male), `1` NPC_Female, `2` NPC_Child, `3` Horse, `8` Dog, `13` Hero, `15` Hero_female, plus animals |
| `brain_id` | the brain GUID |
| `factionName` | must equal a `<Faction Name>` exactly |
| `combat_level` | 0..1; gates techniques (master strikes, combos, perfect blocks). 972 of 986 vanilla female souls are 0 |
| `social_class_id` | row in `social_class.xml` → `soul_crime_role_id`: e.g. `1` villager, `3` townsman, `5` beggar, `38` bandit, `43` cuman, `70` fake_soldier. Crime severity axis; does **not** decide loot vs rob |
| `soul_vip_class_id` | protections. Declared values only: `0` none, `1` pickpocket, `2` attack, `3` attack+steal, `4` immortality, `8` unconsciousness, `12` immortal+no-KO, `13`, `15`, `16` loot, `23`, `31` untouchable. Pick from the list; do not OR bits yourself |
| `digestion_multiplier`, `xp_multiplier` | `0` = never starves; XP for killing |

Stats and skills (`soul2stat`, `soul2skill`) and presets are [data tables](data-tables.md) territory.
For a reliably unkillable NPC, combine `soul_vip_class_id="12"` with the `immortality` buff
`85aca9c5-ec41-400d-a563-53df7b2399e8` (`imm=1`), re-applied periodically. Health top-ups can be
outrun (verified in game: quartermaster).

## Brains and subbrains

A brain is a GUID and name. Its subbrains do the work (vanilla: `Libs/Tables/ai/subbrain_type.xml`,
counts from `subbrain.xml`):

| Type | Name | Vanilla subbrains | Notes |
| ---: | --- | ---: | --- |
| 1 | BehaviorTree | 36 | |
| 3 | SmartArea | 29 | |
| 4 | SmartObject | 107 | doors, props, professions |
| 5 | Situation | 2 | |
| 6 | Switching | 5 | the NPC's always-on "switch" tree; mods put their scheduler logic here |
| 7 | Dialog | 1 | |
| 8 | DogCompanion | 3 | |
| 9 | Scheduler | 5 | daily routine; **required for MonsterLOD switching**. The engine logs `NPC %s doesn't have scheduler subbrain! It will never be switched to MonsterLOD` (retail binary) |

Vanilla reference brain `npc_basic` (`4b914d1c-724a-a92d-3e6b-d183d35b8b98`) pairs
`npc_basic_switch` (type 6, `ec81`, tree `npc/basic/switch/switch.xml` / `root`) with
`npc_basic_scheduler` (type 9, `4eaa0620-d090-e268-c244-cba09ad5ec80`). A mod brain can reuse that
scheduler and add its own type-6 subbrain (`always_active="true"`, `timeout="0"`). The table chain
is `brain` → `brain2subbrain` → `subbrain` → `subbrain_switching`; walkthrough in
[make-npc-brain](../xml/make-npc-brain.md).

- **What each type may run** is not documented. The community guide reports that a Switching
  subbrain cannot run movement or combat nodes directly, which is why those run as interrupts
  (community guide, `(unverified)` beyond "it works that way").
- The player has a real brain (`player`, with `player_switch` and `player_scheduler`) and runs
  trees, but only through level-baked scheduler links ([formations](formations.md#the-player-and-formations)).
- `brain_variable` declares a typed variable at brain level (`is_persistent="true"` survives
  save/load, per the guide). Lua reads and writes brain variables with
  [`XGenAIModule.GetBrainVariable`](api/XGenAIModule.md#getbrainvariable) /
  [`SetBrainVariable`](api/XGenAIModule.md#setbrainvariable).
- A mod cannot move an NPC to another behaviour family by renaming its entity: behaviour binds
  soul → brain → scheduler (verified in game: bandit-camp-quest).
- `npc_basic_scheduler` in an AI error line does not mean your scheduler was bypassed; every NPC
  runs under it (npc-lod).

## SmartEntity and SmartBehaviorTemplate

A SmartEntity is a named registry of behaviours that `AddInterrupt_*`, `CallBehavior` and Skald
`EnableBehavior` refer to by name. 578 vanilla SmartEntity files.

```xml
<SmartEntityTemplate BrainId="ea3ff907-6743-4ad4-8723-2c14ac2a01f0"
    DatabaseId="43c857b4-032b-844f-3d1b-3cc90d5a2382" Name="so_interrupt" UpdatePriority="false">
  <BehaviorTemplates>
    <SmartBehaviorTemplate InitialState="Enabled" MaxInstances="-1" Name="my_attack" PreventsMonsterLod="true">
      <TreeLocation FileName="my_attack.xml" TreeName="my_attack" />
      <Inboxes> <InboxTemplate InboxId="80cbc23c-5752-43e3-9405-38355ad8d617" Priority="0" /> </Inboxes>
    </SmartBehaviorTemplate>
  </BehaviorTemplates>
</SmartEntityTemplate>
```

- **Which `BrainId`:** the shipped, working mod extends vanilla's `so_interrupt` entity. `BrainId`
  `ea3ff907-...` is the vanilla brain named `so_interrupt`, with its `DatabaseId`, in
  `data/libs/tables/ai/smartEntity/SmartEntity__so_interrupt__mercenaries.xml`. The public
  [make-npc-brain](../xml/make-npc-brain.md#smartentity-interrupts) example puts the mod's own brain
  id there. The shipped file is what has been verified in game; prefer it.
- Copy the `InboxTemplate` ids from vanilla `interrupt_attack` (vanilla:
  `Libs/Tables/ai/smartEntity/SmartEntity__so_interrupt.xml`, 81 templates).

| Template attribute | Vanilla | Meaning |
| --- | --- | --- |
| `InitialState` | `Enabled` 1,893 / `Disabled` 2,426 | Disabled ones need Skald `EnableBehavior`; no Lua path |
| `MaxInstances` | `-1` | |
| `PreventsMonsterLod` | 465 × `true` | blocks demotion to MonsterLOD only, **not** Detail→LOD ([LOD](npc-rendering-and-lod.md#ai-lod-tiers)) |
| `HibernateInMonsterLod` / `SkipMLODMove` / `PostponeByPlayerInMonsterLod` | 8 / 6 / 1 | background-crowd ("additive NPC") machinery |

## Mailboxes and messages

Trees receive messages on named inboxes with `ProcessMessage`. Common ones: `hitReaction`,
`perceptionInfo`, `dialogMailbox`, `door_communication`, `crime_stimulus`, `crime_interrupt`
(vanilla census). Message types are declared in `Scripts/AI/MessageTypes.xml`.

- **Dialogue E-prompt:** an NPC's dialogue opens only if its tree polls
  `ProcessMessage inbox="'dialogMailbox'"` and calls `Function_switch_handleDialog dialogRequest="$dialogRequest"`,
  at least once a second (verified in game: [talking](../behaviour-trees/talking.md)).
- Lua → tree: [`XGenAIModule.SendMessageToEntity`](api/XGenAIModule.md#sendmessagetoentity)`(wuid, type, "args")`
  or [`SendMessageToEntityData`](api/XGenAIModule.md#sendmessagetoentitydata)`(wuid, type, table)`.
- Mailbox table rows (`brain2mailbox` etc.) are copied from vanilla or the mod rather than
  understood (community guide).

## Spawning

```lua
System.SpawnEntity({ class = "NPC", name = uniqueName,
  position = pos, orientation = { x = 0, y = 0, z = yaw },
  properties = { guidSharedSoulId = soulGuid } })
local ent = System.GetEntityByName(uniqueName)   -- verify; may be nil
```

([`System.SpawnEntity`](api/System.md#spawnentity), [`System.GetEntityByName`](api/System.md#getentitybyname);
verified in game: spawning-npcs)

- The key is `guidSharedSoulId`. `sharedSoulGuid` gives a soulless NPC with no error. Use the bare
  GUID; an `s` prefix breaks resolution (old context doc correction).
- `class` must match the archetype (`NPC` / `NPC_Female`). The class commits the skeleton, and a
  mismatch T-poses.
- Names must be unique. A collision fails or overwrites silently.
- `SpawnEntity` can "succeed" while the entity never appears (e.g. inside geometry). Re-fetch by
  name before charging, counting or reporting.
- Use yaw only for orientation. The player's pitch/roll tips the NPC into the ground.
- Placement (raycasts, roofs, indoors, navmesh snapping) is in [world and physics](world-and-physics.md).
- A Lua-spawned NPC stands on terrain, not necessarily on navmesh. Positioned dialogue presets
  (`fader`, `ingame`) can then fail with `Path finding failed ... not close enough to nav mesh`
  (aleksej).
- Runtime-spawned NPCs cannot join level-baked constructs: layers/`ProfileAsset`, battle groups,
  `SmartObjectHolder` links, `playerProxy` scheduler links (malesov-structure).
- A periodic `SetPos` on a fighting NPC resets its AI mid-action. Hold combat until placement is
  final (ai-modules).
- Engine-saved NPCs persist across save/load; how that plays with a mod's own bookkeeping is in
  [Lua scripting](lua-scripting.md).

## Factions and relations

```xml
<Faction Name="myFaction" Labels="publicEnemy">
  <Relations> <Relation target="player" reputation="-1" /> </Relations>
</Faction>
```

- **One-directional.** A relation declared on your faction says how *your* NPCs see *them*. Measured
  in a scripted battle: the mod's faction declared `-1` toward vanilla enemies; vanilla NPCs targeted
  the mod's NPCs **0** times while the mod's NPCs targeted them 40 times, because no vanilla faction
  names the mod's faction (verified in game: npc-lod).
  Making vanilla NPCs hostile to you needs a relation on **their** node. Re-declaring a vanilla
  faction in a merge file risks dropping its children (`(unverified)`, untested).
- Only `1` (friend) and `-1` (hostile) matter in practice. Vanilla authors `0` and `0.5` as neutral.
  Treat anything above `-1` as not hostile.
- [`soul:GetRelationship(other[, "Original"|"Current"|"Perceived"])`](api/Soul.md#getrelationship)
  reads it. A wanted player sits at `-1` with the town watch too.
- [`soul:GetFactionID()`](api/Soul.md#getfactionid) returns the faction **name**. Settlement factions
  follow `<region>_settlements_<place>_<estate>_<group>` (estate: `commonFolk`, `nobility`, `soldiers`)
  (crime-watch).
- Skald's `AddFactionRelationBetweenArrays` is directional as well: `SoulArray0` becomes hostile
  toward `SoulArray1` (malesov-structure).
- Moving a soul into `players_friends` did not make a scripted battle fight it
  (merc-battle-rendering).

### Faction labels

`Labels` on a `<Faction>` (defined in `faction_label.xml`). Vanilla uses: `publicEnemy` (13 + 3 with
`camp`), `settlement` (30), `city settlement` (1, Kutná Hora), `camp` (74), `solitude`, `jewish`,
`romani`.

- **`publicEnemy`** is what [`RPG.IsPublicEnemy`](api/RPG.md#ispublicenemy) reads. It decides
  **Loot vs Rob** on corpses and chests (`Stash:UsesStealUiPrompt`, vanilla:
  `Scripts/Scripts/Entities/WH/Stash/AnimStash.lua`). The crime AI also uses it: such NPCs do not
  report, arrest or mourn. Give every hostile mod faction this label, or its loot comes out stolen
  (public-enemy).
- The soul's `social_class_id` does **not** decide Loot vs Rob: vanilla's `deadBodies_enemies` faction
  (`Labels="publicEnemy"`, there so scripted corpses loot legally) holds souls of social class 1 (villager), 5
  (beggar), 38 (bandit) and 61 (vanilla: `Libs/Tables/rpg/FactionTree.xml`, `soul__*.xml`).

## Smart objects: sitting, sleeping, working

- A vanilla sit/sleep spot is **two** objects: the visual prop and a separate `StanceSmartObject`
  entity carrying `guidSmartObjectType`/helpers. Triggers and schedulers link to the smart object.
  Properties hung on the visual prop work for the player but never give NPCs a spot
  (camp).
- `StanceElement` does not walk the NPC there. `Move` first (`changeNPCState="true"`), then
  `StanceElement` with a `WaitAction` child to play the enter animation, then hold with `Wait`.
- Activities are `UnstanceData` entries in `Libs/Tables/ai/NPCStateUnstanceDatabase.xml`, played by
  `UnstanceAction unstance="$name"`. They only work when `UseLocationObject="false"` and nothing is
  needed in the hands. Profession unstances need level-baked `ItemSlot` entities and work only at
  their original village location. `System.SpawnEntity` returns nil for `ItemSlot`
  (camp-forge).
- Hold poses with `UnstanceElement`/`StanceElement`, never with a bare `UnstanceAction`. Only ending
  the owning `StanceElement` releases a pose.
- A **T-pose** when playing a fragment means an unresolved Mannequin tag in its `Loop` (e.g. a
  required weapon in hand). Tags explain failures after the fact but do not predict success; test
  in game (loot-sweep).
- `GetStance Npc Stance StanceObject` reads the real stance. `stanceCategory`: `undefined`,
  `standing`, `lying`, `sitting`, `kneel`, `horse`, `crouch`, `cart` (retail binary).
- A smart object caches its helper transform at creation; set orientation at spawn. `SetAngles`
  yaw and the spawn `orientation` vector differ by a quarter turn.
- Bed ownership (whether sleeping saves) is set only by Skald `SetOwner`; no Lua setter exists.

## Companions and followers

- **Group following:** `CrimeFollower Target Role="Main"|"Assist" RelativeSpeedLimit DisableGhosting BlockWay`
  keeps distance and catch-up speed without scattering. Plain `Move` to one point scatters a group
  ([movement](../behaviour-trees/movement.md)). Engine formations are in
  [formations](formations.md).
- **Live chase:** `additionalMoveParams` `destChangedThreshold('50ms')` re-paths to a moving
  target without re-issuing `Move`.
- **Speed ceiling:** `Dash` is the fastest gait for humans and horses. To keep up with a sprinting
  player, buff the entity (`rms`/`mst` movement-speed stats, the same codes vanilla horse tack uses)
  (formations). `AI.SetEntitySpeedRange` /
  `AI.SetSpeed` are overridden on the next movement tick (old context doc, `(unverified)`).
- **Far-behind teleport:** always guard with `entity:IsDead()`, or corpses teleport to the player.
- Native follow: [`Actor.StartFollow`](api/Actor.md#startfollow) / `CanFollow` exist (1 vanilla use).
  Behaviour is `(unverified)`.
- Friendly followers join any fight the player starts, which breaks tournaments, brawls and duels.
  Park or despawn them first (old context doc, claimed).
- The player's dog runs a `DogCompanion` subbrain (type 8); `$__playerDog` is its WUID.

## Equipment and appearance

Verified in game unless noted (custom-gear, outfits,
companions, [add-new-npc](../xml/add-new-npc.md)):

- A runtime-spawned NPC declines every `EquipInventoryItem` until **a clothing preset** has been
  applied once ([`Actor.EquipClothingPreset`](api/Actor.md#equipclothingpreset)). Apply a
  **weapon preset** too ([`Actor.EquipWeaponPreset`](api/Actor.md#equipweaponpreset)), or combat
  dies at the draw.
- `equipment_slot.xml` `RequiresFilledSlot` silently refuses a piece until its under-layer is worn,
  and not within the same tick (e.g. gambeson before cuirass, coif before helmet).
- Two preset items in one slot means **neither** equips.
- `IsQuestItem` items are refused, even in presets, even for NPCs.
- There is no "what is worn" query. `actor:GetArmor()` can read 0 on a fully armoured NPC.
  Removing worn armour reliably means unequip plus `DeleteItemOfClass`.
- Give NPC items with [`inventory:CreateItem`](api/Inventory.md#createitem)`(class, health, amount)`.
  `ItemManager.CreateItem` + `AddItem` silently adds nothing (archers).
- **Storm appearance** (official wiki KM-A-32): rules select souls (`hasName` supports wildcards)
  and apply `setBody`/`setHead`/`setHair`/`setBeard`/`setUnderwear`. Faces are randomised from the
  archetype unless a rule pins them, and a `setHead` on a soul name clones every NPC with that soul.
  Pin body/underwear and omit head/hair/beard to keep faces varied (old context doc).
- New heads/hair: add named components in a merged `CharacterComponent__<modid>.xml` and point
  souls at them. Overriding a vanilla asset path changes every character that uses it
  (female-mercenaries).
- Clothing `Quality` (1..4) and `Condition` (0..1, `ConditionVariation`) on presets control worn
  look (difficulty).

## Body types and female NPCs

- `NPC_Female` (archetype 1, class `NPC_Female`, `female.cdf`) is a full **civilian** pipeline:
  986 of ~7,200 souls are female (retail data: female-mercenaries).
- **There is no female combat at any layer.** 205 female clothing meshes and none of them armour.
  No female combat `.dba` animations, 0 combat fragments in `wh_female_fragmentids.xml`, and the
  skeleton lacks the IK joints combat needs. A female NPC spawns, walks and talks, then stands inert
  when combat starts.
- A practical workaround: female heads and hair on male bodies via new `CharacterComponent` entries.
  The head mesh must be offset (edit `.skin` vertex Z; `SkinElement` has no offset attribute).
- Copying a vanilla character's `body_type` can pair it with a `unique_assets` index tied to that
  character's quest, which gives a **fully invisible** NPC. Clamp to known-safe body types
  (companions).

## Gotchas

- **NPC spawns with no soul, inventory or brain, and no error**: wrong property key (`sharedSoulGuid`)
  or an `s`-prefixed GUID.
- **T-posed NPC right after spawn**: `class` does not match `soul_archetype_id`.
- **NPC stands still, never fights**: interrupt behaviour not registered in a SmartEntity, or its
  template is `InitialState="Disabled"`.
- **Vanilla NPCs ignore your hostile faction**: relations are one-directional.
- **Corpses of your bandits prompt "Rob" and loot is stolen**: faction lacks `Labels="publicEnemy"`.
- **NPC spawns naked or partially dressed**: no preset applied first, `RequiresFilledSlot` order,
  two items in one slot, or a quest item.
- **NPC invisible from spawn**: DLC-only head without the DLC (e.g. `m_head_painter`), or an
  unsafe `body_type`. See [NPC rendering and LOD](npc-rendering-and-lod.md#content-that-renders-nothing).
- **Polearm NPC looks unarmed**: sheathed polearms do not render.
- **NPC keeps sitting while walking/fighting**: pose held by `UnstanceAction`.
- **Dialogue E-prompt dead or laggy**: no `dialogMailbox` handler in the tree, or polled too slowly.
- **`Move` to a spawned marker does nothing**: `BasicEntity` is not AI-targetable. Move to a `vec3`.
- **Female soldier stands inert in combat**: no female combat pipeline exists.
- **SoulDeathTrigger never fires** for Lua-spawned NPCs. Poll instead.

## See also

Public guides: [add-new-npc](../xml/add-new-npc.md), [make-npc-brain](../xml/make-npc-brain.md),
spawning-npcs. War stories: companions,
female-mercenaries, camp, camp-forge,
custom-gear, outfits, public-enemy.
