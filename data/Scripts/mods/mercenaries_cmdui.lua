-- Bannerlord-style battle command interface. VISUAL PROTOTYPE ONLY - the orders are not
-- wired to anything yet, they just light up and log.
--
-- Everything is drawn with System.DrawText, which is the only immediate-mode primitive
-- that renders in screen space in KCD2 (System.Draw2DLine does not - see docs/ui.md).
-- That means there are no filled rectangles: a panel is rows of a repeated glyph, one
-- DrawText call per row, so keep the glyph budget in mind.
--
--   merc_cmd_keys   bind F1-F10 and the numpad, and turn the interface on
--   merc_cmd        toggle it
--   merc_cmd_off    hide it and release the keys
--   merc_cmd_cal    glyph metric ruler, if the panels look wrong

mercenaries.FrameHooks = mercenaries.FrameHooks or {}

mercenaries.CMD = mercenaries.CMD or {
    on       = false,
    cat      = nil,     -- open order category, nil = none
    sel      = { [1] = true },
    lastOrder = "",
    lastAt   = 0,
    -- glyph metrics: how wide and tall one fill glyph is at fillSize. Tune with
    -- merc_cmd_cell if panels come out gappy or overlapping.
    glyph    = "_",   -- see charsets below: the debug font is ASCII only
    -- Fill metrics. A fill is rows of underscores, and all three of these have to match
    -- the font or panels come out the wrong size and in the wrong place:
    --   cellW    horizontal advance of ONE glyph at fillSize (too small -> panel too wide)
    --   rowPx    vertical gap between rows (too big -> stripes, too small -> costly)
    --   fillYOff the underscore paints near its BASELINE, well below the y you pass, so
    --            the whole fill needs shifting up by roughly one glyph height
    -- merc_cmd_cal draws a target rectangle out of text markers and the fill on top of it;
    -- tune until they coincide, then the numbers are right for good.
    fillSize = 4,
    cellW    = 30,
    rowPx    = 3,
    fillYOff = -48,
}

-- MEASURED: the engine's debug font has NO Unicode block characters - U+2588, the shades,
-- the half blocks and U+25A0 all render as empty tofu boxes. ASCII only.
-- '_' is the useful one: a run of underscores is a continuous unbroken line, so stacking
-- rows of it a few pixels apart is the closest thing to a filled rectangle we have.
mercenaries.CMD.charsets = {
    under   = { g = "_", d = "unbroken line - best fill" },
    equals  = { g = "=", d = "double rule, striped fill" },
    hash    = { g = "#", d = "dense but gappy" },
    at      = { g = "@", d = "round, gappy" },
    eight   = { g = "8", d = "dense, gappy" },
    minus   = { g = "-", d = "thin dashed rule" },
    dot     = { g = ".", d = "dotted" },
    colon   = { g = ":", d = "dotted, two rows" },
}

-- Every layout number, live-tunable with  merc_cmd_lay <key> <value>.  merc_cmd_lay_dump
-- prints the table back as Lua so a good set can be pasted in here as the new default.
-- Sizes (s*) are font sizes and are NOT scaled by S; the rest are 1080p pixels that are.
mercenaries.CMD.L = mercenaries.CMD.L or {
    BW = 1320, gapx = 14, botY = 320,
    cardH = 112, catH = 54, ordH = 48, headH = 66,
    gapCat = 18, gapOrd = 18, gapTitle = 0, gapHint = 14,
    padx = 20, idxY = 14, countY = 14, nameY = 44, barY = 82,
    hintX = 20, headTitleY = 11, headHintY = 40,
    catTextY = 15, ordTextY = 17,
    sHero = 4.8, sBar = 3.0, sSum = 4.2, sName = 4.0,
    sCat = 4.2, sOrd = 3.1, sOrdKey = 3.1, sTitle = 4.8, sHint = 3.6, sLast = 4.8,
    sTag = 8, sCount = 4.0, sIdx = 4.0, idxDX = 46, tagY = 12,
    charW = 4.04,
}

local CMD = mercenaries.CMD
local function log(s) System.LogAlways("[MercCmd] " .. tostring(s)) end

-- Slot -> key. F1 is taken by the game and F12 by Steam's screenshot, so neither can be
-- bound; F5 is deliberately left alone so quicksave keeps working. Seven slots, which is
-- what the longest order list needs.
CMD.keys = {
    { "f2", "F2" }, { "f3", "F3" }, { "f4", "F4" },
    { "f6", "F6" }, { "f7", "F7" }, { "f8", "F8" }, { "f11", "F11" },
}
local function keyLabel(i)
    local k = CMD.keys[i]
    return k and k[2] or ("#" .. i)
end

-- The company as it actually fields: three infantry squads and two archer squads.
CMD.groups = {
    { name = "Infantry I",   n = 8, cap = 10 },
    { name = "Infantry II",  n = 8, cap = 8 },
    { name = "Infantry III", n = 6, cap = 10 },
    { name = "Archers I",    n = 5, cap = 6 },
    { name = "Archers II",   n = 4, cap = 6 },
}

CMD.cats = {
    { name = "Movement",  orders = { "Charge", "Advance", "Fall Back", "Stand Ground", "Follow Me", "Retreat" } },
    { name = "Formation", orders = { "Line", "Shield Wall", "Loose", "Circle", "Skein", "Column", "Square" } },
    { name = "Mount",     orders = { "Mount", "Dismount" } },
    -- direct: no submenu, the key issues the order straight away
    { name = "Position",  direct = true },
}

-- ============================================================================
-- drawing primitives, all on top of DrawText
-- ============================================================================

-- MEASURED signature: System.DrawText(x, y, text, size, r, g, b, a).
-- NOT the (x, y, text, font, size, p2y, r, g, b, a) form in the 2012 scriptbind doc -
-- passing that shifts every argument along and everything comes out magenta. The base
-- game agrees: CrimeDebugger.lua calls System.DrawText(x, y, str, 3).
local calls = 0

local function label(x, y, s, size, r, g, b, a)
    calls = calls + 1
    System.DrawText(x, y, tostring(s), size or 3, r or 1, g or 1, b or 1, a or 1)
end

local function fill(x, y, w, h, r, g, b, a)
    local n    = math.max(1, math.floor(w / CMD.cellW + 0.5))
    local run  = string.rep(CMD.glyph, n)
    local step = math.max(1, CMD.rowPx)
    local rows = math.max(1, math.ceil(h / step))
    calls = calls + rows
    for i = 0, rows - 1 do
        System.DrawText(x, y + (CMD.fillYOff or 0) + i * step, run, CMD.fillSize, r, g, b, a)
    end
end

-- A border is horizontal rules only. fill() cannot draw anything narrower than one glyph,
-- so a 2px vertical edge came out ~60px wide - hence top and bottom only, which also reads
-- more like the game's own banded panels.
local function rule(x, y, w, r, g, b, a)
    local n = math.max(1, math.floor(w / CMD.cellW + 0.5))
    calls = calls + 1
    System.DrawText(x, y + (CMD.fillYOff or 0), string.rep(CMD.glyph, n), CMD.fillSize, r, g, b, a)
end

local function panel(x, y, w, h, sel)
    if sel then
        fill(x, y, w, h, 0.39, 0.31, 0.14, 0.97)
        rule(x, y, w, 0.90, 0.76, 0.36, 1)
        rule(x, y + h, w, 0.90, 0.76, 0.36, 1)
    else
        fill(x, y, w, h, 0.102, 0.098, 0.110, 0.93)
        rule(x, y, w, 0.42, 0.39, 0.34, 0.9)
        rule(x, y + h, w, 0.42, 0.39, 0.34, 0.9)
    end
end

-- Draw "F2  Movement" centred inside a cell of width w, key in gold and label in tc.
-- The font is monospace, so the width is just character count x size x charW.
local function pairLabel(x, y, w, key, name, size, charW, tc, keycol)
    keycol = keycol or { 0.90, 0.76, 0.36 }
    local gap   = (key ~= "") and 2 or 0
    local chars = #key + gap + #name
    local avail = w - 16 * (charW / 4.05)          -- keep a little padding either side
    -- shrink to fit rather than clip: a fixed-width font makes the width exact, so a
    -- long label like "Stand Ground" simply renders a little smaller in its cell
    if chars * size * charW > avail then size = avail / (chars * charW) end
    local tw = chars * size * charW
    local cx = x + (w - tw) * 0.5
    if key ~= "" then label(cx, y, key, size, keycol[1], keycol[2], keycol[3], 1) end
    label(cx + (#key + gap) * size * charW, y, name, size, tc[1], tc[2], tc[3], 1)
end

-- right-aligned label, so the card index sits the same distance from every card's edge
local function labelR(xRight, y, s, size, charW, r, g, b, a)
    label(xRight - #tostring(s) * size * charW, y, s, size, r, g, b, a)
end

-- ============================================================================
-- the interface
-- ============================================================================

function mercenaries:CmdDraw(dt)
    local C = self.CMD
    if not C.on then return end

    local lastCalls = calls
    calls = 0
    if dt and dt > 0 then
        C.fps = (C.fps and (C.fps * 0.95 + (1 / dt) * 0.05)) or (1 / dt)
    end

    local vp
    pcall(function() vp = System.GetViewport() end)
    local W = (vp and tonumber(vp.width)) or 1920
    local H = (vp and tonumber(vp.height)) or 1080
    local S = H / 1080                       -- everything below is authored at 1080p

    local GOLD = { 0.90, 0.76, 0.36 }
    local DIM  = { 0.62, 0.60, 0.55 }
    local KEYD = { 0.59, 0.50, 0.29 }
    local CREAM = { 0.93, 0.91, 0.84 }
    local RUST  = { 0.86, 0.29, 0.19 }
    local CATD  = { 0.77, 0.75, 0.71 }

    -- Font sizes are NOT multiplied by S: the engine already auto-scales this font above
    -- 1080p (r_AuxGeomAutoScaleOver1080pWH), so scaling again double-counts. Layout
    -- coordinates DO get S. Everything below is authored against a fixed 1500-wide block
    -- so every row shares one left edge and one width.

    local L     = C.L
    local BW    = L.BW * S
    local left  = (W - BW) * 0.5
    local gapx  = L.gapx * S

    local cardH, catH, ordH = L.cardH * S, L.catH * S, L.ordH * S
    local cardY  = H - L.botY * S
    local catY   = cardY - catH - L.gapCat * S
    local ordY   = catY  - ordH - L.gapOrd * S
    local titleY = ordY - L.gapTitle * S
    local hintY  = (C.cat and titleY or catY) - L.gapHint * S

    -- ---- formation cards --------------------------------------------------
    local nC = #C.groups
    local cw = (BW - (nC - 1) * gapx) / nC
    for i, g in ipairs(C.groups) do
        local x   = left + (i - 1) * (cw + gapx)
        local sel = C.sel[i] == true
        panel(x, cardY, cw, cardH, sel)
        local tc = sel and CREAM or DIM
        local cwch = L.charW * S
        -- the squad name is the card: centred, with the select key and the strength at the
        -- same size in the corners
        local nw = #g.name * L.sHero * cwch
        label(x + (cw - nw) * 0.5, cardY + L.nameY * S, g.name, L.sHero, tc[1], tc[2], tc[3], 1)
        -- strength gauge: one mark per man, rust for every man short of full complement
        local cap  = g.cap or g.n
        local bar  = string.rep("|", g.n)
        local lost = string.rep("x", math.max(0, cap - g.n))
        local bw2  = (#bar + #lost) * L.sBar * cwch
        local bx   = x + (cw - bw2) * 0.5
        label(bx, cardY + L.barY * S, bar, L.sBar, tc[1], tc[2], tc[3], 1)
        label(bx + #bar * L.sBar * cwch, cardY + L.barY * S, lost, L.sBar,
            RUST[1], RUST[2], RUST[3], 1)
        local kc = sel and CREAM or DIM
        label(x + L.padx * S, cardY + L.idxY * S, tostring(i), L.sName, kc[1], kc[2], kc[3], 1)
        labelR(x + cw - L.padx * S, cardY + L.countY * S, g.n .. " men", L.sName, cwch, 0.78, 0.78, 0.74, 1)
    end

    -- ---- category strip ---------------------------------------------------
    local nK = #C.cats
    local bw = (BW - (nK - 1) * gapx) / nK
    for i, cat in ipairs(C.cats) do
        local x   = left + (i - 1) * (bw + gapx)
        local act = (C.cat == i)
        panel(x, catY, bw, catH, act)
        local tc = act and GOLD or DIM
        local k = (C.cat ~= nil) and "" or keyLabel(i)
        pairLabel(x, catY + L.catTextY * S, bw, k, cat.name, L.sCat, L.charW * S,
            act and CREAM or CATD, act and CREAM or KEYD)
    end

    -- ---- open category: its orders ---------------------------------------
    if C.cat then
        local cat = C.cats[C.cat]
        local nO  = #cat.orders
        local ow  = (BW - (nO - 1) * gapx) / nO
        for i, o in ipairs(cat.orders) do
            local x = left + (i - 1) * (ow + gapx)
            panel(x, ordY, ow, ordH, false)
            pairLabel(x, ordY + L.ordTextY * S, ow, keyLabel(i), o, L.sOrd, L.charW * S, DIM, KEYD)
        end
    end

    -- ---- header band: title + hint share one panel, same edges as the rows --------
    local headH = L.headH * S
    local headY = (C.cat and titleY or catY) - L.gapHint * S - headH
    panel(left, headY, BW, headH, false)
    if C.cat then
        label(left + L.padx * S, headY + L.headTitleY * S,
            string.upper(C.cats[C.cat].name) .. " ORDERS", L.sTitle, GOLD[1], GOLD[2], GOLD[3], 1)
    else
        label(left + L.padx * S, headY + L.headTitleY * S,
            "COMPANY", L.sTitle, GOLD[1], GOLD[2], GOLD[3], 1)
    end
    if C.lastOrder ~= "" and (System.GetCurrTime() - C.lastAt) < 4 then
        label(left + L.hintX * S, headY + L.headHintY * S, "> " .. C.lastOrder,
            L.sLast, GOLD[1], GOLD[2], GOLD[3], 1)
    else
        label(left + L.hintX * S, headY + L.headHintY * S,
            ((C.cat ~= nil) and "F2-F4, F6-F8 order" or "F2-F4, F6 category")
            .. "  |  numpad 1-" .. #C.groups .. " select, 0 all",
            L.sHint, 0.72, 0.72, 0.70, 1)
    end
    -- F9 is contextual: back out of an open category, or hide the whole thing
    local dismiss = (C.cat ~= nil) and "F9 back" or "F9 hide"
    labelR(left + BW - 8 * S, headY + L.headHintY * S, dismiss, L.sHint, L.charW * S,
        0.55, 0.53, 0.49, 1)
    -- summary names what is selected rather than counting it
    local seli, men = {}, 0
    for i, g in ipairs(C.groups) do
        if C.sel[i] then seli[#seli + 1] = i; men = men + g.n end
    end
    local summ = "nothing selected"
    if #seli == 1 then summ = C.groups[seli[1]].name .. "  |  " .. men .. " men"
    elseif #seli > 1 then summ = #seli .. " squads  |  " .. men .. " men" end
    labelR(left + BW - 8 * S, headY + L.headTitleY * S, summ, L.sSum, L.charW * S,
        GOLD[1], GOLD[2], GOLD[3], 1)

    if C.stats then
        label(20 * S, 20 * S, string.format(
            "%d draw calls   %.0f fps   fillSize=%s rowPx=%s cellW=%s",
            lastCalls, C.fps or 0, tostring(C.fillSize), tostring(C.rowPx), tostring(C.cellW)),
            4.5, 0.4, 1, 0.5, 1)
    end
end

function mercenaries:CmdStats()
    self.CMD.stats = not self.CMD.stats
    log("draw-call readout " .. (self.CMD.stats and "on" or "off"))
end

-- ============================================================================
-- input
-- ============================================================================

local function selectedNames()
    local t = {}
    for i, g in ipairs(mercenaries.CMD.groups) do
        if mercenaries.CMD.sel[i] then t[#t + 1] = g.name end
    end
    if #t == 0 then return "nobody" end
    return table.concat(t, ", ")
end

-- F1..F7: pick the category when none is open, pick the order when one is
function mercenaries:CmdKey(i)
    local C = self.CMD
    if not C.on then return end

    if C.cat == nil then
        local cat = C.cats[i]
        if not cat then return end
        if cat.direct then
            C.lastOrder = cat.name .. "  ->  " .. selectedNames()
            C.lastAt = System.GetCurrTime()
            log("ORDER: " .. C.lastOrder .. "   (not wired to anything yet)")
        else
            C.cat = i
            log("category " .. cat.name)
        end
        return
    end

    local cat = C.cats[C.cat]
    local order = cat.orders[i]
    if order then
        C.lastOrder = order .. "  ->  " .. selectedNames()
        C.lastAt = System.GetCurrTime()
        log("ORDER: " .. C.lastOrder .. "   (not wired to anything yet)")
    end
    C.cat = nil
end

function mercenaries:CmdSelect(i)
    local C = self.CMD
    if not C.on then return end
    if i == 0 then
        local all = true
        for k = 1, #C.groups do if not C.sel[k] then all = false end end
        for k = 1, #C.groups do C.sel[k] = not all end
        log(all and "selection cleared" or "all formations selected")
        return
    end
    if not C.groups[i] then return end
    C.sel[i] = not C.sel[i]
    log("selection: " .. selectedNames())
end

-- F9: step back out of an open category first, only hide when nothing is open
function mercenaries:CmdBack()
    if self.CMD.on and self.CMD.cat ~= nil then
        self.CMD.cat = nil
        log("back to categories")
        return
    end
    self:CmdToggle()
end

function mercenaries:CmdToggle()
    local C = self.CMD
    C.on = not C.on
    C.cat = nil
    if C.on then
        self.FrameHooks["cmdui"] = function(dt) mercenaries:CmdDraw(dt) end
        self:CmdEnsureEntity()
        log("command interface ON")
    else
        self.FrameHooks["cmdui"] = nil
        log("command interface OFF")
    end
end

function mercenaries:CmdEnsureEntity()
    if self.CMD.ent then return end
    local p
    pcall(function() p = player and player:GetWorldPos() end)
    if not p then log("no player position - are you in a level?"); return end
    local e
    local ok, err = pcall(function()
        e = System.SpawnEntity({
            class = "mercenaries_UIDraw",
            name  = "merc_cmdui_" .. tostring(math.random(100000, 999999)),
            position = { x = p.x, y = p.y, z = p.z },
        })
    end)
    if not ok then log("SpawnEntity threw: " .. tostring(err)); return end
    if not e then log("SpawnEntity returned nil - is mercenaries_UIDraw.ent deployed?"); return end
    self.CMD.ent = e.id
end

function mercenaries:CmdOff()
    local C = self.CMD
    C.on, C.cat = false, nil
    self.FrameHooks["cmdui"] = nil
    if C.ent then
        pcall(function() System.RemoveEntity(C.ent) end)
        C.ent = nil
    end
    for _, k in ipairs(CMD.keys) do
        pcall(function() System.ExecuteCommand("unbind " .. k[1]) end)
    end
    for _, k in ipairs({ "f9", "f10", "np_1", "np_2", "np_3", "np_4", "np_5", "np_0" }) do
        pcall(function() System.ExecuteCommand("unbind " .. k) end)
    end
    log("command interface off, keys released")
end

function mercenaries:CmdKeys()
    for i, k in ipairs(CMD.keys) do
        pcall(function() System.ExecuteCommand("bind " .. k[1] .. " merc_cmd_f" .. i) end)
    end
    for i = 1, #CMD.groups do
        pcall(function() System.ExecuteCommand("bind np_" .. i .. " merc_cmd_sel" .. i) end)
    end
    pcall(function() System.ExecuteCommand("bind np_0 merc_cmd_sel0") end)
    pcall(function() System.ExecuteCommand("bind f9 merc_cmd_back") end)
    pcall(function() System.ExecuteCommand("bind f10 merc_cmd_off") end)

    local cats, orders = {}, {}
    for i = 1, #CMD.cats do cats[#cats + 1] = keyLabel(i) end
    for i = 1, 7 do orders[#orders + 1] = keyLabel(i) end
    log("keys bound:")
    log("  " .. table.concat(cats, " ") .. "   open an order category")
    log("  " .. table.concat(orders, " ") .. "  pick the order once a category is open")
    log("  np 1-" .. #CMD.groups .. "  toggle a squad, np 0  all/none")
    log("  F9      back out of a category, or show/hide;  F10  off and unbind")
    log("  F1 (game-reserved), F5 (quicksave) and F12 (Steam) are deliberately not used.")
    if not self.CMD.on then self:CmdToggle() end
end

-- Glyph metrics ruler: panels are built from repeated glyphs, so cellW/cellH have to
-- match the font. Run this, read the numbers off the screen, then merc_cmd_cell <w> <h>.
function mercenaries:CmdCal()
    self.CMD.cal = not self.CMD.cal
    if self.CMD.cal then
        self.FrameHooks["cmdcal"] = function()
            local C2 = mercenaries.CMD
            local X, Y, TW, TH = 500, 400, 900, 300

            -- the TARGET rectangle, drawn out of text markers whose placement we trust
            for i = 0, TW, 30 do
                label(X + i, Y,      "-", 4, 1, 1, 1, 1)
                label(X + i, Y + TH, "-", 4, 1, 1, 1, 1)
            end
            for j = 0, TH, 30 do
                label(X,      Y + j, "|", 4, 1, 1, 1, 1)
                label(X + TW, Y + j, "|", 4, 1, 1, 1, 1)
            end
            label(X - 10, Y - 50, "TARGET " .. TW .. "x" .. TH .. " - the fill should land exactly inside it",
                5, 1, 1, 1, 1)

            -- the fill, in translucent green, over the same rectangle
            fill(X, Y, TW, TH, 0.2, 1, 0.35, 0.55)

            label(X, Y + TH + 60, string.format(
                "cellW=%s  (fill too WIDE -> raise it)", tostring(C2.cellW)), 5, 0.4, 1, 0.5, 1)
            label(X, Y + TH + 110, string.format(
                "fillYOff=%s  (fill too LOW -> lower it)", tostring(C2.fillYOff)), 5, 0.4, 1, 0.5, 1)
            label(X, Y + TH + 160, string.format(
                "rowPx=%s  (striped -> lower it; solid+slow -> raise fillSize=%s first)",
                tostring(C2.rowPx), tostring(C2.fillSize)), 5, 0.4, 1, 0.5, 1)
            label(X, Y + TH + 220,
                "merc_cmd_cell <w>   merc_cmd_yoff <px>   merc_cmd_row <px>   merc_cmd_glyph <c> <size>",
                4.5, 0.8, 0.8, 0.78, 1)
        end
        self:CmdEnsureEntity()
        log("calibration on - tune cellW, yoff and row until the green fill fits the white box")
    else
        self.FrameHooks["cmdcal"] = nil
        log("calibration off")
    end
end

-- Which of the block characters does the engine's debug font actually have? Anything
-- that comes out as a hollow box, a question mark or nothing is missing from the font.
function mercenaries:CmdChars()
    self.CMD.chars = not self.CMD.chars
    if not self.CMD.chars then
        self.FrameHooks["cmdchars"] = nil
        log("charset probe off")
        return
    end
    local order = { "under", "equals", "hash", "at", "eight", "minus", "dot", "colon" }
    self.FrameHooks["cmdchars"] = function()
        local x, y = 300, 200
        label(x, y - 120, "CHARSET PROBE - pick one, then: merc_cmd_set <name>", 6, 0.9, 0.75, 0.3, 1)
        -- colour check: if these three are not red/green/blue the signature is wrong again
        label(x,        y - 60, "RED",   6, 1, 0, 0, 1)
        label(x + 200,  y - 60, "GREEN", 6, 0, 1, 0, 1)
        label(x + 450,  y - 60, "BLUE",  6, 0.2, 0.4, 1, 1)
        label(x + 700,  y - 60, "WHITE", 6, 1, 1, 1, 1)

        for i, name in ipairs(order) do
            local cs = mercenaries.CMD.charsets[name]
            local ry = y + (i - 1) * 90
            label(x, ry, name, 5, 0.8, 0.8, 0.76, 1)
            label(x + 220, ry, cs.g, 8, 1, 0.85, 0.25, 1)
            label(x + 330, ry, string.rep(cs.g, 20), 4, 1, 0.85, 0.25, 1)
            -- six tightly stacked rows: this is what a fill actually looks like
            for k = 0, 5 do
                label(x + 780, ry + k * mercenaries.CMD.rowPx, string.rep(cs.g, 14),
                    mercenaries.CMD.fillSize, 0.35, 0.75, 1, 1)
            end
            label(x + 1150, ry, cs.d, 4.5, 0.62, 0.62, 0.6, 1)
        end
        label(x, y + #order * 90 + 30,
            "middle column = one run; next column = 6 rows at rowPx=" ..
            tostring(mercenaries.CMD.rowPx) .. " (merc_cmd_row <px> to tighten)",
            4.5, 0.72, 0.72, 0.7, 1)
    end
    self:CmdEnsureEntity()
    log("charset probe on - merc_cmd_chars again to hide")
end

function mercenaries:CmdSet(line)
    local name = string.match(tostring(line), "%a+")
    local cs = name and self.CMD.charsets[name]
    if not cs then
        local t = {}
        for k in pairs(self.CMD.charsets) do t[#t + 1] = k end
        table.sort(t)
        log("usage: merc_cmd_set <" .. table.concat(t, "|") .. ">")
        return
    end
    self.CMD.glyph = cs.g
    log("fill glyph is now '" .. name .. "' (" .. cs.d .. ")")
end

function mercenaries:CmdCell(line)
    local w = string.match(tostring(line), "([%d%.]+)")
    if not w then log("usage: merc_cmd_cell <cellW>"); return end
    self.CMD.cellW = tonumber(w)
    log("glyph advance now " .. self.CMD.cellW .. "px")
end

function mercenaries:CmdYOff(line)
    local v = string.match(tostring(line), "(-?[%d%.]+)")
    if not v then log("usage: merc_cmd_yoff <pixels>  (negative moves the fill up)"); return end
    self.CMD.fillYOff = tonumber(v)
    log("fill vertical offset now " .. self.CMD.fillYOff .. "px")
end

function mercenaries:CmdRow(line)
    local p = string.match(tostring(line), "([%d%.]+)")
    if not p then log("usage: merc_cmd_row <pixels between fill rows>"); return end
    self.CMD.rowPx = math.max(1, tonumber(p))
    log("fill rows now " .. self.CMD.rowPx .. "px apart")
end

function mercenaries:CmdGlyph(line)
    local g, s = string.match(tostring(line), "(%S+)%s*([%d%.]*)")
    if not g then log("usage: merc_cmd_glyph <char> [fillSize]"); return end
    self.CMD.glyph = g
    if s and s ~= "" then self.CMD.fillSize = tonumber(s) end
    log("glyph '" .. self.CMD.glyph .. "' at size " .. self.CMD.fillSize)
end

mercenaries:DevCommand("merc_cmd",       "mercenaries:CmdToggle()", "Battle command interface: show/hide")
mercenaries:DevCommand("merc_cmd_back",  "mercenaries:CmdBack()",   "Back out of an open category, or hide the interface")
mercenaries:DevCommand("merc_cmd_keys",  "mercenaries:CmdKeys()",   "Bind F1-F10 + numpad and turn the interface on")
mercenaries:DevCommand("merc_cmd_off",   "mercenaries:CmdOff()",    "Hide the interface and release the keys")
mercenaries:DevCommand("merc_cmd_cal",   "mercenaries:CmdCal()",    "Glyph metric ruler - use if the panels look wrong")
mercenaries:DevCommand("merc_cmd_chars", "mercenaries:CmdChars()",  "Show which block characters the debug font actually has")
mercenaries:DevCommand("merc_cmd_set",   "mercenaries:CmdSet('%line')",   "Pick the panel fill character: <name> from merc_cmd_chars")
mercenaries:DevCommand("merc_cmd_cell",  "mercenaries:CmdCell('%line')",  "Set the glyph advance width in px: <cellW>")
mercenaries:DevCommand("merc_cmd_stats", "mercenaries:CmdStats()", "Toggle the draw-call / fps readout")
mercenaries:DevCommand("merc_cmd_yoff",  "mercenaries:CmdYOff('%line')",  "Shift the fill vertically: <px>, negative = up")
mercenaries:DevCommand("merc_cmd_row",   "mercenaries:CmdRow('%line')",   "Set pixels between fill rows: <px> (smaller = more solid)")
mercenaries:DevCommand("merc_cmd_glyph", "mercenaries:CmdGlyph('%line')", "Set the fill glyph: <char> [fillSize]")
for i = 1, 7 do
    mercenaries:DevCommand("merc_cmd_f" .. i, "mercenaries:CmdKey(" .. i .. ")", "Command interface key F" .. i)
end
for i = 0, 5 do
    mercenaries:DevCommand("merc_cmd_sel" .. i, "mercenaries:CmdSelect(" .. i .. ")", "Command interface: select formation " .. i)
end

-- ============================================================================
-- live tuning + remote control, for the automated look-tuning loop
-- ============================================================================

function mercenaries:CmdLay(line)
    local k, v = string.match(tostring(line), "(%a+)%s+(-?[%d%.]+)")
    if not k then log("usage: merc_cmd_lay <key> <value>   (merc_cmd_lay_dump lists them)"); return end
    local t = self.CMD.L
    if t[k] == nil then
        -- also allow the fill metrics through the same command
        if self.CMD[k] ~= nil and type(self.CMD[k]) == "number" then
            self.CMD[k] = tonumber(v); log(k .. " = " .. v); return
        end
        log("no such key: " .. k); return
    end
    t[k] = tonumber(v)
    log(k .. " = " .. v)
end

function mercenaries:CmdLayDump()
    local t, keys = self.CMD.L, {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = k .. " = " .. tostring(t[k]) end
    log("L = { " .. table.concat(out, ", ") .. " }")
    log("fill: fillSize = " .. tostring(self.CMD.fillSize) .. ", cellW = " .. tostring(self.CMD.cellW)
        .. ", rowPx = " .. tostring(self.CMD.rowPx) .. ", fillYOff = " .. tostring(self.CMD.fillYOff))
end

-- Poll a control file so a host script can drive the running game without keystrokes.
-- The file lives in the game root; writing commands into it is how the tuning loop works.
mercenaries.CMD.remoteOn = false

function mercenaries:CmdRemote()
    local C = self.CMD
    C.remoteOn = not C.remoteOn
    if C.remoteOn then
        log("remote control ON - polling merc_ui_ctl.cfg every second")
        mercenaries.CmdRemoteTick()
    else
        log("remote control OFF")
    end
end

mercenaries.CmdRemoteTick = function()
    if not mercenaries.CMD.remoteOn then return end
    pcall(function() System.ExecuteCommand("exec merc_ui_ctl.cfg") end)
    Script.SetTimerForFunction(1000, "mercenaries.CmdRemoteTick")
end

function mercenaries:CmdShot()
    pcall(function() System.ExecuteCommand("r_GetScreenShot 1") end)
end

mercenaries:DevCommand("merc_cmd_lay",      "mercenaries:CmdLay('%line')", "Set a layout number: <key> <value>")
mercenaries:DevCommand("merc_cmd_lay_dump", "mercenaries:CmdLayDump()",    "Print the whole layout table")
mercenaries:DevCommand("merc_cmd_remote",   "mercenaries:CmdRemote()",     "Poll merc_ui_ctl.cfg so a host script can drive this")
mercenaries:DevCommand("merc_cmd_shot",     "mercenaries:CmdShot()",       "Take a screenshot")


-- Idempotent setters. The control file is re-executed every second, so anything the
-- tuning loop uses must be a SET, never a toggle.
function mercenaries:CmdOn()
    if not self.CMD.on then self:CmdToggle() end
end

function mercenaries:CmdCat(line)
    local n = tonumber(string.match(tostring(line), "%d+") or "")
    self.CMD.cat = (n and self.CMD.cats[n]) and n or nil
end

function mercenaries:CmdStatsSet(line)
    self.CMD.stats = (string.match(tostring(line), "%d+") == "1")
end

mercenaries:DevCommand("merc_cmd_on",    "mercenaries:CmdOn()",             "Show the interface (idempotent)")
mercenaries:DevCommand("merc_cmd_cat",   "mercenaries:CmdCat('%line')",     "Open order category <n>, 0 = none (idempotent)")
mercenaries:DevCommand("merc_cmd_stats_set", "mercenaries:CmdStatsSet('%line')", "Draw-call readout on/off: <0|1>")

-- The control-file poll (merc_cmd_remote) is NOT armed automatically. tools/uitune.ps1
-- turns it on for a tuning session; players never get it. The interface itself starts
-- hidden and only appears via merc_cmd_keys / merc_cmd.
