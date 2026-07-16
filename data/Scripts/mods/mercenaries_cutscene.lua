-- Plays a prerendered (.bk2) cutscene from the quartermaster dialog.
-- The quest's CutsceneHandler needs a real CutsceneHolder entity, reached
-- through an asset link on a SmartObjectHolder named after the quest. The base
-- game bakes both into the level; this mod can't, so it spawns and links them
-- at runtime. See docs/cutscenes.md.

mercenaries.CutsceneQuest = "mercenaries_background_quest"
mercenaries.CutsceneAsset = "qm_tutorial_cs"

-- Vanilla RenderedCutscene playing cin_m0110t_prepadeni__intro_cutscene.bk2.
mercenaries.CutsceneName = "story_switch_to_trosecko"

local function assetLink(name)
    return string.format("asset['%s']", name)
end

function mercenaries:TeardownCutsceneBinding()
    local b = self.CutsceneBinding
    if not b then return end
    pcall(function() b.qso:RemoveLink(assetLink(self.CutsceneAsset)) end)
    for _, id in ipairs({ b.holder.id, b.qso.id }) do
        pcall(function() System.RemoveEntity(id) end)
    end
    self.CutsceneBinding = nil
end

function mercenaries:SetupCutsceneBinding()
    self:TeardownCutsceneBinding()

    local pos = player and player.GetWorldPos and player:GetWorldPos()
    if not pos then
        System.LogAlways("[MercCutscene] no player position yet")
        return false
    end

    local holder
    pcall(function()
        holder = System.SpawnEntity({
            class = "CutsceneHolder",
            name = "MercQmTutorialCutsceneHolder",
            position = pos,
            properties = { esCutsceneName = self.CutsceneName },
        })
    end)
    if not holder then
        System.LogAlways("[MercCutscene] could not spawn CutsceneHolder")
        return false
    end

    local qso
    pcall(function()
        qso = System.SpawnEntity({
            class = "SmartObjectHolder",
            name = self.CutsceneQuest,
            position = pos,
            properties = { bSaved_by_game = false },
        })
    end)
    if not qso then
        pcall(function() System.RemoveEntity(holder.id) end)
        System.LogAlways("[MercCutscene] could not spawn QSO '" .. self.CutsceneQuest .. "'")
        return false
    end

    -- targetId is optional on CreateLink, so a rejected id yields a dangling
    -- link that still looks like success. Read it back instead of trusting it.
    local link = assetLink(self.CutsceneAsset)
    if not pcall(function() qso:CreateLink(link, holder.id) end) then
        System.LogAlways("[MercCutscene] CreateLink threw: " .. link)
        return false
    end

    self.CutsceneBinding = { qso = qso, holder = holder }

    local target
    pcall(function() target = qso:GetLinkTarget(link) end)
    if not target then
        System.LogAlways("[MercCutscene] LINK IS DANGLING - " .. link ..
            " has no target; the quest will never resolve it")
        return false
    end

    System.LogAlways(string.format("[MercCutscene] linked %s.%s -> %s (target verified: %s)",
        self.CutsceneQuest, self.CutsceneAsset, self.CutsceneName,
        tostring(target:GetName())))
    return true
end

-- The binding is session-only: spawned entities don't survive a save, so this
-- reruns on every load.
function mercenaries.SetupCutsceneBindingDelayed()
    mercenaries.CutsceneBinding = nil
    mercenaries:SetupCutsceneBinding()
end

-- Dumps every side of the binding, so a failure points at one link in the chain
-- rather than "no cutscene played".
function mercenaries:CutsceneStatus()
    local b = self.CutsceneBinding
    if not b then
        System.LogAlways("[MercCutscene] not bound - run merc_cutscene_bind")
        return
    end

    local link = assetLink(self.CutsceneAsset)
    local target, count, backName, prop
    pcall(function() target = b.qso:GetLinkTarget(link) end)
    pcall(function() count = b.qso:CountLinks() end)
    pcall(function() backName = b.qso:GetLinkName(b.holder.id) end)
    pcall(function() prop = b.holder.Properties.esCutsceneName end)

    System.LogAlways("[MercCutscene] --- status ---")
    System.LogAlways("  qso name        : " .. tostring(b.qso:GetName()))
    System.LogAlways("  qso links       : " .. tostring(count))
    System.LogAlways("  link            : " .. link)
    System.LogAlways("  link -> target  : " .. tostring(target and target:GetName() or "MISSING (dangling)"))
    System.LogAlways("  qso->holder name: " .. tostring(backName or "none"))
    System.LogAlways("  holder name     : " .. tostring(b.holder:GetName()))
    System.LogAlways("  esCutsceneName  : " .. tostring(prop))
end

-- esCutsceneName is read off the entity, so the holder is respawned rather than
-- edited in place: merc_cutscene_name <RenderedCutscene name>
function mercenaries:SetCutsceneName(name)
    if not name or name == "" or name == "%1" then
        System.LogAlways("[MercCutscene] current: " .. tostring(self.CutsceneName))
        return
    end
    self.CutsceneName = name
    self:SetupCutsceneBinding()
end

-- Diagnostic: a FaderCutscene needs no video pak, so if the screen fades the
-- whole chain works and only the chosen cutscene is wrong.
function mercenaries:CutsceneTestFader()
    self:SetCutsceneName("crime_fader")
end

System.AddCCommand("merc_cutscene_bind", "mercenaries:SetupCutsceneBinding()",
    "Respawn + link the quartermaster tutorial CutsceneHolder")
System.AddCCommand("merc_cutscene_test_fader", "mercenaries:CutsceneTestFader()",
    "Swap to a plain fader: if it plays, the binding works and the video is the problem")
System.AddCCommand("merc_cutscene_status", "mercenaries:CutsceneStatus()",
    "Report the quartermaster tutorial cutscene binding")
System.AddCCommand("merc_cutscene_name", "mercenaries:SetCutsceneName('%1')",
    "Set which RenderedCutscene the quartermaster tutorial plays")
