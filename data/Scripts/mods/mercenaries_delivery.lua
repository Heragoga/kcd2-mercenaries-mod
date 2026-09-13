-- Handing food and drink to the company, through the game's own item-transfer window.
--
-- The quartermaster does this with a Skald CreateItemDelivery panel. That panel cannot be
-- used here: it hangs off a ForEach over his soul, so it does nothing at all without a camp
-- standing, and the camp screen has to work before there is a camp. This is the same answer
-- the wardrobe reached for the same reason (see mercenaries_custom_gear.lua): spawn a Stash,
-- open the real transfer window onto it, and read back what was put in.
--
-- What the player puts in is CONSUMED - it becomes supply units. Anything else they drop in
-- by accident is handed straight back.

local function dLog(s) System.LogAlways("[Delivery] " .. tostring(s)) end

mercenaries.DelChestName  = "MercDeliveryChest"
mercenaries.DelChestModel = "Objects/characters/assets/chest/chest_rustic_a.cdf"
mercenaries.DelChestDepth = 100.0      -- as the wardrobe: the window is opened FOR the
                                       -- player, so the chest never wants to be walked to
mercenaries.DelTickMs     = 1000
-- Nothing tells Lua the transfer window has closed, so "they are done" is read off the
-- chest: this many quiet seconds with its contents unchanged.
mercenaries.DelSettle     = 3
mercenaries.DelLife       = 180        -- quiet ticks before an abandoned chest packs up

mercenaries.DelChest = nil             -- { id, kind, sig, idle, ticks }
mercenaries.DelTickArmed = false

-- kind -> what it accepts, what it fills, and the filter the transfer window is opened with.
mercenaries.DelKinds = {
    food  = { pool = "food",  filter = "food.*.*",
              classes = function(s) return s.FoodItemClasses end },
    drink = { pool = "drink", filter = "food.*.*",
              classes = function(s) return s.DrinkItemClasses or s.FoodItemClasses end },
}

function mercenaries:DelChestEntity()
    local C = self.DelChest
    if not C then return nil end
    local e
    pcall(function() e = System.GetEntity(C.id) end)
    return e
end

-- What is in the chest, as { cls = class, amount = n }. Borrows the gear module's reader,
-- which already knows that GetInventoryTable + ItemManager.GetItem is the only introspection
-- the engine offers and what to do when it returns nothing.
function mercenaries:DelContentsOf(inv)
    if self.GearContentsOf then return self:GearContentsOf(inv, true) end
    return {}
end

function mercenaries:DelOpen(kind)
    local spec = self.DelKinds[kind]
    if not spec then return end
    if self.DelChest then
        dLog("a delivery is already open")
        return
    end
    local pos, dir
    pcall(function()
        pos = player:GetWorldPos()
        dir = player:GetDirectionVector()
    end)
    if not (pos and dir) then return end

    local at = { x = pos.x, y = pos.y, z = pos.z - self.DelChestDepth }
    -- SpawnEntity's `orientation` is a DIRECTION VECTOR, not Euler angles, so the yaw is
    -- set again afterwards (reference_camp_inn_tavern).
    local yaw = math.atan2(-dir.y, -dir.x)
    local name = self.DelChestName .. "_" .. tostring(math.random(100000, 999999))

    local e
    pcall(function()
        e = System.SpawnEntity({
            class = "Stash", name = name, position = at,
            orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
            properties = { object_Model = self.DelChestModel,
                           sWH_AI_EntityCategory = "Chest",
                           -- Saved with the game on purpose: a quicksave taken mid-transfer
                           -- must not take the player's food with the entity. DelSweep
                           -- empties and removes it on the next load.
                           bSaved_by_game = 1,
                           bSerialize = 1,
                           bSkipAngleCheck = true },
        })
    end)
    if not e then
        dLog("delivery chest failed to spawn")
        Game.SendInfoText('merc_camp_deliver_nochest', false, 0, 4)
        return
    end
    pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw }) end)

    self.DelChest = { id = e.id, kind = kind, sig = nil, idle = 0, ticks = 0 }
    dLog("delivery chest open for " .. kind)
    Game.SendInfoText('merc_camp_deliver_open', false, 0, 6)

    pcall(function()
        player.actor:OpenItemTransferStore(e.id, e.inventory:GetId(), spec.filter, "Inventory")
    end)

    if not self.DelTickArmed then
        self.DelTickArmed = true
        Script.SetTimerForFunction(self.DelTickMs, "mercenaries.DelTick")
    end
end

-- A stable description of the chest's contents, so "unchanged since last tick" is a
-- comparison of two strings rather than a diff.
function mercenaries:DelSignature(e)
    local parts = {}
    for _, entry in ipairs(self:DelContentsOf(e.inventory)) do
        parts[#parts + 1] = tostring(entry.cls) .. "x" .. tostring(entry.amount or 1)
    end
    table.sort(parts)
    return table.concat(parts, ";")
end

-- Take what belongs, hand back what does not.
function mercenaries:DelSettleChest(e, kind)
    local spec = self.DelKinds[kind]
    local accept = {}
    for _, cls in ipairs(spec.classes(self) or {}) do accept[cls] = true end

    local taken, returned = 0, 0
    for _, entry in ipairs(self:DelContentsOf(e.inventory)) do
        local n = entry.amount or 1
        if accept[entry.cls] then
            pcall(function() e.inventory:DeleteItemOfClass(entry.cls, n) end)
            taken = taken + n
        else
            -- not food: back to the player, never destroyed
            pcall(function()
                e.inventory:MoveItemOfClass(player.inventory:GetId(), entry.cls, n, true)
            end)
            local still = 0
            pcall(function() still = e.inventory:GetCountOfClass(entry.cls) or 0 end)
            if still > 0 then
                pcall(function() e.inventory:DeleteItemOfClass(entry.cls, still) end)
                pcall(function() player.inventory:CreateItem(entry.cls, 1, still) end)
            end
            returned = returned + n
        end
    end

    if taken > 0 then
        self:LogiAdjust(spec.pool, taken, "delivered by the player")
        self:LogiReconcile()
        self:LogiSave()
        local L = self:LogiState()
        self:LogiInfo("@merc_n_fdeliv " .. taken .. " @merc_n_stock " .. (L[spec.pool] or 0)
                      .. " @merc_n_days " .. self:LogiSupplyDays(L[spec.pool]))
    else
        Game.SendInfoText('merc_logi_nothing_to_deliver', false, 0, 3)
    end
    dLog(string.format("%s delivery: %d taken, %d handed back", kind, taken, returned))
    return taken
end

function mercenaries:DelClose(silent)
    local C = self.DelChest
    self.DelChest = nil
    if not C then
        self:DelSweep()
        return
    end
    local e
    pcall(function() e = System.GetEntity(C.id) end)
    if e then pcall(function() System.RemoveEntity(C.id) end) end
    if not silent then
        -- back to the camp screen the player came from
        if mercenaries.CUShow then pcall(function() mercenaries:CUShow() end) end
    end
end

-- A chest from a previous session that lost its handle: empty it and take it away.
function mercenaries:DelSweep()
    local all
    pcall(function() all = System.GetEntitiesByClass("Stash") end)
    for _, e in ipairs(all or {}) do
        local nm = e and e:GetName()
        if nm and string.find(nm, self.DelChestName, 1, true) == 1 then
            for _, entry in ipairs(self:DelContentsOf(e.inventory)) do
                pcall(function()
                    e.inventory:MoveItemOfClass(player.inventory:GetId(), entry.cls,
                                                entry.amount or 1, true)
                end)
            end
            pcall(function() System.RemoveEntity(e.id) end)
        end
    end
end

-- Self-arming poll, one chain ever: DelTickArmed is the latch, so opening a second chest
-- cannot leave two timers running. Every exit drops the latch, so the next open can arm a
-- fresh chain (a dead chain nothing can restart is the failure
-- reference_settimerforfunction_third_arg is about).
mercenaries.DelTick = function()
    local self = mercenaries
    local C = self.DelChest
    if not C then
        self.DelTickArmed = false
        return
    end
    Script.SetTimerForFunction(self.DelTickMs, "mercenaries.DelTick")

    C.ticks = C.ticks + 1
    local e = self:DelChestEntity()
    if not e then
        self.DelChest = nil
        self.DelTickArmed = false
        return
    end

    local sig = self:DelSignature(e)
    if sig ~= C.sig then
        C.sig, C.idle = sig, 0
        return
    end
    C.idle = C.idle + 1

    -- Nothing put in and nothing happening: pack up without taking anything.
    if sig == "" then
        if C.ticks > self.DelLife then
            dLog("nothing delivered - packing the chest away")
            self:DelClose(false)
        end
        return
    end

    if C.idle >= self.DelSettle then
        self:DelSettleChest(e, C.kind)
        self:DelClose(false)
    end
end
