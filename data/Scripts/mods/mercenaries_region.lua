-- Crossing between Trosky and Kuttenberg. See docs/regions.md.
--
-- The two regions are separate LEVELS. Everything the mod spawns belongs to the level it
-- was spawned in - the men, the camp props, the walls and towers, and the hidden saver
-- entities that carry every persisted tag - so on arriving in the other region the mod
-- reads a blank state and tells the player he has no company. Lua tables survive the level
-- change (the base game itself relies on that: SinglePlayer.lua stashes a game token in a
-- Lua global across EndLevel/OnStartLevel), so the company is carried over in memory and
-- re-materialised on the other side. The camp and its defences stay where they were built.

mercenaries.RegionEnabled     = true
mercenaries.RegionMaxDayGap   = 2.0     -- world-days a crossing may advance the clock
mercenaries.RegionStampGrain  = 3600    -- world-seconds the freshness stamp is rounded to
mercenaries.RegionSpawnBatch  = 4       -- men re-spawned per step
mercenaries.RegionSpawnStepMs = 250
mercenaries.RegionRestoreMs   = 3000    -- after RebuildMercCacheDelayed (2s) has run
mercenaries.RegionAnchorTries = 20      -- spawn-position retries before the carry is dropped

mercenaries.RegionCarry      = nil      -- { tags = {...}, men = {...}, when = <world time> }
mercenaries.RegionSpawnQueue = {}

local function rLog(s) System.LogAlways("[Region] " .. tostring(s)) end

-- Tags that belong to a PLACE, not to the company: a camp is pitched on a spot in one
-- region and its walls, gates and towers stand on that spot. They are left behind rather
-- than carried, so the camp is still there when the player travels back.
mercenaries.RegionPlaceTags = {
    MercCampActive = true, MercCampX = true, MercCampY = true, MercCampZ = true,
    MercCampAng = true, MercCampTiles = true, MercOutParty = true,
    QMDefX = true, QMDefY = true, QMWallPts = true, QMWallClosed = true,
    QMWallType = true, QMGates = true, QMTowers = true, QMCarts = true,
    QMRoutes = true, BCampLayout = true, EditorOwner = true,
}

-- ...and tag prefixes that are region-pinned or dev-only for the same reason (Aleksej
-- lodges in Kuttenberg; the torture harness is a test rig).
mercenaries.RegionPlacePrefixes = { "Alx", "Torture" }

function mercenaries:RegionTagTravels(tag)
    if self.RegionPlaceTags[tag] then return false end
    for _, p in ipairs(self.RegionPlacePrefixes) do
        if string.sub(tag, 1, #p) == p then return false end
    end
    return true
end

-- ==== the freshness stamp ====
-- Which side holds the newer picture of the company. Rounded to the hour so the tag is
-- rewritten every few real minutes rather than every tick - a rewrite respawns its saver
-- entity, and that churn is what SaveStrings exists to avoid.
function mercenaries:RegionStamp()
    local t = self:LogiNow()
    if t <= 0 then return nil end
    return math.floor(t / self.RegionStampGrain) * self.RegionStampGrain
end

function mercenaries:RegionTick()
    if not self.RegionEnabled then return end
    local s = self:RegionStamp()
    if s then self:SaveString("MercStateWhen", tostring(s)) end
end

-- ==== capture, before the level being left is forgotten ====
-- Called at the top of OnGameplayStarted, BEFORE SaverForget drops the tag map: at that
-- moment SaverValues and ActiveMercs still describe the level just left. Only the merc
-- NAMES are read - the entity handles are already dead.
function mercenaries:RegionCaptureTags()
    if not self.RegionEnabled then return end
    if not self.SaverMapped then return end

    local tags, n = {}, 0
    for k, v in pairs(self.SaverValues or {}) do tags[k] = v; n = n + 1 end
    if n == 0 then return end

    local men = {}
    for name in pairs(self.ActiveMercs or {}) do table.insert(men, name) end

    self.RegionCarry = { tags = tags, men = men, when = tonumber(tags.MercStateWhen or "") or 0 }
    rLog("carrying " .. n .. " tag(s) and " .. #men .. " man/men out of the level being left")
end

-- ==== decide, on the level arrived in ====
function mercenaries:RegionOnLoad()
    self.RegionCrossed = false
    self.RegionSpawnQueue = {}
    local carry = self.RegionCarry
    if not (self.RegionEnabled and carry) then return end

    self:SaverMap()
    local here = 0
    for _ in pairs(self.SaverValues or {}) do here = here + 1 end

    -- A crossing carries the world clock FORWARD by the travel time. Loading an unrelated
    -- save is the one thing that looks like a crossing from in here, and it moves the
    -- clock somewhere else entirely - so the clock is the identity check.
    local now = self:LogiNow()
    local gap = (now - (carry.when or 0)) / self.SecondsPerDay
    if now <= 0 or (carry.when or 0) <= 0 or gap < 0 or gap > self.RegionMaxDayGap then
        rLog(string.format("not a crossing (clock moved %.2f day(s)) - leaving this save alone", gap))
        self.RegionCarry = nil
        return
    end

    if here > 0 then
        -- This region already knows the company. Whichever side holds the newer picture
        -- wins, so a second crossing does not resurrect the state this region had when the
        -- player last left it.
        local theirs = tonumber(self:LoadString("MercStateWhen") or "") or 0
        if theirs >= (carry.when or 0) then
            rLog("this region's own state is current - ordinary load")
            self.RegionCarry = nil
            return
        end
        rLog("this region's state is stale - the company that travelled with the player wins")
    end

    local batch, n = {}, 0
    for tag, val in pairs(carry.tags) do
        if self:RegionTagTravels(tag) then batch[tag] = val; n = n + 1 end
    end
    -- The camp tags are not in the batch (RegionTagTravels holds them back) and are not
    -- forced either way: whatever this region has of its own is exactly what should stand
    -- here. A region with no camp of its own gets none; travel back to the one the camp was
    -- pitched in and its own anchor puts it up again.
    self:SaveStrings(batch)

    self.RegionCrossed = true
    if carry.tags.MercenariesDismissed == "1" then
        rLog("company was paid off - " .. n .. " tag(s) carried, nobody to bring across")
    else
        for _, name in ipairs(carry.men or {}) do table.insert(self.RegionSpawnQueue, name) end
        rLog(n .. " tag(s) carried, " .. #self.RegionSpawnQueue .. " man/men to bring across")
    end
    Script.SetTimerForFunction(self.RegionRestoreMs, "mercenaries.RegionRestoreDelayed")
end

-- ==== re-materialise the company ====
-- Everything needed to rebuild a man is in his entity name: the prefix says whether he is
-- foot, archer or a named companion, and the last field is his soul, so he comes back with
-- the same face. He keeps his name too, which is what stops a second crossing duplicating
-- him.
function mercenaries:RegionParseMan(name)
    if not name or name == "" then return nil end
    local soul = string.match(name, "([0-9a-fA-F%-]+)$")
    if not (soul and string.len(soul) >= 32) then return nil end
    local kind = "foot"
    if string.find(name, "_hero_", 1, true) then
        kind = "hero"
        soul = string.match(name, "_hero_([0-9a-fA-F%-]+)_") or soul
    elseif string.find(name, "_archer_", 1, true) then
        kind = "archer"
    end
    return { kind = kind, soul = soul }
end

function mercenaries:RegionSpawnMan(name, anchor)
    local m = self:RegionParseMan(name)
    if not m then return false end
    if System.GetEntityByName(name) then return false end

    local raw = { x = anchor.pos.x + (math.random() - 0.5) * 3.0,
                  y = anchor.pos.y + (math.random() - 0.5) * 3.0,
                  z = anchor.pos.z }
    local pos = anchor.snap and self:FindValidGround(raw, anchor.pos.z) or raw

    System.SpawnEntity({
        class = "NPC", name = name, position = pos,
        orientation = { x = 0, y = 0, z = anchor.rot.z },
        properties = { guidSharedSoulId = m.soul },
    })
    local ent = System.GetEntityByName(name)
    if not ent then
        rLog("SpawnEntity produced nothing for " .. name)
        return false
    end

    -- Register before dressing him, for the reason Hire spells out: an equip call that
    -- throws must not leave a live NPC nothing tracks.
    self.ActiveMercs[name] = ent
    local ok, err = pcall(function()
        self:EnsureMercIsAlwaysRendered(ent)
        if m.kind ~= "hero" then
            self:EquipMercenary(ent, _G.MercCurrentOutfit or 1)
            if m.kind == "archer" then
                self:EquipArcherWeapon(ent)
            else
                self:EquipMercenaryWeapon(ent, _G.MercCurrentWeapon or 1, _G.MercCurrentOutfit or 1)
            end
        end
        self:InjectInteraction(ent)
        self:CampOnMercJoined(ent)
    end)
    if not ok then rLog("post-spawn setup failed for " .. name .. ": " .. tostring(err)) end
    -- A companion is equipped by his soul and gets nothing between the spawn and the
    -- injection, so the override can land on a script table the engine has not finished
    -- with. The same re-injection HireCustomCompanion arms.
    if m.kind == "hero" then Script.SetTimerForFunction(1000, "mercenaries.CCReinject", ent.id) end
    return true
end

-- Men this region is holding that the company no longer has (killed or paid off on the
-- other side). Only ever our own squad NPCs - a tower archer or a roaming patrolman
-- carries a different prefix and is nobody's to sweep.
function mercenaries:RegionSweepStrays(keep)
    local swept = 0
    pcall(function()
        for _, e in pairs(System.GetEntitiesByClass("NPC") or {}) do
            local n = (e and e.GetName and e:GetName()) or ""
            local ours = (string.find(n, "SpawnedFriend", 1, true) == 1)
                          or string.find(n, "MercenaryCustomCompanion", 1, true)
            if ours and not keep[n] then
                self.ActiveMercs[n] = nil
                pcall(function() System.RemoveEntity(e.id) end)
                swept = swept + 1
            end
        end
    end)
    if swept > 0 then rLog("swept " .. swept .. " man/men the company no longer has") end
end

function mercenaries.RegionRestoreDelayed()
    local self = mercenaries
    if not self.RegionCrossed then return end
    local ok, err = pcall(function()
        local keep = {}
        for _, n in ipairs(self.RegionSpawnQueue) do keep[n] = true end
        self:RegionSweepStrays(keep)
        self:RegionSpawnStep()
    end)
    if not ok then rLog("restore failed: " .. tostring(err)) end
end

function mercenaries.RegionSpawnStep()
    local self = mercenaries
    local q = self.RegionSpawnQueue or {}
    if #q == 0 then
        if self.RegionCrossed then
            self.RegionCrossed = false
            self.RegionCarry = nil
            self:Recount()
            pcall(function() self:LogiUpdateStatusBuffs() end)
            pcall(function() self:BeginFollowVerify("region") end)
            rLog("the company is across: " .. tostring(_G.MercCount) .. " man/men")
        end
        return
    end

    local anchor
    pcall(function() anchor = self:HireSpawnAnchor() end)
    if not (anchor and anchor.pos and anchor.rot) then
        -- Bounded: a player who arrives somewhere the anchor can never resolve must not
        -- leave a 4Hz timer running for the rest of the session.
        self._regionTries = (self._regionTries or 0) + 1
        if self._regionTries > self.RegionAnchorTries then
            rLog("no usable spawn position after " .. self._regionTries ..
                 " tries - " .. #q .. " man/men not brought across")
            self.RegionSpawnQueue, self.RegionCrossed, self._regionTries = {}, false, 0
            return
        end
        rLog("no usable spawn position yet - trying again")
        Script.SetTimerForFunction(self.RegionSpawnStepMs, "mercenaries.RegionSpawnStep")
        return
    end
    self._regionTries = 0

    -- Spread over several passes: fifty NPCs and their gear in one frame is a hitch, and
    -- the equip pipeline wants frames between its passes anyway.
    for _ = 1, self.RegionSpawnBatch do
        local name = table.remove(q, 1)
        if not name then break end
        pcall(function() self:RegionSpawnMan(name, anchor) end)
    end
    Script.SetTimerForFunction(self.RegionSpawnStepMs, "mercenaries.RegionSpawnStep")
end

-- ==== diagnostics ====
function mercenaries:RegionReport()
    rLog("carrying across regions: " .. (self.RegionEnabled and "ON" or "OFF"))
    local c = self.RegionCarry
    if not c then
        rLog("nothing carried (no state was captured on the last load)")
    else
        local n = 0
        for _ in pairs(c.tags or {}) do n = n + 1 end
        rLog(string.format("carry: %d tag(s), %d man/men, stamped %s", n, #(c.men or {}), tostring(c.when)))
    end
    rLog("this region's stamp: " .. tostring(self:LoadString("MercStateWhen")) ..
         ", world time now " .. tostring(self:LogiNow()))
    rLog("queue: " .. #(self.RegionSpawnQueue or {}) .. " man/men waiting to be brought across")
end

function mercenaries:RegionSet(line)
    local a = self:CmdArgs(line)
    self.RegionEnabled = (tonumber(a[1]) or 0) ~= 0
    rLog("carrying the company across regions " .. (self.RegionEnabled and "ON" or "OFF"))
end

mercenaries:DevCommand("merc_region", "mercenaries:RegionReport()",
                   "Report the cross-region carry (what would follow the player to the other map)")
mercenaries:DevCommand("merc_region_carry", "mercenaries:RegionSet('%line')",
                   "merc_region_carry 0|1 - whether the company follows the player between Trosky and Kuttenberg")
