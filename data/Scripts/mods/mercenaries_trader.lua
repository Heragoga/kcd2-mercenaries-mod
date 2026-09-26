-- The camp trader: a market stall, a sutler standing behind it, and a counter the player
-- can buy from and sell to. See docs/camp-trader.md.
--
-- The trade is the mod's own, not the game's shop screen, and that is not a shortcut - it is
-- MEASURED. `Shops` exposes eleven functions and not one of them opens the trade UI; the
-- only thing that does is a Skald sequence with Type="OpenShop" on an NPC the engine has
-- accepted as a shopkeeper. A runtime-spawned one is NOT accepted: in game,
-- Shops.GetShopDBIdByKeeper answered -1 for this sutler with a Shop entity standing and a
-- shopKeeper link on him. The engine resolves a keeper by walking its own shop-record list
-- (sub_152EDC8) asking each record "is this mine", and those records take their keeper from
-- the XGenAI linkable-object graph built at LEVEL LOAD. Entity.CreateLink writes a CryEntity
-- link; nothing in Lua writes the other. Shops.OpenInventoryForItem is no way round it
-- either - it resolves the same way and returns silently when there is no shop.
--
-- So what ships is the item-transfer window the food delivery and the wardrobe already use:
-- the player moves goods either way across the counter, and the deal is settled in real
-- groschen at real prices when the window closes. See docs/camp-trader.md.
--
-- Prices come from ItemManager's own item object where that answers, and otherwise from
-- mercenaries_price_data.lua, which is the game's `Price` column baked offline. That is
-- what makes "sell all your loot" work at all: the engine offers no way to price an
-- arbitrary item, which is the reason the war chest exists (LogiDepositCoffer's comment).

local function tLog(s) System.LogAlways("[Trader] " .. tostring(s)) end

-- ---------------------------------------------------------------- the sutler

mercenaries.TraderSoul        = "7a3d1f88-2c4b-4e6a-9f01-3b8c5d2e7c01"  -- soul_merc_trader
-- Deliberately NOT under the camp's "MercCamp" prop prefix. The stall props are
-- (MercCampTraderProp_, so ClearAnyLeftoverCamp takes them), but the sutler and his
-- counter are not props: the counter holds the stock and has to survive breaking camp.
-- Both still match the uninstall sweep's "^Merc%u".
mercenaries.TraderNamePrefix  = "MercTrader_"
mercenaries.TraderStockPrefix = "MercTraderStock_"
mercenaries.TraderClothing    = "9fa83a0e-2f43-420b-86dd-c20f1c4c2525"  -- kpri_bailiff
mercenaries.TraderWeapon      = "412d0219-c28e-4b67-8bbb-d6ee362d6623"  -- basic hunting sword

mercenaries.CampTrader = nil     -- { origin, ang, ids, npcId, npcName, stockId, post }

-- ---------------------------------------------------------------- the deal
--
-- What the player pays over the base price, and what the sutler pays under it. He follows an
-- army into the field, so his goods carry a markup and his offers are thin - but he is the
-- only buyer for miles, which is the whole point of him.
mercenaries.TraderBuyMargin  = 1.15
mercenaries.TraderSellMargin = 0.35

-- His purse. Deliberately deep: the feature exists so a company can empty its packs after a
-- battle without three trips to Kuttenberg. It refills on restock.
mercenaries.TraderPurseFull   = 25000
mercenaries.TraderRestockDays = 3

-- The counter is a Stash, and the transfer window is opened FOR the player, so it never
-- wants to be walked to - it sits under the stall where nobody can open it as a chest.
mercenaries.TraderStockDepth = 120.0
mercenaries.TraderStockPreset = "inventory_merc_trader_stock"
-- Only used for a save written before traderStockN existed: below this many classes the
-- counter is treated as having been emptied by the save rather than bought out.
mercenaries.TraderStockFloor = 6

-- Nothing tells Lua that the transfer window has closed (the same wall mercenaries_delivery
-- ran into), so "they are done" is read off the counter: this many quiet seconds with its
-- contents unchanged.
mercenaries.TraderTickMs = 1000
mercenaries.TraderSettle = 3
-- ...and because it cannot tell a closed window from a customer still making up his
-- mind, a settled deal does not end the watch: it re-snapshots and keeps going, so a
-- second armful across the same counter is charged for too. The watch stops after this
-- many quiet ticks with nothing moving at all.
mercenaries.TraderQuietMax = 30
mercenaries.TraderDeal   = nil        -- { before, sig, idle, ticks } while a window is open
mercenaries.TraderTickArmed = false

-- ---------------------------------------------------------------- the stall
--
-- Station frame, as the other camp stations use it: fwd = outward from the camp centre (so
-- the player walks up from -fwd), lat = +left, up = height above the ground-snapped spot,
-- rz = yaw in degrees on top of the station's own facing. At rz = 0 a mesh's +X points along
-- fwd and its +Y along lat, so rz = -90 turns a mesh's +Y to point outward.
--
-- The STRUCTURE is one authored mesh, not a pile of furniture. That is how the game builds a
-- market stall: `Prefabs/profession/seller/shop_outside.xml` - the prefab behind every
-- outdoor shop in Kuttenberg - is a single `shop_rustic_b.cgf` brush plus the shop's logic
-- ports, and `Prefabs/exteriorDecoration/shop_fisherman.xml` is the same mesh with fish and
-- barrels laid on it. The family is objects/manmade/structures/municipal/trading:
-- shop_rustic_a/b, shop_by_house_a/b, shop_fancy_a, shop_big_a, each with a matching
-- _counter piece for shops built into a house front. shop_rustic_b is the roadside one:
-- 3.32 wide, 1.07 deep, 2.70 tall, origin on the CUSTOMER edge with the body running +Y,
-- counter top at 0.97.
--
-- The dressing follows the fisherman's: goods on the counter at 0.97, things hung off the
-- frame around 2.0, barrels and crates on the ground either side. Every figure below is
-- measured out of the object paks, not guessed.
mercenaries.CampTraderStallModel = "objects/manmade/structures/municipal/trading/shop_rustic_b.cgf"
mercenaries.TraderCounterTop = 0.97

mercenaries.CampTraderLayout = {
    { n = "stall",    m = mercenaries.CampTraderStallModel,
      fwd =  0.00, lat =  0.00, up = 0.00, rz = -90 },

    -- ON THE COUNTER (top at 0.97), four pieces spread left to right as the player walks up:
    -- bread, a flask, his scales, a quiver. lat is the customer's LEFT, so the bread sits at
    -- -0.80 rather than out on the end of the counter.
    { n = "bread",    m = "objects/manmade/common_furniture/baskets/basket_b_bread.cgf",
      fwd =  0.55, lat = -0.80, up = 0.97, rz =  20 },
    { n = "flask",    m = "objects/manmade/task_specific_props/alchemy/ceramics/saving_potion_flask_ceramic_b.cgf",
      fwd =  0.45, lat = -0.20, up = 0.97, rz =  30 },
    { n = "scales",   m = "objects/manmade/task_specific_props/trade/scales_small_table.cgf",
      fwd =  0.60, lat =  0.55, up = 0.97, rz = -90 },
    { n = "quiver",   m = "objects/manmade/task_specific_props/combat/archery/quiver_with_arrows.cgf",
      fwd =  0.78, lat =  1.15, up = 0.97, rz =  10 },

    -- HUNG OFF THE FRAME, under the 2.69 roof. The herb bunch is modelled hanging DOWN from
    -- its origin (z -0.63..0.07), so that figure is the hook height, not the bottom.
    { n = "herbs",    m = "objects/manmade/task_specific_props/alchemy/herbs/herbs_hanging_a.cgf",
      fwd =  0.28, lat = -1.25, up = 2.05, rz =   0 },
}

-- Where the sutler stands: a step behind the stall, clear of its 1.04 m body and of the
-- weapon rack behind him. The awning is only as deep as the stall, so he stands in the open
-- the way the game's own market sellers do.
mercenaries.TraderPostOffset = { fwd = 1.55, lat = 0.0 }

-- ================================================================ prices

-- The packed table is 200 KB of string; it is walked once, on the first trade, and only if
-- the item object turns out not to answer for prices on its own.
mercenaries.TraderPrices = nil

function mercenaries:TraderBuildPriceTable()
    if self.TraderPrices then return self.TraderPrices end
    local map = {}
    local n = 0
    for _, blob in ipairs(self.PriceBlobs or {}) do
        local len = string.len(blob)
        local i = 1
        while i + 37 <= len do
            local guid = string.sub(blob, i, i + 31)
            local price = tonumber(string.sub(blob, i + 32, i + 37))
            if price then map[guid] = price; n = n + 1 end
            i = i + 38
        end
    end
    self.TraderPrices = map
    tLog("price table unpacked: " .. n .. " item classes")
    return map
end

-- Class GUIDs arrive dashed from ItemManager and are stored dashless.
function mercenaries:TraderPriceKey(cls)
    local s = string.lower(tostring(cls or ""))
    return (string.gsub(s, "%-", ""))
end

-- One unit of `cls` at full condition. `it` is the item object when there is one: it may
-- carry the engine's own current price, which already accounts for quality, so it is
-- preferred and the baked table is the floor under it.
function mercenaries:TraderBasePrice(cls, it)
    if it then
        local p
        pcall(function()
            local v = it.CurrentUnitPrice
            if type(v) == "function" then v = it:CurrentUnitPrice() end
            if type(v) ~= "number" then
                v = it.NewUnitPrice
                if type(v) == "function" then v = it:NewUnitPrice() end
            end
            if type(v) == "number" and v > 0 then p = v end
        end)
        if p then return p, "engine" end
    end
    local map = self:TraderBuildPriceTable()
    return map[self:TraderPriceKey(cls)] or 0, "table"
end

-- ================================================================ reading a counter

-- Every class in an inventory with its total count and mean condition. Unlike the gear
-- module's reader this keeps EVERYTHING - the point of the sutler is arbitrary loot - so it
-- cannot lean on the baked gear index to decide what counts.
function mercenaries:TraderReadInv(inv)
    local out = {}
    if not inv then return out end
    local t
    pcall(function() t = inv:GetInventoryTable() end)
    if type(t) ~= "table" then return out end
    for _, handle in pairs(t) do
        local it
        pcall(function() it = ItemManager.GetItem(handle) end)
        if type(it) == "table" and it.class then
            local key = self:TraderPriceKey(it.class)
            local amount = tonumber(it.amount) or 1
            local health = tonumber(it.health) or 1
            local row = out[key]
            if not row then
                row = { cls = it.class, amount = 0, health = 0, name = nil }
                pcall(function() row.name = ItemManager.GetItemName(tostring(it.class)) end)
                row.unit = self:TraderBasePrice(it.class, it)
                out[key] = row
            end
            -- Condition is averaged over the stack, weighted by how many are in it.
            row.health = (row.health * row.amount + health * amount) / (row.amount + amount)
            row.amount = row.amount + amount
        end
    end
    return out
end

function mercenaries:TraderSignature(contents)
    local parts = {}
    for key, row in pairs(contents) do
        parts[#parts + 1] = key .. "x" .. string.format("%.3f", row.amount)
    end
    table.sort(parts)
    return table.concat(parts, ";")
end

-- ================================================================ the counter Stash

-- How many item CLASSES the counter holds. This number is the whole save-loss detector:
-- a Stash spawned at runtime with Database.sGeneratedInventory serialises into the save,
-- and its entity and any real items the player put in come back - but the GENERATED stock
-- does not. The stall then re-opened holding nothing but the one thing that had been sold
-- to it. Nothing reports that loss, so it is read off the count.
function mercenaries:TraderStockCount(e)
    if not e then return 0 end
    local n = 0
    for _ in pairs(self:TraderReadInv(e.inventory)) do n = n + 1 end
    return n
end

-- Record what the counter holds now, so the next load can tell a save loss (the count
-- collapses on its own) from the player having bought the place out (the count was already
-- low when it was last written).
function mercenaries:TraderNoteStock(e)
    e = e or self:TraderStockEntity()
    if not e then return end
    local L = self:LogiState()
    L.traderStockN = self:TraderStockCount(e)
    pcall(function() self:LogiSave() end)
end

function mercenaries:TraderStockEntity()
    local st = self.CampTrader
    if not (st and st.stockId) then return nil end
    local e
    pcall(function() e = System.GetEntity(st.stockId) end)
    return e
end

-- The counter survives breaking camp, a save and a reload: it is the shop's stock, and
-- re-rolling it every time the camp goes back up would make the restock timer meaningless.
-- So a leftover one is adopted rather than replaced.
function mercenaries:TraderFindStock()
    local found
    pcall(function()
        for _, e in pairs(System.GetEntitiesByClass("Stash") or {}) do
            local nm = e and e.GetName and e:GetName()
            if nm and string.find(nm, self.TraderStockPrefix, 1, true) == 1 then
                found = found or e
            end
        end
    end)
    return found
end

function mercenaries:TraderSpawnStock(at, fresh)
    local old = nil
    if not fresh then
        old = self:TraderFindStock()
        if old then
            -- Adopt it, unless it came back from a save empty. `traderStockN` is what it
            -- held when it was last written; two classes of slack so a single stack
            -- vanishing for some other reason does not re-roll the whole stall. Comparing
            -- against that number, rather than just "is it empty", is what stops a player
            -- who bought the stall out getting it refilled by reloading.
            local now = self:TraderStockCount(old)
            local was = tonumber(self:LogiState().traderStockN)
            if was == nil then
                -- A save written before the count was tracked, so there is nothing to
                -- compare with: judge the counter on its own. Anything above a bare few
                -- classes is a stall that still has goods on it.
                if now >= self.TraderStockFloor then return old end
            elseif now + 2 >= was then
                return old
            end
            tLog(string.format("counter came back holding %d class(es) of %s - the save lost" ..
                               " its generated stock, re-rolling it", now, tostring(was or "?")))
        end
    end
    local name = self.TraderStockPrefix .. tostring(math.random(100000, 999999))
    local e
    pcall(function()
        e = System.SpawnEntity({
            class = "Stash", name = name,
            position = { x = at.x, y = at.y, z = at.z - self.TraderStockDepth },
            properties = {
                object_Model = "objects/characters/assets/chest/chest_rustic_a.cdf",
                sWH_AI_EntityCategory = "Chest",
                -- Saved on purpose, unlike the stall props: this one holds the stock and
                -- the goods the player has already sold him.
                bSaved_by_game = 1,
                bSerialize     = 1,
                bSkipAngleCheck = true,
                Database = { sGeneratedInventory = self.TraderStockPreset },
            },
        })
    end)
    if not e then
        tLog("counter failed to spawn - no stock")
        return old
    end

    -- Anything real that was on the old counter - what the player sold him, what he has
    -- not sold on yet - moves across. Only the generated stock is being replaced.
    if old and old.id ~= e.id then
        local moved = 0
        for _, row in pairs(self:TraderReadInv(old.inventory)) do
            local n = math.floor(row.amount + 0.5)
            if n > 0 then
                pcall(function() old.inventory:MoveItemOfClass(e.inventory:GetId(), row.cls, n, true) end)
                moved = moved + 1
            end
        end
        pcall(function() System.RemoveEntity(old.id) end)
        if moved > 0 then tLog("carried " .. moved .. " class(es) over from the old counter") end
    end

    tLog("counter stocked from " .. self.TraderStockPreset)
    self:TraderNoteStock(e)
    return e
end

-- Restock: throw the old counter away and roll a fresh one, and fill the purse back up.
-- Called on a day boundary from the logistics tick.
function mercenaries:TraderRestock(force)
    local L = self:LogiState()
    if not L.hasTrader then return false end
    local day = self:LogiUpkeepDay()
    if not force then
        local last = L.traderRestockDay
        if last ~= nil and (day - last) < self.TraderRestockDays then return false end
    end
    L.traderRestockDay = day
    L.traderPurse = self.TraderPurseFull
    local st = self.CampTrader
    if st then
        local old = self:TraderStockEntity()
        if old then pcall(function() System.RemoveEntity(old.id) end) end
        local e = self:TraderSpawnStock(st.origin, true)
        st.stockId = e and e.id or nil
    else
        -- No stall standing: drop the old stock so the next pitch rolls a new one.
        local old = self:TraderFindStock()
        if old then pcall(function() System.RemoveEntity(old.id) end) end
    end
    pcall(function() self:LogiSave() end)
    tLog("restocked (purse " .. self.TraderPurseFull .. ")")
    return true
end

-- ================================================================ building the stall

function mercenaries:SpawnCampTrader(center)
    if self.CampTrader then return true end
    center = center or self.CampCenter
    if not center then return false end

    local spot, ang = self:CampStationSpot("trader")
    if not spot then
        local avoid = {}
        if self.CampForge and self.CampForge.anvilPos then table.insert(avoid, self.CampForge.anvilPos) end
        if self.CampAlchemy and self.CampAlchemy.spot then table.insert(avoid, self.CampAlchemy.spot) end
        if self.CampHunt and self.CampHunt.origin then table.insert(avoid, self.CampHunt.origin) end
        if self.CampInn and self.CampInn.origin then table.insert(avoid, self.CampInn.origin) end
        if self.CampFoodCart and self.CampFoodCart.origin then table.insert(avoid, self.CampFoodCart.origin) end
        if #avoid == 0 then avoid = nil end
        spot, ang = self:ForgeFindFlattest(center, avoid)
    end
    if not spot then
        ang = -math.pi / 2
        spot = self:CampSnapToGround({ x = center.x + math.cos(ang) * 8,
                                       y = center.y + math.sin(ang) * 8, z = center.z })
    end

    -- The reserved tile was never tested against anything but the ground: a station on it
    -- could stand in a bush, against a tent ring, or 15 m out. Nudged clear, and leashed.
    if spot and self.CampNudgeClearOfStructures then spot = self:CampNudgeClearOfStructures(spot, 3.0) end
    if spot and self.CampLeashToCamp then spot = self:CampLeashToCamp(spot) end
    local F = { x = math.cos(ang), y = math.sin(ang) }
    local Lft = { x = -F.y, y = F.x }
    local st = { origin = spot, ang = ang, ids = {} }
    self.CampTrader = st

    for _, piece in ipairs(self.CampTraderLayout) do
        local w = { x = spot.x + F.x * piece.fwd + Lft.x * piece.lat,
                    y = spot.y + F.y * piece.fwd + Lft.y * piece.lat,
                    z = spot.z + (piece.up or 0) }
        -- Spawned directly rather than through SpawnCampPropModel, which ground-snaps every
        -- piece and would drop the scales and the sign off the stall. `spot` is already
        -- snapped, so `up` is a height above it - the same rule the food cart follows.
        local yaw = ang + math.rad(piece.rz or 0)
        local e
        pcall(function()
            e = System.SpawnEntity({
                class = "BasicEntity",
                name = "MercCampTraderProp_" .. tostring(math.random(100000, 999999)),
                position = w,
                orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
                properties = { object_Model = piece.m, bMissionCritical = false,
                               bSaved_by_game = false, bSerialize = false },
            })
        end)
        if e then
            pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw }) end)
            table.insert(st.ids, e.id)
        end
    end

    if self.CampLayoutClaim then self:CampLayoutClaim(spot, ang, self.CampTraderLayout, 1.0, "trader stall") end
    local stock = self:TraderSpawnStock(spot, false)
    st.stockId = stock and stock.id or nil

    self:SpawnTraderNpc(spot, ang, center)
    self:SpawnTraderShop(spot)

    -- First stall of the game gets a full purse and starts the restock clock.
    local L = self:LogiState()
    if L.traderPurse == nil then
        L.traderPurse = self.TraderPurseFull
        L.traderRestockDay = self:LogiUpkeepDay()
        pcall(function() self:LogiSave() end)
    end

    tLog(string.format("stall built (%d props, purse %d)", #st.ids, L.traderPurse or 0))
    return true
end

function mercenaries:SpawnTraderNpc(spot, ang, center)
    local st = self.CampTrader
    if not st then return end
    self:DespawnTraderNpc()

    local F = { x = math.cos(ang), y = math.sin(ang) }
    local Lft = { x = -F.y, y = F.x }
    local off = self.TraderPostOffset
    local pos = { x = spot.x + F.x * off.fwd + Lft.x * off.lat,
                  y = spot.y + F.y * off.fwd + Lft.y * off.lat,
                  z = spot.z }
    pcall(function() pos = self:FindValidGround(pos, spot.z) end)

    -- Facing the way a customer comes from, which is in from the camp centre.
    local faceAngle = math.atan2((center or spot).y - pos.y, (center or spot).x - pos.x)
    local name = self.TraderNamePrefix .. tostring(math.random(100000, 999999)) .. "_" .. self.TraderSoul

    local ok = pcall(function()
        System.SpawnEntity({
            class = "NPC", name = name, position = pos,
            orientation = { x = 0, y = 0, z = faceAngle },
            properties = self:NoSaveProps({ guidSharedSoulId = self.TraderSoul }),
        })
    end)
    if not ok then tLog("sutler spawn threw"); return end

    local ent = System.GetEntityByName(name)
    if not ent then tLog("sutler spawn failed (no entity after spawn)"); return end

    st.npcId, st.npcName = ent.id, name
    pcall(function() self:MakeImmortal(ent, "the sutler") end)
    -- His post, read by quartermaster_idle through GetQuartermasterPost(entity): he shares
    -- the quartermaster's brain, and that call answers per entity so the two do not walk to
    -- the same spot.
    st.post = { x = pos.x, y = pos.y, z = pos.z,
                faceX = (center or spot).x, faceY = (center or spot).y, faceZ = (center or spot).z }

    pcall(function() self:EnsureMercIsAlwaysRendered(ent) end)
    if ent.actor then
        pcall(function() ent.actor:EquipClothingPreset(self.TraderClothing) end)
        pcall(function() ent.actor:EquipWeaponPreset(self.TraderWeapon) end)
    end
    self:TraderInjectInteraction(ent)
    tLog("sutler spawned: " .. name)
end

-- quartermaster_idle.xml asks Lua where to stand once per cycle, with the entity in hand.
function mercenaries:TraderPostFor(ent)
    local st = self.CampTrader
    if not (st and st.post and ent) then return nil end
    if st.npcId and ent.id == st.npcId then return st.post end
    return nil
end

-- ================================================================ the engine shop (open)
--
-- The market-stall prefab (references/Prefabs/profession/seller/shop_market.xml) wires a
-- keeper to a shop with a single `shopKeeper` entity link, and the roadside-camp merchants
-- - whose keepers ARE spawned at runtime - carry bOwnerIsSpawned on the Shop entity and no
-- baked link at all. So the same two steps are taken here. Nothing in the mod depends on
-- them working; if they do, a Skald sequence with Type="OpenShop" becomes possible and the
-- player gets the game's own trade screen instead of the counter below. `merc_trader_probe`
-- is what says whether the engine took it.
mercenaries.TraderShopName = "merc_camp_trader"

function mercenaries:SpawnTraderShop(spot)
    local st = self.CampTrader
    if not st then return end
    local e
    pcall(function()
        e = System.SpawnEntity({
            class = "Shop",
            name = "MercCampTraderShop_" .. tostring(math.random(100000, 999999)),
            position = { x = spot.x, y = spot.y, z = spot.z },
            properties = { sShopName = self.TraderShopName, bOwnerIsSpawned = 1,
                           bSaved_by_game = false, bSerialize = false },
        })
    end)
    if not e then
        tLog("Shop entity did not spawn - the engine-shop route is closed, counter only")
        return
    end
    st.shopId = e.id
    local npc = st.npcId and System.GetEntity(st.npcId) or nil
    if npc then
        pcall(function() npc:CreateLink("shopKeeper", e.id) end)
        pcall(function() npc:CreateLink("owner", e.id) end)
    end
    tLog("Shop entity spawned id=" .. tostring(e.id) .. " - run merc_trader_probe to see if it registered")
end

-- ================================================================ the counter (trade)

function mercenaries:TraderCanTrade()
    local st = self.CampTrader
    if not st then return false end
    return self:TraderStockEntity() ~= nil
end

function mercenaries:TraderOpen()
    local e = self:TraderStockEntity()
    if not e then
        Game.SendInfoText('merc_trader_closed', false, 0, 3)
        return
    end

    -- A watch may still be running: it outlives the window on purpose, because nothing
    -- tells Lua the window shut. Walking up a second time inside that window used to be
    -- REFUSED here, which is the "trading again does nothing" bug - the dialogue consumed
    -- its token and no window opened. Settle whatever is outstanding instead (it no-ops if
    -- nothing moved, and charges for it if something did, so a re-open is not a free grab)
    -- and start a fresh snapshot.
    if self.TraderDeal then
        self:TraderSettleDeal(e, self:TraderReadInv(e.inventory))
        self.TraderDeal = nil
    end

    local before = self:TraderReadInv(e.inventory)
    self.TraderDeal = { before = before, sig = self:TraderSignature(before),
                        idle = 0, ticks = 0 }

    local header = "Trader"
    pcall(function()
        player.actor:OpenItemTransferStore(e.id, e.inventory:GetId(), "", header)
    end)
    local L = self:LogiState()
    self:LogiInfo("@merc_n_trpurse " .. math.floor(L.traderPurse or 0))

    if not self.TraderTickArmed then
        self.TraderTickArmed = true
        Script.SetTimerForFunction(self.TraderTickMs, "mercenaries.TraderTick")
    end
end

-- Self-arming poll, one chain ever - TraderTickArmed is the latch, and every exit drops it
-- so the next open can arm a fresh chain.
mercenaries.TraderTick = function()
    local self = mercenaries
    local D = self.TraderDeal
    if not D then self.TraderTickArmed = false; return end
    Script.SetTimerForFunction(self.TraderTickMs, "mercenaries.TraderTick")

    D.ticks = D.ticks + 1
    local e = self:TraderStockEntity()
    if not e then self.TraderDeal = nil; self.TraderTickArmed = false; return end

    local now = self:TraderReadInv(e.inventory)
    local sig = self:TraderSignature(now)

    -- Only the counter is watched: a transfer window moves goods, never coin, so the
    -- purse cannot be what says the player is still deciding.
    if sig ~= D.sig then
        D.sig, D.idle = sig, 0
        return
    end
    D.idle = D.idle + 1
    if D.idle == self.TraderSettle then
        self:TraderSettleDeal(e, now)
        -- Settled, but the window may still be open. Start again from where the counter
        -- stands now (TraderSettleDeal can have moved goods back onto it), so nothing
        -- taken afterwards is free.
        D.before = self:TraderReadInv(e.inventory)
        D.sig = self:TraderSignature(D.before)
    elseif D.idle >= self.TraderQuietMax then
        self.TraderDeal = nil
        self.TraderTickArmed = false
    end
end

-- What changed on the counter, priced. Anything that LEFT it the player bought; anything
-- that arrived the player sold.
function mercenaries:TraderSettleDeal(e, after)
    local D = self.TraderDeal
    if not D then return end
    local before = D.before

    local cost, gain = 0, 0
    local boughtN, soldN = 0, 0
    local claw = {}          -- what could be taken back if the player cannot pay

    for key, was in pairs(before) do
        local now = after[key]
        local left = was.amount - ((now and now.amount) or 0)
        if left > 0.001 then
            local unit = (was.unit or 0) * (was.health or 1) * self.TraderBuyMargin
            cost = cost + unit * left
            boughtN = boughtN + left
            claw[#claw + 1] = { cls = was.cls, amount = left, unit = unit }
        end
    end
    for key, now in pairs(after) do
        local was = before[key]
        local added = now.amount - ((was and was.amount) or 0)
        if added > 0.001 then
            local unit = (now.unit or 0) * (now.health or 1) * self.TraderSellMargin
            gain = gain + unit * added
            soldN = soldN + added
        end
    end

    cost = math.floor(cost + 0.5)
    gain = math.floor(gain + 0.5)
    if boughtN <= 0 and soldN <= 0 then
        tLog("counter closed with nothing moved")
        return
    end

    local L = self:LogiState()
    local purse = math.floor(L.traderPurse or 0)
    local paid, taken = 0, 0

    if gain > cost then
        -- He owes the player, and can only pay what he is carrying.
        local owed = gain - cost
        paid = math.min(owed, purse)
        if paid > 0 then
            pcall(function() self:GiveMoney(paid) end)
            L.traderPurse = purse - paid
        end
        if paid < owed then
            Game.SendInfoText('merc_trader_broke', false, 0, 4)
        end
    elseif cost > gain then
        local owed = cost - gain
        local money = 0
        pcall(function() money = player.inventory:GetMoney() or 0 end)
        taken = math.min(owed, math.floor(money))
        if taken > 0 then
            pcall(function() player.inventory:RemoveMoney(taken) end)
            L.traderPurse = purse + taken
        end
        if taken < owed then
            local short = owed - taken
            local recovered = self:TraderClawBack(e, claw, short)
            -- Goods come back whole, so the last one clawed back is usually worth more
            -- than the debt it settles. Without this the player pays what they had AND
            -- loses the item - 713 groschen for nothing, in the run that found it.
            local over = math.floor(recovered - short + 0.5)
            local refund = math.min(over, taken)
            if refund > 0 then
                pcall(function() self:GiveMoney(refund) end)
                L.traderPurse = math.max(0, (L.traderPurse or 0) - refund)
                taken = taken - refund
            end
        end
    end

    -- What is left on the counter IS the stock now: write it down, so a stall the player
    -- bought out is not mistaken for one the save emptied.
    self:TraderNoteStock(e)
    pcall(function() self:LogiSave() end)

    tLog(string.format("deal settled: bought %d for %d, sold %d for %d (paid %d, taken %d, purse %d)",
        math.floor(boughtN + 0.5), cost, math.floor(soldN + 0.5), gain,
        paid, taken, math.floor(L.traderPurse or 0)))

    if paid > 0 then
        self:LogiInfo("@merc_n_trpaid " .. paid .. " @merc_n_trpurse " .. math.floor(L.traderPurse or 0))
    elseif taken > 0 then
        self:LogiInfo("@merc_n_trspent " .. taken .. " @merc_n_trpurse " .. math.floor(L.traderPurse or 0))
    end
end

-- The player walked off with more than they could pay for. Take the dearest goods back,
-- cheapest kept, until the debt is covered. Two things are rough about this on purpose:
-- condition is lost (the item is recreated on the counter, not moved), and the count is
-- taken by CLASS, so a piece the player already owned can be the one that goes. That is
-- the price of walking off with more than you can pay for.
function mercenaries:TraderClawBack(e, claw, owed)
    table.sort(claw, function(a, b) return (a.unit or 0) > (b.unit or 0) end)
    local recovered, pieces = 0, 0
    for _, row in ipairs(claw) do
        if recovered >= owed then break end
        local unit = row.unit or 0
        if unit > 0 then
            local want = math.min(row.amount, math.ceil((owed - recovered) / unit))
            local had = 0
            pcall(function() had = player.inventory:GetCountOfClass(row.cls) or 0 end)
            local n = math.min(want, had)
            if n > 0 then
                pcall(function() player.inventory:DeleteItemOfClass(row.cls, n) end)
                pcall(function() e.inventory:CreateItem(row.cls, 1, n) end)
                recovered = recovered + unit * n
                pieces = pieces + n
            end
        end
    end
    tLog(string.format("short by %d - took back %d piece(s) worth %d", owed, pieces, math.floor(recovered)))
    Game.SendInfoText('merc_trader_short', false, 0, 4)
    return recovered
end

-- ================================================================ the E prompt
--
-- OFF by default: the sutler has a dialogue role now, so pressing E opens trader_dialog and
-- a second hold-E "Trade" beside it would just be two doors into one room. Kept because it
-- is the only route that does not depend on the Skald chain - flip TraderUsePrompt to true
-- (or use merc_trader_open) if the dialogue ever fails to cast him.
--
-- Same contract as mercenaries_lookatinteraction.lua: vanilla's two gates first, then
-- vanilla's own actions, then ours appended - AddInteractorAction returns firstFast, which
-- is how the cheap survey pass knows to stop.
mercenaries.TraderUsePrompt = false

function mercenaries:TraderInjectInteraction(entity)
    if not entity then return end
    if not self.TraderUsePrompt then return end

    entity.TraderTradeAction = function(_self, _user)
        mercenaries:TraderOpen()
    end

    entity.GetActions = function(this, user, firstFast)
        if user == nil then return {} end
        if not (user.actor and user.actor:CanInteractWith(this.id)) then return {} end

        local output = {}
        if BasicAIActions and BasicAIActions.GetActions then
            output = BasicAIActions.GetActions(this, user, firstFast) or {}
        end
        if firstFast and #output > 0 then return output end

        if this.actor and not this.actor:IsDead() and not this.actor:IsUnconscious() then
            if AddInteractorAction(
                output, firstFast,
                Action()
                    :hint("ui_mercenary_trade_action")
                    :hintType(AHT_HOLD)
                    :action("use")
                    :uiOrder(1)
                    :func(this.TraderTradeAction)
                    :interaction(inr_loot)
            ) then return output end
        end
        return output
    end
end

-- ================================================================ teardown

function mercenaries:DespawnTraderNpc()
    local st = self.CampTrader
    if st and st.npcId then
        pcall(function() System.RemoveEntity(st.npcId) end)
        st.npcId, st.npcName, st.post = nil, nil, nil
    end
    -- Name sweep for strays: a camp standing through a save loses the tracked id.
    pcall(function()
        if not player then return end
        local pp = player:GetWorldPos()
        if not pp then return end
        for _, ent in pairs(System.GetPhysicalEntitiesInBoxByClass(pp, 200.0, "NPC") or {}) do
            if ent and ent.GetName and string.find(ent:GetName() or '', self.TraderNamePrefix, 1, true) == 1 then
                pcall(function() System.RemoveEntity(ent.id) end)
            end
        end
    end)
end

-- Breaking camp takes the stall down but NOT the counter: the stock and everything the
-- player has sold him belong to the company, not to this pitch.
function mercenaries:DespawnCampTrader()
    local st = self.CampTrader
    self.TraderDeal = nil
    if not st then
        self:DespawnTraderNpc()
        return
    end
    self:DespawnTraderNpc()
    for _, id in ipairs(st.ids or {}) do pcall(function() System.RemoveEntity(id) end) end
    if st.shopId then pcall(function() System.RemoveEntity(st.shopId) end) end
    self.CampTrader = nil
    tLog("stall taken down")
end

-- Selling the upgrade back, or uninstalling: the counter goes too.
function mercenaries:TraderDropStock()
    self:DespawnCampTrader()
    local old = self:TraderFindStock()
    while old do
        pcall(function() System.RemoveEntity(old.id) end)
        local next_ = self:TraderFindStock()
        if next_ and old and next_.id == old.id then break end
        old = next_
    end
    local L = self:LogiState()
    L.traderPurse, L.traderRestockDay, L.traderStockN = nil, nil, nil
end

-- ================================================================ console

function mercenaries:TraderProbeCmd()
    local st = self.CampTrader
    local function say(fmt, ...) System.LogAlways("[Trader] " .. string.format(fmt, ...)) end
    if not st then say("no stall standing"); return end
    say("stall at %.1f %.1f %.1f, %d prop(s)", st.origin.x, st.origin.y, st.origin.z, #(st.ids or {}))
    say("sutler id=%s  counter id=%s  Shop entity id=%s",
        tostring(st.npcId), tostring(st.stockId), tostring(st.shopId))

    -- Did the engine accept a runtime-spawned shopkeeper? ANSWERED, 2026-09-14: no.
    -- GetShopDBIdByKeeper came back -1 and IsLinkedWithShop null, and the disassembly says
    -- why - the keeper is resolved by walking the engine's shop record list and asking each
    -- record "is this my keeper", and those records bind their keeper from the XGenAI
    -- linkable-object graph, which is built at level load. Entity.CreateLink writes a
    -- CryEntity link, which is not the same thing, and no bind writes the other.
    -- The four lines below are kept so a future attempt can tell WHICH half is missing:
    -- the keeper binding alone, or the shop row / Shop entity as well.
    local dbid, linked, money = "nil", "nil", "nil"
    if st.npcId then
        pcall(function() dbid = tostring(Shops.GetShopDBIdByKeeper(st.npcId)) end)
        pcall(function() linked = tostring(Shops.IsLinkedWithShop(st.npcId)) end)
        pcall(function() money = tostring(Shops.GetShopMoney(st.npcId)) end)
    end
    say("keeper: GetShopDBIdByKeeper=%s  IsLinkedWithShop=%s  GetShopMoney=%s", dbid, linked, money)

    -- Did shop__mercenaries.xml load and did the Shop ENTITY register? If this answers
    -- >= 0 the table and the entity are fine and only the keeper binding is missing.
    local edb, elinked = "nil", "nil"
    if st.shopId then
        pcall(function() edb = tostring(Shops.GetShopDBIdByLinkedEntityId(st.shopId)) end)
        pcall(function() elinked = tostring(Shops.IsLinkedWithShop(st.shopId)) end)
    end
    say("shop entity: GetShopDBIdByLinkedEntityId=%s  IsLinkedWithShop=%s", edb, elinked)

    -- Did the link take at all, on either graph?
    local npc = st.npcId and System.GetEntity(st.npcId) or nil
    local nlinks, aiLinks = "nil", "nil"
    if npc then
        pcall(function() nlinks = tostring(npc:CountLinks()) end)
        pcall(function()
            local t = XGenAIModule.FindLinks(st.npcId, "shopKeeper")
            aiLinks = (type(t) == "table") and tostring(#t) or tostring(t)
        end)
    end
    say("links on the sutler: Entity.CountLinks=%s  XGenAIModule.FindLinks(shopKeeper)=%s",
        nlinks, aiLinks)

    local e = self:TraderStockEntity()
    local rows, total = 0, 0
    if e then
        for _, row in pairs(self:TraderReadInv(e.inventory)) do
            rows = rows + 1
            total = total + (row.unit or 0) * row.amount
        end
    end
    local L = self:LogiState()
    say("counter: %d class(es), stock worth %d; purse %d; last restock day %s",
        rows, math.floor(total), math.floor(L.traderPurse or 0), tostring(L.traderRestockDay))

    -- Which price route is live. `engine` means ItemManager answered and the baked table is
    -- only a fallback; `table` means the 200 KB blob is doing all the work.
    if e then
        local t
        pcall(function() t = e.inventory:GetInventoryTable() end)
        for _, handle in pairs(t or {}) do
            local it
            pcall(function() it = ItemManager.GetItem(handle) end)
            if type(it) == "table" and it.class then
                local p, how = self:TraderBasePrice(it.class, it)
                say("price route: %s (%s = %d)", how, tostring(it.class), math.floor(p))
                break
            end
        end
    end
end

function mercenaries:TraderStockCmd()
    local e = self:TraderStockEntity()
    if not e then System.LogAlways("[Trader] no counter"); return end
    local rows = {}
    for _, row in pairs(self:TraderReadInv(e.inventory)) do
        rows[#rows + 1] = string.format("  %-40s x%-5d  %d gr each",
            tostring(row.name or row.cls), math.floor(row.amount),
            math.floor((row.unit or 0) * (row.health or 1) * self.TraderBuyMargin))
    end
    table.sort(rows)
    System.LogAlways("[Trader] counter holds " .. #rows .. " class(es):")
    for _, r in ipairs(rows) do System.LogAlways(r) end
end

local function traderCmd(name, body, desc)
    pcall(function() System.AddCCommand(name, body, desc) end)
end

traderCmd("merc_trader_build",   "mercenaries:SpawnCampTrader()",
          "Build the trader's stall at the standing camp.")
traderCmd("merc_trader_remove",  "mercenaries:DespawnCampTrader()",
          "Take the trader's stall down (the counter and its stock stay).")
traderCmd("merc_trader_open",    "mercenaries:TraderOpen()",
          "Open the trade counter without walking to it.")
traderCmd("merc_trader_restock", "mercenaries:TraderRestock(true)",
          "Roll the trader a fresh stock and refill his purse.")
traderCmd("merc_trader_stock",   "mercenaries:TraderStockCmd()",
          "List what is on the trader's counter, with prices.")
traderCmd("merc_trader_probe",   "mercenaries:TraderProbeCmd()",
          "Report the stall, the counter, the purse, and whether the engine accepted the Shop entity.")
