# How to Mod KCD2: The Real Way

Alright, so you decided to create a KCD2 mod. Cool. You might wonder: *How do I create a mod?* The short answer is to look at the official guide: [The Modding Tools](https://warhorse.youtrack.cloud/articles/KM-A-55/The-Modding-Tools). It covers setting up the folder structure, installing the modding tools, etc.

**My honest opinion? Scrap that.** Only use the official modding tools for four things:
1. **Assets:** I have no idea how to do this, and you won't find any information on that here.
2. **Level Editing:** I highly advise against doing this, as it's almost guaranteed to create incompatibilities with other mods. If you want to spawn in an asset, use Lua. It's harder, but it will not conflict with other mods.
3. **The Lua Docs:** This is the most useful part of the tools. You can find them at `C:\Program Files\Steam\steamapps\common\KCD2Mod\Tools\modding\docs\script_bind`. They are extremely useful.
4. **Publishing:** Use the official tools to publish your mod on the Steam Workshop.

## Why avoid the official Modding Tools?

You might wonder why I am flaming the official modding tools so badly. Here is why:

* **Reason 1: Loading Times.** It takes about a minute for a save file to load in the modding tools version of the game. In the base game, it takes 20 seconds. If you frequently restart the game to test something out, you will waste a humongous amount of time.
* **Reason 2: Version Differences.** There are differences between the official KCD2 version and the modding tools version. It is usually a different game build, meaning not every part of Lua works the same. For example, in the modding tools, you can execute console commands from Skald; in vanilla, you can't. Don't ask me how much time that wasted for me.
* **Reason 3: False Positives.** Working directly with the base game will save you the shock of finding out your mod works in the modding tools but breaks in the actual game. Trust me, I experienced it twice and do not recommend it. The modding tools version is far more robust against errors in your files, meaning bad code might run there but crash vanilla.

**The ONLY reason to launch the modding tools version of KCD2 is for the logs.** They are bad, but better than nothing. They can point you in the basic direction of an issue (like a syntax error), though they rarely provide the exact line of the culprit.

---

## The Recommended Setup

Let's say you have set up your mod folder in the vanilla game files. The very first thing you need to do is set up a **Base Game Reference**—a folder where you extract the vanilla files so they are quickly accessible.

1. Go to `C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2\Data\`
2. Take `Tables.pak`, `Scripts.pak`, and `IPL_GameData.pak` and extract them somewhere safe. 
3. **Use Total Commander** (or another power-user file explorer) to search through these extracted files. It enables lightning-fast searching inside files. *Under no circumstance should you use Windows Explorer for this.*

If you want to do something (add a buff, quest, etc.), always start by looking through these base game files. Search for keywords, extract the lines containing those keywords, and feed them into your LLM/chatbot of preference. Feed your chatbot the files that seem to do what you want and ask it to adapt them. Trust me, it's a highly efficient way to mod.

---

## Vanilla File Breakdown

Here is a basic overview of what you will find inside those extracted vanilla files:

### `AI/` (Behavior Trees)
Contains all behavior trees—the "brains" of basically everything in the game, from soldiers, beggars, and nobles to horses, dogs, and doors. Almost everything of interest is located in `AI\npc\basic\switch\`.
* **Notable file:** `AI\npc\basic\switch\switch.xml`. This file handles the basic NPC handling of stimuli (e.g., how the game routes the reaction when the player attacks them). All other files in this folder are different actions reacting to something the player did.
* **Notable file:** `AI\npc\basic\switch\interrupt_attack.xml`. This is pretty much what runs all of vanilla combat. I will explore it more in the combat section of the behavior tree guides.

### `Libs/` (Definitions)
This contains all basic definitions (NPCs, who wears what, prefabs, items, buffs, etc.). The most interesting folders are `tables` and `storm`. They basically contain everything of interest for a large majority of mods.
* **Storm:** You have to create your own rules, which are merged into the base game files.
* **Tables:** You have to create patches using a very specific naming convention: `fileyouwanttoedit__yourmodid.xml` (note the **two underscores**—this is very important). 

### `Quest/`
This contains all base game quests, random encounters, activities, and dialog definitions. `Final\Barbora` is the most interesting part; explore it at your leisure. 
* *Note:* This is usually edited with Skald, but I advise against using Skald directly for this. If you want to add a completely new Skald file, I recommend defining the files manually. Feed a bunch of reference files into a chatbot and tell it what you want. In Skald, you can see nodes and add them, but the nodes themselves aren't very informative, and you'll have to guess at their meaning. A basic overview will be provided in the "How to add a quest" guide.

### `Scripts/` (Lua)
The Lua scripts the base game uses. I honestly never 100% understood why the devs bothered with Lua at all, since all the heavy lifting is defined in the C++ part of the game (which modders cannot access). This folder just contains random utilities, testing stuff, a few interesting definitions, and a bunch of CryEngine/KCD1 leftovers.
* **Notable file:** `Scripts\Debug\CombatDebug.lua`. It gives you a crash course on spawning NPCs.
* Even with its limitations, this folder is a paradise for modders. I am of the opinion that with enough creativity, you can code almost anything using Lua.

---

This is just a basic overview of the base game files. I will not cover exactly how to implement every feature here—writing a truly "general" guide is close to impossible. If you want to create something specific, explore the game files or look at one of my specific guides!