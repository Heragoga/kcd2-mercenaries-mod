-- Player-tent amenities: the personal chest by the bed, and a drying rack and a
-- smokehouse beside the tent. All three stand for the camp's lifetime and are
-- rebuilt with it. See docs/camp-amenities.md.

-- ---------------------------------------------------------------------------
-- The personal chest
--
-- A vanilla `Stash` linked to the player's own master chest by a "masterStash"
-- link - the same link the Zelejov inn chest uses in level data, so the camp
-- chest shares the one stash inventory rather than carrying a second one.

mercenaries.CampChestModel = "objects/characters/assets/chest/chest_rustic_a.cdf"

-- Where the chest sits relative to the BED (right/forward in the bed's own
-- frame). The sleeper lies along `right` (CampBedSOYawFixDeg), so `right` is
-- past the head/feet and `forward` is the narrow side - and the narrow side is
-- either the tent's centre pole or its wall, so the chest goes at the end.
--
-- `forward` is what moves it sideways as SEEN FROM THE BED: standing at the bed
-- looking down `right` at the chest, this frame's `forward` is the viewer's own
-- right hand (CampRelativeOffset's `right` is `forward` turned a quarter turn
-- anticlockwise, so the reverse turn takes the view direction back to it).
-- Nudged right twice by eye, 0.2m each time: 0.3 -> 0.5 -> 0.7.
mercenaries.CampChestOffset = { right = 1.55, forward = 0.7 }
-- A chest's open face is a quarter turn off its yaw. Flip the sign if it ends
-- up with its back to the tent.
mercenaries.CampChestYawFixDeg = 90

-- ---------------------------------------------------------------------------
-- Drying rack and smokehouse
--
-- Both are the butcher's own food-processing stations, rebuilt from
-- references/Prefabs/profession/butcher/butcher_dryer.xml and
-- butcher_smokeHouse.xml: a mesh, a `FoodProcessingTrigger` (the "E - use"
-- prompt and the filtered multi-select inventory) and a `SmartObjectHolder`
-- carrying the so_smokehouse smart entity, with the trigger linked to it. The
-- holder's brain is what actually dries/smokes - the trigger only forwards the
-- chosen items to it. Nothing here is level data, so it all spawns from Lua.
--
-- `trigger`/`foot` are in the station's own frame: `forward` is the mesh's own
-- +X, `right` its +Y (SpawnCampPropModel is a plain yaw - see CampPropFootHalf).
-- Both meshes present their working face along their own -Y, which is the
-- quarter turn SpawnCampAmenities adds when it points one back at the tent.
-- `foot` is measured off the .cgf rather than read from CampPropFoot, which
-- only covers the models tools/measure_camp_props.py scans.
mercenaries.CampFoodSOGuid = "13611b23-88fe-4ff1-98e5-a6f7135be645"

mercenaries.CampFoodStations = {
    {
        key = "dryer",
        model = "objects/manmade/structures/industrial/drying_house/drying_rack_a.cgf",
        -- The interactive variant of the rack's own material: same six
        -- submaterials in the same order, so SetMaterial cannot drop a submesh.
        material = "objects/manmade/structures/industrial/drying_house/drying_rack_a_interactive",
        soClass = "butcherDryer",
        isSmokehouse = "false",
        processType = "drying",
        useMessage = "@ui_use_dryer",
        filter = "food.meat.raw|food.fruit.apple|food.fruit.pear|food.mushroom.vegetable|"
              .. "food.meat.dryable|food.dairy.dryable|crafting_material.herb.dryable",
        trigger = { forward = -0.003, right = -0.065, z = 0.778, scale = 0.2935 },
        foot = { w = 0.57, h = 0.96, right = 0.22, forward = 0.01 },
    },
    {
        key = "smokehouse",
        -- The prefab hangs the .chr on an AnimObject (its door animates); the
        -- static .cgf beside it is the same mesh and needs no character slot.
        model = "objects/characters/assets/smokehouses/smokehouse_a.cgf",
        soClass = "butcherSmokehouse",
        isSmokehouse = "true",
        processType = "smoking",
        useMessage = "@ui_use_smokehouse",
        filter = "food.meat.raw|food.meat.dryable|food.dairy.dryable",
        trigger = { forward = -0.003, right = -0.454, z = 0.648, scale = 0.45 },
        foot = { w = 0.72, h = 0.88, right = 0.04, forward = 0.06 },
        smoke = { effect = "WH_Particels.smokes.smokehouse",
                  forward = 0.064, right = -0.461, z = 1.612 },
    },
}

-- Where the two stand, in the frame of whatever is at the camp's centre: the
-- tent's entrance (facingAngle + 130deg, see SpawnPlayerCampTent) or, with the
-- house upgrade bought, grid-forward (the house's door, see SpawnQuartermaster).
-- Both sit to the left, clear of the quartermaster on the right.
mercenaries.CampAmenityOffsets = {
    tent  = { dryer = { right = -3.6, forward =  1.0 },
              smokehouse = { right = -3.6, forward = -1.6 } },
    house = { dryer = { right = -4.6, forward =  1.2 },
              smokehouse = { right = -4.6, forward = -1.0 } },
}

local function aLog(s) System.LogAlways("[CampAmenities] " .. tostring(s)) end

-- ---------------------------------------------------------------------------

-- The player's master chest, the one every other chest of theirs shares an
-- inventory with. It is level data (one per level, "playerMasterChest_<guid>"),
-- so this is a whole-level class scan - run once per camp build and cached.
function mercenaries:AmenMasterChest()
    local cached = self.CampMasterChest
    if cached then
        local ok, p = pcall(function() return cached:GetWorldPos() end)
        if ok and p then return cached end
        self.CampMasterChest = nil
    end

    local found
    pcall(function()
        for _, s in pairs(System.GetEntitiesByClass("Stash") or {}) do
            local n = s.GetName and s:GetName()
            if n and string.find(string.lower(n), "playermasterchest", 1, true) then
                found = s
                break
            end
        end
    end)
    self.CampMasterChest = found
    return found
end

-- The camp's copy of the player's chest, beside the bed. `bedPos`/`bedAngle` are
-- the bed's own, and no ground snap is applied - the house's bed stands on a
-- raised deck, and the tent's is already snapped.
function mercenaries:SpawnCampChest(bedPos, bedAngle, trackList)
    if not bedPos then return nil end

    local master = self:AmenMasterChest()
    local pos = self:CampRelativeOffset(bedPos, bedAngle or 0, self.CampChestOffset)
    -- Face the open side back toward the tent's middle, so the chest is used
    -- from inside rather than through the canvas.
    local toward = math.atan2(bedPos.y - pos.y, bedPos.x - pos.x)
    local yaw = toward + math.rad(self.CampChestYawFixDeg or 0)

    local chest
    local ok, err = pcall(function()
        chest = System.SpawnEntity({
            class = "Stash",
            name = "MercCampChest_" .. tostring(math.random(100000, 999999)),
            position = pos,
            orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
            properties = {
                object_Model = self.CampChestModel,
                sPickPlaceAnimTag = "slaveChest+pickPlaceChest02",
                sWH_AI_EntityCategory = "Chest",
                esChestContextLabel = "empty",
                bOwnedByHome = false,
                bSaved_by_game = false,
                bSerialize = false,
            },
        })
    end)
    if not ok or not chest then
        aLog("chest spawn failed: " .. tostring(err))
        return nil
    end

    pcall(function() chest:SetAngles({ x = 0, y = 0, z = yaw }) end)
    pcall(function() chest:SetViewDistUnlimited() end)
    pcall(function() chest:RenderShadow(true) end)
    table.insert(trackList or self.CampEntities, chest.id)

    -- A "masterStash" link is how level data declares a shared chest, and it is
    -- kept here for the same reason - but it does NOT take when made from Lua:
    -- the stash's own component has already resolved its master by the time
    -- CreateLink runs, and re-reads nothing.
    if master then
        pcall(function() chest:CreateLink("masterStash", master.id) end)
    end

    -- So the sharing is done one level up instead, at the single function every
    -- vanilla path asks: Stash:GetInventoryToOpen. Overriding THAT (rather than
    -- Open, the first attempt) is what makes the chest read as the player's
    -- stash everywhere - Open, GetActions, and the look-at label, which is built
    -- from HasPlayerVisibleItems on the same inventory and is why an Open-only
    -- override opened full but displayed empty. The override is on this entity's
    -- own table, which inherits the class table rather than being it.
    chest.GetInventoryToOpen = function(this)
        local mid
        pcall(function() mid = this.stash:GetMasterInventory() end)
        if mid and mid ~= 0 then
            local valid = true
            pcall(function() valid = Framework.IsValidWUID(mid) and true or false end)
            if valid then return mid end
        end
        local m = mercenaries:AmenMasterChest()
        if m and m.GetInventoryToOpen then
            local id
            pcall(function() id = m:GetInventoryToOpen() end)
            if id and id ~= 0 then return id end
        end
        return this.inventoryId
    end

    -- With no master chest in the level the chest would quietly open as its own
    -- empty container, which reads as a bug. Say so instead.
    local vanillaOpen = chest.Open
    chest.Open = function(this, user)
        if not mercenaries:AmenMasterChest() then
            Game.SendInfoText("merc_info_chest_locked", false, 0, 4)
            return
        end
        return vanillaOpen(this, user)
    end

    aLog(master and "personal chest placed (sharing the player's stash inventory)"
                 or "personal chest placed, but no master chest found in this level")
    return chest
end

-- One food station: mesh, FoodProcessingTrigger, SmartObjectHolder, and for the
-- smokehouse its smoke. `yaw` is the station's own facing; the trigger and the
-- holder sit at the prefab's own local offsets from it.
function mercenaries:AmenSpawnFoodStation(spec, pos, yaw, trackList)
    if not (spec and pos) then return nil end
    local prefix = "MercCampFood" .. spec.key

    local mesh = self:SpawnCampPropModel(spec.model, pos, yaw, prefix, trackList)
    if not mesh then
        aLog(spec.key .. ": mesh failed, station not built")
        return nil
    end
    if spec.material then
        pcall(function() mesh:SetMaterial(spec.material) end)
    end
    -- The mesh may have been snapped down onto the ground; everything else hangs
    -- off where it actually landed.
    local base = pos
    pcall(function() base = mesh:GetWorldPos() end)

    -- The smart object. Its brain (so_smokehouse, via CampFoodSOGuid) is what
    -- runs the drying/smoking; `isSmokehouse` is the branch it reads on init,
    -- and the player is aligned to this entity for the animation - so its
    -- orientation has to be set at SPAWN, as a forward direction VECTOR.
    local holder
    pcall(function()
        holder = System.SpawnEntity({
            class = "SmartObjectHolder",
            name = prefix .. "SO_" .. tostring(math.random(100000, 999999)),
            position = base,
            orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
            properties = {
                guidSmartObjectType = self.CampFoodSOGuid,
                soclass_SmartObjectHelpers = spec.soClass,
                bSaved_by_game = false,
                bSerialize = false,
                Script = { Misc = "isSmokehouse:" .. spec.isSmokehouse },
            },
        })
    end)
    if not holder then
        aLog(spec.key .. ": SmartObjectHolder failed, nothing to process food with")
        return nil
    end
    pcall(function() holder:SetAngles({ x = 0, y = 0, z = yaw }) end)
    table.insert(trackList or self.CampEntities, holder.id)

    local t = spec.trigger
    local tpos = self:CampRelativeOffset(base, yaw, t)
    local trigger
    -- FoodProcessingTrigger is TriggerBase plus the tutorial popups and nothing
    -- else, so a plain ActionTrigger does the same job if the class ever turns
    -- out not to be spawnable by name - as long as its own action type, which
    -- defaults to sitting the player down on the linked smart object, is off.
    for _, cls in ipairs({ "FoodProcessingTrigger", "ActionTrigger" }) do
        local click = {
            bIsActive = true,
            InventoryMultiFilter = spec.filter,
            UseMessage = spec.useMessage,
            fZToleration = 2,
            Angle = { fAngleTolerance = 90 },
        }
        -- Only ActionTrigger has an action type, and its default sits the player
        -- down on the linked smart object; "None" falls through to the plain
        -- report-use TriggerBase does.
        if cls == "ActionTrigger" then click.esActionType = "None" end
        pcall(function()
            trigger = System.SpawnEntity({
                class = cls,
                name = prefix .. "Trigger_" .. tostring(math.random(100000, 999999)),
                position = tpos,
                scale = { t.scale, t.scale, t.scale },
                properties = {
                    bSaved_by_game = false,
                    bSerialize = false,
                    Click = click,
                    Script = { Misc = "foodProcessingType:" .. spec.processType },
                },
            })
        end)
        if trigger then
            if cls ~= "FoodProcessingTrigger" then aLog(spec.key .. ": fell back to " .. cls) end
            break
        end
    end
    if trigger then
        table.insert(trackList or self.CampEntities, trigger.id)
        -- TriggerBase forwards the chosen items to everything it links to, so
        -- this one link is the whole connection between prompt and brain.
        pcall(function() trigger:CreateLink("smartObject", holder.id) end)
    else
        aLog(spec.key .. ": trigger failed, the station stands but cannot be used")
    end

    if spec.smoke then
        local sp = self:CampRelativeOffset(base, yaw, spec.smoke)
        pcall(function()
            local fx = System.SpawnEntity({
                class = "ParticleEffect",
                name = prefix .. "Smoke_" .. tostring(math.random(100000, 999999)),
                position = sp,
                properties = { ParticleEffect = spec.smoke.effect,
                               bSaved_by_game = false, bSerialize = false },
            })
            if fx then table.insert(trackList or self.CampEntities, fx.id) end
        end)
    end

    if spec.foot and self.CampClaimFoot then
        self:CampClaimFoot(base, yaw, spec.foot, spec.key)
    end
    return mesh
end

-- Both food stations, beside whatever stands at the camp centre. Called from
-- SpawnMercCamp once the centre and its facing are settled.
function mercenaries:SpawnCampAmenities(center, facingAngle)
    if not center then return end

    local house = false
    pcall(function() house = self.LogiState and self:LogiState().hasHouse end)
    local entranceAngle = (facingAngle or 0) + (house and 0 or math.rad(130))
    local offsets = self.CampAmenityOffsets[house and "house" or "tent"]

    for _, spec in ipairs(self.CampFoodStations) do
        local off = offsets[spec.key]
        if off then
            local pos = self:CampRelativeOffset(center, entranceAngle, off)
            -- Both meshes present their working face along their own -Y, so a
            -- station whose front should look back at the tent is turned a
            -- quarter turn past that direction.
            local toward = math.atan2(center.y - pos.y, center.x - pos.x)
            self:AmenSpawnFoodStation(spec, pos, toward + math.pi / 2)
        end
    end
end

-- ==== tuning ====
-- All three of these are placed by eye against a tent nothing was measured
-- against, so both take a value and re-pitch the standing camp on its own
-- anchor - the same trick merc_camp_bed_yaw uses.

function mercenaries:AmenChestYawSet(line)
    local v = tonumber((self:CmdArgs(line))[1])
    if v == nil then
        System.LogAlways("[CampAmenities] chest yaw fix is " .. tostring(self.CampChestYawFixDeg)
                         .. " deg; usage: merc_camp_chest_yaw <degrees>")
        return
    end
    self.CampChestYawFixDeg = v
    aLog("chest yaw fix -> " .. tostring(v) .. " deg")
    if self.CampActive then pcall(function() self:LogiRebuildCampForUpgrade() end) end
end

function mercenaries:AmenChestOffsetSet(line)
    local a = self:CmdArgs(line)
    local right, forward = tonumber(a[1]), tonumber(a[2])
    local o = self.CampChestOffset
    if not (right and forward) then
        System.LogAlways(string.format(
            "[CampAmenities] chest is at right %.2f, forward %.2f (forward moves it sideways"
            .. " as seen from the bed); usage: merc_camp_chest <right> <forward>", o.right, o.forward))
        return
    end
    o.right, o.forward = right, forward
    aLog(string.format("chest -> right %.2f, forward %.2f", right, forward))
    if self.CampActive then pcall(function() self:LogiRebuildCampForUpgrade() end) end
end

function mercenaries:AmenOffsetSet(line)
    local a = self:CmdArgs(line)
    local key, right, forward = a[1], tonumber(a[2]), tonumber(a[3])
    local house = false
    pcall(function() house = self.LogiState and self:LogiState().hasHouse end)
    local set = self.CampAmenityOffsets[house and "house" or "tent"]
    if not (key and set[key] and right and forward) then
        System.LogAlways("[CampAmenities] usage: merc_camp_amenity <dryer|smokehouse> <right> <forward>")
        for k, o in pairs(set) do
            System.LogAlways(string.format("[CampAmenities]   %-11s right %.2f  forward %.2f", k, o.right, o.forward))
        end
        return
    end
    set[key].right, set[key].forward = right, forward
    aLog(string.format("%s -> right %.2f, forward %.2f", key, right, forward))
    if self.CampActive then pcall(function() self:LogiRebuildCampForUpgrade() end) end
end

mercenaries:DevCommand("merc_camp_chest_yaw", "mercenaries:AmenChestYawSet('%line')",
                   "Set the personal chest's yaw fix in degrees and re-pitch the camp")
mercenaries:DevCommand("merc_camp_chest", "mercenaries:AmenChestOffsetSet('%line')",
                   "Move the personal chest beside the bed and re-pitch the camp")
mercenaries:DevCommand("merc_camp_amenity", "mercenaries:AmenOffsetSet('%line')",
                   "Move the drying rack or smokehouse beside the tent and re-pitch the camp")
