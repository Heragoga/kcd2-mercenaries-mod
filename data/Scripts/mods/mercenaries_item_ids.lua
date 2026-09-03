-- GENERATED FILE - DO NOT EDIT BY HAND.
-- Source: data/libs/tables/item/item__mercenaries.xml
-- Regenerate: python tools/gen_item_ids.py
--
-- Every item class this mod defines. The uninstall/audit commands need the
-- WHOLE list, not just the tokens the script happens to reference by name:
-- any of these left in a save is a broken class reference once the mod is
-- gone. See mercenaries_commands.lua (merc_items / merc_purge_*).

mercenaries.ModItemIds = {
    -- Generic merc recruitment (first item tier one, second item tier tow and third itme tier three)
    { id = "679a655e-189d-4519-b437-ccc4b92be41d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be42d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be43d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Items used to pass orders (dimiss, idle, follow)
    { id = "679a655e-189d-4519-b437-ccc4b92be44d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be45d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be46d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Item used to indicate which style should be chosen (one of these items: common merc, two bandit, three cuman, four skalitz and five kuttenberg)
    { id = "679a655e-189d-4519-b437-ccc4b92be47d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Item used to indicate the recruitment of a custom companion, one means custom companion 1, two custom companion 2 etc
    { id = "679a655e-189d-4519-b437-ccc4b92be48d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Item to handle recalling your mercs via innkeeper
    { id = "679a655e-189d-4519-b437-ccc4b92be49d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- ITem to handle healing, number of this item corresponds to number of mercs healed
    { id = "679a655e-189d-4519-b437-ccc4b92be50d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Item to select weapon loadout via dialogue; count = loadout index (1 Random ... 12 Handcannon)
    { id = "679a655e-189d-4519-b437-ccc4b92be55d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Items to spawn renegades via dialogue, one per tier; count = how many to spawn
    { id = "679a655e-189d-4519-b437-ccc4b92be56d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be57d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be58d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Archer (ranged merc) hire tokens, one per tier; count = how many to hire
    { id = "679a655e-189d-4519-b437-ccc4b92be60d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Archer stance token; count = stance (1 skirmish, 2 guard, 3 melee, 4 hold)
    { id = "679a655e-189d-4519-b437-ccc4b92be62d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be51d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bee4d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bee5d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bee6d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bee7d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bee8d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- RESERVED, currently unused. Was a 'the squad is holding' marker meant to let an ItemDescriptorTrigger drive the order wheel's Wait/Fall-in label. Backed out: the prompt whose text actually changes is the LOOK-AT interactor action (mercenaries_lookatinteraction.lua), which reads mercenaries:SquadIsWaiting() directly and needs no marker at all - and a marker that sits in the inventory for the life of an order is visible to the player. Kept only so the GUID stays claimed.
    { id = "679a655e-189d-4519-b437-ccc4b92bee9d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92beead", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92beebd", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92beecd", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92beefd", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Custom uniform: 'I want you to dress this way' was picked
    { id = "679a655e-189d-4519-b437-ccc4b92beeed", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Archer ranged weapon type token; count = weapon type (1 bow, 2 crossbow, 3 handcannon)
    { id = "679a655e-189d-4519-b437-ccc4b92be63d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Squad status report token
    { id = "679a655e-189d-4519-b437-ccc4b92be64d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Camp tokens: spawn a procedural camp / break it down
    { id = "679a655e-189d-4519-b437-ccc4b92be65d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be66d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Quartermaster placeholder test dialog token
    { id = "679a655e-189d-4519-b437-ccc4b92be67d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Quartermaster logistics dialog tokens
    { id = "679a655e-189d-4519-b437-ccc4b92be68d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be69d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be6ad", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be6bd", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be6cd", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be6dd", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be6ed", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be6fd", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Quartermaster camp-upgrade tokens
    { id = "679a655e-189d-4519-b437-ccc4b92be70d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be71d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be72d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be73d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be74d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be75d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be7cd", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be7dd", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be7ed", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be7fd", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be80d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Count-as-selector tokens: the AMOUNT granted picks the menu option
    { id = "679a655e-189d-4519-b437-ccc4b92bef1d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bef2d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Camp deploy (take-N) tokens
    { id = "679a655e-189d-4519-b437-ccc4b92bee2d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bee3d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be79d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be7ad", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be7bd", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Ask-drink query token
    { id = "679a655e-189d-4519-b437-ccc4b92be76d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Food-delivery-panel result token: its COUNT = how many food items the player delivered
    { id = "679a655e-189d-4519-b437-ccc4b92be77d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be78d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Bandit-camp contract. be81d goes Skald->Lua like every other token here (dialog port -> CreatePlayerReward -> polled in mercenaries.lua). be82d goes the OTHER way: Lua creates it when the last bandit falls and an ItemDescriptorTrigger in bandit_camp_quest.xml watches for it, which is how a Lua-computed condition closes a Skald objective.
    { id = "679a655e-189d-4519-b437-ccc4b92be81d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be82d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be83d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Handing the letter over (Skald->Lua) and the quest closing (Lua->Skald).
    { id = "679a655e-189d-4519-b437-ccc4b92be85d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be86d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- 'the letter is in hand': moves the marker off the camp and onto the quartermaster.
    { id = "679a655e-189d-4519-b437-ccc4b92be87d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- NO IsQuestItem. That attribute is what stopped inventory:CreateItem making one: the item loaded into the database fine (the DB reports all 53 entries) and the call still produced nothing. The `cheat` mod in references/ hit the same wall and works around it explicitly - 'some quest item cannot be added while others can', 'some items are block by inventory:CreateItem' - and both vanilla letters that look like this one (letter_huntsmanRenes, zikmunduv_dopis) omit it too. Trade-off: without it the letter can be sold to a merchant. The contract checks the pack at hand-in, so selling it strands that contract until it is re-taken.
    { id = "679a655e-189d-4519-b437-ccc4b92be84d", tag = "Document", name = "merc_banditcamp_letter" },
    -- The quartermaster's two dialog gates: contract open/shut, hand-in ready.
    { id = "679a655e-189d-4519-b437-ccc4b92be9fd", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bea0d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bea1d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bea2d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- After the last kill: search his body / report straight back.
    { id = "679a655e-189d-4519-b437-ccc4b92be9dd", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be9ed", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bea3d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Aleksej forced-dialogue gates: player in range / out of range.
    { id = "679a655e-189d-4519-b437-ccc4b92bea5d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bea6d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Aleksej of Zaslawye: the seven documents (docs/aleksej.md). No IsQuestItem - it blocks inventory:CreateItem, which is how these reach a corpse.
    { id = "679a655e-189d-4519-b437-ccc4b92beaad", tag = "Document", name = "merc_alx_doc1" },
    { id = "679a655e-189d-4519-b437-ccc4b92beabd", tag = "Document", name = "merc_alx_doc2" },
    { id = "679a655e-189d-4519-b437-ccc4b92beacd", tag = "Document", name = "merc_alx_doc3" },
    { id = "679a655e-189d-4519-b437-ccc4b92beadd", tag = "Document", name = "merc_alx_doc4" },
    { id = "679a655e-189d-4519-b437-ccc4b92beaed", tag = "Document", name = "merc_alx_doc5" },
    { id = "679a655e-189d-4519-b437-ccc4b92beafd", tag = "Document", name = "merc_alx_doc6" },
    { id = "679a655e-189d-4519-b437-ccc4b92beb0d", tag = "Document", name = "merc_alx_doc7" },
    { id = "679a655e-189d-4519-b437-ccc4b92beb1e", tag = "Document", name = "merc_alx_doc8" },
    -- Aleksej of Zaslawye: the nine-beat progression's Lua-to-Skald bridge tokens (mercenaries_aleksej.lua TokenIDAlxB1/TokenIDAlxB1Done..TokenIDAlxB9Done). Same 'loot_sackOfNails' reusable token shape as the Kleinkrieg gates above - only beat 1's open and every beat's done need a Lua-droppable item; beats 2-9's open gates are pure graph edges (docs/aleksej.md).
    { id = "679a655e-189d-4519-b437-ccc4b92beb1d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92beb2d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92beb3d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92beb4d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92beb5d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92beb6d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92beb7d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92beb8d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92beb9d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bebad", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Aleksej of Zaslawye: the OTHER direction, Skald-to-Lua. Dropped by mercenaries_background_quest.xml's exec_alx_accept_N EventFunctions the instant aleksej_dialog.xml's alx_accept_1..5/alx_report_5 out-ports fire (the player heard that beat's assignment, or beat 5's report which is what opens beat 6), and swept by MonitorInventory's tok() entries (mercenaries.lua), which call AlxBeatStart(N) - same be81d/exec_qm_banditcamp shape the Kleinkrieg contract uses for 'I'll take the job'. Beats 7-9 need no token: AlxBeatComplete chains them directly in Lua once it knows the previous beat just finished.
    { id = "679a655e-189d-4519-b437-ccc4b92bec2d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bec3d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bec4d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bec5d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bec6d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bec7d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Beats 7, 8 and 9 need their own spawn tokens too: the rebuilt quest issues one per beat, both when the beat opens and again on every level wake while that beat is the live one (docs/aleksej.md, 'the camp is not save data').
    { id = "679a655e-189d-4519-b437-ccc4b92bec8d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bec9d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92becad", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92becbd", tag = "MiscItem", name = "loot_sackOfNails" },
    -- 'beat N's leader is down', Lua -> Skald. See the quest graph: the vanilla SoulDeathTrigger does not bind to a Lua-spawned NPC.
    { id = "679a655e-189d-4519-b437-ccc4b92beccd", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92becdd", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92beced", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92becfd", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bed0d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bed1d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bed2d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bed3d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- 'the document is off his body', Lua -> Skald.
    { id = "679a655e-189d-4519-b437-ccc4b92bed4d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bed5d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bed6d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bed7d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Cast silver. The base game has a full set of raw-silver meshes under metal_industry/silver, built to dress the Royal Silver quest's mint, and never wraps any of them as an item - so this is the first lootable silver in the game. Priced against loot_silverChalice (650 for 0.6 kg, with a craftsman's markup on top), so a plain cake of bullion sits a little under that per kilo.
    { id = "679a655e-189d-4519-b437-ccc4b92bed8d", tag = "MiscItem", name = "merc_alx_silver" },
    -- Kleinkrieg phase markers: token N latches 'the run has reached contract N'.
    { id = "679a655e-189d-4519-b437-ccc4b92be90d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be91d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be92d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be93d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be94d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be95d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be96d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be97d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be98d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be99d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be9ad", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be9bd", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92be9cd", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Signals the END of the whole Kleinkrieg arc (last contract paid).
    { id = "679a655e-189d-4519-b437-ccc4b92be8ed", tag = "MiscItem", name = "loot_sackOfNails" },
    -- The Kleinkrieg story letters (docs/bandit-camp-quest.md). Letter 6 is Raborsch's and arrives with that contract. No IsQuestItem - it blocks inventory:CreateItem, which is how these reach the leader's body.
    { id = "679a655e-189d-4519-b437-ccc4b92be88d", tag = "Document", name = "merc_kk_letter1" },
    { id = "679a655e-189d-4519-b437-ccc4b92be89d", tag = "Document", name = "merc_kk_letter2" },
    { id = "679a655e-189d-4519-b437-ccc4b92be8ad", tag = "Document", name = "merc_kk_letter3" },
    { id = "679a655e-189d-4519-b437-ccc4b92be8bd", tag = "Document", name = "merc_kk_letter4" },
    { id = "679a655e-189d-4519-b437-ccc4b92be8cd", tag = "Document", name = "merc_kk_letter5" },
    { id = "679a655e-189d-4519-b437-ccc4b92be8dd", tag = "Document", name = "merc_kk_letter7" },
    { id = "679a655e-189d-4519-b437-ccc4b92bec0d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bec1d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- The quartermaster's repeatable camp bounty (mercenaries_bounty.lua): accept, 'the camp is standing', 'the camp is cleared', report, paid, then the two dialog gates with a set and a clear token each. Same reusable sack-of-nails shape as the Kleinkrieg tokens above - none of them is ever seen by the player, they are swept back out of the pack a tick after Skald has read them.
    { id = "679a655e-189d-4519-b437-ccc4b92bed9d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bedad", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bedbd", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bedcd", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92beddd", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92beded", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bedfd", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bee0d", tag = "MiscItem", name = "loot_sackOfNails" },
    { id = "679a655e-189d-4519-b437-ccc4b92bee1d", tag = "MiscItem", name = "loot_sackOfNails" },
    -- Reinforced caftans: see docs/outfits.md. A Cuman wears a caftan where a Bohemian wears a gambeson plus a mail shirt, so these carry that armour value themselves and let the Cuman styles hit their tier budget without being dressed as men-at-arms.
    { id = "6d657263-caf7-4a00-9000-000000000001", tag = "Armor", name = "Caftan01_m02_D1_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-000000000002", tag = "Armor", name = "Caftan01_m04_D1_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-000000000003", tag = "Armor", name = "Caftan01_m06_D1_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-000000000004", tag = "Armor", name = "Caftan01_m08_D1_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-000000000005", tag = "Armor", name = "Caftan01_m10_D1_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-000000000006", tag = "Armor", name = "Caftan02_m02_A2_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-000000000007", tag = "Armor", name = "Caftan02_m04_A2_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-000000000008", tag = "Armor", name = "Caftan02_m06_A2_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-000000000009", tag = "Armor", name = "Caftan02_m08_A2_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-00000000000a", tag = "Armor", name = "Caftan02_m10_A2_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-00000000000b", tag = "Armor", name = "Caftan03_m02_C1_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-00000000000c", tag = "Armor", name = "Caftan03_m04_C1_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-00000000000d", tag = "Armor", name = "Caftan03_m06_C1_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-00000000000e", tag = "Armor", name = "Caftan03_m08_C1_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-00000000000f", tag = "Armor", name = "Caftan03_m10_C1_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-000000000010", tag = "Armor", name = "Caftan04_m02_D2_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-000000000011", tag = "Armor", name = "Caftan04_m04_D2_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-000000000012", tag = "Armor", name = "Caftan04_m06_D2_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-000000000013", tag = "Armor", name = "Caftan04_m08_D2_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-000000000014", tag = "Armor", name = "Caftan04_m10_D2_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-000000000015", tag = "Armor", name = "Caftan05_m02_D3_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-000000000016", tag = "Armor", name = "Caftan05_m04_D3_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-000000000017", tag = "Armor", name = "Caftan05_m06_D3_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-000000000018", tag = "Armor", name = "Caftan05_m08_D3_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-000000000019", tag = "Armor", name = "Caftan05_m10_D3_mercRnf" },
    { id = "6d657263-caf7-4a00-9000-00000000001a", tag = "Armor", name = "Caftan05_m12_D3_mercRnf" },
}
