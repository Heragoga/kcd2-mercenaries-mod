-- Bandit camp BUILDER - an in-game placement editor.
--
-- F5-F8 each own a CATEGORY. Pressing a category key selects it; pressing the same key again
-- CYCLES to the next variant within it. The ghost follows wherever you look. Left-click
-- places, right-click takes back the last thing placed.
--
--   F5  tents (incl. the player house)      F9   new camp (clear and start over)
--   F6  beds, stools, chairs, tables        F10  save camp
--   F7  fire, crates, chests, sacks...      F11  dump layout
--   F8  camp upgrades (all but the wall)
--
-- IMPORTANT: left/right click reach this through Player.OnAction as `attack_primary_mouse`
-- and `block`, and those only fire WITH A WEAPON DRAWN. That is a property of the input map
-- the placement engine has always used, not something this module can change - so draw a
-- weapon before building. merc_bcamp_place / merc_bcamp_undo do the same jobs from the
-- console if that is inconvenient.
--
-- Nothing here re-implements placement. It drives the existing generic engine in
-- mercenaries_tower.lua (StartPlacement / GhostBuild / PlaceTick / ConfirmPlacement) with a
-- spec rebuilt each time the selection changes, and the multi-part upgrades are placed by
-- calling their own spawn functions rather than by copying their geometry.

local function bLog(s) System.LogAlways("[BanditCamp] " .. s) end

mercenaries.BCampPieces = {}   -- undo stack: { kind=, label=, ents={id,...}, station=, pos= }
mercenaries.BCampCat    = 0    -- which category key is selected (0 = none yet)
mercenaries.BCampSel    = { 1, 1, 1, 1 }   -- per-category variant index

-- Tent meshes sit sideways to the aim point and need a quarter turn to square up. Judged by
-- eye in game: +90 was the wrong way and 180 was too far, so it is -90. The one number to
-- change if a mesh disagrees.
mercenaries.BCampTentYaw = -math.pi / 2

-- Upgrades are previewed with a plain barrel: they are multi-part structures assembled by
-- their own spawn functions, so there is no single mesh that honestly represents them, and a
-- barrel at the exact spot reads as "the thing lands here" without pretending to be a preview.
mercenaries.BCampUpgradeGhost = "objects/manmade/common_furniture/barrels/barrel_a.cgf"

-- ==== catalogues ====
-- `model` entries are plain meshes placed by SpawnCampPropModel.
-- `build` entries call a real spawn function; `ghost` is the mesh used to preview them, since
-- a multi-part structure cannot be previewed from a model path alone.
local T = "objects/manmade/"

function mercenaries:BCampCatalogue()
    if self._bcampCat then return self._bcampCat end

    local tents = {}
    for i, m in ipairs(self.CampTentVariants or {}) do
        tents[#tents + 1] = { label = "tent " .. i, model = m, yaw = self.BCampTentYaw }
    end
    if self.CampPlayerTentModel then
        tents[#tents + 1] = { label = "player tent", model = self.CampPlayerTentModel,
                              yaw = self.BCampTentYaw }
    end
    -- The house is a whole structure (shell, windows, foundation, bed, invisible collider
    -- walls), so it is built by its own function and only previewed by its shell mesh.
    tents[#tents + 1] = {
        label = "player HOUSE",
        ghost = (self.CampHouseParts and self.CampHouseParts[1] and self.CampHouseParts[1].model),
        build = function(s, pos, yaw) return s:SpawnCampHouse(pos, yaw) end,
    }

    local furniture = {
        { label = "bed",         model = self.CampModels.Bed,      so = self.CampBedSO },
        { label = "straw bed",   model = self.CampModels.BedStraw },
        { label = "chair",       model = self.CampModels.Chair,    so = self.CampChairSO },
        { label = "stool",       model = self.CampModels.Stool,    so = self.CampChairSO },
        { label = "log seat",    model = self.CampModels.Log,      so = self.CampChairSO },
        { label = "table big",   model = T .. "common_furniture/tables/table_shabby_d_160_rough.cgf" },
        { label = "table small", model = T .. "common_furniture/tables/table_shabby_d_80_rough.cgf" },
    }

    local loose = {
        -- The vanilla fireplace prefab: fire, particles and a real light. No seating ring -
        -- seats are furniture, placed individually on F6 where you actually want them.
        { label = "campfire (light)", fire = true,
          ghost = T .. "task_specific_props/food_processing/cooking/camp_cooking_c_old.cgf" },
        -- A standalone light. The lamp mesh alone does not illuminate anything - a bare .cgf
        -- has no light source - so a vanilla Light entity is spawned with it. Its properties
        -- are the ones already lifted from level data for the forge light, warm and small.
        { label = "torch / lamp (light)", model = T .. "common_illumination/lamp_table_rustic_a.cgf",
          light = { Radius = 4.0, fAttenuationBulbSize = 0.4,
                    Color = { clrDiffuse = { x = 0.85, y = 0.42, z = 0.15 }, fDiffuseMultiplier = 0.08 },
                    Options = { fVerticalClipDistanceDownward = 3, fVerticalClipDistanceUpward = 11 },
                    Shadows = { nCastShadows = 2 } },
          lightZ = 1.2 },
        { label = "weapon pile",  model = self.CampModels.WeaponStack },
        -- The big rustic chest, spawned as a Stash so it is actually lootable - the same
        -- class and model the personal-chest mod uses. CampModels.Chest is the small one.
        { label = "big chest (lootable)", stash = "Objects/characters/assets/chest/chest_rustic_a.cdf" },
        { label = "small chest",  model = self.CampModels.Chest },
        { label = "barrel",       model = T .. "common_furniture/barrels/barrel_a.cgf" },
        { label = "beer barrel",  model = T .. "common_furniture/barrels/barrel_beer.cgf" },
        { label = "arrow barrel", model = T .. "weapons/arrows/barrel_arrow_full_closed.cgf" },
    }
    for _, m in ipairs(self.CampTentClutterVariants or {}) do
        loose[#loose + 1] = { label = m:match("([^/]+)%.cgf$") or "clutter", model = m }
    end

    -- Upgrades. The wall is excluded on purpose - it has its own corner-marking builder.
    -- Forge and alchemy BORROW a vanilla Smithery / AlchemyTable that must already be loaded
    -- nearby; they return false and build nothing if there is none, which is reported rather
    -- than silently swallowed.
    -- `tile` is the CampStationSpot name each builder consults. Seeding it with the aim point
    -- is what pins these to EXACTLY where you are looking: called standalone they would
    -- otherwise fall back to their own "find the flattest nearby patch" scan and wander off
    -- by several metres. Every one of them previews as a barrel (BCampUpgradeGhost).
    -- `despawn` is the upgrade's OWN teardown, carried on the item rather than looked up by
    -- label. An earlier version matched label strings and so silently failed for exactly the
    -- two whose labels carry a parenthetical - smithy and alchemy - which is also why undo
    -- appeared broken for them. Their teardowns matter most of all: both BORROW a vanilla
    -- Smithery / AlchemyTable and move it to the camp, and only DespawnCampForge /
    -- DespawnCampAlchemy put it back where it came from. Deleting entities by hand would
    -- strand a real world object at the camp forever.
    local upgrades = {
        { label = "food cart",     tile = "cart",    despawn = "DespawnCampFoodCart",
          build = function(s, pos) return s:SpawnCampFoodCart(pos) end },
        { label = "makeshift inn", tile = "inn",     despawn = "DespawnCampInn",
          build = function(s, pos) return s:SpawnCampInn(pos) end },
        { label = "hunter's spot", tile = "hunt",    despawn = "DespawnCampHunt",
          build = function(s, pos) return s:SpawnCampHunt(pos) end },
        { label = "smithy (needs a Smithery nearby)", tile = "forge", despawn = "DespawnCampForge",
          build = function(s, pos) return s:SpawnCampForge(pos) end },
        { label = "alchemy bench (needs an AlchemyTable nearby)", tile = "alchemy", despawn = "DespawnCampAlchemy",
          build = function(s, pos) return s:SpawnCampAlchemy(pos) end },
        -- No teardown of its own; the entity watermark below is what undoes it.
        { label = "practice yard",
          build = function(s, pos) return s:SpawnCampPracticeYard(pos) end },
        { label = "archer tower (spawns an archer)", station = "tower",
          build = function(s, pos, yaw) return s:SpawnTowerStation(pos, yaw) end },
        { label = "archer cart (spawns 3 archers)", station = "cart",
          build = function(s, pos, yaw) return s:SpawnArcherCart(pos, yaw) end },
    }
    for _, u in ipairs(upgrades) do u.ghost = u.ghost or self.BCampUpgradeGhost end

    self._bcampCat = {
        { name = "tents",     items = tents },
        { name = "furniture", items = furniture },
        { name = "props",     items = loose },
        { name = "upgrades",  items = upgrades },
    }
    return self._bcampCat
end

local function current(self)
    local cats = self:BCampCatalogue()
    local c = cats[self.BCampCat]
    if not c then return nil, nil end
    local i = ((self.BCampSel[self.BCampCat] - 1) % #c.items) + 1
    return c, c.items[i]
end

-- ==== the spec ====
-- Rebuilt whenever the selection changes, because the ghost geometry changes with it.
function mercenaries:BCampSpec()
    local cat, item = current(self)
    if not item then return nil end

    -- rz carries the item's own yaw offset; GhostMove adds the aim angle on top, so the
    -- preview is turned exactly as the real thing will be.
    local ghostModel = item.ghost or item.model or self.BCampUpgradeGhost
    local parts = { { model = ghostModel, x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = item.yaw or 0 } }

    return {
        parts = parts,
        validMaterial = nil,      -- these are multi-submaterial meshes; forcing one hides submeshes
        sink = 0,
        -- Free-form editor: anywhere the raycast found ground is fair game. The tower's own
        -- validity rules still apply when the tower spawner itself runs.
        isValid = function() return true end,
        atMax   = function() return false end,
        confirm = function(s, pos, angle) s:BCampPlace(pos, angle) end,
        onCancel = function(s) s:BCampUndo() end,
        keepOnCancel = true,      -- right-click undoes and STAYS in the editor
        info = { placing = 'merc_info_tower_placing', already = 'merc_info_tower_already',
                 aim = 'merc_info_tower_aim', blocked = 'merc_info_tower_blocked',
                 limit = 'merc_info_tower_limit', raised = 'merc_info_tower_raised',
                 cancelled = 'merc_info_tower_cancelled' },
    }
end

-- Swap the live spec. StartPlacement refuses to replace an active one, so end it first.
function mercenaries:BCampRefresh(quiet)
    local spec = self:BCampSpec()
    if not spec then return end
    if self.ActivePlacement then self:EndPlacement() end
    self:StartPlacement(spec)
    if not quiet then
        local cat, item = current(self)
        local n = #cat.items
        local i = ((self.BCampSel[self.BCampCat] - 1) % n) + 1
        bLog(string.format("%s  %d/%d  %s", cat.name, i, n, item.label))
    end
end

-- Category key: select it, or advance the variant if it is already selected.
function mercenaries:BCampPick(catIdx)
    if self.BCampCat == catIdx then
        self.BCampSel[catIdx] = self.BCampSel[catIdx] + 1
    else
        self.BCampCat = catIdx
    end
    self:BCampRefresh()
end

-- ==== placing ====
function mercenaries:BCampPlace(pos, yaw)
    local cat, item = current(self)
    if not item then return end
    pos = pos or self.PlacePos
    yaw = (yaw or self.PlaceAngle or 0) + (item.yaw or 0)
    if not pos then bLog("look at solid ground first"); return end

    local ents = {}

    if item.fire then
        -- Fire only. Seats are furniture (F6) and go where you want them, not in a ring.
        pcall(function() self:SpawnCampFirePrefab(pos, 0) end)

    elseif item.stash then
        -- A real lootable container, not a prop: same class and model as the personal chest.
        pcall(function()
            local e = System.SpawnEntity({
                class = "Stash",
                name = "BCampChest_" .. tostring(math.random(100000, 999999)),
                position = self:CampSnapToGround(pos),
                orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
                properties = { object_Model = item.stash, bSaved_by_game = false },
            })
            if e then
                pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw }) end)
                table.insert(ents, e.id)
            end
        end)

    elseif item.station == "tower" then
        local before = #(self.TowerStations or {})
        self:SpawnTowerStation(pos, yaw)
        if #(self.TowerStations or {}) <= before then bLog("tower refused (cap or blocked)"); return end
        table.insert(self.BCampPieces, { kind = "tower", label = item.label, station = "tower", pos = pos, yaw = yaw })
        bLog("placed " .. item.label); return

    elseif item.station == "cart" then
        local before = #(self.ArcherCarts or {})
        self:SpawnArcherCart(pos, yaw)
        if #(self.ArcherCarts or {}) <= before then bLog("cart refused (cap or blocked)"); return end
        table.insert(self.BCampPieces, { kind = "cart", label = item.label, station = "cart", pos = pos, yaw = yaw })
        bLog("placed " .. item.label); return

    elseif item.build then
        -- Pin it to the aim point. Each of these asks CampStationSpot(tile) for its spot and,
        -- getting nothing, falls back to scanning for the flattest nearby patch - which is
        -- right when a whole camp is being laid out automatically and wrong when you are
        -- pointing at a specific place. Seeding the tile makes the answer exactly here.
        local restore, had
        if item.tile then
            self.CampStationTiles = self.CampStationTiles or {}
            had, restore = true, self.CampStationTiles[item.tile]
            self.CampStationTiles[item.tile] = { x = pos.x, y = pos.y, z = pos.z, ang = yaw }
        end

        -- Watermark the shared camp entity list. Everything these builders spawn is appended
        -- to CampEntities, so remembering the length beforehand gives undo a way to remove
        -- exactly what this build added - even for the ones (practice yard, house) that have
        -- no teardown function at all.
        local mark = #(self.CampEntities or {})

        local ok, res = pcall(function() return item.build(self, pos, yaw) end)

        if had then self.CampStationTiles[item.tile] = restore end

        if not ok or res == false then
            bLog(item.label .. " could not be built here (a borrowed vanilla prop may be missing)")
            return
        end
        -- Carry BOTH undo routes: the upgrade's own teardown (which also puts back anything
        -- it borrowed) and the CampEntities watermark (which catches the rest).
        table.insert(self.BCampPieces, { kind = "upgrade", label = item.label, pos = pos, yaw = yaw,
                                         despawn = item.despawn, mark = mark })
        bLog("placed " .. item.label); return

    elseif item.so then
        -- Usable furniture: visual prop plus its StanceSmartObject, so a merc can sit/lie on it.
        self:SpawnCampFurnitureSO(item.model, pos, yaw, "BCampFurn", item.so, nil, ents)

    elseif item.model then
        self:SpawnCampPropModel(item.model, pos, yaw, "BCampProp", ents)
        -- A mesh emits nothing on its own, so anything meant to light the camp gets a real
        -- Light entity alongside it, raised to roughly flame height.
        if item.light then
            pcall(function()
                local e = System.SpawnEntity({
                    class = "Light",
                    name = "BCampLight_" .. tostring(math.random(100000, 999999)),
                    position = { x = pos.x, y = pos.y, z = pos.z + (item.lightZ or 1.0) },
                    properties = item.light,
                })
                if e then table.insert(ents, e.id) end
            end)
        end
    else
        bLog("nothing to place for " .. tostring(item.label)); return
    end

    table.insert(self.BCampPieces, { kind = "prop", label = item.label, ents = ents, pos = pos, yaw = yaw })
    bLog("placed " .. item.label)
end

-- Right-click, or merc_bcamp_undo.
function mercenaries:BCampUndo()
    local last = table.remove(self.BCampPieces)
    if not last then bLog("nothing to undo"); return end

    if last.station == "tower" then
        local st = table.remove(self.TowerStations or {})
        if st then pcall(function() self:TowerStationClearOne(st) end) end
    elseif last.station == "cart" then
        local st = table.remove(self.ArcherCarts or {})
        if st then pcall(function() self:ArcherCartClearOne(st) end) end
    elseif last.kind == "upgrade" then
        -- Two routes, in this order and both run.
        --
        -- 1. The upgrade's OWN teardown, when it has one. This is not optional for the smithy
        --    and the alchemy bench: they do not spawn a station, they BORROW a real vanilla
        --    Smithery / AlchemyTable and move it to the camp, and only their despawn puts it
        --    back. Removing entities by hand would strand a world object at the camp for good.
        if last.despawn and self[last.despawn] then
            pcall(function() self[last.despawn](self) end)
        end

        -- 2. Anything this build appended to the shared camp entity list. Catches the
        --    upgrades that have no teardown at all (practice yard), and any dressing a
        --    teardown leaves behind. Walking backwards keeps the indices valid.
        local ents = self.CampEntities or {}
        local mark = last.mark or #ents
        for i = #ents, mark + 1, -1 do
            local id = ents[i]
            pcall(function() System.RemoveEntity(id) end)
            table.remove(ents, i)
        end
    else
        for _, id in ipairs(last.ents or {}) do pcall(function() System.RemoveEntity(id) end) end
    end
    bLog("undid " .. tostring(last.label))
end

-- ==== camp-level commands ====
-- F9. Clears the site and ENTERS build mode, so "new camp" leaves you ready to place.
function mercenaries:BCampNew()
    for _, p in ipairs(self.BCampPieces) do
        for _, id in ipairs(p.ents or {}) do pcall(function() System.RemoveEntity(id) end) end
    end
    self.BCampPieces = {}
    pcall(function() if self.TowerStationClearAll then self:TowerStationClearAll() end end)
    pcall(function() if self.ClearArcherCarts then self:ClearArcherCarts() end end)
    pcall(function() if self.WallClearAll then self:WallClearAll() end end)

    if self.BCampCat == 0 then self.BCampCat = 1 end
    self:BCampRefresh()
    bLog("new camp - cleared, builder on")
end

-- Persists the layout through the mod's own save-string storage, so it survives a reload.
function mercenaries:BCampSave()
    local rows = {}
    for _, p in ipairs(self.BCampPieces) do
        if p.pos then
            rows[#rows + 1] = string.format("%s|%.2f|%.2f|%.2f", p.label, p.pos.x, p.pos.y, p.pos.z)
        end
    end
    local blob = table.concat(rows, ";")
    pcall(function() self:SaveString("BCampLayout", blob) end)
    -- Saving is the "done" action, so it drops the ghost and leaves build mode - otherwise
    -- you finish a camp and are still stood there with a barrel floating on your crosshair.
    self:BCampStop()
    bLog("saved " .. #rows .. " piece(s) - builder off")
end

function mercenaries:BCampDump()
    if #self.BCampPieces == 0 then bLog("nothing placed yet"); return end
    bLog("---- " .. #self.BCampPieces .. " piece(s) ----")
    bLog("-- paste into mercenaries_banditcamp_quest.lua under BanditCampLayouts")
    bLog("mercenaries.BanditCampLayouts.RENAME_ME = {")
    for _, p in ipairs(self.BCampPieces) do
        if p.pos then
            -- Positions are dumped RELATIVE to the first piece, so a layout can be
            -- replayed anywhere; SpawnBanditCampLayout adds the site origin back.
            local o = self.BCampPieces[1].pos
            bLog(string.format('    { kind = "%s", what = "%s", x = %.2f, y = %.2f, z = %.2f, yaw = %.4f },',
                 p.kind, p.label, p.pos.x - o.x, p.pos.y - o.y, p.pos.z - o.z, p.yaw or 0))
        end
    end
    bLog("}")
    -- The layout is relative to the FIRST piece, so the matching site origin is that
    -- piece's real position - not wherever you happen to be standing when you dump.
    local o = self.BCampPieces[1].pos
    local lvl = "unknown"
    for _, get in ipairs({ function() return System.GetCurrLevelName() end,
                           function() return Game.GetLevelName() end,
                           function() return System.GetCurrAsyncLevelName() end }) do
        local ok, v = pcall(get)
        if ok and v and v ~= "" then lvl = tostring(v); break end
    end
    bLog("-- and its site row (paste under BanditCampSites):")
    bLog(string.format('    { name = "RENAME_ME", level = "%s", x = %.2f, y = %.2f, z = %.2f, yaw = 0, layout = "RENAME_ME" },',
         lvl, o.x, o.y, o.z))
    bLog("-- wall corners live in the wall builder: use its own dump for those")
end

function mercenaries:BCampStop()
    if self.ActivePlacement then self:EndPlacement() end
    self.BCampCat = 0
    bLog("builder off")
end

function mercenaries:BCampHelp()
    bLog("F5 tents (incl. house)   F6 furniture   F7 props   F8 upgrades")
    bLog("  press the same key again to cycle variants; the ghost follows your aim")
    bLog("LEFT CLICK places, RIGHT CLICK undoes - both need a weapon drawn (engine input map)")
    bLog("F9 new camp   F10 save camp   F11 dump layout")
    bLog("merc_bcamp_list shows the current category, merc_bcamp_off leaves the editor")
    bLog("walls are their own tool: merc_wall_build / merc_wall_close")
end

function mercenaries:BCampList()
    local cats = self:BCampCatalogue()
    local c = cats[self.BCampCat]
    if not c then bLog("no category selected - press F5-F8"); return end
    local sel = ((self.BCampSel[self.BCampCat] - 1) % #c.items) + 1
    bLog(c.name .. ":")
    for i, it in ipairs(c.items) do
        bLog(string.format("  %2d %s%s", i, it.label, (i == sel) and "   <- current" or ""))
    end
end

-- ==== keys ====
-- F5-F8 are also wanted by the patrol route recorder. merc_binds_routes lends them back for a
-- recording session; merc_bcamp_binds takes them again.
-- Three tools want F5-F11: this builder, the siege builder and the route recorder. Only one
-- may hold them, and the choice is REMEMBERED - the load hook used to hand them back to this
-- builder every single time, so anyone using another tool lost the keys on every reload and
-- found the camp editor still answering them.
function mercenaries:EditorOwner(who)
    if who then pcall(function() self:SaveString("EditorOwner", who) end) end
    local v
    pcall(function() v = self:LoadString("EditorOwner") end)
    return (v ~= nil and v ~= "") and v or "bcamp"
end

-- Leave every editor but the named one, so a stale ghost or category cannot answer a key
-- that now belongs to somebody else.
function mercenaries:EditorsStopExcept(who)
    -- Only stop one that is actually running: an unconditional stop logs "builder off" twice
    -- on every single load for editors nobody had open.
    if who ~= "bcamp" and (self.BCampCat or 0) ~= 0 then
        pcall(function() self:BCampStop() end)
    end
    if who ~= "siege" and (self.SiegeCat or 0) ~= 0 then
        pcall(function() if self.SiegeStop then self:SiegeStop() end end)
    end
    if who ~= "aleksej" and (self.AlxCat or 0) ~= 0 then
        pcall(function() if self.AlxClear then self:AlxClear() end end)
    end
end

function mercenaries:EditorWho()
    local who = self:EditorOwner()
    local name = ({ bcamp = "the bandit-camp builder (merc_bcamp_*)",
                    siege = "the siege builder (merc_siege_*)",
                    routes = "the patrol route recorder (merc_route_*)" })[who] or who
    bLog("F5-F11 belong to " .. name)
    bLog("  merc_bcamp_binds / merc_siege_binds / merc_binds_routes hand them over")
    bLog("  the choice is remembered across loads")
end

-- DISABLED while the siege of Raborsch is being authored: F5-F11 belong to the siege builder
-- (mercenaries_siege.lua) and this kept taking them back. Every merc_bcamp_* command still
-- works from the console - only the key grab is off.
--
-- TO RESTORE: uncomment the block below and comment out the SiegeBinds call in the load hook
-- in mercenaries.lua.
function mercenaries:BCampBinds(quiet)
    bLog("key binding is OFF for the camp builder - F5-F11 belong to the siege builder.")
    bLog("  every merc_bcamp_* command still works from the console")
    bLog("  to restore: uncomment BCampBinds in mercenaries_banditcamp.lua")
    -- self:EditorOwner("bcamp")
    -- self:EditorsStopExcept("bcamp")
    -- pcall(function()
    --     System.ExecuteCommand("bind f5 merc_bcamp_tents")
    --     System.ExecuteCommand("bind f6 merc_bcamp_furniture")
    --     System.ExecuteCommand("bind f7 merc_bcamp_props")
    --     System.ExecuteCommand("bind f8 merc_bcamp_upgrades")
    --     System.ExecuteCommand("bind f9 merc_bcamp_new")
    --     System.ExecuteCommand("bind f10 merc_bcamp_save")
    --     System.ExecuteCommand("bind f11 merc_bcamp_dump")
    -- end)
    -- if not quiet then self:BCampHelp() end
end

function mercenaries:BCampRouteBinds()
    self:EditorOwner("routes")
    self:EditorsStopExcept("routes")
    pcall(function()
        System.ExecuteCommand("bind f5 merc_route_new")
        System.ExecuteCommand("bind f6 merc_route_save")
        System.ExecuteCommand("bind f7 merc_route_cancel")
        System.ExecuteCommand("bind f8 merc_route_dump")
    end)
    bLog("F5-F8 lent to the route recorder; merc_bcamp_binds takes them back")
end

System.AddCCommand("merc_bcamp_tents",     "mercenaries:BCampPick(1)",  "Tents category / cycle (F5)")
System.AddCCommand("merc_bcamp_furniture", "mercenaries:BCampPick(2)",  "Furniture category / cycle (F6)")
System.AddCCommand("merc_bcamp_props",     "mercenaries:BCampPick(3)",  "Props category / cycle (F7)")
System.AddCCommand("merc_bcamp_upgrades",  "mercenaries:BCampPick(4)",  "Upgrades category / cycle (F8)")
System.AddCCommand("merc_bcamp_new",       "mercenaries:BCampNew()",    "New camp: clear everything placed (F9)")
System.AddCCommand("merc_bcamp_save",      "mercenaries:BCampSave()",   "Save the camp layout (F10)")
System.AddCCommand("merc_bcamp_dump",      "mercenaries:BCampDump()",   "Dump the layout as a Lua table (F11)")
System.AddCCommand("merc_bcamp_place",     "mercenaries:BCampPlace()",  "Place the current selection (same as left-click)")
System.AddCCommand("merc_bcamp_undo",      "mercenaries:BCampUndo()",   "Undo the last piece (same as right-click)")
System.AddCCommand("merc_bcamp_list",      "mercenaries:BCampList()",   "List the current category's variants")
System.AddCCommand("merc_bcamp_off",       "mercenaries:BCampStop()",   "Leave the builder")
System.AddCCommand("merc_bcamp_help",      "mercenaries:BCampHelp()",   "Builder keys")
System.AddCCommand("merc_bcamp_binds",     "mercenaries:BCampBinds()",  "Bind F5-F11 to the builder")
System.AddCCommand("merc_binds_who",       "mercenaries:EditorWho()",   "Which editor owns F5-F11")
System.AddCCommand("merc_binds_routes",    "mercenaries:BCampRouteBinds()", "Lend F5-F8 to the route recorder")
