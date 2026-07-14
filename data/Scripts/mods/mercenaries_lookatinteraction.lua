-- =======================================================================
-- INJECT INTERACTION: the look-at prompts on a merc. Up to TWO options:
--
--   1. CAMP option (always shown), decided live from the camp state and whether
--      THIS merc is deployed:
--        no camp                 -> Make camp
--        camp up, merc in camp    -> Break camp
--        camp up, merc deployed    -> Back to camp (returns the whole sortie)
--
--   2. WAIT / FOLLOW toggle (only shown for a merc that is "in a sortie" - i.e.
--      deployed out of camp, or the whole squad when there is no camp). Sets the
--      global wait order for the sortie; the mercs who stayed in camp ignore it.
--      Hidden for a merc that is in camp (a camped merc can't be told to wait).
-- =======================================================================
function mercenaries:InjectInteraction(entity)
    if not entity then return end

    -- Camp option callback - re-checks state at press time. The merc you looked
    -- at barks an acknowledgment (the return order barks the whole sortie itself).
    entity.CampContextAction = function(self, user)
        local wuid = nil
        pcall(function() wuid = XGenAIModule.GetMyWUID(self) end)

        if not mercenaries.CampActive then
            mercenaries:SpawnMercCamp()
            mercenaries:RequestBark(wuid, "merc_bark_ack")
        elseif wuid and mercenaries:IsCampOut(wuid) then
            mercenaries:CampReturnAll()
        else
            mercenaries:BreakMercCamp()
            mercenaries:RequestBark(wuid, "merc_bark_ack")
        end
    end

    -- Wait/follow toggle callback for the sortie. The looked-at merc barks.
    entity.SortieWaitToggle = function(self, user)
        local wuid = nil
        pcall(function() wuid = XGenAIModule.GetMyWUID(self) end)
        local newWait = not _G.MercPersistentIdleFlag
        mercenaries:SetSortieWait(newWait)
        mercenaries:RequestBark(wuid, newWait and "merc_bark_wait" or "merc_bark_follow")
    end

    entity.GetActions = function(self, user, firstFast)
        local output = {}

        -- Keep standard vanilla actions (Talk, Pickpocket, etc.) intact.
        if BasicAIActions and BasicAIActions.GetActions then
            local baseActions = BasicAIActions.GetActions(self, user, firstFast)
            for i, action in pairs(baseActions) do
                table.insert(output, action)
            end
        end

        -- Only draw prompts if the mercenary is conscious and alive.
        if self.actor and not self.actor:IsDead() and not self.actor:IsUnconscious() then
            local wuid = nil
            pcall(function() wuid = XGenAIModule.GetMyWUID(self) end)
            local inSortie = (not wuid) or mercenaries:IsMercInSortie(wuid)

            -- 1. Camp option (make / break / back-to-camp). Uses CampActive (does
            --    a camp STRUCTURE exist) rather than the sortie check.
            local campText = "ui_mercenary_make_camp_action"
            if mercenaries.CampActive then
                if wuid and mercenaries:IsCampOut(wuid) then
                    campText = "ui_mercenary_return_camp_action"
                else
                    campText = "ui_mercenary_break_camp_action"
                end
            end
            AddInteractorAction(
                output, firstFast,
                Action()
                    :hint(campText)
                    :hintType(AHT_RELEASE)
                    :action("companion_bond")
                    :uiOrder(3)
                    :func(self.CampContextAction)
                    :interaction(inr_loot)
            )

            -- 2. Wait / follow toggle - sortie mercs only. Uses the "use_other"
            --    action (a hold), the way references/CompanionMerchant drives its
            --    second prompt - "alch_use" rendered a blank/dead entry.
            if inSortie then
                local waitText = _G.MercPersistentIdleFlag and "ui_mercenary_follow_action" or "ui_mercenary_wait_action"
                AddInteractorAction(
                    output, firstFast,
                    Action()
                        :hint(waitText)
                        :hintType(AHT_HOLD)
                        :action("use_other")
                        :uiOrder(4)
                        :func(self.SortieWaitToggle)
                        :interaction(inr_loot)
                )
            end
        end

        return output
    end
end
