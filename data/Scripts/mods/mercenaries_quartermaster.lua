-- Quartermaster: an immortal camp NPC that serves as the talking interface, with
-- a stripped-down "lobotomized merc" brain (stand, eat, self-defend only). See
-- docs/quartermaster.md for the brain/soul/scheduler wiring.

mercenaries.QuartermasterSoul = "7a3d1f88-2c4b-4e6a-9f01-3b8c5d2e7a44"

-- Name prefix so leftover ones can be swept by name (ClearAnyLeftoverCamp).
mercenaries.QuartermasterNamePrefix = "MercQuartermaster_"

mercenaries.QuartermasterClothing = "9fa83a0e-2f43-420b-86dd-c20f1c4c2525" -- clothing_preset kpri_bailiff
mercenaries.QuartermasterWeapon   = "85741a9f-1e35-45b8-879e-cfa17fc87dc0" -- weapon_preset (strong sword + shield)

mercenaries.QuartermasterId = nil

-- His post: stand spot + a point he faces (tent centre). quartermaster_idle.xml
-- reads this each cycle to walk him back and re-face the tent after a fight.
mercenaries.QuartermasterPost = nil

-- Where he stands, as {right, forward} from the doorway he's posted outside of.
-- The tent and the house (Player House upgrade) have different doorways AND very
-- different footprints, so each gets its own offset - the tent's would leave him
-- standing inside the hut's side wall.
mercenaries.QuartermasterTentOffset  = { right = 1.5, forward = 3.2 }
mercenaries.QuartermasterHouseOffset = { right = 2.0, forward = 5.0 }

function mercenaries:GetQuartermasterPost()
    return self.QuartermasterPost
end

-- Spawn the quartermaster beside the player tent, facing it. centerPos is the
-- camp grid origin and facingAngle the direction camp was built around.
function mercenaries:SpawnQuartermaster(centerPos, facingAngle)
    if not centerPos then return end

    self:DespawnQuartermaster()

    local ok, err = pcall(function()
        -- Place him out the doorway, offset a little to the side so he doesn't
        -- block it. The tent's entrance faces (facingAngle + 130deg), not raw
        -- grid-forward (see SpawnPlayerCampTent). The house instead opens along
        -- grid-forward (its door gable is the local -X end, and it's spawned at
        -- facingAngle + pi), and its body runs ~5m the OTHER way - so he needs the
        -- forward axis and more clearance, or he ends up inside a wall.
        local house = false
        pcall(function() house = self.LogiState and self:LogiState().hasHouse end)
        local entranceAngle = (facingAngle or 0) + (house and 0 or math.rad(130))
        local off = house and self.QuartermasterHouseOffset or self.QuartermasterTentOffset
        local qpos = self:CampRelativeOffset(centerPos, entranceAngle, off)
        qpos = self:FindValidGround(qpos, centerPos.z)

        -- Face back toward the tent/centre so he looks at the approaching player.
        local faceAngle = math.atan2(centerPos.y - qpos.y, centerPos.x - qpos.x)

        local entityName = self.QuartermasterNamePrefix .. tostring(math.random(100000, 999999)) .. "_" .. self.QuartermasterSoul

        System.SpawnEntity({
            class       = "NPC",
            name        = entityName,
            position    = qpos,
            orientation = { x = 0, y = 0, z = faceAngle },
            properties  = mercenaries:NoSaveProps({ guidSharedSoulId = self.QuartermasterSoul })
        })

        self.QuartermasterPost = {
            x = qpos.x, y = qpos.y, z = qpos.z,
            faceX = centerPos.x, faceY = centerPos.y, faceZ = centerPos.z,
        }

        local ent = System.GetEntityByName(entityName)
        if ent then
            self.QuartermasterId = ent.id
            self.QuartermasterName = entityName   -- so logistics can find him (health regen, food inventory)
            pcall(function() self:EnsureMercIsAlwaysRendered(ent) end)
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

-- Despawn the quartermaster, plus a name-prefix sweep for strays (a camp active
-- during a save loses the tracked id but the NPC may still be around).
function mercenaries:DespawnQuartermaster()
    self.QuartermasterPost = nil
    self.QuartermasterName = nil
    if self.QuartermasterId then
        pcall(function() System.RemoveEntity(self.QuartermasterId) end)
        self.QuartermasterId = nil
    end

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

-- Defensive target selection, called ~1s from quartermaster_scheduler.xml. Picks
-- a hostile NPC within range of himself (IsValidEnemy filter); keeps a still-close
-- current target rather than re-rolling.
mercenaries.QuartermasterEngageRadius = 30.0

-- data.qmHasTarget, not `$currentTarget ~= $__null`, is what the scheduler switches on: a Lua
-- nil does not clear a BT _wuid, so once he had fought once $currentTarget stayed set for ever
-- and he never dropped back to quartermaster_idle - he just stood where the fight ended.
-- Everywhere else in the mod a _wuid is cleared by a BT Expression; here the flag does it.
function mercenaries:FindQuartermasterTarget(data, myWuid)
    data.qmHasTarget = false
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
                        data.qmHasTarget = true
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

        -- Only ever WRITE a real wuid; the flag is what says whether it is current.
        if best then data.currentTarget = best end
        data.qmHasTarget = (best ~= nil)
    end)

    if not ok then
        System.LogAlways('[Mercenaries] FindQuartermasterTarget error: ' .. tostring(err))
    end
end

-- Placeholder handler for the quartermaster's test dialog.
function mercenaries:QuartermasterTest()
    Game.SendInfoText('merc_info_quartermaster_test', false, 0, 3)
    System.LogAlways('[Mercenaries] Quartermaster test dialog fired.')
end

-- Play a facial animation on the quartermaster. Isolates where lipsync breaks:
-- a generic library clip proves the pipeline runs at all, one of our retargeted
-- clip names proves the shipped .dba loaded. See docs/lipsync.md.
function mercenaries:FaceTest(name)
    if not name or name == '' or name == '%line' then name = 'fa_cin_talk_neutral_01' end

    local e = self.QuartermasterId and System.GetEntity(self.QuartermasterId)
    if not e then
        for _, ent in pairs(self.ActiveMercs or {}) do
            if not e and ent and self:IsAliveAndWell(ent, false) then e = ent end
        end
    end
    if not e then
        System.LogAlways('[merc_face] no quartermaster and no live merc to test on')
        return
    end

    System.LogAlways('[merc_face] target=' .. tostring(e:GetName())
        .. ' PlayFacialAnimation=' .. tostring(e.PlayFacialAnimation ~= nil)
        .. ' EnableProceduralFacialAnimation=' .. tostring(e.EnableProceduralFacialAnimation ~= nil))

    if e.EnableProceduralFacialAnimation then
        pcall(function() e:EnableProceduralFacialAnimation(false) end)
    end
    local ok, err = pcall(function() e:PlayFacialAnimation(name, true) end)
    System.LogAlways("[merc_face] PlayFacialAnimation('" .. name .. "') ok=" .. tostring(ok)
        .. ' err=' .. tostring(err))
end
