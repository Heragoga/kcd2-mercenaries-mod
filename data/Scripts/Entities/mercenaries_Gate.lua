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

-- Pulled in explicitly, the way Bed and the camping mod's entities do it. Entity scripts
-- load in an order we do not control, and this file sorts BEFORE mercenaries_Prop.lua -
-- so BasicEntity and EntityCommon cannot be assumed to be in scope yet. If they are not,
-- EntityCommon.Derive below errors, the script never finishes, the class is never
-- registered, and the only symptom is that no prompt ever appears.
Script.ReloadScript("Scripts/Entities/EntityCommon.lua")
Script.ReloadScript("Scripts/Entities/Physics/BasicEntity.lua")
Script.ReloadScript("Scripts/Utils/InteractorAction.lua")

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
        -- Both spellings: AnimDoor reads fUseDistance, Bed reads fUsabilityDistance, and
        -- which one the engine honours depends on the class it derives from.
        fUseDistance = 2.5,
        fUsabilityDistance = 2.5,
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

-- Set by merc_gate_probe: logs every interactor call so the log shows whether the engine
-- is asking this entity for actions at all.
mercenaries_Gate.mercTrace = false

-- Always usable: a camp gate has no lock and belongs to the player.
function mercenaries_Gate:IsUsable(user)
    if mercenaries_Gate.mercTrace then System.LogAlways("[GateProbe] IsUsable called") end
    return 1
end

-- Recomputed every time the player looks at it, so the prompt follows the state.
function mercenaries_Gate:IsUsableMsgChanged()
    return true
end

function mercenaries_Gate:GetActions(user, firstFast)
    local output = {}
    if mercenaries_Gate.mercTrace then
        System.LogAlways("[GateProbe] GetActions called, open=" .. tostring(self.mercGateOpen))
    end
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

-- Reaching this line means the script parsed and the class is registered. If the log has
-- no such line, the .ent never loaded or something above threw - and a missing class is
-- indistinguishable in game from a broken prompt, because the gate silently falls back to
-- mercenaries_Prop and still looks right.
System.LogAlways("[Gate] mercenaries_Gate class script loaded")
