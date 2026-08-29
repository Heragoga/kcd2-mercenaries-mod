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
* [How to master recorded voice-lines](general/voice-mastering.md) (Denoise, dereverb and level takes to match vanilla dialogue)


### Lua
* [Console commands](console.md) (Every command a player can type, where they are registered, and how the `merc_dev` gate keeps the ~350 authoring/diagnostic ones out of the player's console)
* [Spawning NPCs](spawning-npcs.md) (How to spawn an NPC you defined in the other guides)

### XML
* [How to add a new NPC](xml/add-new-npc.md) (Covers defining the soul, inventory and appearance)
* [How to make an NPC Brain](xml/make-npc-brain.md) (Bridge between the NPC soul and the Behaviour Tree)

### Skald
* [How to add a top level quest](skald/add-top-level-quest.md) (Basic management quest, adds dialog and may create new quests)
* [How to add dialog](skald/add-dialog.md) (Creating dialog, both ingame chatter and player to NPC conversation)
* [The silent order wheel](order-wheel.md) (Mutt-style chat menus: `Type="chat"` dialogues that open with no camera and no spoken line, the four-slot `ChatPosition` limit, and how the squad-order wheel reuses the E-dialog's tokens)
* [Lipsync](lipsync.md) (Making custom lines move the lips: the `<voiceAbbrev>_<StringName>` rule that binds a facial clip to a line, retargeting vanilla lipsync onto our own StringNames, the generic `fa_cin_talk_*` library, and the dead ends - lip sync is **not** proprietary)
* [Cutscenes: why a mod can't play one](cutscenes.md) (How the cutscene tables, CutsceneHolder entities and quest assets fit together, and the postmortem of why no cutscene of any type can be played without shipping level data - read before attempting it)

### Combat & AI
* [Ranged mercenaries / archer AI](archers.md) (The archer combat group: why ranged AI needs its own brain, the three skirmish variants, and how to test them)
* [AI modules](ai-modules.md) (The five reusable behaviour modules - combat_melee, combat_archer_dynamic/static, follow, camp_actor - the schedulers that fire them, and the Lua control points for encounters)
* [Combat target selection](combat-target-selection.md) (How mercs, archers and enemies pick who to fight: the shared enemy cache, the lock-on aggro rule, anti-swarm cap and the -1 relationship rule)
* [The town watch](town-watch.md) (Murder enough people in a village and it musters a defence force against the company: the four trigger gates, why stealth kills don't count, the five muster points that beat a town's terrain, and the 3-day regeneration after a watch is wiped out)
* [The crime watchdog](crime-watch.md) (Logging guards and townsmen the company kills, and the player's standing in a village: the `crime_isAuthority`/`crime_isCivilian` script contexts that classify an NPC, the NPC-name-to-settlement prefix map, and why the crime rating itself is unreadable from Lua)
* [Squad orders](squad-orders.md) (Everything the player can order beyond follow/equip: the four engagement stances and why they need no scheduler XML at all, anti-swarm presets, calling a target, holding ground with a role-shaped line and a leash, escorting in column, and multi-merc barks — including vanilla voiced shouts for free)
* [Difficulty](difficulty.md) (One tier setting read by raids, roaming patrols and the bounty/Kleinkrieg contracts: how the count cap works against each system's own strength measure, the hard ceilings that had to scale with it, and how armour quality is biased from data the mod already had)
* [Custom companions](companions.md) (The 44 named companions cloned from vanilla characters: the roster generator that is the single source of truth, the thirteen files each one has to exist in, vanilla-versus-built gear, the categorised hire menu, and the three traps - quest items that arm nobody, sheathed polearms that do not render, and body_type making an NPC invisible)
* [Squad outfits](outfits.md) (The 180-preset wardrobe: the per-tier armour budget that makes every style equally tough, the layering rules that break silently, the six styles and their heraldry, the reinforced caftans the Cuman styles need, and what is excluded from the item pool and why)
* [The custom uniform](custom-gear.md) (Drop a set of gear in a chest and the whole company wears a copy of it, anywhere, camp or no camp: the offline GUID→slot table that exists because nothing in the scriptbind reports a slot, the dressing order that is the whole trick, the gambeson-under-plate rule, and how an empty pattern means naked with a sword)
* [Formations](formations.md) (How the squad marches: the engine formation system, the elected-leader anchor it forces, the seven generated shapes, and the mounted variant - plus the vanilla research behind it)
* [The torture test](torture-test.md) (One command drives a real game session through 19 behaviour checks - hire, camp, upgrades, deploy composition, a staged fight, the time-skip guards, and persistence across a save + cold relaunch - and prints PASS/FAIL verdicts)
* [Performance](performance.md) (What the mod costs and what controls it: the patrol population caps that fixed the long-standing lag, every cost tunable with its default, the profiler and how to read it, and what was ruled out so it is not re-chased)
* [NPC LOD and invisible mercenaries](npc-lod.md) (The four systems that can stop an NPC rendering while it keeps fighting: AI LOD tiers and count budgets, the runtime clothing/attachment pipeline, quest-driven hides, and the per-battle cvar overrides — plus diagnostics)
* [utokNaMalesov structure](malesov-structure.md) (What actually enrols an NPC in a scripted battle: `AddFactionRelationBetweenArrays` SoulArray0→SoulArray1, why nothing in the quest hides anyone, and why hibernation is a red herring)
* [Main-quest battle overrides](quest-override-battles.md) (**The shipping fix for invisible mercenaries**: all 12 main-quest battles overridden with the merc souls listed in their SoulAssets — what the tool does, the scopes, and the maintenance burden)
* [Quest-override experiment](quest-override-test.md) (The single-quest Malesov prototype that proved soul membership is the render gate — `merc_testmerc`, the bisects, and how to revert)
* [Post-battle loot sweep](loot-sweep.md) (Mercs wander the corpses and rummage after a fight - animation only, no item transfer - plus the revive/knockout/mercy-kill act, and why it rides the camp activity pipeline instead of its own module)
* [Foe AI](foe-ai.md) (The rewritten hostile AI: idle until alerted, then one foe shouts and every foe in earshot engages at once. Own brain, souls, faction and trees - shares nothing with the enemy groups)
* [Enemy groups](enemies.md) (The six hostile groups that replaced the renegades — looters, bandits, Sigismund's soldiers, Prague regiment, Cumans, Sigismund's knights — their souls/faction/brains/gear and the spawn commands)
* [Public enemies and stolen loot](public-enemy.md) (Why hostile NPCs dropped stolen loot - `Labels="publicEnemy"` on the faction, not the soul's social class - and the two reasons the town watch ignores a patrol beating the player)
* [The bandit-camp contract](bandit-camp-quest.md) (The mod's first real journal quest: how an Objective, its log entries and its map marker are built from Skald primitives only, why the marker has to ride a soul, and the Lua↔Skald token bridge in both directions)
* [The standing bounty](bounty.md) (The quartermaster's repeatable “clear a camp for coin” job: how two bandit-camp contracts run at once on one set of machinery, how a site is drawn at random without treading on Kleinkrieg's, and why the bounty is the one that moves)

### Camp
* [Mercenary camp](camp.md) (Procedural camp spawn/despawn, how props render without a custom entity class, the smart-object sit/sleep integration, and deploying from camp)
* [The quartermaster](quartermaster.md) (An immortal camp NPC with a lobotomized-merc brain: stands, eats, defends when raided, and serves as a talking interface)
* [Quartermaster logistics](quartermaster-logistics.md) (The camp-management systems he fronts: tiredness, food, drink and wages, with combat buffs and save-persistent state)
* [The camp forge and its smith](camp-forge.md) (The borrowed-Smithery forge, and the full postmortem of ~10 failed NPC-smith approaches plus the one that works - read before making any NPC "work" at a built structure)
* [The camp alchemy bench](camp-alchemy.md) (The Alchemy Bench upgrade: borrowing and relocating a village AlchemyTable, and why it needs its own spawned mesh)
* [Walls, pathfinding and staged battles](walls-and-sieges.md) (The palisade upgrade, the custom navmesh mod NPCs use to route around it - and every engine blocker that does NOT work - and the three-phase staged battle that forms both sides into lines at the gaps before combat opens)
* [Camp gates and multi-stretch walls](gates.md) (Placeable gates that open and shut - a shut gate blocks pathing and calls off raids - plus the many-stretch wall builder, and how to enumerate all 16k object meshes straight out of the paks)
* [Patrols (tester)](patrols.md) (Waypoint/leader/formation sandbox for bandit and soldier patrols - and why a harmless NPC needs its own soul on testFaction rather than just having its combat fires gated)

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
