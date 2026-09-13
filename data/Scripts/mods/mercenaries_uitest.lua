-- UI technique test bench. Every command here answers one question about what KCD2's
-- Scaleform UI will let a mod do. Nothing in this file is used by the shipping mod.
-- Background and the API reference: docs/ui.md.
--
-- merc_ui_off is the panic button - it restores the HUD and the action map.

mercenaries.UIT = mercenaries.UIT or {
    PID       = 47101,   -- our own Menu instance, so we never touch the game's
    stageW    = 1280,
    stageH    = 720,
    buttons   = {},
    tracking  = false,
    drawing   = false,
    drawMode  = "calib",
    drawEnt   = nil,
    drawTicks = 0,
    drawBeat  = 0,
    samples   = {},
    sel       = 1,
    overlay   = false,
    bubbling  = false,
    bubbles   = {},
}

local function log(s) System.LogAlways("[MercUI] " .. tostring(s)) end

local function cvar(n)
    local v
    pcall(function() v = System.GetCVar(n) end)
    return v
end

local function setcvar(n, v)
    local ok = pcall(function() System.SetCVar(n, v) end)
    if not ok then pcall(function() System.ExecuteCommand(n .. " " .. tostring(v)) end) end
end

local function screenH()
    local h = tonumber(cvar("r_height"))
    if not h or h < 100 then h = 1080 end
    return h
end

-- ============================================================================
-- merc_ui_probe
-- ============================================================================

function mercenaries:UIProbe()
    local function mark(name, v) log(string.format("  %-28s %s", name, v and "YES" or "no")) end

    log("==== UI capability probe ====")
    mark("UIAction", UIAction ~= nil)
    if UIAction then
        local n = 0
        for _, v in pairs(UIAction) do if type(v) == "function" then n = n + 1 end end
        log("  UIAction methods: " .. n .. " (no CreateMovieClip - dynamic sprites are flowgraph only)")
    end
    mark("ActionMapManager", ActionMapManager ~= nil)
    mark("PlayerEventDispatcher", _G.PlayerEventDispatcher ~= nil)
    mark("HUD", _G.HUD ~= nil)

    log("  -- immediate mode --")
    mark("System.DrawText", System.DrawText ~= nil)
    mark("System.DrawLabel", System.DrawLabel ~= nil)
    mark("System.Draw2DLine", System.Draw2DLine ~= nil)
    mark("System.DrawLine", System.DrawLine ~= nil)
    mark("System.DrawTriStrip", System.DrawTriStrip ~= nil)
    mark("System.ProjectToScreen", System.ProjectToScreen ~= nil)
    mark("System.SetScissor", System.SetScissor ~= nil)

    log("  -- cvars that gate drawing --")
    for _, n in ipairs({ "r_enableAuxGeom", "r_auxGeom", "r_AuxGeomAutoScaleOver1080pWH",
                         "r_AuxGeomFontAutoScaleMultiplierOver1080pWH", "r_DisplayInfo",
                         "wh_ui_BubblesEnabled", "wh_ui_BubbleDebug", "wh_gfx_useSWF",
                         "gfx_enabled", "gfx_uiaction_enable", "gfx_draw", "gfx_debugdraw" }) do
        log(string.format("  %-44s = %s", n, tostring(cvar(n))))
    end

    local vp
    pcall(function() vp = System.GetViewport() end)
    if vp then
        log(string.format("  viewport %sx%s   r_width=%s r_height=%s",
            tostring(vp.width), tostring(vp.height), tostring(cvar("r_width")), tostring(cvar("r_height"))))
    end
    log("  drivable flash sprites with no new assets: hud=71 clips, LockPicking=6. Nothing else has any.")
    log("==== end probe ====")
end

-- ============================================================================
-- merc_ui_menu - interactive screen
-- ============================================================================

function mercenaries:UIMenuPage(page)
    local B = {}
    local function btn(label, tip, fn) B[#B + 1] = { kind = "basic", label = label, tooltip = tip or "", fn = fn } end

    if page == "second" then
        btn("Back to page one", "Tests deferred navigation", function() self:UIMenu("main") end)
        btn("Disabled button", "Should be greyed out", nil)
        B[#B].disabled = true
        btn("Close", "Shuts the test screen", function() self:UIMenuClose() end)
        return B, "Test screen - page two"
    end

    btn("Fire a HUD notification", "Calls hud ShowNotification", function()
        pcall(function() UIAction.CallFunction("hud", -1, "ShowNotification", "button worked") end)
    end)
    btn("Go to page two", "Rebuilds the page in place", function() self:UIMenu("second") end)
    B[#B + 1] = { kind = "value", label = "Squad size", tooltip = "Slider test",
                  value = self.UIT.sel or 1, vmin = 1, vmax = 20 }
    B[#B + 1] = { kind = "choice", label = "Stance", tooltip = "Dropdown test",
                  options = { "Aggressive", "Defensive", "Hold fire" } }
    btn("Ask me something", "Tests AddConfirmation", function()
        pcall(function()
            UIAction.CallFunction("Menu", self.UIT.PID, "AddConfirmation", "uit_q",
                "Does this confirmation box work?", "Yes", "No", 0, 1)
        end)
    end)
    btn("Close", "Shuts the test screen", function() self:UIMenuClose() end)

    return B, "Mercenaries - UI test bench"
end

function mercenaries:UIMenu(page)
    if not UIAction then log("UIAction is nil - run merc_ui_probe"); return end
    page = page or "main"

    local pid = self.UIT.PID
    local B, title = self:UIMenuPage(page)
    self.UIT.buttons = B
    self.UIT.page    = page

    local ok, err = pcall(function()
        UIAction.HideElement("hud", -1)
        UIAction.HideElement("Menu", -1)
        UIAction.CallFunction("Menu", pid, "ClearAll")
        UIAction.HideElement("Menu", pid)
        for _, cb in ipairs({ "UITestOnButton", "UITestOnValue", "UITestOnChoice", "UITestOnConfirm" }) do
            pcall(function() UIAction.UnregisterElementListener(self, cb) end)
        end

        -- everything goes in container 0: mixing container 1 makes the rows overlap
        local shown = #B
        if shown > 10 then shown = 10 end
        local frac = (shown >= 7) and 0.27 or 0.325

        UIAction.CallFunction("Menu", pid, "PreparePage", 0,
            math.floor(screenH() * frac), shown, tostring(title), 1)
        ActionMapManager.EnableActionMap("menu", true)
        UIAction.CallFunction("Menu", pid, "SetActiveUser", "")

        for i, el in ipairs(B) do
            local id = "uit_" .. i
            if el.kind == "value" then
                UIAction.CallFunction("Menu", pid, "AddValueButton", id, 0,
                    tostring(el.label), el.value, el.vmin, el.vmax, tostring(el.tooltip), false)
            elseif el.kind == "choice" then
                UIAction.CallFunction("Menu", pid, "AddChoicesButton", id, 0,
                    tostring(el.label), tostring(el.tooltip), false)
                for ci, opt in ipairs(el.options) do
                    UIAction.CallFunction("Menu", pid, "AddChoiceOption", ci - 1, id, 0,
                        tostring(opt), tostring(el.tooltip), false)
                end
            else
                UIAction.CallFunction("Menu", pid, "AddBasicButton", id, 0,
                    tostring(el.label), tostring(el.tooltip), el.disabled == true)
            end
        end

        UIAction.ShowElement("Menu", pid)
        UIAction.RegisterElementListener(self, "Menu", pid, "OnButton", "UITestOnButton")
        UIAction.RegisterElementListener(self, "Menu", pid, "OnInteractiveValue", "UITestOnValue")
        UIAction.RegisterElementListener(self, "Menu", pid, "OnInteractiveChoice", "UITestOnChoice")
        UIAction.RegisterElementListener(self, "Menu", pid, "OnConfirm", "UITestOnConfirm")
        UIAction.CallFunction("Menu", pid, "ShowPage")
    end)

    if ok then
        log("menu opened on instance " .. pid .. " (page " .. page .. ")")
    else
        log("menu FAILED: " .. tostring(err))
        self:UIOff()
    end
end

local function firstArg(argTable)
    if not argTable then return "" end
    for _, v in pairs(argTable) do
        if v ~= nil then return tostring(v) end
    end
    return ""
end

mercenaries.UITestOnButton = function(func, elementName, instanceId, eventName, argTable)
    local self = mercenaries
    local id = firstArg(argTable)
    log("OnButton -> " .. id)
    local idx = tonumber(string.match(id, "^uit_(%d+)$"))
    local el = idx and self.UIT.buttons[idx]
    if el and el.fn and not el.disabled then
        self.UIT.pending = el.fn
        pcall(function() Script.SetTimerForFunction(1, "mercenaries.UITestRunPending") end)
    end
end

mercenaries.UITestRunPending = function()
    local fn = mercenaries.UIT.pending
    mercenaries.UIT.pending = nil
    if fn then pcall(fn) end
end

mercenaries.UITestOnValue = function(func, elementName, instanceId, eventName, argTable)
    local id  = argTable and argTable[0] and tostring(argTable[0]) or "?"
    local val = argTable and argTable[1] and tonumber(argTable[1]) or -1
    mercenaries.UIT.sel = math.floor(val + 0.5)
    log(string.format("OnInteractiveValue -> %s = %s", id, tostring(val)))
end

mercenaries.UITestOnChoice = function(func, elementName, instanceId, eventName, argTable)
    log(string.format("OnInteractiveChoice -> %s = %s",
        tostring(argTable and argTable[0]), tostring(argTable and argTable[1])))
end

mercenaries.UITestOnConfirm = function(func, elementName, instanceId, eventName, argTable)
    log(string.format("OnConfirm -> %s answer=%s",
        tostring(argTable and argTable[0]), tostring(argTable and argTable[1])))
end

function mercenaries:UIMenuClose()
    pcall(function()
        UIAction.CallFunction("Menu", self.UIT.PID, "ClearAll")
        UIAction.HideElement("Menu", self.UIT.PID)
        UIAction.ShowElement("hud", 0)
        ActionMapManager.EnableActionMap("menu", false)
    end)
    log("menu closed")
end

-- ============================================================================
-- merc_ui_modal - and how to get rid of it again
-- ============================================================================

function mercenaries:UIModal()
    if not UIAction then log("UIAction is nil"); return end
    pcall(function()
        UIAction.ShowElement("ApseModalDialog", 0)
        for _, ev in ipairs({ "OnConfirm", "OnClose", "OnCancel", "OnAnswer" }) do
            pcall(function()
                UIAction.RegisterElementListener(self, "ApseModalDialog", 0, ev, "UITestOnModal")
            end)
        end
        ActionMapManager.EnableActionMap("menu", true)
        UIAction.CallFunction("ApseModalDialog", 0, "OpenQuestionDialog",
            "This text came from Lua. Does the modal accept arbitrary strings?",
            "Confirm", "Cancel", "[F] confirm", "[Esc] cancel")
    end)
    log("ApseModalDialog opened - merc_ui_modal_close dismisses it")
end

mercenaries.UITestOnModal = function(func, elementName, instanceId, eventName, argTable)
    log(string.format("modal event %s arg=%s", tostring(eventName), firstArg(argTable)))
end

function mercenaries:UIModalClose()
    for _, fn in ipairs({ "CloseDialog", "Close", "HideDialog", "CloseQuestionDialog" }) do
        local ok = pcall(function() UIAction.CallFunction("ApseModalDialog", 0, fn) end)
        log("  tried " .. fn .. " -> " .. (ok and "no error" or "error"))
    end
    pcall(function() UIAction.RequestHide("ApseModalDialog", 0) end)
    pcall(function() UIAction.HideElement("ApseModalDialog", 0) end)
    pcall(function() ActionMapManager.EnableActionMap("menu", false) end)
    log("modal dismissed")
end

-- ============================================================================
-- merc_ui_lock - can Lua move a flash sprite anywhere on screen?
-- LockPicking is the cleanest subject: 6 named clips, no ActionScript of its own,
-- and no HUD logic fighting us for the positions.
-- ============================================================================

function mercenaries:UILock(line)
    local arg = tostring(line or "")
    if arg == "off" then
        pcall(function() UIAction.HideElement("LockPicking", 0) end)
        self.UIT.lockOn = false
        log("LockPicking hidden")
        return
    end

    pcall(function() UIAction.ShowElement("LockPicking", 0) end)
    self.UIT.lockOn = true
    for _, mc in ipairs({ "LockPick", "Cursor", "Point", "Lock", "Pin", "Debug" }) do
        local p, s, v
        pcall(function() p = UIAction.GetPos("LockPicking", 0, mc) end)
        pcall(function() s = UIAction.GetScale("LockPicking", 0, mc) end)
        pcall(function() v = UIAction.IsVisible("LockPicking", 0, mc) end)
        log(string.format("  %-9s pos=(%s,%s) scale=(%s,%s) visible=%s", mc,
            p and tostring(p.x) or "?", p and tostring(p.y) or "?",
            s and tostring(s.x) or "?", s and tostring(s.y) or "?", tostring(v)))
    end
    log("LockPicking shown. Those positions ARE the flash stage space for this element.")
    log("Now try: merc_ui_lockpos Cursor 400 300")
end

function mercenaries:UILockPos(line)
    local mc, x, y = string.match(tostring(line), "(%a+)%s+(%-?%d+)%s+(%-?%d+)")
    if not mc then log("usage: merc_ui_lockpos <clipName> <x> <y>"); return end
    x, y = tonumber(x), tonumber(y)
    local ok = pcall(function()
        UIAction.SetVisible("LockPicking", 0, mc, true)
        UIAction.SetPos("LockPicking", 0, mc, { x = x, y = y, z = 0 })
    end)
    local p
    pcall(function() p = UIAction.GetPos("LockPicking", 0, mc) end)
    log(string.format("%s -> %d,%d  (%s, reads back %s,%s)", mc, x, y,
        ok and "set" or "FAILED", p and tostring(p.x) or "?", p and tostring(p.y) or "?"))
end

-- ============================================================================
-- merc_ui_bubbles - the 16 hud text sprites
-- ============================================================================

-- SetBubbleText restarts the bubble's appear animation, so calling it every tick makes
-- the text strobe. Only send it when the string actually changed; move it every tick.
mercenaries.UIT.bubbleText = mercenaries.UIT.bubbleText or {}

function mercenaries:UIBubbleSet(i, text, x, y, dist)
    text = tostring(text)
    if self.UIT.bubbleText[i] ~= text then
        self.UIT.bubbleText[i] = text
        pcall(function()
            UIAction.CallFunction("hud", -1, "SetBubbleText", i, text, "", dist or 5.0)
        end)
        pcall(function() UIAction.SetVisible("hud", -1, "bubble" .. i, true) end)
    end
    if x and y then
        pcall(function() UIAction.SetPos("hud", -1, "bubble" .. i, { x = x, y = y, z = 0 }) end)
    end
end

function mercenaries:UIBubbles()
    setcvar("wh_ui_BubblesEnabled", 1)
    pcall(function() UIAction.ShowElement("hud", 0) end)
    pcall(function() UIAction.SetVisible("hud", -1, "MasterSwitch", true) end)
    pcall(function() UIAction.SetVisible("hud", -1, "Bubbles", true) end)

    local W, H = self.UIT.stageW, self.UIT.stageH
    self.UIT.bubbles = {}
    local spots = {
        { 0.10, 0.15 }, { 0.50, 0.15 }, { 0.90, 0.15 },
        { 0.10, 0.50 }, { 0.50, 0.50 }, { 0.90, 0.50 },
        { 0.10, 0.85 }, { 0.50, 0.85 },
    }
    for i, s in ipairs(spots) do
        local x, y = math.floor(W * s[1]), math.floor(H * s[2])
        self.UIT.bubbles[i] = { text = string.format("%d (%d,%d)", i, x, y), x = x, y = y }
    end

    -- the hud repositions its own bubbles every frame, so keep re-applying
    if not self.UIT.bubbling then
        self.UIT.bubbling = true
        mercenaries.UIBubbleTick()
    end

    local p
    pcall(function() p = UIAction.GetPos("hud", -1, "bubble1") end)
    log(string.format("8 bubbles requested on a %dx%d stage; bubble1 reads back at (%s,%s)",
        W, H, p and tostring(p.x) or "?", p and tostring(p.y) or "?"))
    log("nothing visible? the hud owns these clips - try merc_ui_lock instead")
end

mercenaries.UIBubbleTick = function()
    local self = mercenaries
    if not self.UIT.bubbling then return end
    for i, b in pairs(self.UIT.bubbles) do
        self:UIBubbleSet(i, b.text, b.x, b.y, 5.0)
    end
    Script.SetTimerForFunction(100, "mercenaries.UIBubbleTick")
end

function mercenaries:UIGetPos(line)
    local i = tonumber(line) or 1
    local ok, p = pcall(function() return UIAction.GetPos("hud", -1, "bubble" .. i) end)
    if ok and p then
        log(string.format("bubble%d at x=%s y=%s z=%s", i, tostring(p.x), tostring(p.y), tostring(p.z)))
    else
        log("GetPos failed: " .. tostring(p))
    end
end

function mercenaries:UIStage(line)
    local w, h = string.match(tostring(line), "(%d+)%s+(%d+)")
    if not w then log("usage: merc_ui_stage <width> <height>"); return end
    self.UIT.stageW, self.UIT.stageH = tonumber(w), tonumber(h)
    log(string.format("assumed stage is now %dx%d", self.UIT.stageW, self.UIT.stageH))
end

function mercenaries:UIClearBubbles()
    self.UIT.bubbling = false
    self.UIT.bubbles = {}
    self.UIT.bubbleText = {}
    for i = 1, 16 do
        pcall(function() UIAction.CallFunction("hud", -1, "SetBubbleText", i, "", "", 0) end)
    end
end

-- ============================================================================
-- merc_ui_proj - what coordinate space does ProjectToScreen answer in?
-- Project a point straight ahead of the camera: whatever comes back IS the centre
-- of the screen, so doubling it gives the full space.
-- ============================================================================

function mercenaries:UIProj()
    local cp, cd
    pcall(function() cp = System.GetViewCameraPos() end)
    pcall(function() cd = System.GetViewCameraDir() end)
    if not (cp and cd) then log("no camera - are you in a level?"); return end

    local function proj(tag, p)
        local s
        pcall(function() s = System.ProjectToScreen(p) end)
        if s then
            log(string.format("  %-14s -> x=%8.2f  y=%8.2f  z=%.4f", tag, s.x, s.y, s.z))
            return s
        end
        log("  " .. tag .. " -> failed")
    end

    local function at(d, ox, oz)
        -- right vector = dir x up, good enough for a horizontal offset
        local rx, ry = cd.y, -cd.x
        local n = math.sqrt(rx * rx + ry * ry)
        if n < 0.0001 then n = 1 end
        return { x = cp.x + cd.x * d + (rx / n) * ox,
                 y = cp.y + cd.y * d + (ry / n) * ox,
                 z = cp.z + cd.z * d + oz }
    end

    log("==== ProjectToScreen calibration ====")
    local c = proj("dead centre", at(10, 0, 0))
    proj("2m left", at(10, -2, 0))
    proj("2m right", at(10, 2, 0))
    proj("2m up", at(10, 0, 2))
    proj("2m down", at(10, 0, -2))
    local vp
    pcall(function() vp = System.GetViewport() end)
    if c then
        self.UIT.projW, self.UIT.projH = c.x * 2, c.y * 2
        log(string.format("centre reads (%.1f, %.1f) so the space is about %.0f x %.0f",
            c.x, c.y, c.x * 2, c.y * 2))
        log("merc_ui_track will now use that space")
        if vp then
            log(string.format("viewport is %sx%s -> %s",
                tostring(vp.width), tostring(vp.height),
                (math.abs(c.x * 2 - 100) < 10) and "PERCENT (0-100)" or "not percent; use the numbers above"))
        end
        log("feed that into merc_ui_stage if the bubbles land wrong")
    end
end

function mercenaries:UITrack()
    local n = 0
    for _ in pairs(self.ActiveMercs or {}) do n = n + 1 end
    if n == 0 and not self.UIT.tracking then
        log("no active mercs - hire some first, this labels the squad")
        return
    end
    self.UIT.tracking = not self.UIT.tracking
    if self.UIT.tracking then
        setcvar("wh_ui_BubblesEnabled", 1)
        log("tracking ON - " .. n .. " merc(s)")
        mercenaries.UITrackTick()
    else
        self:UIClearBubbles()
        log("tracking OFF")
    end
end

mercenaries.UITrackTick = function()
    local self = mercenaries
    if not self.UIT.tracking then return end

    local W, H = self.UIT.stageW, self.UIT.stageH
    local i = 0
    for name, ent in pairs(self.ActiveMercs or {}) do
        if i >= 16 then break end
        local p = ent and ent.GetWorldPos and ent:GetWorldPos()
        if p then
            local sp
            pcall(function() sp = System.ProjectToScreen(p) end)
            if sp then
                i = i + 1
                if i == 1 then
                    log(string.format("ProjectToScreen sample: x=%s y=%s z=%s",
                        tostring(sp.x), tostring(sp.y), tostring(sp.z)))
                end
                local pw = self.UIT.projW or 100
                local ph = self.UIT.projH or 100
                local x = math.floor((sp.x / pw) * W)
                local y = math.floor((sp.y / ph) * H)
                self:UIBubbleSet(i, tostring(name), x, y, 5.0)
            end
        end
    end
    for k = i + 1, 16 do
        pcall(function() UIAction.CallFunction("hud", -1, "SetBubbleText", k, "", "", 0) end)
    end
    Script.SetTimerForFunction(100, "mercenaries.UITrackTick")
end

-- ============================================================================
-- merc_ui_draw - immediate mode. This is the "individual pixels" question.
-- ============================================================================

function mercenaries:UIDraw(line)
    local mode = (line ~= nil and line ~= "") and tostring(line) or nil

    if not mode then
        if not self.UIT.drawing then
            log("not drawing. Use merc_ui_draw_pixels / _calib / _graph / _world / _raw")
            return
        end
        self.UIT.drawing = false
        mercenaries.FrameHooks["uitest"] = nil
        if self.UIT.drawEnt then
            pcall(function() System.RemoveEntity(self.UIT.drawEnt) end)
            self.UIT.drawEnt = nil
        end
        log("draw OFF after " .. self.UIT.drawTicks .. " frames")
        return
    end

    self.UIT.drawMode  = mode or "calib"
    self.UIT.drawTicks = 0
    self.UIT.drawBeat  = 0

    -- aux geometry is what DrawText/Draw2DLine go through; if it is off they no-op silently
    log("r_enableAuxGeom was " .. tostring(cvar("r_enableAuxGeom")) ..
        ", r_auxGeom was " .. tostring(cvar("r_auxGeom")))
    setcvar("r_enableAuxGeom", 1)
    setcvar("r_auxGeom", 1)
    log("forced both to 1; now " .. tostring(cvar("r_enableAuxGeom")) ..
        " / " .. tostring(cvar("r_auxGeom")))
    log("NOTE: r_enableAuxGeom is read when the renderer starts - if 0 at launch the aux")
    log("buffer is a null stub for the whole session. If nothing draws, put")
    log("  r_enableAuxGeom = 1")
    log("in the game's user.cfg and restart, then try again.")

    if not self.UIT.drawing then
        local p
        pcall(function() p = player and player:GetWorldPos() end)
        if not p then log("no player position - are you in a level?"); return end
        local e
        local ok, err = pcall(function()
            e = System.SpawnEntity({
                class = "mercenaries_UIDraw",
                name  = "merc_uidraw_" .. tostring(math.random(100000, 999999)),
                position = { x = p.x, y = p.y, z = p.z },
            })
        end)
        if not ok then log("SpawnEntity threw: " .. tostring(err)); return end
        if not e then log("SpawnEntity returned nil - is mercenaries_UIDraw.ent deployed?"); return end
        self.UIT.drawEnt = e.id
        self.UIT.drawing = true
        log("spawned the per-frame entity")
    end
    -- the entity dispatches mercenaries.FrameHooks, so register into it
    mercenaries.FrameHooks = mercenaries.FrameHooks or {}
    mercenaries.FrameHooks["uitest"] = function(dt) mercenaries:UIDrawTick(dt) end
    local vp
    pcall(function() vp = System.GetViewport() end)
    self.UIT.vpW = (vp and tonumber(vp.width)) or tonumber(cvar("r_width")) or 1920
    self.UIT.vpH = (vp and tonumber(vp.height)) or tonumber(cvar("r_height")) or 1080
    log(string.format("viewport %dx%d - Draw2DLine gets pixel/viewport, DrawText gets pixels",
        self.UIT.vpW, self.UIT.vpH))

    log("draw ON, mode=" .. self.UIT.drawMode .. "   (merc_ui_draw with no argument = off)")
    log("modes: calib | pixels | graph | world | raw | space | glyph | scale | bitmap")
end

function mercenaries:UIDrawTick(dt)
    if not self.UIT.drawing then return end
    self.UIT.drawTicks = self.UIT.drawTicks + 1

    if dt and dt > 0 then
        local inst = 1 / dt
        self.UIT.fps = (self.UIT.fps and (self.UIT.fps * 0.95 + inst * 0.05)) or inst
    end

    -- proof the hook fires at all, once a second, independent of anything rendering
    self.UIT.drawBeat = self.UIT.drawBeat + (dt or 0)
    if self.UIT.drawBeat >= 1.0 then
        self.UIT.drawBeat = 0
        log("OnUpdate is running: " .. self.UIT.drawTicks .. " frames so far")
    end

    local m = self.UIT.drawMode

    -- MEASURED: System.DrawText takes real backbuffer pixels. System.Draw2DLine does NOT -
    -- it goes through aux-geom 2D render flags, where coordinates are normalised 0..1.
    -- Feeding it pixels throws the geometry off into the distance (the "white pyramid").
    -- line() takes pixels and converts; text() takes pixels straight.
    local VW = self.UIT.vpW or 3840
    local VH = self.UIT.vpH or 2160
    local function line(x1, y1, x2, y2, r, g, b, a)
        System.Draw2DLine(x1 / VW, y1 / VH, x2 / VW, y2 / VH, r, g, b, a or 1)
    end
    local function dot(x, y, r, g, b, a)
        line(x, y, x + 1, y, r, g, b, a)
    end
    local function text(x, y, s, size)
        System.DrawText(x, y, s, size or 2)
    end
    local function box(x, y, w, h, r, g, b, a)
        line(x, y, x + w, y, r, g, b, a)
        line(x + w, y, x + w, y + h, r, g, b, a)
        line(x + w, y + h, x, y + h, r, g, b, a)
        line(x, y + h, x, y, r, g, b, a)
    end

    if m == "world" then
        -- 3D primitives take a different renderer path than the 2D ones; if these
        -- appear and the 2D ones do not, the problem is the 2D path specifically.
        local p = player and player:GetWorldPos()
        if p then
            local a = { x = p.x, y = p.y, z = p.z + 1 }
            local b = { x = p.x + 3, y = p.y, z = p.z + 3 }
            System.DrawLine(a, b, 1, 0, 0, 1)
            System.DrawLabel({ x = p.x + 3, y = p.y, z = p.z + 3 }, 2, "DrawLabel works", 0, 1, 0, 1)
        end
        return
    end

    if m == "scale" then
        -- How small can one glyph get? Ladder of sizes against a 100px ruler.
        -- BLOCK is UTF-8 U+2588; the engine's debug font may not have it, so ASCII
        -- candidates are drawn beside it for comparison.
        local BLOCK = "\226\150\136"
        local glyphs = { { BLOCK, "block" }, { "#", "hash" }, { "8", "eight" },
                         { "M", "M" }, { ".", "dot" }, { "_", "under" } }
        local sizes  = { 0.25, 0.5, 1, 1.5, 2, 3, 4, 6, 8 }

        -- ruler: a tick every 10px, labelled every 100px, so glyph size is measurable
        local ry = 400
        for i = 0, 40 do
            local x = 600 + i * 10
            System.DrawText(x, ry, (i % 10 == 0) and "|" or ".", 2, 1, 1, 1, 1)
        end
        System.DrawText(600, ry - 40, "ruler: ticks 10px apart, bars every 100px",
            3, 1, 1, 1, 1)

        for gi, g in ipairs(glyphs) do
            local y = ry + 60 + (gi - 1) * 90
            System.DrawText(400, y, g[2], 3, 0.7, 0.7, 0.7, 1)
            for si, s in ipairs(sizes) do
                local x = 600 + (si - 1) * 90
                System.DrawText(x, y, g[1], s, 1, 0.85, 0.2, 1)
                System.DrawText(x, y + 34, tostring(s), 2, 0.4, 0.6, 1, 1)
            end
        end
        text(400, 320, "scale ladder - sizes 0.25 to 8. autoscale=" ..
            tostring(cvar("r_AuxGeomAutoScaleOver1080pWH")) ..
            "  (merc_ui_autoscale_off shrinks the font at 4K)")
        return
    end

    if m == "bitmap" then
        -- A real per-pixel raster: one DrawText per pixel. Measures both whether it
        -- looks like a bitmap and what it costs.
        local BLOCK = "\226\150\136"
        local g = self.UIT.pxGlyph or BLOCK
        local s = self.UIT.pxSize or 1
        local step = self.UIT.pxStep or 2
        local ox, oy = 700, 500
        local W, H = 48, 24
        local n = 0
        for y = 0, H - 1 do
            for x = 0, W - 1 do
                local dx, dy = (x - W / 2) / (W / 2), (y - H / 2) / (H / 2)
                local d = dx * dx + dy * dy
                if d < 1.0 then
                    System.DrawText(ox + x * step, oy + y * step, g, s, 0.5 + 0.5 * dx, 0.5 + 0.5 * dy, 1 - d, 1)
                    n = n + 1
                end
            end
        end
        self.UIT.pxCount = n
        text(ox, oy - 80, string.format(
            "bitmap: %d glyphs/frame at %.0f fps, size=%s step=%spx  (merc_ui_px <size> <step>)",
            n, self.UIT.fps or 0, tostring(s), tostring(step)))
        text(ox, oy - 30, "a filled ellipse means DrawText is a real plotter")
        return
    end

    if m == "space" then
        -- ONE line per candidate coordinate space, nothing else. Whichever colour shows up
        -- as a horizontal bar across the middle of the screen is the space Draw2DLine wants.
        -- If none of them do, Draw2DLine is not a screen-space primitive in this build.
        System.Draw2DLine(-0.6, 0.0, 0.6, 0.0, 1, 0, 0, 1)          -- red    NDC -1..1
        System.Draw2DLine(0.2, 0.5, 0.8, 0.5, 0, 1, 0, 1)           -- green  0..1
        System.Draw2DLine(20, 50, 80, 50, 0, 0.4, 1, 1)             -- blue   0..100
        System.Draw2DLine(160, 300, 640, 300, 1, 1, 0, 1)           -- yellow 800x600
        System.Draw2DLine(768, 1080, 3072, 1080, 1, 0, 1, 1)        -- purple 3840x2160
        text(100, 100, "space probe: red=NDC green=0..1 blue=0..100 yellow=800x600 purple=pixels")
        text(100, 160, "a horizontal bar across mid-screen names the winner; none = no 2D path")
        return
    end

    if m == "glyph" then
        -- DrawText is a CONFIRMED screen-pixel primitive. If a block glyph can be placed
        -- and coloured per call, then text is a pixel plotter and we do not need Draw2DLine.
        local ox, oy = 600, 600
        for i = 0, 31 do
            local f = i / 31
            System.DrawText(ox + i * 24, oy, "#", 4, f, 0.3, 1 - f, 1)
        end
        for i = 0, 20 do
            System.DrawText(ox + i * 24, oy + 60 + i * 12, "#", 4, 1, 0.85, 0.2, 1)
        end
        text(ox, oy - 70, "glyph mode: 32 coloured '#' across, then a diagonal")
        text(ox, oy - 20, "if these are coloured differently, DrawText takes r,g,b,a")
        return
    end

    if m == "raw" then
        -- control: raw pixels straight into Draw2DLine. This is what produced the
        -- "white pyramid in the world". Kept so the difference is demonstrable.
        System.Draw2DLine(400, 400, 1400, 400, 1, 1, 1, 1)
        System.Draw2DLine(400, 400, 400, 900, 1, 1, 1, 1)
        text(400, 340, "raw mode: pixels fed straight to Draw2DLine")
        return
    end

    if m == "pixels" then
        -- THE test. Individual one-pixel dots at exact screen coordinates.
        -- A 40x24 checkerboard at 4px pitch, then a 256px solid run, then a
        -- single-pixel diagonal. If this renders, we own every pixel on screen.
        local ox, oy = 400, 500
        for gy = 0, 23 do
            for gx = 0, 39 do
                if (gx + gy) % 2 == 0 then
                    dot(ox + gx * 4, oy + gy * 4, 1, 0.85, 0.2, 1)
                end
            end
        end
        for i = 0, 255 do
            dot(ox + i, oy + 130, i / 255, 0.2, 1 - i / 255, 1)
        end
        for i = 0, 200 do
            dot(ox + i, oy + 160 + i, 0.3, 1, 0.4, 1)
        end
        box(ox - 10, oy - 10, 40 * 4 + 20, 24 * 4 + 20, 1, 1, 1, 0.5)
        text(ox, oy - 60, "pixels: checkerboard + 256px gradient + 1px diagonal")
        return
    end

    if m == "graph" then
        local s = self.UIT.samples
        s[#s + 1] = 50 + 40 * math.sin(System.GetCurrTime() * 1.5)
        while #s > 120 do table.remove(s, 1) end
        local x0, y0, w, h = 400, 1200, 1200, 400
        line(x0, y0, x0 + w, y0, 1, 1, 1, 0.6)
        line(x0, y0 - h, x0, y0, 1, 1, 1, 0.6)
        for i = 2, #s do
            line(x0 + (i - 2) * (w / 120), y0 - (s[i - 1] / 100) * h,
                 x0 + (i - 1) * (w / 120), y0 - (s[i] / 100) * h, 0.85, 0.7, 0.3, 1)
        end
        text(x0, y0 - h - 50, "morale (sine) - " .. #s .. " samples")
        text(x0 - 60, y0 - 12, "0")
        text(x0 - 60, y0 - h - 12, "100")
        return
    end

    -- calib: one rectangle that should frame the screen exactly, drawn in pixels and
    -- converted to the normalised space Draw2DLine actually wants. DrawText labels sit
    -- at the same corners in raw pixels, so if the two line up, both spaces are settled.
    box(40, 40, VW - 80, VH - 80, 1, 0.2, 0.2, 1)
    line(40, 40, VW - 40, VH - 40, 0.2, 1, 0.2, 1)
    line(VW - 40, 40, 40, VH - 40, 0.2, 1, 0.2, 1)
    box(VW * 0.5 - 200, VH * 0.5 - 100, 400, 200, 0.3, 0.7, 1, 1)
    text(40, 10, "TOP LEFT 40,40 - the red box should hug the screen edge")
    text(VW * 0.5 - 190, VH * 0.5 - 20, "CENTRE " .. VW .. "x" .. VH)
    text(VW - 700, VH - 80, "BOTTOM RIGHT")
end

-- ============================================================================
-- text / html
-- ============================================================================

-- merc_ui_px <size> <step> [glyph]  - tune the bitmap raster
function mercenaries:UIPx(line)
    local s, st, g = string.match(tostring(line), "([%d%.]+)%s+([%d%.]+)%s*(%S*)")
    if not s then log("usage: merc_ui_px <size> <step> [glyph]   e.g. merc_ui_px 1 2"); return end
    self.UIT.pxSize = tonumber(s)
    self.UIT.pxStep = tonumber(st)
    if g and g ~= "" then self.UIT.pxGlyph = g end
    log(string.format("bitmap now size=%s step=%s glyph=%s",
        tostring(self.UIT.pxSize), tostring(self.UIT.pxStep), tostring(self.UIT.pxGlyph)))
end

-- The engine enlarges this font above 1080p. At 4K that is the difference between a
-- glyph you can shrink to a pixel and one that bottoms out fat.
function mercenaries:UIAutoScale(on)
    setcvar("r_AuxGeomAutoScaleOver1080pWH", on and 1 or 0)
    setcvar("r_AuxGeomFontAutoScaleMultiplierOver1080pWH", on and 0.8 or 0)
    log("font autoscale " .. (on and "ON" or "OFF") ..
        "  (now " .. tostring(cvar("r_AuxGeomAutoScaleOver1080pWH")) .. " / " ..
        tostring(cvar("r_AuxGeomFontAutoScaleMultiplierOver1080pWH")) .. ")")
end

function mercenaries:UIText()
    pcall(function() UIAction.CallFunction("hud", -1, "ShowNotification", "1/4 ShowNotification") end)
    pcall(function() UIAction.CallFunction("hud", -1, "ShowInfoText", "2/4 ShowInfoText", 5, 4000, true) end)
    pcall(function() UIAction.CallFunction("hud", -1, "ShowGameLog", 0, 0, "3/4 ShowGameLog") end)
    pcall(function() Game.SendInfoText("4/4 SendInfoText", false, 0, 4) end)
    log("fired four text channels")
end

function mercenaries:UIHtml(line)
    if line == nil or line == "" then
        line = "<font color='#c8a04a' size='28'><b>HTML</b></font> in a subtitle, " ..
               "<font color='#8a2020'>second colour</font>"
    end
    pcall(function() UIAction.CallFunction("hud", -1, "SetSubtitles", line, "UI test", false) end)
    pcall(function() UIAction.CallFunction("hud", -1, "ShowTutorial", "uit", line, 6000, false, 5, 0) end)
    log("sent: " .. line)
end

-- ============================================================================
-- keyboard overlay
-- ============================================================================

function mercenaries:UIKeys()
    local binds = {
        { "f6", "merc_ui_ov",      "toggle the overlay" },
        { "f7", "merc_ui_ov_next", "cycle the selected merc" },
        { "f8", "merc_ui_ov_cmd",  "issue a test order" },
        { "f9", "merc_ui_off",     "PANIC" },
    }
    for _, b in ipairs(binds) do
        pcall(function() System.ExecuteCommand("bind " .. b[1] .. " " .. b[2]) end)
        log(string.format("  %-4s %-18s %s", b[1], b[2], b[3]))
    end
end

function mercenaries:UIUnbind()
    for _, k in ipairs({ "f6", "f7", "f8", "f9" }) do
        pcall(function() System.ExecuteCommand("unbind " .. k) end)
    end
    log("tried to unbind F6-F9 (binds are session-only anyway)")
end

function mercenaries:UIOverlay()
    self.UIT.overlay = not self.UIT.overlay
    if self.UIT.overlay then
        self.UIT.sel = 1
        if not self.UIT.tracking then self:UITrack() end
        pcall(function()
            UIAction.CallFunction("hud", -1, "ShowInfoText",
                "COMMAND MODE  -  F7 cycle  -  F8 order  -  F6 exit", 9, 600000, true)
        end)
        log("overlay ON")
    else
        if self.UIT.tracking then self:UITrack() end
        pcall(function() UIAction.CallFunction("hud", -1, "ShowInfoText", "", 9, 1, false) end)
        log("overlay OFF")
    end
end

function mercenaries:UIOverlayNext()
    local n = 0
    for _ in pairs(self.ActiveMercs or {}) do n = n + 1 end
    if n < 1 then log("no mercs to select"); return end
    self.UIT.sel = (self.UIT.sel % n) + 1
    log("selection -> " .. self.UIT.sel)
end

function mercenaries:UIOverlayCmd()
    pcall(function()
        UIAction.CallFunction("hud", -1, "ShowNotification", "order issued to slot " .. tostring(self.UIT.sel))
    end)
end

-- ============================================================================
-- panic
-- ============================================================================

function mercenaries:UIOff()
    self.UIT.tracking = false
    self.UIT.overlay  = false
    if self.UIT.drawing then
        self.UIT.drawing = false
        if self.UIT.drawEnt then
            pcall(function() System.RemoveEntity(self.UIT.drawEnt) end)
            self.UIT.drawEnt = nil
        end
    end
    self:UIClearBubbles()
    pcall(function() UIAction.CallFunction("hud", -1, "ShowInfoText", "", 9, 1, false) end)
    pcall(function() UIAction.CallFunction("hud", -1, "SetSubtitles", "", "", false) end)
    pcall(function() UIAction.CallFunction("Menu", self.UIT.PID, "ClearAll") end)
    pcall(function() UIAction.HideElement("Menu", self.UIT.PID) end)
    pcall(function() UIAction.HideElement("ApseModalDialog", 0) end)
    pcall(function() UIAction.HideElement("AlchemyBook", 0) end)
    pcall(function() UIAction.HideElement("LockPicking", 0) end)
    pcall(function() UIAction.SetVisible("hud", -1, "MasterSwitch", true) end)
    pcall(function() UIAction.ShowElement("hud", 0) end)
    pcall(function() ActionMapManager.EnableActionMap("menu", false) end)
    log("everything reset - HUD restored, menu action map off")
end

function mercenaries:UIHelp()
    log("==== merc UI test bench (docs/ui.md) ====")
    log("  merc_ui_probe        capabilities + the cvars that gate drawing")
    log("  merc_ui_menu         interactive screen (WORKS)")
    log("  merc_ui_modal        modal dialog;  merc_ui_modal_close dismisses it")
    log("  -- can we draw pixels? --")
    log("  merc_ui_draw calib   a box that should hug the screen edge, in pixels")
    log("  merc_ui_draw pixels  checkerboard + gradient + 1px diagonal - the real test")
    log("  merc_ui_draw graph   live line chart")
    log("  merc_ui_draw world   3D DrawLine/DrawLabel (different renderer path)")
    log("  merc_ui_draw raw     control: raw pixels into Draw2DLine (the white pyramid)")
    log("  merc_ui_draw         (no argument) turns it off")
    log("  -- can we move flash sprites? --")
    log("  merc_ui_lock         show LockPicking and dump its 6 clip positions")
    log("  merc_ui_lockpos <clip> <x> <y>   move one of them")
    log("  merc_ui_bubbles      the 16 hud text sprites, re-applied every tick")
    log("  merc_ui_gpos <n>     read a bubble position back")
    log("  merc_ui_proj         calibrate ProjectToScreen (run before merc_ui_track)")
    log("  merc_ui_stage <w h>  set the assumed stage size")
    log("  merc_ui_track        label every merc (needs a squad)")
    log("  -- misc --")
    log("  merc_ui_text / merc_ui_html <s> / merc_ui_keys / merc_ui_ov")
    log("  merc_ui_off          PANIC")
end

mercenaries:DevCommand("merc_ui",            "mercenaries:UIHelp()",              "List the UI test commands")
mercenaries:DevCommand("merc_ui_probe",      "mercenaries:UIProbe()",             "Capabilities and the cvars that gate drawing")
mercenaries:DevCommand("merc_ui_menu",       "mercenaries:UIMenu()",              "Open the interactive test screen")
mercenaries:DevCommand("merc_ui_modal",      "mercenaries:UIModal()",             "Open ApseModalDialog with arbitrary text")
mercenaries:DevCommand("merc_ui_modal_close","mercenaries:UIModalClose()",        "Dismiss the modal (tries every close function)")
mercenaries:DevCommand("merc_ui_lock",       "mercenaries:UILock('%line')",     "Show LockPicking and dump its clip positions; arg 'off' hides it")
mercenaries:DevCommand("merc_ui_lockpos",    "mercenaries:UILockPos('%line')",  "Move a LockPicking clip: <clipName> <x> <y>")
mercenaries:DevCommand("merc_ui_text",       "mercenaries:UIText()",              "Fire all four on-screen text channels")
mercenaries:DevCommand("merc_ui_html",       "mercenaries:UIHtml('%line')",     "Send HTML to the subtitle and tutorial")
mercenaries:DevCommand("merc_ui_bubbles",    "mercenaries:UIBubbles()",           "Place 8 hud bubbles and keep re-applying them")
mercenaries:DevCommand("merc_ui_gpos",       "mercenaries:UIGetPos('%line')",   "Read a bubble's position back")
mercenaries:DevCommand("merc_ui_proj",       "mercenaries:UIProj()",              "Calibrate ProjectToScreen: project a point dead ahead of the camera")
mercenaries:DevCommand("merc_ui_stage",      "mercenaries:UIStage('%line')",    "Set the assumed flash stage size: <w> <h>")
mercenaries:DevCommand("merc_ui_track",      "mercenaries:UITrack()",             "Toggle world-projected labels on every merc")
-- One command per mode, argument baked in. Passing the mode as an argument goes through
-- %line, which expands to the whole typed line and loses the quotes - the engine then
-- tries to run `mercenaries:UIDraw(merc_ui_draw pixels)` and dies with a syntax error
-- that only the dev build reports. See docs/console.md.
mercenaries:DevCommand("merc_ui_draw",        "mercenaries:UIDraw(nil)",          "Immediate-mode draw OFF")
mercenaries:DevCommand("merc_ui_draw_calib",  "mercenaries:UIDraw(\"calib\")",    "Draw: a box that should hug the screen edge")
mercenaries:DevCommand("merc_ui_draw_pixels", "mercenaries:UIDraw(\"pixels\")",   "Draw: checkerboard + gradient + 1px diagonal - the real pixel test")
mercenaries:DevCommand("merc_ui_draw_graph",  "mercenaries:UIDraw(\"graph\")",    "Draw: live line chart")
mercenaries:DevCommand("merc_ui_draw_world",  "mercenaries:UIDraw(\"world\")",    "Draw: 3D DrawLine/DrawLabel (different renderer path)")
mercenaries:DevCommand("merc_ui_draw_raw",    "mercenaries:UIDraw(\"raw\")",      "Draw: control - raw pixels into Draw2DLine (the white pyramid)")
mercenaries:DevCommand("merc_ui_draw_space",  "mercenaries:UIDraw(\"space\")",    "Draw: one line per candidate coordinate space - settles Draw2DLine")
mercenaries:DevCommand("merc_ui_draw_glyph",  "mercenaries:UIDraw(\"glyph\")",    "Draw: coloured block glyphs via DrawText - the pixel-plotter fallback")
mercenaries:DevCommand("merc_ui_draw_scale",  "mercenaries:UIDraw(\"scale\")",    "Draw: 6 glyphs x 9 sizes against a 10px ruler - how small can a glyph get")
mercenaries:DevCommand("merc_ui_draw_bitmap", "mercenaries:UIDraw(\"bitmap\")",   "Draw: per-pixel raster of an ellipse, with glyph count and fps")
mercenaries:DevCommand("merc_ui_px",          "mercenaries:UIPx('%line')",        "Tune the raster: <size> <step> [glyph], e.g. merc_ui_px 1 2")
mercenaries:DevCommand("merc_ui_autoscale_off", "mercenaries:UIAutoScale(false)", "Disable the 4K debug-font enlargement (makes glyphs smaller)")
mercenaries:DevCommand("merc_ui_autoscale_on",  "mercenaries:UIAutoScale(true)",  "Restore the 4K debug-font enlargement")
mercenaries:DevCommand("merc_ui_keys",       "mercenaries:UIKeys()",              "Bind F6-F9 to the keyboard overlay")
mercenaries:DevCommand("merc_ui_unbind",     "mercenaries:UIUnbind()",            "Remove the F6-F9 bindings")
mercenaries:DevCommand("merc_ui_ov",         "mercenaries:UIOverlay()",           "Toggle the keyboard-driven command overlay")
mercenaries:DevCommand("merc_ui_ov_next",    "mercenaries:UIOverlayNext()",       "Overlay: cycle the selected merc")
mercenaries:DevCommand("merc_ui_ov_cmd",     "mercenaries:UIOverlayCmd()",        "Overlay: issue a test order")
mercenaries:DevCommand("merc_ui_off",        "mercenaries:UIOff()",               "PANIC: restore the HUD and close every test screen")

-- ============================================================================
-- merc_ui_elem - does a NEW UIElements XML register?
-- The disassembly says the engine scans Libs/UI/UIElements/*.xml through CryPak and
-- keys elements by the XML's name= attribute at runtime (CFlashUI::vf11, RVA 0x563AE0),
-- so a mod-supplied file should work. This asks the running engine.
-- ============================================================================

function mercenaries:UIElemProbe(line)
    local name = string.match(string.gsub(tostring(line), "[" .. string.char(34) .. string.char(39) .. "]", ""), "%S+") or "MercTest"
    log("==== element probe: " .. name .. " ====")

    -- a registered element answers GetPos on a declared MovieClip; an unknown one cannot
    local function known(el, mc)
        local ok, p = pcall(function() return UIAction.GetPos(el, 0, mc) end)
        return ok and p ~= nil, p
    end

    local okV, pv = known("LockPicking", "Cursor")
    log(string.format("  vanilla LockPicking.Cursor  -> %s%s", tostring(okV),
        pv and string.format("  (%s,%s)", tostring(pv.x), tostring(pv.y)) or ""))

    local okM, pm = known(name, "Cursor")
    log(string.format("  %s.Cursor  -> %s%s", name, tostring(okM),
        pm and string.format("  (%s,%s)", tostring(pm.x), tostring(pm.y)) or ""))

    local okJ = known("DefinitelyNotAnElement", "Cursor")
    log("  control (bogus element name) -> " .. tostring(okJ))

    if okM and not okJ then
        log("  RESULT: the mod-supplied element REGISTERED - a mod can add its own screen")
    elseif okJ then
        log("  RESULT: inconclusive - the bogus name answered too, so GetPos is not a valid test")
    else
        log("  RESULT: not registered. Check the pak actually carries")
        log("          Libs/UI/UIElements/" .. name .. ".xml, then retry after a restart")
    end
end

function mercenaries:UIElemShow(line)
    local name = string.match(string.gsub(tostring(line), "[" .. string.char(34) .. string.char(39) .. "]", ""), "%S+") or "MercTest"
    pcall(function() UIAction.ShowElement(name, 0) end)
    pcall(function() UIAction.SetVisible(name, 0, "LockPick", true) end)
    pcall(function() UIAction.SetPos(name, 0, "LockPick", { x = 900, y = 500, z = 0 }) end)
    log("ShowElement(" .. name .. ", 0) sent - a lockpick should appear mid-screen")
end

mercenaries:DevCommand("merc_ui_elem",      "mercenaries:UIElemProbe('%line')", "Does a mod-added UIElements XML register? <name>, default MercTest")
mercenaries:DevCommand("merc_ui_elem_show", "mercenaries:UIElemShow('%line')",  "Show a mod-added element: <name>, default MercTest")
