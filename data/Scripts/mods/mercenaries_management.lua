-- Heals and washes all active mercenaries.
function mercenaries:FullHealAndWashNumberOfMercs()
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

-- Squad overview, from the management dialog and the merc_status console command:
-- a HUD summary line plus full detail to the log.
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

        -- HUD line via the "@labelKey <number>" pattern: every visible word must
        -- be an @-key, or the engine prefixes it with a stray @.
        pcall(function()
            Game.SendInfoText(
                "@merc_n_squad " .. total
                .. " @merc_n_melee " .. (total - archers - heroes)
                .. " @merc_n_archers " .. archers
                .. " @merc_n_heroes " .. heroes
                .. " @merc_n_health " .. math.floor(avg + 0.5)
                .. " @merc_n_injured " .. injured, false, 0, 5)
        end)
        -- Full detail (including wordy state) goes to the log.
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
