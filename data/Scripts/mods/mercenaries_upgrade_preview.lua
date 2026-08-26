-- Console-only tooling: spawns candidate camp-upgrade props/prefabs in a row in
-- front of the player (each on a flag-marked spot) so the models can be judged,
-- and hosts the forge R&D experiments below (all superseded by the shipped camp
-- forge in mercenaries_forge.lua; the full postmortem is in docs/camp-forge.md).
-- Commands: merc_upgrade_preview / merc_forge_preview / merc_prefab_preview /
-- merc_upgrade_preview_clear. None of this runs during normal play.
mercenaries.UpgradePreviewEntities = {}
mercenaries.UpgradePreviewPrefabHosts = {}   -- host ids needing Game.DeletePrefab on cleanup

-- Reuse the ground-scan flag as the per-spot marker.
mercenaries.UpgradePreviewFlag = "objects/manmade/common_decorations/flags/flag_temporary.cgf"

-- The row, in order. label = what it's meant to represent; model = the .cgf;
-- pile = spawn a small cluster instead of a single prop (for "a pile of ...").
mercenaries.UpgradePreviewAssets = {
    { label = "small smithy",        model = "objects/manmade/structures/industrial/smitheries/coal_forge_small_a.cgf" },
    { label = "alchemy bench",       model = "objects/manmade/task_specific_props/alchemy/alchemy_table_b/alchemy_table_b.cgf" },
    { label = "pile of bows (rack)", model = "objects/manmade/task_specific_props/combat/weapon_racks/weapon_rack_fancy_a.cgf" },
    { label = "cart with food",      model = "objects/manmade/common_furniture/sacks/sack_stash/sacks_stash_cart_02.cgf" },
    { label = "sacks with food",     model = "objects/manmade/common_furniture/sacks/sack_flour.cgf", pile = true },
    { label = "cart (empty)",        model = "objects/manmade/vehicles/carts/cart_a.cgf" },
    { label = "decoration (antlers)",model = "objects/manmade/task_specific_props/foraging/hunting/antlers_deer_c.cgf" },
    { label = "tanning rack",        model = "objects/manmade/task_specific_props/clothing_industry/tanning/drying_fur_e.cgf" },
    { label = "smoking house",       model = "objects/manmade/structures/industrial/drying_house/drying_house_a.cgf" },
    { label = "bench (log)",         model = "objects/manmade/common_furniture/benches/low/bench_log_a.cgf" },
    { label = "table (rustic)",      model = "objects/manmade/common_furniture/tables/table_rustic_b.cgf" },
    { label = "beer jug",            model = "objects/manmade/task_specific_props/household/cooking_eating/jugs/jug_a_mead.cgf" },
    { label = "wine barrels (pile)", model = "objects/manmade/common_furniture/barrels/barrel_c.cgf", pile = true },
    { label = "small wine barrel",   model = "objects/manmade/common_furniture/barrels/barrel_small_spigot_stand.cgf" },
    { label = "wooden tower",        model = "objects/manmade/structures/defensive/watchtowers/unique/nebakov/watchtower.cgf" },
}

-- Forge/smithy candidates, previewed on their own with merc_forge_preview.
-- Standalone props first, then full smithy structures (likely one-sided / large).
mercenaries.ForgePreviewAssets = {
    { label = "forge_small_a (prop)",  model = "objects/manmade/task_specific_props/metal_industry/smithing/forge_small_a.cgf" },
    { label = "coal_forge (full)",     model = "objects/manmade/structures/industrial/smitheries/coal_forge.cgf" },
    { label = "coal_forge_small_a",    model = "objects/manmade/structures/industrial/smitheries/coal_forge_small_a.cgf" },
    { label = "anvil",                 model = "objects/manmade/task_specific_props/metal_industry/smithing/anvil.cgf" },
    { label = "armourer_anvil",        model = "objects/manmade/task_specific_props/metal_industry/smithing/armourer_anvil.cgf" },
    { label = "bellows_a",             model = "objects/manmade/common_tools/bellows_a.cgf" },
    { label = "smithery (nebakov)",    model = "objects/manmade/structures/industrial/smitheries/unique/nebakov/smithery.cgf" },
    { label = "smithy (tachov)",       model = "objects/manmade/structures/industrial/smitheries/unique/tachov/tachov_1_smithy.cgf" },
    { label = "blacksmith (chmelna)",  model = "objects/manmade/structures/industrial/smitheries/unique/chmelna/chmelna_02_blacksmith.cgf" },
}

-- "Compositions": our own prop arrangements, rebuilt from the models a vanilla
-- prefab uses (Game.SpawnPrefab skips static brushes, so we spawn each .cgf
-- ourselves). Offsets dx/dy/dz + yaw (deg) + scale are lifted straight from
-- smithy_workshop_small (+ its nested smithy_workshop_base). This is the full
-- forge-minigame kit: forge body, hot coals on top, anvil, water/quench, barrel.
-- EXACT offsets from smithy_workshop_small (+ nested smithy_workshop_base),
-- relative to the prefab origin. Parts are authored upright so no per-part
-- rotation is needed; a global yaw (ForgeBuild) spins the whole rig. Using the
-- real positions keeps our visuals aligned with the prefab's own Smithery /
-- anvil-alignment when we spawn both (ForgeBuildFunctional).
-- Full visual set (for the standalone, prefab-less merc_forge_build):
mercenaries.ForgeComposition = {
    { model = "objects/manmade/task_specific_props/metal_industry/smithing/forge_small_a.cgf",   dx = -0.44, dy =  2.27, dz = -0.10 },
    { model = "objects/manmade/structures/industrial/smitheries/coal_forge_small_a.cgf",         dx = -0.54, dy =  2.48, dz =  0.64 },
    { model = "objects/manmade/task_specific_props/metal_industry/smithing/anvil.cgf",           dx =  0.31, dy = -0.88, dz = -0.11 },
    { model = "objects/manmade/task_specific_props/metal_industry/smithing/water_container.cgf", dx =  2.04, dy =  0.16, dz =  0.00 },
    { model = "objects/manmade/task_specific_props/metal_industry/smithing/barrel_forging.cgf",  dx =  2.51, dy =  0.52, dz =  0.00 },
}

-- Brush-only subset for the FUNCTIONAL build: the prefab (via Game.SpawnPrefab)
-- already brings the coals + forge-bag as GeomEntities and the interactive
-- Smithery; it just skips these static brushes, so we overlay exactly them at
-- the same exact offsets.
mercenaries.ForgeOverlayBrushes = {
    { model = "objects/manmade/task_specific_props/metal_industry/smithing/forge_small_a.cgf",   dx = -0.44, dy =  2.27, dz = -0.10 },
    { model = "objects/manmade/task_specific_props/metal_industry/smithing/anvil.cgf",           dx =  0.31, dy = -0.88, dz = -0.11 },
    { model = "objects/manmade/task_specific_props/metal_industry/smithing/water_container.cgf", dx =  2.04, dy =  0.16, dz =  0.00 },
    { model = "objects/manmade/task_specific_props/metal_industry/smithing/barrel_forging.cgf",  dx =  2.51, dy =  0.52, dz =  0.00 },
}
mercenaries.SmithyPrefabGuid = "bad22e6e-32ed-4c2a-9597-668243bb0736"  -- smithy_workshop_small

-- Curated compositions, previewed with merc_composition_preview.
mercenaries.UpgradeCompositions = {
    { label = "forge (built)", composition = mercenaries.ForgeComposition },
}

-- Metres between row spots. Generous so the big props (tower, smokehouse) don't
-- overlap their neighbours.
mercenaries.UpgradePreviewSpacing  = 5.0
mercenaries.UpgradePreviewStartDist = 4.0

function mercenaries:UpgradePreviewSpawnModel(model, pos, label)
    local ent = System.SpawnEntity({
        class = "BasicEntity",
        name = "MercUpgPreview_" .. tostring(math.random(100000, 999999)),
        position = pos,
        properties = { object_Model = model, bMissionCritical = false, bSaved_by_game = false, bSerialize = false },
    })
    if ent then table.insert(self.UpgradePreviewEntities, ent.id) end
    return ent
end

-- Spawn one of our own compositions: each piece is a .cgf placed at anchor +
-- (dx,dy,dz), yawed and scaled per the source prefab. Axis-aligned (no anchor
-- yaw) for now - good enough to judge the arrangement.
function mercenaries:UpgradePreviewSpawnComposition(pieces, anchor, yawDeg)
    yawDeg = yawDeg or 0
    local th = math.rad(yawDeg)
    local cs, sn = math.cos(th), math.sin(th)
    for _, pc in ipairs(pieces) do
        local dx, dy, dz = pc.dx or 0, pc.dy or 0, pc.dz or 0
        -- Rigid-body yaw: rotate the local offset about the vertical (Z) axis and
        -- turn each part to match, so the whole rig spins as one.
        local ox = dx * cs - dy * sn
        local oy = dx * sn + dy * cs
        -- No orientation in the spawn params (a zero vector there trips the
        -- engine's "zero orientation" validator); set angles after the spawn,
        -- the way the camp props do.
        local params = {
            class = "BasicEntity",
            name = "MercUpgPreview_" .. tostring(math.random(100000, 999999)),
            position = { x = anchor.x + ox, y = anchor.y + oy, z = anchor.z + dz },
            properties = { object_Model = pc.model, bMissionCritical = false, bSaved_by_game = false, bSerialize = false },
        }
        if pc.s and pc.s ~= 1.0 then params.scale = pc.s end
        local ent = System.SpawnEntity(params)
        if ent then
            table.insert(self.UpgradePreviewEntities, ent.id)
            pcall(function() ent:SetAngles({ x = math.rad(pc.rx or 0), y = math.rad(pc.ry or 0), z = math.rad((pc.rz or 0) + yawDeg) }) end)
            if pc.s and pc.s ~= 1.0 then pcall(function() ent:SetScale(pc.s) end) end
        end
    end
end

-- Spawn a whole PREFAB composition (many props + logic). We spawn a bare host
-- entity as the anchor, then call the documented
--   Game.SpawnPrefab(entityId, prefabTemplateId, nMaxSpawn)
-- to instantiate the prefab's contents onto it. Cleanup pairs Game.DeletePrefab
-- (removes the instantiated contents) with removing the host entity.
function mercenaries:UpgradePreviewSpawnPrefab(guid, pos, yawDeg)
    local ent = System.SpawnEntity({
        class = "BasicEntity",
        name = "MercUpgPrefab_" .. tostring(math.random(100000, 999999)),
        position = pos,
        orientation = { x = 0, y = 0, z = math.rad(yawDeg or 0) },
        properties = {},
    })
    if not ent then System.LogAlways("[UpgradePreview] prefab host spawn failed"); return end
    table.insert(self.UpgradePreviewEntities, ent.id)
    self.UpgradePreviewPrefabHosts[ent.id] = true
    local ok, err = pcall(function() Game.SpawnPrefab(ent.id, guid, 0) end)
    if not ok then System.LogAlways("[UpgradePreview] Game.SpawnPrefab failed for " .. tostring(guid) .. ": " .. tostring(err)) end
    return ent
end

-- Complete prefab compositions (the "real" upgrade builds), spawned with
-- merc_prefab_preview. These are full prefabs, not single models.
mercenaries.PrefabPreviewList = {
    { label = "smithy_workshop_base",    prefab = "bad22e6e-32ed-4c2a-9597-668243bb0724" },
    { label = "smithy_workshop_small",   prefab = "bad22e6e-32ed-4c2a-9597-668243bb0736" },
    { label = "cooking_station_3",       prefab = "9ffbb97d-6666-4e4d-a91e-e75ad5c3374f" },
    { label = "alchemy_table",           prefab = "ee978eb5-b9df-4bd8-adf3-3ba8d91cfdd3" },
    { label = "fireplace_camp",          prefab = "90425fc9-018a-4c36-854e-79ee25ad4195" },
    { label = "fireplace_camp_prepared", prefab = "9891b396-655a-42a9-b73b-b98f52021f79" },
    { label = "small_inner_gate_tower",  prefab = "80f78241-07cf-40c3-8a93-98e01d62f45f" },
}

-- Thin wrappers: preview the full upgrade set, the forge candidates, or the
-- complete prefab compositions (wider spacing, they're big).
function mercenaries:UpgradePreview() self:UpgradePreviewRow(self.UpgradePreviewAssets) end
function mercenaries:ForgePreview()   self:UpgradePreviewRow(self.ForgePreviewAssets) end
function mercenaries:PrefabPreview()  self:UpgradePreviewRow(self.PrefabPreviewList, 9.0) end
function mercenaries:CompositionPreview() self:UpgradePreviewRow(self.UpgradeCompositions, 9.0) end

-- Build the whole forge at a flag 4m in front of you, rotated by a global yaw
-- (degrees). Re-run with a different yaw to spin the whole rig; it clears first.
function mercenaries:ForgeBuild(yaw)
    yaw = tonumber(yaw) or 0
    self:ClearUpgradePreview()
    if not player then return end
    local o = player:GetWorldPos()
    local d = player:GetDirectionVector() or { x = 0, y = 1, z = 0 }
    local fl = math.sqrt(d.x * d.x + d.y * d.y); if fl < 0.001 then d = { x = 0, y = 1, z = 0 }; fl = 1 end
    local anchor = self:CampSnapToGround({ x = o.x + d.x / fl * 4, y = o.y + d.y / fl * 4, z = o.z })
    self:UpgradePreviewSpawnModel(self.UpgradePreviewFlag, anchor, "flag")
    self:UpgradePreviewSpawnComposition(self.ForgeComposition, anchor, yaw)
    System.LogAlways("[Forge] built with global yaw=" .. yaw .. " deg")
end

-- Functional forge: spawn the smithy prefab (brings the interactive Smithery +
-- its linked slots/particles/alignment + the coals & forge-bag GeomEntities,
-- but not the static brushes) AND overlay our brush visuals at the exact same
-- offsets so the visible forge/anvil sit where the minigame expects them.
-- Shared base for the functional-forge experiments: visuals + Smithery + a
-- SmartObjectHolder carrying the REAL blacksmith smart-object type (properties
-- lifted from the vanilla smithy prefab's holder). Returns the Smithery and
-- holder entities for the per-strategy linking step.
function mercenaries:ForgeFuncBase(yaw)
    yaw = tonumber(yaw) or 0
    self:ClearUpgradePreview()
    if not player then return nil end
    local o = player:GetWorldPos()
    local d = player:GetDirectionVector() or { x = 0, y = 1, z = 0 }
    local fl = math.sqrt(d.x * d.x + d.y * d.y); if fl < 0.001 then d = { x = 0, y = 1, z = 0 }; fl = 1 end
    local anchor = self:CampSnapToGround({ x = o.x + d.x / fl * 4, y = o.y + d.y / fl * 4, z = o.z })
    self:UpgradePreviewSpawnModel(self.UpgradePreviewFlag, anchor, "flag")
    self:UpgradePreviewSpawnComposition(self.ForgeComposition, anchor, yaw)

    local th = math.rad(yaw)
    local cs, sn = math.cos(th), math.sin(th)
    local sx, sy = 0.30, -0.85   -- Smithery/anvil offset from the prefab
    local wpos = { x = anchor.x + (sx * cs - sy * sn), y = anchor.y + (sx * sn + sy * cs), z = anchor.z - 0.18 }

    local sm
    pcall(function()
        sm = System.SpawnEntity({
            class = "Smithery",
            name = "MercSmithery_" .. tostring(math.random(100000, 999999)),
            position = wpos,
            properties = { object_Model = "objects/special/primitive_cylinder.cgf" },
        })
    end)
    if not sm then System.LogAlways("[Forge] Smithery spawn FAILED"); return nil end
    table.insert(self.UpgradePreviewEntities, sm.id)
    pcall(function() sm:SetAngles({ x = 0, y = 0, z = th }) end)
    pcall(function() sm:SetScale(0.7) end)

    local so
    pcall(function()
        so = System.SpawnEntity({
            class = "SmartObjectHolder",
            name = "MercSmithAlign_" .. tostring(math.random(100000, 999999)),
            position = wpos,
            properties = {
                guidSmartObjectType      = "a7daaa9f-8424-430d-80a6-e7996aed85a3", -- blacksmith SO type (from the prefab)
                soclass_SmartObjectHelpers = "Blacksmith",
            },
        })
    end)
    if so then
        table.insert(self.UpgradePreviewEntities, so.id)
        pcall(function() so:SetAngles({ x = 0, y = 0, z = th }) end)
    end

    -- Diagnostics: what do we actually have to work with?
    System.LogAlways("[Forge] diag: holder=" .. tostring(so and so.id)
        .. " holder.smartObject=" .. tostring(so and so.smartObject and (so.smartObject.__this or "table-no-__this"))
        .. " sm.CreateLink=" .. tostring(sm.CreateLink)
        .. " sm.CountLinks=" .. (sm.CountLinks and tostring(sm:CountLinks()) or "nil"))
    return sm, so
end

-- Strategy A (merc_forge_func): monkey-patch the INSTANCE's GetLinkedSmartObject.
-- OnUsed calls self:GetLinkedSmartObject(), and an instance field shadows the
-- class method - pure Lua, no engine link needed. Returns the holder (real
-- .smartObject if present, else a synthetic table carrying its WUID).
function mercenaries:ForgeBuildFunctional(yaw)
    local sm, so = self:ForgeFuncBase(yaw)
    if not (sm and so) then return end
    sm.GetLinkedSmartObject = function(slf)
        if so.smartObject and so.smartObject.__this then
            System.LogAlways("[Forge] A: returning holder's real smartObject")
            return so
        end
        local w = nil
        pcall(function() w = XGenAIModule.GetMyWUID(so) end)
        System.LogAlways("[Forge] A: holder has no .smartObject; returning synthetic wuid=" .. tostring(w))
        return { smartObject = { __this = w } }
    end
    System.LogAlways("[Forge] A ready: GetLinkedSmartObject overridden -> holder. Press E at the anvil.")
end

-- Strategy B (merc_forge_func2): try the engine's entity-link API at runtime
-- (no vanilla script ever CREATES a link, so this probes whether it's exposed).
function mercenaries:ForgeBuildFunctional2(yaw)
    local sm, so = self:ForgeFuncBase(yaw)
    if not (sm and so) then return end
    if not sm.CreateLink then
        System.LogAlways("[Forge] B: sm.CreateLink is NOT exposed - this strategy is unavailable, use merc_forge_func (A)")
        return
    end
    local ok, err = pcall(function() sm:CreateLink("", so.id) end)
    System.LogAlways("[Forge] B: CreateLink('') -> ok=" .. tostring(ok) .. " err=" .. tostring(err)
        .. " links now=" .. (sm.CountLinks and tostring(sm:CountLinks()) or "?") .. ". Press E at the anvil.")
end

-- Strategy C (merc_forge_func3): spawn the complete smithery rig and wire its
-- links (hammer/tongs/alignment/etc.) by hand. Dead end - see docs/camp-forge.md.
mercenaries.ForgeRigLinks = {
    { link = "",                     class = "SmartObjectHolder", dx =  0.25, dy = 1.86,  dz = 0.00,  yaw = 0,
      props = { guidSmartObjectType = "a7daaa9f-8424-430d-80a6-e7996aed85a3", soclass_SmartObjectHelpers = "Blacksmith" } },
    { link = "alignment",            class = "TagPoint",          classes = { "TagPoint", "SmartObjectHolder", "StanceSmartObject" },
      dx =  0.25, dy = 1.86,  dz = 0.00,  yaw = 1,   props = {} },
    -- NOTE: property TYPES must match the entity script exactly (booleans as
    -- true/false, not 0/1) or SpawnEntity throws - that's what killed the
    -- ItemSlot/ParticleEffect spawns on the first staged run.
    { link = "hammer",               class = "ItemSlot",          dx = -0.07, dy = -0.51, dz = 0.77,  yaw = 159,
      props = { guidItemClassId = "0502824d-a654-4471-9978-c1624860dde1", bOnlyNPC = true, bOwnedByHome = false } },
    { link = "tongs",                class = "ItemSlot",          dx =  2.39, dy = 0.71,  dz = 0.70,  yaw = 140,
      props = { guidItemClassId = "f22b7bb9-fa73-4aa1-92e6-3943e2be7e69", bOnlyNPC = true, bOwnedByHome = false } },
    { link = "forgeCoal",            class = "GeomEntity",        dx = -0.54, dy = 2.48,  dz = 0.64,  yaw = 67, s = 0.875,
      props = { object_Model = "objects/manmade/structures/industrial/smitheries/coal_forge_small_a.cgf" } },
    { link = "forgeHeatingParticles", class = "ParticleEffect",   dx = -0.63, dy = 2.16,  dz = 0.76,  yaw = 0,
      props = { ParticleEffect = "professions.blacksmith.forge_fire", bPrime = false } },
    { link = "forgeStartParticles",  class = "ParticleEffect",    dx = -0.63, dy = 2.14,  dz = 0.76,  yaw = 0,
      props = { ParticleEffect = "professions.blacksmith.forge_fire_big", bActive = false } },
    { link = "anvilParticles",       class = "ParticleEffect",    dx =  0.34, dy = -0.57, dz = 0.82,  yaw = 0,
      props = { ParticleEffect = "professions.blacksmith.hammering_hit", bActive = false, bPrime = false } },
    { link = "hardeningParticles",   class = "ParticleEffect",    dx =  2.04, dy = 0.15,  dz = 0.48,  yaw = 0,
      props = { ParticleEffect = "professions.blacksmith.hardening", bActive = false } },
    { link = "forgeBag",             class = "GeomEntity",        dx =  1.24, dy = 2.26,  dz = 0.00,  yaw = -83,
      props = { object_Model = "objects/characters/assets/forge_bag_small/forge_bag_small.cdf" } },
    -- Light properties lifted from the level data's light_forge instance.
    { link = "forgeLight",           class = "Light",             dx = -0.48, dy = 2.45,  dz = 1.05,  yaw = 0,
      props = {
          Radius = 2.5, fAttenuationBulbSize = 0.4,
          Color = { clrDiffuse = { x = 0.730461, y = 0.226966, z = 0.0612461 }, fDiffuseMultiplier = 0.02 },
          Options = { fVerticalClipDistanceDownward = 3, fVerticalClipDistanceUpward = 11 },
          Shadows = { nCastShadows = 2 },
      } },
}

-- Visual brushes for the rig build: everything EXCEPT the coals (those spawn as
-- the linked forgeCoal GeomEntity above so the minigame can light them).
mercenaries.ForgeRigBrushes = {
    { model = "objects/manmade/task_specific_props/metal_industry/smithing/forge_small_a.cgf",   dx = -0.44, dy =  2.27, dz = -0.10 },
    { model = "objects/manmade/task_specific_props/metal_industry/smithing/anvil.cgf",           dx =  0.31, dy = -0.88, dz = -0.11 },
    { model = "objects/manmade/task_specific_props/metal_industry/smithing/water_container.cgf", dx =  2.04, dy =  0.16, dz =  0.00 },
    { model = "objects/manmade/task_specific_props/metal_industry/smithing/barrel_forging.cgf",  dx =  2.51, dy =  0.52, dz =  0.00 },
}

-- Strategy D (merc_forge_func4): spawn the nested base prefab directly.
-- Game.SpawnPrefab brings a prefab's entities (links intact) but skips brushes
-- and nested prefabs, so smithy_workshop_base (not _small) is what carries the
-- Smithery + tool ItemSlots + alignment TagPoint; we supply the brush visuals.
-- Dead end - see docs/camp-forge.md.
mercenaries.SmithyBasePrefabGuid = "bad22e6e-32ed-4c2a-9597-668243bb0724" -- smithy_workshop_base

function mercenaries:ForgeBuildFunctional4(yaw)
    yaw = tonumber(yaw) or 0
    self:ClearUpgradePreview()
    if not player then return end
    local o = player:GetWorldPos()
    local d = player:GetDirectionVector() or { x = 0, y = 1, z = 0 }
    local fl = math.sqrt(d.x * d.x + d.y * d.y); if fl < 0.001 then d = { x = 0, y = 1, z = 0 }; fl = 1 end
    local anchor = self:CampSnapToGround({ x = o.x + d.x / fl * 4, y = o.y + d.y / fl * 4, z = o.z })
    self:UpgradePreviewSpawnModel(self.UpgradePreviewFlag, anchor, "flag")

    -- Full visuals (the prefab brings no brushes).
    self:UpgradePreviewSpawnComposition(self.ForgeComposition, anchor, yaw)

    -- Host for the prefab at the nested base's offset within our composition
    -- frame (workshop_base sits at +0.25,+1.86 inside workshop_small).
    local th = math.rad(yaw)
    local cs, sn = math.cos(th), math.sin(th)
    local hpos = { x = anchor.x + (0.25 * cs - 1.86 * sn), y = anchor.y + (0.25 * sn + 1.86 * cs), z = anchor.z }
    local host
    pcall(function()
        host = System.SpawnEntity({
            class = "BasicEntity",
            name = "MercSmithyBase_" .. tostring(math.random(100000, 999999)),
            position = hpos,
            properties = {},
        })
    end)
    if not host then System.LogAlways("[Forge] D: host spawn failed"); return end
    table.insert(self.UpgradePreviewEntities, host.id)
    self.UpgradePreviewPrefabHosts[host.id] = true
    pcall(function() host:SetAngles({ x = 0, y = 0, z = th }) end)
    local ok, err = pcall(function() Game.SpawnPrefab(host.id, self.SmithyBasePrefabGuid, 0) end)
    System.LogAlways("[Forge] D: spawned smithy_workshop_base prefab (entities incl. Smithery/ItemSlots, links intact) -> ok="
        .. tostring(ok) .. (err and (" err=" .. tostring(err)) or "") .. ". Press E at the anvil.")
end

-- ItemSlot hijack recon (merc_itemslot_scan): enumerate loaded ItemSlots and what
-- they hold, to see if a streamed-in village smithy's slots can be borrowed. See docs/camp-forge.md.
mercenaries.HammerItemGuid = "0502824d-a654-4471-9978-c1624860dde1"
mercenaries.TongsItemGuid  = "f22b7bb9-fa73-4aa1-92e6-3943e2be7e69"

function mercenaries:SlotItemClass(ent)
    local g
    pcall(function() g = EntityModule.GetSlotItemClassId(ent.id) end)
    if g == nil and ent.Properties then g = ent.Properties.guidItemClassId end
    return g and tostring(g) or nil
end

function mercenaries:ItemSlotScan()
    if not player then return end
    local o = player:GetWorldPos()
    local slots = System.GetEntitiesByClass and System.GetEntitiesByClass("ItemSlot")
    if not slots then System.LogAlways("[SlotScan] GetEntitiesByClass unavailable"); return end
    local total, near50, hammers, tongs = 0, 0, {}, {}
    local nearest = {}   -- collect closest few of any kind
    for _, e in pairs(slots) do
        total = total + 1
        local p = e.GetWorldPos and e:GetWorldPos()
        if p then
            local dx, dy, dz = p.x - o.x, p.y - o.y, p.z - o.z
            local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
            if dist <= 50 then near50 = near50 + 1 end
            local cls = self:SlotItemClass(e)
            if cls == self.HammerItemGuid then table.insert(hammers, dist)
            elseif cls == self.TongsItemGuid then table.insert(tongs, dist) end
            table.insert(nearest, { d = dist, n = e.GetName and e:GetName() or "?", c = cls })
        end
    end
    table.sort(nearest, function(x, y) return x.d < y.d end)
    table.sort(hammers); table.sort(tongs)
    System.LogAlways(string.format("[SlotScan] loaded ItemSlots: %d total, %d within 50m", total, near50))
    System.LogAlways(string.format("[SlotScan] blacksmith HAMMER slots loaded: %d (nearest %s m)", #hammers, hammers[1] and string.format("%.1f", hammers[1]) or "-"))
    System.LogAlways(string.format("[SlotScan] blacksmith TONGS  slots loaded: %d (nearest %s m)", #tongs, tongs[1] and string.format("%.1f", tongs[1]) or "-"))
    System.LogAlways("[SlotScan] nearest 8 ItemSlots (any kind):")
    for i = 1, math.min(8, #nearest) do
        local s = nearest[i]
        System.LogAlways(string.format("[SlotScan]   %6.1fm  item=%s  %s", s.d, tostring(s.c), tostring(s.n)))
    end
    -- Also: any Smithery entities loaded?
    local sm = System.GetEntitiesByClass("Smithery")
    local smc, smNear = 0, nil
    if sm then for _, e in pairs(sm) do
        smc = smc + 1
        local p = e.GetWorldPos and e:GetWorldPos()
        if p then local d = math.sqrt((p.x-o.x)^2 + (p.y-o.y)^2 + (p.z-o.z)^2); if not smNear or d < smNear then smNear = d end end
    end end
    System.LogAlways(string.format("[SlotScan] loaded Smithery entities: %d (nearest %s m)", smc, smNear and string.format("%.1f", smNear) or "-"))
end

-- merc_anvil_grab / _use / _restore: teleport a real loaded Smithery (+ its
-- alignment holder and visible props) to camp while its invisible tool slots stay
-- linked at the village and still supply the tools. This is the approach that
-- shipped (see mercenaries_forge.lua and docs/camp-forge.md).
mercenaries.AnvilBorrow = nil

-- Henry-relative forge visuals: fwd = toward the anvil, lat = +left/-right,
-- up = height, yaw = per-piece rotation offset (deg, +=CCW). Derived from
-- smithy_workshop_small: alignment ~2.74m behind the anvil, forge & coal
-- behind-left, water & barrel front-right.
mercenaries.ForgeVisualLayout = {
    -- interaction anvil: at the Smithery (E fires here), ~2.74m ahead. Distinct
    -- model (armourer's anvil) from the forging one.
    { name = "anvil_interact", model = "objects/manmade/task_specific_props/metal_industry/smithing/armourer_anvil.cgf", fwd =  2.74, lat =  0.00, up = -0.11 },
    -- forging anvil: where Henry hammers (tuned in-game).
    { name = "anvil_forge",    model = "objects/manmade/task_specific_props/metal_industry/smithing/anvil.cgf",           fwd =  1.10, lat =  1.00, up = -0.11 },
    -- forge + coals, rotated 90deg CCW.
    { name = "forge",          model = "objects/manmade/task_specific_props/metal_industry/smithing/forge_small_a.cgf",   fwd = -0.82, lat =  0.48, up = -0.10, yaw = 90 },
    { name = "coal",           model = "objects/manmade/structures/industrial/smitheries/coal_forge_small_a.cgf",         fwd = -0.74, lat =  0.68, up =  0.64, yaw = 90, s = 0.875 },
    { name = "water",          model = "objects/manmade/task_specific_props/metal_industry/smithing/water_container.cgf", fwd =  1.74, lat = -1.75, up =  0.00 },
    { name = "barrel",         model = "objects/manmade/task_specific_props/metal_industry/smithing/barrel_forging.cgf",  fwd =  2.19, lat = -1.23, up =  0.00 },
    -- new pieces - rough placements, tune live with merc_forge_nudge (7=bellows, 8=furnace).
    { name = "bellows",        model = "objects/manmade/common_tools/bellows_a.cgf",                                      fwd = -1.30, lat =  0.60, up =  0.35, yaw = 90 },
    { name = "furnace",        model = "objects/manmade/task_specific_props/metal_industry/smelting/smelting_oven_a.cgf", fwd = -0.90, lat =  1.30, up =  0.00, yaw = 90 },
}

function mercenaries:AnvilGrab()
    if not player then return end
    local sm, dist = self:FindNearestSmithery()
    if not sm then System.LogAlways("[Anvil] no loaded Smithery to borrow (need to be near a village)"); return end
    if self.AnvilBorrow then self:AnvilRestore() end

    local o = player:GetWorldPos()
    local d = player:GetDirectionVector() or { x = 0, y = 1, z = 0 }
    local fl = math.sqrt(d.x * d.x + d.y * d.y); if fl < 0.001 then d = { x = 0, y = 1, z = 0 }; fl = 1 end
    local F = { x = d.x / fl, y = d.y / fl }   -- forward (toward the anvil)
    local L = { x = -F.y, y = F.x }            -- Henry's left
    -- Anvil ~1.5m in front of the player; Henry's working spot 2.74m behind the
    -- anvil (the base-game align->anvil distance) so the layout matches.
    local anvilPos = self:CampSnapToGround({ x = o.x + F.x * 1.5, y = o.y + F.y * 1.5, z = o.z })
    local standPos = self:CampSnapToGround({ x = anvilPos.x - F.x * 2.74, y = anvilPos.y - F.y * 2.74, z = o.z })
    local yaw = math.atan2(anvilPos.y - standPos.y, anvilPos.x - standPos.x)

    -- Keep the layout frame so the live tuner (merc_forge_nudge) can convert
    -- fwd/lat/up back to world positions.
    local rec = { sm = sm, smPos = sm:GetWorldPos(), visuals = {}, F = F, L = L, stand = standPos, yaw = yaw }

    -- Borrow ONLY the invisible Smithery logic (move it to the anvil spot so
    -- CanUse/E fire at the visible anvil). We deliberately DO NOT touch the
    -- village's own visible coal/bellows/light - no cannibalising their forge.
    pcall(function() sm:SetWorldPos(anvilPos) end)

    -- Spawn OUR forge visuals in the base-game layout around Henry's stand spot.
    for _, p in ipairs(self.ForgeVisualLayout) do
        local wpos = { x = standPos.x + F.x * p.fwd + L.x * p.lat,
                       y = standPos.y + F.y * p.fwd + L.y * p.lat,
                       z = standPos.z + (p.up or 0) }
        local params = { class = "BasicEntity", name = "MercForgeVis_" .. tostring(math.random(100000, 999999)),
                         position = wpos, properties = { object_Model = p.model, bMissionCritical = false, bSaved_by_game = false, bSerialize = false } }
        if p.s and p.s ~= 1.0 then params.scale = p.s end
        local e; pcall(function() e = System.SpawnEntity(params) end)
        if e then
            pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw + math.rad(p.yaw or 0) }) end)
            if p.s and p.s ~= 1.0 then pcall(function() e:SetScale(p.s) end) end
            table.insert(rec.visuals, { e = e, name = p.name, fwd = p.fwd, lat = p.lat, up = p.up or 0, yaw = p.yaw or 0 })
        end
    end

    -- Anti-teleport fix: retarget the Smithery's 'alignment' link (its target
    -- TagPoint is Lua-invisible, but SetLinkTarget works by NAME) to our own
    -- SmartObjectHolder at Henry's spot, so the minigame plants him at camp.
    local holder
    pcall(function()
        holder = System.SpawnEntity({ class = "SmartObjectHolder",
            name = "MercAnvilAlign_" .. tostring(math.random(100000, 999999)),
            position = standPos, properties = {} })
    end)
    if holder then
        pcall(function() holder:SetAngles({ x = 0, y = 0, z = yaw }) end)
        local ok = pcall(function() sm:SetLinkTarget("alignment", holder.id) end)
        rec.holder = holder
        pcall(function()
            local wang = sm:GetWorldAngles()
            local baseYaw = (wang and wang.z or 0) - math.rad(63)
            local c2, s2 = math.cos(baseYaw), math.sin(baseYaw)
            local lx, ly, lz = 0.046, -2.706, -0.178
            rec.alignOrig = { x = rec.smPos.x - (lx * c2 - ly * s2), y = rec.smPos.y - (lx * s2 + ly * c2), z = rec.smPos.z - lz }
        end)
        System.LogAlways("[Anvil] SetLinkTarget('alignment' -> our holder) ok=" .. tostring(ok))
    else
        System.LogAlways("[Anvil] holder spawn failed - alignment not retargeted")
    end

    self.AnvilBorrow = rec
    local can; pcall(function() can = Blacksmithing.CanUse(player.id, sm.id) end)
    System.LogAlways(string.format("[Anvil] borrowed Smithery logic (was %.0fm), spawned %d camp visuals, CanUse=%s.", dist or -1, #rec.visuals, tostring(can)))
    System.LogAlways("[Anvil] Walk to the anvil + press E (or merc_anvil_use). Restore with merc_anvil_restore.")
end

function mercenaries:AnvilUse()
    if not self.AnvilBorrow then System.LogAlways("[Anvil] nothing borrowed - run merc_anvil_grab first"); return end
    local sm = self.AnvilBorrow.sm
    local can; pcall(function() can = Blacksmithing.CanUse(player.id, sm.id) end)
    System.LogAlways("[Anvil] CanUse=" .. tostring(can) .. ", firing StartMinigame...")
    pcall(function() Blacksmithing.StartMinigame(player.id, sm.id) end)
end

-- Live layout tuner: nudge a spawned forge piece by INDEX (1=anvil_interact
-- 2=anvil_forge 3=forge 4=coal 5=water 6=barrel) with fwd/lat/up deltas (metres),
-- then merc_forge_dump prints the final fwd/lat/up to paste into ForgeVisualLayout.
function mercenaries:ForgeNudge(idx, dfwd, dlat, dup, dyaw)
    local rec = self.AnvilBorrow
    if not rec then System.LogAlways("[Forge] nothing borrowed - run merc_anvil_grab first"); return end
    idx = tonumber(idx); local v = idx and rec.visuals[idx]
    if not v then System.LogAlways("[Forge] no piece #" .. tostring(idx)); return end
    v.fwd = v.fwd + (tonumber(dfwd) or 0)
    v.lat = v.lat + (tonumber(dlat) or 0)
    v.up  = v.up  + (tonumber(dup)  or 0)
    v.yaw = (v.yaw or 0) + (tonumber(dyaw) or 0)
    local w = { x = rec.stand.x + rec.F.x * v.fwd + rec.L.x * v.lat,
                y = rec.stand.y + rec.F.y * v.fwd + rec.L.y * v.lat,
                z = rec.stand.z + v.up }
    pcall(function() v.e:SetWorldPos(w) end)
    pcall(function() v.e:SetAngles({ x = 0, y = 0, z = rec.yaw + math.rad(v.yaw) }) end)
    System.LogAlways(string.format("[Forge] #%d %s -> fwd=%.2f lat=%.2f up=%.2f yaw=%d", idx, v.name, v.fwd, v.lat, v.up, v.yaw))
end

function mercenaries:ForgeDump()
    local rec = self.AnvilBorrow
    if not rec then System.LogAlways("[Forge] nothing borrowed"); return end
    System.LogAlways("[Forge] ==== layout (paste back) ====")
    for i, v in ipairs(rec.visuals) do
        System.LogAlways(string.format('    #%d { name="%s", fwd=%.2f, lat=%.2f, up=%.2f, yaw=%d },', i, v.name, v.fwd, v.lat, v.up, v.yaw or 0))
    end
end

function mercenaries:AnvilRestore()
    local rec = self.AnvilBorrow
    if not rec then System.LogAlways("[Anvil] nothing to restore"); return end
    pcall(function() rec.sm:SetWorldPos(rec.smPos) end)
    for _, v in ipairs(rec.visuals or {}) do pcall(function() System.RemoveEntity(v.e.id) end) end
    -- The alignment link now points at OUR holder (the TagPoint can't be
    -- re-referenced), so park the holder at the village's original alignment
    -- position and leave it linked - equivalent placement for the village smith.
    -- A reload restores the level's own links regardless.
    if rec.holder then
        if rec.alignOrig then pcall(function() rec.holder:SetWorldPos(rec.alignOrig) end)
        else pcall(function() rec.holder:SetWorldPos(rec.smPos) end) end
    end
    self.AnvilBorrow = nil
    System.LogAlways("[Anvil] restored: Smithery back, camp visuals removed, alignment holder parked at the village.")
end

-- merc_forge_real: fire vanilla Blacksmithing.StartMinigame on the nearest real
-- loaded Smithery, to test whether blacksmithing can be driven from Lua at all.
function mercenaries:ForgeReal()
    local sm, dist = self:FindNearestSmithery()
    if not sm then System.LogAlways("[ForgeReal] no loaded Smithery found"); return end
    local pid = player and player.id
    System.LogAlways(string.format("[ForgeReal] nearest real Smithery @ %.1fm, player=%s", dist or -1, tostring(pid)))
    local can
    pcall(function() can = Blacksmithing.CanUse(pid, sm.id) end)
    System.LogAlways("[ForgeReal] Blacksmithing.CanUse = " .. tostring(can))
    local ok, err = pcall(function() Blacksmithing.StartMinigame(pid, sm.id) end)
    System.LogAlways("[ForgeReal] Blacksmithing.StartMinigame ok=" .. tostring(ok) .. (err and (" err=" .. tostring(err)) or ""))
end

-- merc_smithery_dump: find the nearest loaded Smithery and dump every link
-- (name -> linked entity), to see whether its tool/alignment slots can be borrowed.
function mercenaries:FindNearestSmithery()
    if not player then return nil end
    local o = player:GetWorldPos()
    local sm = System.GetEntitiesByClass and System.GetEntitiesByClass("Smithery")
    if not sm then return nil end
    local best, bestD, bestP
    for _, e in pairs(sm) do
        local p = e.GetWorldPos and e:GetWorldPos()
        if p then
            local d = math.sqrt((p.x - o.x) ^ 2 + (p.y - o.y) ^ 2 + (p.z - o.z) ^ 2)
            if not bestD or d < bestD then best, bestD, bestP = e, d, p end
        end
    end
    return best, bestD, bestP
end

function mercenaries:SmitheryDump()
    local sm, dist = self:FindNearestSmithery()
    if not sm then System.LogAlways("[SmithDump] no loaded Smithery found"); return end
    local n = 0; pcall(function() n = sm:CountLinks() end)
    System.LogAlways(string.format("[SmithDump] nearest Smithery '%s' @ %.1fm, %d links:",
        tostring(sm.GetName and sm:GetName()), dist or -1, n))
    for i = 0, n - 1 do
        pcall(function()
            local l, nm = sm:GetLink(i)
            if l then
                local cls, ename, epos, item = "?", "?", nil, nil
                pcall(function() cls = l.class or (l.GetClass and l:GetClass()) or "?" end)
                pcall(function() ename = l.GetName and l:GetName() or "?" end)
                pcall(function() epos = l.GetWorldPos and l:GetWorldPos() end)
                pcall(function() item = EntityModule.GetSlotItemClassId(l.id) end)
                System.LogAlways(string.format("[SmithDump]   [%d] link='%s' class=%s item=%s  %s",
                    i, tostring(nm), tostring(cls), tostring(item), tostring(ename)))
            else
                local _, nm = sm:GetLink(i)
                System.LogAlways(string.format("[SmithDump]   [%d] link='%s' -> (nil entity)", i, tostring(nm)))
            end
        end)
    end
    System.LogAlways("[SmithDump] done. Note whether 'hammer'/'tongs'/'alignment' links resolve to real entities with item guids.")
end

-- Strategy E (merc_forge_func5): spawn the base prefab, census what actually
-- arrived, then spawn our own Smithery and CreateLink it to the arrived pieces.
-- Dead end - see docs/camp-forge.md.
function mercenaries:ForgeBuildFunctional5(yaw)
    self:ForgeBuildFunctional4(yaw)   -- visuals + base prefab (also sets _fD below)
    self._forgeD = { yaw = tonumber(yaw) or 0 }
    -- Anchor for the census = where func4 put the host (recompute identically).
    local o = player and player:GetWorldPos(); if not o then return end
    local d = player:GetDirectionVector() or { x = 0, y = 1, z = 0 }
    local fl = math.sqrt(d.x * d.x + d.y * d.y); if fl < 0.001 then d = { x = 0, y = 1, z = 0 }; fl = 1 end
    self._forgeD.anchor = self:CampSnapToGround({ x = o.x + d.x / fl * 4, y = o.y + d.y / fl * 4, z = o.z })
    Script.SetTimerForFunction(600, "mercenaries.ForgeCensusStep")
end

function mercenaries.ForgeCensusStep()
    local self = mercenaries
    local st = self._forgeD
    if not (st and st.anchor) then return end
    local a = st.anchor
    local function near(ent, r)
        local p = ent.GetWorldPos and ent:GetWorldPos() or (ent.GetPos and ent:GetPos())
        if not p then return false, 999 end
        local dx, dy = p.x - a.x, p.y - a.y
        local dist = math.sqrt(dx * dx + dy * dy)
        return dist <= (r or 12), dist
    end

    System.LogAlways("[Forge] E census: entities near the forge, by class:")
    local found = {}
    for _, cls in ipairs({ "Smithery", "ItemSlot", "TagPoint", "SmartObjectHolder", "ParticleEffect", "Light", "Shop", "GhostDummy" }) do
        local ents = System.GetEntitiesByClass and System.GetEntitiesByClass(cls) or nil
        if ents then
            for _, e in pairs(ents) do
                local ok, dist = near(e, 12)
                if ok then
                    System.LogAlways(string.format("[Forge] E   %-18s %5.1fm  %s", cls, dist, tostring(e:GetName())))
                    found[cls] = found[cls] or {}
                    table.insert(found[cls], e)
                end
            end
        else
            System.LogAlways("[Forge] E   (GetEntitiesByClass unavailable for " .. cls .. ")")
        end
    end

    -- If the prefab's Smithery is there, dump its links and stop - the E should
    -- come from it. If not, spawn ours and wire it to what we found.
    local sm = found["Smithery"] and found["Smithery"][1]
    if sm then
        local n = 0; pcall(function() n = sm:CountLinks() end)
        System.LogAlways("[Forge] E: prefab Smithery IS present with " .. n .. " links:")
        for i = 0, n - 1 do
            pcall(function()
                local l, nm = sm:GetLink(i)
                System.LogAlways("[Forge] E    link '" .. tostring(nm) .. "' -> " .. tostring(l and l:GetName()))
            end)
        end
        System.LogAlways("[Forge] E: walk around the anvil/pyramid and check for the E prompt.")
        return
    end

    System.LogAlways("[Forge] E: no prefab Smithery - spawning ours and wiring to the prefab pieces...")
    local th = math.rad(st.yaw)
    local cs, sn = math.cos(th), math.sin(th)
    local wpos = { x = a.x + (0.30 * cs - (-0.85) * sn), y = a.y + (0.30 * sn + (-0.85) * cs), z = a.z - 0.18 }
    local mySm
    pcall(function()
        mySm = System.SpawnEntity({
            class = "Smithery",
            name = "MercSmithery_" .. tostring(math.random(100000, 999999)),
            position = wpos,
            properties = { object_Model = "objects/special/primitive_cylinder.cgf" },
        })
    end)
    if not mySm then System.LogAlways("[Forge] E: our Smithery spawn failed"); return end
    table.insert(self.UpgradePreviewEntities, mySm.id)
    pcall(function() mySm:SetAngles({ x = 0, y = 0, z = math.rad(63 + st.yaw) }) end)
    pcall(function() mySm:SetScale(0.7) end)

    local function linkIt(name, e)
        if not e then return end
        local before = 0; pcall(function() before = mySm:CountLinks() end)
        pcall(function() mySm:CreateLink(name, e.id) end)
        local after = before; pcall(function() after = mySm:CountLinks() end)
        System.LogAlways("[Forge] E: link '" .. name .. "' -> " .. tostring(e:GetName()) .. " : " .. tostring(after > before))
    end
    -- hammer/tongs: tell them apart by name (prefab names carry HammerSlot/TongsSlot).
    for _, e in ipairs(found["ItemSlot"] or {}) do
        local nm = tostring(e:GetName() or "")
        if nm:find("Hammer") then linkIt("hammer", e)
        elseif nm:find("Tongs") then linkIt("tongs", e)
        elseif nm:find("sword") or nm:find("Sword") then -- ignore the display sword slot
        else System.LogAlways("[Forge] E: unclassified ItemSlot: " .. nm) end
    end
    for _, e in ipairs(found["TagPoint"] or {}) do
        if tostring(e:GetName() or ""):find("Align") then linkIt("alignment", e) end
    end
    linkIt("", found["SmartObjectHolder"] and found["SmartObjectHolder"][1])
    for _, e in ipairs(found["ParticleEffect"] or {}) do
        local nm = tostring(e:GetName() or "")
        if nm:find("forge_particle_big") then linkIt("forgeStartParticles", e)
        elseif nm:find("forge_particle") then linkIt("forgeHeatingParticles", e)
        elseif nm:find("hammering_hit") then linkIt("anvilParticles", e)
        elseif nm:find("hardening") then linkIt("hardeningParticles", e) end
    end
    linkIt("forgeLight", found["Light"] and found["Light"][1])
    local total = 0; pcall(function() total = mySm:CountLinks() end)
    System.LogAlways("[Forge] E ready: our Smithery wired to prefab pieces (CountLinks=" .. total .. "). Press E at the anvil.")
end

function mercenaries:ForgeBuildFunctional3(yaw)
    yaw = tonumber(yaw) or 0
    self:ClearUpgradePreview()
    if not player then return end
    local o = player:GetWorldPos()
    local d = player:GetDirectionVector() or { x = 0, y = 1, z = 0 }
    local fl = math.sqrt(d.x * d.x + d.y * d.y); if fl < 0.001 then d = { x = 0, y = 1, z = 0 }; fl = 1 end
    local anchor = self:CampSnapToGround({ x = o.x + d.x / fl * 4, y = o.y + d.y / fl * 4, z = o.z })
    self:UpgradePreviewSpawnModel(self.UpgradePreviewFlag, anchor, "flag")
    self:UpgradePreviewSpawnComposition(self.ForgeRigBrushes, anchor, yaw)

    local th = math.rad(yaw)
    local cs, sn = math.cos(th), math.sin(th)
    local function world(dx, dy, dz)
        return { x = anchor.x + (dx * cs - dy * sn), y = anchor.y + (dx * sn + dy * cs), z = anchor.z + dz }
    end

    -- The Smithery itself (exact prefab transform: base (0.05,-2.71,-0.18) yaw 63, scale 0.7).
    local sm
    pcall(function()
        sm = System.SpawnEntity({
            class = "Smithery",
            name = "MercSmithery_" .. tostring(math.random(100000, 999999)),
            position = world(0.30, -0.85, -0.18),
            properties = { object_Model = "objects/special/primitive_cylinder.cgf" },
        })
    end)
    if not sm then System.LogAlways("[Forge] C: Smithery spawn FAILED"); return end
    table.insert(self.UpgradePreviewEntities, sm.id)
    pcall(function() sm:SetAngles({ x = 0, y = 0, z = math.rad(63 + yaw) }) end)
    pcall(function() sm:SetScale(0.7) end)

    -- STAGED spawn: one rig part per 0.5s, logging BEFORE each spawn. The last
    -- run hard-crashed the GPU somewhere in this batch, so if it dies again the
    -- final "[Forge] C: spawning" line in kcd.log names the culprit exactly.
    self._forgeRig = { sm = sm, anchor = anchor, yaw = yaw, idx = 0 }
    System.LogAlways("[Forge] C: staged spawn of " .. #self.ForgeRigLinks
        .. " rig parts (one per 0.5s). If it crashes, the last '[Forge] C: spawning' line is the culprit.")
    mercenaries.ForgeRigStep()
end

function mercenaries.ForgeRigStep()
    local self = mercenaries
    local st = self._forgeRig
    if not st or not st.sm then return end
    st.idx = st.idx + 1
    local p = self.ForgeRigLinks[st.idx]
    if not p then
        local total = 0; pcall(function() total = st.sm:CountLinks() end)
        System.LogAlways("[Forge] C ready: all parts spawned, Smithery CountLinks=" .. tostring(total) .. ". Press E at the anvil.")
        self._forgeRig = nil
        return
    end
    System.LogAlways(string.format("[Forge] C: spawning part %d/%d '%s' (%s)...",
        st.idx, #self.ForgeRigLinks, p.link == "" and "smartobject" or p.link, p.class))

    local th = math.rad(st.yaw)
    local cs, sn = math.cos(th), math.sin(th)
    local pos = {
        x = st.anchor.x + (p.dx * cs - p.dy * sn),
        y = st.anchor.y + (p.dx * sn + p.dy * cs),
        z = st.anchor.z + p.dz,
    }
    -- Try each candidate class in order, LOGGING the actual failure reason
    -- (last run's silent "spawn FAILED" hid whether it's an unknown class, a
    -- property mismatch, or an OnInit error).
    local ent
    for _, cls in ipairs(p.classes or { p.class }) do
        local ok, err = pcall(function()
            ent = System.SpawnEntity({
                class = cls,
                name = "MercForgeRig_" .. (p.link == "" and "so" or p.link) .. "_" .. tostring(math.random(100000, 999999)),
                position = pos,
                properties = p.props,
            })
        end)
        if not ok then
            System.LogAlways("[Forge] C:   class '" .. cls .. "' errored: " .. tostring(err))
        elseif not ent then
            System.LogAlways("[Forge] C:   class '" .. cls .. "' returned nil (no error)")
        else
            if cls ~= (p.classes and p.classes[1] or p.class) then
                System.LogAlways("[Forge] C:   fell back to class '" .. cls .. "'")
            end
            break
        end
    end
    if ent then
        table.insert(self.UpgradePreviewEntities, ent.id)
        pcall(function() ent:SetAngles({ x = 0, y = 0, z = math.rad((p.yaw or 0) + st.yaw) }) end)
        if p.s then pcall(function() ent:SetScale(p.s) end) end
        local before = 0
        pcall(function() before = st.sm:CountLinks() end)
        pcall(function() st.sm:CreateLink(p.link, ent.id) end)
        local after = before
        pcall(function() after = st.sm:CountLinks() end)
        if after == before then pcall(function() st.sm:CreateLink(ent.id, p.link) end) end
        pcall(function() after = st.sm:CountLinks() end)
        System.LogAlways(string.format("[Forge] C: part %d '%s' spawned, linked=%s (links %d -> %d)",
            st.idx, p.link == "" and "smartobject" or p.link, tostring(after > before), before, after))
    else
        System.LogAlways("[Forge] C: spawn FAILED for '" .. p.link .. "' (" .. p.class .. ")")
    end
    Script.SetTimerForFunction(500, "mercenaries.ForgeRigStep")
end

function mercenaries:UpgradePreviewRow(assets, spacing)
    if not player then return end
    spacing = spacing or self.UpgradePreviewSpacing
    local ok, err = pcall(function()
        self:ClearUpgradePreview()

        local origin = player:GetWorldPos()
        local dir = player:GetDirectionVector() or { x = 0, y = 1, z = 0 }
        -- Flatten forward to the ground plane and normalise.
        local fl = math.sqrt(dir.x * dir.x + dir.y * dir.y)
        if fl < 0.001 then dir = { x = 0, y = 1, z = 0 }; fl = 1 end
        local fwd   = { x = dir.x / fl, y = dir.y / fl }
        -- Right-hand perpendicular in the ground plane (row runs to the right).
        local right = { x = fwd.y, y = -fwd.x }

        System.LogAlways("[UpgradePreview] ==== spawning " .. #assets .. " assets in a row to your right ====")

        for i, a in ipairs(assets) do
            local k = i - 1
            -- Prop spot: in front of the player, then stepped along "right".
            local cx = origin.x + fwd.x * self.UpgradePreviewStartDist + right.x * (k * spacing)
            local cy = origin.y + fwd.y * self.UpgradePreviewStartDist + right.y * (k * spacing)
            local spot = self:CampSnapToGround({ x = cx, y = cy, z = origin.z })

            -- Flag ~1.2m toward the player so it stays visible even under a big prop.
            local flag = self:CampSnapToGround({ x = spot.x - fwd.x * 1.2, y = spot.y - fwd.y * 1.2, z = origin.z })
            self:UpgradePreviewSpawnModel(self.UpgradePreviewFlag, flag, "flag")

            if a.composition then
                self:UpgradePreviewSpawnComposition(a.composition, spot)
            elseif a.prefab then
                self:UpgradePreviewSpawnPrefab(a.prefab, spot)
            elseif a.pile then
                -- A small cluster: three on the ground, one on top.
                local off = { { 0, 0, 0 }, { 0.6, 0.1, 0 }, { 0.25, 0.6, 0 }, { 0.3, 0.25, 0.72 } }
                for _, o in ipairs(off) do
                    self:UpgradePreviewSpawnModel(a.model, { x = spot.x + o[1], y = spot.y + o[2], z = spot.z + o[3] }, a.label)
                end
            else
                self:UpgradePreviewSpawnModel(a.model, spot, a.label)
            end

            System.LogAlways(string.format("[UpgradePreview]  spot %2d (flag) -> %-22s %s", i, a.label, a.model or a.prefab or "?"))
        end

        Game.SendInfoText("@merc_logi_msg Upgrade preview: " .. #assets .. " assets spawned to your right (see kcd.log for the order).", false, 0, 5)
    end)
    if not ok then System.LogAlways("[UpgradePreview] error: " .. tostring(err)) end
end

function mercenaries:ClearUpgradePreview()
    for _, id in ipairs(self.UpgradePreviewEntities or {}) do
        if self.UpgradePreviewPrefabHosts[id] then
            pcall(function() Game.DeletePrefab(id) end)
        end
        pcall(function() System.RemoveEntity(id) end)
    end
    self.UpgradePreviewEntities = {}
    self.UpgradePreviewPrefabHosts = {}
end

-- Interactive part tuner: place one part at a time and nudge its position /
-- rotation / scale until it looks right, then merc_part_dump prints the values.
-- Parts are picked by index (1=forge 2=coals 3=anvil 4=water 5=barrel); offsets
-- are world-axis metres from the merc_part_reset anchor (4m ahead of you). Re-run
-- the same index to re-place that part in situ. Commands: merc_part_reset /
-- merc_part <idx> dx dy dz rx ry rz s / merc_part_dump.
mercenaries.PartList = {
    { name = "forge",  model = "objects/manmade/task_specific_props/metal_industry/smithing/forge_small_a.cgf" },
    { name = "coals",  model = "objects/manmade/structures/industrial/smitheries/coal_forge_small_a.cgf" },
    { name = "anvil",  model = "objects/manmade/task_specific_props/metal_industry/smithing/anvil.cgf" },
    { name = "water",  model = "objects/manmade/task_specific_props/metal_industry/smithing/water_container.cgf" },
    { name = "barrel", model = "objects/manmade/task_specific_props/metal_industry/smithing/barrel_forging.cgf" },
}
mercenaries.PartInstances = {}   -- index -> entity id
mercenaries.PartParams    = {}   -- index -> last params (for dump)
mercenaries.PartAnchor    = nil

function mercenaries:PartReset()
    for _, id in pairs(self.PartInstances) do pcall(function() System.RemoveEntity(id) end) end
    self.PartInstances, self.PartParams = {}, {}
    if player then
        local o = player:GetWorldPos()
        local d = player:GetDirectionVector() or { x = 0, y = 1, z = 0 }
        local fl = math.sqrt(d.x * d.x + d.y * d.y); if fl < 0.001 then d = { x = 0, y = 1, z = 0 }; fl = 1 end
        self.PartAnchor = self:CampSnapToGround({ x = o.x + d.x / fl * 4, y = o.y + d.y / fl * 4, z = o.z })
    end
    System.LogAlways("[Part] anchor reset, parts cleared. names: forge coals anvil water barrel")
end

function mercenaries:PartSpawn(sel, dx, dy, dz, rx, ry, rz, s)
    local idx = tonumber(sel)
    local entry = idx and self.PartList[idx]
    if not entry then
        System.LogAlways("[Part] unknown part '" .. tostring(sel) .. "' - use an index 1-" .. #self.PartList
            .. " (1=forge 2=coals 3=anvil 4=water 5=barrel)")
        return
    end
    dx = tonumber(dx) or 0; dy = tonumber(dy) or 0; dz = tonumber(dz) or 0
    rx = tonumber(rx) or 0; ry = tonumber(ry) or 0; rz = tonumber(rz) or 0
    s  = tonumber(s)  or 1.0
    if not self.PartAnchor then self:PartReset() end
    local a = self.PartAnchor
    -- Replace any previous instance of this index so tuning re-places it in situ.
    if self.PartInstances[idx] then pcall(function() System.RemoveEntity(self.PartInstances[idx]) end) end
    local wx, wy, wz = a.x + dx, a.y + dy, a.z + dz
    local params = {
        class = "BasicEntity",
        name = "MercPart_" .. entry.name .. "_" .. tostring(math.random(100000, 999999)),
        position = { x = wx, y = wy, z = wz },
        orientation = { x = math.rad(rx), y = math.rad(ry), z = math.rad(rz) },
        properties = { object_Model = entry.model, bMissionCritical = false, bSaved_by_game = false, bSerialize = false },
    }
    if s ~= 1.0 then params.scale = s end
    local ent = System.SpawnEntity(params)
    if ent then
        self.PartInstances[idx] = ent.id
        if s ~= 1.0 then pcall(function() ent:SetScale(s) end) end
    else
        System.LogAlways("[Part] spawn failed for " .. entry.model)
    end
    self.PartParams[idx] = { name = entry.name, dx = dx, dy = dy, dz = dz, rx = rx, ry = ry, rz = rz, s = s }
    System.LogAlways(string.format("[Part] %d %-7s off %.2f,%.2f,%.2f  rot %d,%d,%d  s=%.2f  (world %.1f,%.1f,%.1f)",
        idx, entry.name, dx, dy, dz, rx, ry, rz, s, wx, wy, wz))
end

function mercenaries:PartDump()
    System.LogAlways("[Part] ==== current parts (paste this back) ====")
    for _, p in pairs(self.PartParams) do
        System.LogAlways(string.format('    { name="%s", dx=%.2f, dy=%.2f, dz=%.2f, rx=%d, ry=%d, rz=%d, s=%.2f },',
            p.name, p.dx, p.dy, p.dz, p.rx, p.ry, p.rz, p.s))
    end
end

mercenaries:DevCommand("merc_upgrade_preview", "mercenaries:UpgradePreview()",
    "Spawn one candidate prop per camp upgrade in a flag-marked row in front of you (see kcd.log for the order).")
mercenaries:DevCommand("merc_upgrade_preview_clear", "mercenaries:ClearUpgradePreview()",
    "Remove the merc_upgrade_preview props.")
mercenaries:DevCommand("merc_forge_preview", "mercenaries:ForgePreview()",
    "Spawn the forge/smithy candidates in a flag-marked row (see kcd.log for the order). Clear with merc_upgrade_preview_clear.")
mercenaries:DevCommand("merc_prefab_preview", "mercenaries:PrefabPreview()",
    "Spawn complete prefab compositions (smithy workshop, cooking station, alchemy table, camp fireplace, gate tower) in a flag-marked row. Clear with merc_upgrade_preview_clear.")
mercenaries:DevCommand("merc_composition_preview", "mercenaries:CompositionPreview()",
    "Spawn our own hand-built prop compositions (e.g. the full forge kit) from real models. Clear with merc_upgrade_preview_clear.")
mercenaries:DevCommand("merc_forge_build", "mercenaries:ForgeBuild(%1)",
    "Build the whole forge (visual only) 4m in front of you, rotated by a global yaw in degrees. Re-run to re-orient; clear with merc_upgrade_preview_clear.")
mercenaries:DevCommand("merc_forge_func", "mercenaries:ForgeBuildFunctional(%1)",
    "Functional forge, strategy A: visuals + Smithery + blacksmith SmartObjectHolder, GetLinkedSmartObject monkey-patched. Press E at the anvil. Clear with merc_upgrade_preview_clear.")
mercenaries:DevCommand("merc_forge_func2", "mercenaries:ForgeBuildFunctional2(%1)",
    "Functional forge, strategy B: same build but linked via the engine's entity CreateLink (if exposed). Press E at the anvil. Clear with merc_upgrade_preview_clear.")
mercenaries:DevCommand("merc_forge_func3", "mercenaries:ForgeBuildFunctional3(%1)",
    "Functional forge, strategy C: the COMPLETE rig - item slots (hammer/tongs), alignment point, coal, bellows bag, particles, light, all entity-linked. Press E at the anvil. Clear with merc_upgrade_preview_clear.")
mercenaries:DevCommand("merc_forge_func4", "mercenaries:ForgeBuildFunctional4(%1)",
    "Functional forge, strategy D: our visuals + the NESTED smithy_workshop_base prefab spawned directly - its Smithery/ItemSlots/alignment come pre-linked. Press E at the anvil. Clear with merc_upgrade_preview_clear.")
mercenaries:DevCommand("merc_forge_func5", "mercenaries:ForgeBuildFunctional5(%1)",
    "Functional forge, strategy E: base prefab + census of what actually spawned (logged) + auto-wire our Smithery to the prefab's ItemSlots/alignment/holder if its own is missing. Clear with merc_upgrade_preview_clear.")
mercenaries:DevCommand("merc_itemslot_scan", "mercenaries:ItemSlotScan()",
    "Recon: enumerate loaded ItemSlots + report any blacksmith hammer/tongs slots and their distance (tests the ItemSlot-hijack idea). Output in kcd.log.")
mercenaries:DevCommand("merc_smithery_dump", "mercenaries:SmitheryDump()",
    "Recon: find the nearest loaded (real, village) Smithery and dump its links - can we grab its hammer/tongs/alignment slot entities? Output in kcd.log.")
mercenaries:DevCommand("merc_forge_real", "mercenaries:ForgeReal()",
    "Fire Blacksmithing.StartMinigame on the nearest REAL loaded Smithery (which already has working slots). If it runs cleanly, a camp forge near a settlement can trigger it.")
mercenaries:DevCommand("merc_anvil_grab", "mercenaries:AnvilGrab()",
    "Teleport the nearest REAL Smithery (+ its alignment holder) to right in front of you, so you can smith at camp with its real tool slots. Restore with merc_anvil_restore.")
mercenaries:DevCommand("merc_anvil_use", "mercenaries:AnvilUse()",
    "Force-start blacksmithing on the borrowed anvil (if pressing E doesn't).")
mercenaries:DevCommand("merc_anvil_restore", "mercenaries:AnvilRestore()",
    "Put the borrowed village Smithery back where it belongs.")
mercenaries:DevCommand("merc_forge_nudge", "mercenaries:ForgeNudge(%1, %2, %3, %4, %5)",
    "Live-tune the borrowed forge: merc_forge_nudge <idx> dfwd dlat dup dyaw  (1=anvil_interact 2=anvil_forge 3=forge 4=coal 5=water 6=barrel 7=bellows 8=furnace; metres + degrees, +fwd=toward anvil, +lat=left, +yaw=CCW).")
mercenaries:DevCommand("merc_forge_dump", "mercenaries:ForgeDump()",
    "Print the current borrowed-forge layout (fwd/lat/up per piece) to paste back into ForgeVisualLayout.")
mercenaries:DevCommand("merc_part_reset", "mercenaries:PartReset()",
    "Part tuner: clear placed parts and set the anchor 4m in front of you.")
mercenaries:DevCommand("merc_part", "mercenaries:PartSpawn(%1, %2, %3, %4, %5, %6, %7, %8)",
    "Part tuner: merc_part <idx> dx dy dz rx ry rz scale  (idx 1=forge 2=coals 3=anvil 4=water 5=barrel; all 8 args; pos metres, rot degrees, scale e.g. 1).")
mercenaries:DevCommand("merc_part_dump", "mercenaries:PartDump()",
    "Part tuner: print all current parts' pos/rot/scale to the log to paste back.")
