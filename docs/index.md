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

### Lua
* [Spawning NPCs](spawning-npcs.md) (How to spawn an NPC you defined in the other guides)

### XML
* [How to add a new NPC](xml/add-new-npc.md) (Covers defining the soul, inventory and appearance)
* [How to make an NPC Brain](xml/make-npc-brain.md) (Bridge between the NPC soul and the Behaviour Tree)

### Skald
* [How to add a top level quest](skald/add-top-level-quest.md) (Basic management quest, adds dialog and may create new quests)
* [How to add dialog](skald/add-dialog.md) (Creating dialog, both ingame chatter and player to NPC conversation)

### Behavior Trees
* [Basic structure](behaviour-trees/basic-structure.md) (Covers the basic structure of the Behaviour Tree and some basic logical components)
* [Combat](behaviour-trees/combat.md) (How to make your NPC fight)
* [Movement](behaviour-trees/movement.md) (How to make your NPC move)
* [Talking](behaviour-trees/talking.md) (How to make the NPC talk to the player or just talk in general)

---

*This wiki will get expanded as I continue to mod.*
