-- =============================================================================
-- mercenaries_Gate
-- The camp gate's prop, with an E interaction that swings it.
--
-- Same static physicalisation as mercenaries_Prop (bRigidBody = false -> PE_STATIC),
-- plus the usable machinery a door has: IsUsable + GetActions put an "Open"/"Close"
-- prompt on the crosshair, and OnUsed hands the toggle back to the mercenaries table.
--
-- The prompt reuses the game's OWN door strings and interaction filters -
-- @ui_door_open / @ui_door_close and inr_doorOpen / inr_doorClose - so no new
-- localization or interaction_filter entry is needed. inr_* globals come from
-- Libs/Config/interaction_filter.xml, where doorOpen and doorClose are both declared.
--
-- The gate's open state is pushed onto the entity as `mercGateOpen` when the gate
-- module spawns it, because GetActions runs on the entity and has no other way to
-- know which way the gate currently stands.
-- =============================================================================

Script.ReloadScript("scripts/Utils/InteractorAction.lua")

mercenaries_Gate = {
    Properties = {
        soclasses_SmartObjectClass = "",
        sWH_AI_EntityCategory = "",
        bMissionCritical = false,
        bCanTriggerAreas = false,
        object_Model = "",
        bSaved_by_game = 0,
        bSerialize = 0,
        Physics = {
            bPhysicalize = true,
            bRigidBody = false,     -- PE_STATIC, so the gate mesh itself collides
            bPushableByPlayers = false,
            Density = -1,
            Mass = -1,
        },
        MultiplayerOptions = {
            bNetworked = false,
        },
        bInteractiveCollisionClass = true,
        bExcludeCover = false,
        fUseDistance = 2.5,
    },
    Client = {},
    Server = {},
    Editor = {
        Icon = "physicsobject.bmp",
        IconOnTop = 1,
    },
}

EntityCommon.Derive(mercenaries_Gate, BasicEntity)

function mercenaries_Gate:OnSpawn()
    BasicEntity.OnSpawn(self)
    self:SetFromProperties()
    pcall(function() self:SetViewDistUnlimited() end)
    pcall(function() self:RenderShadow(true) end)
end

-- Always usable: a camp gate has no lock and belongs to the player.
function mercenaries_Gate:IsUsable(user)
    return 1
end

-- Recomputed every time the player looks at it, so the prompt follows the state.
function mercenaries_Gate:IsUsableMsgChanged()
    return true
end

function mercenaries_Gate:GetActions(user, firstFast)
    local output = {}
    if self.mercGateOpen then
        AddInteractorAction(output, firstFast,
            Action():hint("@ui_door_close"):action("use")
                    :func(mercenaries_Gate.OnUsed):interaction(inr_doorClose))
    else
        AddInteractorAction(output, firstFast,
            Action():hint("@ui_door_open"):action("use")
                    :func(mercenaries_Gate.OnUsed):interaction(inr_doorOpen))
    end
    return output
end

-- Swinging the gate destroys THIS entity and spawns the other mesh, so the work is
-- handed to the mod table, which defers it a tick rather than pulling the entity out
-- from under the callback that is still running on it.
function mercenaries_Gate:OnUsed(user, slot)
    if mercenaries and mercenaries.GateToggleByEntity then
        pcall(function() mercenaries:GateToggleByEntity(self.id) end)
    end
    return true
end

-- NOT EntityCommon.MakeUsable: it DEFINES IsUsable (gated on the bUsable property) and
-- would overwrite the one above. AnimDoor, Ladder and Bed all skip it for the same
-- reason and supply their own.
EntityCommon.SetupCollisionFiltering(mercenaries_Gate)
