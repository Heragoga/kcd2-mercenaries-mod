-- =======================================================================
-- FORGE ANYWHERE
--
-- Set up a working blacksmith's forge in the open field. The vanilla
-- blacksmithing minigame is welded to level-baked ItemSlot/TagPoint entities
-- that can't be created at runtime - but a loaded village Smithery already owns
-- them. So we BORROW the nearest loaded Smithery: move its (invisible) trigger
-- to a spot in front of the player, retarget its alignment link to a holder we
-- spawn (so the player is placed at the field, not teleported to the village),
-- and dress the scene with our own forge props. The borrowed Smithery's hidden
-- hammer/tongs slots keep feeding the tools. Packing up restores everything.
--
--   F2 (rebindable)  - open the menu (set up / pack up forge)
--   forge_menu       - console: toggle the menu
--   forge_spawn      - console: set up the forge
--   forge_despawn    - console: pack it up
--
-- No save persistence. Auto-packs-up when the player nears the borrowed
-- forge's home village (so they never find that smithy broken).
-- =======================================================================
forgeanywhere = {}

forgeanywhere.Active = nil             -- borrow record while a forge is up

-- Metres: pack the forge up when the player gets this close to the borrowed
-- Smithery's original (village) position, so the village forge is back in place
-- before they arrive.
forgeanywhere.AutoPackDist = 30.0

-- Blacksmith's hammer & tongs (only used for reference/keeps parity with the
-- borrowed Smithery's own slots - we never spawn these).
-- Final in-game-tuned prop layout, Henry-relative: fwd = toward the interaction
-- anvil, lat = +left / -right, up = height, yaw = degrees CCW.
forgeanywhere.Layout = {
    { name = "anvil_interact", model = "objects/manmade/task_specific_props/metal_industry/smithing/armourer_anvil.cgf", fwd =  2.74, lat =  0.00, up = -0.11, yaw =   0 },
    { name = "anvil_forge",    model = "objects/manmade/task_specific_props/metal_industry/smithing/anvil.cgf",           fwd = -0.23, lat = -2.56, up = -0.11, yaw =   0 },
    { name = "forge",          model = "objects/manmade/task_specific_props/metal_industry/smithing/forge_small_a.cgf",   fwd = -0.82, lat =  0.58, up = -0.06, yaw =  90 },
    { name = "coal",           model = "objects/manmade/structures/industrial/smitheries/coal_forge_small_a.cgf",         fwd = -0.98, lat =  0.66, up =  0.63, yaw =  90, s = 0.875 },
    { name = "water",          model = "objects/manmade/task_specific_props/metal_industry/smithing/water_container.cgf", fwd =  1.74, lat = -1.75, up =  0.00, yaw =   0 },
    { name = "barrel",         model = "objects/manmade/task_specific_props/metal_industry/smithing/barrel_forging.cgf",  fwd =  2.19, lat = -1.23, up =  0.00, yaw =   0 },
    -- Grindstone is a self-contained interactive entity (its own model + E),
    -- so we BORROW a real loaded one instead of spawning a dead prop.
    { name = "grindstone",     borrow = "Grindstone",                                                                   fwd =  0.90, lat =  2.30, up =  0.00, yaw =   0 },
}

local function msg(key, dur)
    pcall(function() Game.SendInfoText(key, false, 0, dur or 3) end)
end

-- =======================================================================
-- Forge borrow / spawn / despawn
-- =======================================================================
function forgeanywhere:FindNearest(cls)
    if not player then return nil end
    local o = player:GetWorldPos()
    local list = System.GetEntitiesByClass and System.GetEntitiesByClass(cls)
    if not list then return nil end
    local best, bestD
    for _, e in pairs(list) do
        local p = e.GetWorldPos and e:GetWorldPos()
        if p then
            local dd = (p.x - o.x) ^ 2 + (p.y - o.y) ^ 2 + (p.z - o.z) ^ 2
            if not bestD or dd < bestD then best, bestD = e, dd end
        end
    end
    return best, bestD and math.sqrt(bestD)
end

function forgeanywhere:SpawnForge()
    if self.Active then msg("ui_forge_already"); return end
    if not player then return end
    local sm, dist = self:FindNearest("Smithery")
    if not sm then msg("ui_forge_none", 4); return end

    local o = player:GetWorldPos()
    local d = player:GetDirectionVector() or { x = 0, y = 1, z = 0 }
    local fl = math.sqrt(d.x * d.x + d.y * d.y); if fl < 0.001 then d = { x = 0, y = 1, z = 0 }; fl = 1 end
    local F = { x = d.x / fl, y = d.y / fl }   -- forward (toward the anvil)
    local L = { x = -F.y, y = F.x }            -- Henry's left
    local anvilPos = { x = o.x + F.x * 1.5, y = o.y + F.y * 1.5, z = o.z }
    local standPos = { x = anvilPos.x - F.x * 2.74, y = anvilPos.y - F.y * 2.74, z = o.z }
    local yaw = math.atan2(anvilPos.y - standPos.y, anvilPos.x - standPos.x)

    -- Frame kept on the record so the live tuner (forge_nudge) can convert
    -- fwd/lat/up back to world positions.
    local rec = { sm = sm, smPos = sm:GetWorldPos(), visuals = {}, F = F, L = L, stand = standPos, baseYaw = yaw }

    -- Borrow the invisible Smithery logic: move its trigger to the anvil spot.
    pcall(function() sm:SetWorldPos(anvilPos) end)

    -- Build the scene: spawn our own props, or BORROW a real self-contained
    -- interactive entity (grindstone) that carries its own model + E.
    for _, p in ipairs(self.Layout) do
        local w = { x = standPos.x + F.x * p.fwd + L.x * p.lat,
                    y = standPos.y + F.y * p.fwd + L.y * p.lat,
                    z = standPos.z + (p.up or 0) }
        if p.borrow then
            local e = self:FindNearest(p.borrow)
            if e then
                local origPos = e:GetWorldPos()
                pcall(function() e:SetWorldPos(w) end)
                pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw + math.rad(p.yaw or 0) }) end)
                table.insert(rec.visuals, { e = e, name = p.name, fwd = p.fwd, lat = p.lat, up = p.up or 0, yaw = p.yaw or 0, borrowed = true, origPos = origPos })
            end
        else
            local params = { class = "BasicEntity", name = "ForgeAnywhereVis_" .. tostring(math.random(100000, 999999)),
                             position = w, properties = { object_Model = p.model, bMissionCritical = false } }
            if p.s then params.scale = p.s end
            local e; pcall(function() e = System.SpawnEntity(params) end)
            if e then
                pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw + math.rad(p.yaw or 0) }) end)
                if p.s then pcall(function() e:SetScale(p.s) end) end
                table.insert(rec.visuals, { e = e, name = p.name, fwd = p.fwd, lat = p.lat, up = p.up or 0, yaw = p.yaw or 0 })
            end
        end
    end

    -- Retarget the Smithery's 'alignment' link (its TagPoint is Lua-invisible,
    -- but SetLinkTarget works by name) to our holder at the working spot, so the
    -- minigame plants the player here instead of teleporting to the village.
    local holder
    pcall(function()
        holder = System.SpawnEntity({ class = "SmartObjectHolder",
            name = "ForgeAnywhereAlign_" .. tostring(math.random(100000, 999999)),
            position = standPos, properties = {} })
    end)
    if holder then
        pcall(function() holder:SetAngles({ x = 0, y = 0, z = yaw }) end)
        pcall(function() sm:SetLinkTarget("alignment", holder.id) end)
        rec.holder = holder
        -- Original alignment position (base-prefab origin), so pack-up puts our
        -- holder where the village's alignment TagPoint was.
        pcall(function()
            local wang = sm:GetWorldAngles()
            local baseYaw = (wang and wang.z or 0) - math.rad(63)
            local c2, s2 = math.cos(baseYaw), math.sin(baseYaw)
            local lx, ly, lz = 0.046, -2.706, -0.178
            rec.alignOrig = { x = rec.smPos.x - (lx * c2 - ly * s2), y = rec.smPos.y - (lx * s2 + ly * c2), z = rec.smPos.z - lz }
        end)
    end

    self.Active = rec
    System.LogAlways(string.format("[ForgeAnywhere] set up (borrowed a Smithery %.0fm away)", dist or -1))
    msg("ui_forge_created", 4)
    Script.SetTimerForFunction(1500, "forgeanywhere.MonitorTick")
end

function forgeanywhere:DespawnForge(silent)
    local rec = self.Active
    if not rec then if not silent then msg("ui_forge_noforge") end; return end
    pcall(function() rec.sm:SetWorldPos(rec.smPos) end)
    for _, v in ipairs(rec.visuals or {}) do
        if v.borrowed then pcall(function() v.e:SetWorldPos(v.origPos) end)  -- return borrowed grindstone
        else pcall(function() System.RemoveEntity(v.e.id) end) end           -- remove our own props
    end
    -- Alignment link now points at our holder (the TagPoint can't be re-referenced);
    -- park the holder at the village's original alignment spot so the village
    -- smith is placed correctly again. A reload restores the level's own link.
    if rec.holder then
        if rec.alignOrig then pcall(function() rec.holder:SetWorldPos(rec.alignOrig) end)
        else pcall(function() rec.holder:SetWorldPos(rec.smPos) end) end
    end
    self.Active = nil
    System.LogAlways("[ForgeAnywhere] packed up, village Smithery restored")
    if not silent then msg("ui_forge_destroyed") end
end

-- Auto-pack-up when the player nears the borrowed forge's home village.
function forgeanywhere.MonitorTick()
    local self = forgeanywhere
    if not self.Active then return end
    local packed = false
    pcall(function()
        if player and self.Active.smPos then
            local o = player:GetWorldPos()
            local sp = self.Active.smPos
            local dd = (o.x - sp.x) ^ 2 + (o.y - sp.y) ^ 2 + (o.z - sp.z) ^ 2
            if dd < (self.AutoPackDist * self.AutoPackDist) then
                self:DespawnForge(false)
                packed = true
            end
        end
    end)
    if self.Active and not packed then Script.SetTimerForFunction(1500, "forgeanywhere.MonitorTick") end
end

-- =======================================================================
-- Toggle: one hotkey sets the forge up, or packs it up if one is already out.
-- =======================================================================
function forgeanywhere:ToggleForge()
    if self.Active then self:DespawnForge(false) else self:SpawnForge() end
end

-- =======================================================================
-- Live layout tuner (works on the forge that's currently out). Nudge a piece
-- by INDEX with fwd/lat/up/yaw deltas, then forge_dump prints the values to
-- paste into Layout. Indices follow Layout order:
--   1 anvil_interact  2 anvil_forge  3 forge  4 coal  5 water  6 barrel  7 grindstone
-- =======================================================================
function forgeanywhere:Nudge(idx, dfwd, dlat, dup, dyaw)
    local rec = self.Active
    if not rec then System.LogAlways("[ForgeAnywhere] no forge out - set one up first (F2)"); return end
    idx = tonumber(idx); local v = idx and rec.visuals[idx]
    if not v then System.LogAlways("[ForgeAnywhere] no piece #" .. tostring(idx)); return end
    v.fwd = v.fwd + (tonumber(dfwd) or 0)
    v.lat = v.lat + (tonumber(dlat) or 0)
    v.up  = v.up  + (tonumber(dup)  or 0)
    v.yaw = (v.yaw or 0) + (tonumber(dyaw) or 0)
    local w = { x = rec.stand.x + rec.F.x * v.fwd + rec.L.x * v.lat,
                y = rec.stand.y + rec.F.y * v.fwd + rec.L.y * v.lat,
                z = rec.stand.z + v.up }
    pcall(function() v.e:SetWorldPos(w) end)
    pcall(function() v.e:SetAngles({ x = 0, y = 0, z = rec.baseYaw + math.rad(v.yaw) }) end)
    System.LogAlways(string.format("[ForgeAnywhere] #%d %s -> fwd=%.2f lat=%.2f up=%.2f yaw=%d", idx, v.name, v.fwd, v.lat, v.up, v.yaw))
end

function forgeanywhere:Dump()
    local rec = self.Active
    if not rec then System.LogAlways("[ForgeAnywhere] no forge out"); return end
    System.LogAlways("[ForgeAnywhere] ==== layout (paste back) ====")
    for i, v in ipairs(rec.visuals) do
        System.LogAlways(string.format('    #%d { name="%s", fwd=%.2f, lat=%.2f, up=%.2f, yaw=%d },', i, v.name, v.fwd, v.lat, v.up, v.yaw or 0))
    end
end

-- =======================================================================
-- Bootstrap
-- =======================================================================
function forgeanywhere:OnGameplayStarted()
    System.LogAlways("[ForgeAnywhere] gameplay started")
    pcall(function() System.ExecuteCommand("bind f2 forge_toggle") end)
    -- No persistence: any forge from a previous session is gone with the reload.
    self.Active = nil
end

System.AddCCommand("forge_toggle",  "forgeanywhere:ToggleForge()",  "Forge Anywhere: set up the field forge, or pack it up if one is already out")
System.AddCCommand("forge_spawn",   "forgeanywhere:SpawnForge()",   "Forge Anywhere: set up a field forge")
System.AddCCommand("forge_despawn", "forgeanywhere:DespawnForge()", "Forge Anywhere: pack up the field forge")
System.AddCCommand("forge_nudge",   "forgeanywhere:Nudge(%1, %2, %3, %4, %5)", "Forge Anywhere: tune the current forge - forge_nudge <idx> dfwd dlat dup dyaw (1=anvil_interact 2=anvil_forge 3=forge 4=coal 5=water 6=barrel 7=grindstone; metres + degrees, +fwd=toward anvil, +lat=left, +yaw=CCW)")
System.AddCCommand("forge_dump",    "forgeanywhere:Dump()", "Forge Anywhere: print the current forge layout (fwd/lat/up/yaw) to paste back")

UIAction.RegisterEventSystemListener(forgeanywhere, "", "OnGameplayStarted", "OnGameplayStarted")

System.LogAlways("[ForgeAnywhere] loaded")
