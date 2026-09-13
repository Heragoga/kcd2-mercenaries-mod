-- Limits test for a MOD-SUPPLIED Scaleform element.
--
-- Everything before this drove vanilla movies. This drives ours: tools/make_swf.py writes
-- data/libs/UI/MercUI.swf (48 named sprites, zero ActionScript) and the matching
-- data/libs/UI/UIElements/MercUI.xml. If this works, a mod owns real vector rectangles at
-- arbitrary position, size, rotation and opacity - the primitive the ASCII-underscore panel
-- hack existed only because we lacked. See docs/ui.md.
--
-- Two things the disassembly says must hold, and this checks:
--   * wh_gfx_useSWF must be 1, or the loader never tries the .swf at all (RVA 0x0088FC39)
--   * the element registers from the XML's name= attribute, scanned at CFlashUI init, so
--     a NEW element needs a game restart - it will not appear live
--
--   merc_swf            status + what to run
--   merc_swf_on/off     show / hide the element
--   merc_swf_grid       position every clip           (SetPos)
--   merc_swf_bars       a bar chart                   (SetScale)
--   merc_swf_spin       rotate them                   (SetRotation)
--   merc_swf_fade       opacity ramp                  (SetAlpha)
--   merc_swf_stress     animate all 48 per frame      (cost)
--   merc_swf_probe      read back a clip's transform  (does the engine see our movie?)

mercenaries.FrameHooks = mercenaries.FrameHooks or {}

mercenaries.SWF = mercenaries.SWF or {
    element = "MercUI",
    n       = 48,
    on      = false,
    ent     = nil,
    t       = 0,
    fps     = 0,
}

local SWF = mercenaries.SWF
local function log(s) System.LogAlways("[MercSWF] " .. tostring(s)) end
local function clip(i) return string.format("mc_%02d", i) end

-- %line reaches Lua with its surrounding quotes intact (see docs/console.md), so a bare
-- "%S+" capture picks up the quote characters and the name matches no element at all.
local QUOTES = string.char(34) .. string.char(39)     -- " and '
local function unquote(s)
    return (string.gsub(tostring(s or ""), "[" .. QUOTES .. "]", ""))
end

local function cvar(n)
    local v
    pcall(function() v = System.GetCVar(n) end)
    return v
end

local function setpos(i, x, y)
    pcall(function() UIAction.SetPos(SWF.element, 0, clip(i), { x = x, y = y, z = 0 }) end)
end

-- MEASURED: SetScale and SetAlpha are in PERCENT, not multipliers - Flash's _xscale/_yscale
-- are 100 = natural size and _alpha is 0..100. An untouched clip reads back as
-- scale=(100,100) alpha=100. Passing 1 means ONE PERCENT: a hundredth-size, 1%-opaque clip,
-- which looks exactly like the UI vanishing a moment after it is laid out.
-- These helpers take sane multipliers (1.0 = natural, alpha 0..1) and convert.
local function setscale(i, sx, sy)
    pcall(function()
        UIAction.SetScale(SWF.element, 0, clip(i), { x = sx * 100, y = sy * 100, z = 100 })
    end)
end

local function setalpha(i, a)
    pcall(function() UIAction.SetAlpha(SWF.element, 0, clip(i), a * 100) end)
end

local function setrot(i, deg)
    pcall(function() UIAction.SetRotation(SWF.element, 0, clip(i), { x = 0, y = 0, z = deg }) end)
end

local function setvis(i, v)
    pcall(function() UIAction.SetVisible(SWF.element, 0, clip(i), v) end)
end

-- ============================================================================

function mercenaries:SwfStatus()
    log("==== mod-supplied element: " .. SWF.element .. " ====")
    log("  wh_gfx_useSWF = " .. tostring(cvar("wh_gfx_useSWF"))
        .. "   (must be 1, else the .swf is never tried)")
    log("  gfx_uiaction_folder = " .. tostring(cvar("gfx_uiaction_folder")))
    log("  shown = " .. tostring(SWF.on))
    log("  run: merc_swf_on, then merc_swf_grid / _bars / _spin / _fade / _stress")
    log("  nothing visible? the element list is built at CFlashUI init - RESTART the game")
    log("  after deploying, and make sure no MercUI.gfx exists anywhere in the VFS.")
end

function mercenaries:SwfOn()
    -- The cvar is read INSIDE the movie loader, so setting it here is too late for a movie
    -- that already loaded. UnloadElement + ReloadElement forces the loader to run again with
    -- the cvar now set - that is the only way to pick up the .swf without a restart.
    local before = cvar("wh_gfx_useSWF")
    pcall(function() System.SetCVar("wh_gfx_useSWF", 1) end)
    log("wh_gfx_useSWF " .. tostring(before) .. " -> " .. tostring(cvar("wh_gfx_useSWF")))

    pcall(function() UIAction.UnloadElement(SWF.element, -1) end)
    pcall(function() UIAction.ReloadElement(SWF.element, -1) end)
    log("unloaded + reloaded the element so the loader re-runs with the cvar set")

    local ok, err = pcall(function() UIAction.ShowElement(SWF.element, 0) end)
    SWF.on = true
    log("ShowElement(" .. SWF.element .. ", 0) -> " .. (ok and "no error" or tostring(err)))
    log("layout deferred - the movie is built on first display, so transforms sent in this")
    log("same call would hit clips that do not exist yet and silently no-op")
    Script.SetTimerForFunction(600, "mercenaries.SwfApplyDeferred")
end

mercenaries.SwfApplyDeferred = function()
    mercenaries:SwfGrid()
end

function mercenaries:SwfOff()
    SWF.on = false
    mercenaries.FrameHooks["swfstress"] = nil
    if SWF.ent then
        pcall(function() System.RemoveEntity(SWF.ent) end)
        SWF.ent = nil
    end
    for i = 0, SWF.n - 1 do setvis(i, false) end
    pcall(function() UIAction.HideElement(SWF.element, 0) end)
    log("hidden")
end

-- SetPos: lay every clip out on a grid. The clip art is 100x20 at authoring size.
function mercenaries:SwfGrid()
    local cols, x0, y0, dx, dy = 8, 120, 120, 130, 44
    for i = 0, SWF.n - 1 do
        local c, r = i % cols, math.floor(i / cols)
        setvis(i, true)
        setscale(i, 1, 1)
        setrot(i, 0)
        setalpha(i, 1)
        setpos(i, x0 + c * dx, y0 + r * dy)
    end
    log("grid: " .. SWF.n .. " clips placed on an 8-wide grid from (120,120)")
    log("  if they land somewhere else, the stage space is not 1:1 with pixels - compare")
    log("  against merc_swf_probe, which reads a position back")
end

-- SetScale: a bar chart, the thing the ASCII gauge was faking
function mercenaries:SwfBars()
    for i = 0, SWF.n - 1 do
        local h = 0.4 + 3.6 * (0.5 + 0.5 * math.sin(i * 0.4))
        setvis(i, true)
        setrot(i, 0)
        setalpha(i, 1)
        setscale(i, 0.6, h)
        setpos(i, 120 + i * 22, 600)
    end
    log("bars: SetScale on each clip, y from 0.4x to 4.0x - a real bar chart")
end

function mercenaries:SwfSpin()
    for i = 0, SWF.n - 1 do
        setvis(i, true)
        setalpha(i, 1)
        setscale(i, 1, 1)
        setrot(i, (i * 360 / SWF.n))
        setpos(i, 640 + 260 * math.cos(i * 2 * math.pi / SWF.n),
                  400 + 260 * math.sin(i * 2 * math.pi / SWF.n))
    end
    log("spin: SetRotation + a circular layout")
end

function mercenaries:SwfFade()
    for i = 0, SWF.n - 1 do
        setvis(i, true)
        setalpha(i, i / (SWF.n - 1))
    end
    log("fade: SetAlpha ramp 0 -> 1 across the clips (leaves the current layout)")
end

-- Cost: drive every clip every frame and watch the framerate.
function mercenaries:SwfStress()
    if mercenaries.FrameHooks["swfstress"] then
        mercenaries.FrameHooks["swfstress"] = nil
        if SWF.ent then
            pcall(function() System.RemoveEntity(SWF.ent) end)
            SWF.ent = nil
        end
        log("stress off")
        return
    end

    local p
    pcall(function() p = player and player:GetWorldPos() end)
    if not p then log("no player position - are you in a level?"); return end
    local e
    local ok = pcall(function()
        e = System.SpawnEntity({
            class = "mercenaries_UIDraw",
            name  = "merc_swfstress_" .. tostring(math.random(100000, 999999)),
            position = { x = p.x, y = p.y, z = p.z },
        })
    end)
    if not (ok and e) then log("could not spawn the frame entity"); return end
    SWF.ent = e.id

    mercenaries.FrameHooks["swfstress"] = function(dt)
        if dt and dt > 0 then
            SWF.fps = (SWF.fps > 0) and (SWF.fps * 0.95 + (1 / dt) * 0.05) or (1 / dt)
        end
        SWF.t = SWF.t + (dt or 0)
        local t = SWF.t
        for i = 0, SWF.n - 1 do
            local a = t * 1.2 + i * 0.3
            setpos(i, 640 + 300 * math.cos(a), 400 + 220 * math.sin(a * 1.3))
            setrot(i, (a * 60) % 360)
        end
        if math.floor(t) ~= math.floor(t - (dt or 0)) then
            System.LogAlways(string.format(
                "[MercSWF] stress: %d clips x 2 calls/frame at %.0f fps", SWF.n, SWF.fps))
        end
    end
    log("stress ON - " .. SWF.n .. " clips moved and rotated every frame; watch the fps in the log")
    log("  merc_swf_stress again to stop")
end

-- Does the engine actually know our movie? A clip we set and read back proves it.
function mercenaries:SwfProbe()
    log("==== transform read-back ====")
    setpos(3, 700, 300)
    setscale(3, 2, 3)
    setrot(3, 45)
    setalpha(3, 0.5)

    local p, s, r, a, v
    pcall(function() p = UIAction.GetPos(SWF.element, 0, clip(3)) end)
    pcall(function() s = UIAction.GetScale(SWF.element, 0, clip(3)) end)
    pcall(function() r = UIAction.GetRotation(SWF.element, 0, clip(3)) end)
    pcall(function() a = UIAction.GetAlpha(SWF.element, 0, clip(3)) end)
    pcall(function() v = UIAction.IsVisible(SWF.element, 0, clip(3)) end)

    local function fmt(x) return x and string.format("(%s,%s,%s)",
        tostring(x.x), tostring(x.y), tostring(x.z)) or "nil" end
    log("  set pos(700,300) scale(2,3) rot(45) alpha(0.5) on mc_03")
    log("  GetPos      -> " .. fmt(p))
    log("  GetScale    -> " .. fmt(s))
    log("  GetRotation -> " .. fmt(r))
    log("  GetAlpha    -> " .. tostring(a))
    log("  IsVisible   -> " .. tostring(v))
    log("  A non-zero read-back that MATCHES what was set means the engine is talking to")
    log("  our movie. GetPos alone proves nothing - it answers (0,0) for a bogus element.")

    -- control: the same calls against a name no XML declares
    local bp
    pcall(function()
        UIAction.SetPos("NoSuchElementAnywhere", 0, "mc_03", { x = 700, y = 300, z = 0 })
        bp = UIAction.GetPos("NoSuchElementAnywhere", 0, "mc_03")
    end)
    log("  control (undeclared element) -> " .. fmt(bp) .. "   <- should NOT match (700,300)")
end

mercenaries:DevCommand("merc_swf",        "mercenaries:SwfStatus()", "Mod-supplied Scaleform element: status")
mercenaries:DevCommand("merc_swf_on",     "mercenaries:SwfOn()",     "Show our own .swf element and lay it out")
mercenaries:DevCommand("merc_swf_off",    "mercenaries:SwfOff()",    "Hide it")
mercenaries:DevCommand("merc_swf_grid",   "mercenaries:SwfGrid()",   "SetPos: 48 clips on a grid")
mercenaries:DevCommand("merc_swf_bars",   "mercenaries:SwfBars()",   "SetScale: a real bar chart")
mercenaries:DevCommand("merc_swf_spin",   "mercenaries:SwfSpin()",   "SetRotation: rotated clips in a circle")
mercenaries:DevCommand("merc_swf_fade",   "mercenaries:SwfFade()",   "SetAlpha: an opacity ramp")
mercenaries:DevCommand("merc_swf_stress", "mercenaries:SwfStress()", "Animate all 48 every frame and report fps")
mercenaries:DevCommand("merc_swf_probe",  "mercenaries:SwfProbe()",  "Set then read back a transform, with a control")

-- ============================================================================
-- Bisect: which SWF does Scaleform actually accept?
-- The engine opened MercUI.swf (kcd.log: CryGFxFileOpener::OpenFile 'Libs/UI//MercUI.swf')
-- and logged no complaint, yet drew nothing - so the file is found but its CONTENT is
-- rejected or renders empty. These variants differ by one thing each.
-- A reload does NOT re-read the file (the movie is cached), but each variant is a SEPARATE
-- element, so all of them can be tried in one session.
-- ============================================================================

function mercenaries:SwfUse(line)
    local name = string.match(unquote(line), "%S+")
    if not name then
        log("usage: merc_swf_use <MercUI|MercUIb|MercUIc>"); return
    end
    SWF.element = name
    SWF.n = (name == "MercUIc") and 1 or 48
    log("target element is now " .. name .. " (" .. SWF.n .. " clips) - run merc_swf_on")
end

function mercenaries:SwfBisect()
    log("==== which movie does Scaleform accept? ====")
    log("  Each is a separate element, so no restart is needed between them.")
    log("")
    log("  1. merc_ui_elem_show          MercTest -> VANILLA LockPicking.gfx")
    log("     THE control. A lockpick on screen means our element+XML pipeline renders,")
    log("     and the only remaining suspect is the .swf we generate.")
    log("")
    log("  2. merc_swf_use MercUIc")
    log("     merc_swf_on                ONE 600x300 rectangle, v8 + FileAttributes")
    log("     The minimal case - rules out sprite count and naming.")
    log("")
    log("  3. merc_swf_use MercUI")
    log("     merc_swf_on                48 clips, v8 + FileAttributes (was missing before)")
    log("")
    log("  4. merc_swf_use MercUIb")
    log("     merc_swf_on                48 clips, SWF v6, no FileAttributes")
    log("     SWF 6 predates the FileAttributes requirement entirely.")
    log("")
    log("  After each, check kcd.log for a new CryGFxFileOpener::OpenFile line naming the")
    log("  file - that proves the engine read THAT variant rather than a cached movie.")
end

mercenaries:DevCommand("merc_swf_use",    "mercenaries:SwfUse('%line')", "Target a different generated element: <MercUI|MercUIb|MercUIc>")
mercenaries:DevCommand("merc_swf_bisect", "mercenaries:SwfBisect()",     "Print the bisect order for finding what Scaleform accepts")

-- ============================================================================
-- Why is nothing drawing? Two blunt instruments.
--
-- The engine's own UI debug overlay is the one tool that reports what the FlashUI
-- subsystem thinks is loaded, rather than us inferring it from read-backs:
--   gfx_debugdraw  0=Disabled 1=UIElements 2=UIActions 4=UIActions 12=UIStack per UI FG
--   gfx_draw       "Draw UI Elements"
-- ============================================================================

function mercenaries:SwfDebug(line)
    local v = tonumber(string.match(unquote(line), "%d+") or "") or 1
    pcall(function() System.SetCVar("gfx_debugdraw", v) end)
    pcall(function() System.SetCVar("gfx_draw", 1) end)
    log("gfx_debugdraw = " .. tostring(cvar("gfx_debugdraw"))
        .. "   gfx_draw = " .. tostring(cvar("gfx_draw")))
    log("  1 lists UIElements. If " .. SWF.element .. " is NOT in that list, the element")
    log("  never loaded a movie. If it IS listed, the movie loaded and the problem is")
    log("  the content or where it is drawn. merc_swf_debug 0 turns it off.")
end

-- Impossible to miss: one clip, screen centre, 50x scale, full alpha, on top.
function mercenaries:SwfHuge()
    pcall(function() UIAction.ShowElement(SWF.element, 0) end)
    local c = clip(0)
    pcall(function() UIAction.SetVisible(SWF.element, 0, c, true) end)
    pcall(function() UIAction.SetAlpha(SWF.element, 0, c, 100) end)
    pcall(function() UIAction.SetRotation(SWF.element, 0, c, { x = 0, y = 0, z = 0 }) end)
    pcall(function() UIAction.SetScale(SWF.element, 0, c, { x = 5000, y = 5000, z = 100 }) end)
    pcall(function() UIAction.SetPos(SWF.element, 0, c, { x = 0, y = 0, z = 0 }) end)
    log("mc_00 of " .. SWF.element .. " at (0,0), scale 50x, alpha 1.")
    log("  A 100x20 rect at 50x is 5000x1000 - if the movie renders at all, this covers")
    log("  the screen. Still nothing means the movie is not being drawn, not mispositioned.")
end

mercenaries:DevCommand("merc_swf_debug", "mercenaries:SwfDebug('%line')", "Engine UI debug overlay: <0|1|2> - lists what FlashUI has loaded")
mercenaries:DevCommand("merc_swf_huge",  "mercenaries:SwfHuge()",        "One clip at 50x scale over the whole screen - rules out positioning")

-- ============================================================================
-- CONFIRMED: our own SWF renders. The 48 rectangles drew at their AUTHORED positions,
-- which told us two things at once:
--   * the stage is 1280x720 and is letterboxed to the backbuffer, so on a 3840x2160
--     screen everything is scaled 3x - SetPos coordinates are STAGE units, not pixels
--   * transforms issued in the same call as ShowElement no-op, because the movie has not
--     been built yet. Defer them a frame or two.
-- ============================================================================

function mercenaries:SwfStage()
    local vp
    pcall(function() vp = System.GetViewport() end)
    local w = (vp and tonumber(vp.width)) or 1920
    local h = (vp and tonumber(vp.height)) or 1080
    log("viewport " .. w .. "x" .. h .. "   authored stage 1280x720   scale "
        .. string.format("%.2f", h / 720))
    log("  SetPos takes STAGE units: (640,360) is screen centre, (1280,720) the far corner")
end

-- Re-apply the layout now that the movie certainly exists.
function mercenaries:SwfApply()
    self:SwfGrid()
    log("re-applied. If the clips MOVED this time, the only bug left was call ordering.")
end

mercenaries:DevCommand("merc_swf_apply", "mercenaries:SwfApply()", "Re-apply the layout now the movie exists (tests the deferral theory)")
mercenaries:DevCommand("merc_swf_stage", "mercenaries:SwfStage()", "Report the stage-to-screen scale")

-- ============================================================================
-- One clip, one place, everything else hidden. No follow-up call to overwrite it.
-- The grid/huge tests kept stepping on each other: merc_swf_huge scales mc_00 to 50x
-- (5000x1000 stage units - it overflows the 1280x720 stage and reads as a wedge), then
-- merc_swf_on's layout resets the scale a moment later, so each looked like a failure of
-- the other. This does exactly one thing and then stops.
-- ============================================================================

function mercenaries:SwfOne(line)
    local a = unquote(line)
    local x = tonumber(string.match(a, "(%-?%d+)%s+%-?%d+") or "") or 640
    local y = tonumber(string.match(a, "%-?%d+%s+(%-?%d+)") or "") or 360

    for i = 1, SWF.n - 1 do setvis(i, false) end

    local c = clip(0)
    pcall(function() UIAction.SetVisible(SWF.element, 0, c, true) end)
    pcall(function() UIAction.SetAlpha(SWF.element, 0, c, 100) end)
    pcall(function() UIAction.SetRotation(SWF.element, 0, c, { x = 0, y = 0, z = 0 }) end)
    pcall(function() UIAction.SetScale(SWF.element, 0, c, { x = 400, y = 400, z = 100 }) end)
    pcall(function() UIAction.SetPos(SWF.element, 0, c, { x = x, y = y, z = 0 }) end)

    log(string.format("mc_00 only: pos(%d,%d) scale 4x, everything else hidden", x, y))
    log("  stage is 1280x720, so (640,360) is screen CENTRE and (0,0) the top-left corner")
    log("  a 100x20 rect at 4x = 400x80 stage units - big, but still on the stage")
    log("  run merc_swf_one 100 100 then merc_swf_one 1100 600 - if the block MOVES between")
    log("  those two, SetPos works and the layout maths is all that is left")
end

mercenaries:DevCommand("merc_swf_one", "mercenaries:SwfOne('%line')", "Show ONE clip at a stage position: <x> <y> (default 640 360)")

-- ============================================================================
-- WHAT changes at the one-second mark? Poll the element and log it, instead of guessing.
-- Three possible culprits look identical on screen but differ completely here:
--   * transforms revert to the authored matrix   -> the movie's timeline re-ran
--   * IsVisible flips to false                   -> something hid the clips
--   * reads start returning nil                  -> the engine unloaded the element
-- ============================================================================

mercenaries.SWFW = mercenaries.SWFW or { on = false, n = 0 }

function mercenaries:SwfWatch()
    local W = self.SWFW
    W.on = not W.on
    if not W.on then log("watch off"); return end
    W.n = 0
    log("watch ON - sampling mc_00 every 250ms for 6s. Run merc_swf_grid now.")
    mercenaries.SwfWatchTick()
end

mercenaries.SwfWatchTick = function()
    local W = mercenaries.SWFW
    if not W.on then return end
    W.n = W.n + 1

    local c = string.format("mc_%02d", 0)
    local p, s, v, a
    pcall(function() p = UIAction.GetPos(SWF.element, 0, c) end)
    pcall(function() s = UIAction.GetScale(SWF.element, 0, c) end)
    pcall(function() v = UIAction.IsVisible(SWF.element, 0, c) end)
    pcall(function() a = UIAction.GetAlpha(SWF.element, 0, c) end)

    System.LogAlways(string.format(
        "[MercSWF] t=%4.2fs  pos=%s  scale=%s  vis=%s  alpha=%s",
        W.n * 0.25,
        p and string.format("(%.0f,%.0f)", p.x, p.y) or "nil",
        s and string.format("(%.2f,%.2f)", s.x, s.y) or "nil",
        tostring(v), tostring(a)))

    if W.n >= 24 then
        W.on = false
        System.LogAlways("[MercSWF] watch finished. pos reverting to the authored spot means")
        System.LogAlways("[MercSWF] the timeline re-ran; vis=false means something hid it;")
        System.LogAlways("[MercSWF] nil means the element went away entirely.")
        return
    end
    Script.SetTimerForFunction(250, "mercenaries.SwfWatchTick")
end

-- Workaround AND diagnosis in one: re-assert the layout every frame. If it stays on screen
-- while pinned, whatever resets it is periodic and can simply be out-written.
function mercenaries:SwfPin()
    if mercenaries.FrameHooks["swfpin"] then
        mercenaries.FrameHooks["swfpin"] = nil
        if SWF.ent then
            pcall(function() System.RemoveEntity(SWF.ent) end)
            SWF.ent = nil
        end
        log("pin off")
        return
    end
    local p
    pcall(function() p = player and player:GetWorldPos() end)
    if not p then log("no player position"); return end
    local e
    local ok = pcall(function()
        e = System.SpawnEntity({ class = "mercenaries_UIDraw",
            name = "merc_swfpin_" .. tostring(math.random(100000, 999999)),
            position = { x = p.x, y = p.y, z = p.z } })
    end)
    if not (ok and e) then log("could not spawn the frame entity"); return end
    SWF.ent = e.id

    local cols, x0, y0, dx, dy = 8, 120, 120, 130, 44
    mercenaries.FrameHooks["swfpin"] = function()
        for i = 0, SWF.n - 1 do
            local cc, rr = i % cols, math.floor(i / cols)
            setvis(i, true)
            setalpha(i, 1)
            setscale(i, 1, 1)
            setpos(i, x0 + cc * dx, y0 + rr * dy)
        end
    end
    log("pin ON - the whole layout re-asserted every frame. If it now STAYS, the reset is")
    log("  periodic and we can out-write it; merc_swf_pin again to stop.")
end

mercenaries:DevCommand("merc_swf_watch", "mercenaries:SwfWatch()", "Log mc_00's pos/scale/visibility every 250ms for 6s")
mercenaries:DevCommand("merc_swf_pin",   "mercenaries:SwfPin()",   "Re-assert the layout every frame - workaround and diagnosis")

-- ============================================================================
-- Images. The bitmap is EMBEDDED in the swf (DefineBitsLossless2 + a bitmap-filled shape),
-- not fetched at runtime, so the movie stays ActionScript-free and the image clip is driven
-- from Lua exactly like the rectangles - same SetPos/SetScale/SetRotation/SetAlpha.
--
-- The test image is deliberately legible: a RED square marks its top-left, a BLUE square its
-- bottom-right, and alpha ramps left (transparent) to right (opaque). Wrong channel order,
-- flipped rows or broken alpha are all obvious at a glance rather than subtle.
-- ============================================================================

mercenaries.IMG = mercenaries.IMG or { element = "MercImg", clip = "mc_img" }

local function imgset(fn) pcall(fn) end

function mercenaries:ImgOn()
    local I = self.IMG
    pcall(function() System.SetCVar("wh_gfx_useSWF", 1) end)
    pcall(function() UIAction.ShowElement(I.element, 0) end)
    log("ShowElement(" .. I.element .. ", 0) - layout deferred past movie creation")
    Script.SetTimerForFunction(600, "mercenaries.ImgPlace")
end

mercenaries.ImgPlace = function()
    local I = mercenaries.IMG
    imgset(function() UIAction.SetVisible(I.element, 0, I.clip, true) end)
    imgset(function() UIAction.SetAlpha(I.element, 0, I.clip, 100) end)          -- PERCENT
    imgset(function() UIAction.SetScale(I.element, 0, I.clip, { x = 200, y = 200, z = 100 }) end)
    imgset(function() UIAction.SetRotation(I.element, 0, I.clip, { x = 0, y = 0, z = 0 }) end)
    imgset(function() UIAction.SetPos(I.element, 0, I.clip, { x = 380, y = 230, z = 0 }) end)
    log("mc_img at stage (380,230), 200% scale - a 256x128 image drawn at 512x256 stage units")
    log("  RED square = top-left of the image, BLUE = bottom-right, alpha ramps left to right")
end

function mercenaries:ImgOff()
    pcall(function() UIAction.HideElement(mercenaries.IMG.element, 0) end)
    log("image element hidden")
end

-- Prove the image clip is as driveable as a rectangle.
function mercenaries:ImgSpin()
    local I = self.IMG
    if mercenaries.FrameHooks["imgspin"] then
        mercenaries.FrameHooks["imgspin"] = nil
        if I.ent then pcall(function() System.RemoveEntity(I.ent) end); I.ent = nil end
        log("image spin off")
        return
    end
    local p
    pcall(function() p = player and player:GetWorldPos() end)
    if not p then log("no player position"); return end
    local e
    local ok = pcall(function()
        e = System.SpawnEntity({ class = "mercenaries_UIDraw",
            name = "merc_imgspin_" .. tostring(math.random(100000, 999999)),
            position = { x = p.x, y = p.y, z = p.z } })
    end)
    if not (ok and e) then log("could not spawn the frame entity"); return end
    I.ent = e.id
    I.t = 0
    mercenaries.FrameHooks["imgspin"] = function(dt)
        I.t = (I.t or 0) + (dt or 0)
        local t = I.t
        imgset(function() UIAction.SetRotation(I.element, 0, I.clip, { x = 0, y = 0, z = (t * 60) % 360 }) end)
        local sc = 150 + 80 * math.sin(t * 1.5)
        imgset(function() UIAction.SetScale(I.element, 0, I.clip, { x = sc, y = sc, z = 100 }) end)
        imgset(function() UIAction.SetAlpha(I.element, 0, I.clip, 60 + 40 * math.sin(t * 2)) end)
        imgset(function() UIAction.SetPos(I.element, 0, I.clip,
            { x = 540 + 200 * math.cos(t), y = 300 + 120 * math.sin(t), z = 0 }) end)
    end
    log("image spin ON - rotating, pulsing, fading, orbiting. merc_img_spin again to stop.")
end

mercenaries:DevCommand("merc_img_on",   "mercenaries:ImgOn()",   "Show an EMBEDDED bitmap from our own swf")
mercenaries:DevCommand("merc_img_off",  "mercenaries:ImgOff()",  "Hide it")
mercenaries:DevCommand("merc_img_spin", "mercenaries:ImgSpin()", "Rotate/pulse/fade/orbit the image - proves it is as driveable as a rectangle")
