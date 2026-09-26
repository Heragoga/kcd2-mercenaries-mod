-- A second, independent record of where the player stands in the Kleinkrieg arc.
--
-- Why a second one. The contract has always been persisted as the BCQuest blob, and on
-- 2026-09-04 three sessions of logs proved it never comes back:
--
--     [BanditCampQuest] restore [BCQuest]: LoadString gave NIL - nothing was saved
--
-- Not the scrub latch (no PERSISTENCE IS OFF line), and not the rebuild (the rebuild is
-- never reached). The tag is simply not in the save. Rather than keep guessing at why one
-- tag goes missing, this writes the same facts under a DIFFERENT tag at DIFFERENT moments,
-- and the restore takes whichever survives. If both come back NIL the fault is the saver
-- mechanism itself, not this quest - and merc_save_probe says so in one line.
--
-- The stage is deliberately coarse and named the way a player would describe it, because
-- that is what has to survive: which encounter are we before or after.
--
--   0  no contract          nothing taken, or the arc is finished
--   1  taken                accepted, camp not cleared
--   2  cleared              every bandit down, letter still to hand in
--   3  letter in hand       the letter is on the player
--   4  paid                 handed in; the next contract is available

mercenaries.KKStageTag   = "KKStage"
mercenaries.KKStageNames = { [0] = "no contract", [1] = "taken", [2] = "cleared",
                             [3] = "letter in hand", [4] = "paid" }

local function kLog(s) System.LogAlways("[KKStage] " .. tostring(s)) end

-- Everything needed to put the camp back, in one line. Deliberately the same facts as the
-- BCQuest blob rather than a subset: a record that cannot rebuild the camp is a record
-- that only tells you how badly things went.
function mercenaries:KKStageWrite(stage, why)
    local S = self.BCQ_KK
    if not S then return end
    local site = S.site or {}
    local blob = string.format("%d|%s|%s|%d|%d|%d|%.2f|%.2f|%.2f|%.4f|%s|%s|%s",
        stage or 0, tostring(site.name or "?"), tostring(S.group or "bandit"),
        S.target or 0, S.killed or 0, S.reward or 0,
        site.x or 0, site.y or 0, site.z or 0, site.yaw or 0,
        tostring(S.contractIdx or 0),
        S.leaderDead and "1" or "0", S.paid and "1" or "0")
    pcall(function() self:SaveString(self.KKStageTag, blob) end)
    self.KKStage = stage
    kLog(string.format("stage %d (%s) - %s   [%s]", stage or 0,
        tostring(self.KKStageNames[stage or 0]), tostring(why), blob))
end

function mercenaries:KKStageRead()
    local raw
    pcall(function() raw = self:LoadString(self.KKStageTag) end)
    if not raw or raw == "" then
        kLog("read: NIL - no stage record in this save")
        return nil
    end
    local f = {}
    for part in string.gmatch(raw, "([^|]+)") do table.insert(f, part) end
    if #f < 13 then kLog("read: unreadable record: " .. tostring(raw)); return nil end
    local rec = {
        stage = tonumber(f[1]) or 0, site = f[2], group = f[3],
        target = tonumber(f[4]) or 0, killed = tonumber(f[5]) or 0,
        reward = tonumber(f[6]) or 0,
        x = tonumber(f[7]), y = tonumber(f[8]), z = tonumber(f[9]), yaw = tonumber(f[10]),
        contractIdx = tonumber(f[11]), leaderDead = (f[12] == "1"), paid = (f[13] == "1"),
    }
    kLog(string.format("read: stage %d (%s) at '%s', %d/%d down",
        rec.stage, tostring(self.KKStageNames[rec.stage]), tostring(rec.site),
        rec.killed, rec.target))
    return rec
end

-- The recovery path. Called from the load AFTER the BCQuest restore has had its go: if
-- that produced a live contract this does nothing, and if it did not, this puts one back
-- from the stage record so the camp can be rebuilt by the ordinary monitor.
function mercenaries:KKStageRecover()
    local S = self.BCQ_KK
    if not S then return end
    if S.active then
        kLog("BCQuest restored the contract - stage record not needed")
        return
    end
    local rec = self:KKStageRead()
    if not rec then return end
    if rec.stage <= 0 or rec.stage >= 4 then
        kLog("stage " .. rec.stage .. " needs no camp")
        return
    end

    S.active     = true
    S.spawned    = false          -- the monitor rebuilds it on the next tick
    S.group      = rec.group
    S.target     = rec.target
    S.killed     = rec.killed
    S.reward     = rec.reward
    S.cleared    = (rec.stage >= 2)
    S.leaderDead = rec.leaderDead
    S.paid       = rec.paid
    S.contractIdx = (rec.contractIdx ~= 0) and rec.contractIdx or nil
    S.letterTaken = (rec.stage >= 3)
    S.site = { name = rec.site, x = rec.x, y = rec.y, z = rec.z,
               yaw = rec.yaw, layout = "default" }
    S.health, S.missing, S.chatCooldown = {}, {}, {}
    S.entities, S.bandits, S.spots, S.actorSet = {}, {}, {}, {}
    S.leaderId = nil
    -- Same as the BCQuest path: whatever the old session left standing goes first, or the
    -- rebuild stacks a second camp on it.
    for _, s in ipairs(self.BanditCampSites or {}) do
        if s.name == rec.site then
            S.site.layout = s.layout or "default"
            S.site.route, S.site.pt = s.route, s.pt
        end
    end
    pcall(function() self:ClearAnyLeftoverBanditCamp() end)
    kLog(string.format("RECOVERED from the stage record: '%s', stage %d (%s), %d/%d down"
        .. " - the monitor rebuilds the camp on the next tick",
        tostring(rec.site), rec.stage, tostring(self.KKStageNames[rec.stage]),
        rec.killed, rec.target))
end

function mercenaries:KKStageReport()
    kLog("in-session stage: " .. tostring(self.KKStage) ..
         " (" .. tostring(self.KKStageNames[self.KKStage or -1]) .. ")")
    self:KKStageRead()
end

-- ==== does the saver mechanism work at all? ====
--
-- One command that settles it, because "the contract did not come back" has three
-- completely different causes and no log could tell them apart: the write never happened,
-- the write happened but did not reach the save, or the read is broken.
--
--   merc_save_probe          write a fresh value, read it straight back
--   merc_save_probe check    read only - run this AFTER a save and reload
mercenaries.SaveProbeTag = "SaveProbe"

function mercenaries:SaveProbe(line)
    local a = self:CmdArgs(line)
    local w = string.lower(tostring(a[1] or ""))
    local prev
    pcall(function() prev = self:LoadString(self.SaveProbeTag) end)

    if w == "check" or w == "read" then
        if prev then
            System.LogAlways("[SaveProbe] survived: " .. tostring(prev))
            System.LogAlways("[SaveProbe] the saver mechanism DOES persist across a reload.")
        else
            System.LogAlways("[SaveProbe] NOTHING came back.")
            System.LogAlways("[SaveProbe] the saver mechanism does NOT survive a save/reload")
            System.LogAlways("[SaveProbe] on this build - which is the Kleinkrieg bug's cause,")
            System.LogAlways("[SaveProbe] and every other 'it did not persist' report with it.")
        end
        return
    end

    local mark = "probe_" .. tostring(math.random(100000, 999999))
    pcall(function() self:SaveString(self.SaveProbeTag, mark) end)
    local back
    pcall(function() back = self:LoadString(self.SaveProbeTag) end)
    System.LogAlways("[SaveProbe] previous value: " .. tostring(prev))
    System.LogAlways("[SaveProbe] wrote: " .. mark)
    System.LogAlways("[SaveProbe] read back in-session: " .. tostring(back) ..
        (tostring(back) == mark and "   OK" or "   MISMATCH - the write did not take"))
    System.LogAlways("[SaveProbe] now SAVE, reload, and run:  merc_save_probe check")
end
