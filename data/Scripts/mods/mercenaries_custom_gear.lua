-- The CUSTOM uniform. The player drops one set of gear into a chest, the mod
-- remembers the item classes, hands the gear straight back and dresses the whole
-- company in copies of it - every tier and the archers too. It is outfit style 7,
-- shown second in the equipment menu right after Generic. See docs/custom-gear.md.

mercenaries.CustomOutfitIndex = 7
mercenaries.GearSaveTag = "MercCustomGear"

-- Skald -> Lua: "I want you to dress this way", top level on both the
-- quartermaster's dialogue and any merc's. It carries no data - it just says the
-- player asked, and Lua puts the wardrobe chest down in front of him.
mercenaries.TokenIDGearOpened = "679a655e-189d-4519-b437-ccc4b92beeed"

-- Per-piece dressing log. Off by default (it is file I/O and it runs once per merc
-- per outfit change); merc_gear_log turns it on when something is not going on.
mercenaries.GearLog = false

-- Squad weapon loadouts used as the base under the custom weapons, picked so
-- whatever the player did NOT hand over still reads consistently: a shield only
-- survives if the custom set has one.
mercenaries.GearBaseWeaponShield   = 2   -- WeaponSets: sword and shield
mercenaries.GearBaseWeaponNoShield = 6   -- WeaponSets: shortsword, no shield

-- "Nothing saved" is a legal pattern: a naked man with a sword.
mercenaries.GearDefaultWeapon = "efa237c7-3905-4813-b9c3-a32b449c17ad"  -- shortswordCommon

-- equipment_slot.xml declares RequiresFilledSlot: a slot refuses everything until
-- the layer beneath it is filled, silently. So a cuirass with no gambeson under it
-- simply does not go on. Rather than let the player's set fail mute, the missing
-- layer is added for him.
mercenaries.GearPrereqSlot = {
    [37] = 36,   -- body_chainmail <- body_cloth_padded
    [38] = 36,   -- body_plate     <- body_cloth_padded
    [39] = 36,   -- sleeves        <- body_cloth_padded
    [42] = 41,   -- leg_armor      <- leg_trousers_padded
    [34] = 32,   -- head_helmet    <- head_coif_padded
    [43] = 30,   -- spur           <- boot
}
-- The bottom layer. Nothing requires these, which is exactly why they were missed:
-- a pattern of harness pieces names no hose, no shirt and sometimes no shoes, the
-- purge then deletes the base preset's, and the man is left with **bare legs** under
-- his leg plate. That is the "one in ten has no pants" report - one in ten, because
-- padded chausses hide it until the one merc whose chausses or leg plate did not take.
--
-- So a pattern that names anything at all gets these underneath it unless it brought
-- its own. They are invisible under armour and cost nothing. A pattern that names
-- NOTHING is left alone: an empty pattern is meant to be a naked man with a sword.
mercenaries.GearBaseFillItem = {
    [35] = "003c862e-e1a9-480b-80b9-be6a2ccf055f",  -- TunicShort05_m09_D, a plain shirt
    [40] = "08d82149-af01-48b6-9e72-b3f000da5e5f",  -- HoseJoined01_m05_C, plain hose
    [30] = "2a169fbe-251a-49f8-85d1-0b9a651f61d1",  -- BootsAnkle03_m01_D
}

-- Plain, cheap, non-quest fillers - they are meant to disappear under the plate.
mercenaries.GearPrereqItem = {
    [36] = "0116b44d-972d-43a1-8a59-dfe40b2ae916",  -- GambesonShort02_m09_E1
    [41] = "50413cc2-f405-44b4-b80e-6150db354bb1",  -- LegsPadded02_m11_E1
    [32] = "039bc3a6-ac77-4e59-a1fa-37c0b4db3b67",  -- CoifSmall02_m07_E1
    [30] = "2a169fbe-251a-49f8-85d1-0b9a651f61d1",  -- BootsAnkle03_m01_D
}

-- Dressing order. Every RequiresFilledSlot pair above has to come out of this list
-- with the prerequisite first; reorder it and mercs end up half dressed with no
-- error anywhere. Items with no slot in the baked table are appended after this list
-- by GearResolveSet, so they always go last.
mercenaries.GearLayerOrder = {
    35, 40, 41, 30, 31, 32, 36, 37, 38, 39, 42, 34, 22, 44, 45, 7, 33, 23, 8, 43, 18, 19
}

-- Horse tack. Recognised so it can be refused with a reason instead of being
-- handed to a man who is not a horse.
mercenaries.GearHorseSlots = { [13] = true, [14] = true, [16] = true, [21] = true }

mercenaries.GearShieldClasses  = { [8] = true, [17] = true }
mercenaries.GearMissileClasses = { [9] = "bow", [10] = "crossbow", [13] = "handcannon",
                                   [14] = "crossbow", [15] = "crossbow" }

mercenaries.GearMaxPieces = 24    -- one man cannot wear more; the rest is a typo
mercenaries.GearDescribeMax = 10  -- how many pieces the on-screen summary names

local function gLog(s) System.LogAlways("[Gear] " .. tostring(s)) end

-- ==== the baked GUID -> slot / weapon-class index ====
-- mercenaries_gear_data.lua ships the table dashless and concatenated; it is
-- unpacked once, on first use, so a session that never touches the wardrobe never
-- pays for it.

mercenaries.GearIndexBuilt = false
mercenaries.GearSlot   = {}
mercenaries.GearWeapon = {}
mercenaries.GearQuest  = {}

local function unpackBlobs(blobs, into, value)
    for _, blob in ipairs(blobs or {}) do
        local n = string.len(blob)
        for i = 1, n, 32 do
            if i + 31 <= n then into[string.sub(blob, i, i + 31)] = value end
        end
    end
end

-- The engine hands class ids back with dashes and in whatever case they were
-- written; the index is keyed dashless and lower case.
function mercenaries:GearKey(cls)
    if not cls then return nil end
    -- The parentheses matter: gsub returns the string AND a count.
    return string.lower((string.gsub(tostring(cls), "%-", "")))
end

function mercenaries:GearDashed(key)
    if not key or string.len(key) ~= 32 then return nil end
    return string.sub(key, 1, 8) .. "-" .. string.sub(key, 9, 12) .. "-" ..
           string.sub(key, 13, 16) .. "-" .. string.sub(key, 17, 20) .. "-" ..
           string.sub(key, 21, 32)
end

function mercenaries:GearBuildIndex()
    if self.GearIndexBuilt then return end
    self.GearIndexBuilt = true
    for slot, blobs in pairs(self.GearSlotBlobs or {}) do
        unpackBlobs(blobs, self.GearSlot, slot)
    end
    for wclass, blobs in pairs(self.GearWeaponBlobs or {}) do
        unpackBlobs(blobs, self.GearWeapon, wclass)
    end
    unpackBlobs(self.GearQuestBlobs, self.GearQuest, true)
end

function mercenaries:GearSlotOf(cls)
    self:GearBuildIndex()
    return self.GearSlot[self:GearKey(cls)]
end

function mercenaries:GearWeaponClassOf(cls)
    self:GearBuildIndex()
    return self.GearWeapon[self:GearKey(cls)]
end

function mercenaries:GearIsQuestItem(cls)
    self:GearBuildIndex()
    return self.GearQuest[self:GearKey(cls)] == true
end

-- A readable label for logs and for the on-screen summary. GetItemUIName takes a
-- CLASS id and returns a localisation key, so it can be fed straight to
-- SendInfoText as an "@key" word (reference_onscreen_number_text).
function mercenaries:GearUIKey(cls)
    local key
    pcall(function() key = ItemManager.GetItemUIName(cls) end)
    if type(key) == "string" and key ~= "" then return key end
    return nil
end

function mercenaries:GearDbName(cls)
    local n
    pcall(function() n = ItemManager.GetItemName(cls) end)
    if type(n) == "string" and n ~= "" then return n end
    return tostring(cls)
end

-- ==== the saved pattern ====

mercenaries.CustomGearSet = nil   -- cached list of class ids, nil = not read yet

function mercenaries:GearLoadState()
    self.CustomGearSet = nil
    -- No chest and no live poll survives a load; clearing the latch is what lets the
    -- next open arm a chain at all.
    self.GearChest, self.GearTickArmed = nil, false
    self.GearKeepList, self.GearKeepIdx = nil, 1
    self:GearLoadSet()
    self:GearArmKeep()
    -- A chest standing at save time comes back with the level but not its handle, so
    -- it would sit there for ever. Emptied into the player and removed.
    pcall(function() self:GearSweepChests() end)
end

function mercenaries:GearLoadSet()
    if self.CustomGearSet then return self.CustomGearSet end
    local list = {}
    local blob = self:LoadString(self.GearSaveTag)
    if blob and blob ~= "" and blob ~= "none" then
        local n = string.len(blob)
        for i = 1, n, 32 do
            if i + 31 <= n then
                local cls = self:GearDashed(string.sub(blob, i, i + 31))
                if cls then list[#list + 1] = cls end
            end
        end
    end
    self.CustomGearSet = list
    return list
end

function mercenaries:GearSaveSet(list)
    local parts = {}
    for _, cls in ipairs(list or {}) do
        local k = self:GearKey(cls)
        if k and string.len(k) == 32 then parts[#parts + 1] = k end
    end
    local blob = table.concat(parts)
    self:SaveString(self.GearSaveTag, (blob ~= "") and blob or "none")
    self.CustomGearSet = list or {}
    gLog("pattern saved: " .. tostring(#self.CustomGearSet) .. " piece(s)")
end

-- Sort the saved pattern into what a merc actually has to be given, with the
-- prerequisite layers filled in. Returns armour (already in dressing order),
-- weapons split by role, and the list of pieces that had to be added.
function mercenaries:GearResolveSet()
    local set = self:GearLoadSet()

    local bySlot, weapons, added, refused, unknown = {}, {}, {}, {}, {}
    for _, cls in ipairs(set) do
        local wclass = self:GearWeaponClassOf(cls)
        if wclass then
            weapons[#weapons + 1] = { cls = cls, wclass = wclass }
        else
            local slot = self:GearSlotOf(cls)
            if slot == nil then
                -- Not in the baked table at all - a modded item, or one added by a
                -- patch newer than the dump. "Unknown" is not a slot: collapsing them
                -- all into bySlot[0] meant the first one won and every other one was
                -- silently refused. Offer them all and let the engine decide.
                unknown[#unknown + 1] = cls
            elseif self.GearHorseSlots[slot] then
                refused[#refused + 1] = cls
            elseif not bySlot[slot] then
                bySlot[slot] = cls          -- one item per slot; first wins
            else
                refused[#refused + 1] = cls
            end
        end
    end

    -- Fill the layers underneath, or the plate silently refuses to go on. Every
    -- prerequisite here is itself a bottom layer (equipment_slot.xml has no deeper
    -- chain), so one pass in any order is enough.
    for slot, need in pairs(self.GearPrereqSlot) do
        if bySlot[slot] and not bySlot[need] then
            local filler = self.GearPrereqItem[need]
            if filler then
                bySlot[need] = filler
                added[#added + 1] = filler
            end
        end
    end

    -- And the bottom layer nothing asks for - shirt, hose, shoes. See GearBaseFillItem:
    -- without these the purge leaves bare legs under the leg plate.
    if #set > 0 then
        for slot, filler in pairs(self.GearBaseFillItem) do
            if not bySlot[slot] then
                bySlot[slot] = filler
                added[#added + 1] = filler
            end
        end
    end

    -- A cap and a padded coif cannot both be worn (head_cap declares
    -- RequiresEmptySlot="head_coif_padded"), and a helmet forces a coif on. The
    -- helmet is the deliberate choice, so the cap is the one that goes. Checked
    -- after the fill above, or an auto-added coif would slip past it.
    if bySlot[32] and bySlot[33] then
        refused[#refused + 1] = bySlot[33]
        bySlot[33] = nil
    end

    local armour = {}
    for _, slot in ipairs(self.GearLayerOrder) do
        if bySlot[slot] then armour[#armour + 1] = { cls = bySlot[slot], slot = slot } end
    end
    -- Unknown slots go last, after every layer whose order is known.
    for _, cls in ipairs(unknown) do armour[#armour + 1] = { cls = cls, slot = 0 } end

    local melee, shield, missile = nil, nil, nil
    for _, w in ipairs(weapons) do
        if self.GearShieldClasses[w.wclass] then
            shield = shield or w.cls
        elseif self.GearMissileClasses[w.wclass] then
            missile = missile or { cls = w.cls, kind = self.GearMissileClasses[w.wclass] }
        else
            melee = melee or w.cls
        end
    end

    return { armour = armour, melee = melee, shield = shield, missile = missile,
             added = added, refused = refused, empty = (#set == 0) }
end

-- ==== dressing one merc ====

-- Put one item on: CreateItem into the pack, FindItem for the instance id,
-- EquipInventoryItem on that. Straight out of AlxWear, which is the only version of
-- this that has ever been proven to work on a runtime-spawned NPC.
local function wearOne(ent, cls)
    if not (ent and ent.inventory and ent.actor and cls) then return false, "no entity" end
    local id
    pcall(function() id = ent.inventory:FindItem(cls) end)
    if not id then
        pcall(function() ent.inventory:CreateItem(cls, 1, 1) end)
        pcall(function() id = ent.inventory:FindItem(cls) end)
    end
    if not id then return false, "not created" end
    local ok = pcall(function() ent.actor:EquipInventoryItem(id) end)
    return ok, ok and "worn" or "equip refused"
end

-- Clothing half. Ends with the merc wearing exactly the saved pattern and nothing
-- else - which, for an empty pattern, means nothing at all.
--
--   1. a clothing preset, always - an NPC that has never worn one accepts CreateItem
--      and then quietly declines every EquipInventoryItem;
--   2. RemoveAllItems - empties the pack, leaves what is WORN worn, so the new pieces
--      have something to replace rather than nothing to sit on;
--   3. the pattern, in layer order;
--   4. take off the slots the pattern does not own;
--   5. AN EMPTY CLOTHING PRESET, to make any of it show.
--
-- Step 5 is the one that is not in any guide, and without it the whole feature looks
-- broken. **EquipInventoryItem changes what an NPC is WEARING but does not rebuild
-- what he LOOKS like.** Two builds of this dressed every merc correctly - the log
-- reported every piece equipped, no refusals - and every one of them stood there
-- naked. The tell was that switching the squad to any ordinary outfit style made the
-- custom armour appear: EquipClothingPreset rebuilds the character, and it does NOT
-- strip slots that are already filled, so the pieces underneath became visible.
--
-- generic_naked is an empty preset (no <Items> at all, clothing_preset.xml), so it is
-- a pure "redraw him as he now is": it cannot add anything and it has nothing to
-- fight the pattern over.
-- The under layers: everything that is itself a prerequisite for something else, or
-- has none of its own. These go on FIRST and, crucially, in a separate pass from the
-- plate that sits on top of them.
mercenaries.GearUnderSlots = {
    [35] = true,   -- body_cloth
    [40] = true,   -- leg_trousers
    [41] = true,   -- leg_trousers_padded
    [30] = true,   -- boot
    [31] = true,   -- head_coif
    [32] = true,   -- head_coif_padded
    [36] = true,   -- body_cloth_padded (the gambeson)
}

-- Pass 1 purges and relays the under layers, passes 2-4 wear the rest. Purging on the
-- first pass rather than a later one also shortens the window in which the man is
-- visibly wearing the base preset instead of the pattern.
mercenaries.GearFinishPasses = 4      -- how many later passes the outer layers get
mercenaries.GearFinishTickMs = 500

-- Which of those passes strips the base preset. It must NOT be the last one.
--
-- It used to be, and that is what "they appear in armour, then a second later the
-- plate comes off and they stand there in gambesons" was. The base preset holds slot
-- 36 (the gambeson) from phase one, the pattern's own gambeson is refused because the
-- slot is taken, and the pattern's cuirass therefore goes on over the BASE gambeson.
-- Deleting that gambeson at the end pulls the cuirass off with it - RequiresFilledSlot
-- is not satisfied any more - and nothing runs afterwards to put it back.
--
-- So the purge goes first: it frees the slots the base preset was squatting on, relays
-- the pattern's own under layers into them, and the passes after it put the plate on
-- top - a pass later, because a plate equipped in the same frame as the gambeson under
-- it is refused without a word.
mercenaries.GearPurgePass = 1

-- Off by default, on purpose. An empty clothing preset applied after the pieces
-- (generic_naked has no <Items> at all, so it can only redraw, never add) was tried in
-- an earlier build as a way to force the character to rebuild, and it did not help -
-- see docs/custom-gear.md. It is kept behind merc_gear_redraw because it costs nothing
-- to try again if a piece is ever equipped-but-invisible.
mercenaries.GearRedraw = false
mercenaries.GearRedrawPreset = "00000000-0000-0000-0000-000000000006"  -- generic_naked

-- The keep loop. A dressed merc does not stay dressed: pieces come off him over a
-- session and the company visibly decays. Nothing here can ask an NPC what he is
-- wearing, so the answer is the same one NPC Dresser reached - keep putting it back
-- on. A few mercs are re-offered the whole pattern every second, round-robin, which
-- works out at the whole company every five or six seconds.
--
-- This is deliberately NOT a re-dress: no base preset, no purge, nothing deleted. It
-- can only ever add a piece that has gone missing, so unlike a full run it cannot
-- itself be the thing that loses one.
-- 5s, not 1s. There is no "is he wearing it" query, so every pass re-equips the WHOLE
-- pattern on GearKeepPerTick mercs blind, and EquipInventoryItem on a KCD2 character is
-- attachment work, not a table write. At 1s with the default budget of 4 that was a dozen
-- or more equips a second, for ever, on any squad wearing the custom uniform - a repair pass
-- running at the cadence of a combat loop. At 5s a twenty-man company is still fully
-- re-asserted about every 25 seconds, which is far inside the time it takes anyone to
-- notice a missing piece. See docs/performance.md.
mercenaries.GearKeepTickMs = 5000
mercenaries.GearKeepPerTick = 4
mercenaries.GearKeepArmed = false
mercenaries.GearKeepSlot = 0
mercenaries.GearKeepList = nil
mercenaries.GearKeepIdx = 1

mercenaries.GearDressing = {}         -- [entity name] = true, waiting for the outer layers
mercenaries.GearFinishArmed = false
mercenaries.GearFinishPass = 0

-- Clothing half, phase one: the base preset and the under layers only.
--
-- The outer layers are deliberately NOT done here. `equipment_slot.xml` declares
-- RequiresFilledSlot, and the engine does not see the gambeson as filled in the same
-- frame it was equipped in - a cuirass equipped straight after it is refused, without
-- a word. That is exactly what the last build looked like in game: gambeson, coif and
-- hose on, plate nowhere. Two passes in the same frame did not help, because the frame
-- is the problem. GearFinishTick does the rest a few hundred milliseconds later.
function mercenaries:GearApplyArmour(ent)
    if not (ent and ent.actor) then return end
    local plan = self:GearResolveSet()
    local name = tostring(ent:GetName())
    local n0 = self:GearCountItems(ent)

    -- The base is the merc's OWN generic preset for his tier: known-good, known to
    -- render, and it means a fresh hire whose first outfit is Custom has had a preset
    -- applied at least once (without that, an NPC accepts CreateItem and then quietly
    -- declines every EquipInventoryItem).
    --
    -- Which one is ROLLED, and the roll is the only thing that differs between two
    -- mercs dressed in the same tick - so it is recorded against the merc's name. If
    -- one man in a squad comes out wrong and the other nine do not, this is the only
    -- line that can say what was different about him.
    local tier = self:GearTierOf(ent)
    local pool = (self.Outfits[1] or {})[tier] or (self.Outfits[1] or {})["weak"]
    local base = nil
    if pool and #pool > 0 then
        base = pool[math.random(1, #pool)]
        pcall(function() ent.actor:EquipClothingPreset(base) end)
    end

    local under = 0
    for _, piece in ipairs(plan.armour) do
        if self.GearUnderSlots[piece.slot] and not self:GearIsQuestItem(piece.cls) then
            if wearOne(ent, piece.cls) then under = under + 1 end
        end
    end

    self.GearDressing[name] = base or true
    self:GearArmFinish()

    if self.GearLog then
        gLog(string.format("%s: phase 1, %d under layer(s), items %d -> %d",
                           name, under, n0, self:GearCountItems(ent)))
    end
end

-- GearKeepArmed is cleared per load (see TimerLatches), so this can arm once per load. The
-- slot is what makes that safe: it names the entry point, so the previous load's chain - if
-- the engine kept it - retires on its next firing instead of running alongside this one.
-- Same device as LootSweepArm; the reasoning is written out there.
function mercenaries:GearArmKeep()
    if self.GearKeepArmed then return end
    self.GearKeepArmed = true
    self.GearKeepSlot  = 1 - (self.GearKeepSlot or 0)
    Script.SetTimerForFunction(self.GearKeepTickMs, "mercenaries.GearKeepTick" .. self.GearKeepSlot)
end

function mercenaries.GearKeepTick0() mercenaries.GearKeepBeat(0) end
function mercenaries.GearKeepTick1() mercenaries.GearKeepBeat(1) end

function mercenaries.GearKeepBeat(slot)
    local self = mercenaries
    if not self.GearKeepArmed or self.GearKeepSlot ~= slot then return end
    -- Re-armed first and unconditionally: this loop has to survive the squad being off
    -- the custom uniform for a while and come back when it returns
    -- (reference_settimerforfunction_third_arg).
    Script.SetTimerForFunction(self.GearKeepTickMs, "mercenaries.GearKeepTick" .. slot)

    if (_G.MercCurrentOutfit or 1) ~= self.CustomOutfitIndex then return end
    if next(self.GearDressing) ~= nil then return end   -- a full run is mid-flight

    local plan = self:GearResolveSet()
    if #plan.armour == 0 then return end

    -- One list per sweep, indexed rather than walked with next(): ActiveMercs changes
    -- under us as men are hired and killed, and a stale key is an error in next().
    if not self.GearKeepList or self.GearKeepIdx > #self.GearKeepList then
        self.GearKeepList, self.GearKeepIdx = {}, 1
        for nm in pairs(self.ActiveMercs) do
            self.GearKeepList[#self.GearKeepList + 1] = nm
        end
    end

    for _ = 1, self.GearKeepPerTick do
        local nm = self.GearKeepList[self.GearKeepIdx]
        if not nm then break end
        self.GearKeepIdx = self.GearKeepIdx + 1
        local ent = self.ActiveMercs[nm]
        if ent and ent.actor and ent.inventory and self:GearWantsCustom(ent, nil) then
            for _, piece in ipairs(plan.armour) do
                if not self:GearIsQuestItem(piece.cls) then wearOne(ent, piece.cls) end
            end
        end
    end
end

function mercenaries:GearArmFinish()
    self.GearFinishPass = 0
    if self.GearFinishArmed then return end
    self.GearFinishArmed = true
    Script.SetTimerForFunction(self.GearFinishTickMs, "mercenaries.GearFinishTick")
end

-- Phase two, and three, and four. Every pass re-equips the WHOLE pattern in layer
-- order: re-equipping something already worn is harmless, and it is the only way to
-- catch a layer that was refused last time because the one under it had not settled
-- yet. There is no "is it worn" query to be cleverer with.
--
-- The passes are not interchangeable. GearPurgePass strips the base preset, and at
-- least one wear pass has to come after it - see the note there.
function mercenaries.GearFinishTick()
    local self = mercenaries
    if not self.GearFinishArmed then return end

    self.GearFinishPass = self.GearFinishPass + 1
    local purging = (self.GearFinishPass == self.GearPurgePass)
    local last    = (self.GearFinishPass >= self.GearFinishPasses)
    if not last then
        Script.SetTimerForFunction(self.GearFinishTickMs, "mercenaries.GearFinishTick")
    else
        self.GearFinishArmed = false
    end

    local plan = self:GearResolveSet()
    local keep = {}
    for _, piece in ipairs(plan.armour) do keep[self:GearKey(piece.cls)] = true end

    -- Once per dressing run, not per merc: the slots the pattern actually owns. A slot
    -- missing from this line is a slot nobody will be wearing anything in once the base
    -- preset has been stripped, which is the difference between "it did not equip" and
    -- "it was never in the pattern".
    if purging then
        local slots = {}
        for _, piece in ipairs(plan.armour) do slots[#slots + 1] = tostring(piece.slot) end
        gLog("pattern slots: " .. table.concat(slots, " ") ..
             (#plan.refused > 0 and ("  refused " .. #plan.refused) or ""))
    end

    for name, base in pairs(self.GearDressing) do
        -- By name, not by handle: ActiveMercs does not hold the tower archers, and a
        -- handle kept across half a second is a handle to something that may be gone.
        local ent = self.ActiveMercs[name]
        if not ent then pcall(function() ent = System.GetEntityByName(name) end) end
        if ent and ent.actor and ent.inventory then
            -- Strip first on the purge pass: the slots the base preset is holding have
            -- to be free BEFORE the pattern is offered for them, or the pattern's own
            -- layer is refused and the plate ends up sitting on gear that is about to
            -- be deleted underneath it.
            local purged = 0
            if purging then purged = self:GearPurgeArmour(ent, keep) end

            -- The purge pass re-runs phase one, and for the same reason: the slots it
            -- just emptied need the pattern's OWN under layers in them, and a plate
            -- equipped in the same frame as the gambeson beneath it is refused without
            -- a word. So the under layers go on here and the plate waits a pass.
            local failed = {}
            for _, piece in ipairs(plan.armour) do
                local skip = purging and not self.GearUnderSlots[piece.slot]
                if skip then                                     -- not this pass
                elseif self:GearIsQuestItem(piece.cls) then
                    failed[#failed + 1] = piece
                elseif not wearOne(ent, piece.cls) then
                    failed[#failed + 1] = piece
                end
            end

            if last and self.GearRedraw then
                pcall(function() ent.actor:EquipClothingPreset(self.GearRedrawPreset) end)
            end

            if purging then
                gLog(string.format("%s: pass %d purged %d, under layers relaid, items %d, base %s",
                                   name, self.GearFinishPass, purged,
                                   self:GearCountItems(ent), tostring(base)))
            elseif last then
                local names = {}
                for _, piece in ipairs(failed) do
                    names[#names + 1] = piece.slot .. ":" .. self:GearDbName(piece.cls)
                end
                gLog(string.format("%s: pass %d, %d/%d piece(s), items %d%s",
                                   name, self.GearFinishPass,
                                   #plan.armour - #failed, #plan.armour,
                                   self:GearCountItems(ent),
                                   (#names > 0) and (", missed " .. table.concat(names, " ")) or ""))
            end
        end
    end

    if last then self.GearDressing = {} end
end

-- Take the armour the pattern does not name off, and DELETE it.
--
-- Unequipping alone is not enough and never was: the item count did not move across a
-- strip (23 -> 23 in the log), the men came back wearing a mash-up of the new livery
-- and the old pieces whenever an outfit was applied over them, and no call in the
-- scriptbind will say whether something is worn. Destroying the instance is the only
-- state change here that cannot be quietly ignored.
--
-- Weapons are left alone - GearApplyWeapons runs after this and a deleted sword would
-- be a disarmed merc.
function mercenaries:GearPurgeArmour(ent, keep)
    if not (ent and ent.inventory) then return 0 end
    local t
    pcall(function() t = ent.inventory:GetInventoryTable() end)
    if type(t) ~= "table" then return 0 end

    local doomed = {}
    for _, handle in pairs(t) do
        local it
        pcall(function() it = ItemManager.GetItem(handle) end)
        local cls = type(it) == "table" and it.class or nil
        if cls and self:GearSlotOf(cls) ~= nil then          -- armour only
            local key = self:GearKey(cls)
            if not (keep and keep[key]) then doomed[key] = cls end
        end
    end

    local n = 0
    for _, cls in pairs(doomed) do
        pcall(function()
            local id = ent.inventory:FindItem(cls)
            if id then ent.actor:UnequipInventoryItem(id) end
        end)
        pcall(function() ent.inventory:DeleteItemOfClass(cls, 99) end)
        n = n + 1
    end
    return n
end

-- The other half of the same guarantee: when the company is NOT on the custom uniform,
-- the custom pieces must not be on anybody. Applying an ordinary preset over them does
-- not do it - that is what the mash-up was - so they are deleted outright. They were
-- only ever copies (inventory:CreateItem), so nothing of the player's is lost.
-- Put a named companion back in his own gear, if some earlier build of this left him
-- in the company uniform. Cheap when there is nothing to do - one FindItem per pattern
-- piece and out - which is what it will be every time after the first.
function mercenaries:GearHeroRestore(ent)
    if not (ent and ent.inventory and ent.actor) then return end
    local dressed = false
    for _, cls in ipairs(self:GearLoadSet()) do
        local id
        pcall(function() id = ent.inventory:FindItem(cls) end)
        if id then dressed = true; break end
    end
    if not dressed then return end

    self:GearRemoveCustom(ent)
    -- A preset does not take off what is already worn, so the removal above has to
    -- happen first or this just layers his own kit over the pattern.
    pcall(function()
        local own = ent.actor:GetInitialClothingPreset()
        if own and own ~= "" then ent.actor:EquipClothingPreset(own) end
    end)
    pcall(function()
        local own = ent.actor:GetInitialWeaponPreset()
        if own and own ~= "" then ent.actor:EquipWeaponPreset(own) end
    end)
    gLog(tostring(ent:GetName()) .. ": named companion, put back in his own gear")
end

function mercenaries:GearRemoveCustom(ent)
    if not (ent and ent.inventory) then return end
    self.GearDressing[tostring(ent:GetName())] = nil
    local function drop(cls)
        pcall(function()
            local id = ent.inventory:FindItem(cls)
            if id and ent.actor then ent.actor:UnequipInventoryItem(id) end
        end)
        pcall(function() ent.inventory:DeleteItemOfClass(cls, 99) end)
    end
    for _, cls in ipairs(self:GearLoadSet()) do drop(cls) end
    for _, cls in pairs(self.GearPrereqItem) do drop(cls) end
    drop(self.GearDefaultWeapon)
end

-- How many item instances this entity holds. The only cheap, honest measure of what
-- the dressing calls are actually doing - see the log line in GearApplyArmour.
function mercenaries:GearCountItems(ent)
    local t, n = nil, 0
    pcall(function() t = ent.inventory:GetInventoryTable() end)
    if type(t) ~= "table" then return -1 end
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- Weapon half. The preset goes on first so the engine has a populated weapon set
-- to draw from (an empty set kills combat_melee at the draw), then the player's
-- own weapons are worn over the top of it.
function mercenaries:GearApplyWeapons(ent, isArcher)
    if not (ent and ent.actor) then return end
    local plan = self:GearResolveSet()

    if isArcher then
        -- Archers keep a working missile set no matter what the pattern holds:
        -- their combat trees fail outright without one.
        local weaponType = plan.missile and plan.missile.kind or self:GetArcherWeaponType()
        local sets = self.ArcherWeaponSets[weaponType] or self.ArcherWeaponSets["bow"] or {}
        if #sets > 0 then
            local presetId = sets[math.random(1, #sets)]
            if presetId ~= "" then
                pcall(function() ent.actor:EquipWeaponPreset(presetId) end)
            end
        end
        if plan.missile then wearOne(ent, plan.missile.cls) end
        self:GiveArcherAmmo(ent, weaponType, 40)
    else
        local base = plan.shield and self.GearBaseWeaponShield or self.GearBaseWeaponNoShield
        local tier = self:GearTierOf(ent)
        local pool = (self.WeaponSets[base] or {})[tier] or (self.WeaponSets[base] or {})["weak"]
        if pool and #pool > 0 then
            local presetId = pool[math.random(1, #pool)]
            pcall(function() ent.actor:EquipWeaponPreset(presetId) end)
        end
        -- A bow on a man whose brain is combat_melee is the player's choice, but he
        -- keeps the preset's sword underneath so he can still fight.
        if plan.missile then
            wearOne(ent, plan.missile.cls)
            self:GiveArcherAmmo(ent, plan.missile.kind, 40)
        end
    end

    -- A pattern with no weapon in it is still a pattern: a naked man with a sword.
    -- Only fall back to that when nothing at all was named - a pattern that names a
    -- bow and no sword should not quietly grow one.
    local melee = plan.melee
    if not melee and not plan.missile and not isArcher then melee = self.GearDefaultWeapon end
    if melee then wearOne(ent, melee) end
    if plan.shield then wearOne(ent, plan.shield) end
end

function mercenaries:GearTierOf(ent)
    local name = (ent and ent:GetName()) or ''
    if string.find(name, '_strong_') then return "strong" end
    if string.find(name, '_medium_') then return "medium" end
    return "weak"
end

-- Is this entity one the custom uniform applies to? The outfit index is normally
-- proof enough, but EquipMercenaryWeapon is called for enemies with no outfit at
-- all and falls back to the squad's - which would put the player's own uniform on
-- the men fighting him.
function mercenaries:GearWantsCustom(ent, outfitPreset)
    -- Named companions are out of this entirely: they wear their own character's gear
    -- through every style. Checked before the index, because the index alone would
    -- sweep them in through ChangeMercOutfit and the keep loop alike.
    if self:IsHero(ent) then return false end
    if outfitPreset == self.CustomOutfitIndex then return true end
    if outfitPreset ~= nil then return false end
    if (_G.MercCurrentOutfit or 1) ~= self.CustomOutfitIndex then return false end
    local name = (ent and ent:GetName()) or ''
    if string.find(name, 'SpawnedEnemy') or string.find(name, 'SpawnedFoe') then return false end
    -- Named companions carry the SpawnedFriend_ prefix so they get every other squad
    -- system for free, but the company uniform is not theirs: they wear what their own
    -- character wears.
    if self:IsHeroName(name) then return false end
    return string.find(name, 'SpawnedFriend') ~= nil
        or string.find(name, self.StaticArcherNamePrefix or 'SpawnedTower_archer_', 1, true) == 1
end

-- ==== reading an inventory ====

-- GetInventoryTable hands back item INSTANCES; ItemManager.GetItem turns one into
-- a class id. Neither is used anywhere else in this mod, so both are guarded and
-- there is a slower route below for the build where they are not. Returns the list
-- and whether the fast route actually worked - an EMPTY inventory is a real answer
-- and must not send the caller off to scan 2700 classes for nothing.
function mercenaries:GearReadInventory(inv)
    local out, seen, entries = {}, {}, 0
    local t
    pcall(function() t = inv:GetInventoryTable() end)
    if type(t) ~= "table" then return nil, false end
    for _, handle in pairs(t) do
        entries = entries + 1
        local it
        pcall(function() it = ItemManager.GetItem(handle) end)
        if type(it) == "table" and it.class then
            local k = self:GearKey(it.class)
            if k and not seen[k] then
                seen[k] = true
                out[#out + 1] = { cls = it.class, amount = it.amount or 1 }
            end
        end
    end
    -- Entries that no class could be read from mean GetItem is not doing its job.
    return out, (entries == 0) or (#out > 0)
end

-- Fallback: ask for a count of every gear class the index knows about. ~2700
-- lookups, one-shot, only when GetInventoryTable/GetItem produced nothing.
function mercenaries:GearScanInventory(inv)
    self:GearBuildIndex()
    local out = {}
    local function probe(map)
        for key in pairs(map) do
            local cls = self:GearDashed(key)
            local n = 0
            pcall(function() n = inv:GetCountOfClass(cls) or 0 end)
            if n > 0 then out[#out + 1] = { cls = cls, amount = n } end
        end
    end
    probe(self.GearSlot)
    probe(self.GearWeapon)
    return out
end

function mercenaries:GearContentsOf(inv, noScan)
    if not inv then return {} end
    local list, ok = self:GearReadInventory(inv)
    if ok then return list end
    if noScan then return list or {} end
    gLog("GetInventoryTable/GetItem gave nothing - falling back to a class scan")
    return self:GearScanInventory(inv)
end

-- ==== the wardrobe chest ====
-- The player is shown a chest, puts a set of gear in it, and the mod reads the
-- classes back off it and hands the gear straight back the same tick. The men wear
-- COPIES, so nothing the player owns is ever spent describing them.
--
-- This used to be a Skald ItemDelivery panel pointed at the quartermaster, the way
-- the food and drink panels are. Two things killed that: the panel hangs off a
-- ForEach over his soul, so it did nothing at all without a camp standing, and the
-- gear went into a live NPC's inventory where getting it back out depended on a
-- MoveItemOfClass round trip that did not survive contact. A Stash is spawned by this
-- mod in seven other places, always works, needs no camp and no NPC, and if anything
-- ever does go wrong the failure is "your gear is in that chest" rather than "your
-- gear is gone".

mercenaries.GearChestName   = "MercWardrobeChest"
mercenaries.GearChestModel  = "Objects/characters/assets/chest/chest_rustic_a.cdf"
mercenaries.GearChestTickMs = 1000
-- Nothing tells Lua that the transfer window has been closed, so "the transaction is
-- over" is read off the chest itself: this many seconds with its contents unchanged.
-- Generous, because the cost of being wrong is a player who was still deciding
-- getting his gear handed back mid-thought. The chest keeps polling afterwards, so
-- carrying on where he left off just works.
mercenaries.GearChestSettle = 5
mercenaries.GearChestLife = 180        -- quiet ticks before the chest packs itself away

-- 100 m straight down. It is never meant to be walked up to and opened - the transfer
-- window is opened for the player by OpenItemTransferStore, and the log confirms the
-- panel comes up from down there - so putting it underfoot only left a chest lying
-- about in the world.
mercenaries.GearChestDepth = 100.0

mercenaries.GearChest = nil            -- { id, base, sig, idle, ticks }

-- Which one thing in the pattern this class would be. Armour answers with a slot,
-- weapons with a role, and the pattern holds one of each: that is what makes a second
-- visit with a pair of hose ADD hose, and a second helmet REPLACE the first.
function mercenaries:GearRoleOf(cls)
    local wclass = self:GearWeaponClassOf(cls)
    if not wclass then return nil, (self:GearSlotOf(cls) or 0) end
    if self.GearShieldClasses[wclass] then return "shield" end
    if self.GearMissileClasses[wclass] then return "missile" end
    return "melee"
end

function mercenaries:GearFold(list, cls)
    local role, slot = self:GearRoleOf(cls)
    if slot and self.GearHorseSlots[slot] then return false, "horse tack" end
    if self:GearIsQuestItem(cls) then return false, "quest item, cannot be copied" end
    for i = #list, 1, -1 do
        local oRole, oSlot = self:GearRoleOf(list[i])
        if (role and oRole == role) or (slot and oSlot == slot) then
            table.remove(list, i)
        end
    end
    if #list >= self.GearMaxPieces then return false, "pattern full" end
    list[#list + 1] = cls
    return true, "taken"
end

function mercenaries:GearChestEntity()
    local C = self.GearChest
    if not C then return nil end
    local e
    pcall(function() e = System.GetEntity(C.id) end)
    return e
end

-- Called off the dialogue token, from the quartermaster or from any merc. Needs
-- nothing but a player standing on the ground.
function mercenaries:GearOpenWardrobe()
    self:GearCloseWardrobe(true)   -- one chest at a time

    local pos, dir
    pcall(function()
        pos = player:GetWorldPos()
        dir = player:GetDirectionVector()
    end)
    if not (pos and dir) then return end

    local at = { x = pos.x, y = pos.y, z = pos.z - self.GearChestDepth }
    -- Facing the player. SpawnEntity's `orientation` is a DIRECTION VECTOR, not Euler
    -- angles, so the yaw is set again afterwards (reference_camp_inn_tavern).
    local yaw = math.atan2(-dir.y, -dir.x)
    local name = self.GearChestName .. "_" .. tostring(math.random(100000, 999999))

    local e
    pcall(function()
        e = System.SpawnEntity({
            class = "Stash", name = name, position = at,
            orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
            properties = { object_Model = self.GearChestModel,
                           sWH_AI_EntityCategory = "Chest",
                           -- Saved WITH the game on purpose: the gear now waits in the
                           -- chest until the transaction ends, so a quicksave in the
                           -- middle of one must not take it with the entity.
                           -- GearSweepChests empties and removes it on the next load.
                           bSaved_by_game = 1,
                           bSerialize = 1,
                           bSkipAngleCheck = true },
        })
    end)
    if not e then
        gLog("wardrobe chest failed to spawn")
        Game.SendInfoText('merc_info_gear_nochest', false, 0, 4)
        return
    end
    pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw }) end)

    -- `base` is the pattern as it stood before this chest was opened. Every tick
    -- rebuilds the pattern as base + whatever is in the chest right now, so taking a
    -- piece back OUT drops it again, while a second visit still adds to the harness
    -- rather than replacing it. It has to be a copy: GearSaveSet keeps the list it is
    -- handed as the live cache.
    local base = {}
    for _, cls in ipairs(self:GearLoadSet()) do base[#base + 1] = cls end
    self.GearChest = { id = e.id, base = base, sig = nil, idle = 0, ticks = 0 }
    gLog("wardrobe chest open, " .. self.GearChestDepth .. "m down, holding " .. #base .. " piece(s)")
    Game.SendInfoText('merc_info_gear_chest', false, 0, 6)

    pcall(function()
        player.actor:OpenItemTransferStore(e.id, e.inventory:GetId(),
                                           "armor.*.*|weapon.*.*", "Inventory")
    end)

    if not self.GearTickArmed then
        self.GearTickArmed = true
        Script.SetTimerForFunction(self.GearChestTickMs, "mercenaries.GearWardrobeTick")
    end
end

-- Empty the chest back into the player's pack. Returns how much is STILL in there, so
-- the caller can refuse to delete a chest that is holding somebody's harness.
function mercenaries:GearEmptyChest(e)
    if not (e and e.inventory) then return 0 end
    local left = 0
    for _, entry in ipairs(self:GearContentsOf(e.inventory, true)) do
        local n = entry.amount or 1
        pcall(function()
            e.inventory:MoveItemOfClass(player.inventory:GetId(), entry.cls, n, true)
        end)
        -- Whatever the move reported, the truth is what the chest still holds.
        local still = 0
        pcall(function() still = e.inventory:GetCountOfClass(entry.cls) or 0 end)
        if still > 0 then
            pcall(function() e.inventory:DeleteItemOfClass(entry.cls, still) end)
            pcall(function() player.inventory:CreateItem(entry.cls, 1, still) end)
            pcall(function() still = e.inventory:GetCountOfClass(entry.cls) or 0 end)
        end
        left = left + still
    end
    return left
end

function mercenaries:GearCloseWardrobe(silent)
    local C = self.GearChest
    self.GearChest = nil
    if not C then
        self:GearSweepChests()   -- a chest from a previous session that lost its handle
        return
    end
    local e
    pcall(function() e = System.GetEntity(C.id) end)
    if not e then return end
    local left = self:GearEmptyChest(e)
    if left > 0 then
        -- Never delete gear. The chest stays where it is and the player is told.
        gLog("wardrobe chest still holds " .. left .. " item(s) - leaving it standing")
        if not silent then Game.SendInfoText('merc_info_gear_chest_left', false, 0, 5) end
        return
    end
    pcall(function() System.RemoveEntity(C.id) end)
end

function mercenaries:GearSweepChests()
    local all
    pcall(function() all = System.GetEntitiesByClass("Stash") end)
    for _, e in ipairs(all or {}) do
        local nm = e and e:GetName()
        if nm and string.find(nm, self.GearChestName, 1, true) == 1 then
            if self:GearEmptyChest(e) == 0 then
                pcall(function() System.RemoveEntity(e.id) end)
            end
        end
    end
end

-- Self-arming poll. There is exactly one chain, ever: GearTickArmed is the latch, so
-- opening a second chest cannot leave two timers ticking the same one. The only exit
-- is a chest that is gone, and it drops the latch on the way out so the next open can
-- arm a fresh chain (a dead chain that nothing can restart is the failure mode
-- reference_settimerforfunction_third_arg is about).
--
-- The transaction is over when the chest has stopped changing. Until then the gear
-- stays in it, untouched: the pattern is only saved, the men only re-dressed and the
-- gear only handed back once the player has finished moving things about.
function mercenaries.GearWardrobeTick()
    local self = mercenaries
    local C = self.GearChest
    if not C then self.GearTickArmed = false; return end
    Script.SetTimerForFunction(self.GearChestTickMs, "mercenaries.GearWardrobeTick")

    C.ticks = C.ticks + 1
    local e = self:GearChestEntity()
    if not e then self.GearChest = nil; return end

    -- What the pattern would be right now: what it was before this chest was opened,
    -- plus everything currently in it. Rebuilt from scratch every tick, so taking a
    -- piece back out of the chest takes it out of the pattern again.
    local contents = self:GearContentsOf(e.inventory, true)
    local list, sig = {}, {}
    for _, cls in ipairs(C.base) do list[#list + 1] = cls end
    for _, entry in ipairs(contents) do
        sig[#sig + 1] = tostring(self:GearKey(entry.cls)) .. "x" .. tostring(entry.amount or 1)
        if (self:GearSlotOf(entry.cls) ~= nil) or (self:GearWeaponClassOf(entry.cls) ~= nil) then
            local ok, why = self:GearFold(list, entry.cls)
            if self.GearLog or not ok then
                gLog("  " .. self:GearDbName(entry.cls) .. ": " .. tostring(why))
            end
        end
    end
    table.sort(sig)
    sig = table.concat(sig, ";")

    if sig ~= C.sig then
        -- Still moving things. Note where we are and wait.
        C.sig, C.idle, C.pending = sig, 0, list
        return
    end

    C.idle = C.idle + 1
    if C.idle ~= self.GearChestSettle then
        if C.idle >= self.GearChestLife then self:GearCloseWardrobe(false) end
        return
    end

    -- Settled: this is the end of the transaction. Exactly once, on the tick the
    -- counter reaches the settle mark.
    if sig == "" then return end          -- nothing was put in; nothing to do

    self:GearSaveSet(C.pending or list)
    C.base = {}
    for _, cls in ipairs(self:GearLoadSet()) do C.base[#C.base + 1] = cls end

    local left = self:GearEmptyChest(e)
    C.sig = ""                            -- the chest is empty now; do not re-trigger
    if left > 0 then
        gLog("could not hand back " .. left .. " item(s) - they are still in the chest")
        Game.SendInfoText('merc_info_gear_chest_left', false, 0, 5)
    end

    self:ChangeMercOutfit(self.CustomOutfitIndex, false)
    self:GearDescribe()
end

-- ==== reporting ====

-- Every word of a SendInfoText line has to be a localisation key, so the summary
-- is built out of the items' own UIName keys (reference_onscreen_number_text).
function mercenaries:GearDescribe()
    local plan = self:GearResolveSet()
    if plan.empty then
        Game.SendInfoText('merc_info_gear_empty', false, 0, 4)
        return
    end
    local words = { 'merc_info_gear_now' }
    local function add(cls)
        if cls and #words <= self.GearDescribeMax then
            words[#words + 1] = self:GearUIKey(cls) or 'merc_info_gear_piece'
        end
    end
    -- Weapons first: they are the half of the pattern a player is most likely to be
    -- checking, and a long harness would otherwise push them off the end.
    add(plan.melee)
    add(plan.shield)
    add(plan.missile and plan.missile.cls)
    for _, piece in ipairs(plan.armour) do add(piece.cls) end
    Game.SendInfoText('@' .. table.concat(words, ' @'), false, 0, 6)
end

-- ==== console ====

function mercenaries:GearDump()
    local plan = self:GearResolveSet()
    gLog("custom uniform: " .. (plan.empty and "EMPTY (naked, plain sword)" or (#plan.armour .. " piece(s)")))
    for _, piece in ipairs(plan.armour) do
        gLog(string.format("  slot %-3d %s", piece.slot, self:GearDbName(piece.cls)))
    end
    if plan.melee   then gLog("  melee   " .. self:GearDbName(plan.melee)) end
    if plan.shield  then gLog("  shield  " .. self:GearDbName(plan.shield)) end
    if plan.missile then gLog("  missile " .. self:GearDbName(plan.missile.cls) .. " (" .. plan.missile.kind .. ")") end
    for _, cls in ipairs(plan.added)   do gLog("  added   " .. self:GearDbName(cls)) end
    for _, cls in ipairs(plan.refused) do gLog("  refused " .. self:GearDbName(cls)) end
end

function mercenaries:GearClear()
    self:GearSaveSet({})
    if (_G.MercCurrentOutfit or 1) == self.CustomOutfitIndex then
        self:ChangeMercOutfit(self.CustomOutfitIndex, true)
    end
    gLog("custom uniform cleared")
end

mercenaries:DevCommand("merc_gear_dump",  "mercenaries:GearDump()",
                   "Log the saved custom uniform, layer by layer")
mercenaries:DevCommand("merc_gear_log",   "mercenaries.GearLog = not mercenaries.GearLog",
                   "Toggle the per-piece dressing log (off by default: it is file I/O)")
mercenaries:DevCommand("merc_gear_redraw", "mercenaries.GearRedraw = not mercenaries.GearRedraw",
                   "Toggle the empty-preset redraw at the end of dressing (on by default)")
