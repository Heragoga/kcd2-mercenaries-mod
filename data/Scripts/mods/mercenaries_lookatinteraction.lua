-- Look-at prompts on a merc: a camp make/break/return option and a sortie
-- wait/follow toggle. See docs/camp.md "Look-at prompts on a merc".
--
-- GetActions is called on the ENGINE'S INTERACTOR POLL, not once per prompt shown, so it
-- honours the same three things vanilla does (BasicAIActions.GetActions:18-27): bail on a
-- nil user, bail when the player cannot interact with this entity at all, and treat
-- firstFast as "one action is enough". Skipping those meant building two Action objects
-- per merc on every poll, including for mercs far out of reach and on the cheap survey
-- pass. AddInteractorAction RETURNS firstFast - that is how vanilla knows to stop.
function mercenaries:InjectInteraction(entity)
    if not entity then return end

    -- Resolved once at injection rather than per call: that was a pcall and a fresh closure
    -- on every poll. Re-injected at hire and on every cache rebuild, so it stays current.
    local injected = nil
    pcall(function() injected = XGenAIModule.GetMyWUID(entity) end)
    entity._mercWuid = injected

    local function mercWuid(self)
        local w = self._mercWuid
        if w == nil then
            pcall(function() w = XGenAIModule.GetMyWUID(self) end)
            self._mercWuid = w
        end
        return w
    end

    entity.CampContextAction = function(self, user)
        local wuid = mercWuid(self)
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
        local newWait = not mercenaries:SquadIsWaiting()
        mercenaries:SetSortieWait(newWait)
        mercenaries:RequestBark(barkWuid, newWait and "merc_bark_wait" or "merc_bark_follow")
    end

    entity.GetActions = function(self, user, firstFast)
        -- Vanilla's own two gates, before any work at all.
        if user == nil then return {} end
        if not (user.actor and user.actor:CanInteractWith(self.id)) then return {} end

        -- Vanilla's list, appended to rather than copied into a second table.
        local output = {}
        if BasicAIActions and BasicAIActions.GetActions then
            output = BasicAIActions.GetActions(self, user, firstFast) or {}
        end

        -- The survey pass only wants to know there IS an action, and ours are appended
        -- after vanilla's, so they could never be the first one it reads.
        if firstFast and #output > 0 then return output end

        if self.actor and not self.actor:IsDead() and not self.actor:IsUnconscious() then
            local wuid = mercWuid(self)
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
            if AddInteractorAction(
                output, firstFast,
                Action()
                    :hint(campText)
                    :hintType(AHT_HOLD)
                    :action("use_other")
                    :uiOrder(3)
                    :func(self.CampContextAction)
                    :interaction(inr_loot)
            ) then return output end

            -- Wait / follow toggle: sortie mercs only.
            if inSortie then
                local waitText = mercenaries:SquadIsWaiting() and "ui_mercenary_follow_action" or "ui_mercenary_wait_action"
                if AddInteractorAction(
                    output, firstFast,
                    Action()
                        :hint(waitText)
                        :hintType(AHT_HOLD)
                        :action("companion_bond")
                        :uiOrder(4)
                        :func(self.SortieWaitToggle)
                        :interaction(inr_loot)
                ) then return output end
            end
        end

        return output
    end
end
