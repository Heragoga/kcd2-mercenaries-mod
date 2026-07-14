-- Monitors all active mercs and teleports any that have fallen too far behind.
-- PERFORMANCE: Uses ActiveMercs cache instead of GetEntitiesByClass. This
-- replaces what used to be a per-merc behavior-tree loop doing its own
-- 10-ray physics sweep every tick, whether or not anyone actually needed
-- it — one shared pass over the roster instead of N independent ones.
-- Called from MonitorLoop once per second.
function mercenaries:MonitorDistanceAndTeleport()
    local ok, err = pcall(function()
        -- Early exit: Don't teleport if they are explicitly told to wait/idle, or are fleeing/dismissed
        if _G.MercIdle or _G.MercenariesDismissed then return end
        -- (Sortie mercs teleport to keep up even while the player is mounted -
        -- that's how a deployed party stays with a horseman. In-camp mercs are
        -- skipped per-merc below so they're never yanked out of the camp.)
        if not player then return end

        local playerPos = player:GetPos()
        if not playerPos then return end

        -- PERFORMANCE: the safe-position raycast sweep (10 rays) is computed
        -- at most once per pass and shared by every straggler, instead of
        -- re-running it per merc. Jitter keeps them from stacking on the
        -- exact same spot.
        local sharedSafePos = nil
        local sweepDone = false

        for name, ent in pairs(self.ActiveMercs) do
            -- IsAliveAndWell already checked by PruneMercCache, but double-check cheaply
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