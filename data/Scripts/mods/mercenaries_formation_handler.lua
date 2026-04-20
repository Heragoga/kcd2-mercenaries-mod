-- =======================================================================
-- CORE: Runs ONCE per second in MonitorLoop (not per-merc per-tick).
-- Computes formation slots for all active mercs and stores results in
-- mercenaries.FormationSlots[tostring(wuid)].
-- Each merc's CalculateFormationTarget call then just does a table lookup.
-- =======================================================================
function mercenaries:UpdateFormationSlots()
    local ok, err = pcall(function()
        self.FormationSlots = {}

        local heroes   = {}
        local regulars = {}

        for name, ent in pairs(self.ActiveMercs) do
            -- Cache is already pruned, but IsAliveAndWell is cheap so guard anyway
            if self:IsAliveAndWell(ent, false) then
                local mercType = self:GetMercType(ent)
                local entWuid  = ent.this and ent.this.id or ent.id
                local entName  = ent:GetName() or name

                if mercType == "hero" then
                    table.insert(heroes, { wuid = entWuid, name = entName })
                else
                    local hp = 0
                    pcall(function()
                        local rawHp = ent.soul:GetState('health')
                        hp = tonumber(rawHp) or 0
                    end)
                    table.insert(regulars, { wuid = entWuid, name = entName, hp = hp })
                end
            end
        end

        -- Heroes always go first, sorted by name for stability
        table.sort(heroes, function(a, b) return a.name < b.name end)

        -- Regulars sorted by descending health; fall back to name to prevent flickering
        table.sort(regulars, function(a, b)
            if a.hp == b.hp then return a.name < b.name end
            return a.hp > b.hp
        end)

        local alive = {}
        for _, v in ipairs(heroes)   do table.insert(alive, v) end
        for _, v in ipairs(regulars) do table.insert(alive, v) end

        local totalMercs = #alive
        local width = (totalMercs >= 15) and 3 or 2

        for i, v in ipairs(alive) do
            local slot = i - 1
            local followTarget = nil  -- nil means "follow the player" (resolved in BT)

            if slot >= width then
                local targetIndex = slot - width + 1
                local targetData  = alive[targetIndex]
                if targetData then
                    followTarget = targetData.wuid
                end
            end

            self.FormationSlots[tostring(v.wuid)] = {
                slot        = slot,
                followTarget = followTarget,
                totalMercs  = totalMercs,
            }
        end
    end)

    if not ok then
        System.LogAlways('[Mercenary Jeff] UpdateFormationSlots Error: ' .. tostring(err))
    end
end

-- =======================================================================
-- CORE: Called per-merc from the behavior tree.
-- Now a simple table lookup — no GetEntitiesInSphere, no sorting.
-- =======================================================================
function mercenaries:CalculateFormationTarget(bt_data, myWuid)
    local ok, err = pcall(function()
        local key  = tostring(myWuid)
        local data = self.FormationSlots and self.FormationSlots[key]

        if data then
            bt_data.formationSlot = data.slot
            bt_data.followTarget  = data.followTarget or bt_data.playerWUID
        else
            -- Fallback: slot 0, follow the player directly
            bt_data.formationSlot = 0
            bt_data.followTarget  = bt_data.playerWUID
        end
    end)

    if not ok then
        System.LogAlways('[Mercenary Jeff] CalculateFormationTarget Error: ' .. tostring(err))
    end
end