-- Teleport any active merc that has fallen too far behind. One shared pass over
-- the roster (from MonitorLoop, once/sec), replacing a per-merc BT raycast loop.
function mercenaries:MonitorDistanceAndTeleport()
    local ok, err = pcall(function()
        if _G.MercIdle or _G.MercenariesDismissed then return end
        -- Sortie mercs teleport to keep up even while the player is mounted;
        -- in-camp mercs are skipped per-merc below so they're never yanked out.
        if not player then return end

        local playerPos = player:GetPos()
        if not playerPos then return end

        -- The safe-position sweep (10 rays) runs at most once per pass and is
        -- shared by every straggler; jitter stops them stacking on one spot.
        local sharedSafePos = nil
        local sweepDone = false

        for name, ent in pairs(self.ActiveMercs) do
            -- A merc who stayed in camp must never be teleported to the player.
            local inCampProper = false
            pcall(function() inCampProper = self:IsMercInCampProper(ent.this and ent.this.id or ent.id) end)
            if ent and ent.actor and not inCampProper then
                -- Don't teleport a merc out of a fight mid-swing.
                local inCombat = false
                pcall(function() inCombat = ent.soul:HasScriptContext("crime_interruptAttack") end)

                if not inCombat then
                    local mp = ent:GetPos()
                    if mp then
                        local dx = playerPos.x - mp.x
                        local dy = playerPos.y - mp.y
                        local dz = playerPos.z - mp.z
                        local distance = math.sqrt(dx*dx + dy*dy + dz*dz)

                        if distance > 50.0 then
                            if not sweepDone then
                                sweepDone = true
                                sharedSafePos = self:GetSafeSpawnPosition(player, 10)
                            end
                            if sharedSafePos then
                                -- Validate the jittered spot so a straggler
                                -- isn't teleported onto a tree/rock (the jitter
                                -- and flat z alone could land on one).
                                local tp = self:FindValidGround({
                                    x = sharedSafePos.x + (math.random() - 0.5) * 3.0,
                                    y = sharedSafePos.y + (math.random() - 0.5) * 3.0,
                                    z = sharedSafePos.z
                                }, sharedSafePos.z)
                                ent:SetPos(tp)
                            end
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