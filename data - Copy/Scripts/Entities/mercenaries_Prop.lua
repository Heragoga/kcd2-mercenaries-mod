-- =============================================================================
-- mercenaries_Prop
-- A BasicEntity-derived prop that physicalises STATIC (bRigidBody = false ->
-- PE_STATIC in EntityCommon.PhysicalizeRigid) instead of the rigid body a plain
-- BasicEntity defaults to. That's the only reliable way to get static collision
-- out of a spawned model whose .cgf has a physics proxy - which is what the camp
-- house's invisible collider walls need.
--
-- Ported from references/spawn house (villagebuilding_Prop), which in turn models
-- the camping mod's DJB_PropEntity - but with save-by-game turned OFF: that mod
-- wants its houses to persist, whereas the camp here is torn down and rebuilt from
-- scratch (see docs/camp.md). Left on, every house part got serialised into the
-- save and came back as a broken white placeholder mesh.
-- =============================================================================

mercenaries_Prop = {
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
            bRigidBody = false,     -- false -> physicalise as PE_STATIC (collision)
            bPushableByPlayers = false,
            Density = -1,
            Mass = -1,
        },
        MultiplayerOptions = {
            bNetworked = false,
        },
        bInteractiveCollisionClass = true,
        bExcludeCover = false,
    },
    Client = {},
    Server = {},
    Editor = {
        Icon = "physicsobject.bmp",
        IconOnTop = 1,
    },
}

EntityCommon.Derive(mercenaries_Prop, BasicEntity)

function mercenaries_Prop:OnSpawn()
    BasicEntity.OnSpawn(self)
    self:SetFromProperties()
    pcall(function() self:SetViewDistUnlimited() end)
    pcall(function() self:RenderShadow(true) end)
end

EntityCommon.MakeUsable(mercenaries_Prop)
EntityCommon.MakePickable(mercenaries_Prop)
EntityCommon.AddHeavyObjectProperty(mercenaries_Prop)
EntityCommon.AddInteractLargeObjectProperty(mercenaries_Prop)
EntityCommon.SetupCollisionFiltering(mercenaries_Prop)
