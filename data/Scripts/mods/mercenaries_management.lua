-- Heals and washes all active mercenaries.
-- Note: count parameter is retained for API compatibility but currently heals all,
-- as the count variable is slightly broken in skald.
function mercenaries:FullHealAndWashNumberOfMercs(count)
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