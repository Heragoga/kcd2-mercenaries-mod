-- Bannerlord-style command interface, drawn with real Scaleform clips.
--
--   merc_bl          show/hide
--   merc_bl_keys     bind the keys and show it
--   merc_bl_off      hide it and release the keys
--   merc_bl_demo     cycle the placeholder squad roster, to exercise the card states
--
-- The art, the geometry and the order tree all come from mercenaries_blatlas.lua, which
-- tools/make_bl.py generates alongside MercBL.swf. See docs/command-ui.md.

mercenaries.BL = mercenaries.BL or {}
local BL = mercenaries.BL
local EL = "MercBL"

local function log(s) System.LogAlways("[MercBL] " .. tostring(s)) end
local function atlas() return mercenaries.BLAtlas end

-- %line reaches Lua with its surrounding quotes intact - see docs/console.md.
local QUOTES = string.char(34) .. string.char(39)
local function unquote(s)
    return (string.gsub(tostring(s or ""), "[" .. QUOTES .. "]", ""))
end

BL.on = false
BL.open = nil                       -- "move" | "form" | "toggle" | nil
BL.shown = BL.shown or {}
BL.frame = BL.frame or {}
-- What the row and the wheels are showing. This is a CACHE of the company's real settings,
-- not the settings themselves: BLReadState refreshes every entry from the mod on each draw,
-- so these values only ever stand in for the frame before the behaviour layer has loaded.
-- They were the whole state once, and the screen duly reported a wedge as a line and a
-- company holding fire as firing at will. See docs/command-ui.md.
BL.state = BL.state or {
    move = "follow", form = "line",
    fire = "on", mount = "off", engage = "default", swarm = "balanced",
    wpnm = "random", wpnr = "bow", outfit = "generic",
}
-- Seventeen wardrobe styles across a six-slot wheel, so it pages five at a time.
BL.outfitPage = BL.outfitPage or 1

-- The binding comes from the atlas so the badge drawn on a button is always the key that
-- actually fires it. Swap a key in tools/make_bl.py BIND and rebuild; every key in
-- BLAtlas.keys already has badge art, so no new images are needed.
BL.keys, BL.keyName = {}, {}
for i, kv in ipairs(mercenaries.BLAtlas and mercenaries.BLAtlas.bind or {}) do
    BL.keys[i], BL.keyName[i] = kv[1], kv[2]
end
BL.hideKey = (mercenaries.BLAtlas and mercenaries.BLAtlas.hideKey or { "f11" })[1]
-- ESC is deliberately NOT taken. A console bind on it closes the interface but the
-- pause menu still opens underneath, and the only map that could stop that is `player`,
-- which costs mouse look. H does open / close / back instead.
BL.escKey = nil
-- Squad selection, direct on 1-4. Those are qam_1..qam_4, and in the field they also DRAW the
-- weapon in that quick slot - the game's `no_qam_weapons` action filter names exactly those
-- actions, but nothing in the retail Lua binding can enable a filter. Until that is solved
-- the draw happens alongside the selection; the Squads wheel is the clean alternative.
BL.selKeys = { "1", "2", "3", "4" }
BL.selAllKey = nil
BL.sel = BL.sel or { true, true, true, true, true }
local RETURN_SLOT = (mercenaries.BLAtlas and mercenaries.BLAtlas.returnSlot) or 8

-- ---------------------------------------------------------------- clip plumbing

-- SetScale and SetAlpha are PERCENT, and the atlas bakes a 1/ss shrink into every clip's
-- authored matrix, so a scale call has to re-apply that shrink or the clip jumps to ss
-- times its intended size.
local function sc(m) return m * 100.0 / atlas().ss end

-- One pcall per call, and SetVisible FIRST.
--
-- This used to be a single pcall with SetVisible last, which turns any throw in SetPos or
-- SetScale into a clip that is never made visible - and because BL.frame[name] is recorded
-- either way, sweep() then promotes it into BL.shown and no later frame calls SetVisible
-- again either. The screen stays invisible for good, except for whatever was placed with no
-- scale at all. On this screen that is exactly one thing, the corner prompt, which is how
-- "pressing H only shows the close prompt" happens with nothing in the log.
local function place(name, x, y, m, sy, a)
    if not BL.shown[name] then
        pcall(function() UIAction.SetVisible(EL, -1, name, true) end)
    end
    pcall(function() UIAction.SetPos(EL, -1, name, { x = x, y = y, z = 0 }) end)
    if m then
        pcall(function()
            UIAction.SetScale(EL, -1, name, { x = sc(m), y = sc(sy or m), z = 100 })
        end)
    end
    if a then
        pcall(function() UIAction.SetAlpha(EL, -1, name, a * 100) end)
    end
    BL.frame[name] = true
end

local function sweep()
    for name in pairs(BL.shown) do
        if not BL.frame[name] then
            pcall(function() UIAction.SetVisible(EL, -1, name, false) end)
        end
    end
    BL.shown, BL.frame = BL.frame, {}
end

-- Forward declarations. These are defined further down but referenced by the layout above
-- it; a Lua local is only in scope AFTER its declaration, so without these they resolve to
-- nil globals and the call silently does nothing.
local applySlowmo
local applyQamBlock
local setMaps
local takeKey, giveKey

-- ---------------------------------------------------------------- content

-- Replace this to drive the cards off the real company. Every field is optional; type must
-- be one of BLAtlas.troopTypes and order one of the movement keys.
mercenaries.BLSquadSource = mercenaries.BLSquadSource or function()
    return {
        { type = "infantry", count = 12, hp = 1.00, order = "charge",   sel = true },
        { type = "infantry", count = 11, hp = 0.82, order = "charge" },
        { type = "archer",   count = 9,  hp = 0.55, order = "follow" },
        { type = "archer",   count = 8,  hp = 0.30, order = "stop" },
    }
end

-- Which wheel a bottom button opens. Weapons is the one that depends on context: archers
-- draw from mercenaries.ArcherWeaponSets, everyone else from mercenaries.WeaponSets.
local function wheelFor(slot)
    if slot == "move" or slot == "form" then return slot end
    if slot == "toggle" then return "tog" end
    if slot == "outfit" then return "outfit" end
    if slot == "weapons" then
        local squads = mercenaries.BLSquadSource() or {}
        for i = 1, #squads do
            if BL.sel[i] and squads[i] then
                local t = squads[i].type
                if t == "archer" or t == "crossbow" or t == "handcannon" then return "wpnr" end
                return "wpnm"
            end
        end
        return "wpnm"
    end
    return nil
end

local function wheelItems(cat)
    local A, out = atlas(), {}
    local simple = A.wheels and A.wheels[cat]
    if simple then
        local live = BL.state[cat]
        for _, e in ipairs(simple) do
            out[#out + 1] = {
                icon = "i_" .. cat .. "_" .. e.key, label = "t_" .. cat .. "_" .. e.key,
                sel = (e.key == live), act = e.key, kind = cat,
            }
        end
        return out
    end
    local ent = A.stateWheels and A.stateWheels[cat]
    if not ent then return out end
    local per = A.outfitPage or 5
    for i, e in ipairs(ent) do
        local st, sel
        if cat == "outfit" and e.slot ~= "return" and e.slot ~= "more" then
            -- an outfit slot shows whichever style this page puts there
            local idx = (BL.outfitPage - 1) * per + i
            local o = e.states[idx]
            if not o then
                out[#out + 1] = { empty = true, kind = cat, index = i }
                st = nil
            else
                st = o
                sel = (o.key == BL.state.outfit)
            end
        else
            local live = BL.state[e.slot] or e.states[1].key
            st = e.states[1]
            for _, c in ipairs(e.states) do if c.key == live then st = c end end
            sel = mercenaries:BLLit(e.slot)
        end
        if st ~= nil then
            out[#out + 1] = {
                icon = "i_" .. cat .. "_" .. e.slot .. "_" .. st.key,
                label = "t_" .. cat .. "_" .. e.slot .. "_" .. st.key,
                -- An OUTFIT slot is addressed by the style it shows; a TOGGLE slot is
                -- addressed by the slot being cycled, never by whichever state it happens to
                -- be displaying. Taking st.key for both is what stopped every toggle working:
                -- BLCycle("on") matches no slot and quietly does nothing.
                sel = sel, act = (cat == "outfit") and st.key or e.slot,
                kind = cat, index = i,
            }
        end
    end
    return out
end

local function bottomVariant(b)
    if b.src == "move" or b.src == "form" then return BL.state[b.src] end
    if b.src == "state" then return BL.state[b.slot] end
    return b.variants[1].key
end

local function isWheelSlot(slot)
    return wheelFor(slot) ~= nil
end

-- Which entries wear the gold ring. Engagement and swarm are multi-state settings rather
-- than on/off, so only their non-default states read as "active".
function mercenaries:BLLit(slot)
    local v = BL.state[slot]
    if slot == "engage" then return v ~= nil and v ~= "default" end
    if slot == "swarm" then return v ~= nil and v ~= "balanced" end
    return v == "on"
end

-- ---------------------------------------------------------------- the key prompts
--
-- The mod draws NOTHING while both screens are closed. There used to be a permanent corner
-- column - [U] Camp over [H] Command - and it was the loudest complaint this mod has had:
-- a mark on the HUD in every moment of play, saying something you learn once and then know
-- for good. Moving it out of KCD2's own message corner helped; making it hideable helped
-- the handful of players who read a console command. Neither was the answer. It is gone.
--
-- What is left is one prompt saying how to CLOSE the screen you are looking at, and it is
-- only on screen while that screen is. The keys themselves live on the mod page, in
-- merc_help, and in the quartermaster's dialogue.
--
--   merc_hints on|off              the close prompts
--   merc_hints_pos <where>         topright (default) | compass | topleft
--                                  | bottomright | bottomleft
--   merc_hints_pos <x> <y>         anywhere, in stage units on a 1280x720 stage
--
-- The position governs the command interface's prompt. The camp screen's own panels fill
-- that corner, so its prompt has a fixed home beside the compass (HintOpenXY).
mercenaries.HintsOn = (mercenaries.HintsOn ~= false)
mercenaries.HintCorner = mercenaries.HintCorner or "topright"
mercenaries.HintAt = mercenaries.HintAt or nil          -- set only by an explicit x y

-- Each named position is a pair of atlas keys, so the geometry stays in the generated
-- table and adding a position is one row here plus one number in each builder.
local CORNERS = {
    compass     = { "hintCompassX", "hintTopY" },
    topright    = { "hintRightX",   "hintTopY" },
    topleft     = { "hintLeftX",    "hintTopY" },
    bottomright = { "hintRightX",   "hintBottomY" },
    bottomleft  = { "hintLeftX",    "hintBottomY" },
}
-- Only reached if the atlas is older than this file; every value is a row's RIGHT EDGE.
local FALLBACK = { hintCompassX = 865, hintRightX = 1262, hintLeftX = 200,
                   hintTopY = 32, hintBottomY = 618 }
local hintLoaded = false

function mercenaries:HintLoad()
    if hintLoaded then return end
    hintLoaded = true
    local v
    pcall(function() v = self:LoadString("MercHints") end)
    if v == "0" then self.HintsOn = false elseif v == "1" then self.HintsOn = true end
    local p
    pcall(function() p = self:LoadString("MercHintPos") end)
    p = tostring(p or "")
    if CORNERS[p] then
        self.HintCorner, self.HintAt = p, nil
    else
        local x, y = string.match(p, "^(-?%d+)%s+(-?%d+)$")
        if x then self.HintAt = { x = tonumber(x), y = tonumber(y) } end
    end
end

-- Where this screen's row of the column goes. The anchors come from the atlas so the two
-- screens cannot drift apart, and hintRowDY says which row of the column this screen is.
function mercenaries:HintRowXY(L)
    self:HintLoad()
    local dy = L.hintRowDY or 0
    if self.HintAt then return self.HintAt.x, self.HintAt.y + dy end
    local p = CORNERS[self.HintCorner] or CORNERS.topright
    local x = L[p[1]] or FALLBACK[p[1]]
    local y = L[p[2]] or FALLBACK[p[2]]
    return x, y + dy
end

-- Where a Close prompt goes when its screen covers the corner the player chose.
--
-- Only the camp screen needs it: both of its modes fill the top right from y=20 down, so
-- the chosen corner would put the prompt half on top of the logistics panel. Beside the
-- compass is free - the bar ends at x=749, and the camp's panels leave the gap between
-- them (326..954) empty. It lives here rather than in the camp driver because the anchors
-- it reads are the shared ones.
--
-- hintRowDY is deliberately ignored: only one prompt is on screen while the camp screen is
-- open, so there is no column to be the second row of.
function mercenaries:HintOpenXY(L)
    return (L.hintCompassX or 865), (L.hintTopY or 32)
end

-- The setting is shared, so whichever screen is currently drawing has to be told - and the
-- only prompt left is the close one, which is only ever on screen while its interface is
-- open. *HintUpdate is the closed-state path and returns immediately when its screen is up,
-- so an open screen has to be relaid out directly.
function mercenaries:HintsRefresh()
    if mercenaries.BL and mercenaries.BL.on then
        pcall(function() self:BLLayout() end)
    else
        pcall(function() self:BLHintUpdate() end)
    end
    if mercenaries.CU and mercenaries.CU.on then
        pcall(function() self:CULayout() end)
    else
        pcall(function() self:CUHintUpdate() end)
    end
end

function mercenaries:HintsSet(arg)
    self:HintLoad()
    local v = string.gsub(string.lower(unquote(arg)), "%s", "")
    if v == "on" or v == "1" then self.HintsOn = true
    elseif v == "off" or v == "0" then self.HintsOn = false
    else self.HintsOn = not self.HintsOn end
    pcall(function() self:SaveString("MercHints", self.HintsOn and "1" or "0") end)
    self:HintsRefresh()
    log("corner hints " .. (self.HintsOn and "on" or "off")
        .. " (the H / U keys still work either way)")
end

function mercenaries:HintsPos(arg)
    self:HintLoad()
    local a = string.lower(unquote(arg))
    a = string.gsub(string.gsub(a, "^%s+", ""), "%s+$", "")
    local x, y = string.match(a, "^(-?%d+)[%s,]+(-?%d+)$")
    if x then
        self.HintAt = { x = tonumber(x), y = tonumber(y) }
        pcall(function() self:SaveString("MercHintPos", x .. " " .. y) end)
    elseif CORNERS[a] then
        self.HintCorner, self.HintAt = a, nil
        pcall(function() self:SaveString("MercHintPos", a) end)
    else
        log("usage: merc_hints_pos <compass|topright|topleft|bottomright|bottomleft>,"
            .. " or an x and a y on a 1280x720 stage")
        return
    end
    self:HintsRefresh()
    log("corner hints at " ..
        (self.HintAt and (self.HintAt.x .. " " .. self.HintAt.y) or self.HintCorner))
end

-- The quartermaster's menu hands the choice over as a count, so it needs no console:
-- 1 on, 2 off, 3 top right, 4 bottom right, 5 beside the compass. Picking a position also
-- turns them back on - "move them up there" is not something you ask for while they are
-- hidden.
local BY_INDEX = { [3] = "topright", [4] = "bottomright", [5] = "compass" }

function mercenaries:HintsSetByIndex(n)
    n = tonumber(n) or 0
    if n == 1 then
        self:HintsSet("on")
    elseif n == 2 then
        self:HintsSet("off")
    elseif BY_INDEX[n] then
        if not self.HintsOn then self:HintsSet("on") end
        self:HintsPos(BY_INDEX[n])
    end
end

-- Per-screen switch, under the shared one: turns off this screen's close prompt on its own.
BL.hintEnabled = (BL.hintEnabled ~= false)
BL.userClosed = BL.userClosed or false

-- The interface does NOT open itself, ever. There is no auto-show path and there must not
-- be one: a screen that appears over the world unasked is a screen you have to close
-- before you can play. The corner nudge says which key brings it up and that is the whole
-- of it.
-- Closed means nothing is DRAWN. The element itself stays loaded, holding no visible
-- clips, because the movie is only built on first display - that is what the deferred first
-- layout in BLShow is for. Tear it down when the screen closes and every press of H is a
-- fresh element paying that 600ms again, which reads as the key not working. Loaded-and-
-- empty is invisible and is what the mod already shipped: the idle prompt kept it up too.
-- There is no idle prompt any more, so this only has to make sure nothing of ours is
-- left on screen. It must NOT load the element: BLOnLoad and CUHide both reach here, and
-- loading from either put the command movie on UI layer 36 alongside the camp one.
-- BLLayout returns immediately unless the element is up, and sweeps when it is.
function mercenaries:BLHintUpdate()
    self:HintLoad()
    if BL.on then return end
    self:BLLayout()
end

function mercenaries:BLHint()
    BL.hintEnabled = not BL.hintEnabled
    self:BLHintUpdate()
    log("command nudge " .. (BL.hintEnabled and "on" or "off"))
end

-- ---------------------------------------------------------------- layout

function mercenaries:BLLayout()
    local A = atlas()
    if not A or not BL.elUp then return end
    local L = A.layout
    BL.frame = {}

    -- Laid out like KCD2's own action hint: the word first, the cap on the right, the
    -- row anchored on its RIGHT EDGE so the caps line up in a straight column whatever
    -- the words do. The letter is baked into the cap art.
    -- This screen's prompt does NOT move when it opens: the cards are on the left and
    -- the button row is at the bottom, so the corner the player chose is still free and a
    -- prompt that jumps for no visible reason is worse than one that stays. Only the camp
    -- screen has to dodge its own panels - see CULayout.
    local function hintRow(lbl)
        local kn = (A.hideKey and A.hideKey[2]) or "H"
        local btn = "hint_btn_" .. kn
        local bw = (A.size[btn] or { w = 21.33 }).w
        local lw = A.size[lbl].w
        local x, y = mercenaries:HintRowXY(L)
        place(btn, x - bw / 2, y)
        place(lbl, x - bw - L.hintGap - lw / 2, y)
    end

    if not BL.on then
        sweep()
        applySlowmo()
        applyQamBlock()
        return
    end
    -- The only thing this mod ever draws outside its own screens is this, and it is not
    -- outside them: it says what closes the screen you are already looking at.
    if BL.hintEnabled and (mercenaries.HintsOn ~= false) then hintRow("hint_lbl_close") end

    -- Every draw, before anything is placed: the row and the wheels show the company's live
    -- settings, not the last thing this screen was told. A press writes BL.state
    -- optimistically and then lands in the mod, so this is also what puts the button back if
    -- the order was refused or clamped.
    if mercenaries.BLReadState then
        pcall(function() mercenaries:BLReadState() end)
    end

    local squads = mercenaries.BLSquadSource() or {}
    for i = 1, 5 do
        local s = squads[i]
        if s then
            local p = "c" .. i .. "_"
            local y = L.cardY0 + (i - 1) * L.cardPitch
            local sel = BL.sel[i]
            if sel == nil then sel = s.sel end
            place(p .. (sel and "sel" or "plate"), L.cardX, y)
            place(p .. "wm_" .. (s.type or "infantry"),
                  L.cardX + L.cardW / 2, y + L.cardH / 2 + L.cardWmDY, nil, nil, 0.16)
            place(p .. "ty_" .. (s.type or "infantry"),
                  L.cardX + L.cardIconDX, y + L.cardIconDY)

            local n = tostring(math.max(0, math.min(99, s.count or 0)))
            for d = 1, #n do
                place(p .. "d" .. (d - 1) .. "_" .. string.sub(n, d, d),
                      L.cardX + L.cardCountDX + (d - 1) * 10, y + L.cardCountDY)
            end

            local hx = L.cardX + (L.cardW - L.cardHpW) / 2
            local hy = y + L.cardH + L.cardHpDY
            place(p .. "hpbg", hx, hy)
            local hp = math.max(0, math.min(1, s.hp or 1))
            local band = (hp > 0.6 and "g") or (hp > 0.3 and "a") or "r"
            -- The bar's full width is the squad's strength BEFORE the fight, so the dark
            -- band on the right is the men it has cost so far.
            local dead = math.max(0, s.dead or 0)
            local total = math.max(1, (s.count or 0) + dead)
            local liveFrac = (s.count or 0) / total
            place(p .. "hp_" .. band, hx, hy + 1, liveFrac * hp, 1)
            if dead > 0 then
                place(p .. "hp_dead", hx + L.cardHpW * liveFrac, hy + 1, 1 - liveFrac, 1)
            end

            place(p .. "chip", L.cardX + L.cardChipDX, y + L.cardH / 2)
            place(p .. "num", L.cardX + L.cardChipDX, y + L.cardH / 2)
            if s.order then
                place(p .. "o_" .. s.order, L.cardX + L.cardW / 2, y + L.cardH + L.cardOrderDY)
            end
        end
    end

    local nb = #A.bottom
    local x0 = A.stageW / 2 - (nb - 1) * L.btnPitch / 2
    local openIdx = nil
    for i, b in ipairs(A.bottom) do
        local cx, cy = x0 + (i - 1) * L.btnPitch, L.rowY
        local isOpen = (BL.open == b.slot)
        if isOpen then openIdx = i end
        local m = isOpen and L.btnOpenScale or 1
        local p = "b" .. i .. "_"
        place(p .. ((isOpen or self:BLLit(b.slot)) and "ring" or "disc"), cx, cy, m)
        local v = bottomVariant(b)
        place(p .. "i_" .. v, cx, cy, m)
        place(p .. "t_" .. v, cx, cy + L.btnLabelDY)
        -- While a wheel is open the F-keys address the wheel, so the row drops its badges.
        if not BL.open then
            place(p .. "chip", cx, cy + L.btnBadgeDY)
            place(p .. "k_" .. BL.keyName[i], cx, cy + L.btnBadgeDY)
        end
    end

    if BL.open and openIdx then
        local items = wheelItems(wheelFor(BL.open))
        local cx0 = x0 + (openIdx - 1) * L.btnPitch
        local cy0 = L.rowY + L.wheelDY
        place("vig", cx0, cy0)
        local n = #items
        for j, it in ipairs(items) do
            if not it.empty then
            local ang = -math.pi / 2 + 2 * math.pi * (j - 1) / n
            local cx = cx0 + math.cos(ang) * L.wheelR
            local cy = cy0 + math.sin(ang) * L.wheelR
            local m = it.sel and L.wheelSelScale or 1
            local p = "w" .. j .. "_"
            place(p .. (it.sel and "ring" or "disc"), cx, cy, m)
            place(p .. it.icon, cx, cy, m)
            place(p .. it.label, cx, cy + L.wheelLabelDY)
            place(p .. "chip", cx, cy + L.wheelBadgeDY)
            local ki = (j == n) and RETURN_SLOT or j
            place(p .. "k_" .. BL.keyName[ki], cx, cy + L.wheelBadgeDY)
            end
        end
    end

    sweep()
    applySlowmo()
    applyQamBlock()
end

-- ---------------------------------------------------------------- input

function mercenaries:BLKey(i)
    -- BL.keys is 5,6,7,8,9,0,n,h - so slot i here is the camp screen's slot i+4.
    if mercenaries.CU and (mercenaries.CU.on or mercenaries.CU.placing) and i <= 6 then
        return self:CUKey(i + 4)
    end
    local A = atlas()
    if not A or not BL.on then return end
    if BL.open then
        local items = wheelItems(wheelFor(BL.open))
        local n = #items
        -- Return keeps the reserved last key whatever the wheel's length, so a key that
        -- lands past the last order does nothing rather than aliasing onto Return.
        local j = (i == RETURN_SLOT) and n or i
        if i ~= RETURN_SLOT and i >= n then return end
        local it = items[j]
        if not it or it.empty then return end
        if it.act == "return" then
            BL.open = nil
        elseif it.kind == "outfit" then
            if it.act == "more" then
                -- step to the next page; the wheel stays open
                local pages = math.ceil(#(A.stateWheels.outfit[1].states) / (A.outfitPage or 5))
                BL.outfitPage = (BL.outfitPage % pages) + 1
            else
                BL.state.outfit = it.act
                BL.open = nil
                if mercenaries.BLOutfit then
                    pcall(function() mercenaries:BLOutfit(it.act) end)
                end
            end
        elseif it.kind == "tog" then
            self:BLCycle(it.act)
            if mercenaries.BLToggleApply then
                pcall(function() mercenaries:BLToggleApply(it.act, BL.state[it.act]) end)
            end
        elseif it.kind == "wpnm" or it.kind == "wpnr" then
            BL.state[it.kind] = it.act
            BL.open = nil
            if mercenaries.BLWeapons then
                pcall(function() mercenaries:BLWeapons(it.act) end)
            end
        else
            BL.state[it.kind] = it.act
            BL.open = nil
            -- hand the movement and formation wheels to the behaviour layer
            if it.kind == "move" and mercenaries.BLOrder then
                pcall(function() mercenaries:BLOrder(it.act) end)
            elseif it.kind == "form" and mercenaries.BLFormation then
                pcall(function() mercenaries:BLFormation(it.act) end)
            end
        end
    else
        local b = A.bottom[i]
        if not b then return end
        if isWheelSlot(b.slot) then
            BL.open = b.slot
        elseif b.slot == "camp" and mercenaries.BLCamp then
            pcall(function() mercenaries:BLCamp() end)
        else
            self:BLCycle(b.slot)
            if mercenaries.BLToggleApply then
                pcall(function() mercenaries:BLToggleApply(b.slot, BL.state[b.slot]) end)
            end
        end
    end
    self:BLLayout()
end

-- Step a stateful entry to its next state. Two-state entries read as a toggle; aggression
-- has three.
function mercenaries:BLCycle(slot)
    local A = atlas()
    for _, e in ipairs(A.stateWheels and A.stateWheels.tog or {}) do
        if e.slot == slot then
            local live, at = BL.state[slot] or e.states[1].key, 1
            for k, c in ipairs(e.states) do if c.key == live then at = k end end
            BL.state[slot] = e.states[(at % #e.states) + 1].key
            return
        end
    end
    log("BLCycle: no toggle slot named '" .. tostring(slot) .. "'")
end

-- ---------------------------------------------------------------- qam block
--
-- Squad selection sits on 1-4, which are qam_1..qam_4 - in the field those unsheathe the
-- weapon in that quick slot. Blocking them is an ACTION FILTER, and Lua cannot enable one:
-- EnableActionFilter was removed from the binding before release. The only live route is the
-- Skald node FilterInput, so the bridge is the one this mod already uses elsewhere - Lua puts
-- a weightless marker item in the player's inventory and an ItemDescriptorTrigger in
-- mercenaries_background_quest.xml turns the filter on and off with it.
--
-- Gate: "shown" blocks for as long as the interface is up (1-4 are ours then), "wheel" only
-- while an order is being picked, "off" never.

BL.qamToken = BL.qamToken or "679a655e-189d-4519-b437-ccc4b92bef3d"
BL.qamGate = BL.qamGate or "shown"
BL.qamBlocked = BL.qamBlocked or false

local function qamWant()
    if BL.qamGate == "off" or not BL.on then return false end
    if BL.qamGate == "wheel" then return BL.open ~= nil end
    return true
end

-- Only ever called on a transition: adding and removing an item every layout would churn the
-- inventory dozens of times a second.
applyQamBlock = function()
    local want = qamWant()
    if want == BL.qamBlocked then return end
    BL.qamBlocked = want
    pcall(function()
        if want then
            player.inventory:CreateItem(BL.qamToken, 1, 1)
        else
            player.inventory:DeleteItemOfClass(BL.qamToken, 99)
        end
    end)
end

-- A crash or an alt-F4 with the interface open would otherwise leave the token - and so the
-- filter - stuck on. Cleared unconditionally on every gameplay start.
function mercenaries:BLClearQamBlock()
    BL.qamBlocked = false
    pcall(function() player.inventory:DeleteItemOfClass(BL.qamToken, 99) end)
end

function mercenaries:BLQam(arg)
    local v = unquote(arg)
    if v == "shown" or v == "wheel" or v == "off" then BL.qamGate = v end
    applyQamBlock()
    log("quick-slot block: " .. BL.qamGate .. " (currently " ..
        (BL.qamBlocked and "on" or "off") .. ")")
end

-- ---------------------------------------------------------------- input filter probe
--
-- Blocking the quick-slot weapon draw on 1-4 is an ACTION FILTER, not an action map. The
-- game ships `no_qam_weapons` for exactly this, but it also covers `toggle_holster_qam_weapon`
-- (the B key), so using it costs the player their weapon wheel. Libs/Config/mercenaries_input.xml
-- declares a narrower `merc_no_qam_slots` instead.
--
-- Two unknowns, and this probe answers both without touching the quest graph:
--   1. does ActionMapManager.LoadFromXML accept a file containing only <actionfilter> blocks?
--   2. is IsFilterEnabled able to see a filter registered that way?
--
-- Nothing here ENABLES a filter - EnableActionFilter was removed from the Lua binding before
-- release (it is in Warhorse's own 2023 scriptbind changelog as `removed`, and the string is
-- absent from WHGame.dll). The only live route is the Skald quest node `FilterInput`, which
-- the base game uses 94 times, 8 of them on no_qam_weapons.

BL.filterFile = BL.filterFile or "Libs/Config/mercenaries_input.xml"
BL.filterName = BL.filterName or "merc_no_qam_slots"

function mercenaries:BLFilterProbe()
    if not ActionMapManager then log("no ActionMapManager global") return end
    local function state(n)
        local ok, v = pcall(function() return ActionMapManager.IsFilterEnabled(n) end)
        return ok and tostring(v) or ("error: " .. tostring(v))
    end
    log("before load:  " .. BL.filterName .. " -> " .. state(BL.filterName))
    log("vanilla ref:  no_qam_weapons -> " .. state("no_qam_weapons"))
    local ok, err = pcall(function() ActionMapManager.LoadFromXML(BL.filterFile) end)
    log("LoadFromXML(" .. BL.filterFile .. ") -> " .. (ok and "no error" or tostring(err)))
    log("after load:   " .. BL.filterName .. " -> " .. state(BL.filterName))
    log("If the two " .. BL.filterName .. " lines differ, or the second is a boolean rather")
    log("than an error, the custom filter registered and the Skald FilterInput node can drive it.")
end

-- ---------------------------------------------------------------- slow motion
--
-- t_GameScale is stock CryEngine's own "Game time scaled by this - for variable slow
-- motion". It is not cheat-gated (flags 0x84 share no bits with the console's 0x3000002
-- cheat mask, and ICVar::Set has no gate of its own), and KCD2 never writes it - the game's
-- Master Strike and Perfect Block are parry-timing windows, not time dilation - so nothing
-- else is competing for it.
--
-- t_GameScale is scoped to game time; t_Scale is "All times" and also drags the UI. Set
-- BL.slowmo to 1 to turn the effect off.

BL.slowmo = BL.slowmo or 0.30
-- t_GameScale is scoped to game time; t_Scale is "All times" and drags the UI with it.
BL.timeCvar = BL.timeCvar or "t_GameScale"


local curScale = 1.0
local function timeScale(v)
    if math.abs(v - curScale) < 0.001 then return end
    curScale = v
    pcall(function() System.SetCVar(BL.timeCvar, v) end)
end

-- The interface is on permanently now, so the slow-down follows the WHEEL, not the bar:
-- time only stretches while an order is actually being picked.
--
-- MEASURED: something in the engine restores t_GameScale about ten seconds after it is
-- written, so a single write is not enough - it has to be re-asserted while the wheel is
-- open. The refresh chain is generation-guarded and dies the moment the wheel closes, so it
-- never outlives the order being given and never accumulates into a save.
local SLOW_REFRESH = 1000
local slowChain = false                 -- exactly one refresh chain may be in flight

mercenaries.BLSlowTick = function()
    if not (BL.on and BL.open and BL.slowmo < 1) then
        slowChain = false               -- wheel closed: let the chain end here
        return
    end
    curScale = -1                       -- the engine may have reset it behind our back
    timeScale(BL.slowmo)
    Script.SetTimerForFunction(SLOW_REFRESH, "mercenaries.BLSlowTick")
end

applySlowmo = function()
    local want = (BL.on and BL.open and BL.slowmo < 1) and BL.slowmo or 1.0
    timeScale(want)
    if want < 1 and not slowChain then
        slowChain = true
        Script.SetTimerForFunction(SLOW_REFRESH, "mercenaries.BLSlowTick")
    end
end

-- Time scale is global engine state, so anything that can leave the interface without
-- running BLHide - a crash, an alt-F4, a load from a save taken while it was open - would
-- otherwise strand the game in slow motion. Reset it on every gameplay start.
function mercenaries:BLResetGlobals()
    self:BLClearQamBlock()
    curScale = -1               -- the engine cvar may be stale after a load; always write
    timeScale(1.0)
    setMaps(true)
end

-- Console binds and timers both die with the level, so the interface re-arms itself on every
-- gameplay start rather than needing merc_bl_keys typed once per session.
function mercenaries:BLOnLoad()
    self:BLResetGlobals()
    if self.BLOrdersOnLoad then pcall(function() self:BLOrdersOnLoad() end) end
    BL.held, BL.on, BL.open, BL.userClosed = {}, false, nil, false
    BL.elUp, BL.shown, BL.frame = false, {}, {}
    -- A key the player chose (merc_cmd_key) beats the shipped one.
    local ov = self.UiKeyLoad and self:UiKeyLoad("MercCmdKey")
    if ov then
        BL.hideKey = ov
        if self.BLAtlas then self.BLAtlas.hideKey = { ov, string.upper(ov) } end
    end
    takeKey(BL.hideKey, "merc_bl")
    self:HintLoad()
    self:BLHintUpdate()
end

function mercenaries:BLModal()
    BL.modal = not BL.modal
    if BL.on then setMaps(false) end
    log("modal input " .. (BL.modal and "ON - movement and the pause menu are suppressed"
        or "off - gameplay keys stay live"))
end

function mercenaries:BLSlowmo(arg)
    local v = tonumber(unquote(arg))
    if v then BL.slowmo = math.max(0.05, math.min(1.0, v)) end
    applySlowmo()
    log("slow motion " .. (BL.slowmo >= 1 and "off" or ("x" .. BL.slowmo))
        .. "  (" .. BL.timeCvar .. ")")
end

-- ---------------------------------------------------------------- action maps
--
-- KCD2's gameplay keys are not console binds - they are CryEngine action maps, declared in
-- Libs/Config/defaultProfile.xml with a priority tier and an exclusivity flag, and resolved
-- to physical keys through Libs/Config/keybindSuperactions.xml.
--
-- The number row is superactions qam_1..qam_8, and each one fires TWO actions: action_qam_N
-- in map `qam_init` (the weapon/food quick-access wheel, pure_include'd into the base player
-- map) and weapon_slot_N / food_slot_N in map `apse_qam_slots`. ESC is superaction `back`,
-- which fans out to `open_menu` and `open_pause_menu` among others.
--
-- So rather than out-binding those keys and hoping we win the race, we disable the maps that
-- own the competing actions. That removes the other listener instead of racing it, and it is
-- reversible. ActionMapManager.EnableActionMap is a confirmed-live retail script bind;
-- EnableActionFilter is NOT - the string does not appear anywhere in WHGame.dll - so filters
-- are query-only and action maps are the route.

-- MEASURED, twice: EnableActionMap does nothing to a map whose priority is `pure_include`.
-- The name is literal - those maps exist only to be <include>d into others and are never
-- enabled as units. `qam_init`, `open_apse_keyboard`, `open_menu`, `open_pause_menu` and
-- `open_skiptime` are all pure_include, and every one of them chains up into `player`, so
-- `player` is the only enable-able map that actually owns those keys.
--
-- Modal mode suppresses `player` and does work - but `player` owns the camera, so it takes
-- MOUSE LOOK with it. That is why it is off by default and why the order keys have to be
-- keys the game does not want in the first place rather than keys we take back.
BL.suppress = BL.suppress or {}       -- maps suppressed regardless of modal mode
BL.modal = BL.modal or false
BL.modalMaps = BL.modalMaps or { "player" }

setMaps = function(on)
    if not ActionMapManager then return end
    for _, m in ipairs(BL.suppress) do
        pcall(function() ActionMapManager.EnableActionMap(m, on) end)
    end
    -- Re-enabling is unconditional: if modal mode was on when the interface opened and got
    -- switched off before it closed, the maps still have to come back.
    if on or BL.modal then
        for _, m in ipairs(BL.modalMaps) do
            pcall(function() ActionMapManager.EnableActionMap(m, on) end)
        end
    end
end

-- ---------------------------------------------------------------- key ownership
--
-- The command keys are held only while the interface is VISIBLE. The moment it hides they
-- go back to whatever the game or another mod had on them. Only the show/hide key is held
-- for the whole session, because something has to bring the interface back.
--
-- The engine's bind table keeps no history: `bind` overwrites and `unbind` leaves the key
-- dead, so releasing a key cannot by itself restore a binding another mod installed. List
-- any such binding in BLRestore and it is re-issued when we hand the key back.
--
--     mercenaries.BLRestore = { f4 = "wh_camera_thirdperson_toggle" }

mercenaries.BLRestore = mercenaries.BLRestore or {}
BL.held = BL.held or {}

-- Console binds are the standalone fallback. With KCD2 Keybinder installed the commands
-- below are assigned through the game's own keybind options instead, which is conflict-free
-- because it is the same system every other mod and the base game use - set this false then.
BL.useConsoleBinds = (BL.useConsoleBinds ~= false)

takeKey = function(k, cmd)
    if not BL.useConsoleBinds or BL.held[k] then return end
    pcall(function() System.ExecuteCommand("bind " .. k .. " " .. cmd) end)
    BL.held[k] = true
end

giveKey = function(k)
    if not BL.held[k] then return end
    BL.held[k] = nil
    local back = mercenaries.BLRestore[k]
    pcall(function()
        if back then
            System.ExecuteCommand("bind " .. k .. " " .. back)
        else
            System.ExecuteCommand("bind " .. k .. " merc_noop") -- the console has no unbind
        end
    end)
end

-- Held only while the interface is on screen.
function mercenaries:BLAcquireKeys()
    for i, k in ipairs(BL.keys) do
        if k ~= BL.hideKey then takeKey(k, "merc_bl_k" .. i) end
    end
    for i, k in ipairs(BL.selKeys) do
        takeKey(k, "merc_bl_sel" .. i)
        takeKey("np_" .. k, "merc_bl_sel" .. i)
    end
    if BL.selAllKey then
        takeKey(BL.selAllKey, "merc_bl_sel0")
        takeKey("np_" .. BL.selAllKey, "merc_bl_sel0")
    end
    if BL.escKey then takeKey(BL.escKey, "merc_bl_esc") end
    setMaps(false)
end

function mercenaries:BLReleaseKeys()
    setMaps(true)
    for _, k in ipairs(BL.keys) do
        if k ~= BL.hideKey then giveKey(k) end
    end
    for _, k in ipairs(BL.selKeys) do giveKey(k) giveKey("np_" .. k) end
    if BL.selAllKey then
        giveKey(BL.selAllKey)
        giveKey("np_" .. BL.selAllKey)
    end
    if BL.escKey then giveKey(BL.escKey) end
end

-- Toggle one squad, or 0 for all / none.
function mercenaries:BLSelect(i)
    -- BL.selKeys is 1,2,3,4 - the camp screen's first four slots.
    if mercenaries.CU and (mercenaries.CU.on or mercenaries.CU.placing)
       and i >= 1 and i <= 4 then
        return self:CUKey(i)
    end
    if not BL.on then return end
    if i == 0 then
        local any = false
        for n = 1, 5 do if BL.sel[n] then any = true end end
        for n = 1, 5 do BL.sel[n] = not any end
    else
        BL.sel[i] = not BL.sel[i]
    end
    self:BLLayout()
end

function mercenaries:BLKeys()
    takeKey(BL.hideKey, "merc_bl")
    log("keys: " .. table.concat(BL.keyName, " ") .. " while shown; "
        .. string.upper(BL.hideKey) .. " show/hide; ESC closes")
    log("  wheel: same keys, " .. BL.keyName[RETURN_SLOT] .. " is always Return")
    if not BL.on then self:BLShow() end
end

function mercenaries:BLRelease()
    self:BLReleaseKeys()
    giveKey(BL.hideKey)
end

-- ---------------------------------------------------------------- show / hide

-- The element carries both the interface and the idle hint, so it stays up whenever either
-- one wants to draw and is only torn down when neither does.
function mercenaries:BLElement(want)
    if want == BL.elUp then return false end
    if want then
        pcall(function() System.SetCVar("wh_gfx_useSWF", 1) end)
        pcall(function() UIAction.UnloadElement(EL, -1) end)
        pcall(function() UIAction.ReloadElement(EL, -1) end)
        local ok, err = pcall(function() UIAction.ShowElement(EL, 0) end)
        BL.elUp, BL.shown, BL.frame = true, {}, {}
        log("ShowElement -> " .. (ok and "ok" or tostring(err)))
        return true                     -- caller must defer its first layout
    end
    BL.elUp, BL.shown, BL.frame = false, {}, {}
    pcall(function() UIAction.HideElement(EL, 0) end)
    return false
end

function mercenaries:BLShow()
    if not atlas() then log("mercenaries_blatlas.lua did not load - run tools/make_bl.py") return end
    -- One screen at a time. The camp screen does the same to this one in CUShow, and the
    -- two of them up together is not a layout problem so much as an input one: they share
    -- the number row, and which of them a keypress reaches depends on which test runs
    -- first. Closed BEFORE the keys are taken below, because CUReleaseKeys hands them back
    -- to the game on its way out.
    if mercenaries.CU and mercenaries.CU.on then
        pcall(function() self:CUHide() end)
    end
    -- ...and take the camp movie off the layer. Both screens live on UI layer 36, and two
    -- loaded elements there do not coexist: until the idle prompt was removed, CUShow took
    -- THIS movie down as a side effect of silencing its prompt, and that side effect was
    -- the only thing keeping one element on the layer at a time.
    if mercenaries.CUElement then
        pcall(function() self:CUElement(false) end)
    end
    local fresh = self:BLElement(true)
    BL.on, BL.open, BL.userClosed = true, nil, false
    self:BLAcquireKeys()
    if fresh then
        -- The movie is built on first display; transforms sent in this same call would
        -- address clips that do not exist yet and silently no-op.
        Script.SetTimerForFunction(600, "mercenaries.BLDeferred")
    else
        self:BLLayout()
    end
end

mercenaries.BLDeferred = function()
    mercenaries:BLLayout()
end

function mercenaries:BLHide()
    BL.on, BL.open, BL.userClosed = false, nil, true
    self:BLReleaseKeys()
    applyQamBlock()
    log("hidden, command keys released")
    self:BLHintUpdate()                 -- falls back to the hint, or tears the element down
end

-- The show/hide key doubles as the wheel's Return, so one key covers all three steps:
-- open, back out of a wheel, close. That is why the Return slot's badge reads H.
function mercenaries:BLToggle()
    if BL.placing and mercenaries.BLPlaceCancel then
        mercenaries:BLPlaceCancel()
        return
    end
    if not BL.on then
        self:BLShow()
    elseif BL.open then
        BL.open = nil
        self:BLLayout()
    else
        self:BLHide()
    end
end

-- ESC backs out of an open wheel first, then closes the interface - so it never takes two
-- presses to get out, and never falls through to the pause menu while we hold it.
function mercenaries:BLEsc()
    if BL.open then BL.open = nil self:BLLayout() else self:BLHide() end
end

function mercenaries:BLOff()
    self:BLHide()
    self:BLRelease()
    log("off, all keys released")
end

-- ---------------------------------------------------------------- dev

local DEMO = 0
function mercenaries:BLDemo()
    DEMO = DEMO + 1
    local types = atlas().troopTypes
    local orders = { "move", "follow", "charge", "fallback", "stop", "retreat" }
    mercenaries.BLSquadSource = function()
        local out = {}
        for i = 1, 5 do
            out[i] = {
                type = types[((DEMO + i) % #types) + 1],
                count = ((DEMO * 7 + i * 13) % 40) + 1,
                hp = ((DEMO * 17 + i * 29) % 100) / 100,
                order = orders[((DEMO + i) % #orders) + 1],
                sel = (i == ((DEMO % 5) + 1)),
            }
        end
        return out
    end
    self:BLLayout()
    log("demo roster " .. DEMO)
end

-- ---------------------------------------------------------------- KCD2 Keybinder
--
-- KCD2 Keybinder scans mod Lua for these annotations, merges what it finds into the game's
-- own Libs/Config/defaultProfile.xml and keybindSuperactions.xml, and writes the result as a
-- generated pak. The commands then become real action-map actions the player assigns in the
-- game's keybind options - so two mods can no longer silently take the same F-key, which is
-- what console binds do.
--
-- It matches ---@bindingMap <word> and ---@bindingCommand <word>, one per line. The pair is
-- repeated per command so it reads correctly whether the tool scopes the map per file or
-- per command.

--- @bindingMap mercenaries
--- @bindingCommand merc_bl
--- @bindingMap mercenaries
--- @bindingCommand merc_bl_esc
--- @bindingMap mercenaries
--- @bindingCommand merc_bl_k1
--- @bindingMap mercenaries
--- @bindingCommand merc_bl_k2
--- @bindingMap mercenaries
--- @bindingCommand merc_bl_k3
--- @bindingMap mercenaries
--- @bindingCommand merc_bl_k4
--- @bindingMap mercenaries
--- @bindingCommand merc_bl_k5
--- @bindingMap mercenaries
--- @bindingCommand merc_bl_k6
--- @bindingMap mercenaries
--- @bindingCommand merc_bl_k7
--- @bindingMap mercenaries
--- @bindingCommand merc_bl_k8
--- @bindingMap mercenaries
--- @bindingCommand merc_bl_sel0
--- @bindingMap mercenaries
--- @bindingCommand merc_bl_sel1
--- @bindingMap mercenaries
--- @bindingCommand merc_bl_sel2
--- @bindingMap mercenaries
--- @bindingCommand merc_bl_sel3
--- @bindingMap mercenaries
--- @bindingCommand merc_bl_sel4
--- @bindingMap mercenaries
--- @bindingCommand merc_bl_sel5

mercenaries:PlayerCommand("merc_bl",      "mercenaries:BLToggle()", "Show/hide the command interface")
mercenaries:PlayerCommand("merc_bl_keys", "mercenaries:BLKeys()",   "Bind the keys and show the interface")
mercenaries:PlayerCommand("merc_bl_off",  "mercenaries:BLOff()",    "Hide the interface and release the keys")
mercenaries:PlayerCommand("merc_bl_esc",  "mercenaries:BLEsc()",    "Back out of a wheel, or close the interface")
for i = 0, 5 do
    mercenaries:PlayerCommand("merc_bl_sel" .. i, "mercenaries:BLSelect(" .. i .. ")",
                           i == 0 and "Select all squads / none" or ("Toggle squad " .. i))
end
mercenaries:PlayerCommand("merc_bl_qam",    "mercenaries:BLQam('%line')",
                       "Quick-slot weapon block while the interface is up: <shown|wheel|off>")
mercenaries:DevCommand("merc_bl_filter", "mercenaries:BLFilterProbe()",
                       "Probe whether a custom action filter can be registered at runtime")
mercenaries:PlayerCommand("merc_bl_hint",   "mercenaries:BLHint()",
                       "Toggle just the [H] Command nudge")
mercenaries:PlayerCommand("merc_hints", "mercenaries:HintsSet('%line')",
                       "Corner key nudges: <on|off>, blank toggles. Saved with the game")
mercenaries:PlayerCommand("merc_hints_pos", "mercenaries:HintsPos('%line')",
                       "Move them: <compass|topright|topleft|bottomright|bottomleft> or <x> <y>")
mercenaries:PlayerCommand("merc_bl_modal",  "mercenaries:BLModal()",
                       "Toggle modal input: suppress the base player map while the UI is up")
mercenaries:PlayerCommand("merc_bl_slowmo", "mercenaries:BLSlowmo('%line')",
                       "Time scale while the interface is up: <0.05-1.0>, 1 = off")
mercenaries:DevCommand("merc_bl_demo", "mercenaries:BLDemo()",   "Cycle the placeholder squad roster")
for i = 1, 8 do
    mercenaries:PlayerCommand("merc_bl_k" .. i, "mercenaries:BLKey(" .. i .. ")",
                           "Command slot " .. i)
end

-- merc_cmd_key <key>: rebind the command screen. Takes effect now and is kept with the save.
function mercenaries:BLKeySet(line)
    -- The console hands %line back quoted ("j", quotes included); CmdClean takes them off.
    local raw = self.CmdClean and self:CmdClean(line) or tostring(line or "")
    local k = string.match(raw, "%S+")
    if not k or k == "%line" then
        System.LogAlways("[BL] the command screen is on '" .. tostring(BL.hideKey) .. "' - merc_cmd_key <key> to change it")
        return
    end
    k = string.lower(k)
    if not string.match(k, "^[%w_]+$") then System.LogAlways("[BL] '" .. k .. "' is not a key name"); return end
    if BL.held[BL.hideKey] then giveKey(BL.hideKey) end
    pcall(function() self:SaveString("MercCmdKey", k) end)
    BL.hideKey = k
    if self.BLAtlas then self.BLAtlas.hideKey = { k, string.upper(k) } end
    takeKey(k, "merc_bl")
    pcall(function() self:BLHintUpdate() end)
    System.LogAlways("[BL] command screen key is now '" .. k .. "'")
end
