-- FAST TRAVEL, SLEEP, WAIT AND TELEPORT DETECTION.
--
-- The test itself is the one written in the first commit and unchanged since: the player's
-- POSITION moves while the engine reports HENRY'S OWN SPEED as zero. Nothing else in normal
-- play looks like that - walking, running and riding all report a speed - so it is the
-- signature of the player being carried by something rather than moving himself.
--
-- What was wrong with it was never the test. It is guarded by `realTimeDelta < 0.4`, and it
-- sat inside MonitorMainQuestLoop, which has run at 1 Hz since the first commit - so the
-- guard was false on every tick and the branch has never once fired, in any version of this
-- mod. It reads as a working detector and is dead code. (Checked against every commit in the
-- repository on 2026-09-03: the file is byte-identical in all of them.)
--
-- So it runs here instead, on a 100 ms scheduler slot where a 0.4 s delta is the normal case
-- and the test can do what it was written to do. MonitorMainQuestLoop still owns the idle
-- bookkeeping and still reads FastTravelLastDetected; this only decides when to stamp it.
--
-- MEASURED 2026-09-03, 2343 probe samples across fast travels on foot and on horseback.
-- What the movement heuristics can actually see:
--
--   * the position NEVER jumped on foot. A galloping horse can sample 15-25 m/s, so an
--     instant->teleport distance threshold is the only position-based signal left.
--   * `GetHorse()` answered "mounted" on all 2343 samples, on foot included. It reports that
--     Henry OWNS a horse, not that he is riding one - fixed below with the horse's own
--     position.
--   * `GetWorldTimeRatio()` read exactly 15.0 on every sample; 15 is this build's NORMAL
--     rate. The world clock's REAL advance rate (GetWorldTime() per real second, against
--     that nominal) does move during a crossing - but noisily, sample to sample, so gating
--     detection on it was slow: "the fast travelling detection only fired when the fast
--     travelling was done" (2026-09-03). It is kept only as a last-resort fallback below.
--
-- ON FOOT, distance with zero Henry-speed has no other explanation in ordinary play -
-- walking, running and sprinting all report a speed - so it fires on a short grace with no
-- further test needed.
--
-- MOUNTED, it does: riding a horse is ALSO distance with zero Henry-speed, at any pace from
-- a walk to a gallop, because Henry's own animation speed is what is read and he is sitting
-- still either way. So the same question is put to the HORSE instead - see
-- TravelHorseMotion. `CScriptBind_Entity::GetSpeed`/`GetVelocity` are entity-level binds,
-- so the horse answers them exactly as the player does on foot: a horse under a rider
-- reports its own motion at any pace, a horse being carried along a crossing has its
-- position set for it and reports none. That is the mounted rule, and it assumes nothing
-- about pace at all.
--
-- STAMINA is the fallback for a build where the horse-motion binds do not answer, and it
-- is a poor one. It was the first mounted discriminator (2026-09-03, `soul:GetState`,
-- "returns state value for a given name (health, stamina,...)"): fast travel does not run the
-- stamina simulation, so the value sits bit-for-bit flat for a crossing. But so does a real
-- ride at any pace that does not drain stamina - and measured, a canter at 5-6 m/s drains
-- none, while crossings had been seen rendering at 3-4 m/s. The two overlap, so the speed
-- gate in front of the stamina test (TravelStaminaMinSpeed) cannot separate them; it is
-- kept only so a build with nothing better still catches a gallop-speed crossing.

-- Declared before anything that calls it: a Lua local binds downward only, so a helper
-- added above this line would get a nil global at runtime (see docs/patrols.md).
local function twLog(s) System.LogAlways("[Travel] " .. tostring(s)) end

-- ---------------------------------------------------------------------------
-- THE ENGINE'S OWN ANSWER
-- ---------------------------------------------------------------------------
--
-- The heuristics below are a fallback. The engine tracks what the player is DOING in an
-- actor-state enum, and it has exactly the states this module wants:
--
--   enum_actorState = { ... skipTime=32, fastTravel=33, cutscene=34, ... }
--
-- (references/kcd2-mod-docs-main/lua_dump_state/LuaState_Sorted.txt). What is not
-- documented anywhere is which bind returns it, so rather than guess one name and ship a
-- detector that silently never fires - which is the exact bug this file exists to fix -
-- every plausible getter is tried once, the first that answers with a number is kept, and
-- the name of the winner is logged. If none answers, the heuristics carry on and the log
-- says so. merc_travelstate prints the whole table of answers.
--
-- MEASURED 2026-09-03: all nine answer nil or unavailable on this build. `soul:GetState`
-- exists and takes a name, but it answers nil for "actorState" - it is for soul STATS
-- (health, stamina), which is exactly the bind reused below for the stamina discriminator.
mercenaries.TravelStateFastTravel = 33
mercenaries.TravelStateCutscene   = 34
mercenaries.TravelStateSkipTime   = 32

mercenaries.TravelStateGetters = {
    { name = "soul:GetState('actorState')",      fn = function() return player.soul:GetState("actorState") end },
    { name = "soul:GetState('state')",           fn = function() return player.soul:GetState("state") end },
    { name = "soul:GetState('actor_state')",     fn = function() return player.soul:GetState("actor_state") end },
    { name = "actor:GetState()",                 fn = function() return player.actor:GetState() end },
    { name = "actor:GetActorState()",            fn = function() return player.actor:GetActorState() end },
    { name = "player:GetState()",                fn = function() return player.player:GetState() end },
    { name = "human:GetActorState()",            fn = function() return player.human:GetActorState() end },
    { name = "human:GetState()",                 fn = function() return player.human:GetState() end },
    { name = "this:GetState()",                  fn = function() return player.this:GetState() end },
}

-- The chosen getter, or false once every candidate has been tried and failed.
function mercenaries:TravelActorState()
    if self._twGetter == false then return nil end
    if self._twGetter then
        local v
        local ok = pcall(function() v = self._twGetter.fn() end)
        return (ok and type(v) == "number") and v or nil
    end
    for _, g in ipairs(self.TravelStateGetters or {}) do
        local v
        local ok = pcall(function() v = g.fn() end)
        if ok and type(v) == "number" then
            self._twGetter = g
            twLog("actor state read through " .. g.name .. " (first answer: " .. tostring(v) .. ")")
            return v
        end
    end
    self._twGetter = false
    twLog("no actor-state getter answered - falling back to the movement heuristics")
    return nil
end

-- Print what every candidate answers, for when the chosen one stops being right.
function mercenaries:TravelStateReport()
    twLog("actor-state getters:")
    for _, g in ipairs(self.TravelStateGetters or {}) do
        local v
        local ok = pcall(function() v = g.fn() end)
        twLog(string.format("  %-34s %s", g.name,
                  ok and (type(v) .. " " .. tostring(v)) or "unavailable"))
    end
    twLog("wanted: fastTravel=" .. tostring(self.TravelStateFastTravel) ..
              " cutscene=" .. tostring(self.TravelStateCutscene) ..
              " skipTime=" .. tostring(self.TravelStateSkipTime))
end

-- ---------------------------------------------------------------------------
-- STAMINA - the mounted discriminator
-- ---------------------------------------------------------------------------
--
-- `soul:GetState(name)` is a generic Soul method (C_ScriptBindSoul), not a Player-only one,
-- so it is tried on the horse entity the same way. If a build's horse entity has no `.soul`
-- (or the bind fails for any other reason), this returns nil and the caller falls back to
-- the player's own stamina, then finally to the world-clock rate - see TravelWatchTick.
function mercenaries:TravelHorseStamina()
    local v
    local ok = pcall(function()
        local h = player.human:GetHorse()
        local e = h and XGenAIModule.GetEntityByWUID(h)
        v = e and e.soul and e.soul:GetState("stamina")
    end)
    return (ok and type(v) == "number") and v or nil
end

function mercenaries:TravelPlayerStamina()
    local v
    local ok = pcall(function() v = player.soul:GetState("stamina") end)
    return (ok and type(v) == "number") and v or nil
end

-- THE HORSE'S OWN MOTION - the mounted mirror of the on-foot test.
--
-- On foot the whole detector rests on one fact: Henry's position moves while
-- `player:GetSpeed()` says he is not moving himself. In the saddle that reading is 0 either
-- way, so it says nothing - but the HORSE has the same bind. `CScriptBind_Entity::GetSpeed`
-- and `GetVelocity` are entity-level (documented: "Get the speed of the entity", "Get the
-- velocity of the entity"), so the horse resolved the same way the mounted test resolves it
-- answers them too. A horse being ridden reports its own motion at any pace; a horse being
-- carried along a crossing has its position set for it and reports none. Position covering
-- ground while the horse itself reports zero is the crossing, at ANY speed - which is what
-- stamina could never say, because a canter at 5-6 m/s drains none either (measured
-- 2026-09-03, a false detection at exactly that pace).
--
-- Returns the horse's own speed (GetSpeed, falling back to |GetVelocity|) and the velocity
-- magnitude, or nil if neither bind answers on this build.
function mercenaries:TravelHorseMotion()
    local spd, vel
    pcall(function()
        local h = player.human:GetHorse()
        local e = h and XGenAIModule.GetEntityByWUID(h)
        if not e then return end
        pcall(function() spd = e:GetSpeed() end)
        pcall(function()
            local v = e:GetVelocity()
            if type(v) == "table" and v.x then
                vel = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
            end
        end)
    end)
    if type(spd) == "number" then return spd, vel end
    if type(vel) == "number" then return vel, vel end
    return nil, nil
end

-- How long a stamina reading has sat at the exact same value SINCE `armed` last went from
-- false to true - not since whenever the value happened to last change, which could be
-- minutes earlier if the horse has been standing at a stable with capped stamina. Without
-- that re-baseline, riding off from a standstill on a rested horse would read as an
-- INSTANT "fast travel": the freeze clock would already be minutes long the moment ghost
-- movement began. `armed` is true only while the ambiguous state (mounted, covering ground,
-- zero Henry-speed) actually holds - see TravelWatchTick.
--
-- Returns nil while a real reading is unavailable, or while not armed (nothing to measure
-- yet); otherwise seconds since this specific armed span began without the value changing.
function mercenaries:TravelStaminaFrozenFor(key, val, now, armed)
    local prevKey, atKey, wasKey = "_tw" .. key .. "Val", "_tw" .. key .. "At", "_tw" .. key .. "Armed"
    if val == nil or not armed then
        self[prevKey], self[atKey], self[wasKey] = nil, nil, false
        return nil
    end
    if not self[wasKey] then
        -- Just armed: the baseline is THIS reading, THIS instant - any history before now
        -- (including a long-capped stamina from before he ever started moving) is discarded.
        self[wasKey], self[prevKey], self[atKey] = true, val, now
        return 0.0
    end
    if val ~= self[prevKey] then
        self[atKey] = now
    end
    self[prevKey] = val
    return now - (self[atKey] or now)
end

-- ---------------------------------------------------------------------------
-- Tunables
-- ---------------------------------------------------------------------------

-- Metres in one sample below which he is not moving at all. 0.02 was far too fine: sitting
-- in the saddle through a conversation drifts further than that between ticks, and the
-- detector called it "carried 0.0m at 0.4 m/s" and stowed the company (2026-09-03). Sway,
-- settling physics and a saddle bone's animation all live under 10 cm a tick; a crossing
-- moves metres.
mercenaries.TravelMoveEps           = 0.10
mercenaries.TravelGhostSpeed        = 0.1    -- Henry's own speed at or below this = not walking
mercenaries.TravelOnFootGraceSecs   = 0.3    -- on foot: sustained this long before it counts
-- How long a MOUNTED horse's stamina must sit dead still, while ground is being covered,
-- before that stops being a horse under a rider. Real riding regenerates or drains stamina
-- essentially every tick; fast travel runs no such simulation at all, so this is a small
-- number chosen to absorb one or two ticks the engine happens to skip an update, not to
-- tolerate a genuinely idle stat. If a high-stamina horse at a gentle walk ever sits at a
-- capped value long enough to trip this falsely, raise it - merc_travelstamina shows the
-- live readings to check against.
-- The horse's OWN reported speed at or below which it is not moving itself. Mirrors
-- TravelGhostSpeed for Henry on foot. Primary mounted signal; stamina is the fallback.
mercenaries.TravelHorseMoveSpeed    = 0.3
-- SMOOTHING, all three of these. An instantaneous reading of anything is not enough:
--
--   * A horse that reported real motion within TravelHorseRecentSecs is still "a horse
--     under a rider". Hard acceleration and deceleration are exactly where the horse's own
--     speed and the position it drags behind it disagree for a few ticks - brake from a
--     gallop and the reported speed hits zero while momentum still carries the position,
--     which read as a crossing (2026-09-03). Remembering that it WAS moving a moment ago
--     costs nothing and removes the whole class.
--   * A span must have covered TravelSpanMinDist of real ground before anything fires. A
--     crossing eats that in a tick or two; sway in the saddle never accumulates it.
--   * The grace is a full second, not half.
mercenaries.TravelHorseRecentSecs   = 1.5
mercenaries.TravelSpanMinDist       = 8.0
mercenaries.TravelMountedGraceSecs  = 1.0
mercenaries.TravelStaminaFreezeSecs = 1.0
-- Sustained m/s (a running average since the ambiguous state began, not one noisy sample)
-- below which the stamina test is not trusted at all - see the header. Above the AI
-- movement table's Run ceiling (2.6) and below its Sprint floor (6.5); recalibrate with
-- merc_travelprobe/merc_travelstamina if a real horse's drain threshold differs from the
-- generic AI table (upgraded/perked horses are not guaranteed to match it exactly).
mercenaries.TravelStaminaMinSpeed   = 3.0
mercenaries.TravelTeleportDist      = 25.0   -- metres in one 100ms sample is never locomotion
-- Fallback only, for a build where neither stamina getter answers. Noisy and slow - see the
-- header - kept so a mounted crossing is still caught eventually rather than never.
mercenaries.TravelClockRate         = 3.0
mercenaries.TravelClockRatio        = 20.0
mercenaries.TravelFallbackGraceSecs = 1.0
mercenaries.TravelCoolSecs          = 3.0    -- how long a detection keeps the state up
mercenaries.TravelMountedDist       = 2.5    -- horse within this of the player = he is on it
mercenaries.TravelProbe             = false  -- merc_travelprobe


function mercenaries:TravelWatchTick()
    local now
    pcall(function() now = System.GetCurrTime() end)
    if not now then return end

    local pos
    pcall(function() pos = player:GetWorldPos() end)
    if not pos then return end

    local last, lastT = self._twPos, self._twT
    local dt = (lastT and (now - lastT)) or 0
    local dist = 0
    if last then
        dist = math.sqrt((pos.x - last.x) ^ 2 + (pos.y - last.y) ^ 2 + (pos.z - last.z) ^ 2)
    end
    self._twPos, self._twT = { x = pos.x, y = pos.y, z = pos.z }, now

    local speed = -1
    pcall(function() speed = player:GetSpeed() end)

    -- RIDING, not OWNING. GetHorse() answers with the player's horse whether or not he is on
    -- it (measured 2026-09-03: true on all 2343 samples, on foot included), so the horse's own
    -- position decides. XGenAIModule.GetEntityByWUID is the bind the rest of the mod resolves
    -- a WUID with; System.GetEntity takes an entity id and returns nil for a WUID.
    local mounted = false
    pcall(function()
        local h = player.human:GetHorse()
        local e = h and XGenAIModule.GetEntityByWUID(h)
        local hp = e and e.GetWorldPos and e:GetWorldPos()
        if hp then
            mounted = ((hp.x - pos.x) ^ 2 + (hp.y - pos.y) ^ 2) < (self.TravelMountedDist or 2.5) ^ 2
        end
    end)
    -- Second opinion, and the one the rest of the mod already trusts: the horse-lifecycle
    -- poll in follow.xml publishes this. It is forced false when merc_horses is off, so it
    -- can only ADD a mounted reading, never clear one.
    if _G.PlayerMounted then mounted = true end

    -- The world-clock rate, kept only as the last-resort fallback below and for the probe.
    local ratio = 0
    pcall(function() ratio = Calendar.GetWorldTimeRatio() or 0 end)
    local wt
    pcall(function() wt = Calendar.GetWorldTime() end)
    local rate = 1.0
    if wt and self._twWT and dt > 0.01 and ratio > 0 then
        rate = ((wt - self._twWT) / dt) / ratio
    end
    if wt then self._twWT = wt end
    local clockFast = (ratio > (self.TravelClockRatio or 20.0)) or (rate > (self.TravelClockRate or 3.0))

    -- The engine's own answer, if this build ever exposes it. When it is available nothing
    -- else is consulted: it knows the difference between a crossing and a gallop, and the
    -- heuristics below do not.
    local st = self:TravelActorState()

    -- MOVING: distance THIS SAMPLE beyond noise. WALKING: Henry's own speed says he is doing
    -- it himself - covers running and sprinting too, on foot or as a mounted merc animation
    -- (never the player, who reads 0 either way in the saddle).
    local moving  = dist > (self.TravelMoveEps or 0.02)
    local walking = moving and speed >= (self.TravelGhostSpeed or 0.1)
    local ghost   = moving and not walking
    local teleport = dist > (self.TravelTeleportDist or 25.0)

    local mountedGhost = mounted and ghost

    -- The horse's own motion - see TravelHorseMotion. nil when neither bind answers.
    -- SMOOTHED over TravelHorseRecentSecs: the horse counts as moving itself if it reported
    -- motion at any point in that window, not only on this tick. See the note on the
    -- tunables - a hard stop drops the reported speed to zero while momentum still carries
    -- the position, and that disagreement is not a crossing.
    local hSpd, hVel = self:TravelHorseMotion()
    local horseMotionKnown = (hSpd ~= nil)
    if horseMotionKnown and hSpd > (self.TravelHorseMoveSpeed or 0.3) then
        self._twHorseMovedAt = now
    end
    local horseSelfMoving = horseMotionKnown and self._twHorseMovedAt
                            and (now - self._twHorseMovedAt) < (self.TravelHorseRecentSecs or 1.5)

    -- The ambiguous span: how far and how fast he has been carried since ghost movement
    -- began, mounted or not. A running average over the whole span, never one 100ms sample.
    -- Reset the instant ghosting stops, so a later span starts clean rather than being
    -- dragged by an unrelated earlier lull.
    if ghost then
        if not self._twSpanAt then
            self._twSpanAt, self._twSpanPos = now, { x = pos.x, y = pos.y }
        end
    else
        self._twSpanAt, self._twSpanPos = nil, nil
    end
    local spanSpeed, spanDist = 0, 0
    if self._twSpanAt then
        local sp = self._twSpanPos
        spanDist = math.sqrt((pos.x - sp.x) ^ 2 + (pos.y - sp.y) ^ 2)
        if (now - self._twSpanAt) > 0.05 then spanSpeed = spanDist / (now - self._twSpanAt) end
    end
    local staminaGateOpen = spanSpeed >= (self.TravelStaminaMinSpeed or 3.0)

    -- The stamina discriminator only needs to run - and only needs to be believed - while
    -- BOTH mounted+ghosting AND going fast enough to be exertion. Armed exactly there, so its
    -- freeze clock starts at zero the instant that combined state begins rather than
    -- inheriting however long the horse happened to already be standing still (or walking)
    -- with flat stamina beforehand.
    local staminaArmed = mountedGhost and staminaGateOpen
    local hStam = self:TravelHorseStamina()
    local pStam = self:TravelPlayerStamina()
    local hFrozenFor = self:TravelStaminaFrozenFor("HStam", hStam, now, staminaArmed)
    local pFrozenFor = self:TravelStaminaFrozenFor("PStam", pStam, now, staminaArmed)

    -- Whether stamina is readable on this build at all, independent of whether the speed
    -- gate is currently open - the fallback below only wants the former.
    local staminaAvailable = (hStam ~= nil) or (pStam ~= nil)

    if self.TravelProbe then
        twLog(string.format(
            "at=%.0f,%.0f dt=%.2f dist=%.2f speed=%.2f mounted=%s state=%s | hSpd=%s hVel=%s selfMoving=%s | spanDist=%.1f spanSpd=%.1f gate=%s hStam=%s frozen=%s pStam=%s frozen=%s rate=%.1f | moving=%s walk=%s ghost=%s tp=%s",
            pos.x, pos.y, dt, dist, speed, tostring(mounted), tostring(st),
            hSpd and string.format("%.2f", hSpd) or "nil", hVel and string.format("%.2f", hVel) or "nil",
            tostring(horseSelfMoving), spanDist, spanSpeed, tostring(staminaGateOpen),
            hStam and string.format("%.2f", hStam) or "nil", hFrozenFor and string.format("%.1fs", hFrozenFor) or "-",
            pStam and string.format("%.2f", pStam) or "nil", pFrozenFor and string.format("%.1fs", pFrozenFor) or "-",
            rate, tostring(moving), tostring(walking), tostring(ghost), tostring(teleport)))
    end

    local why = nil

    if st ~= nil then
        -- The engine's answer, when available, overrides everything below.
        if st == self.TravelStateFastTravel or st == self.TravelStateCutscene or st == self.TravelStateSkipTime then
            why = "the engine says the player is in state " .. tostring(st) ..
                  (st == self.TravelStateCutscene and " (a cutscene)"
                   or st == self.TravelStateSkipTime and " (skipping time)" or " (fast travel)")
        end
    elseif teleport then
        why = string.format("%.0fm in one sample", dist)
    elseif ghost then
        if mounted then
            -- Riding and mounted fast travel are the SAME thing to a movement test of the
            -- PLAYER - distance with zero Henry-speed either way. They are not the same thing
            -- to the HORSE: one is moving itself, the other is being moved. So ask the horse
            -- first (TravelHorseMotion), with the same short grace the on-foot rule uses.
            if horseMotionKnown then
                if horseSelfMoving then
                    self._twMountedFrom = nil          -- a horse under a rider, at any pace
                else
                    self._twMountedFrom = self._twMountedFrom or now
                    -- Both clocks, and real ground covered: the horse silent for a full
                    -- second while the span has carried him metres, not centimetres.
                    if (now - self._twMountedFrom) >= (self.TravelMountedGraceSecs or 1.0)
                       and spanDist >= (self.TravelSpanMinDist or 8.0) then
                        why = string.format("mounted, carried %.0fm at %.1f m/s while the horse itself reports %.2f m/s",
                                            spanDist, spanSpeed, hSpd)
                    end
                end
            -- No horse-motion bind on this build: the stamina discriminator, which can only
            -- be trusted above the pace at which stamina drains at all (measured 2026-09-03:
            -- a canter at 5-6 m/s drains none, so the gate below is a poor substitute - it
            -- is here for a build that gives us nothing better).
            elseif not staminaGateOpen and staminaAvailable then
                -- Gate closed but stamina IS readable: a real walk/trot. Do nothing - not
                -- even the clock fallback, which exists only for a build with no stamina
                -- reading at all, not as a second opinion once one is available.
            elseif hFrozenFor ~= nil then
                if hFrozenFor >= (self.TravelStaminaFreezeSecs or 1.0) then
                    why = string.format("mounted, the horse's stamina has not moved in %.1fs at %.1f m/s", hFrozenFor, spanSpeed)
                end
            elseif pFrozenFor ~= nil then
                if pFrozenFor >= (self.TravelStaminaFreezeSecs or 1.0) then
                    why = string.format("mounted, his own stamina has not moved in %.1fs at %.1f m/s (no horse stamina on this build)", pFrozenFor, spanSpeed)
                end
            elseif (not staminaAvailable) and clockFast then
                -- Neither stamina getter answers on this build at all, so the speed gate
                -- above has nothing to do with - fall back to the clock regardless of pace,
                -- with its own grace so one noisy rate spike is not read as a whole crossing.
                self._twFallbackFrom = self._twFallbackFrom or now
                if (now - self._twFallbackFrom) >= (self.TravelFallbackGraceSecs or 1.0) then
                    why = string.format("mounted, the world clock is running %.1fx its normal rate (no stamina reading on this build)", rate)
                end
            else
                self._twFallbackFrom = nil
            end
        else
            -- On foot, distance with zero Henry-speed has no other explanation in ordinary
            -- play - walking, running and sprinting all report a speed. A short grace
            -- absorbs one noisy frame; it does not wait on the clock at all. The same
            -- ground-covered floor as the mounted rule, so an idle animation's drift while
            -- he stands in a conversation can never add up to a crossing.
            self._twOnFootFrom = self._twOnFootFrom or now
            if (now - self._twOnFootFrom) >= (self.TravelOnFootGraceSecs or 0.3)
               and spanDist >= (self.TravelSpanMinDist or 8.0) then
                why = string.format("on foot, carried %.0fm at %.1f m/s with none of his own", spanDist, spanSpeed)
            end
        end
    end

    if not (ghost and not mounted) then self._twOnFootFrom = nil end
    if not (ghost and mounted) then self._twMountedFrom = nil end
    if not (ghost and mounted and not staminaAvailable) then self._twFallbackFrom = nil end

    if why then
        self.FastTravelLastDetected = now
        if not self._twOn then
            self._twOn = true
            twLog("the player is being carried (" .. why .. ")")
            self:TravelBegin(why)
        end
    elseif self._twOn and self.FastTravelLastDetected
           and (now - self.FastTravelLastDetected) >= (self.TravelCoolSecs or 3.0) then
        self._twOn = false
        twLog("the crossing is over")
        self:TravelEnd()
    end
end

-- The two things that happen for the duration of a crossing. Both are idempotent.
-- Who travels WITH the player, and who is left exactly where they stand.
--
-- 2.3 stowed the whole company through the roster and put it back around the player. That
-- was wrong four different ways, all reported at once: the camp's own men were teleported
-- to the player, men told to wait followed anyway, the camp came down, and - worst - the
-- roster only ever stored "tier,hp", so a custom companion or an archer came back as a
-- generic merc. Nothing is stowed any more. Men who were with you are TELEPORTED to you at
-- the far end, which keeps the same entities and therefore their identity, gear and orders.
--
-- Left alone, by the mod's own state rather than by distance (the player may well be fast
-- travelling FROM his camp, so "near me" is not the test):
--   * camp residents - _G.MercInCamp and not in the sortie party (IsCampOut)
--   * the whole company when it is holding ground ("wait here" is HoldBegin)
mercenaries.TravelWith = {}

function mercenaries:TravelTakesAlong(ent)
    if not (ent and ent.id) then return false end
    if _G.MercenariesDismissed then return false end
    -- "Wait here" is squad-wide: if they are holding ground, nobody is dragged off it.
    if self.HoldAnchor then return false end
    if _G.MercInCamp then
        local w
        pcall(function() w = XGenAIModule.GetMyWUID(ent) end)
        -- In camp and not part of the sortie: he stays in camp.
        if w and not self:IsCampOut(tostring(w)) then return false end
    end
    return true
end

function mercenaries:TravelBegin(why)
    -- Remember who was actually following, before the crossing moves anything.
    self.TravelWith = {}
    local n = 0
    if self.TravelStow then
        for _, ent in pairs(self.ActiveMercs or {}) do
            if self:TravelTakesAlong(ent) then self.TravelWith[ent.id] = true; n = n + 1 end
        end
    end
    twLog(string.format("crossing begins (%s): %d man/men come along, the rest stay where they are",
                       tostring(why), n))

    -- Nothing of ours stands on the road he is crossing either.
    pcall(function()
        local g = 0
        for _, rec in pairs(self.LivePatrols or {}) do
            if rec.spawned then
                g = g + 1
                self:PatrolDespawnGang(rec, "the player is travelling")
            end
        end
        -- A gang taken down before the player ever met it must not spend the day's
        -- allowance: the crossing is why he never saw it.
        if g > 0 and self.PatrolDayRefund then self:PatrolDayRefund(g) end
        local now = System.GetCurrTime() or 0
        local until_ = now + (self.PatrolTravelGraceSecs or 90.0)
        if until_ > (self._patrolGraceUntil or 0) then self._patrolGraceUntil = until_ end
    end)
end

function mercenaries:TravelEnd()
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    local moved, lost = 0, 0
    for id in pairs(self.TravelWith or {}) do
        local e
        pcall(function() e = System.GetEntity(id) end)
        if e and pp then
            -- Scattered behind him rather than on him: a dozen men on one point is a
            -- physics pile, and the formation sorts them within a tick.
            local ang = math.random() * math.pi * 2
            local rad = 3.0 + math.random() * 6.0
            local spot = { x = pp.x + math.cos(ang) * rad, y = pp.y + math.sin(ang) * rad, z = pp.z }
            pcall(function()
                local gz = System.GetTerrainElevation(spot.x, spot.y)
                if gz and math.abs(gz - pp.z) < 8.0 then spot.z = gz end
            end)
            pcall(function() e:SetPos(spot) end)
            if self.NoteTeleport then pcall(function() self:NoteTeleport(e) end) end
            moved = moved + 1
        else
            lost = lost + 1
        end
    end
    self.TravelWith = {}
    if moved > 0 then
        twLog(string.format("crossing over: %d man/men brought to you%s", moved,
             lost > 0 and (", " .. lost .. " could not be found") or ""))
        -- They arrive as a batch, which is exactly the burst the follow verify exists for.
        -- No SetState here: a man who was following still is, and one who was not is not
        -- being dragged into it.
        pcall(function() self:BeginFollowVerify("travel") end)
    elseif lost > 0 then
        twLog(lost .. " man/men could not be found after the crossing")
    end
end

function mercenaries:TravelWatchOnLoad()
    self._twPos, self._twT, self._twOnFootFrom, self._twOn = nil, nil, nil, false
    self._twWT, self._twFallbackFrom = nil, nil
    self._twSpanAt, self._twSpanPos, self._twMountedFrom = nil, nil, nil
    self._twHorseMovedAt = nil
    self._twHStamVal, self._twHStamAt, self._twHStamArmed = nil, nil, false
    self._twPStamVal, self._twPStamAt, self._twPStamArmed = nil, nil, false
end

function mercenaries:TravelProbeSet(on)
    self.TravelProbe = on and true or false
    twLog("probe " .. (self.TravelProbe and
          "ON - every 100ms sample is logged; fast travel once, then send the log" or "off"))
end

-- Live readings on demand, without leaving the probe running (which writes a line every
-- 100 ms). Mount up (or not) and type this a few times over a couple of seconds to see
-- whether stamina is actually ticking.
function mercenaries:TravelStaminaReport()
    local hStam, pStam = self:TravelHorseStamina(), self:TravelPlayerStamina()
    local hSpd, hVel = self:TravelHorseMotion()
    local hHealth
    pcall(function()
        local h = player.human:GetHorse()
        local e = h and XGenAIModule.GetEntityByWUID(h)
        hHealth = e and e.soul and e.soul:GetState("health")
    end)
    local pSpd
    pcall(function() pSpd = player:GetSpeed() end)
    twLog(string.format("horse: speed=%s |velocity|=%s stamina=%s health=%s   player: speed=%s stamina=%s",
          hSpd and string.format("%.2f", hSpd) or "unavailable",
          hVel and string.format("%.2f", hVel) or "unavailable",
          hStam and string.format("%.2f", hStam) or "unavailable",
          hHealth and string.format("%.2f", hHealth) or "unavailable",
          pSpd and string.format("%.2f", pSpd) or "unavailable",
          pStam and string.format("%.2f", pStam) or "unavailable"))
end

