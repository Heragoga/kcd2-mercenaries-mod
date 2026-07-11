-- =======================================================================
-- QUARTERMASTER - a single, immortal camp NPC that acts as a talking
-- interface for the player. He spawns near the player's tent whenever camp
-- is made and despawns when it's broken down. His whole job is to stand
-- there (occasionally eating) and be talked to; for now the dialog is just
-- a placeholder. He has a custom "lobotomized merc" brain
-- (quartermaster_brain): no follow, no schedule, no barks - he only stands,
-- eats, and defends himself with the shared melee tree when the camp is
-- raided. He can't die (soul_vip_class_id 12).
--
-- Wiring lives across:
--   data/libs/tables/ai/*__quartermaster.xml    (custom brain)
--   data/libs/tables/rpg/soul__quartermaster.xml (the soul)
--   data/AI/quartermaster_scheduler.xml          (the switch)
--   data/AI/quartermaster_idle.xml               (stand + eat)
--   data/quests/.../quartermaster_dialog.xml     (the talk interface)
-- He borrows his look/loadout from the base game the way renegades do:
-- appearance via storm, clothes + weapon applied here on spawn.
-- =======================================================================

mercenaries.QuartermasterSoul = "7a3d1f88-2c4b-4e6a-9f01-3b8c5d2e7a44"

-- Every spawned quartermaster is named with this prefix so leftover ones can
-- be swept by name (ClearAnyLeftoverCamp), the same way camp props are.
mercenaries.QuartermasterNamePrefix = "MercQuartermaster_"

-- Bailiff outfit + a plain sword-and-shield loadout, both vanilla presets
-- referenced directly (like mercenaries.Outfits / mercenaries.WeaponSets).
-- kpri_bailiff reads as a period supply/official figure.
mercenaries.QuartermasterClothing = "9fa83a0e-2f43-420b-86dd-c20f1c4c2525" -- clothing_preset kpri_bailiff
mercenaries.QuartermasterWeapon   = "85741a9f-1e35-45b8-879e-cfa17fc87dc0" -- weapon_preset (strong sword + shield)

-- Live handle to the spawned quartermaster (nil when no camp is up).
mercenaries.QuartermasterId = nil

-- His post: where he stands, and a point he faces (the tent centre). The
-- idle behaviour (quartermaster_idle.xml) reads this each cycle so that after
-- a fight - which drags him toward the enemy via the shared combat tree - he
-- walks back here, sheathes, and faces the tent again.
mercenaries.QuartermasterPost = nil

function mercenaries:GetQuartermasterPost()
    return self.QuartermasterPost
end

-- =======================================================================
-- Spawn the quartermaster near the player's tent. centerPos is the camp
-- grid origin (where the player tent sits) and facingAngle is the world
-- direction the camp was built around - both already computed in
-- SpawnMercCamp. He's placed a couple of metres off to the side of the tent
-- and turned to face it, so he greets the player walking up to the tent.
-- =======================================================================
function mercenaries:SpawnQuartermaster(centerPos, facingAngle)
    if not centerPos then return end

    -- Never leave a stray one behind.
    self:DespawnQuartermaster()

    local ok, err = pcall(function()
        -- Place him in FRONT of the player tent - i.e. out the tent's own
        -- door. The player tent model is spawned turned to
        -- (facingAngle + 130deg) (see SpawnPlayerCampTent's tentAngle), so its
        -- entrance faces that way, NOT along the raw grid-forward axis - which
        -- is why offsetting along facingAngle landed him behind the tent.
        -- Offset a few metres along the entrance direction, a touch to the
        -- side so he doesn't block the doorway, then ground-snap.
        local entranceAngle = (facingAngle or 0) + math.rad(130)
        local qpos = self:CampRelativeOffset(centerPos, entranceAngle, { right = 1.5, forward = 3.2 })
        qpos = self:FindValidGround(qpos, centerPos.z)

        -- Face back toward the tent/centre so he looks at the approaching player.
        local faceAngle = math.atan2(centerPos.y - qpos.y, centerPos.x - qpos.x)

        local entityName = self.QuartermasterNamePrefix .. tostring(math.random(100000, 999999)) .. "_" .. self.QuartermasterSoul

        System.SpawnEntity({
            class       = "NPC",
            name        = entityName,
            position    = qpos,
            orientation = { x = 0, y = 0, z = faceAngle },
            properties  = { guidSharedSoulId = self.QuartermasterSoul }
        })

        -- Remember the post (stand spot + the tent centre to face) for the
        -- idle behaviour's "return home after a fight" logic.
        self.QuartermasterPost = {
            x = qpos.x, y = qpos.y, z = qpos.z,
            faceX = centerPos.x, faceY = centerPos.y, faceZ = centerPos.z,
        }

        local ent = System.GetEntityByName(entityName)
        if ent then
            self.QuartermasterId = ent.id
            self.QuartermasterName = entityName   -- so logistics can find him (health regen, food inventory)
            pcall(function() self:EnsureMercIsAlwaysRendered(ent) end)
            -- Dress + arm him from the base game presets (renegade pattern).
            if ent.actor then
                pcall(function() ent.actor:EquipClothingPreset(self.QuartermasterClothing) end)
                pcall(function() ent.actor:EquipWeaponPreset(self.QuartermasterWeapon) end)
            end
            System.LogAlways('[Mercenaries] Quartermaster spawned: ' .. entityName)
        else
            System.LogAlways('[Mercenaries] Quartermaster spawn failed (entity not found after spawn).')
        end
    end)

    if not ok then
        System.LogAlways('[Mercenaries] SpawnQuartermaster error: ' .. tostring(err))
    end
end

-- =======================================================================
-- Despawn the quartermaster. Removes the tracked entity and, as a safety
-- net, sweeps for any stray one by name prefix (a camp that was active
-- during a save loses the tracked id but the NPC may still be around).
-- =======================================================================
function mercenaries:DespawnQuartermaster()
    self.QuartermasterPost = nil
    self.QuartermasterName = nil
    if self.QuartermasterId then
        pcall(function() System.RemoveEntity(self.QuartermasterId) end)
        self.QuartermasterId = nil
    end

    -- Name-prefix sweep near the player, mirroring ClearAnyLeftoverCamp.
    pcall(function()
        if not player then return end
        local pp = player:GetWorldPos()
        if not pp then return end
        local ents = System.GetPhysicalEntitiesInBoxByClass(pp, 200.0, "NPC")
        if ents then
            for _, ent in pairs(ents) do
                if ent and ent.GetName and string.find(ent:GetName() or '', self.QuartermasterNamePrefix, 1, true) then
                    pcall(function() System.RemoveEntity(ent.id) end)
                end
            end
        end
    end)
end

-- =======================================================================
-- Defensive target selection, called ~1s from quartermaster_scheduler.xml.
-- Unlike the renegades' indiscriminate FindRenegadeTarget, the quartermaster
-- only ever picks a genuinely hostile, weapon-drawn NPC near him (a raider),
-- using the shared IsValidEnemy filter (skips the player, mercs, archers,
-- non-hostiles). He never wanders, so the scan is centred on himself, not
-- the player. Sticks with a live, close target instead of re-rolling.
-- =======================================================================
mercenaries.QuartermasterEngageRadius = 30.0

function mercenaries:FindQuartermasterTarget(data, myWuid)
    local ok, err = pcall(function()
        local me = XGenAIModule.GetEntityByWUID(myWuid)
        if not me then return end
        local mp = me:GetPos()
        if not mp then return end

        local playerWuid = player and (player.this and player.this.id or player.id)

        -- Keep a still-valid, still-close current target rather than rescanning.
        if data.currentTarget then
            local curEnt = XGenAIModule.GetEntityByWUID(data.currentTarget)
            if curEnt and curEnt.soul and self:IsValidEnemy(curEnt, nil, playerWuid) then
                local cp = curEnt:GetPos()
                if cp then
                    local dx, dy, dz = cp.x - mp.x, cp.y - mp.y, cp.z - mp.z
                    if (dx * dx + dy * dy + dz * dz) <= (self.QuartermasterEngageRadius * self.QuartermasterEngageRadius) then
                        return
                    end
                end
            end
        end

        local radiusSq = self.QuartermasterEngageRadius * self.QuartermasterEngageRadius
        local best, bestDist = nil, nil

        local ents = System.GetPhysicalEntitiesInBoxByClass(mp, self.QuartermasterEngageRadius, "NPC")
        if ents then
            for _, ent in pairs(ents) do
                if ent and type(ent) == "table" and ent.soul and ent.this and ent.this.id then
                    if self:IsValidEnemy(ent, nil, playerWuid) then
                        local ep = ent:GetPos()
                        if ep then
                            local dx, dy, dz = ep.x - mp.x, ep.y - mp.y, ep.z - mp.z
                            local d2 = dx * dx + dy * dy + dz * dz
                            if d2 <= radiusSq and (not bestDist or d2 < bestDist) then
                                best, bestDist = ent.this.id, d2
                            end
                        end
                    end
                end
            end
        end

        data.currentTarget = best -- nil when nothing hostile is near
    end)

    if not ok then
        System.LogAlways('[Mercenaries] FindQuartermasterTarget error: ' .. tostring(err))
    end
end

-- =======================================================================
-- Placeholder handler for the quartermaster's test dialog. Just a
-- confirmation for now; this is where the camp-management interface will
-- eventually hook in.
-- =======================================================================
function mercenaries:QuartermasterTest()
    Game.SendInfoText('merc_info_quartermaster_test', false, 0, 3)
    System.LogAlways('[Mercenaries] Quartermaster test dialog fired.')
end
