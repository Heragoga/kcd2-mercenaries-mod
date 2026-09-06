-- ============================================================================
--  The camp on the world map (and, if asked for, on the compass)
-- ============================================================================
--
-- RESEARCH NOTE, and a correction. This mod had concluded there was no Lua route to the
-- map at all, and every closed negative behind that conclusion is still true: there is no
-- `Map` global, `C_ScriptBind_Map` exposes only CallScript, `LocationPoint` is dead, and a
-- Skald `ShowMapMarker` on a Lua-spawned NPC never renders (docs/skald). They were all
-- looking in the wrong place. The map is not a game system with a script binding - it is a
-- Scaleform movie, and UIAction talks to Scaleform directly. Two shipped mods do exactly
-- this; both are in references/ (NoHorseTeleportMapMarkersOnly, ddv_hc_map_marker).
--
-- Verified against the game's own definitions rather than inferred from those mods:
--
--   Libs/UI/UIElements/ApseMap.xml
--       <array name="PoiMarkers" varname="g_PoiMarkersA" />
--       <function name="AddPoiMarkers"    funcname="fc_addPoiMarkers" />     -- no params
--       <function name="RemovePoiMarkers" funcname="fc_removePoiMarkers" />  -- no params
--
--   ApseMap.gfx, class PoiMarker: SetData reads Id, m_UiName, m_IconName, m_IsFastTravel
--       and m_Position, then loads
--       Libs/UI/Textures/Icons/Map/<icon>[_undiscovered]_icon.dds and ..._sh_icon.dds.
--
-- So a POI is nine values pushed into one array, and the icon is chosen by NAME - which is
-- why this needs no art of its own: the base game already ships camp_icon.dds and
-- camp_sh_icon.dds (Libs/UI/Textures/icons/Map). ddv_hc_map_marker ships its own pair to
-- get a custom icon; this mod tried that and reverted, see MapMarkerRows.
--
--   { id, uniqueKey, uiTextKey, iconName, state, isFastTravel, 0, worldX, worldY }
--
-- WHY ONLY OnShow, AND WHY RemovePoiMarkers IS NEVER CALLED. fc_open's teardown clears the
-- marker containers when the map closes, so every open starts empty and the game re-pushes
-- its own POIs; adding ours on each OnShow is therefore enough and cannot accumulate.
-- RemovePoiMarkers takes no argument and clears the whole container, the game's own POIs
-- with it - ddv_hc_map_marker calls it three times a second because it is redrawing a
-- moving marker, and that is a trade this mod has no reason to make.

local function mmLog(s) System.LogAlways("[MapMarker] " .. tostring(s)) end

mercenaries.CampMapMarkerState = 1     -- discovered; 0 would ask for a _undiscovered texture
mercenaries.CampMarkerEnabled  = true

-- The mod's own POIs. Each row names a method that returns a position or nil, so a marker
-- simply does not exist when there is nothing to point at.
--
-- VANILLA ICON NAMES, deliberately. Shipping our own 128x128 art to make the markers bigger
-- was tried and REVERTED: all three drew with no texture at all. The cause was the files,
-- not the route - Pillow's pixel_format="BC3" writes dxgiFormat 76 (BC3_TYPELESS) with
-- arraySize 0, which is not a loadable texture, and the stock icons are BC7_UNORM (98) with
-- arraySize 1. tools/gen_map_icons.py now writes a correct header, but nothing here uses it
-- until it has actually been seen to render; see docs/map-marker.md, "Making a marker
-- bigger". Stock names cannot fail this way, so stock names it is.
--
-- Tents for the camp, crossed blades for the men. Deliberately NOT campEnemy for the
-- waiting men (skull and red tent - reads hostile) and no second tent, so nothing can be
-- confused with the camp. Aleksej carries the same crossed blades as the waiting men rather
-- than the tipster pin: the pin is a map-pin shape and sits oddly next to icons that are
-- drawn objects. The two are told apart by their labels, not their art.
mercenaries.MapMarkerRows = {
    { key = "MERC_CAMP",    icon = "camp",
      text = "merc_ui_camp_marker",    at = "MarkerPosCamp"    },
    { key = "MERC_WAIT",    icon = "weaponsmiths",
      text = "merc_ui_wait_marker",    at = "MarkerPosWaiting" },
    { key = "MERC_ALEKSEJ", icon = "weaponsmiths",
      text = "merc_ui_aleksej_marker", at = "MarkerPosAleksej" },
}

-- ==== where to point ====
--
-- The camp is gated on CampActive, not on the saved origin, and deliberately so: the save
-- records the camp's coordinates but not which level it stood on, and Trosecko and
-- Kutnohorsko are separate worlds sharing one coordinate space. A camp that is ACTUALLY
-- standing is on the level the player is looking at, so its origin is the right place to
-- draw. No camp up on this level, no marker - which is also the honest answer.
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

-- Men left standing somewhere. "Wait here" is a real hold order (SetState "wait" ->
-- HoldBegin), so HoldAnchor is the exact ground they were told to hold and is what the
-- player is trying to find again. The older MercIdle state carries no anchor, so for that
-- one the men's own centroid is the honest answer.
--
-- Not drawn while they are in camp: the camp marker already says where they are, and two
-- markers on one spot is worse than one.
function mercenaries:MarkerPosWaiting()
    if _G.MercenariesDismissed then return nil end
    if _G.MercInCamp then return nil end

    if self.HoldActive and self.HoldAnchor and self.HoldAnchor.x then
        return self.HoldAnchor
    end
    if not _G.MercIdle then return nil end

    local sx, sy, sz, n = 0, 0, 0, 0
    for _, ent in pairs(self.ActiveMercs or {}) do
        local p
        pcall(function()
            if self:IsAliveAndWell(ent, true) then p = ent:GetWorldPos() end
        end)
        if p then sx, sy, sz, n = sx + p.x, sy + p.y, sz + p.z, n + 1 end
    end
    if n == 0 then return nil end
    return { x = sx / n, y = sy / n, z = sz / n }
end

-- Aleksej, wherever he is standing. Found the same way the questline finds him: the live id
-- if the lodging is up this session, else the name persisted across the save (see
-- AlxLodgingNameTag and the keep-and-adopt note in mercenaries_aleksej.lua). No Aleksej in
-- this save, or a dead one, means no marker.
function mercenaries:MarkerPosAleksej()
    local e
    if self.AlxLodgingId then
        pcall(function() e = System.GetEntity(self.AlxLodgingId) end)
    end
    if not e then
        local nm
        pcall(function() nm = self:LoadString(self.AlxLodgingNameTag or "AlxLodgingName") end)
        if nm and nm ~= "" and nm ~= "0" then
            pcall(function() e = System.GetEntityByName(nm) end)
        end
    end
    if not e then return nil end

    local alive = true
    pcall(function()
        if e.actor then alive = self:IsAliveAndWell(e, true) and true or false end
    end)
    if not alive then return nil end

    local p
    pcall(function() p = e:GetWorldPos() end)
    if not (p and p.x) then return nil end
    return p
end

-- ==== the setting ====
function mercenaries:CampMarkerOn()
    if self._campMarkerLoaded == nil then
        local v
        pcall(function() v = self:LoadString("MercCampMarker") end)
        self.CampMarkerEnabled = (v ~= "0")
        self._campMarkerLoaded = true
    end
    return self.CampMarkerEnabled
end

function mercenaries:CampMarkerSet(on)
    self.CampMarkerEnabled = on and true or false
    self._campMarkerLoaded = true
    self:SaveString("MercCampMarker", self.CampMarkerEnabled and "1" or "0")
    mmLog("camp map marker " .. (self.CampMarkerEnabled and "on" or "off")
          .. " (it appears the next time you open the map)")
end

-- ==== the map ====
--
-- FIRST ATTEMPT DREW NOTHING, and the log said nothing either, because the only lines in
-- here were on the failure paths. Two candidate causes were left standing, so this version
-- is built to tell them apart in one run rather than to guess again:
--
--   1. THE TRIGGER. Both reference mods listen for "OnShow" on ApseMap - but ApseMap.xml
--      declares no such event (its only OnShow* is OnShowTooltipPos), and no base-game Lua
--      registers an element listener at all, so there is no vanilla example to copy. The
--      scriptbind docs say an EMPTY event name receives every event the element fires, so
--      that listener is registered too, and each distinct event name is logged once. If
--      "OnShow" is real, both fire and the latch drops one; if it is not, the catch-all
--      still draws and the log names whatever the map really fires.
--   2. THE ARRAY SHAPE. The leading value is an id in one reading and a COUNT in the other:
--      NoHorseTeleportMapMarkersOnly sends 1 with one marker, ddv_hc_map_marker sends 666.
--      Both readings fit one marker. CLOSED NEGATIVE: UIAction.GetArray does NOT answer
--      this - it returned 0 values every time, including immediately after a SetArray that
--      visibly drew a marker. The array is write-through to the movie and reads back empty,
--      so do not reach for GetArray here again. What settles it is drawing three at once.
--
-- The icon is NOT a candidate: Libs/UI/Textures/Icons/Map/camp_icon.dds and camp_sh_icon.dds
-- ship in the game's own IPL_GameData.pak, at exactly the path PoiMarker builds.
mercenaries.MapMarkerVerbose    = false  -- merc_map_probe 1 brings the event log back
mercenaries.MapMarkerSessionGap = 2.0    -- a quiet gap this long means the map was closed
mercenaries.MapMarkerPushes     = 6      -- pushes per opening; see CampMapMarkerDraw

-- THE MARKER ID BAND. Three runs, three outcomes, and they only make sense together:
--
--   ids 1 and 2   -> CRASHED the map open, but only once the icons really resolved
--   ids 9001+     -> no crash and no markers at all, though the push reported success
--   666           -> what ddv_hc_map_marker ships, and that mod works
--
-- PoiMarker builds its clip depth from the Id (getMCDepth, MAX_DEPTH, attachMovie). Low ids
-- land on depths the game's own POIs are already using, and attaching over a live clip is
-- what took the game down; a very high id runs past the movie's depth ceiling, so
-- attachMovie never happens and there is nothing to draw and nothing to crash. 666 is above
-- vanilla's POIs and below the ceiling, which is presumably how ddv_hc_map_marker arrived
-- at it. Ours sit just after it.
--
-- Tunable live (merc_map_idbase, dev) because this band is inferred from three data points,
-- not read out of the movie.
mercenaries.MapMarkerIdBase     = 666

-- ROUND TWO. The listener works: ApseMap fires OnInit, OnShow, OnPlayAudio,
-- OnUpdatingChanged, OnCursorOnActiveAreaChanged, OnShowTooltipPos, OnHideTooltip,
-- OnHighlightFastTravelPoint, OnHide, OnUnload and OnInstanceDestroyed - so OnShow is real
-- after all, just not declared in ApseMap.xml. The push reported success and still drew
-- nothing. Two faults were visible in that log and both are fixed here.
--
-- THE INSTANCE. The events arrive with instanceId 130725, and round one forwarded that
-- straight into SetArray - but the scriptbind docs say of instanceID: "if instance with id
-- does not exist, it will be created". So an id that is really a handle, not an index,
-- quietly gets a PHANTOM instance created for it and the live map never sees the array.
-- ddv_hc_map_marker hardcodes -1 (= all instances) for every call and the horse mod
-- forwards the id; that is the one substantive difference between them. -1 it is. The
-- event's own instance is still logged, because it is the thing being ruled out.
--
-- WHEN. OnInit fires before the movie's variables exist and OnUnload after they are gone;
-- pushing at either is pointless, and worse, round one's once-per-opening latch let those
-- two claim the opening so the useful OnShow push was skipped. Only events that mean "the
-- map is up" draw now, and a handful of pushes per opening are allowed rather than one, so
-- that the marker survives the game populating its own POIs after us.
local MAP_IS_DOWN = {
    OnInit = true, OnUnload = true, OnHide = true, OnInstanceDestroyed = true,
}

-- ROUND THREE: IT CRASHED THE GAME ON OPENING THE MAP. What was on screen was two markers
-- pushed as one 18-value array, with ids 1 and 2 and real vanilla textures behind them.
--
-- The cause is NOT proven - there was no callstack, only the log ending mid-opening - so
-- what follows is three changes, each of which is defensible on its own and none of which
-- costs anything. Two runs bound the problem:
--
--   * one marker, id 1, real texture, pushed repeatedly  -> fine, for a whole session
--   * two markers, ids 1 and 2, textures that FAILED to load -> fine, exited cleanly
--   * two markers, ids 1 and 2, textures that loaded     -> crash on the first opening
--
-- So it takes more than one marker AND the icons actually resolving. That also retires the
-- id-versus-count question: a leading COUNT of 666 would leave ddv_hc_map_marker visibly
-- broken for everyone who runs it, so the leading value is an Id - and PoiMarker derives
-- its clip depth from the Id (GetDepth, MAX_DEPTH, attachMovie). Ids 1 and 2 are exactly
-- where the game's own POIs are likeliest to sit, and attaching over a live clip is a very
-- good way to leave a dangling reference behind. Hence:
--
--   1. ids 9001+, well clear of anything vanilla is plausibly using (ddv_hc_map_marker
--      picking 666 out of the air now looks like the same defence);
--   2. ONE marker per SetArray+AddPoiMarkers call, so every call is the exact shape of the
--      one that was proven to work, rather than a multi-record array whose stride is a guess;
--   3. one push per opening instead of six. The six were a hedge from when nothing drew at
--      all; re-adding the same markers five more times is now pure risk.
--
-- If it crashes again, merc_camp_marker 0 turns the whole thing off, and the setting is read
-- before anything is pushed.

-- Every event ApseMap fires, whatever it is called. Registered with an empty event name.
function mercenaries:CampMapEvent(elementName, instanceId, eventName, argTable)
    local name = tostring(eventName or "?")
    if self.MapMarkerVerbose then
        self._campMapSeen = self._campMapSeen or {}
        if not self._campMapSeen[name] then
            self._campMapSeen[name] = true
            mmLog("ApseMap fires an event called '" .. name .. "' (instance "
                  .. tostring(instanceId) .. ")")
        end
    end
    self:CampMapMarkerDraw(elementName, instanceId, name)
end

-- The named "OnShow", kept alongside the catch-all so the log can say which one delivered.
-- Declared with a colon on purpose. The scriptbind docs write the callback as
-- `CallbackName(elementName, instanceId, eventName, argTable)`, but the engine invokes it as
-- a METHOD on the registered table - which is why both reference mods declare theirs with a
-- colon and still read elementName correctly, and why ddv_hc_map_marker's `self.mapOpen`
-- does not blow up on a string.
function mercenaries:CampMapMarkerShow(elementName, instanceId, eventName, argTable)
    self:CampMapMarkerDraw(elementName, instanceId, "OnShow")
end

function mercenaries:CampMapMarkerHide()
    self._campMapPushed = 0
end

function mercenaries:CampMapMarkerDraw(elementName, instanceId, via)
    if not self:CampMarkerOn() then return end
    if MAP_IS_DOWN[via] then return end          -- the movie is not there to draw on

    -- A new opening of the map, without depending on a close event arriving. Events come in
    -- bursts while the map is up and stop when it is down, so a quiet gap IS the close: it
    -- re-arms the push budget. This also survives the map pausing game time, which would
    -- freeze the gap at zero and hold the budget spent.
    local now = 0
    pcall(function() now = System.GetCurrTime() or 0 end)
    if (now - (self._campMapLastEventAt or -9999)) > (self.MapMarkerSessionGap or 2.0) then
        self._campMapPushed = 0
    end
    self._campMapLastEventAt = now

    local budget = self.MapMarkerPushes or 6
    if (self._campMapPushed or 0) >= budget then return end

    -- ONE MARKER PER CALL, and this is the whole lesson of the crash below: each call is
    -- then byte-identical in shape to the single-marker push that was proven to work, and
    -- the question of how the movie walks a multi-record array never has to be answered.
    local todo = {}
    local base = self.MapMarkerIdBase or 666
    for i, m in ipairs(self.MapMarkerRows or {}) do
        local pos
        local getter = m.at and self[m.at]
        if getter then pcall(function() pos = getter(self) end) end
        if pos and pos.x and pos.y then
            -- The id is the row's position in the band, so every marker keeps the same id
            -- for the life of the session whether or not its neighbours are present.
            todo[#todo + 1] = { m = m, pos = pos, id = base + i - 1 }
        end
    end

    if #todo == 0 then
        if self.MapMarkerVerbose and (self._campMapPushed or 0) == 0 then
            mmLog("map up (via " .. tostring(via) .. ") but nothing of ours to point at here")
        end
        self._campMapPushed = budget             -- do not re-ask every event of this opening
        return
    end

    local el    = elementName or "ApseMap"
    local nth   = (self._campMapPushed or 0) + 1
    local first = (nth == 1)
    self._campMapPushed = nth

    -- Instance -1, NOT the event's instanceId. See the note above MAP_IS_DOWN.
    local drawn, failed = {}, nil
    for _, t in ipairs(todo) do
        local row = { t.id, t.m.key, t.m.text, t.m.icon, self.CampMapMarkerState,
                      false, 0, t.pos.x, t.pos.y }
        local ok, err = pcall(function()
            UIAction.SetArray(el, -1, "PoiMarkers", row)
            UIAction.CallFunction(el, -1, "AddPoiMarkers")
        end)
        if ok then
            drawn[#drawn + 1] = string.format("%s(%d) @ %.0f,%.0f",
                                              t.m.key, t.id, t.pos.x, t.pos.y)
        else
            failed = failed or tostring(err)
        end
    end

    if first then
        mmLog(string.format("pushed %d marker(s) to %s/-1 one at a time (via %s): %s%s",
              #drawn, tostring(el), tostring(via), table.concat(drawn, ", "),
              failed and ("; one failed: " .. failed) or ""))
    end
end

-- Both of these exist because the two numbers they set were arrived at by elimination
-- rather than by reading the movie. If a marker is missing, walk the id base (400, 666, 900,
-- 2000) before changing anything else.
function mercenaries:MapIdBaseSet(line)
    local n = tonumber(self:CmdClean(line))
    if not n then
        mmLog("marker id base is " .. tostring(self.MapMarkerIdBase)
              .. " (merc_map_idbase <n>; ids run from there, one per marker)")
        return
    end
    self.MapMarkerIdBase = n
    mmLog("marker id base set to " .. n .. " - reopen the map")
end

function mercenaries:MapPushesSet(line)
    local n = tonumber(self:CmdClean(line))
    if not n then
        mmLog("push budget is " .. tostring(self.MapMarkerPushes) .. " per opening"
              .. " (merc_map_pushes <n>)")
        return
    end
    self.MapMarkerPushes = n
    mmLog("push budget set to " .. n .. " per opening - reopen the map")
end

function mercenaries:MapProbeSet(on)
    self.MapMarkerVerbose = on and true or false
    self._campMapSeen = {}
    mmLog("map marker chatter " .. (self.MapMarkerVerbose and "on" or "off"))
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
-- "Frame" is m_Angle, and the icon is loaded from Libs/UI/Textures/Icons/Map - the same
-- folder as the map POI, so "camp" is as valid here as it is there.
--
-- What is NOT verified is what that angle is measured FROM. The one working example
-- (NoHorseTeleportMapMarkersOnly) arrives at it by taking the bearing backwards and adding
-- 45 degrees, its author noting it "seems like the complete opposite of what it should be
-- mathematically but ok whatever". That is very likely a world-to-map rotation, which may
-- well differ between Trosecko and Kutnohorsko. So: opt in with merc_camp_compass 1, and
-- merc_camp_compass_offset (dev) turns the fudge while you watch it.
mercenaries.CampCompassEnabled = false
mercenaries.CampCompassKey     = "MERC_CAMP"   -- its own id on the compass
mercenaries.CampCompassIcon    = "camp"        -- same art as the map marker
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
-- Both shipped reference mods re-register their ApseMap listeners on every OnGameplayStarted
-- rather than once per session, and neither drops the old registration first - so both are
-- one stacked listener per load away from adding their marker twice. There is no need to
-- live with that: the scriptbind docs (references/kcd2-mod-docs-main) give
--
--   UIAction.UnregisterElementListener( table, callbackFunctionName )
--
-- so each callback is dropped before it is re-registered and only ever one is live. The
-- latch in CampMapMarkerShow stays as the cheap belt to that brace.
--
-- Everything else in here is a latch that died with the level and has to be let go of, or a
-- saved setting that belongs to the save just loaded rather than the one before it.
function mercenaries:MapMarkerOnLoad()
    self._campMarkerLoaded  = nil
    self._campCompassLoaded = nil
    self._campMapPushed     = 0
    self._campCompassArmed  = false
    self._campCompassUp     = false

    self._campMapSeen = {}
    self._campMapLastEventAt = nil

    -- The empty event name is the important one: the scriptbind docs say it receives every
    -- event the element fires, and ApseMap declares no OnShow at all. OnShow is registered
    -- anyway, on its own callback, so the log can say which of the two actually delivers.
    local ok, err = pcall(function()
        UIAction.UnregisterElementListener(mercenaries, "CampMapEvent")
        UIAction.UnregisterElementListener(mercenaries, "CampMapMarkerShow")
        UIAction.UnregisterElementListener(mercenaries, "CampMapMarkerHide")
        UIAction.RegisterElementListener(mercenaries, "ApseMap", -1, "",       "CampMapEvent")
        UIAction.RegisterElementListener(mercenaries, "ApseMap", -1, "OnShow", "CampMapMarkerShow")
        UIAction.RegisterElementListener(mercenaries, "ApseMap", -1, "OnHide", "CampMapMarkerHide")
    end)
    if ok then
        mmLog("listening to ApseMap (catch-all + OnShow/OnHide)")
    else
        mmLog("could not listen to the map: " .. tostring(err))
    end

    if self:CampCompassOn() then self:CampCompassArm() end
end
