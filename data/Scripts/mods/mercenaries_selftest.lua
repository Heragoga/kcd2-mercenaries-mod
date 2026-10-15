-- Pre-release self-test: `merc_selftest`.
--
-- Two halves. AUTOMATED checks run first and instantly - pure Lua, nothing spawned - and
-- print PASS/FAIL lines. Then the VISUAL steps: each one spawns something a few metres in
-- front of the player, puts a caption on screen saying what to look for, and waits for a
-- verdict (numpad 1 = looks right, numpad 3 = wrong, or merc_selftest_ok / _bad / _skip)
-- or StepSecs, whichever comes first. Its spawns are removed before the next step starts,
-- and everything is tracked through the test-reset registry, so a load mid-run cleans up.
--
-- Everything is logged with the [SelfTest] prefix; the summary at the end lists every
-- check and every verdict. Nothing here writes to the save.

local function stLog(s) System.LogAlways("[SelfTest] " .. tostring(s)) end

mercenaries.SelfTestStepSecs = 10
mercenaries.SelfTestPrefix   = "MercSelfTest_"
mercenaries.SelfTest         = nil      -- the run in progress

-- Item classes the checks look for (vanilla item.xml).
local ITEM = {
    bartoschHose = "cc1adb78-fa5a-45c9-be7b-b7b50e182cb3",   -- LegsPadded01_m02_C3
    bartoschLegs = "b8f6cbf1-6cab-4abb-8eb7-8488a95839f2",   -- LegsBrigandine03_m01
    bocekCoif    = "33d6b02e-35fc-4b79-aa3f-25f42fc4dae6",   -- CoifSmall01_m04_C2
    brigArm      = "17ce237d-232c-4ada-b2c9-46926ca9eb6a",   -- BrigandineArm05_m05_B4
    cuirass      = "459ae318-ac5d-4de1-b34e-f6ce5ef6492c",   -- Cuirass05_m01_B3
}
local CC_BARTOSCH, CC_BOCEK = 4, 37

-- ==== small helpers ====

local function show(text, secs)
    pcall(function() Game.SendInfoText(text, true, 0, secs or 10) end)
end

local function hasItem(ent, cls)
    local id
    pcall(function() id = ent.inventory:FindItem(cls) end)
    return id ~= nil
end

-- A row of spots across the player's view, `dist` metres out.
local function row(self, n, dist, spacing)
    local spots = {}
    local base, rot = self:GetSafeSpawnPosition(player, dist or 6)
    local pp; pcall(function() pp = player:GetWorldPos() end)
    if not (base and pp) then return spots, 0 end
    local ax, ay = base.x - pp.x, base.y - pp.y
    local L = math.sqrt(ax * ax + ay * ay)
    if L < 0.01 then ax, ay = 0, 1 else ax, ay = ax / L, ay / L end
    local rx, ry = ay, -ax
    spacing = spacing or 2.2
    for i = 1, n do
        local off = (i - (n + 1) / 2) * spacing
        local p = { x = base.x + rx * off, y = base.y + ry * off, z = base.z }
        pcall(function() p = self:FindValidGround(p, base.z) or p end)
        spots[i] = p
    end
    -- face the player
    local yaw = (rot and rot.z or 0) + math.pi
    if yaw > math.pi then yaw = yaw - 2 * math.pi end
    return spots, yaw
end

-- Spawn one NPC on a soul. The name is what the test-reset registry removes by.
function mercenaries:SelfTestSpawn(tag, soul, pos, yaw)
    local name = self.SelfTestPrefix .. tag .. "_" .. tostring(math.random(10000, 99999))
    local ent
    pcall(function()
        System.SpawnEntity({ class = "NPC", name = name, position = pos,
                             orientation = { x = 0, y = 0, z = yaw or 0 },
                             properties = { guidSharedSoulId = soul } })
        ent = System.GetEntityByName(name)
    end)
    if ent then
        self:TestTrack(name)
        pcall(function() self:EnsureMercIsAlwaysRendered(ent) end)
        local S = self.SelfTest
        if S then S.spawned[#S.spawned + 1] = name end
    else
        stLog("could not spawn " .. tag .. " (soul " .. tostring(soul) .. ")")
    end
    return ent
end

function mercenaries:SelfTestClearSpawns()
    local S = self.SelfTest
    if not S then return end
    for _, name in ipairs(S.spawned) do
        pcall(function()
            local e = System.GetEntityByName(name)
            if e then System.RemoveEntity(e.id) end
        end)
        if self.TestSpawned then self.TestSpawned[name] = nil end
    end
    S.spawned = {}
end

-- ==== automated checks ====

local function check(S, name, ok, detail)
    S.results[#S.results + 1] = { kind = "auto", name = name, ok = ok and true or false, detail = detail }
    stLog(string.format("%s  %s%s", ok and "PASS" or "FAIL", name, detail and ("  (" .. detail .. ")") or ""))
end

function mercenaries:SelfTestAutomated(S)
    -- 1. No F key can be bound.
    pcall(function()
        local okFn = self:IsFunctionKey("F5") and self:IsFunctionKey("f12") and not self:IsFunctionKey("np_1")
        local refused = (self:BindKey("f5", "merc_noop") == false)
        local userRefused = (self:ValidUserKey("f2") == nil) and (self:ValidUserKey("u") == "u")
        local boundF = {}
        for k in pairs(self.BoundKeys or {}) do if self:IsFunctionKey(k) then boundF[#boundF + 1] = k end end
        check(S, "F keys are never bound", okFn and refused and userRefused and #boundF == 0,
              (#boundF > 0) and ("bound now: " .. table.concat(boundF, ",")) or nil)
    end)

    -- 2. Named companion names parse to their soul (region crossing).
    pcall(function()
        local g = self.CustomCompanionsData[CC_BARTOSCH].guid
        local m = self:RegionParseMan("SpawnedFriend_hero_" .. g .. "_12345")
        local f = self:RegionParseMan("SpawnedFriend_medium_12345_" .. g)
        check(S, "companion survives a region crossing (name -> soul)",
              m and m.kind == "hero" and m.soul == g and f and f.kind == "foot" and f.soul == g)
    end)

    -- 3. Custom uniform: brigandine arms are sleeves, not body plate.
    pcall(function()
        local arm, body = self:GearSlotOf(ITEM.brigArm), self:GearSlotOf(ITEM.cuirass)
        check(S, "uniform: cuirass and brigandine arms are different slots",
              arm == 39 and body ~= nil and body ~= arm,
              "arm=" .. tostring(arm) .. " cuirass=" .. tostring(body))
    end)

    -- 4. The Steal prompt is stripped.
    pcall(function()
        local list = { { action = "talk" }, { action = "pickpocketing" } }
        if inr_steal ~= nil then list[#list + 1] = { action = "x", interactionName = inr_steal } end
        local out = self:StripStealActions(list)
        check(S, "no Steal prompt on the company", #out == 1 and out[1].action == "talk")
    end)

    -- 5. "Spare me" silences the unsolicited reports.
    pcall(function()
        local wasOn, wasLoaded = self.StatusIconsEnabled, self._statusIconsLoaded
        local real = Game.SendInfoText
        local calls = 0
        self.StatusIconsEnabled, self._statusIconsLoaded = false, true
        Game.SendInfoText = function() calls = calls + 1 end
        pcall(function() self:LogiNotify("merc_logi_hungry", 1) end)
        Game.SendInfoText = real
        self.StatusIconsEnabled, self._statusIconsLoaded = wasOn, wasLoaded
        check(S, "quartermaster 'spare me' silences the reports", calls == 0)
    end)

    -- 6. A palisade does not close across a gate.
    pcall(function()
        local saved = self.Gates
        self.Gates = { { x = 0, y = 0, z = 0, yaw = 0 } }
        local across = self:WallEdgeCrossesGate({ x = -6, y = 0 }, { x = 6, y = 0 })
        local clear  = self:WallEdgeCrossesGate({ x = -6, y = 12 }, { x = 6, y = 12 })
        self.Gates = saved
        check(S, "wall close refuses to run through a gate", across and not clear)
    end)

    -- 7. A companion's own kit is never stripped by the uniform pass (Black Bartosch).
    pcall(function()
        check(S, "uniform never strips a named companion", self.GearHeroRestoreOn ~= true)
    end)

    -- 8. Test spawns are removed by the load reset.
    pcall(function()
        local spots, yaw = row(self, 1, 25)
        local soul = self.Souls and self.Souls.medium and self.Souls.medium[1]
        if not (spots[1] and soul) then check(S, "test spawns are cleaned up on load", false, "no spot"); return end
        local name = self.SelfTestPrefix .. "resetprobe_" .. tostring(math.random(10000, 99999))
        System.SpawnEntity({ class = "NPC", name = name, position = spots[1],
                             orientation = { x = 0, y = 0, z = yaw }, properties = { guidSharedSoulId = soul } })
        local before = System.GetEntityByName(name) ~= nil
        self:TestTrack(name)
        self:TestRemoveTracked("selftest")
        -- RemoveEntity is carried out at the end of the frame, so the entity still answers
        -- by name right now: the verdict is taken at the end of the run (SelfTestFinish).
        if before then S.resetProbe = name
        else check(S, "test spawns are cleaned up on load", false, "probe did not spawn") end
    end)


    -- ---- 3.2 bug list (each stubs what it needs and puts everything back) ----

    -- 9. The command screen's Move order: left click and E reach the flag.
    pcall(function()
        local BL = self.BL
        if not BL then check(S, "Move order: left click / E plant the flag", false, "no command screen"); return end
        local wasPlacing = BL.placing
        local real, hit = self.BLPlaceConfirm, 0
        self.BLPlaceConfirm = function() hit = hit + 1 end
        BL.placing = true
        local c1, c2 = false, false
        pcall(function() c1 = self:HandlePlacementAction("attack_primary_mouse", "press") end)
        pcall(function() c2 = self:HandlePlacementAction("use", "press") end)
        self.BLPlaceConfirm = real
        BL.placing = wasPlacing
        check(S, "Move order: left click / E plant the flag", c1 and c2 and hit == 2)
    end)
    -- 10. ...and siting it does not switch on the no_attack filter that swallowed the click.
    pcall(function()
        local BL = self.BL
        if not (BL and not BL.placing) then return end
        local blocked
        pcall(function() self:BLPlaceBegin(); blocked = BL.atkBlocked end)
        pcall(function() self:BLPlaceCancel() end)
        check(S, "Move order: the click is not filtered away", blocked == false)
    end)

    -- 11. Raid: a man sitting, asleep or harvesting is left in camp.
    pcall(function()
        local rG, rP, rL = self.IsGroundedStance, self.InCampPose, self.LeavingCampPose
        self.IsGroundedStance = function(_, w) return tostring(w) == "posed" end
        self.InCampPose = function(_, w) return tostring(w) == "harvesting" end
        self.LeavingCampPose = function() return false end
        local a = self:WBDefenderFree({ id = "posed" })
        local b = self:WBDefenderFree({ id = "harvesting" })
        local c = self:WBDefenderFree({ id = "standing" })
        self.IsGroundedStance, self.InCampPose, self.LeavingCampPose = rG, rP, rL
        check(S, "raid: sitting/sleeping/harvesting men are left alone", (not a) and (not b) and c)
    end)

    -- 12. Every wall run is drawn as the wall it was built as.
    pcall(function()
        local cur, other = self.WallTypeIdx, nil
        for i in pairs(self.WallTypes or {}) do if i ~= cur then other = i; break end end
        if not other then check(S, "wall runs keep their own type", false, "one wall type only"); return end
        local restore = self:WallUseRunType({ wtype = other })
        local during = self.WallTypeIdx
        restore()
        check(S, "wall runs keep their own type", during == other and self.WallTypeIdx == cur)
    end)

    -- 13. Taking the stone wall down leaves the palisade standing.
    pcall(function()
        local base = self.CastleWallBase or 0
        if base <= 0 then check(S, "stone wall removal keeps the palisade", false, "no stone types"); return end
        local saved = { WallRuns = self.WallRuns, WallMarks = self.WallMarks, WallClosed = self.WallClosed,
                        CastleGateways = self.CastleGateways, Gates = self.Gates }
        local stubs = { "WallRebuild", "WallPreviewClear", "WallClearStartMarker", "WallClearAll",
                        "GateClearAll", "GateTouched", "WallTouched" }
        local real = {}
        for _, k in ipairs(stubs) do real[k] = self[k]; self[k] = function() end end
        local pal = self.WallTypePalisade or 3
        self.WallRuns = {
            { pts = { { x = 0, y = 0, z = 0 }, { x = 6, y = 0, z = 0 } }, wtype = base + 1 },
            { pts = { { x = 0, y = 9, z = 0 }, { x = 6, y = 9, z = 0 } }, wtype = pal },
        }
        self.WallMarks, self.Gates = {}, {}
        local had = false
        pcall(function() had = self:WallRemoveKind(true) end)
        local left, kept = #(self.WallRuns or {}), self.WallRuns and self.WallRuns[1] and self.WallRuns[1].wtype
        for k, v in pairs(saved) do self[k] = v end
        for _, k in ipairs(stubs) do self[k] = real[k] end
        check(S, "stone wall removal keeps the palisade", had and left == 1 and kept == pal)
    end)

    -- 14. A gate from another save is not hung again with no camp standing.
    pcall(function()
        local sG, sA, realSpawn = self.Gates, self.CampActive, System.SpawnEntity
        local spawned = 0
        self.Gates, self.CampActive = { { x = 0, y = 0, z = 0, yaw = 0 } }, false
        System.SpawnEntity = function() spawned = spawned + 1 end
        pcall(function() self:GateWatchdog() end)
        System.SpawnEntity = realSpawn
        self.Gates, self.CampActive = sG, sA
        check(S, "a stale gate is not re-hung after a load", spawned == 0)
    end)

    -- 15. The company does not pick unarmed bystanders; outlaws need no drawn weapon.
    pcall(function()
        local rHK, rIV = self.HostileKind, self.IsValidEnemy
        local first = {}
        local kind
        self.HostileKind = function() return kind end
        self.IsValidEnemy = function(_, e, ref, pw, skipRel, skipWpn)
            if first[kind] == nil then first[kind] = (skipWpn == true) end
            return false
        end
        kind = "neutral"; pcall(function() self:EngageCacheAccepts({ id = "x" }, nil, false, false) end)
        kind = "hostile"; pcall(function() self:EngageCacheAccepts({ id = "x" }, nil, false, false) end)
        self.HostileKind, self.IsValidEnemy = rHK, rIV
        check(S, "bystanders must draw before they are targeted", first.neutral == false and first.hostile == true)
    end)

    -- 16. A held rear rank may take an enemy pressing the front rank.
    pcall(function()
        local sS, rL = self.HoldStations, self.HoldLeashOf
        self.HoldStations = { a = { x = 0, y = 0 }, b = { x = 0, y = 3 } }
        self.HoldLeashOf = function() return 2 end
        local atLine = self:HoldPosOutOfLeash("a", { x = 0, y = 4.2 })
        local far    = self:HoldPosOutOfLeash("a", { x = 0, y = 10 })
        self.HoldStations, self.HoldLeashOf = sS, rL
        check(S, "held rear rank joins the fight at the line", atLine == false and far == true)
    end)

    -- 17. Aleksej keeps his spot; beat 6 hands over the documents.
    pcall(function()
        check(S, "Aleksej stays on his stool, no lodging search",
              self.AlxLodgingRoutine == false and self.AlxBeat6Search == false)
    end)

    -- 18. Load latches that used to survive a load are in the reset list.
    pcall(function()
        local found = false
        for _, k in ipairs(self.TimerLatches or {}) do if k == "StaticArcherPinActive" then found = true end end
        check(S, "tower archers' drift pin re-arms after a load", found)
    end)

    -- 19. The alchemy bench is gone (3.2.1): never built, not on the camp screen, not for sale.
    pcall(function()
        local listed = false
        for _, imp in ipairs((self.CampAtlas or {}).improvements or {}) do
            if imp.key == "alchemy" then listed = true end
        end
        local built = true
        pcall(function() built = self:SpawnCampAlchemy({ x = 0, y = 0, z = 0 }) end)
        check(S, "alchemy bench removed (no borrow, not listed)",
              self.CampAlchemyEnabled == false and not listed and built == false)
    end)

    -- 20. No world scan every half minute (the 3.2 stutter); the mod's things are flagged
    --     out of the save as they spawn instead.
    pcall(function()
        local name = self.SelfTestPrefix .. "nosave_" .. tostring(math.random(10000, 99999))
        local e
        pcall(function()
            e = System.SpawnEntity({ class = "BasicEntity", name = name, position = { x = 0, y = 0, z = -500 },
                                     properties = { object_Model = "" } })
        end)
        local flagged = false
        if e then
            pcall(function() flagged = e:HasFlags(self.EntityFlagNoSave) and true or false end)
            pcall(function() System.RemoveEntity(e.id) end)
        end
        local need = self.RosterNoSave ~= false
        check(S, "no periodic world scan; spawns are kept out of saves at once",
              (self.NoSaveSweepEveryTicks or 0) <= 0 and self._spawnHooked == true and (flagged or not need),
              "flagged=" .. tostring(flagged))
    end)

    -- 21. A fast travel never brings the dead along.
    pcall(function()
        local realAlive, realPlace = self.IsAliveAndWell, self.MercPlaceAt
        local placed = 0
        self.IsAliveAndWell = function() return false end          -- every man is a corpse
        self.MercPlaceAt = function() placed = placed + 1; return true end
        local taken = self:TravelTakesAlong({ id = "corpse" })
        local moved = self:TravelPlaceAt({ id = "corpse" }, { x = 0, y = 0, z = 0 })
        self.IsAliveAndWell, self.MercPlaceAt = realAlive, realPlace
        check(S, "fast travel leaves corpses where they fell", taken == false and moved == false and placed == 0)
    end)

    -- 22. A townsman with bare fists is never "armed"; one with a weapon in hand is.
    pcall(function()
        local fists = { human = { IsWeaponDrawn = function() return true end, GetItemInHand = function() return nil end } }
        local sword = { human = { IsWeaponDrawn = function() return true end, GetItemInHand = function() return 12345 end } }
        check(S, "unarmed townsfolk are never targets", self:HoldsRealWeapon(fists) == false and self:HoldsRealWeapon(sword) == true)
    end)

    -- 23. A crossing ends every fight.
    pcall(function()
        local saved = { self.MercTargetOf, self.EnemyAlerted, self.AttackerSeen }
        self.MercTargetOf, self.EnemyAlerted, self.AttackerSeen = { a = "b" }, true, { c = 1 }
        self:TravelForgetFights("selftest")
        local cleared = next(self.MercTargetOf) == nil and self.EnemyAlerted == false and next(self.AttackerSeen) == nil
        if not cleared then self.MercTargetOf, self.EnemyAlerted, self.AttackerSeen = saved[1], saved[2], saved[3] end
        check(S, "fast travel leaves the fight behind", cleared)
    end)

    -- 24. Morale is easier to keep: fed & paid counts, gentler slide and tiredness.
    pcall(function()
        check(S, "morale: fed & paid +5/day, slide 2/day, tiredness 5/day",
              self.MoraleFedPaidGain == 5 and self.MoraleDecayPerDay == 2 and self.MoraleTiredDrain == 5)
    end)
end

-- ==== visual steps ====
-- setup(self, S) spawns and returns the caption; verify(self, S) (optional) adds automated
-- checks against what was spawned, run just before it is taken away.

mercenaries.SelfTestSteps = {
    {
        name = "named companions keep their own kit",
        setup = function(self, S)
            local spots, yaw = row(self, 2, 5, 2.4)
            local b = self.CustomCompanionsData[CC_BARTOSCH]
            local c = self.CustomCompanionsData[CC_BOCEK]
            -- "_hero_" in the name: EquipMercenary treats them as companions
            S.bart = self:SelfTestSpawn("hero_Bartosch", b.guid, spots[1], yaw)
            S.bocek = self:SelfTestSpawn("hero_Bocek", c.guid, spots[2], yaw)
            -- The 2.5.1 bug: a custom uniform holding a stock item he also wears deleted it
            -- from him. Run the real dressing path against such a uniform.
            local realLoad = self.GearLoadSet
            self.GearLoadSet = function() return { ITEM.bartoschHose } end
            pcall(function() if S.bart then self:EquipMercenary(S.bart, self.CustomOutfitIndex) end end)
            self.GearLoadSet = realLoad
            return "LEFT Black Bartosch: padded hose AND leg armour on.  RIGHT Levej Bocek: coif under his skullcap."
        end,
        verify = function(self, S)
            if S.bart then
                check(S, "Bartosch still has his padded hose", hasItem(S.bart, ITEM.bartoschHose))
                check(S, "Bartosch still has his leg armour", hasItem(S.bart, ITEM.bartoschLegs))
            end
            if S.bocek then check(S, "Bocek has a coif", hasItem(S.bocek, ITEM.bocekCoif)) end
        end,
    },
    {
        name = "Skalitz livery (needs Kobyla Arms installed)",
        setup = function(self, S)
            local pools = (self.Outfits or {})[self.SkalitzOutfitIndex] or {}
            local presets = { (pools.weak or {})[1], (pools.medium or {})[1], (pools.strong or {})[1] }
            local spots, yaw = row(self, 3, 6, 2.2)
            local soul = self.Souls.medium[1]
            for i = 1, 3 do
                local e = self:SelfTestSpawn("skalitz" .. i, soul, spots[i], yaw)
                if e and presets[i] then pcall(function() e.actor:EquipClothingPreset(presets[i]) end) end
            end
            return "Weak / medium / strong Skalitz: red-white Skalitz waffenrocks (Kobyla) - not plain basic armour."
        end,
    },
    {
        name = "no Steal prompt on a merc",
        secs = 20,
        setup = function(self, S)
            local spots, yaw = row(self, 1, 3)
            local e = self:SelfTestSpawn("thief_target", self.Souls.medium[1], spots[1], yaw)
            if e then pcall(function() self:InjectInteraction(e) end) end
            return "Walk up to him (crouched, with Thievery): camp / follow prompts, but NO 'Steal'. 20 s."
        end,
    },
}

-- ==== the run ====

function mercenaries:SelfTestStart()
    if self.SelfTest then stLog("already running - merc_selftest_stop first"); return end
    local S = { results = {}, spawned = {}, step = 0, gen = (self._selfTestGen or 0) + 1 }
    self._selfTestGen = S.gen
    self.SelfTest = S
    stLog("===== Mercenaries self-test =====")
    stLog("automated checks:")
    self:SelfTestAutomated(S)
    -- the verdict keys (never F keys; released at the end and on any load)
    local b1, b3 = false, false
    pcall(function() b1 = self:TestBindKey("np_1", "merc_selftest_ok") end)
    pcall(function() b3 = self:TestBindKey("np_3", "merc_selftest_bad") end)
    stLog("verdict keys bound: numpad 1 " .. tostring(b1) .. ", numpad 3 " .. tostring(b3)
          .. " (if pressing them logs no 'answer' line, use merc_selftest_ok / merc_selftest_bad)")
    stLog("visual steps: numpad 1 = looks right, numpad 3 = wrong (or merc_selftest_ok / _bad / _skip)")
    self:SelfTestNext()
end

function mercenaries:SelfTestNext()
    local S = self.SelfTest
    if not S then return end
    S.step = S.step + 1
    local st = self.SelfTestSteps[S.step]
    if not st then return self:SelfTestFinish() end
    local caption = "?"
    local ok, err = pcall(function() caption = st.setup(self, S) or st.name end)
    if not ok then stLog("step '" .. st.name .. "' setup failed: " .. tostring(err)) end
    S.caption = string.format("SELF-TEST %d/%d: %s  [NUM1 = right, NUM3 = wrong]",
                              S.step, #self.SelfTestSteps, caption)
    S.deadline = (System.GetCurrTime() or 0) + (st.secs or self.SelfTestStepSecs)
    S.answer, S.shownAt = nil, -99
    stLog("step " .. S.step .. ": " .. st.name .. " - " .. tostring(caption))
    Script.SetTimerForFunction(250, "mercenaries.SelfTestTick")
end

function mercenaries.SelfTestTick()
    local self = mercenaries
    local S = self.SelfTest
    if not S then return end
    local now = System.GetCurrTime() or 0
    if not S.answer and now < (S.deadline or 0) then
        -- keep the caption up (an info line fades on its own)
        if now - (S.shownAt or -99) > 4.5 then show(S.caption, 5); S.shownAt = now end
        Script.SetTimerForFunction(250, "mercenaries.SelfTestTick")
        return
    end
    self:SelfTestEndStep(S.answer or "no answer")
end

function mercenaries:SelfTestEndStep(verdict)
    local S = self.SelfTest
    if not S then return end
    local st = self.SelfTestSteps[S.step]
    if st and st.verify then
        local ok, err = pcall(function() st.verify(self, S) end)
        if not ok then stLog("verify failed: " .. tostring(err)) end
    end
    if st then
        S.results[#S.results + 1] = { kind = "visual", name = st.name, verdict = verdict }
        stLog(string.format("step %d '%s': %s", S.step, st.name, verdict))
    end
    self:SelfTestClearSpawns()
    S.bart, S.bocek = nil, nil
    self:SelfTestNext()
end

-- Answers. The tick picks them up on its next pass (<= 250 ms).
function mercenaries:SelfTestAnswer(v)
    local S = self.SelfTest
    if not S or S.answer then return end
    S.answer = v
    stLog("answer: " .. v)
    show("SELF-TEST: " .. v, 2)
end

function mercenaries:SelfTestFinish()
    local S = self.SelfTest
    if not S then return end
    self:SelfTestClearSpawns()
    pcall(function() self:UnbindKey("np_1") end)
    pcall(function() self:UnbindKey("np_3") end)
    if self.TestBoundKeys then self.TestBoundKeys["np_1"], self.TestBoundKeys["np_3"] = nil, nil end
    if S.resetProbe then
        check(S, "test spawns are cleaned up on load", System.GetEntityByName(S.resetProbe) == nil)
        S.resetProbe = nil
    end
    local fails, wrong, silent = 0, 0, 0
    stLog("===== summary =====")
    for _, r in ipairs(S.results) do
        if r.kind == "auto" then
            if not r.ok then fails = fails + 1 end
            stLog(string.format("  [%s] %s", r.ok and "PASS" or "FAIL", r.name))
        else
            if r.verdict == "WRONG" then wrong = wrong + 1 elseif r.verdict ~= "RIGHT" then silent = silent + 1 end
            stLog(string.format("  [%s] %s (visual)", r.verdict, r.name))
        end
    end
    local line = string.format("SELF-TEST done: %d automated failure(s), %d visual WRONG, %d unanswered - see console/kcd.log [SelfTest]",
                               fails, wrong, silent)
    stLog(line)
    show(line, 8)
    self.SelfTest = nil
end

function mercenaries:SelfTestStop()
    if not self.SelfTest then return end
    stLog("stopped")
    self:SelfTestFinish()
end

-- A load mid-run: stop, drop the spawns (they are tracked anyway), release the keys.
mercenaries:RegisterTestReset("selftest", function(self)
    if self.SelfTest then
        self.SelfTest = nil
        System.LogAlways("[Merc] test reset: self-test stopped")
    end
end)

mercenaries:PlayerCommand("merc_selftest",      "mercenaries:SelfTestStart()",
    "Pre-release self-test: automated checks, then visual steps in front of you (numpad 1 right / 3 wrong)")
mercenaries:PlayerCommand("merc_selftest_ok",   "mercenaries:SelfTestAnswer('RIGHT')", "Self-test: this step looks right")
mercenaries:PlayerCommand("merc_selftest_bad",  "mercenaries:SelfTestAnswer('WRONG')", "Self-test: this step looks wrong")
mercenaries:PlayerCommand("merc_selftest_skip", "mercenaries:SelfTestAnswer('skipped')", "Self-test: skip this step")
mercenaries:PlayerCommand("merc_selftest_stop", "mercenaries:SelfTestStop()",          "Self-test: stop and clean up")
