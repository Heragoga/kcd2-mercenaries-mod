-- ============================================================================
--  The camp on the compass
-- ============================================================================
--
-- The mod used to draw three POIs on the world map as well (the camp, the waiting men and
-- Aleksej) by pushing rows into ApseMap's PoiMarkers array. They were removed on request;
-- the whole mechanism, the crash it can cause and the icon research are kept in
-- docs/map-marker.md in case they are ever wanted back.
--
-- What is left is the compass marker, which is a different Scaleform element (hud) and is
-- opt-in: merc_camp_compass 1.

local function mmLog(s) System.LogAlways("[MapMarker] " .. tostring(s)) end

-- Gated on CampActive, not on the saved origin: the save records the camp's coordinates but
-- not which level it stood on, and Trosecko and Kutnohorsko share one coordinate space.
function mercenaries:MarkerPosCamp()
    if _G.MercenariesDismissed then return nil end
    if not self.CampActive then return nil end
    local o = self.CampBuildOrigin
    if not (o and o.x and o.y) then
        pcall(function() o = self:LoadCampOrigin() end)
    end
    if not (o and o.x and o.y) then return nil end
    return o
end

-- ==== the compass ====
--
-- OFF by default: it carries the one number nothing in the game's data pins down, and it
-- costs a four-times-a-second redraw while it is up. HUD.xml documents the call:
--
--   AddCompassMarker(MarkerID, MarkerType, MarkerState, QuestColor, ObjectiveNumber,
--                    Distance, Frame, IsInsideArea, IsInsideArea2D,
--                    NearThreshold, LayerThreshold, FarThreshold)
--
-- hud.gfx's CompassMarker class confirms the rest of it: the fields are m_Id, m_Type,
-- m_State, m_Angle, m_AnglePitch, m_Distance, ... in the order the update array sends them,
-- "Frame" is m_Angle, and the icon is loaded from Libs/UI/Textures/Icons/Map.
--
-- What is NOT verified is what that angle is measured FROM. The one working example
-- (NoHorseTeleportMapMarkersOnly) arrives at it by taking the bearing backwards and adding
-- 45 degrees, its author noting it "seems like the complete opposite of what it should be
-- mathematically but ok whatever". That is very likely a world-to-map rotation, which may
-- well differ between Trosecko and Kutnohorsko. So: opt in with merc_camp_compass 1, and
-- merc_camp_compass_offset (dev) turns the fudge while you watch it.
mercenaries.CampCompassEnabled = false
mercenaries.CampCompassKey     = "MERC_CAMP"   -- its own id on the compass
mercenaries.CampCompassIcon    = "camp"        -- a vanilla icon name, so it cannot miss art
mercenaries.CampCompassOffset  = 45.0   -- degrees, see above
mercenaries.CampCompassMs      = 250    -- redraw interval; the marker only moves as you do
mercenaries.CampCompassMinDist = 10.0   -- standing in camp, the camp needs no signpost
mercenaries.CampCompassNear    = 3      -- full alpha inside this
mercenaries.CampCompassLayer   = 50     -- switches layer here
mercenaries.CampCompassFar     = 5000   -- ...and stays legible right across the map

function mercenaries:CampCompassOn()
    if self._campCompassLoaded == nil then
        local v
        pcall(function() v = self:LoadString("MercCampCompass") end)
        self.CampCompassEnabled = (v == "1")
        self._campCompassLoaded = true
    end
    return self.CampCompassEnabled
end

function mercenaries:CampCompassDrop()
    if not self._campCompassUp then return end
    self._campCompassUp = false
    pcall(function()
        UIAction.CallFunction("hud", -1, "RemoveCompassMarker", self.CampCompassKey)
    end)
end

function mercenaries:CampCompassSet(on)
    self.CampCompassEnabled = on and true or false
    self._campCompassLoaded = true
    self:SaveString("MercCampCompass", self.CampCompassEnabled and "1" or "0")
    if self.CampCompassEnabled then
        self:CampCompassArm()
    else
        self:CampCompassDrop()
    end
    mmLog("camp compass marker " .. (self.CampCompassEnabled and "on" or "off"))
end

function mercenaries:CampCompassOffsetSet(line)
    local deg = tonumber(self:CmdClean(line))
    if not deg then
        mmLog("compass bearing offset is " .. tostring(self.CampCompassOffset)
              .. " degrees (merc_camp_compass_offset <degrees>)")
        return
    end
    self.CampCompassOffset = deg
    mmLog("compass bearing offset set to " .. tostring(deg) .. " degrees")
end

-- Arm the redraw chain. Latched, because the chain re-arms itself: a second arm would run
-- two chains at once for the rest of the session.
function mercenaries:CampCompassArm()
    if self._campCompassArmed then return end
    self._campCompassArmed = true
    Script.SetTimerForFunction(self.CampCompassMs or 250, "mercenaries.CampCompassTick")
end

function mercenaries.CampCompassTick()
    local self = mercenaries
    self._campCompassArmed = false

    if not self:CampCompassOn() then
        self:CampCompassDrop()
        return                                   -- switched off: let the chain end
    end

    local pos = self:MarkerPosCamp()
    local pp
    pcall(function() pp = player:GetWorldPos() end)

    if pos and pp then
        local dx, dy = pos.x - pp.x, pos.y - pp.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < (self.CampCompassMinDist or 10.0) then
            self:CampCompassDrop()
        else
            local deg = math.deg(math.atan2(-dx, -dy)) + (self.CampCompassOffset or 45.0)
            while deg < 0 do deg = deg + 360 end
            while deg >= 360 do deg = deg - 360 end
            pcall(function()
                if not self._campCompassUp then
                    UIAction.CallFunction("hud", -1, "AddCompassMarker",
                        self.CampCompassKey, self.CampCompassIcon, 1, -1, -1,
                        dist, deg, false, false,
                        self.CampCompassNear, self.CampCompassLayer, self.CampCompassFar)
                    self._campCompassUp = true
                end
                UIAction.SetArray("hud", -1, "CompassMarkers",
                    { 1, self.CampCompassKey, -1, dist, deg, 0, false, false })
                UIAction.CallFunction("hud", -1, "UpdateCompass", 0)
            end)
        end
    else
        self:CampCompassDrop()
    end

    self:CampCompassArm()
end

-- ==== load ====
--
-- Latches that died with the level, and a saved setting that belongs to the save just
-- loaded rather than the one before it. The ApseMap listeners this used to register are
-- gone with the map markers; they are dropped once here in case an older session in this
-- process still has one live.
function mercenaries:MapMarkerOnLoad()
    self._campCompassLoaded = nil
    self._campCompassArmed  = false
    self._campCompassUp     = false

    pcall(function()
        UIAction.UnregisterElementListener(mercenaries, "CampMapEvent")
        UIAction.UnregisterElementListener(mercenaries, "CampMapMarkerShow")
        UIAction.UnregisterElementListener(mercenaries, "CampMapMarkerHide")
    end)

    if self:CampCompassOn() then self:CampCompassArm() end
end
