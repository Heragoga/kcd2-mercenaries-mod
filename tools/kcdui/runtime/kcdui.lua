-- kcdui - the engine-facing half of a custom Scaleform screen for KCD2.
--
-- Ship this beside your mod's scripts and LoadScript it BEFORE any screen that uses it.
-- It owns the parts every screen gets wrong the same way: the element lifecycle, the
-- deferred first layout, anchor conversion, frame diffing and number columns.
--
--     KCDUI.screen(atlas, "MyModScreenDeferred")
--
-- What it deliberately does NOT own is what your screen shows and when. That is your
-- driver, it is where all the real work is, and no library can write it for you.

KCDUI = KCDUI or {}
KCDUI.VERSION = "0.1.0"

local function log(s) System.LogAlways("[kcdui] " .. tostring(s)) end

-- ---------------------------------------------------------------- a screen

local Screen = {}
Screen.__index = Screen

--- atlas     the table your builder emitted (needs .element, .ss, .size)
--- deferName the name of a GLOBAL function that calls screen:layout() - Script.SetTimerForFunction
---           takes a function NAME, not a function, so the screen cannot register itself.
function KCDUI.screen(atlas, deferName)
    if type(atlas) ~= "table" or not atlas.element then
        log("screen() got no atlas - did the generated atlas .lua fail to load? "
            .. "An unloaded atlas is not an error: the table is simply nil and every "
            .. "keypress then does nothing.")
        return nil
    end
    local s = setmetatable({}, Screen)
    s.atlas = atlas
    s.el = atlas.element
    s.iid = 0
    s.deferName = deferName
    s.up = false            -- is the Scaleform element loaded
    s.shown = {}            -- what is visible right now
    s.frame = {}            -- what this frame asked for
    s.onLayout = nil        -- set by the driver
    return s
end

-- SetScale and SetAlpha are PERCENT, and the atlas bakes a 1/ss shrink into every clip's
-- authored matrix, so a scale call has to re-apply that shrink or the clip jumps to ss
-- times its intended size.
function Screen:scale(m)
    return m * 100.0 / (self.atlas.ss or 1)
end

--- Place a clip by where its MIDDLE should go, whatever its registration point is.
--- x, y      stage units
--- m, sy     scale multiplier (sy defaults to m)
--- a         alpha 0..1
function Screen:place(name, x, y, m, sy, a)
    local meta = self.atlas.size[name]
    if not meta then
        -- Loud on purpose. A missing clip draws nothing and reports nothing, and that is
        -- the single most common way a screen "does not work".
        if not self._missing then self._missing = {} end
        if not self._missing[name] then
            self._missing[name] = true
            log("no such clip: " .. tostring(name))
        end
        return
    end
    if meta.c == false then
        -- registered at the top-left, so shift by half the drawn size
        x = x - meta.w * (m or 1.0) / 2.0
        y = y - meta.h * (sy or m or 1.0) / 2.0
    end
    pcall(function()
        UIAction.SetPos(self.el, self.iid, name, { x = x, y = y, z = 0 })
        if m then
            UIAction.SetScale(self.el, self.iid, name,
                              { x = self:scale(m), y = self:scale(sy or m), z = 100 })
        end
        if a then UIAction.SetAlpha(self.el, self.iid, name, a * 100) end
        if not self.shown[name] then UIAction.SetVisible(self.el, self.iid, name, true) end
    end)
    self.frame[name] = true
end

--- Swap a multi-frame clip to one of its labelled states.
function Screen:state(name, label)
    pcall(function()
        UIAction.GotoAndStopFrameName(self.el, self.iid, name, label)
    end)
end

--- Start a frame. Call before the first place() of a layout pass.
function Screen:begin()
    self.frame = {}
end

--- Hide everything placed last frame and not this one.
--- Redrawing the whole screen every frame both costs more and flickers.
function Screen:sweep()
    for name in pairs(self.shown) do
        if not self.frame[name] then
            pcall(function() UIAction.SetVisible(self.el, self.iid, name, false) end)
        end
    end
    self.shown = self.frame
    self.frame = {}
end

-- ---------------------------------------------------------------- numbers
--
-- An instance can only be in one place at a time, so a figure built from a shared set of
-- ten digit clips asks the single "0" instance to be in two places when it draws 500.
-- Every field gets its own column of per-position instances; this walks them.

--- Draw a string of glyphs from the `field` column, left edge at x, centred on y.
--- Returns the width drawn, in stage units.
function Screen:digits(field, str, x, y, m, a, align)
    str = tostring(str)
    m = m or 1.0
    local total, n = 0, 0
    for i = 1, #str do
        local ch = str:sub(i, i)
        local meta = self.atlas.size["n_" .. field .. "_" .. (i) .. "_" .. self.glyph(ch)]
        if meta then total = total + meta.w * m end
        n = n + 1
    end
    local cx = x
    if align == "center" then cx = x - total / 2.0
    elseif align == "right" then cx = x - total end
    for i = 1, #str do
        local name = "n_" .. field .. "_" .. i .. "_" .. self.glyph(str:sub(i, i))
        local meta = self.atlas.size[name]
        if meta then
            -- digit clips are registered top-left, so place() wants the middle
            self:place(name, cx + meta.w * m / 2.0, y, m, m, a)
            cx = cx + meta.w * m
        end
        -- a character with no clip is skipped, which is how "2 / 6" once printed as "2 6";
        -- give the column every separator it can ever print
    end
    return total
end

--- Map a character to the clip-name suffix its glyph was built under.
KCDUI.GLYPH = { ["/"] = "slash", ["%"] = "pct", ["+"] = "plus", ["-"] = "minus",
                [","] = "comma", ["."] = "dot", [":"] = "colon", [" "] = "space" }
function Screen.glyph(ch)
    return KCDUI.GLYPH[ch] or ch
end

-- ---------------------------------------------------------------- lifecycle

--- Show or hide the Scaleform element itself. Returns true if it was freshly created,
--- which means the caller MUST defer its first layout.
function Screen:element(want)
    if want == self.up then return false end
    if want then
        pcall(function() System.SetCVar("wh_gfx_useSWF", 1) end)
        -- Unload before reload: a stale instance from a previous level keeps its old
        -- clip transforms and nothing you send afterwards is applied.
        pcall(function() UIAction.UnloadElement(self.el, -1) end)
        pcall(function() UIAction.ReloadElement(self.el, -1) end)
        local ok, err = pcall(function() UIAction.ShowElement(self.el, self.iid) end)
        self.up, self.shown, self.frame = true, {}, {}
        if not ok then log("ShowElement failed: " .. tostring(err)) end
        return true
    end
    self.up, self.shown, self.frame = false, {}, {}
    pcall(function() UIAction.HideElement(self.el, self.iid) end)
    return false
end

--- Bring the screen up and lay it out.
---
--- The movie is BUILT ON FIRST DISPLAY. Transforms sent in the same call address clips
--- that do not exist yet and silently no-op, which looks exactly like a layout bug. So on
--- a fresh element the first layout is deferred by a timer instead.
function Screen:show(delay)
    local fresh = self:element(true)
    if fresh then
        Script.SetTimerForFunction(delay or 600, self.deferName)
    else
        self:layout()
    end
end

function Screen:hide()
    self:element(false)
end

function Screen:layout()
    if not self.up then return end
    if not self.onLayout then return end
    self:begin()
    self.onLayout(self)
    self:sweep()
end

-- ---------------------------------------------------------------- corner prompt
--
-- A screen nobody can find is a screen nobody uses, so put a prompt in a corner saying
-- which key opens it, laid out like KCD2's own action hint: the word first, the key cap
-- second, the row anchored on its RIGHT EDGE so the caps line up in a straight column
-- whatever the words do.
--
-- Make WHERE it sits a player setting from the start. The bottom right is where KCD2 draws
-- its own pickup and objective messages AND its interaction prompts, and a prompt parked on
-- top of those is the first complaint you will get.

KCDUI.CORNERS = { topright = true, topleft = true, bottomright = true, bottomleft = true }

--- anchors: { leftX=, rightX=, topY=, bottomY= } in stage units, from your atlas. Every one
--- of them is the row's RIGHT EDGE, because that is the edge the caps line up on.
--- Returns x, y for one row of the column.
function KCDUI.cornerXY(anchors, corner, rowDY)
    corner = KCDUI.CORNERS[corner] and corner or "topright"
    local x = (corner == "topleft" or corner == "bottomleft")
              and (anchors.leftX or 200) or (anchors.rightX or 1262)
    local y = (corner == "topleft" or corner == "topright")
              and (anchors.topY or 32) or (anchors.bottomY or 618)
    return x, y + (rowDY or 0)
end

--- Draw `Label [K]` at a corner. `cap` and `label` are clip names.
---
--- The key letter is expected to be baked into the cap art (one clip, not two): the key a
--- screen opens on is fixed at build time, so there is nothing to compose at runtime and a
--- separate letter clip is just one more thing to position wrongly.
function Screen:nudge(anchors, corner, rowDY, cap, label, gap)
    local x, y = KCDUI.cornerXY(anchors, corner, rowDY)
    local cw = (self.atlas.size[cap] or { w = 21.33 }).w
    local lw = (self.atlas.size[label] or { w = 0 }).w
    self:place(cap, x - cw / 2, y)
    self:place(label, x - cw - (gap or 7) - lw / 2, y)
end

return KCDUI
