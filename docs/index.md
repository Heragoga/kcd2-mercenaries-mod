# Welcome to Alex's KCD2 Modding Wiki

This is a small documentation where I am going to write down the knowledge I gained about KCD2 modding while I create the mercenaries mod. Since Warhorse gives us barely any docs about modding, it all falls to us. 

This wiki will be structured a bit differently: it will mostly consist of guides about doing a certain thing, not articles describing a certain feature or whatever. The primary purpose of this is so that I don't forget how to do something I did some time ago. 

This wiki will cover some parts of modding, but not all of them. Most will be heavily focused on **Lua**, **XML editing**, **Skald**, and in particular **Behavior Trees**, since these are the parts I actually touched. 

> **Note:** Don't come here searching for information about adding 3D models, textures, or animation. I don't have anything even remotely approaching an idea of how to do that.

---

## Things this wiki currently covers:

### General
* [How to mod](general/how-to-mod.md) (How to set up a project, how to understand the base game's structure, how to test out your creation)
* [Communicating between Lua and Skald](general/lua-skald-communication.md) (How to call lua code from your quest)
* [How to add new equipment presets](general/adding-new-outfits.md) (How to change the equipment of the Mercenaries)
* [How to add new custom weapons](general/adding-new-weapons.md) (How to change the weapons of the Mercenaries)
* [How to create new voice-lines](general/voice-acting.md) (If you want to contribute some new voice-lines)


### Lua
* [Spawning NPCs](spawning-npcs.md) (How to spawn an NPC you defined in the other guides)

### XML
* [How to add a new NPC](xml/add-new-npc.md) (Covers defining the soul, inventory and appearance)
* [How to make an NPC Brain](xml/make-npc-brain.md) (Bridge between the NPC soul and the Behaviour Tree)

### Skald
* [How to add a top level quest](skald/add-top-level-quest.md) (Basic management quest, adds dialog and may create new quests)
* [How to add dialog](skald/add-dialog.md) (Creating dialog, both ingame chatter and player to NPC conversation)

### Combat & AI
* [Ranged mercenaries / archer AI](archers.md) (The archer combat group: why ranged AI needs its own brain, the three skirmish variants, and how to test them)
* [Combat target selection](combat-target-selection.md) (How mercs, archers and renegades pick who to fight: the one-scan-per-second cache, anti-swarm cap, the -1 relationship rule, and the stance pickers)

### Camp
* [Mercenary camp](camp.md) (Procedural camp spawn/despawn, how props render without a custom entity class, the smart-object sit/sleep integration, and deploying from camp)
* [The quartermaster](quartermaster.md) (An immortal camp NPC with a lobotomized-merc brain: stands, eats, defends when raided, and serves as a talking interface)
* [Quartermaster logistics](quartermaster-logistics.md) (The camp-management systems he fronts: tiredness, food, drink and wages, with combat buffs and save-persistent state)
* [The camp forge and its smith](camp-forge.md) (The borrowed-Smithery forge, and the full postmortem of ~10 failed NPC-smith approaches plus the one that works - read before making any NPC "work" at a built structure)
* [The camp alchemy bench](camp-alchemy.md) (The Alchemy Bench upgrade: borrowing and relocating a village AlchemyTable, and why it needs its own spawned mesh)

### Behaviour Trees
* [Basic structure](behaviour-trees/basic-structure.md) (Covers the basic structure of the Behaviour Tree and some basic logical components)
* [Combat](behaviour-trees/combat.md) (How to make your NPC fight)
* [Movement](behaviour-trees/movement.md) (How to make your NPC move)
* [Talking](behaviour-trees/talking.md) (How to make the NPC talk to the player or just talk in general)

---

## Random pieces of advice

* Do not prefix string ids with a number or special character, they always have to begin with a letter
* Lua comments should not be put into behaviour trees

---

*This wiki will get expanded as I continue to mod.*
