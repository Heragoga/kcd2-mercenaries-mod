# KCD2 Modding Tutorials

Guides to modding **Kingdom Come: Deliverance II**, written down while building the
Mercenaries mod. Warhorse publishes little documentation, so most of this comes from reading
the vanilla game files and trial and error. The guides are about doing a specific thing, and
they lean heavily on **Lua**, **XML tables**, **Skald** and **behaviour trees**, because those
are the parts the Mercenaries mod touches. Examples use the mod's own files where that helps;
the techniques apply to any mod.

## Start here

* [Episode 1: Mod setup and game file structure](tutorials/episode-01-mod-setup.md) - the
  written companion to the first video: tools, the vanilla reference, mod layout,
  `mod.manifest`, load order, building the pak, `__modid` table patches, overrides,
  localization, the Lua init script, `mod.cfg` and reading `kcd.log`.
* [How to mod](general/how-to-mod.md) - setting up a project, understanding the base game's
  files, and testing your work.

## General

* [Communicating between Lua and Skald](general/lua-skald-communication.md) - calling Lua from
  a quest or dialogue via inventory tokens.
* [Custom equipment presets](general/adding-new-outfits.md) - changing what the Mercenaries wear.
* [Custom weapon presets](general/adding-new-weapons.md) - changing what the Mercenaries carry.

## XML

* [Adding a new NPC](xml/add-new-npc.md) - the soul, faction, roles, Skald character,
  clothing, inventory and Storm rules.
* [Making an NPC brain](xml/make-npc-brain.md) - the bridge between an NPC's soul and its
  behaviour tree.

## Skald

* [Adding a top-level quest](skald/add-top-level-quest.md) - a silent background quest that
  hooks your dialogue into the game.
* [Adding dialogue](skald/add-dialog.md) - player conversations and ambient NPC monologues.

## Behaviour trees

* [Basic structure](behaviour-trees/basic-structure.md) - variables, logic nodes, interrupts,
  running Lua and concurrency.
* [Combat](behaviour-trees/combat.md) - making an NPC fight.
* [Movement](behaviour-trees/movement.md) - making an NPC move.
* [Talking](behaviour-trees/talking.md) - dialogue and monologues from a behaviour tree.

## A few pieces of advice

* Do not start string ids with a number or special character; they must begin with a letter.
* Do not put Lua comments inside behaviour trees.
