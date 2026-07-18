function mercenaries:UpdateFormationSlots()
    local ok, err = pcall(function()
        self.FormationSlots = {}

        local mounted   = {}
        local unmounted = {}

        for name, ent in pairs(self.ActiveMercs) do
            local entWuid  = ent and (ent.this and ent.this.id or ent.id)
            -- Mercs holding the camp aren't part of the marching formation; only
            -- sortie mercs (and the whole squad when there's no camp) form up.
            if self:IsAliveAndWell(ent, false) and not self:IsMercInCampProper(entWuid) then
                local mercType = self:GetMercType(ent)
                local entName  = ent:GetName() or name
                local hp       = 0
                local isMounted = false

                pcall(function()
                    local rawHp = ent.soul:GetState('health')
                    hp = tonumber(rawHp) or 0
                end)

                pcall(function()
                    isMounted = ent.human:IsMounted()
                end)

                local entry = { wuid = entWuid, name = entName, hp = hp, mercType = mercType }

                if isMounted then
                    table.insert(mounted, entry)
                else
                    table.insert(unmounted, entry)
                end
            end
        end

        -- Formation rank: heroes lead, melee regulars next, archers at the back
        local function formationRank(mercType)
            if mercType == "hero" then return 0 end
            if mercType == "archer" then return 2 end
            return 1
        end

        -- Mounted mercs: heroes first by name, then regulars, archers last
        table.sort(mounted, function(a, b)
            local aRank = formationRank(a.mercType)
            local bRank = formationRank(b.mercType)
            if aRank ~= bRank then return aRank < bRank end
            return a.name < b.name
        end)

        -- Unmounted mercs: heroes first by name, then regulars by descending health, archers last
        table.sort(unmounted, function(a, b)
            local aRank = formationRank(a.mercType)
            local bRank = formationRank(b.mercType)
            if aRank ~= bRank then return aRank < bRank end
            if a.mercType == "hero" then return a.name < b.name end
            if a.hp == b.hp then return a.name < b.name end
            return a.hp > b.hp
        end)

        local alive = {}
        for _, v in ipairs(mounted)   do table.insert(alive, v) end
        for _, v in ipairs(unmounted) do table.insert(alive, v) end

        local totalMercs = #alive
        local width = (totalMercs >= 15) and 3 or 2

        for i, v in ipairs(alive) do
            local slot = i - 1
            local followTarget = nil

            if slot >= width then
                local targetIndex = slot - width + 1
                local targetData  = alive[targetIndex]
                if targetData then
                    followTarget = targetData.wuid
                end
            end

            self.FormationSlots[tostring(v.wuid)] = {
                slot         = slot,
                followTarget = followTarget,
                totalMercs   = totalMercs,
            }
        end
    end)

    if not ok then
        System.LogAlways('[Mercenary Jeff] UpdateFormationSlots Error: ' .. tostring(err))
    end
end

function mercenaries:CalculateFormationTarget(bt_data, myWuid)
    local ok, err = pcall(function()
        local key = tostring(myWuid)

        -- NPC-led formations (patrols etc., see AssignNpcFormation) win over the
        -- player-squad slots; their followTarget is always explicit, so nothing
        -- here ever routes an enemy toward the player.
        local npc = self.NpcFormations and self.NpcFormations[key]
        if npc then
            bt_data.formationSlot = npc.slot
            bt_data.followTarget  = npc.followTarget
            return
        end

        local data = self.FormationSlots and self.FormationSlots[key]

        if data then
            bt_data.formationSlot = data.slot
            bt_data.followTarget  = data.followTarget or bt_data.playerWUID
        else
            bt_data.formationSlot = 0
            bt_data.followTarget  = bt_data.playerWUID
        end
    end)

    if not ok then
        System.LogAlways('[Mercenary Jeff] CalculateFormationTarget Error: ' .. tostring(err))
    end
end