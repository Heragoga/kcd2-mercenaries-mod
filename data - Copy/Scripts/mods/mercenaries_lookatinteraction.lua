-- Look-at prompts on a merc: a camp make/break/return option and a sortie
-- wait/follow toggle. See docs/camp.md "Look-at prompts on a merc".
function mercenaries:InjectInteraction(entity)
    if not entity then return end

    entity.CampContextAction = function(self, user)
        local wuid = nil
        pcall(function() wuid = XGenAIModule.GetMyWUID(self) end)
        local barkWuid = self.this and self.this.id or self.id   -- entity id, matches the BT bark lookup

        if not mercenaries.CampActive then
            mercenaries:SpawnMercCamp()
            mercenaries:RequestBark(barkWuid, "merc_bark_ack")
        elseif wuid and mercenaries:IsCampOut(wuid) then
            mercenaries:CampReturnAll()
        else
            mercenaries:BreakMercCamp()
            mercenaries:RequestBark(barkWuid, "merc_bark_ack")
        end
    end

    entity.SortieWaitToggle = function(self, user)
        local barkWuid = self.this and self.this.id or self.id
        local newWait = not _G.MercPersistentIdleFlag
        mercenaries:SetSortieWait(newWait)
        mercenaries:RequestBark(barkWuid, newWait and "merc_bark_wait" or "merc_bark_follow")
    end

    entity.GetActions = function(self, user, firstFast)
        local output = {}

        -- Keep the vanilla actions (Talk, Pickpocket, etc.) intact.
        if BasicAIActions and BasicAIActions.GetActions then
            local baseActions = BasicAIActions.GetActions(self, user, firstFast)
            for i, action in pairs(baseActions) do
                table.insert(output, action)
            end
        end

        if self.actor and not self.actor:IsDead() and not self.actor:IsUnconscious() then
            local wuid = nil
            pcall(function() wuid = XGenAIModule.GetMyWUID(self) end)
            local inSortie = (not wuid) or mercenaries:IsMercInSortie(wuid)

            -- Camp option: make / break / back-to-camp, gated on CampActive.
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
                    :hintType(AHT_HOLD)
                    :action("use_other")
                    :uiOrder(3)
                    :func(self.CampContextAction)
                    :interaction(inr_loot)
            )

            -- Wait / follow toggle: sortie mercs only.
            if inSortie then
                local waitText = _G.MercPersistentIdleFlag and "ui_mercenary_follow_action" or "ui_mercenary_wait_action"
                AddInteractorAction(
                    output, firstFast,
                    Action()
                        :hint(waitText)
                        :hintType(AHT_HOLD)
                        :action("companion_bond")
                        :uiOrder(4)
                        :func(self.SortieWaitToggle)
                        :interaction(inr_loot)
                )
            end
        end

        return output
    end
end
