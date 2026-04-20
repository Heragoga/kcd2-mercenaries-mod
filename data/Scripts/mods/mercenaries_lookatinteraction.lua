-- =======================================================================
-- INJECT INTERACTION: Adds a dynamic 'Wait/Follow' toggle prompt to the merc
-- =======================================================================
function mercenaries:InjectInteraction(entity)
    if not entity then return end

    -- 1. Define the callback function directly on the NPC entity
    entity.ToggleWaitFollow = function(self, user)
        -- Check your existing global idle flag to determine current state
        if _G.MercPersistentIdleFlag then
            mercenaries:SetState("follow")
        else
            mercenaries:SetState("wait")
        end
    end

    -- 2. Override the engine's GetActions function for this specific NPC
    entity.GetActions = function(self, user, firstFast)
        local output = {}

        -- Keep standard vanilla actions (Talk, Pickpocket, etc.) intact
        if BasicAIActions and BasicAIActions.GetActions then
            local baseActions = BasicAIActions.GetActions(self, user, firstFast)
            for i, action in pairs(baseActions) do
                table.insert(output, action)
            end
        end

        -- Only draw the button prompt if the mercenary is conscious and alive
        if self.actor and not self.actor:IsDead() and not self.actor:IsUnconscious() then
            
            -- Determine the text prompt based on their current state.
            -- (You can change these to point to your localized XML string names like "ui_merc_follow")
            local promptText = _G.MercPersistentIdleFlag and "ui_mercenary_follow_action" or "ui_mercenary_wait_action"

            -- Add the interaction prompt to the UI
            AddInteractorAction(
                output, 
                firstFast, 
                Action()
                    :hint(promptText)            -- The text shown on screen
                    :hintType(AHT_RELEASE)       -- Triggered on a standard button press
                    :action("companion_bond")               -- Maps to the standard 'Use' key (E)  alch_use companion_bond
                    :uiOrder(3)                  -- Position in the prompt list
                    :func(self.ToggleWaitFollow) -- The callback to trigger
                    :interaction(inr_loot)       -- Engine interaction category
            )
            
            
        end

        return output
    end
end