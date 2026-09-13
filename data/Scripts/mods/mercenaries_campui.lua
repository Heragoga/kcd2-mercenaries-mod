-- Camp screen: pitch the camp, buy and remove improvements, and run the company's books.
--
--   merc_camp_ui        show / back out of a wheel / close        (bound to U)
--   merc_camp_ui_k<n>   the bottom row and the open wheel         (bound to 1-9, 0)
--
-- The art, the geometry, the improvement list and the action tables all come from
-- mercenaries_campatlas.lua, which tools/make_camp.py generates alongside MercCamp.swf.
-- Every figure shown is read from mercenaries_logistics.lua; nothing here keeps its own
-- copy of the company's state. See docs/camp-ui.md.

mercenaries.CU = mercenaries.CU or {}
local CU = mercenaries.CU
local EL = "MercCamp"

local function log(s) System.LogAlways("[MercCamp] " .. tostring(s)) end
local function atlas() return mercenaries.CampAtlas end

-- ---------------------------------------------------------------- clip plumbing
--
-- SetScale and SetAlpha are PERCENT, and the atlas bakes a 1/ss shrink into every clip's
-- authored matrix, so a scale call has to re-apply that shrink or the clip jumps to ss
-- times its intended size. Same contract as the command interface - see docs/command-ui.md.

local function sc(m) return m * 100.0 / atlas().ss end

local function place(name, x, y, m, sy, a)
    CU.frame[name] = true
    local st = CU.shown[name]
    m = m or 1.0
    a = a or 100
    local meta = atlas().size[name]
    if meta and meta.c == false then
        x = x - meta.w * m / 2.0
        y = y - meta.h * (sy or m) / 2.0
    end
    if not st then
        pcall(function() UIAction.SetVisible(EL, -1, name, true) end)
        st = {}
        CU.shown[name] = st
    end
    if st.x ~= x or st.y ~= y then
        pcall(function() UIAction.SetPos(EL, -1, name, { x = x, y = y, z = 0 }) end)
        st.x, st.y = x, y
    end
    if st.m ~= m or st.sy ~= sy then
        pcall(function() UIAction.SetScale(EL, -1, name, { x = sc(m), y = sc(sy or m) }) end)
        st.m, st.sy = m, sy
    end
    if st.a ~= a then
        pcall(function() UIAction.SetAlpha(EL, -1, name, a) end)
        st.a = a
    end
end

-- Anything placed last frame and not this frame is hidden. Diffing rather than clearing
-- keeps a redraw to the handful of clips that actually moved.
local function sweep()
    for name in pairs(CU.shown) do
        if not CU.frame[name] then
            pcall(function() UIAction.SetVisible(EL, -1, name, false) end)
            CU.shown[name] = nil
        end
    end
end

-- Forward declarations: a Lua local is only in scope after its declaration, so a call above
-- one resolves to a nil global and silently does nothing.
local takeKey, giveKey
local rowSlots, wheelItems

-- ---------------------------------------------------------------- state, read from the mod
--
-- Which logistics flag says you own each improvement. Owning it and standing it up are two
-- different things: the camp builds itself out of these flags every time it is pitched, so
-- an upgrade you bought survives breaking camp and comes back with the next one.

local OWNS = {
    cart       = function(L) return (L.foodCartDays or 0) > 0 end,
    inn        = function(L) return (L.innDays or 0) > 0 end,
    hunter     = function(L) return (L.hunterSpots or 0) > 0 end,
    smithy     = function(L) return L.hasSmithy end,
    alchemy    = function(L) return L.hasAlchemy end,
    practice   = function(L) return L.hasPracticeYard end,
    house      = function(L) return L.hasHouse end,
    tower      = function(L) return L.hasTower end,
    archercart = function(L) return L.hasArcherCart end,
    gate       = function() local n = 0
                     pcall(function() n = mercenaries:GateCount() or 0 end)
                     return n > 0 end,
    wall       = function() return mercenaries:CUWallRuns(false) > 0 end,
    stonewall  = function() return mercenaries:CUWallRuns(true) > 0 end,
    -- The tent circle and your own tent are not bought; they stand for as long as the
    -- camp does.
    circle     = function() return mercenaries.CampActive end,
    tent       = function() return true end,
}

-- These are bought once and then placed by hand, as many times as you like. For them,
-- "built" means one is actually standing - the purchase flag only means you may place them.
local PLACED_KIND = { tower = true, archercart = true, gate = true, wall = true,
                      stonewall = true }

-- These stand at the camp CENTRE rather than on a tile of their own, so there is nothing to
-- relocate: moving them is moving the camp.
local CENTRE_PIECE = { house = true, tent = true }

local BUY = {
    cart = "LogiBuyFoodCart", inn = "LogiBuyInn", hunter = "LogiBuyHunter",
    smithy = "LogiBuySmithy", alchemy = "LogiBuyAlchemy", practice = "LogiBuyPractice",
    house = "LogiBuyHouse", tower = "LogiBuyTower", archercart = "LogiBuyArcherCart",
    wall = "LogiBuyWall", gate = "LogiBuyGate", stonewall = "LogiBuyCastleWall",
}

-- Buying a tower, a cart, a gate or a wall hands straight over to the game's own
-- aim-and-click placement, so those keep working exactly as they do from the console.
local PLACES = { tower = true, archercart = true, gate = true, wall = true, stonewall = true }

-- Taking an improvement down puts it back in storage rather than throwing it away: you
-- paid for it once. The logistics flag has to be cleared so the camp stops building it, so
-- the fact that you still own it is held here and saved alongside.
mercenaries.CampStowed = mercenaries.CampStowed or {}

-- Putting one back up again, without paying. Mirrors the LogiBuy* functions minus the
-- money; anything not listed here is a placed structure with its own build flow.
local RESTORE = {
    cart       = function(s, L) L.foodCartDays = s.UpgFoodCartDays end,
    inn        = function(s, L) L.innDays = s.UpgInnDays; L.innActive = true end,
    hunter     = function(_s, L) L.hunterSpots = math.max(1, L.hunterSpots or 0) end,
    smithy     = function(_s, L) L.hasSmithy = true end,
    alchemy    = function(_s, L) L.hasAlchemy = true end,
    practice   = function(_s, L) L.hasPracticeYard = true end,
    house      = function(_s, L) L.hasHouse = true end,
    archercart = function(_s, L) L.hasArcherCart = true end,
    -- These have no flag to restore; putting them back means running their own
    -- aim-and-click build again, which is free the second time because it was paid for.
    wall       = function(s) pcall(function() s:StartWallBuild() end) end,
    gate       = function(s) pcall(function() s:StartGatePlacement() end) end,
    tower      = function(_s, L) L.hasTower = true end,
}

function mercenaries:CUStowSave()
    local out = {}
    for k, v in pairs(self.CampStowed or {}) do
        local n = tonumber(v) or 0
        if n > 0 then out[#out + 1] = k .. ":" .. n end
    end
    table.sort(out)
    pcall(function() self:SaveString("MercCampStowed", table.concat(out, ",")) end)
end

function mercenaries:CUStowLoad()
    self.CampStowed = {}
    local raw
    pcall(function() raw = self:LoadString("MercCampStowed") end)
    for chunk in string.gmatch(raw or "", "[^,]+") do
        local k, n = string.match(chunk, "^([^:]+):(%d+)$")
        if k then self.CampStowed[k] = tonumber(n) end
    end
end

-- Everything standing goes into storage. Called when camp is broken: you paid for these,
-- so the next camp gets them back for nothing - and gets back as many as you had.
function mercenaries:CUStowStanding()
    self.CampStowed = self.CampStowed or {}
    for _, imp in ipairs(atlas().improvements) do
        local key = imp.key
        if RESTORE[key] then
            local n = 0
            if PLACED_KIND[key] then n = self:CUCount(key) or 0
            elseif self:CUStatus(key) ~= "none" then n = 1 end
            if n > 0 then
                self.CampStowed[key] = math.max(self.CampStowed[key] or 0, n)
            end
        end
    end
    self:CUStowSave()
end

function mercenaries:CUStatus(key)
    local L = self:LogiState()
    if PLACED_KIND[key] then
        -- standing, bought-but-none-up, or not bought at all
        if (self:CUCount(key) or 0) > 0 then return "built" end
        -- stone has no "bought" flag of its own: the purchase IS the build, so owning it
        -- means either one stands or one is in storage.
        local flag = ({ tower = L.hasTower, archercart = L.hasArcherCart })[key]
        if flag or ((self.CampStowed and self.CampStowed[key] or 0) > 0) then return "owned" end
        return "none"
    end
    local own = OWNS[key]
    if own and own(L) then
        return self.CampActive and "built" or "owned"
    end
    -- Owned, taken down, waiting to go back up.
    if (self.CampStowed and self.CampStowed[key] or 0) > 0 then return "owned" end
    return "none"
end

-- How many of an improvement are standing. Nothing caps these - build as many as you can
-- pay for. The tent rings are the one exception: the camp lays out one ring per cluster of
-- men, so their number follows the company rather than the purse.
function mercenaries:CUCount(key)
    local L = self:LogiState()
    if key == "hunter" then return L.hunterSpots or 0 end
    if key == "circle" then
        -- The camp's own list while it stands: cycling Relocate past the real number of
        -- rings addressed centres that did not exist, and those presses did nothing at all.
        -- The head-count estimate is only a fallback for when no camp is up.
        local n = #(self.CampClusterCenters or {})
        if n > 0 then return n end
        self:Recount()
        local men = _G.MercCount or 0
        return math.max(1, math.ceil(men / (self.CampClusterSize or 6)))
    end
    local n = 0
    if key == "gate" then pcall(function() n = self:GateCount() or 0 end)
    elseif key == "tower" then pcall(function() n = #(self.TowerStations or {}) end)
    elseif key == "archercart" then pcall(function() n = #(self.ArcherCarts or {}) end)
    elseif key == "wall" then
        n = self:CUWallRuns(false)
    elseif key == "stonewall" then
        n = self:CUWallRuns(true)
    else
        return (self:CUStatus(key) ~= "none") and 1 or 0
    end
    return n
end

-- One palisade means one continuous run of wall, however many stakes are in it; two
-- separate stretches around the camp are two palisades.
-- One palisade means one continuous run, however many stakes are in it. `stone` picks out
-- the castle curtain: its types sit above CastleWallBase in the same list.
function mercenaries:CUWallRuns(stone)
    local n = 0
    pcall(function()
        local base = self.CastleWallBase or 0
        for _, r in ipairs(self.WallRuns or {}) do
            local isStone = (r.wtype or 0) > base and base > 0
            if isStone == (stone == true) then n = n + 1 end
        end
        if self.WallMarks and #self.WallMarks >= 2 then
            local cur = (self.WallTypeIdx or 0) > base and base > 0
            if cur == (stone == true) then n = n + 1 end
        end
    end)
    return n
end

local function money()
    local m = 0
    pcall(function() m = player.inventory:GetMoney() or 0 end)
    return m
end

function mercenaries:CUInjured()
    local n = 0
    for _, ent in pairs(self.ActiveMercs or {}) do
        if ent then
            local w = ent.this and ent.this.id or ent.id
            local hurt = false
            pcall(function() hurt = self:LogiIsInjured(w) end)
            if hurt then n = n + 1 end
        end
    end
    return n
end

-- Every figure the logistics panel shows, in one place, so the panel cannot drift from
-- what the upkeep tick actually does.
function mercenaries:CUStats()
    local L = self:LogiState()
    self:Recount()
    local men = _G.MercCount or 0
    -- What the company EATS each day, not what is left to pay for after the upgrades have
    -- covered their share. Reporting the remainder read as zero the moment a food cart and
    -- a hunter's station between them covered everyone, and it disagreed with the "days of
    -- food" figure beside it, which LogiSupplyDays computes from the gross.
    local burn = math.ceil(men / self.FeedRatio)
    return {
        strength = men,
        injured  = self:CUInjured(),
        wagebill = self:LogiWageTotal(),
        morale   = math.floor((L.morale or 0) + 0.5),
        combat   = math.floor(self:LogiCombatPct() + 0.5),
        food     = L.food or 0,
        foodDays = self:LogiSupplyDays(L.food),
        drink    = L.drink or 0,
        drinkDays = self:LogiSupplyDays(L.drink),
        burn     = burn,
        coffer   = L.coffer or 0,
        purse    = money(),
    }
end

-- ---------------------------------------------------------------- the bottom row
--
-- Slot 1 is always the mode toggle and slot 2 is always the camp itself, so neither of the
-- two things you always need can page away. Improvements fill the rest.

rowSlots = function()
    local A = atlas()
    local out = { { kind = "mode" }, { kind = "camp" } }
    if CU.mode == "logi" then
        out = { { kind = "mode" } }
        for _, c in ipairs(A.logi) do
            out[#out + 1] = { kind = "logi", key = c.key, label = c.label }
        end
        return out
    end
    local pages = math.ceil(#A.improvements / A.page)
    for i = 1, A.page do
        local idx = (CU.page - 1) * A.page + i
        local imp = A.improvements[idx]
        if not imp then break end
        out[#out + 1] = { kind = "imp", key = imp.key, label = imp.label, idx = idx }
    end
    if pages > 1 then out[#out + 1] = { kind = "more", page = CU.page, pages = pages } end
    return out
end

wheelItems = function(slot)
    local A = atlas()
    if not slot then return nil end
    if slot.kind == "camp" then
        return mercenaries.CampActive and A.campWheelOn or A.campWheelOff
    end
    if slot.kind == "logi" then return A.logiWheels[slot.key] end
    if slot.kind == "imp" then return A.actions end
    return nil
end

-- An action that cannot be taken right now is dimmed rather than hidden, so the wheel keeps
-- the same shape and the same keys whatever state the camp is in.
function mercenaries:CUDisabled(slot, key)
    if not slot or slot.kind ~= "imp" then return false end
    local st = self:CUStatus(slot.key)
    if key == "buy" then return st ~= "none" end
    -- Construct stands up what is in storage; Relocate moves what is already standing.
    if key == "build" then return st ~= "owned" end
    if key == "relocate" then
        if PLACED_KIND[slot.key] or CENTRE_PIECE[slot.key] then return true end
        return st ~= "built"
    end
    if key == "remove" then return st ~= "built" end
    return false
end

-- ---------------------------------------------------------------- layout

CU.mode = CU.mode or "build"
CU.page = CU.page or 1
CU.hintEnabled = (CU.hintEnabled ~= false)

function mercenaries:CULayout()
    local A = atlas()
    if not A or not CU.elUp then return end
    local L = A.layout
    CU.frame = {}

    -- The corner nudge. Unlike the command interface this is NOT gated on having men:
    -- pitching a camp is exactly what you do when you have none yet.
    -- `open` moves the row to the Close prompt's own home beside the compass, rather than
    -- the player's chosen corner: both of this screen's modes fill the top right from y=20
    -- down, so the corner would put it half on top of the logistics panel. The setting
    -- governs the IDLE prompt, which is the one that was in the player's way.
    local function hintRow(lbl, open)
        local kn = A.hideKey[2]
        local btn = "hint_btn_" .. kn
        local bw = (A.size[btn] or { w = 21.33 }).w
        local lw = A.size[lbl].w
        local x, y
        if open then
            x, y = mercenaries:HintOpenXY(L)
        else
            x, y = mercenaries:HintRowXY(L)
        end
        place(btn, x - bw / 2, y)
        place(lbl, x - bw - L.hintGap - lw / 2, y)
    end

    if CU.placing then
        -- choosing a spot: nothing of ours on screen at all, not even the corner hint
        sweep()
        return
    end
    if not CU.on then
        if CU.hintEnabled and (mercenaries.HintsOn ~= false) then
            hintRow("hint_lbl_open")
        end
        sweep()
        return
    end
    -- Open: the wheel's own Return spoke carries U, so the corner only speaks when the
    -- wheel is shut.
    if not CU.open then hintRow("hint_lbl", true) end

    self:CUDrawPanels()
    self:CUDrawRow()
    sweep()
end

mercenaries.CUDeferred = function() mercenaries:CULayout() end

-- The element carries the nudge as well as the screen, so with the nudge off and the
-- screen closed there is nothing for it to draw and it comes down entirely.
function mercenaries:CUHintUpdate()
    if not atlas() or CU.on then return end
    self:HintLoad()
    if CU.hintEnabled and (mercenaries.HintsOn ~= false) then
        if self:CUElement(true) then
            Script.SetTimerForFunction(600, "mercenaries.CUDeferred")
        else
            self:CULayout()
        end
    else
        self:CUElement(false)
    end
end

function mercenaries:CUHint()
    CU.hintEnabled = not CU.hintEnabled
    self:CUHintUpdate()
    log("camp nudge " .. (CU.hintEnabled and "on" or "off"))
end

-- ---------------------------------------------------------------- input

function mercenaries:CUKey(i)
    log("key " .. tostring(i) .. " on=" .. tostring(CU.on) .. " open=" .. tostring(CU.open)
        .. " mode=" .. tostring(CU.mode) .. " placing=" .. tostring(CU.placing))
    -- While aiming, the keyboard can do what the mouse does. Left and right click reach the
    -- placement code as combat actions, which may not fire at all without a weapon drawn;
    -- these keys ride the same route as the rest of this screen, which is known to arrive.
    -- The key fallback is for this screen's own placements; a wall build has its own
    -- handling and must not have 1 and 2 taken out from under it.
    if CU.placing and self.ActivePlacement then
        if i == 1 then
            log("confirm by key")
            pcall(function() self:ConfirmPlacement() end)
        elseif i == 2 then
            log("cancel by key")
            pcall(function() self:CancelPlacement() end)
            pcall(function() self:EndPlacement() end)
            CU.placing = false
            pcall(function() self.ActionLog = false end)
            self:CUShow()
        end
        return
    end
    if not CU.on then return end
    local slots = rowSlots()
    if CU.open then
        local items = wheelItems(slots[CU.open])
        local it = items and items[i]
        if it then self:CUAct(slots[CU.open], it.key) end
        return
    end
    local d = slots[i]
    if not d then return end
    if d.kind == "mode" then
        CU.mode = (CU.mode == "logi") and "build" or "logi"
        CU.page, CU.open = 1, nil
        self:CULayout()
        return
    end
    if d.kind == "more" then
        local pages = math.ceil(#atlas().improvements / atlas().page)
        CU.page = (CU.page % pages) + 1
        self:CULayout()
        return
    end
    CU.open = i
    self:CULayout()
end

-- U: open, back out of a wheel, close.
function mercenaries:CUToggle()
    if not CU.on then self:CUShow() return end
    if CU.open then CU.open = nil self:CULayout() return end
    self:CUHide()
end

-- ---------------------------------------------------------------- actions

function mercenaries:CUAct(slot, key)
    if key == "return" then CU.open = nil self:CULayout() return end

    if slot.kind == "camp" then
        log("camp action: " .. tostring(key) .. " (active=" .. tostring(self.CampActive) .. ")")
        if key == "pitch" then
            self:CUPitch()
        elseif key == "break" then
            -- BreakMercCamp stows what stands, whichever route asked for it
            pcall(function() self:BreakMercCamp() end)
        elseif key == "recall" then
            pcall(function() self:CampReturnAll() end)
        end
        CU.open = nil
        self:CULayout()
        return
    end

    if slot.kind == "logi" then
        -- Deliver opens the game's own transfer window onto a chest, the way the wardrobe
        -- does; the quartermaster's Skald panel cannot be used from here, because it needs
        -- his soul and a standing camp. See mercenaries_delivery.lua.
        if key == "give" and (slot.key == "rations" or slot.key == "drink") then
            local kind = (slot.key == "rations") and "food" or "drink"
            CU.open = nil
            self:CUHide()
            pcall(function() self:DelOpen(kind) end)
            return
        end
        local F = {
            rations = { take = "LogiPanelFood", buy = "LogiBuyFood" },
            drink   = { take = "LogiPanelDrink", buy = "LogiBuyDrink" },
            wages   = { pay = "LogiToggleWithholdWages", hold = "LogiToggleWithholdWages" },
            coffer  = { ["in"] = "LogiDepositCoffer", out = "LogiWithdrawCoffer" },
        }
        local fn = (F[slot.key] or {})[key]
        if fn and self[fn] then pcall(function() self[fn](self) end) end
        self:CULayout()
        return
    end

    if slot.kind ~= "imp" then return end
    if self:CUDisabled(slot, key) then
        Game.SendInfoText(key == "relocate" and 'merc_camp_cant_move' or 'merc_camp_cant_here',
                          false, 0, 3)
        return
    end

    if key == "buy" then
        local fn = BUY[slot.key]
        if fn and self[fn] then
            -- Buying a tower, cart, gate or wall hands straight over to its own aiming, so
            -- this is a placement like any other: mark it as one BEFORE hiding, or the hide
            -- gives the frame back to the command interface in the middle of the build.
            if PLACES[slot.key] then
                CU.placing = true
                self:CUArmPlaceWatch()
            end
            pcall(function() self[fn](self) end)
            if PLACES[slot.key] then self:CUHide() return end
        end
    elseif key == "remove" then
        local idx = self:CURemovableIndex(slot.key)
        if idx then pcall(function() self:LogiRemoveUpgrade(idx) end) end
        -- Into storage, not onto the fire: you paid for it, so it can go back up for free.
        if RESTORE[slot.key] then
            self.CampStowed = self.CampStowed or {}
            local had = (PLACED_KIND[slot.key] and (self:CUCount(slot.key) or 0)) or 1
            self.CampStowed[slot.key] = math.max(self.CampStowed[slot.key] or 0,
                                                 math.max(had, 1))
            self:CUStowSave()
            Game.SendInfoText('merc_camp_stowed', false, 0, 4)
        end
    elseif key == "build" or key == "relocate" then
        -- Standing a stowed improvement back up costs nothing - it was bought once.
        if (self.CampStowed and self.CampStowed[slot.key] or 0) > 0 and RESTORE[slot.key] then
            self.CampStowed[slot.key] = self.CampStowed[slot.key] - 1
            self:CUStowSave()
            pcall(function() RESTORE[slot.key](self, self:LogiState()) end)
            pcall(function() self:LogiSave() end)
            Game.SendInfoText('merc_camp_restored', false, 0, 4)
        end
        -- Both are the same gesture: aim a projection at the ground and put it there. The
        -- spot is remembered per improvement and overrides the camp's automatic layout for
        -- that one station.
        if self:CUPlaceBegin(slot.key, slot.label) then return end
        -- Nothing placeable about this one - stand it up where the camp decides.
        if not self.CampActive then
            self:CUPitch()
        else
            pcall(function() self:LogiRebuildCampForUpgrade() end)
        end
    end
    CU.open = nil
    self:CULayout()
end

function mercenaries:CURemovableIndex(key)
    for i, spec in ipairs(self.UpgRemovable or {}) do
        if spec.key == key then return i end
    end
    return nil
end

-- Pitch the camp where the player stands. A camp with nobody in it is still a camp: the
-- player tent goes up on its own, which is the whole point of being able to make one before
-- there is a company to put in it.
function mercenaries:CUPitch()
    if self.CampActive then
        Game.SendInfoText('merc_info_camp_already_active', false, 0, 3)
        return
    end
    -- Where the player STANDS, not seven metres behind them: with auto-build off there may
    -- be nothing in the camp but their own tent, and it has to land where they chose.
    -- The camp wants { x, y, z, ang }: the player's spot, facing the way they face.
    local pos
    pcall(function()
        local p = player:GetWorldPos()
        local a = player:GetWorldAngles()
        -- `fresh` marks this as a new pitch rather than the same camp going back up,
        -- so the previous camp's defences are left where they stood.
        pos = { x = p.x, y = p.y, z = p.z, ang = (a and a.z) or 0, fresh = true }
    end)
    if not pos then
        pcall(function() pos = self:GetSafeSpawnPosition(player, 7) end)
    end
    if not pos then
        log("pitch: no position for the camp")
        Game.SendInfoText('merc_info_camp_no_spot', false, 0, 3)
        return
    end
    log(string.format("pitch at %.1f, %.1f (solo allowed)", pos.x, pos.y))
    local ok, err = pcall(function() self:SpawnMercCamp(pos, false, true) end)
    log("pitch -> " .. (ok and ("active=" .. tostring(self.CampActive)) or tostring(err)))
end

-- ---------------------------------------------------------------- placing an improvement
--
-- Construct and Relocate both come down to choosing a spot. The mod already has a complete
-- aim-and-click placement framework (StartPlacement / GhostBuild / ConfirmPlacement, see
-- mercenaries_tower.lua), so this only has to describe WHAT is being placed and what to do
-- with the answer.
--
-- The answer goes into mercenaries.CampPlacedSpots, which CampStationSpot reads in
-- preference to the automatic grid tile. That is the whole mechanism: the camp still lays
-- itself out as a whole, but any station the player has put down keeps the spot they chose.

-- UI key -> the station name the camp builder knows it by.
local STATION = {
    cart = "cart", inn = "inn", hunter = "hunt", smithy = "forge", alchemy = "alchemy",
}

-- What the projection looks like: one barrel, wherever the improvement will stand. The
-- real props are borrowed from a village at build time or assembled from a dozen pieces,
-- so a single marker is both honest and easier to aim with.
mercenaries.CampPlaceMarker = "objects/manmade/common_furniture/barrels/barrel_a.cgf"

function mercenaries:CUPlaceSpec(key, label)
    local station = STATION[key]
    return {
        parts = { { model = self.CampPlaceMarker, x = 0, y = 0, z = 0 } },
        -- PlaceTick passes this straight into GhostMove's arithmetic. Leaving it nil threw
        -- inside PlaceTick's pcall, so the ghost never moved off its parking spot 50m below
        -- the world and the projection was simply invisible.
        sink = 0.0,
        -- No material override: a single-submaterial ghost .mtl hides the submeshes of a
        -- multi-part prop (see docs/camp-forge.md), and the pink placeholder always draws
        -- the whole mesh, so the projection is legible either way.
        validMaterial = nil,
        isValid = function(s, pos) return s:CUSpotIsValid(pos) end,
        atMax   = function() return false end,
        confirm = function(s, pos, angle)
            s:CUPlaceConfirm(key, station, pos, angle)
        end,
        -- Right-click backs out. The screen was hidden to clear the view for aiming, so
        -- bring it back rather than leaving the player looking at nothing.
        onCancel = function(s)
            Script.SetTimerForFunction(150, "mercenaries.CUReopen")
        end,
        info = { placing = 'merc_camp_place_aim',   already = 'merc_camp_place_aim',
                 aim = 'merc_camp_place_aimfirst',  blocked = 'merc_camp_place_aimfirst',
                 limit = 'merc_camp_cant_here',     raised = 'merc_camp_place_done',
                 cancelled = 'merc_camp_place_cancel' },
    }
end

-- Anywhere the player aims. This is deliberately NOT TowerSpotIsValid: that refuses any
-- spot within TowerCampClearRadius of a camp prop, which is the right rule for a watchtower
-- and exactly the wrong one here - a tent ring or a smithy belongs INSIDE the camp, so every
-- sensible spot was refused, the click reported "blocked", and nothing happened.
--
-- Keeping it always-valid also means the ghost never flips to the pink invalid material, so
-- the projection shows the prop's own texture throughout.
function mercenaries:CUSpotIsValid(pos)
    return pos ~= nil
end

-- Moving one thing rebuilds the camp, and a rebuild re-derives everything that is not
-- pinned - which is how moving a single tent ring shuffled the rest. Pinning what is
-- standing first means the rebuild reproduces it exactly and only the moved piece moves.
function mercenaries:CUPinLayout()
    self.CampCirclePlaced = self.CampCirclePlaced or {}
    for i, c in ipairs(self.CampClusterCenters or {}) do
        if not self.CampCirclePlaced[i] then
            self.CampCirclePlaced[i] = { x = c.x, y = c.y, z = c.z }
        end
    end
    if not self.CampTrainPlaced and self.CampTrainCenter then
        local t = self.CampTrainCenter
        self.CampTrainPlaced = { x = t.x, y = t.y, z = t.z }
    end
    -- stations keep their own tiles already (CampStationTiles), so they need nothing here
    pcall(function() self:CampSaveCircles() end)
end

function mercenaries:CUPlaceConfirm(key, station, pos, angle)
    CU.placing = false
    pcall(function() self.ActionLog = false end)
    -- pin everything that stands, THEN move the one piece that was chosen
    pcall(function() self:CUPinLayout() end)
    if key == "circle" then
        self.CampCirclePlaced = self.CampCirclePlaced or {}
        self.CampCirclePlaced[CU.circleIdx or 1] = { x = pos.x, y = pos.y, z = pos.z }
        pcall(function() self:CampSaveCircles() end)
        Game.SendInfoText('merc_camp_ring_moved', false, 0, 4)
        station = nil
    end
    if key == "practice" then
        -- The practice yard is positioned off CampTrainCenter, not a station tile.
        self.CampTrainPlaced = { x = pos.x, y = pos.y, z = pos.z }
        self.CampTrainCenter = { x = pos.x, y = pos.y, z = pos.z }
        pcall(function() self:CampSaveCircles() end)
        station = nil
    end
    if station then
        self.CampPlacedSpots = self.CampPlacedSpots or {}
        self.CampPlacedSpots[station] = { x = pos.x, y = pos.y, z = pos.z, ang = angle or 0 }
        pcall(function() self:CampSavePlacedSpots() end)
    end
    -- Placement is over: one improvement, one spot.
    pcall(function() self:EndPlacement() end)
    -- Stand it up where it was just put. The camp rebuilds itself out of the logistics
    -- flags, and CampStationSpot now answers with the chosen spot instead of the grid tile.
    if self.CampActive then
        pcall(function() self:LogiRebuildCampForUpgrade() end)
    else
        self:CUPitch()
    end
    self:CUShow()
end

-- Construct (stand up something you own) and Relocate (move something already standing) are
-- the same gesture; the only difference is whether it was up when you started.
-- Tower, cart, gate and wall end their placement through their own code, which never calls
-- CUPlaceConfirm - so without this the screen would stay hidden until U was pressed. Single
-- instance and capped: timer chains are serialised into saves, so one that re-arms forever
-- is a save-bloat bug waiting to happen (see docs/performance.md).
mercenaries.CUPlaceWatchArmed = false
mercenaries.CUPlaceWatchTicks = 0

mercenaries.CUPlaceWatch = function()
    local self = mercenaries
    local CU = self.CU
    if not CU.placing then
        self.CUPlaceWatchArmed = false
        return
    end
    self.CUPlaceWatchTicks = (self.CUPlaceWatchTicks or 0) + 1
    -- A wall is drawn in the wall BUILD MODE, not through StartPlacement, so
    -- ActivePlacement is nil for its whole duration. Reading that as "the placement ended"
    -- put the screen back up half a second into the run and broke placing a palisade.
    if not (self.ActivePlacement or self.WallBuildActive) then
        self.CUPlaceWatchArmed = false
        CU.placing = false
        pcall(function() self.ActionLog = false end)
        self:CUShow()
        return
    end
    if self.CUPlaceWatchTicks > 600 then         -- five minutes of aiming is not aiming
        self.CUPlaceWatchArmed = false
        CU.placing = false
        return
    end
    Script.SetTimerForFunction(500, "mercenaries.CUPlaceWatch")
end

mercenaries.CUReopen = function()
    -- Only ever a continuation of an aim the player started. The timer that arms this is
    -- serialised into a save, so without the placing test a load could bring the screen up
    -- on its own.
    if not mercenaries.CU.placing then return end
    if mercenaries.ActivePlacement then return end
    mercenaries.CU.placing = false
    mercenaries:CUShow()
end

-- Tower, cart, gate and wall have had their own aim-and-click since long before this
-- screen; Construct and Relocate hand straight over to it rather than to the barrel.
local OWN_PLACEMENT = {
    tower = "StartTowerPlacement", archercart = "StartArcherCartPlacement",
    gate = "StartGatePlacement", wall = "StartWallBuild",
    -- CastleBuild selects the stone type and THEN starts the build; StartWallBuild on its
    -- own would draw whatever type was last selected, which is a palisade.
    stonewall = "CastleBuild",
}

-- Starting a placement from this screen. Two things have to hold that did not always:
--
--   * The Player.OnAction hook has to be live, or left and right click reach nothing. It is
--     installed once, a second after gameplay starts, and anything that assigns
--     Player.OnAction without chaining replaces it. Re-applying is idempotent, so it is
--     done here rather than assumed.
--
-- Between them these cover the reported "the first placement ignores both mouse buttons,
-- everything after it works". Which of the two it was is not yet established - the log line
-- below reports the hook state and whether a stale placement had to be cleared, so the next
-- occurrence says so outright.
--   * No placement may already be active. StartPlacement returns immediately if one is,
--     leaving the previous ghost on screen and the new choice never begun.
function mercenaries:CUStartPlace(spec)
    CU.placing = true
    self:CUArmPlaceWatch()
    if self.UpdateOnAction then pcall(function() self.UpdateOnAction() end) end
    if self.ActivePlacement then
        log("clearing a placement that was still active")
        pcall(function() self:EndPlacement() end)
    end
    local ok, err = pcall(function() self:StartPlacement(spec) end)
    log("StartPlacement -> " .. (ok and tostring(self.ActivePlacement ~= nil) or tostring(err))
        .. " hooked=" .. tostring(self._onActionHooked))
    return self.ActivePlacement ~= nil
end

-- Relocate steps through the rings in turn: first press moves ring one, the next moves
-- ring two, wrapping when it runs out.
function mercenaries:CUArmPlaceWatch()
    -- Log every input while aiming. Left click reaches the placement code as
    -- attack_primary_mouse, which lives in the combat_base map and may only fire with a
    -- weapon drawn, so "left click does nothing" needs to say whether ANY action arrived.
    pcall(function() self.ActionLog = true end)
    self.CUPlaceWatchTicks = 0
    if self.CUPlaceWatchArmed then return end     -- one chain, never two
    self.CUPlaceWatchArmed = true
    Script.SetTimerForFunction(500, "mercenaries.CUPlaceWatch")
end

function mercenaries:CUCircleNext()
    local n = self:CUCount("circle")
    if n < 1 then return 1 end
    CU.circleNext = ((CU.circleNext or 0) % n) + 1
    return CU.circleNext
end

function mercenaries:CUPlaceBegin(key, label)
    log("place " .. tostring(key) .. ": station=" .. tostring(STATION[key])
        .. " alreadyPlacing=" .. tostring(self.ActivePlacement ~= nil))
    local own = OWN_PLACEMENT[key]
    if own and self[own] then
        CU.placing = true
        self:CUArmPlaceWatch()
        self:CUHide()
        if self.UpdateOnAction then pcall(function() self.UpdateOnAction() end) end
        if self.ActivePlacement then pcall(function() self:EndPlacement() end) end
        pcall(function() self[own](self) end)
        return true
    end
    if key == "circle" then
        CU.circleIdx = self:CUCircleNext()
        log("relocating tent ring " .. CU.circleIdx .. " of " .. self:CUCount("circle"))
        CU.placing = true              -- before the hide, or the hide gives the frame away
        self:CUHide()
        self:CUStartPlace(self:CUPlaceSpec(key, label))
        return true
    end
    if not STATION[key] and key ~= "practice" then
        Game.SendInfoText('merc_camp_cant_move', false, 0, 4)
        return false
    end
    CU.placing = true                  -- before the hide, as above
    self:CUHide()
    self:CUStartPlace(self:CUPlaceSpec(key, label))
    Game.SendInfoText('merc_camp_place_aim', false, 0, 5)
    return true
end

-- ---------------------------------------------------------------- input
--
-- This screen does not bind its own keys. It borrows the command interface's, which are
-- already bound, already proven to fire, and already come with the quick-slot filter that
-- stops 1-4 unsheathing a weapon.
--
-- Two routes were tried first and both failed, for reasons worth keeping:
--   * Console binds of our own. The bind went out, the command existed and ran when called
--     directly, and the key still did nothing. Never explained; the command interface's
--     identical binds work, so it is something about ours.
--   * Player.OnAction. The action arrives and can be consumed, but consuming it in Lua does
--     NOT stop the engine drawing the weapon: the action that draws IS action_qam_1..4,
--     the same one the row needs, and the only thing that stops it is the vanilla
--     no_qam_weapons filter - which also stops it reaching us. A dead end by construction.
--
-- BLSelect(1..4) and BLKey(1..6) forward here while this screen is up; see
-- mercenaries_blui.lua.

-- ---------------------------------------------------------------- keys
--
-- Console binds are the standalone fallback, exactly as the command interface does it; with
-- KCD2 Keybinder installed these are assigned through the game's own keybind options
-- instead. Any binding another mod holds is restored when the key is handed back.

mercenaries.CURestore = mercenaries.CURestore or {}
CU.held = CU.held or {}
CU.useConsoleBinds = (CU.useConsoleBinds ~= false)

takeKey = function(k, cmd)
    if not CU.useConsoleBinds or CU.held[k] then return end
    pcall(function() System.ExecuteCommand("bind " .. k .. " " .. cmd) end)
    CU.held[k] = true
end

giveKey = function(k)
    if not CU.held[k] then return end
    CU.held[k] = nil
    local back = mercenaries.CURestore[k]
    pcall(function()
        if back then System.ExecuteCommand("bind " .. k .. " " .. back)
        else System.ExecuteCommand("unbind " .. k) end
    end)
end

function mercenaries:CUAcquireKeys()
    -- The command interface's binds, held while this screen is up. They point at merc_bl_*,
    -- which forwards here (see BLKey / BLSelect), so nothing of ours needs binding at all.
    pcall(function() self:BLAcquireKeys() end)
    -- ...and its quick-slot filter, so 1-4 do not unsheathe a weapon. This is the only
    -- thing that stops the draw: the action that draws is the action the row rides on.
    local token = mercenaries.BL and mercenaries.BL.qamToken
    if token and not CU.qamHeld then
        CU.qamHeld = true
        pcall(function() player.inventory:CreateItem(token, 1, 1) end)
    end
    log("holding the command interface's keys and quick-slot filter")
    -- Does the command the bind points at actually exist? Running it here answers that in
    -- one line: CU.on is false at load, so CUKey logs its arrival and returns without
    -- touching anything. If no "key 1" line follows this, the console never learned the
    -- command and the bind had nothing to call.

end

function mercenaries:CUReleaseKeys()
    -- Aiming still needs the number row: 1 places, 2 cancels.
    if CU.placing then return end
    local token = mercenaries.BL and mercenaries.BL.qamToken
    if token and CU.qamHeld then
        CU.qamHeld = false
        -- only if the command interface is not holding it in its own right
        if not (mercenaries.BL and mercenaries.BL.qamBlocked) then
            pcall(function() player.inventory:DeleteItemOfClass(token, 99) end)
        end
    end
    -- If the command interface is coming back it re-takes its keys itself; if it is not,
    -- they go back to the game.
    if not CU.restoreBL then pcall(function() self:BLReleaseKeys() end) end
end

-- ---------------------------------------------------------------- element

function mercenaries:CUElement(want)
    if want == CU.elUp then return false end
    if want then
        pcall(function() System.SetCVar("wh_gfx_useSWF", 1) end)
        pcall(function() UIAction.UnloadElement(EL, -1) end)
        pcall(function() UIAction.ReloadElement(EL, -1) end)
        local ok, err = pcall(function() UIAction.ShowElement(EL, 0) end)
        CU.elUp, CU.shown, CU.frame = true, {}, {}
        log("ShowElement -> " .. (ok and "ok" or tostring(err)))
        return true                     -- caller must defer its first layout
    end
    CU.elUp, CU.shown, CU.frame = false, {}, {}
    pcall(function() UIAction.HideElement(EL, 0) end)
    return false
end

function mercenaries:CUShow()
    CU.placing = false
    if not atlas() then
        log("mercenaries_campatlas.lua did not load - run tools/make_camp.py")
        return
    end
    -- The two screens share the bottom of the frame, so only one of them can be up.
    CU.restoreBL = mercenaries.BL and mercenaries.BL.on or false
    if CU.restoreBL then pcall(function() self:BLHide() end) end
    -- Both screens keep a hint in the same corner; only one of them may speak at a time.
    if mercenaries.BL then
        -- Capture the ORIGINAL value once. Re-capturing on a later show read back the false
        -- we had just written, and the command interface's hint was then restored to "off"
        -- and never came back.
        if CU.restoreHint == nil then CU.restoreHint = mercenaries.BL.hintEnabled end
        mercenaries.BL.hintEnabled = false
        pcall(function() self:BLHintUpdate() end)
    end

    local fresh = self:CUElement(true)
    CU.on, CU.open = true, nil
    self:CUAcquireKeys()
    if fresh then
        -- The movie is built on first display; transforms sent in this same call would
        -- address clips that do not exist yet and silently no-op.
        Script.SetTimerForFunction(600, "mercenaries.CUDeferred")
    else
        self:CULayout()
    end
end

function mercenaries:CUHide()
    CU.on, CU.open = false, nil
    self:CUReleaseKeys()
    self:CUHintUpdate()                 -- falls back to the nudge, or tears it down
    if CU.placing then
        -- aiming: leave the command interface down too, and give nothing back until the
        -- spot is chosen or the choice is abandoned
        return
    end
    if mercenaries.BL and CU.restoreHint ~= nil then
        mercenaries.BL.hintEnabled = CU.restoreHint
        CU.restoreHint = nil
    end
    if CU.restoreBL then
        CU.restoreBL = false
        pcall(function() self:BLShow() end)
    else
        pcall(function() self:BLHintUpdate() end)
    end
end

function mercenaries:CUOnLoad()
    if not atlas() then return end
    CU.shown, CU.frame = {}, {}
    CU.qamHeld = false
    -- A placement that was running when the game was saved is not running now, but the
    -- watchdog timer that puts the screen back up afterwards IS serialised into the save
    -- (docs/performance.md). Left armed, it opened the screen a few seconds into a load,
    -- unasked.
    CU.on, CU.open, CU.placing = false, nil, false
    self.CUPlaceWatchArmed = false
    self:CUStowLoad()
    takeKey(atlas().hideKey[1], "merc_camp_ui")
    self:HintLoad()
    self:CUHintUpdate()
    log("camp screen ready on " .. tostring(atlas().hideKey[2]))
end

-- ---------------------------------------------------------------- drawing
--
-- Every name below is a MovieClip instance name from mercenaries_campatlas.lua, not the
-- name of the image inside it: several instances share one image, and it is the instance
-- that can be moved. Numbers are assembled from digit clips because the atlas is a bitmap
-- and nothing in it can have a figure written into it at runtime.

local function sz(n) return atlas().size[n] end

-- A figure is built from one clip per character POSITION, not one per character: an
-- instance is what can be moved, so "500" drawn from a shared set of digit clips would ask
-- the single "0" instance to be in two places and only the last would show.
local GLYPH = { [","] = "comma", ["/"] = "slash", ["+"] = "plus", ["-"] = "minus",
                ["%"] = "pct", ["d"] = "days", [" "] = "space" }

local function glyphName(field, pos, c)
    return "n_" .. field .. "_" .. pos .. "_" .. (GLYPH[c] or c)
end

local function digits(field, str, x, y)
    local cx = x
    for i = 1, #str do
        local nm = glyphName(field, i, str:sub(i, i))
        local s = sz(nm)
        if s then
            place(nm, cx + s.w / 2, y)
            cx = cx + s.w
        end
    end
    return cx - x
end

local function width(field, str)
    local w = 0
    for i = 1, #str do
        local s = sz(glyphName(field, i, str:sub(i, i)))
        if s then w = w + s.w end
    end
    return w
end

local function comma(n)
    local s = tostring(math.floor(n or 0))
    local out, c = "", 0
    for i = #s, 1, -1 do
        out = s:sub(i, i) .. out
        c = c + 1
        if c % 3 == 0 and i > 1 then out = "," .. out end
    end
    return out
end

-- Left edge of a clip, given where its centre has to go.
local function left(n, x, y, a)
    local s = sz(n)
    if s then place(n, x + s.w / 2, y, 1.0, 1.0, a) end
end

local function right(n, x, y, a)
    local s = sz(n)
    if s then place(n, x - s.w / 2, y, 1.0, 1.0, a) end
end

-- Right-aligned figure in its own column.
local function value(field, str, rightX, y)
    digits(field, str, rightX - width(field, str), y)
end

function mercenaries:CUDrawPanels()
    local A, L = atlas(), atlas().layout
    left("panel", L.hx - 8, L.panelY + sz("panel").h / 2)
    left("title", L.hx, L.hTitleY + sz("title").h / 2)

    if CU.mode == "logi" then
        self:CUDrawBooks()
        self:CUDrawUpgrades()
        return
    end

    left("lbl_purse", L.hx, L.hStat2Y + 9)
    value("purse", comma(money()), L.hx + L.statValDX, L.hStat2Y + 9)
    left("lbl_camp", L.hx, L.hCampY + 9)
    right(self.CampActive and "camp_yes" or "camp_no", L.hx + L.statValDX, L.hCampY + 9)
    left("lbl_improv", L.hx + 6, L.listY0 - 20)

    for i, imp in ipairs(A.improvements) do
        local p = "r" .. i .. "_"
        local y = L.listY0 + (i - 1) * L.listPitch
        local mid = y - 2 + (L.listPitch - 4) / 2.0
        local st = self:CUStatus(imp.key)
        if CU.focusIdx == i then
            left(p .. "sel", L.hx - 6, y - 3 + sz(p .. "sel").h / 2)
        end
        local dim = (st == "none") and 55 or 100
        place(p .. "ic", L.hx + L.listIconDX, mid, 1.0, 1.0, dim)
        left(p .. "nm", L.hx + L.listNameDX, mid, dim)
        -- fixed column, so the coloured squares line up down the panel
        left(p .. "pill_" .. st, L.hx + L.listPillDX, mid)
        local n = self:CUCount(imp.key)
        if n > 1 then
            local str = "x" .. n
            digits("c" .. i, str, L.hx + L.listCountDX - width("c" .. i, str), mid)
        end
    end
    self:CUDrawDetail()
end

-- The right panel in build mode: what the focused improvement is, what it costs and gives,
-- and how much ground the camp has left.
function mercenaries:CUDrawDetail()
    local A, L = atlas(), atlas().layout
    local imp = A.improvements[CU.focusIdx or 1]
    if not imp then return end
    local st = self:CUStatus(imp.key)
    left("panelD", L.bX, L.panelY + sz("panelD").h / 2)
    left("lbl_detail", L.bX + 22, L.bTitleY + 8)
    -- The icon sits beside the name rather than above it: half the height means the
    -- portrait layout no longer fits.
    place("d_" .. imp.key .. "_ic", L.bX + 56, L.panelY + 104)
    left("d_" .. imp.key .. "_nm", L.bX + 100, L.panelY + 92)
    left("dst_" .. st, L.bX + 100, L.panelY + 116)

    local y = L.panelY + 160
    left("dl_cost", L.bX + 22, y)
    local cost = imp.cost and self[imp.cost]
    if cost then
        local w = digits("cost", comma(cost), L.bX + 104, y)
        left("lbl_groschen", L.bX + 104 + w + 8, y)
    else
        left("lbl_free", L.bX + 104, y)
    end
    y = y + 34
    left("dl_effect", L.bX + 22, y)
    left("u_" .. imp.key .. "_bo", L.bX + 104, y)

    y = y + 44
    left("lbl_standing", L.bX + 22, y)
    y = y + 26
    local n = self:CUCount(imp.key)
    local w = width("standing", tostring(n))
    digits("standing", tostring(n), L.bX + 100, y)
    left("lbl_inthecamp", L.bX + 100 + w + 8, y)
end

-- The left panel in logistics mode.
function mercenaries:CUDrawBooks()
    local A, L = atlas(), atlas().layout
    local S = self:CUStats()
    local touched = {}
    if CU.open then
        local slot = rowSlots()[CU.open]
        local M = { rations = { "food", "burn" }, drink = { "drink" },
                    wages = { "wagebill" }, coffer = { "coffer", "purse" } }
        for _, k in ipairs((slot and slot.key and M[slot.key]) or {}) do touched[k] = true end
    end
    local y = L.statY0
    for _, sect in ipairs(A.stats) do
        left("sect_" .. string.gsub(sect.section, " ", "_"), L.hx + 6, y)
        y = y + L.statSectPitch
        for _, row in ipairs(sect.rows) do
            if touched[row.key] then
                left("statmark", L.hx - 2, y - 9 + sz("statmark").h / 2)
            end
            place("s_" .. row.key .. "_ic", L.hx + L.statIconDX, y)
            left("s_" .. row.key .. "_nm", L.hx + L.statNameDX, y)
            local v = S[row.key] or 0
            local str = comma(v)
            if row.key == "morale" then
                str = ((v >= 0) and "+" or "-") .. comma(math.abs(v))
            elseif row.key == "combat" then
                str = ((v >= 0) and "+" or "-") .. comma(math.abs(v)) .. "%"
            end
            value(row.key, str, L.hx + L.statValDX, y)
            if row.key == "morale" then
                local bx, by = L.hx + L.statNameDX, y + 13
                left("mbar_bg", bx, by + sz("mbar_bg").h / 2)
                local half = L.moraleBarW / 2.0
                local frac = math.max(-1.0, math.min(1.0, (S.morale or 0) / 100.0))
                local col = "good"
                if S.morale < 0 then col = (S.morale > -50) and "warn" or "bad" end
                local run = math.abs(frac) * half
                if run > 0.5 then
                    local x0 = bx + half + ((frac >= 0) and 0 or -run)
                    -- the master fill is half the track wide, so it scales to the run
                    place("mbar_" .. col, x0 + run / 2, by + L.moraleBarH / 2, run / half, 1.0)
                end
                left("mbar_mid", bx + half, by - 2 + sz("mbar_mid").h / 2)
                y = y + 14
            end
            y = y + L.statPitch
        end
        y = y + 6
    end
end

-- The right panel in logistics mode: what is standing, what it gives, and the supply line.
function mercenaries:CUDrawUpgrades()
    local A, L = atlas(), atlas().layout
    left("panelB", L.bX, L.panelY + sz("panelB").h / 2)
    left("lbl_bonuses", L.bX + 22, L.bTitleY + 8)
    local Lg = self:LogiState()
    -- Every improvement can be active at once, which is far more than this panel holds.
    -- Cut the list to what fits above the graph and count off the rest, rather than letting
    -- it run through the graph and out of the panel.
    local fit = math.max(1, math.floor((L.graphY - 26 - L.bListY0) / L.bPitch))
    local total = 0
    for _, imp in ipairs(A.improvements) do
        if self:CUStatus(imp.key) == "built" and A.bonus[imp.key] then total = total + 1 end
    end
    -- when the list IS cut, one row's worth goes to the "+N more" line so it does not land
    -- on the graph's heading
    local cap = (total <= fit) and fit or math.max(1, fit - 1)
    local by, slot = L.bListY0, 0
    for _, imp in ipairs(A.improvements) do
        if self:CUStatus(imp.key) == "built" and A.bonus[imp.key] and slot < cap then
            slot = slot + 1
            place("u_" .. imp.key .. "_ic", L.bX + L.bIconDX, by + 6)
            left("u_" .. imp.key .. "_nm", L.bX + L.bNameDX, by)
            left("u_" .. imp.key .. "_bo", L.bX + L.bNameDX, by + L.bBonusDY)
            local unit = A.bonus[imp.key].unit
            if unit == "days" or unit == "pct" then
                local str
                if unit == "days" then
                    local n = (imp.key == "cart") and (Lg.foodCartDays or 0) or (Lg.innDays or 0)
                    str = tostring(n) .. "d"
                else
                    str = "+" .. tostring((Lg.trainLevel or 0) * self.PracticePctPerLevel) .. "%"
                end
                value("u" .. slot, str, L.bX + L.bW - 26, by + 6)
            end
            by = by + L.bPitch
        end
    end
    if total > slot then
        local str = "+" .. (total - slot)
        local w = width("moreup", str)
        digits("moreup", str, L.bX + 22, by + 6)
        left("lbl_moreup", L.bX + 22 + w + 6, by + 6)
    end

    left("lbl_graph", L.bX + 22, L.graphY - 14)
    local gx, gy = L.bX + L.graphDX, L.graphY + L.graphH
    local hist = Lg.foodHistory or {}
    local top = 1
    for _, v in ipairs(hist) do if v > top then top = v end end
    for i = 1, 3 do left("ggrid", gx, gy - L.graphH * i / 3.0) end
    local burn = self:CUStats().burn
    for i, v in ipairs(hist) do
        if i <= A.graphDays then
            local bh = math.max(1, L.graphH * v / top)
            local bx = gx + (i - 0.5) * (L.graphW / A.graphDays)
            local nm = (v <= burn * 3) and ("g" .. i .. "_low") or ("g" .. i)
            -- the master bar is full height, so it scales down to the day's reading
            if sz(nm) then place(nm, bx, gy - bh / 2, 1.0, bh / L.graphH) end
        end
    end
    left("gbase", gx, gy)
    left("lbl_ago", gx, gy + L.graphLabelDY)
    right("lbl_today", gx + L.graphW, gy + L.graphLabelDY)
end

-- The bottom row and, when one is open, its wheel.
function mercenaries:CUDrawRow()
    local A, L = atlas(), atlas().layout
    local slots = rowSlots()
    local n = #slots
    local x0 = A.stageW / 2.0 - (n - 1) * L.btnPitch / 2.0

    -- what the detail panel describes is what the row points at
    CU.focusIdx = 1
    for i, d in ipairs(slots) do
        if d.kind == "imp" and (CU.open == i or ((not CU.open) and i == 3)) then
            CU.focusIdx = d.idx
        end
    end

    for i, d in ipairs(slots) do
        local p = (CU.mode == "logi") and ("lb" .. i .. "_") or ("b" .. i .. "_")
        local cx, cy = x0 + (i - 1) * L.btnPitch, L.rowY
        local m = (i == CU.open) and L.btnOpenScale or 1.0
        local lit = (i == CU.open)
                    or ((not CU.open) and d.kind == "imp" and d.idx == CU.focusIdx)
        place(lit and (p .. "ring") or (p .. "disc"), cx, cy, m)

        local icon, label, dim = nil, nil, 100
        if d.kind == "mode" then
            icon = (CU.mode == "logi") and "tab_to_build" or "tab_to_logi"
            label = (CU.mode == "logi") and "tab_lbl_build" or "tab_lbl_logi"
        elseif d.kind == "camp" then
            icon, label = "camp_ic", "camp_lbl"
        elseif d.kind == "more" then
            icon, label = p .. "i_more", p .. "t_more_" .. d.page
        elseif d.kind == "logi" then
            icon, label = p .. "i_" .. d.key, p .. "t_" .. d.key
        else
            local imp = A.improvements[d.idx]
            icon, label = p .. "i_" .. imp.key, p .. "t_" .. imp.key
            if self:CUStatus(imp.key) == "none" then dim = 55 end
        end
        if icon and sz(icon) then place(icon, cx, cy, m, m, dim) end
        if label and sz(label) then place(label, cx, cy + L.btnLabelDY, 1.0, 1.0, dim) end
        -- a warning under the name, for anything the atlas flagged
        if d.kind == "imp" then
            local note = p .. "x_" .. A.improvements[d.idx].key
            if sz(note) then place(note, cx, cy + L.btnLabelDY + 13) end
        end
        if not CU.open then
            place(p .. "chip", cx, cy + L.btnBadgeDY)
            place(p .. "k_" .. A.rowBind[i][2], cx, cy + L.btnBadgeDY)
        end
    end

    if not CU.open then return end
    local slot = slots[CU.open]
    local items = wheelItems(slot)
    if not items then return end
    local cx0 = x0 + (CU.open - 1) * L.btnPitch
    local cy0 = L.rowY + L.wheelDY
    local cnt = #items
    local pre = (slot.kind == "camp") and "cw" or ((slot.kind == "logi") and "lw" or "w")
    for j, it in ipairs(items) do
        local p = pre .. j .. "_"
        local ang = -math.pi / 2 + 2 * math.pi * (j - 1) / cnt
        local cx = cx0 + math.cos(ang) * L.wheelR
        local cy = cy0 + math.sin(ang) * L.wheelR
        local off = self:CUDisabled(slot, it.key)
        place(p .. "disc", cx, cy)
        local suffix = (slot.kind == "logi") and (slot.key .. "_" .. it.key) or it.key
        local icon, lbl = p .. "i_" .. suffix, p .. "t_" .. suffix
        if sz(icon) then place(icon, cx, cy, 1.0, 1.0, off and 62 or 100) end
        if off and sz(lbl .. "_off") then lbl = lbl .. "_off" end
        if sz(lbl) then place(lbl, cx, cy + L.wheelLabelDY) end
        place(p .. "chip", cx, cy + L.wheelBadgeDY)
        local kn = (it.key == "return") and A.hideKey[2] or A.wheelBind[j][2]
        place(p .. "k_" .. kn, cx, cy + L.wheelBadgeDY)
    end
end

function mercenaries:CUDiag()
    local A = atlas()
    log("atlas=" .. tostring(A ~= nil) .. " on=" .. tostring(CU.on)
        .. " elUp=" .. tostring(CU.elUp) .. " mode=" .. tostring(CU.mode))
    if A then
        log("rowBind=" .. tostring(#A.rowBind) .. " improvements=" .. tostring(#A.improvements)
            .. " page=" .. tostring(A.page))
    end
    local held = {}
    for k in pairs(CU.held or {}) do held[#held + 1] = k end
    table.sort(held)
    log("keys held: " .. table.concat(held, " "))
    local n = 0
    for _ in pairs(CU.shown or {}) do n = n + 1 end
    log("clips on screen: " .. n)
end

mercenaries:PlayerCommand("merc_camp_diag", "mercenaries:CUDiag()",
                          "Report the camp screen's state into the log")
mercenaries:PlayerCommand("merc_camp_ui", "mercenaries:CUToggle()",
                          "Open or close the camp screen")
mercenaries:PlayerCommand("merc_camp_hint", "mercenaries:CUHint()",
                          "Toggle just the [U] Camp nudge")
for i = 1, 10 do
    mercenaries:PlayerCommand("merc_camp_ui_k" .. i, "mercenaries:CUKey(" .. i .. ")",
                              "Camp screen slot " .. i)
end
