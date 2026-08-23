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
            "Squad: %d (%d melee / %d archers / %d heroes) | Health: %.0f%% avg, %d injured | Orders: %s | Archers: %s, %s",
            total, total - archers - heroes, archers, heroes,
            avg, injured,
            -- A hold order deliberately leaves _G.MercIdle alone (see MercIsIdle), so
            -- asking that alone would report a holding squad as "following".
            _G.MercenariesDismissed and "dismissed"
                or (self.HoldActive and "holding ground")
                or (self.EscortEnt and "escorting")
                or (self.CampActive and "camped")
                or (_G.MercIdle and "waiting" or "following"),
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

-- ==== Player status buffs ====
-- Cosmetic-only buffs on Henry's soul, so the management layer is readable from
-- the HUD. Defined in libs/tables/rpg/buff__mercenaries.xml with no params.
-- Indexed by number: the console does not substitute %1 into an AddCCommand
-- body, so every command bakes its index in literally (merc_buff_1 .. _9).
mercenaries.PlayerStatusBuffs = {
    { name = "low_morale",        guid = "e5a10010-2c4b-4e6a-9f01-000000000010", note = "morale at or below -50" },
    { name = "exhausted",         guid = "e5a10020-2c4b-4e6a-9f01-000000000020", note = "2 days out of camp" },
    { name = "injured",           guid = "e5a10021-2c4b-4e6a-9f01-000000000021", note = "a merc below 50% health" },
    { name = "starvation_mild",   guid = "e5a10023-2c4b-4e6a-9f01-000000000023", note = "1 day of food left" },
    { name = "starvation_strong", guid = "e5a10024-2c4b-4e6a-9f01-000000000024", note = "no food left" },
}

-- AddBuff returns the instance id RemoveBuff needs, so keep it per index.
mercenaries.PlayerStatusBuffInst = {}

-- Accepts an index or a name, so merc_lua calls can use either.
function mercenaries:ResolveStatusBuff(key)
    local i = tonumber(key)
    if i and self.PlayerStatusBuffs[i] then return i, self.PlayerStatusBuffs[i] end
    for n, def in ipairs(self.PlayerStatusBuffs) do
        if def.name == key then return n, def end
    end
    return nil, nil
end

-- quiet suppresses the log line, for the once-a-second refresh tick.
function mercenaries:AddPlayerStatusBuff(key, quiet)
    local i, def = self:ResolveStatusBuff(key)
    if not def then
        System.LogAlways('[Mercenary Jeff] unknown player status buff: ' .. tostring(key))
        self:ListPlayerStatusBuffs()
        return
    end
    -- Re-adding is a refresh: the timed variants expire on their own, so a
    -- tracked instance id may already be dead. Drop it rather than no-op.
    if self.PlayerStatusBuffInst[i] then self:RemovePlayerStatusBuff(i, true) end

    local ok, inst = pcall(function() return player.soul:AddBuff(def.guid) end)
    if not ok or not inst then
        System.LogAlways('[Mercenary Jeff] AddBuff failed for ' .. def.name .. ': ' .. tostring(inst))
        return
    end
    self.PlayerStatusBuffInst[i] = inst
    if not quiet then
        System.LogAlways('[Mercenary Jeff] buff ' .. i .. ' on: ' .. def.name .. ' - ' .. def.note)
    end
end

function mercenaries:RemovePlayerStatusBuff(key, quiet)
    local i, def = self:ResolveStatusBuff(key)
    if not def then
        System.LogAlways('[Mercenary Jeff] unknown player status buff: ' .. tostring(key))
        return
    end

    local inst = self.PlayerStatusBuffInst[i]
    self.PlayerStatusBuffInst[i] = nil
    if inst then
        pcall(function() player.soul:RemoveBuff(inst) end)
    end
    -- Catches instances we lost track of (script reload, save/load, expiry).
    pcall(function() player.soul:RemoveAllBuffsByGuid(def.guid) end)
    if not quiet then
        System.LogAlways('[Mercenary Jeff] buff ' .. i .. ' off: ' .. def.name)
    end
end

function mercenaries:ClearPlayerStatusBuffs()
    for i, _ in ipairs(self.PlayerStatusBuffs) do
        self:RemovePlayerStatusBuff(i)
    end
end

-- Idempotent toggle used by the logistics evaluator: only touches the soul on a
-- state change, so it can be called every tick without replaying the buff-
-- appeared animation or churning the soul.
function mercenaries:SetStatusBuff(key, on)
    local i, def = self:ResolveStatusBuff(key)
    if not def then return end
    local has = self.PlayerStatusBuffInst[i] ~= nil
    if on and not has then
        self:AddPlayerStatusBuff(i, true)
    elseif (not on) and has then
        self:RemovePlayerStatusBuff(i, true)
    end
end

-- ==== System-driven evaluation ====
-- The logistics tick calls this to mirror the squad's real state onto the HUD.
-- Test mode freezes it so the manual merc_buff_* commands aren't overwritten
-- within 5s; merc_buff_auto hands control back.
mercenaries.StatusBuffTestMode = false
mercenaries.ExhaustedBuffDays  = 3      -- days out of camp before the exhausted icon
mercenaries.MoraleLowBuffAt    = -50    -- morale at/below this shows the low-morale icon

function mercenaries:LogiUpdateStatusBuffs()
    if self.StatusBuffTestMode then return end
    local L = self:LogiState()
    self:Recount()
    local count = _G.MercCount or 0

    -- Turned off from the quartermaster: clear the row and stop driving it. Checked
    -- before the roster gate so switching them off takes them down immediately.
    local iconsOn = true
    pcall(function() iconsOn = self:StatusIconsOn() end)

    -- No squad: nothing to report, clear the row.
    if (not iconsOn) or _G.MercenariesDismissed or count <= 0 then
        for i, _ in ipairs(self.PlayerStatusBuffs) do self:SetStatusBuff(i, false) end
        return
    end

    -- Food: days of rations left drives the two starvation tiers.
    local foodDays = self:LogiSupplyDays(L.food)

    -- Injured: any live, conscious merc under half health.
    local injured = false
    for _, ent in pairs(self.ActiveMercs) do
        if ent and ent.soul and self:IsAliveAndWell(ent, true) then
            local hp = 100
            pcall(function() hp = tonumber(ent.soul:GetState('health')) or 100 end)
            if hp < 50 then injured = true; break end
        end
    end

    self:SetStatusBuff('low_morale',        L.morale <= self.MoraleLowBuffAt)
    self:SetStatusBuff('exhausted',         (not self.CampActive) and (L.tiredness / self.SecondsPerDay) >= self.ExhaustedBuffDays)
    self:SetStatusBuff('injured',           injured)
    self:SetStatusBuff('starvation_mild',   foodDays == 1)
    self:SetStatusBuff('starvation_strong', foodDays <= 0)
end

-- ==== Manual test commands (freeze the evaluator) ====
-- Every icon at once, to eyeball the whole set on the HUD.
function mercenaries:ShowAllPlayerStatusBuffs()
    self.StatusBuffTestMode = true
    for i, _ in ipairs(self.PlayerStatusBuffs) do
        self:AddPlayerStatusBuff(i, true)
    end
    System.LogAlways('[Mercenary Jeff] all status buffs on (test mode - merc_buff_auto to return to the system)')
end

-- Clears the rest first, so only one is on screen at once.
function mercenaries:OnlyPlayerStatusBuff(key)
    local _, def = self:ResolveStatusBuff(key)
    if not def then
        System.LogAlways('[Mercenary Jeff] unknown player status buff: ' .. tostring(key))
        self:ListPlayerStatusBuffs()
        return
    end
    self.StatusBuffTestMode = true
    self:ClearPlayerStatusBuffs()
    self:AddPlayerStatusBuff(key)
    System.LogAlways('[Mercenary Jeff] test mode - merc_buff_auto to return to the system')
end

-- Hand control back to the logistics evaluator (and apply the real state now).
function mercenaries:AutoPlayerStatusBuffs()
    self.StatusBuffTestMode = false
    self:LogiUpdateStatusBuffs()
    System.LogAlways('[Mercenary Jeff] status buffs back under system control')
end

function mercenaries:ListPlayerStatusBuffs()
    System.LogAlways('===== Player status buffs (' .. (self.StatusBuffTestMode and 'TEST MODE' or 'system-driven') .. ') =====')
    for i, def in ipairs(self.PlayerStatusBuffs) do
        local on = self.PlayerStatusBuffInst[i] and '  [ON]' or ''
        System.LogAlways(string.format('merc_buff_%d  %-16s triggers when %s%s', i, def.name, def.note, on))
    end
    System.LogAlways('merc_buff_all / merc_buff_off_all / merc_buff_auto')
end
