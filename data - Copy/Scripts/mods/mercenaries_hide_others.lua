-- Console-only debug tool: temporarily hide+deactivate every NPC in the level
-- that is NOT one of ours (mercs, static archers, patrols, the quartermaster,
-- or a mod enemy-group spawn), leaving only our own cast visible. Useful for
-- testing merc/enemy behaviour without vanilla crowds in the way.
--
-- Hide()/Activate() are the same binds documented (never shipped) in
-- docs/npc-lod.md. The danger described there is something ELSE re-forcing a
-- hide every frame (AI LOD demoting a runtime-spawned actor); a hide WE apply
-- and WE reverse via the same toggle does not hit that trap.
--
-- NOT save-safe: toggle back off (run the command again) before saving, or a
-- vanilla NPC's hidden/inactive state will be written into the save.

mercenaries.HideOthersActive = false
mercenaries.HiddenOthersSet = {}   -- [tostring(id)] = id, only entities WE hid, so restore never touches anything else
mercenaries.HideOthersTickMs = 4000 -- rescan while active, to catch NPCs that stream in after the toggle

-- No trailing underscore: the roaming gangs are SpawnedPatrolman_, the tester
-- SpawnedPatrol_. With the underscore this matched only the tester and the
-- roaming patrols got hidden along with the vanilla crowd.
local PatrolNamePrefix = "SpawnedPatrol"

-- True only for a name we recognize as our own spawn; unmatched names (any
-- vanilla NPC) fall through to false. Deliberately not mercenaries:SideOf(),
-- which defaults unknown names to "friend".
function mercenaries:IsOwnNpcName(name)
    if not name then return false end
    if self:IsModEnemyName(name) then return true end
    if self:IsStaticArcherName(name) then return true end
    if string.find(name, PatrolNamePrefix, 1, true) then return true end
    for _, p in ipairs(self.FriendPrefixes) do
        if string.find(name, p, 1, true) then return true end
    end
    return false
end

-- One pass: hides every not-ours, not-already-tracked, non-corpse NPC.
function mercenaries:HideOthersSweep()
    if not player then return end
    local hidCount = 0
    local ents = System.GetEntitiesByClass('NPC')
    if not ents then return 0 end
    for _, ent in pairs(ents) do
        if ent and ent ~= player and ent.id then
            local key = tostring(ent.id)
            if not self.HiddenOthersSet[key] then
                local ok, name = pcall(function() return ent:GetName() end)
                if ok and not self:IsOwnNpcName(name) and not self:IsCorpse(ent) then
                    local alreadyHidden = false
                    pcall(function() alreadyHidden = ent:IsHidden() end)
                    if not alreadyHidden then
                        pcall(function() ent:Hide(1) end)
                        pcall(function() ent:Activate(0) end)
                        self.HiddenOthersSet[key] = ent.id
                        hidCount = hidCount + 1
                    end
                end
            end
        end
    end
    return hidCount
end

function mercenaries:HideOthersRestore()
    local restored = 0
    for key, id in pairs(self.HiddenOthersSet) do
        local ent = System.GetEntity(id)
        if ent then
            pcall(function() ent:Activate(1) end)
            pcall(function() ent:Hide(0) end)
            restored = restored + 1
        end
    end
    self.HiddenOthersSet = {}
    return restored
end

-- Self-rescheduling; stops on its own once HideOthersActive goes false.
function mercenaries.HideOthersTick()
    local self = mercenaries
    if not self.HideOthersActive then return end
    pcall(function() self:HideOthersSweep() end)
    if self.HideOthersActive then
        Script.SetTimerForFunction(self.HideOthersTickMs, "mercenaries.HideOthersTick")
    end
end

function mercenaries:ToggleHideOthers()
    if self.HideOthersActive then
        self.HideOthersActive = false
        local restored = self:HideOthersRestore()
        System.LogAlways('[Mercenaries] hide-others OFF - restored ' .. tostring(restored) .. ' NPC(s)')
    else
        self.HideOthersActive = true
        local hidden = self:HideOthersSweep()
        Script.SetTimerForFunction(self.HideOthersTickMs, "mercenaries.HideOthersTick")
        System.LogAlways('[Mercenaries] hide-others ON - hid ' .. tostring(hidden) .. ' NPC(s), watching for more. Run merc_hide_others again to restore (do this before saving).')
    end
end

System.AddCCommand("merc_hide_others", "mercenaries:ToggleHideOthers()", "Toggle: hide+deactivate every NPC that is not a merc/static archer/patrol/quartermaster/mod enemy. Run again to restore. Restore before saving.")
