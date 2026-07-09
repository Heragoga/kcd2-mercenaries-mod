-- Heals and washes all active mercenaries.
function mercenaries:FullHealAndWashNumberOfMercs()
    -- PERFORMANCE: Iterate the cache instead of scanning all world NPCs.
    for name, e in pairs(self.ActiveMercs) do
        if e and e.soul then
            local ok, hp = pcall(function() return e.soul:GetState('health') end)
            if ok and hp and hp > 0 and hp < 80 and e.actor and not e.actor:IsUnconscious() then
                System.LogAlways('[Mercenary Jeff] healing: ' .. name .. ' Health ' .. tostring(hp))

                e.soul:SetState('health', 100.0)
                e.actor:CleanDirt(1)

                for i = 1, 6 do
                    pcall(function()
                        e.soul:HealBleeding(1.0, i)
                    end)
                end
            end
        end
    end
    Game.SendInfoText('merc_info_merc_healed', false, 0, 3)
end

-- Returns true if at least one active merc could use healing (matches the
-- threshold FullHealAndWashNumberOfMercs itself uses).
function mercenaries:AnyMercNeedsHealing()
    for _, e in pairs(self.ActiveMercs) do
        if e and e.soul and e.actor and not e.actor:IsUnconscious() then
            local ok, hp = pcall(function() return e.soul:GetState('health') end)
            if ok and hp and hp > 0 and hp < 80 then
                return true
            end
        end
    end
    return false
end

-- =======================================================================
-- Game.SendInfoText ONLY accepts a localization key, never freeform text -
-- confirmed the hard way: passing a dynamically-built sentence made every
-- "word" show up prefixed with "@" (the engine's missing-translation
-- marker), because it tries to resolve the whole string as a lookup key.
-- So a dynamic report can't be one interpolated sentence; it's a short
-- queue of pre-defined, bucketed static keys shown one after another.
-- =======================================================================
mercenaries.InfoTextQueue = {}

function mercenaries.DispatchQueuedInfoText()
    local key = table.remove(mercenaries.InfoTextQueue, 1)
    if key then
        Game.SendInfoText(key, false, 0, 3)
    end
    if #mercenaries.InfoTextQueue > 0 then
        Script.SetTimerForFunction(2200, "mercenaries.DispatchQueuedInfoText")
    end
end

-- Queues a list of localization keys to show one at a time (2.2s apart)
-- instead of all at once, which would just have them overwrite each other.
function mercenaries:QueueInfoTexts(keys)
    local wasEmpty = (#self.InfoTextQueue == 0)
    for _, k in ipairs(keys) do
        table.insert(self.InfoTextQueue, k)
    end
    if wasEmpty and #self.InfoTextQueue > 0 then
        self.DispatchQueuedInfoText()
    end
end

-- QoL: squad overview reachable from the management dialog ("How is
-- everyone holding up?") and the merc_status console command. Shown as a
-- short queue of static HUD lines (see note above); the full numeric
-- breakdown still goes to the log for anyone who wants exact numbers.
function mercenaries:ShowSquadStatus()
    local ok, err = pcall(function()
        local total, archers, heroes = 0, 0, 0
        local hpSum, injured = 0, 0

        for name, ent in pairs(self.ActiveMercs) do
            if self:IsAliveAndWell(ent, true) then
                total = total + 1
                local mercType = self:GetMercType(ent)
                if mercType == "archer" then archers = archers + 1
                elseif mercType == "hero" then heroes = heroes + 1 end

                local hp = 100
                pcall(function() hp = tonumber(ent.soul:GetState('health')) or 100 end)
                hpSum = hpSum + hp
                if hp < 80 then injured = injured + 1 end
            end
        end

        if total == 0 then
            Game.SendInfoText('merc_info_status_empty', false, 0, 4)
            return
        end

        local avg = hpSum / total

        local healthKey
        if avg >= 85 then healthKey = 'merc_info_status_health_good'
        elseif avg >= 60 then healthKey = 'merc_info_status_health_hurt'
        else healthKey = 'merc_info_status_health_bad' end

        local orderKey = 'merc_info_following'
        if _G.MercenariesDismissed then orderKey = 'merc_info_dismissed'
        elseif self.CampActive then orderKey = 'merc_info_status_camped'
        elseif _G.MercIdle then orderKey = 'merc_info_waiting' end

        local stanceKey = 'merc_info_stance_' .. tostring(_G.MercStance or 'everyone')

        local keys = { healthKey, orderKey, stanceKey }
        if archers > 0 then
            table.insert(keys, 'merc_info_archer_stance_' .. tostring(_G.ArcherStance or 'skirmish'))
        end
        self:QueueInfoTexts(keys)

        local msg = string.format(
            "Squad: %d (%d melee / %d archers / %d heroes) | Health: %.0f%% avg, %d injured | Orders: %s | Targeting: %s | Archers: %s, %s",
            total, total - archers - heroes, archers, heroes,
            avg, injured,
            _G.MercenariesDismissed and "dismissed" or (self.CampActive and "camped" or (_G.MercIdle and "waiting" or "following")),
            tostring(_G.MercStance or "everyone"),
            tostring(_G.ArcherStance or "skirmish"),
            self:GetArcherWeaponType())
        System.LogAlways('[Mercenary Jeff] ' .. msg)
    end)
    if not ok then System.LogAlways('[Mercenary Jeff] ShowSquadStatus error: ' .. tostring(err)) end
end

-- Called from the heal token handler in mercenaries.lua. Charges a flat fee
-- for the whole squad regardless of how many mercs are hurt.
function mercenaries:HealMercsForFlatFee()
    if not self:AnyMercNeedsHealing() then
        Game.SendInfoText('merc_info_nobody_injured', false, 0, 3)
        return
    end

    local p = player.inventory
    if p:GetMoney() < self.HealCost then
        Game.SendInfoText('merc_info_not_enough_money', false, 0, 3)
        return
    end

    p:RemoveMoney(self.HealCost)
    self:FullHealAndWashNumberOfMercs()
end
