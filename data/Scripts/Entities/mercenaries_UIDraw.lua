-- Invisible entity that exists only for its per-frame update. System.DrawText is a
-- one-frame call, so anything drawn with it needs a real frame hook; the mod's own loops
-- are ~100ms timers. See docs/ui.md.
--
-- The update handler MUST live in the Client (or Server) sub-table. A function called
-- OnUpdate on the entity table itself is never called by the engine - vanilla does the
-- same (AnimDoor.Server:OnUpdate). Measured: Server is the one that fires.
--
-- Dispatches to every function in mercenaries.FrameHooks, so several systems can share
-- one entity. Register with mercenaries:FrameHookAdd(name, fn).

mercenaries_UIDraw = {
    Properties = {
        object_Model = "",
        bSaved_by_game = 0,
        bSerialize = 0,
        MultiplayerOptions = { bNetworked = false },
    },
    Client = {},
    Server = {},
    Editor = {
        Icon = "physicsobject.bmp",
        IconOnTop = 1,
    },
}

EntityCommon.Derive(mercenaries_UIDraw, BasicEntity)

local function tick(self, dt, where)
    if not self._merc_said then
        self._merc_said = true
        System.LogAlways("[MercUI] frame hook alive via " .. where)
    end
    if not mercenaries then return end
    for name, fn in pairs(mercenaries.FrameHooks or {}) do
        local ok, err = pcall(fn, dt)
        if not ok then
            self._merc_err = self._merc_err or {}
            if not self._merc_err[name] then
                self._merc_err[name] = true
                System.LogAlways("[MercUI] frame hook '" .. name .. "' error: " .. tostring(err))
            end
        end
    end
end

function mercenaries_UIDraw:OnSpawn()
    BasicEntity.OnSpawn(self)
    self:Activate(1)
end

function mercenaries_UIDraw:OnReset()
    self:Activate(1)
end

function mercenaries_UIDraw.Client:OnUpdate(dt)
    tick(self, dt, "Client:OnUpdate")
end

function mercenaries_UIDraw.Server:OnUpdate(dt)
    if self._merc_said then return end
    tick(self, dt, "Server:OnUpdate")
end
