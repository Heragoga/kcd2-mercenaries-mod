-- Monitors all active mercs and teleports any that have fallen too far behind.
-- PERFORMANCE: Uses ActiveMercs cache instead of GetEntitiesByClass.
-- Called from MonitorLoop once per second.
function mercenaries:MonitorDistanceAndTeleport()
    local ok, err = pcall(function()
        -- Early exit: Don't teleport if they are explicitly told to wait/idle, or are fleeing/dismissed
        if _G.MercIdle or _G.MercenariesDismissed then return end
        if not player then return end

        local playerPos = player:GetPos()
        if not playerPos then return end

        for name, ent in pairs(self.ActiveMercs) do
            -- IsAliveAndWell already checked by PruneMercCache, but double-check cheaply
            if ent and ent.actor then
                local mp = ent:GetPos()
                if mp then 
                    local dx = playerPos.x - mp.x
                    local dy = playerPos.y - mp.y
                    local dz = playerPos.z - mp.z
                    local distance = math.sqrt(dx*dx + dy*dy + dz*dz)

                    if distance > 50.0 then
                        local safePos, _ = self:GetSafeSpawnPosition(player, 10)
                        if safePos then
                            ent:SetPos({x = safePos.x, y = safePos.y, z = safePos.z})
                        end
                    end
                end
            end
        end
    end)
    
    if not ok then 
        System.LogAlways('[Mercenary Jeff] MonitorDistanceAndTeleport Error: ' .. tostring(err)) 
    end
end

-- NOTE: CalculateDistanceToPlayer and TeleportIfTooFar have been removed.
-- CalculateDistanceToPlayer contained a bug (mp was never defined) and never
-- actually calculated anything. TeleportIfTooFar duplicated MonitorDistanceAndTeleport.
-- The behavior tree's inline Lua handles per-entity distance and teleport correctly.