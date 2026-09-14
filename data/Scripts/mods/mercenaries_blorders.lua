-- Turns the command interface's state into real orders.
--
-- Almost nothing here is new behaviour: the mod already knows how to hold ground
-- (mercenaries_hold.lua), follow, form up and pick an engagement stance. This file is the
-- translation layer - which squads an order binds, where the ground order points, and the
-- flag that shows it.
--
--   merc_bl_place    confirm the marker where you are looking (bound to left click in
--                    placement mode)
--   merc_bl_cancel   leave placement mode without issuing
--
-- See docs/command-ui.md.

local BL = mercenaries.BL
local function log(s) System.LogAlways("[MercOrder] " .. tostring(s)) end

-- The order marker. Alternatives in the same folder if this one sits wrong on the ground:
--   flag_temporary.cgf     spawned from Lua by another mod, so known to work that way
--   flag_spear_scaled.cgf  the same spear flag, smaller
mercenaries.BLFlagMesh = mercenaries.BLFlagMesh
    or "objects/manmade/common_decorations/flags/flag_spear.cgf"
mercenaries.BLLookMax = mercenaries.BLLookMax or 120.0
-- The mesh is a decoration sized for a tent pole; at 1:1 it is barely visible across a
-- field, which is the one thing an order marker must not be.
mercenaries.BLFlagScale = mercenaries.BLFlagScale or 3.5

BL.placing = false            -- true while the player is siting a move order
BL.flags = BL.flags or {}      -- [squad] = marker entity; index 0 is the placement preview

-- ---------------------------------------------------------------- the ground under the cursor

-- Where the player is looking, on the ground. The ray is cast from the VIEW camera rather
-- than the player, so it follows the crosshair in both first and third person.
function mercenaries:BLLookGround()
    local hit
    pcall(function()
        local pos, dir
        pcall(function() pos = System.GetViewCameraPos() end)
        pcall(function() dir = System.GetViewCameraDir() end)
        if not (pos and dir) then return end
        local L = math.sqrt(dir.x * dir.x + dir.y * dir.y + dir.z * dir.z)
        if L < 1e-4 then return end
        local m = self.BLLookMax / L
        local d = { x = dir.x * m, y = dir.y * m, z = dir.z * m }
        local hits = {}
        local n = Physics.RayWorldIntersection(pos, d, 4, ent_terrain + ent_static,
                                               player.id, nil, hits)
        if n and n > 0 and hits[1] and hits[1].pos then hit = hits[1].pos end
    end)
    return hit
end

-- ---------------------------------------------------------------- the marker
--
-- One flag PER SQUAD, because several squads can be under ground orders at once. Index 0 is
-- the preview flag that tracks the crosshair before an order is confirmed.

BL.flags = BL.flags or {}

function mercenaries:BLFlagShow(pos, i)
    if not pos then return end
    i = i or 0
    if not BL.flags[i] then
        local ent
        pcall(function()
            ent = System.SpawnEntity({
                class = "mercenaries_Prop",
                name = "merc_bl_flag_" .. i,
                position = pos,
                orientation = { x = 0, y = 1, z = 0 },
                properties = { object_Model = self.BLFlagMesh },
            })
        end)
        if not ent then log("could not spawn the marker") return end
        BL.flags[i] = ent
    end
    pcall(function() BL.flags[i]:SetWorldPos(pos) end)
    pcall(function() BL.flags[i]:SetScale(self.BLFlagScale) end)
    pcall(function() BL.flags[i]:Hide(0) end)
end

function mercenaries:BLFlagClear(i)
    if i == nil then
        for k in pairs(BL.flags) do self:BLFlagClear(k) end
        return
    end
    local ent = BL.flags[i]
    if not ent then return end
    BL.flags[i] = nil
    pcall(function() System.RemoveEntity(ent.id) end)
end

-- The flag has said what it had to say once the squad is standing on the ground it marks.
--
-- Driven by its own chain rather than the squad tick: that rides LogiUpdateStatusBuffs, which
-- runs on the logistics cadence, and a marker left standing for minutes after the men arrive
-- reads as the order never having finished. The chain only runs while a flag exists, so it
-- costs nothing the rest of the time and cannot accumulate into a save.
local FLAG_TICK = 1000
local FLAG_MAX_TICKS = 300      -- five minutes; a squad that has not arrived by then is stuck
local flagChain, flagTicks = false, 0

function mercenaries:BLFlagTick()
    local any = false
    for i = 1, (self.SquadMax or 4) do
        if BL.flags[i] then
            local o = self.SquadOrder[i]
            if not (o == "move" or o == "retreat") or self:SquadArrived(i) then
                self:BLFlagClear(i)
            else
                any = true
            end
        end
    end
    return any
end

mercenaries.BLFlagChainTick = function()
    flagTicks = flagTicks + 1
    -- Never leave a timer chain running indefinitely: a save taken with one in flight carries
    -- it, and that is how this mod once shipped a save holding thousands of pending timers.
    if flagTicks > FLAG_MAX_TICKS then
        mercenaries:BLFlagClear()
        flagChain = false
        System.LogAlways("[MercOrder] marker watch gave up after " ..
            tostring(FLAG_MAX_TICKS) .. "s - nobody reached the mark")
        return
    end
    if mercenaries:BLFlagTick() then
        Script.SetTimerForFunction(FLAG_TICK, "mercenaries.BLFlagChainTick")
    else
        flagChain = false
    end
end

-- Called whenever a flag is planted.
function mercenaries:BLFlagWatch()
    flagTicks = 0
    if flagChain then return end
    flagChain = true
    Script.SetTimerForFunction(FLAG_TICK, "mercenaries.BLFlagChainTick")
end

-- ---------------------------------------------------------------- attack block
--
-- Left click plants the marker, so it must not also swing the sword. Same route as the
-- quick-slot block: a weightless marker item drives a FilterInput node that enables the
-- game's own `no_attack` filter. Lua cannot enable a filter directly.

mercenaries.TokenIDAttackBlock = "679a655e-189d-4519-b437-ccc4b92bef4d"

function mercenaries:BLAttackBlock(on)
    if on == BL.atkBlocked then return end
    BL.atkBlocked = on
    pcall(function()
        if on then
            player.inventory:CreateItem(self.TokenIDAttackBlock, 1, 1)
        else
            player.inventory:DeleteItemOfClass(self.TokenIDAttackBlock, 99)
        end
    end)
end

-- Placement mode is not something to wake up inside after a crash or a load.
function mercenaries:BLOrdersOnLoad()
    BL.placing, BL.atkBlocked = false, false
    BL.flags = {}
    -- The per-squad records are the last orders GIVEN, and nothing they describe survives a
    -- load: OnGameplayStarted clears HoldStations, and it re-dresses and re-arms the whole
    -- company from MercCurrentOutfit / MercCurrentWeapon. Left standing they are what had
    -- the screen opening on orders nobody had given this session.
    self.SquadOrder, self.SquadWeapon, self.SquadOutfit = {}, {}, {}
    self._blChargePrevStance, self._blPrevOutfit = nil, nil
    flagChain, flagTicks = false, 0
    pcall(function() System.ExecuteCommand("unbind mouse1") end)
    pcall(function()
        player.inventory:DeleteItemOfClass(self.TokenIDAttackBlock, 99)
    end)
end

-- ---------------------------------------------------------------- placement mode

-- The marker tracks the crosshair on a timer rather than a frame hook: a flag that updates
-- ten times a second reads as smooth, and a per-frame entity move is not worth the cost.
local PLACE_TICK = 100

mercenaries.BLPlaceTick = function()
    if not BL.placing then return end
    local p = mercenaries:BLLookGround()
    if p then mercenaries:BLFlagShow(p, 0) end
    Script.SetTimerForFunction(PLACE_TICK, "mercenaries.BLPlaceTick")
end

function mercenaries:BLPlaceBegin()
    if BL.placing then return end
    BL.placing = true
    self:BLAttackBlock(true)
    pcall(function() System.ExecuteCommand("bind mouse1 merc_bl_place") end)
    log("siting the order - left click to set it, " ..
        string.upper(BL.hideKey or "h") .. " to cancel")
    self:BLPlaceTick()
end

function mercenaries:BLPlaceEnd()
    if not BL.placing then return end
    BL.placing = false
    self:BLAttackBlock(false)
    pcall(function() System.ExecuteCommand("unbind mouse1") end)
end

function mercenaries:BLPlaceCancel()
    if not BL.placing then return end
    self:BLPlaceEnd()
    self:BLFlagClear(0)
    log("order cancelled")
end

-- Left click both sets the ground and issues the order.
function mercenaries:BLPlaceConfirm()
    if not BL.placing then return end
    local p = self:BLLookGround()
    if not p then log("no ground under the crosshair") return end
    self:BLPlaceEnd()
    self:BLFlagClear(0)
    self:BLMoveTo(p)
end

-- ---------------------------------------------------------------- leaving camp

-- An order given to a quartered squad has to get them out of camp first. Camp members are
-- excluded from HoldRoster (IsMercInCampProper / IsCampActor), so a ground order simply never
-- reaches them - they stand in camp and the order looks ignored. Marking them out of the
-- out-party is the camp's own way of saying "these men are with the player now".
--
-- This used to set the out-party flag and nothing else, which is a THIRD way out of camp
-- doing a different subset of the teardown from CampTakeParty and CampDeployOne. The man kept
-- his bed record and his claim on the shared bed (so the spot could never be reused), and
-- nothing evicted the camp behaviour holding him in it - he was marched out of camp on paper
-- while still lying in it. Do what the other two paths do, and defer the eviction for anyone
-- mid-pose so camp_actor unwinds the StanceElement instead of having it torn off.
-- See docs/camp.md, "That was not enough".
function mercenaries:BLLeaveCamp(sel)
    if not self.CampActive then return 0 end
    local n = 0
    for _, i in ipairs(sel or {}) do
        for _, ent in ipairs(self:SquadMembers(i)) do
            local w = ent and (ent.this and ent.this.id or ent.id)
            if w and self:IsMercInCampProper(w) then
                local posed = self:InCampPose(w)
                pcall(function()
                    local ka, kb = self:CampMercKeys(ent)
                    for _, k in ipairs({ ka, kb }) do
                        if k then
                            if self.CampRoster then self.CampRoster[k] = nil end
                            if self.CampActivities then self.CampActivities[k] = nil end
                            if self.CampFurniture then self.CampFurniture[k] = nil end
                            if self.CampPatrollers then self.CampPatrollers[k] = nil end
                            self:ReleaseSpot(self.CampSeats or {}, k)
                            self:ReleaseSpot(self.CampBeds or {}, k)
                        end
                    end
                end)
                pcall(function() self:CampSetOut(ent, true) end)
                pcall(function() self:FollowStalled(ent, posed and self.CampPoseUnwindSecs or nil) end)
                n = n + 1
            end
        end
    end
    if n > 0 then
        if self.CampActorInvalidateAll then self:CampActorInvalidateAll() end
        pcall(function() self:SaveCampOutParty() end)
        log(n .. " man/men marched out of camp to take the order")
    end
    return n
end

-- ---------------------------------------------------------------- issuing

-- Which squads the order binds. Selection is the interface's; if nothing is selected the
-- order goes to the whole company, which is what a player who never touched 1-4 expects.
function mercenaries:BLSelected()
    local out = {}
    local n = self.SquadCount or 4
    for i = 1, n do
        if BL.sel[i] then table.insert(out, i) end
    end
    if #out == 0 then for i = 1, n do table.insert(out, i) end end
    return out
end

-- Move to the marker. The existing hold order already walks every man to a station around
-- an anchor and keeps him there, so a ground order is a hold with a chosen anchor rather
-- than the ground underfoot. HoldMembers scopes it to the squads that were selected.
function mercenaries:BLMoveTo(pos)
    local sel = self:BLSelected()
    local keys = self:SquadKeySet(sel)
    self:BLLeaveCamp(sel)
    local facing
    pcall(function()
        local pp = player:GetWorldPos()
        if pp then
            local dx, dy = pos.x - pp.x, pos.y - pp.y
            local L = math.sqrt(dx * dx + dy * dy)
            if L > 1e-3 then facing = { x = dx / L, y = dy / L } end
        end
    end)
    -- Drawn up in line at the marker rather than standing where they were: a ground order
    -- is the one case where the men are meant to march somewhere and form up.
    local wasFormUp = self.HoldFormUp
    self.HoldFormUp = true
    -- HoldAddGroup, not HoldBegin: a second ground order must stand beside the first, not
    -- replace it. HoldBegin wipes every station, which dropped the first squad back to
    -- following the moment a second was told to move.
    local ok = self:HoldAddGroup(keys, pos, facing)
    self.HoldFormUp = wasFormUp
    -- An order to move is an order to move: break off whatever they are fighting.
    self:MarchSet(keys, true)
    self:HoldSetLeash(keys, nil)
    for _, i in ipairs(sel) do
        self.SquadOrder[i] = "move"
        self:BLFlagShow(pos, i)
    end
    self:BLFlagWatch()
    log(string.format("move order to %.1f %.1f for squad(s) %s",
        pos.x, pos.y, table.concat(sel, ",")))
    return ok
end

-- The rest of the movement wheel, mapped onto what the mod already does. Every branch drops
-- the squads out of any standing ground order first, otherwise they walk back to their old
-- station the moment the new order finishes.
function mercenaries:BLOrder(key)
    local sel = self:BLSelected()
    local keys = self:SquadKeySet(sel)
    self:BLLeaveCamp(sel)
    if key == "move" then
        self:BLPlaceBegin()
        return
    end
    if key == "follow" then
        self:HoldDropGroup(keys)
        self:MarchSet(keys, false)
        for _, i in ipairs(sel) do self:BLFlagClear(i) end
    elseif key == "stop" then
        -- HoldBegin with no anchor is stand-fast: every man's station is the ground he is
        -- already on, which is exactly "stop".
        if self.HoldActive then
            self:HoldDropGroup(keys)
        end
        self:HoldBegin(nil, nil, keys)
    elseif key == "charge" then
        self:HoldDropGroup(keys)
        self:MarchSet(keys, false)
        for _, i in ipairs(sel) do self:BLFlagClear(i) end
        self:BLCharge()
    elseif key == "noengage" then
        self:SetEngageStance("hold")
    elseif key == "retreat" then
        self:BLRetreat(sel, keys)
    else
        log("'" .. tostring(key) .. "' is not wired to behaviour yet")
        return
    end
    for _, i in ipairs(sel) do self.SquadOrder[i] = key end
    log("order '" .. key .. "' to squad(s) " .. table.concat(sel, ","))
end

-- ---------------------------------------------------------------- charge

-- How far and how long the company's eyes are widened by a charge order. The scan radius is
-- picked in mercenaries_perf.lua as "alerted and EnemyAlertRadius, or EnemyScanRadius" - so
-- forcing the alert on and raising the radius is the whole of "see further".
mercenaries.BLChargeRadius = mercenaries.BLChargeRadius or 140
mercenaries.BLChargeSecs   = mercenaries.BLChargeSecs or 30

-- Kill everything in front of you, and look a long way for it. The stance does the
-- target-acceptance half; the radius does the seeing half.
--
-- THE ACCEPTANCE HALF IS NOW `viking`, WHICH DOES NOT CARE WHO ANYBODY IS. A charge
-- ordered within BLChargeRadius (140m) of a village is an order to sack the village.
-- That is the order working as specified, not a bug - but it is why BLCharge raises the
-- same warning SetEngageStance does, and why the stance is transient and generation-
-- guarded so it can never outlive the 30s window.
--
-- BOTH halves are temporary, and the stance half did not used to be: the timer restored
-- the radius alone, so one charge order left the company on the top rung for the rest of
-- the session AND across saves, because SetEngageStance persists it. The player charged a
-- camp, won, rode into town, and had no idea what his standing order now was. That is
-- survivable when the rung is "attack outlaws" and it is a massacre now, which is why
-- the change is passed transient (never written to the save, because timers do not
-- survive a load and a saved string does) and why the restore runs on a generation guard.
function mercenaries:BLCharge()
    -- Whatever they were on before the charge - captured before the change, and only on
    -- the first charge of a chain, or a second order inside the window would record
    -- "viking" as the thing to go back to.
    if self._blChargePrevStance == nil then
        self._blChargePrevStance = _G.MercEngage or "default"
    end
    self:SetEngageStance("viking", true)
    self.EnemyAlerted = true
    self.EnemyAlertRadius = math.max(self.EnemyAlertRadius or 60, self.BLChargeRadius)
    -- The alert decays EnemyAlertHoldSecs after the last contact (_alertAt), so stamping it
    -- now buys the charge that long before the ordinary decay can close it mid-advance.
    pcall(function() self._alertAt = System.GetCurrTime() or 0 end)
    self._blChargeGen = (self._blChargeGen or 0) + 1
    local gen = self._blChargeGen
    mercenaries._blChargeRestore = function()
        if gen ~= mercenaries._blChargeGen then return end
        -- Never leave the 140m query running: it is the expensive one.
        mercenaries.EnemyAlertRadius = mercenaries.EnemyAlertRadiusDefault or 60
        local back = mercenaries._blChargePrevStance or "default"
        mercenaries._blChargePrevStance = nil
        -- Only if the charge's own stance is still the one in force: a player who picked
        -- a stance himself mid-charge means that, and must not be overruled 30s later.
        if (_G.MercEngage or "default") == "viking" and back ~= "viking" then
            mercenaries:SetEngageStance(back, true)
        end
        System.LogAlways("[MercOrder] charge expired, scan radius back to "
            .. tostring(mercenaries.EnemyAlertRadius) .. "m, engagement back to "
            .. tostring(_G.MercEngage))
    end
    Script.SetTimerForFunction(self.BLChargeSecs * 1000, "mercenaries._blChargeRestore")
    log(string.format("charge: kill everything in sight, scan radius %dm for %ds",
        self.EnemyAlertRadius, self.BLChargeSecs))
end

-- ---------------------------------------------------------------- retreat

-- Far enough that the fight stops being theirs. There is no readable per-enemy detection
-- radius in the game, so the distance is the mod's own EnemyAlertRadius plus a margin - the
-- same number the mod already uses to decide when an enemy has noticed the company.
-- How close an enemy must come before a retreated squad will fight it. They were pulled out
-- of a fight on purpose; the ordinary 30m leash would have them claim a target the moment they
-- arrive and walk straight back in.
mercenaries.BLRetreatLeash = mercenaries.BLRetreatLeash or 5.0
mercenaries.BLRetreatPad = mercenaries.BLRetreatPad or 20.0
mercenaries.BLRetreatMin = mercenaries.BLRetreatMin or 30.0
mercenaries.BLRetreatMax = mercenaries.BLRetreatMax or 120.0

local function groundAt(x, y, z)
    local out = z
    pcall(function()
        local hits = {}
        local n = Physics.RayWorldIntersection({ x = x, y = y, z = z + 25 },
                                               { x = 0, y = 0, z = -60 }, 3,
                                               ent_terrain + ent_static, nil, nil, hits)
        if n and n > 0 and hits[1] and hits[1].pos then out = hits[1].pos.z end
    end)
    return out
end

-- Away from the fight, then stand: arriving IS the wait, because a hold order keeps them
-- there until they are told otherwise.
function mercenaries:BLRetreat(sel, keys)
    local men = {}
    for _, i in ipairs(sel or {}) do
        for _, e in ipairs(self:SquadMembers(i)) do table.insert(men, e) end
    end
    if #men == 0 then log("nobody to retreat") return end

    local cx, cy, cz, n = 0, 0, 0, 0
    for _, e in ipairs(men) do
        local p
        pcall(function() p = e:GetWorldPos() end)
        if p then cx, cy, cz, n = cx + p.x, cy + p.y, cz + p.z, n + 1 end
    end
    if n == 0 then return end
    cx, cy, cz = cx / n, cy / n, cz / n

    -- Whoever is worth running from: someone near the squad, not on our side, and actually
    -- fighting. soul:IsInCombatDanger is the working combat check, and it keeps bystanders
    -- out of it - a squad that "retreats" from a passing villager is just wandering off.
    local reach = self.EnemyAlertRadius or 60
    local hx, hy, hn = 0, 0, 0
    pcall(function()
        local here = { x = cx, y = cy, z = cz }
        -- PerfNpcsNear's third argument is the cache's MAX AGE IN MS, not a count, and it
        -- returns nil when the cached sweep does not cover this ground - hence the box scan.
        local near = self.PerfNpcsNear and self:PerfNpcsNear(here, reach, 2000) or nil
        local ents = {}
        if near then
            for _, rec in ipairs(near) do
                if rec.entity then table.insert(ents, rec.entity) end
            end
        else
            local box = System.GetPhysicalEntitiesInBoxByClass(here, reach, "NPC")
            for _, e in pairs(box or {}) do table.insert(ents, e) end
        end
        for _, e in ipairs(ents) do
            if e and e.id ~= player.id and not self:IsOwnSide(e) then
                local hot = false
                pcall(function() hot = e.soul:IsInCombatDanger() end)
                if hot then
                    local q
                    pcall(function() q = e:GetWorldPos() end)
                    if q then hx, hy, hn = hx + q.x, hy + q.y, hn + 1 end
                end
            end
        end
    end)

    local goal, why
    if hn > 0 then
        local dx, dy = cx - (hx / hn), cy - (hy / hn)
        local L = math.sqrt(dx * dx + dy * dy)
        if L < 1e-3 then dx, dy, L = 0, 1, 1 end
        dx, dy = dx / L, dy / L
        local dist = math.max(self.BLRetreatMin,
                              math.min(self.BLRetreatMax, reach + self.BLRetreatPad))
        local tx, ty = cx + dx * dist, cy + dy * dist
        goal = { x = tx, y = ty, z = groundAt(tx, ty, cz) }
        why = string.format("%.0fm from %d combatant(s)", dist, hn)
        self._blRetreatFace = { x = -dx, y = -dy }
    else
        -- Nothing is fighting them, so there is nothing to run from and no direction to run
        -- in. Rally on the player instead of marching 80m into empty country.
        local pp
        pcall(function() pp = player:GetWorldPos() end)
        if not pp then log("nothing to retreat from, and no player to rally on") return end
        goal = { x = pp.x, y = pp.y, z = pp.z }
        why = "no combatants - rallying on you"
        local dx, dy = cx - pp.x, cy - pp.y
        local L = math.sqrt(dx * dx + dy * dy)
        self._blRetreatFace = (L > 1e-3) and { x = dx / L, y = dy / L } or { x = 0, y = 1 }
    end

    self:HoldDropGroup(keys)
    local wasFormUp = self.HoldFormUp
    self.HoldFormUp = true
    self:HoldAddGroup(keys, goal, self._blRetreatFace)
    self.HoldFormUp = wasFormUp
    self:MarchSet(keys, true)
    -- Stay there: nothing outside arm's reach is their business any more.
    self:HoldSetLeash(keys, self.BLRetreatLeash)
    for _, i in ipairs(sel or {}) do self:BLFlagShow(goal, i) end
    self:BLFlagWatch()
    log(string.format("retreat to %.1f %.1f - %s", goal.x, goal.y, why))
end

-- ---------------------------------------------------------------- formation

-- The formation wheel. SetFormationShape resolves the preset name on the spot and bumps the
-- epoch, which is what makes the change take on the next rebuild; setting FormationShape by
-- hand would leave FormationName pointing at the old preset for a tick and the leader can
-- re-enter in that window.
--
-- Shape is company-wide in the engine formation system, so this sets it for everyone. The
-- per-squad record is kept for the cards and for the day the engine formation is per group.
function mercenaries:BLFormation(shape)
    self:BLLeaveCamp(self:BLSelected())
    local ok = pcall(function() self:SetFormationShape(shape, true) end)
    if not ok then
        log("SetFormationShape failed for '" .. tostring(shape) .. "'")
        return
    end
    self.SquadForm = self.SquadForm or {}
    for _, i in ipairs(self:BLSelected()) do self.SquadForm[i] = shape end
    log("formation '" .. tostring(shape) .. "' -> preset " .. tostring(self.FormationName))
end

-- ---------------------------------------------------------------- toggles and gear

-- The Toggle wheel. Fire and Mounted were setting interface state and nothing else.
function mercenaries:BLToggleApply(slot, state)
    if slot == "fire" then
        -- The archers' stance is the mod's fire control: hold means stand and shoot only.
        self:SetArcherStance(state == "on" and "skirmish" or "hold")
    elseif slot == "mount" then
        self:HorsesSet(state == "on")
    elseif slot == "engage" then
        self:SetEngageStance(state)
    elseif slot == "swarm" then
        self:SetAggroPreset(state)
    else
        log("toggle '" .. tostring(slot) .. "' is not wired yet")
        return
    end
    log("toggle " .. slot .. " -> " .. tostring(state))
end

-- The Weapons wheel. ChangeMercWeapon takes the loadout index from mercenaries.WeaponSets.
mercenaries.BLWeaponIndex = {
    random = 1, swordshield = 2, axeshield = 3, longsword = 4, maceshield = 5,
    shortsword = 6, mace = 7, axe = 8, polearm = 9,
    bow = 10, crossbow = 11, handcannon = 12,
}
-- The same table read the other way, so BLReadState can turn the company-wide
-- _G.MercCurrentWeapon back into the key the wheel draws.
mercenaries.BLWeaponKeyOf = {}
for k, i in pairs(mercenaries.BLWeaponIndex) do mercenaries.BLWeaponKeyOf[i] = k end

-- ChangeMercWeapon re-arms the WHOLE company, which is how an archer squad's loadout ended up
-- putting hand cannons on the melee line. Equip the selected squads man by man instead -
-- EquipMercenaryWeapon is the per-entity form ChangeMercWeapon itself calls.
function mercenaries:BLWeapons(key)
    local idx = self.BLWeaponIndex[key]
    if not idx then log("no loadout for '" .. tostring(key) .. "'") return end
    -- The archers' weapon type is ONE COMPANY-WIDE setting, and EquipArcherWeapon is the
    -- only thing that reads it. EquipMercenaryWeapon throws away the index it is handed for
    -- an archer and re-equips him from that setting instead, so a bow / crossbow / hand
    -- cannon sent down the per-man path below lit the wheel's icon and changed nothing:
    -- the men kept the weapon they had. See docs/archers.md.
    if self.ArcherWeaponSets and self.ArcherWeaponSets[key] then
        pcall(function() self:SetArcherWeaponType(key) end)
        log("archer weapon type " .. key .. " (company-wide)")
        return
    end
    local sel, n = self:BLSelected(), 0
    for _, i in ipairs(sel) do
        for _, ent in ipairs(self:SquadMembers(i)) do
            local nm
            pcall(function() nm = ent:GetName() end)
            -- Custom companions keep their own weapons, same rule ChangeMercWeapon uses.
            if nm and string.find(nm, "SpawnedFriend") then
                pcall(function() self:EquipMercenaryWeapon(ent, idx) end)
                n = n + 1
            end
        end
        self.SquadWeapon = self.SquadWeapon or {}
        self.SquadWeapon[i] = key
    end
    log(string.format("loadout %s (%d) to %d man/men of squad(s) %s",
        key, idx, n, table.concat(sel, ",")))
end

-- The Clothing wheel. ChangeMercOutfit takes the style number from docs/outfits.md, so the
-- wheel's keys are mapped back to those indices rather than carrying numbers in the UI.
mercenaries.BLOutfitIndex = {
    generic = 1, bandits = 2, cumans = 3, leipa = 4, kuttenberg = 5, skalitz = 6,
    custom = 7, prague = 8, sigismund = 9, red_star = 10, bergov = 11, nebakov = 12,
    semine = 13, pisek = 14, teutonic = 15, ruthard = 16, papal = 17,
}
mercenaries.BLOutfitKeyOf = {}
for k, i in pairs(mercenaries.BLOutfitIndex) do mercenaries.BLOutfitKeyOf[i] = k end

-- Scoped the same way as the loadout, and for the same reason.
function mercenaries:BLOutfit(key)
    local idx = self.BLOutfitIndex[key]
    if not idx then log("no wardrobe style for '" .. tostring(key) .. "'") return end
    local sel, n = self:BLSelected(), 0
    for _, i in ipairs(sel) do
        for _, ent in ipairs(self:SquadMembers(i)) do
            local nm
            pcall(function() nm = ent:GetName() end)
            if nm and string.find(nm, "SpawnedFriend") then
                pcall(function() self:EquipMercenary(ent, idx) end)
                n = n + 1
            end
        end
        self.SquadOutfit = self.SquadOutfit or {}
        self.SquadOutfit[i] = key
    end
    -- The custom uniform carries the weapon with it, so switching into or out of it has to
    -- re-arm the same men - ChangeMercOutfit does the company-wide version of this.
    if idx == self.CustomOutfitIndex or self._blPrevOutfit == self.CustomOutfitIndex then
        local w = (self.SquadWeapon and self.SquadWeapon[sel[1]]) or "random"
        self:BLWeapons(w)
    end
    self._blPrevOutfit = idx
    log(string.format("clothing %s (%d) to %d man/men of squad(s) %s",
        key, idx, n, table.concat(sel, ",")))
end

-- ---------------------------------------------------------------- to camp

-- One button, three states: no camp -> pitch one and send the selection in; selection out ->
-- send it in; selection already in -> bring it out, and break the camp once it is empty.
--
-- Scoped to the selection throughout. Making a camp used to sweep the whole company into it,
-- because SpawnMercCamp takes everyone it finds; the men NOT selected are pushed into the
-- out-party (CampSetOut), which is the camp's own "this man is out with the player" flag.
function mercenaries:BLCamp()
    local sel = self:BLSelected()
    local keys = self:SquadKeySet(sel)

    local selIn, selOut = 0, 0
    for _, i in ipairs(sel) do
        for _, ent in ipairs(self:SquadMembers(i)) do
            local ka = self:CampMercKeys(ent)
            if ka and self.CampOutParty[ka] then selOut = selOut + 1 else selIn = selIn + 1 end
        end
    end

    -- Already home: this press marches them out again.
    if self.CampActive and selOut == 0 and selIn > 0 then
        local n = 0
        for _, i in ipairs(sel) do
            for _, ent in ipairs(self:SquadMembers(i)) do
                pcall(function() self:CampSetOut(ent, true) end)
                n = n + 1
            end
            self.SquadOrder[i] = "follow"
        end
        -- Nobody left inside: the camp has no reason to stand.
        local anyIn = false
        pcall(function()
            for _, ent in pairs(self.ActiveMercs or {}) do
                local ka = self:CampMercKeys(ent)
                if ka and not self.CampOutParty[ka] then anyIn = true end
            end
        end)
        if not anyIn then
            pcall(function() self:BreakMercCamp() end)
            log(string.format("%d man/men marched out; camp broken", n))
        else
            log(string.format("%d man/men of squad(s) %s marched out", n, table.concat(sel, ",")))
        end
        return
    end

    if not (self.CampActive and self.CampCenter) then
        pcall(function() self:SpawnMercCamp() end)
        if not (self.CampActive and self.CampCenter) then
            log("no camp, and one could not be pitched here")
            return
        end
        log("camp pitched on your ground")
        -- SpawnMercCamp gathers everyone. Anyone not selected goes straight back out, or
        -- sending one squad home would quarter the whole company.
        pcall(function()
            for _, ent in pairs(self.ActiveMercs or {}) do
                local w = ent and (ent.this and ent.this.id or ent.id)
                if w and not (keys and keys[tostring(w)]) then
                    self:CampSetOut(ent, true)
                end
            end
        end)
    end

    -- Out of any ground order first: a man teleported off his station would otherwise walk
    -- all the way back to it.
    self:HoldDropGroup(keys)
    self:MarchSet(keys, false)

    local n = 0
    for _, i in ipairs(sel) do
        for _, ent in ipairs(self:SquadMembers(i)) do
            pcall(function() self:CampSetOut(ent, false) end)
            pcall(function() self:CampTeleportToCamp(ent) end)
            n = n + 1
        end
        self.SquadOrder[i] = "camp"
        self:BLFlagClear(i)
    end
    log(string.format("%d man/men of squad(s) %s sent to camp", n, table.concat(sel, ",")))
end

-- ---------------------------------------------------------------- reading the state back
--
-- The row and the wheels report what the company is ACTUALLY set to. BL.state used to be a
-- table of defaults seeded once when the file loaded and written only by this screen's own
-- presses, so everything set from the console, from the quartermaster's dialogue or restored
-- by a save was contradicted the moment the screen opened: a company holding fire read
-- "Firing at will", a wedge read "Line", horses off read "Mounted". Each entry below names
-- the one place the mod really keeps that setting, and BLLayout re-reads all of them on
-- every draw. See docs/command-ui.md.

-- Which keys a wheel actually has art for, taken from the atlas rather than restated here. A
-- live setting with no entry - FormationShape "vanilla", ArcherStance "melee" - must never
-- reach BL.state, or the button asks for a clip that does not exist and silently draws
-- nothing at all.
local wheelKeyCache = {}
local function wheelKeys(cat)
    local hit = wheelKeyCache[cat]
    if hit then return hit end
    local out = {}
    for _, e in ipairs(((mercenaries.BLAtlas or {}).wheels or {})[cat] or {}) do
        if e.key ~= "return" then out[e.key] = true end
    end
    -- An empty answer means the atlas was not there yet, so it is not worth remembering:
    -- cached, it would refuse every real key for the rest of the session.
    if next(out) then wheelKeyCache[cat] = out end
    return out
end

-- Is this squad still standing on a station? SquadOrder records the last order GIVEN, and
-- that record outlives the order itself: HoldDropGroup, a rally and every gameplay start
-- clear the stations while it stays put, which is how a reloaded save opened on "Move to
-- Position" with the men trotting along behind the player.
function mercenaries:BLSquadHeld(i)
    local st = self.HoldStations or {}
    for key in pairs((self.Squads or {})[i] or {}) do
        if st[key] then return true end
    end
    return false
end

local HELD_ORDER = { move = true, stop = true, retreat = true }

-- What this squad is under, mapped onto the movement wheel. The wheel has no Camp entry, so
-- quartered men read as following, which is what they do the moment they step out.
function mercenaries:BLLiveMove(i)
    local o = (self.SquadOrder or {})[i]
    -- A charge is a thirty-second window, not a standing order. _blChargePrevStance is set
    -- for exactly as long as one is in flight and cleared when it expires.
    if o == "charge" then
        return (self._blChargePrevStance ~= nil) and "charge" or "follow"
    end
    if HELD_ORDER[o] then return self:BLSquadHeld(i) and o or "follow" end
    return "follow"
end

function mercenaries:BLReadState()
    local st = BL and BL.state
    if not st then return end
    local first = self:BLSelected()[1] or 1

    -- Siting a flag IS the move order, and nothing records it until the click lands.
    st.move = BL.placing and "move" or self:BLLiveMove(first)

    -- Shape is company-wide.
    if wheelKeys("form")[self.FormationShape] then st.form = self.FormationShape end

    -- Fire at will IS the archers' stance: skirmish shoots, hold stands down. "melee" is a
    -- third stance a two-state button cannot show, and men who have put the bow away are
    -- not firing at anything.
    st.fire = ((_G.ArcherStance or "skirmish") == "skirmish") and "on" or "off"

    local mounted = true
    pcall(function() mounted = self:HorsesAllowed() end)
    st.mount = mounted and "on" or "off"

    local eng = _G.MercEngage
    st.engage = (eng and (self.EngageCodeOf or {})[eng]) and eng or "default"
    local agg = _G.MercAggro
    st.swarm = (agg and (self.AggroPresets or {})[agg]) and agg or "balanced"

    -- Loadout and clothing are per squad once this screen has touched them and company-wide
    -- before that: _G.MercCurrentWeapon and _G.MercCurrentOutfit are what the dialogue, the
    -- console and a loaded save set, and BLOrdersOnLoad drops the per-squad records for
    -- exactly that reason.
    local w = (self.SquadWeapon or {})[first]
    if w and wheelKeys("wpnm")[w] then
        st.wpnm = w
    else
        local k = (self.BLWeaponKeyOf or {})[_G.MercCurrentWeapon or 1]
        if k and wheelKeys("wpnm")[k] then st.wpnm = k end
    end

    -- No per-squad branch for the archers: their weapon type is one company-wide setting,
    -- which is also why BLWeapons routes a ranged pick to SetArcherWeaponType.
    local t = "bow"
    pcall(function() t = self:GetArcherWeaponType() end)
    if wheelKeys("wpnr")[t] then st.wpnr = t end

    local o = (self.SquadOutfit or {})[first]
    if o and (self.BLOutfitIndex or {})[o] then
        st.outfit = o
    else
        local k = (self.BLOutfitKeyOf or {})[_G.MercCurrentOutfit or 1]
        if k then st.outfit = k end
    end
end

-- ---------------------------------------------------------------- cards

-- The interface's card data, now read off the real company.
mercenaries.BLSquadSource = function()
    local out = {}
    local n = mercenaries.SquadCount or 4
    for i = 1, n do
        local men = mercenaries:SquadMembers(i)
        out[i] = {
            type = mercenaries:SquadType(i) or "infantry",
            count = #men,
            hp = mercenaries:SquadHealth(i),
            order = mercenaries:SquadState(i),
            dead = mercenaries.SquadDeaths[i] or 0,
            sel = BL.sel[i],
        }
    end
    return out
end

mercenaries:PlayerCommand("merc_bl_place", "mercenaries:BLPlaceConfirm()",
                       "Set the move marker where you are looking")
mercenaries:PlayerCommand("merc_bl_cancel", "mercenaries:BLPlaceCancel()",
                       "Leave placement mode without issuing")
