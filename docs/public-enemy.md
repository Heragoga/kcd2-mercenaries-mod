# Public enemies, stolen loot and bystanders

Why the mod's hostile NPCs used to drop **stolen** loot, and why the town watch
stands and watches while a patrol beats the player.

## Looting: the `publicEnemy` faction label

Whether a body (or a chest) is *looted* or *robbed* is decided by one thing:

```lua
-- references/Scripts/Entities/WH/Stash/AnimStash.lua
function Stash:UsesStealUiPrompt()
    local ownerWuid = EntityModule.GetInventoryOwner(self:GetInventoryToOpen())
    if ownerWuid == __null then return false end
    if ownerWuid == player.this.id then return false end
    return not RPG.IsPublicEnemy(ownerWuid)
end
```

`RPG.IsPublicEnemy` reads the **`Labels="publicEnemy"` attribute on the owner's faction**
(`faction_label.xml` defines the label; `FactionTree.xml` sets it on 13 nodes). Nothing
else feeds it.

It is **not** the soul's `social_class_id`. The proof is vanilla's own
`deadBodies_enemies` faction — the one that exists purely so scripted corpses can be
looted legally — whose souls carry `social_class_id` 1 (villager) and 5 (beggar)
alongside 38 (bandit). A villager-class body in a `publicEnemy` faction loots clean, so
the class cannot be what the check reads.

The mod shipped every hostile soul in a faction with no label, so every one of them was
a private citizen: their corpses prompted *Rob*, everything taken came out flagged
stolen, and killing them counted against the player. `enemiesFaction`, `patrolFaction`
and `foeFaction` now carry `Labels="publicEnemy"` in
[FactionTree__mercenaries.xml](../data/libs/tables/rpg/FactionTree__mercenaries.xml).
`mercenariesFaction` and `testFaction` deliberately do not.

`IsPublicEnemy` also gates the crime AI: every vanilla use of the `IsPublicEnemy` BT node
asks about **itself** (`Soul="$this.id"`), in `chooseReaction`, `resolveSkirmishParticipants`,
`handleAwareness_corpse` and `crime_isBandit`. So the label additionally tells the engine
that these NPCs are outlaws — they do not report crimes, do not arrest, and are not
mourned.

`social_class_id` is a separate axis (`social_class.xml` → `soul_crime_role`), and every
mod soul is still `3` (townsman). Moving the hostile ones to 38 (bandit) / 43 (cuman) /
70 (fake_soldier) would match vanilla's own bandits, but it changes nothing about loot.

## Bystanders: why the town watch does nothing

Two separate reasons, and the label fixes neither.

**1. No vanilla faction is hostile to ours.** Relations are one-directional: this was
measured in the Malesov battle, where `mercenariesFaction` declared `-1` to the vanilla
enemy factions and vanilla NPCs still targeted our mercs **zero** times, because no
vanilla faction names `mercenariesFaction` at all (see `docs/npc-lod.md`). `patrolFaction`
is silent about every vanilla faction and no vanilla faction has heard of it, so a guard
perceiving a patrolman gets no *enemy* stimulus and `switch_handleStimulusEnemy` never
runs.

Declaring `<Relation target="kutnohorsko_settlements_kutnaHora_soldiers" reputation="-1" />`
from our side is therefore not expected to be enough; the relation has to exist on the
vanilla node, which means re-declaring a vanilla faction inside
`FactionTree__mercenaries.xml` and hoping the merge is additive rather than a replacement
that drops the node's children. Untested, and the failure mode is a wiped subtree.

**2. The mod's attacks never enter the crime system.** Vanilla NPCs start a fight through
`Function_callInterrupt_attack`, which runs `crime_emitInformation` alongside it and
broadcasts an `assault` to everyone in earshot; that broadcast is what a guard reacts to.
Every mod scheduler instead fires the raw `AddInterrupt_attack` SO node. `patrol_scheduler.xml`
does build the `assault` information wrapper (`CreateInformationWrapper Label="'assault'"
PerceivedWuid="$this.id"`) and reserves a reaction link, but it hands the wrapper straight
to `$attackData` — **nobody emits it**, so no bystander is ever told.

The tractable experiment is therefore (2), not (1): run
`Function_crime_emitInformation` (`emitCrimeInformation="true"`,
`reactionKind=$enum:crime_reactionKind.attack`) on the wrapper the patrol scheduler
already builds, as a parallel arm that lives as long as the fight. `PerceivedWuid` is the
patrolman, so a guard who receives it should react against *him*. It is a continuous
behaviour (`Loop count="-1"`), not a one-shot function, so it needs its own arm in the
scheduler's `Parallel`.

Risks worth watching in that experiment: the crime system may attribute the ensuing
brawl to the player, guards may prefer *arrest* over *attack*, and a patrol that is now a
legitimate crime scene may pull the whole village into it.

## Related: patrols spawn inside villages

`mercenaries_patrols_live.lua` gates spawning only on distance from the player
(`PatrolNoSpawnRange`, 200 m). Routes were recorded by riding real roads, and roads run
through villages, so a gang can appear at a blacksmith's door. A settlement exclusion on
route points (`RPG.GetLocations` proximity, or a flag on the recorded points) is the
cheaper fix for "attacked in a village" than teaching the watch to fight.
