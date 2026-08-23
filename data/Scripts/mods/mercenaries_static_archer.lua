-- Static (tower) archers: an archer that never moves and is NOT part of the
-- squad. Everything squad-related keys off mercenaries.ActiveMercs (Recount and
-- so the whole logistics/camp/formation stack), so simply never adding one to
-- that table keeps it out of the merc count, wages, food, morale, camp roles,
-- deploy and recall for free. They live in their own registry instead.
--
-- They also get their own souls + brain (static_archer_brain ->
-- static_archer_scheduler.xml, see soul__static_archers.xml) rather than the
-- ranged mercs' archer_brain, because that one follows/camps/patrols. The
-- scheduler only ever does: pick a target (here, in Lua) -> fire the
-- combat_archer_static interrupt (standFire, no chase, no player leash).
--
-- WHO they shoot is this file's job, per-archer, via StaticArcherMode:
--   "defend"      - the player's and the mercs' enemies (a friendly tower)
--   "hostile"     - the player and their mercs (an enemy tower)
--   "mod_enemies" - only NPCs this mod spawned as enemies (see ModEnemyPrefixes)
--   "wall"        - only the ENEMY'S ARCHERS: a mod-spawned enemy who is himself a static
--                   archer. The garrison of Raborsch uses it so the walls duel the besiegers'
--                   archers and leave the foot alone.
-- Faction is deliberately NOT the lever: they sit in mercenariesFaction and the
-- attack sets RelationOverride="Hostile", so the mode alone decides.

mercenaries.StaticArcherSouls = {
    "8d2f4a61-7b93-4c05-9e18-3a6d5f2b7c41",
    "9e3a5b72-8c04-4d16-af29-4b7e6a3c8d52",
    "af4b6c83-9d15-4e27-b03a-5c8f7b4d9e63",
    "b05c7d94-ae26-4f38-c14b-6d907c5eaf74",
    "c16d8ea5-bf37-4049-d25c-7ea18d6fb085",
}
mercenaries.StaticArcherSoulIndex = 1

-- Tower archers for somebody ELSE's camp (the quartermaster's bandit-camp contract). Same
-- static_archer_brain, but in enemiesFaction so the camp does not attack its own tower, and
-- on a bandit skald character so they read as bandits instead of "mercenary archer". They
-- are killable (soul_vip_class_id 0) - the contract needs them dead.
mercenaries.StaticArcherEnemySouls = {
    "d1e2f3a4-5b6c-4d7e-8f90-1a2b3c4d5e01",
    "d1e2f3a4-5b6c-4d7e-8f90-1a2b3c4d5e02",
    "d1e2f3a4-5b6c-4d7e-8f90-1a2b3c4d5e03",
}
mercenaries.StaticArcherEnemySoulIndex = 1

-- What an enemy tower archer WEARS: a FIXED two-outfit set, not a roll from a group pool.
-- A bowman perched on a platform should look like a lookout in rags rather than a
-- man-at-arms, so both are light looter kit (docs/enemies.md) - but the reason they are
-- pinned is the tower descent: when the camp's ground is cleared the static archer is
-- swapped for an ordinary bandit archer, and a random outfit on either end would change his
-- clothes mid-fight. The chosen preset is recorded on his StaticArchers record so the
-- replacement can wear exactly the same thing. See docs/bandit-camp-quest.md.
mercenaries.StaticArcherEnemyOutfits = {
    "20aba0c4-1cfb-42de-97dd-939530d6240d",
    "2285cbe9-3962-4093-94a9-86f556e5bf2f",
}
mercenaries.StaticArcherEnemyOutfitIndex = 1

-- Every NPC name prefix this mod spawns as an ENEMY. The "mod_enemies" mode
-- shoots only these, and "defend" treats them as valid targets. Renegades are the
-- first; add each new mod enemy's spawn-name prefix here and both modes pick it
-- up with no other change.
mercenaries.ModEnemyPrefixes = {
    "SpawnedRenegade_",   -- legacy spawner
    "SpawnedEnemy_",      -- the enemy-groups spawner (SpawnEnemyAt) - what actually spawns now
}

-- "besieger" is the siege of Raborsch's attacker mode: he shoots the player, the player's
-- mercs AND the garrison's own tower archers - everyone who is not on his side. "hostile"
-- deliberately spares every static archer so two towers never trade shots, which is right for
-- a bandit camp and wrong for a siege, where the two lines of archers are the whole picture.
mercenaries.StaticArcherModes = { defend = true, hostile = true, mod_enemies = true,
                                  besieger = true, wall = true }
mercenaries.StaticArcherDefaultMode = "defend"
-- Console commands pass the mode as an int (the KCD console mangles bare word
-- args): 1 = defend, 2 = hostile, 3 = mod_enemies. ResolveStaticArcherMode also
-- accepts the mode name directly, so Lua callers can keep using strings.
mercenaries.StaticArcherModeList = { "defend", "hostile", "mod_enemies" }

function mercenaries:ResolveStaticArcherMode(v)
    if v == nil or v == "" then return nil end
    local n = tonumber(v)
    if n then return self.StaticArcherModeList[n] end   -- nil if out of range
    v = tostring(v)
    return self.StaticArcherModes[v] and v or nil
end

-- Marksman buff applied to every static archer on spawn (merc_static_archer_buff
-- in buff__mercenaries.xml): heavy marksmanship + agility + double action speed,
-- so a tower archer aims and looses much faster than a footman. See the buff's
-- own note on why marksmanship is the lever for "faster aiming/reloading".
mercenaries.StaticArcherBuff = "e5a10008-2c4b-4e6a-9f01-000000000008"
-- A tower archer sees and shoots much further than a footman on the ground - his
-- reach is deliberately well past the mercs' 50m TargetDetectionRadius.
mercenaries.StaticArcherRange = 90.0        -- how far one will look for a target

-- A bandit camp's own archers engage on THEIR terms, not the foot bandits'. The camp wakes at
-- BanditCampAlertRange (10m), which is right for men standing round a fire and quite wrong for
-- a lookout on a tower: he can see 90m and had to wait until the player was almost inside the
-- camp before loosing. Anything inside this radius is fair game to him, and his first arrow
-- wakes the camp - which is how a watchtower is supposed to work.
mercenaries.BanditCampArcherAlertRange = 45.0

-- Laying out a siege puts defenders and attackers within sight of each other, and they open
-- fire the moment they are placed - which makes the place impossible to build in. While this
-- is on, every static archer holds fire and is not a valid target for anyone. It is turned on
-- by the siege builder and off by merc_siege_go.
mercenaries.SiegePeace = false

function mercenaries:SiegeSuppressed(wuidStr)
    if not self.SiegePeace then return false end
    return (self.StaticArchers ~= nil) and (self.StaticArchers[tostring(wuidStr)] ~= nil)
end
mercenaries.StaticArcherStickRange = 100.0  -- keep the current target while it is this close

-- [wuidStr] = { mode =, ent = }
mercenaries.StaticArchers = {}
-- [wuidStr] = targetWuidStr, cleared by combat_archer_static's OnFail
mercenaries.StaticArcherTargetOf = {}

-- Placement. SetPos is the mod's teleport everywhere else (it is what puts the
-- forge smith on his off-navmesh bench), but putting a NPC on a tower deck needs
-- care:
--   * on a FRESHLY spawned NPC one SetPos does not stick - the spawn settles the
--     body afterwards and he ends up on the ground;
--   * placing him exactly ON the footing puts his capsule inside it, and he gets
--     shoved out or tunnels straight through - which is what made every footing
--     look "unreliable".
-- So he is DROPPED: put a short distance ABOVE the spot and allowed to fall onto
-- it. The tick then only intervenes if he actually fell through (ended up well
-- below the spot) - it no longer fights the settle, which was half the jitter.
-- Once he is standing he stays: his brain never issues a Move.
-- [wuidStr] = { ent =, pos =, ticks = }
mercenaries.StaticArcherPending = {}
mercenaries.StaticArcherDropHeight = 1.2     -- spawn/retry this far ABOVE the spot
mercenaries.StaticArcherFallTol = 1.8        -- this far below the spot = he fell through
mercenaries.StaticArcherPlaceTicks = 6       -- retry the drop this many times...
mercenaries.StaticArcherPlaceInterval = 400  -- ...this far apart (ms), time to land

local function dropPos(self, pos)
    return { x = pos.x, y = pos.y, z = pos.z + self.StaticArcherDropHeight }
end

function mercenaries.StaticArcherPlaceTick()
    local self = mercenaries
    local again = false
    for ws, p in pairs(self.StaticArcherPending) do
        local landed = false
        p.ticks = (p.ticks or 0) - 1
        pcall(function()
            local cur = p.ent:GetWorldPos()
            if cur then
                -- Anywhere at or near the spot (he may rest slightly above/below
                -- the asked height depending on the footing) counts as landed.
                -- Only a real fall-through is worth another drop.
                if cur.z > (p.pos.z - self.StaticArcherFallTol) then landed = true end
            end
            if not landed then p.ent:SetPos(dropPos(self, p.pos)) end
        end)
        if landed or p.ticks <= 0 then
            self.StaticArcherPending[ws] = nil
            System.LogAlways("[StaticArcher] " .. (landed and "landed OK" or "FELL THROUGH - footing does not hold NPCs"))
        else
            again = true
        end
    end
    if again then Script.SetTimerForFunction(self.StaticArcherPlaceInterval, "mercenaries.StaticArcherPlaceTick") end
end

-- Drop `ent` onto `pos` (see the note above). `pos` is where he should END UP, and
-- is remembered as his anchor so the keeper below can put him back.
function mercenaries:PlaceStaticArcher(ent, pos)
    if not (ent and pos) then return end
    local ws = tostring(ent.this and ent.this.id or ent.id)
    local anchor = { x = pos.x, y = pos.y, z = pos.z }
    local rec = self.StaticArchers[ws]
    if rec then rec.anchor = anchor end
    pcall(function() ent:SetPos(dropPos(self, pos)) end)
    self.StaticArcherPending[ws] = { ent = ent, pos = anchor, ticks = self.StaticArcherPlaceTicks }
    Script.SetTimerForFunction(self.StaticArcherPlaceInterval, "mercenaries.StaticArcherPlaceTick")
end

-- KEEPER. Nothing physical reliably holds an NPC off the ground: the AI
-- ground-snaps its actors, so a spawned prop wins for a moment and the AI wins
-- after that - which is why every footing tested "unreliable" and why the drop
-- height made no difference. Since a static archer never moves anyway, the fix is
-- simply to notice he has fallen and put him back. Called every second from
-- MonitorLoop; only touches an archer that is actually well below his anchor, so
-- it costs nothing while he is standing.
function mercenaries:KeepStaticArchersUp()
    for ws, rec in pairs(self.StaticArchers) do
        local a, ent = rec.anchor, rec.ent
        -- holdTest archers are the diagnostic row (merc_tower_hold): each one is
        -- deliberately held by its own strategy so its raw behaviour can be judged,
        -- so the slow global keeper must leave them alone.
        if a and ent and not self.StaticArcherPending[ws] and not rec.holdTest and not rec.attached then
            pcall(function()
                local cur = ent:GetWorldPos()
                if cur and cur.z < (a.z - self.StaticArcherFallTol) then
                    ent:SetPos({ x = a.x, y = a.y, z = a.z + 0.05 })
                end
            end)
        end
    end
end

-- WINNING HOLD (merc_tower_hold #6): parent the archer to a static, UNSCALED anchor
-- entity at his feet. A child entity's transform is slaved to its parent, which
-- overrides the AI ground-snap that pulled him down - so he is held with no keeper
-- and keeps shooting (the physics-off / gravity strategies froze his aim; only the
-- attach kept it). The anchor MUST be unscaled: attaching to the scaled deck slab in
-- testing made him inherit its 2.5x0.3 scale and squashed him flat and wide. Any
-- deliberate resize is applied to the archer himself via StaticArcherScale, not the
-- anchor. Because the child also inherits the anchor's ORIENTATION, the anchor is
-- turned to the archer's facing so he ends up looking outward, not snapped to east.
mercenaries.StaticArcherAnchors = {}     -- [wuidStr] = anchor entity id
mercenaries.StaticArcherAnchorModel = "objects/manmade/common_furniture/crates/crate_low_a.cgf"
mercenaries.StaticArcherScale = 1.0      -- resize the man himself (merc_static_archer_scale)

function mercenaries:AttachStaticArcher(ent, pos, faceAngle)
    if not (ent and pos) then return end
    local ws = tostring(ent.this and ent.this.id or ent.id)
    faceAngle = faceAngle or 0
    -- drop any previous anchor for this archer (re-attach on a re-drop)
    local old = self.StaticArcherAnchors[ws]
    if old then pcall(function() System.RemoveEntity(old) end); self.StaticArcherAnchors[ws] = nil end

    local anchor
    pcall(function()
        anchor = System.SpawnEntity({
            class = "mercenaries_Prop",
            name = "MercArcherAnchor_" .. tostring(math.random(100000, 999999)),
            position = { x = pos.x, y = pos.y, z = pos.z },
            orientation = { x = math.cos(faceAngle), y = math.sin(faceAngle), z = 0 },
            properties = { object_Model = self.StaticArcherAnchorModel, bMissionCritical = false,
                           bSaved_by_game = false, bSerialize = false },
        })
    end)
    if not anchor then System.LogAlways("[StaticArcher] anchor spawn FAILED"); return end
    pcall(function() anchor:SetAngles({ x = 0, y = 0, z = faceAngle }) end)
    pcall(function() anchor:DrawSlot(0, 0) end)                          -- invisible
    pcall(function() ent:SetPos({ x = pos.x, y = pos.y, z = pos.z }) end)
    pcall(function() anchor:AttachChild(ent.id, 0) end)
    pcall(function() ent:SetScale(self.StaticArcherScale) end)          -- undo any inherited squash / resize

    self.StaticArcherAnchors[ws] = anchor.id
    local rec = self.StaticArchers[ws]
    if rec then rec.anchorEnt = anchor.id; rec.attached = true; rec.anchor = { x = pos.x, y = pos.y, z = pos.z } end
    System.LogAlways(string.format("[StaticArcher] attached to unscaled anchor, scale %.2f", self.StaticArcherScale))

    if not self.StaticArcherPinActive then
        self.StaticArcherPinActive = true
        Script.SetTimerForFunction(self.StaticArcherPinInterval, "mercenaries.StaticArcherPinTick")
    end
end

-- DRIFT PIN. The attach holds an archer's HEIGHT (his transform is slaved to the
-- static anchor, which is what beats the AI ground-snap) but it does NOT stop the AI
-- issuing horizontal movement - the attack tree still repositions/strafes him. So he
-- strolls off the deck edge while keeping the deck's height: "walking off the
-- platform but still floating at its height". Nothing about the attach prevents that,
-- so he is simply put back whenever he wanders past StaticArcherDriftTol. Checked
-- often enough (250ms) that a step or two is the most that ever shows, and only
-- touched when he has actually moved, so a standing archer is never interrupted.
mercenaries.StaticArcherDriftTol = 0.6      -- how far he may wander before being put back
mercenaries.StaticArcherPinInterval = 250   -- ms between drift checks
mercenaries.StaticArcherPinActive = false

function mercenaries.StaticArcherPinTick()
    local self = mercenaries
    local any = false
    for ws, rec in pairs(self.StaticArchers) do
        if rec.attached and rec.anchor and rec.ent and not self.StaticArcherPending[ws] then
            any = true
            pcall(function()
                local a = rec.anchor
                local cur = rec.ent:GetWorldPos()
                if not cur then return end
                local dx, dy, dz = cur.x - a.x, cur.y - a.y, cur.z - a.z
                local tol = self.StaticArcherDriftTol
                if (dx * dx + dy * dy) > (tol * tol) or math.abs(dz) > tol then
                    rec.ent:SetPos({ x = a.x, y = a.y, z = a.z })
                end
            end)
        end
    end
    self.StaticArcherPinActive = any
    if any then Script.SetTimerForFunction(self.StaticArcherPinInterval, "mercenaries.StaticArcherPinTick") end
end

-- Live-resize every static archer. He inherits scale 1 from the unscaled anchor, so
-- this is a straight scale on the man himself. merc_static_archer_scale.
function mercenaries:SetStaticArcherScale(s)
    s = tonumber(s); if not s or s <= 0 then System.LogAlways("[StaticArcher] scale must be > 0"); return end
    self.StaticArcherScale = s
    for _, rec in pairs(self.StaticArchers) do
        if rec.ent then pcall(function() rec.ent:SetScale(s) end) end
    end
    System.LogAlways("[StaticArcher] scale = " .. s)
end

mercenaries.StaticArcherNamePrefix = "SpawnedTower_archer_"

-- Either the player's own tower archer (SpawnedTower_archer_ prefix) or an enemy camp's
-- (tagged '_towerarcher_' inside a SpawnedEnemy_ name). Both must answer true: this gates
-- the drop-to-spot keeper and the rule that towers never shoot each other.
mercenaries.StaticArcherEnemyTag = "_towerarcher_"

function mercenaries:IsStaticArcherName(name)
    if name == nil then return false end
    if string.find(name, self.StaticArcherNamePrefix, 1, true) == 1 then return true end
    return string.find(name, self.StaticArcherEnemyTag, 1, true) ~= nil
end

function mercenaries:IsModEnemyName(name)
    if not name then return false end
    for _, p in ipairs(self.ModEnemyPrefixes) do
        if string.find(name, p, 1, true) then return true end
    end
    return false
end

function mercenaries:IsStaticArcher(wuid)
    return self.StaticArchers[tostring(wuid)] ~= nil
end

function mercenaries:GetStaticArcherMode(wuid)
    local rec = self.StaticArchers[tostring(wuid)]
    return (rec and rec.mode) or self.StaticArcherDefaultMode
end

-- Set one archer's mode, or every archer's if `wuid` is nil. `mode` may be an int
-- (1/2/3 from the console) or the mode name (from Lua callers).
function mercenaries:SetStaticArcherMode(mode, wuid)
    local resolved = self:ResolveStaticArcherMode(mode)
    if not resolved then
        System.LogAlways("[StaticArcher] unknown mode '" .. tostring(mode) .. "' - use 1=defend 2=hostile 3=mod_enemies")
        return
    end
    mode = resolved
    if wuid then
        local rec = self.StaticArchers[tostring(wuid)]
        if rec then rec.mode = mode end
    else
        for _, rec in pairs(self.StaticArchers) do rec.mode = mode end
        self.StaticArcherDefaultMode = mode
    end
    -- Drop current targets so the new mode takes effect on the next scan.
    self.StaticArcherTargetOf = {}
    System.LogAlways("[StaticArcher] mode = " .. mode)
end

-- Spawn one at `pos` (already ground/deck placed by the caller - a tower deck, so
-- it is NOT snapped to terrain here). Deliberately not added to ActiveMercs.
-- `enemyGroup` (optional) makes this somebody else's tower - a bandit-camp watchtower. It
-- switches BOTH the soul (enemiesFaction + a bandit character, so the camp does not attack
-- its own tower and it does not read as "mercenary archer") and the clothing. Who he shoots
-- is still `mode`. See docs/bandit-camp-quest.md.
function mercenaries:SpawnStaticArcher(pos, mode, faceAngle, enemyGroup, elevated)
    if not pos then return nil end
    mode = (mode and self.StaticArcherModes[mode]) and mode or self.StaticArcherDefaultMode

    local ent
    local ok, err = pcall(function()
        local soulGuid
        if enemyGroup then
            local i = self.StaticArcherEnemySoulIndex
            soulGuid = self.StaticArcherEnemySouls[i]
            self.StaticArcherEnemySoulIndex = (i % #self.StaticArcherEnemySouls) + 1
        else
            local idx = self.StaticArcherSoulIndex
            soulGuid = self.StaticArcherSouls[idx]
            self.StaticArcherSoulIndex = idx + 1
            if self.StaticArcherSoulIndex > #self.StaticArcherSouls then self.StaticArcherSoulIndex = 1 end
        end

        -- '_archer_' in the name so the archer weapon/ammo helpers
        -- (IsArcherName, EquipArcherWeapon, GiveArcherAmmo) apply as-is; the
        -- SpawnedTower_ prefix is what keeps it out of everything else.
        --
        -- An enemy tower archer additionally carries 'SpawnedEnemy_' so the rest of the mod
        -- reads him as a hostile: SideOf() gives him the enemy combat rules instead of the
        -- merc leash to the player, and IsModEnemyName lets the squad and any friendly
        -- tower shoot back at him. IsStaticArcherName matches on the '_towerarcher_' tag.
        local entityName
        if enemyGroup then
            entityName = "SpawnedEnemy_towerarcher_archer_" .. self.ArcherTier .. "_" ..
                         tostring(math.random(10000, 99999)) .. "_" .. soulGuid
        else
            entityName = self.StaticArcherNamePrefix .. self.ArcherTier .. "_" ..
                         tostring(math.random(10000, 99999)) .. "_" .. soulGuid
        end

        System.SpawnEntity({
            class = "NPC",
            name = entityName,
            position = pos,
            orientation = { x = 0, y = 0, z = faceAngle or 0 },
            properties = { guidSharedSoulId = soulGuid },
        })
        ent = System.GetEntityByName(entityName)
        if not ent then return end

        self:EnsureMercIsAlwaysRendered(ent)
        -- An enemy tower archer takes one of the two pinned outfits directly rather than a
        -- roll from a group pool, so his replacement on descent can match him exactly.
        local outfit
        if enemyGroup then
            local i = self.StaticArcherEnemyOutfitIndex
            outfit = self.StaticArcherEnemyOutfits[i]
            self.StaticArcherEnemyOutfitIndex = (i % #self.StaticArcherEnemyOutfits) + 1
            if outfit then pcall(function() ent.actor:EquipClothingPreset(outfit) end) end
        else
            self:EquipMercenary(ent, _G.MercCurrentOutfit or 1)
        end
        -- EquipArcherWeapon has to run either way: the bow and its 40 rounds are separate
        -- from clothing, and an archer with no ammo looses once and then stands there.
        self:EquipArcherWeapon(ent)
        pcall(function() ent.soul:AddBuff(self.StaticArcherBuff) end)   -- fast, deadly marksman

        -- The probe caught these at vdr=100 while every merc read 1000: they are NPCs, and
        -- nothing was pinning NPC view distance. Same call the mod already makes on props.
        pcall(function() ent:SetViewDistUnlimited() end)

        local ws = tostring(ent.this and ent.this.id or ent.id)
        -- `outfit` is read back by BanditCampBringArchersDown so the man who walks down the
        -- tower is wearing what the man on top of it was wearing.
        -- `elevated` = he is stood on a tower platform, out of reach of anything without a
        -- bow. Only the tower passes it; cart archers stand about a metre up on the wagon bed
        -- and are perfectly reachable, so they stay fair game for everyone.
        self.StaticArchers[ws] = { mode = mode, ent = ent, outfit = outfit, elevated = elevated }
        -- The shared NPC scan is player-centred; a tower reaches StaticArcherRange around
        -- ITSELF, so the scan must be widened or a remote tower goes uncovered (falls back
        -- to its own query, which is correct, just not the win).
        self:PerfWantRadius(self.StaticArcherRange)
        -- Put him where he was asked for and hold him there - a fresh NPC settles
        -- to the ground right after spawning, so one SetPos here is not enough.
        self:PlaceStaticArcher(ent, pos)
        System.LogAlways("[StaticArcher] spawned '" .. entityName .. "' mode=" .. mode)
    end)
    if not ok then System.LogAlways("[StaticArcher] SpawnStaticArcher error: " .. tostring(err)) end
    return ent
end

-- Remove one (its tower came down).
function mercenaries:RemoveStaticArcher(ent)
    if not ent then return end
    local ws = tostring(ent.this and ent.this.id or ent.id)
    self.StaticArchers[ws] = nil
    self.StaticArcherTargetOf[ws] = nil
    self.StaticArcherPending[ws] = nil   -- stop re-placing a corpse
    local anchorId = self.StaticArcherAnchors[ws]
    if anchorId then pcall(function() System.RemoveEntity(anchorId) end); self.StaticArcherAnchors[ws] = nil end
    pcall(function() System.RemoveEntity(ent.id) end)
end

function mercenaries:ClearStaticArchers()
    local n = 0
    for ws, rec in pairs(self.StaticArchers) do
        if rec.ent then pcall(function() System.RemoveEntity(rec.ent.id) end) end
        local anchorId = self.StaticArcherAnchors[ws]
        if anchorId then pcall(function() System.RemoveEntity(anchorId) end) end
        self.StaticArchers[ws] = nil
        n = n + 1
    end
    self.StaticArcherTargetOf = {}
    self.StaticArcherPending = {}
    self.StaticArcherAnchors = {}
    System.LogAlways("[StaticArcher] removed " .. n)
end

-- Is `ent` a thing this archer should shoot, given its mode? Only used by the
-- "hostile" / "mod_enemies" modes - "defend" defers to the mercs' own
-- IsValidEnemy instead (see FindStaticArcherTarget).
function mercenaries:StaticArcherWantsTarget(mode, ent, isPlayer)
    local name = (not isPlayer) and (ent:GetName() or "") or ""
    if mode == "hostile" then
        -- The player and their mercs (not other tower archers, not mod enemies).
        if isPlayer then return true end
        if self:IsStaticArcherName(name) then return false end
        if self:IsModEnemyName(name) then return false end
        return self.ActiveMercs[name] ~= nil
    elseif mode == "mod_enemies" then
        return (not isPlayer) and self:IsModEnemyName(name)
    elseif mode == "wall" then
        -- The garrison on the walls. ONLY the besiegers' own archers: a mod-spawned enemy that
        -- is himself a static archer. Not the assaulting foot - shooting them is what made the
        -- whole besieging line turn round and swarm the wall instead of pressing the assault,
        -- because a man who is being shot at fights back whatever his orders were. Not fellow
        -- defenders either: they are SpawnedTower_archer_, which is a static archer name but not
        -- a mod-enemy one.
        return (not isPlayer) and self:IsModEnemyName(name) and self:IsStaticArcherName(name)
    elseif mode == "besieger" then
        -- Everyone but his own side. His own are the mod-spawned enemies (SpawnedEnemy_,
        -- which covers the other besiegers and their archers); everything else that can be
        -- shot at is the player, their mercs, or a defender on a tower.
        if isPlayer then return true end
        if self:IsModEnemyName(name) then return false end
        return (self.ActiveMercs[name] ~= nil) or self:IsStaticArcherName(name)
    end
    return false
end

-- "defend" target pick: exactly the mercs' own logic, just with a longer reach -
-- a tower sees further than a footman. That means the squad's definition of an
-- enemy (IsValidEnemy: hostile at the -1 faction floor, weapon drawn, not
-- fleeing/surrendering, never one of our own souls), and the player's current
-- combat target taken first, same as the mercs' fallback pass
-- (PickCombatTarget). The only change is the range: IsValidEnemy measures
-- against TargetDetectionRadius, so it is raised to StaticArcherRange for the
-- scan and put straight back.
--
-- The mercs' CachedEnemies list is not reused: it is built around the PLAYER, and
-- the whole point of a tower is to shoot things near the TOWER. So the sweep is
-- centred on the archer, with the same per-entity test.
function mercenaries:FindStaticArcherDefendTarget(data, myWuid, me, mp)
    local playerWuid = player and player.this and player.this.id
    local savedRadius = self.TargetDetectionRadius
    self.TargetDetectionRadius = self.StaticArcherRange

    local best, bestD2 = nil, nil
    local ok = pcall(function()
        -- 1. The player's current combat target, if it is a fair target at all
        -- (skipRelationshipCheck, exactly as the mercs do - if the player picked
        -- the fight, the tower backs him up).
        if data.playerCombatTarget then
            local t = XGenAIModule.GetEntityByWUID(data.playerCombatTarget)
            if t and t.soul and self:IsValidEnemy(t, me, playerWuid, true) then
                best = data.playerCombatTarget
                return
            end
        end

        -- 2. Otherwise the nearest genuine enemy within the tower's reach. A target
        -- counts if EITHER:
        --   * it is one of the mod's own spawned enemies (renegades etc., by name -
        --     ModEnemyPrefixes). These are unconditionally valid: they exist only
        --     to be fought, so they must be shot even before they have closed in
        --     and drawn a weapon. IsValidEnemy would skip an approaching renegade
        --     (it demands weapon-drawn AND relationship exactly -1 to the player),
        --     which is what made the tower fire unreliably; OR
        --   * it passes the squad's own IsValidEnemy (covers world hostiles the
        --     mercs would also fight).
        local myWuidStr = tostring(myWuid)
        -- Shared scan first. It runs at StaticArcherRange for as long as any static archer
        -- exists (PerfScanNpcs recomputes that per pass - it used to latch wide forever
        -- after the first archer, which cost a 90m NPC sweep in every crowd thereafter). A
        -- remote tower outside the shared scan's coverage gets nil and falls back below -
        -- expected, not a bug.
        local shared = self:PerfNpcsNear(mp, self.StaticArcherRange, 1200)
        if shared then
            for _, e in ipairs(shared) do
                local ent = e.entity
                if ent and ent.soul and e.wuid and tostring(e.wuid) ~= myWuidStr and self:IsCombatViable(ent) then
                    local isModEnemy = self:IsModEnemyName(ent:GetName() or "")
                    if isModEnemy or self:IsValidEnemy(ent, me, playerWuid, false) then
                        local ep = e.pos
                        local dx, dy, dz = ep.x - mp.x, ep.y - mp.y, ep.z - mp.z
                        local d2 = dx * dx + dy * dy + dz * dz
                        if not bestD2 or d2 < bestD2 then best, bestD2 = e.wuid, d2 end
                    end
                end
            end
        else
            local ents = System.GetPhysicalEntitiesInBoxByClass(mp, self.StaticArcherRange, "NPC")
            if not ents then return end
            for _, ent in pairs(ents) do
                if ent and type(ent) == "table" and ent.soul and ent.this and ent.this.id
                   and tostring(ent.this.id) ~= myWuidStr and self:IsCombatViable(ent) then
                    local isModEnemy = self:IsModEnemyName(ent:GetName() or "")
                    if isModEnemy or self:IsValidEnemy(ent, me, playerWuid, false) then
                        local ep = ent:GetPos()
                        if ep then
                            local dx, dy, dz = ep.x - mp.x, ep.y - mp.y, ep.z - mp.z
                            local d2 = dx * dx + dy * dy + dz * dz
                            if not bestD2 or d2 < bestD2 then best, bestD2 = ent.this.id, d2 end
                        end
                    end
                end
            end
        end
    end)

    self.TargetDetectionRadius = savedRadius
    if not ok then return nil end
    return best
end

-- Called every ~1s from static_archer_scheduler.xml. Sets data.currentTarget.
-- Same shape as FindRenegadeTarget: keep a live, close target rather than
-- re-scanning every tick.
function mercenaries:FindStaticArcherTarget(data, myWuid)
    local ok, err = pcall(function()
        local myWuidStr = tostring(myWuid)
        local rec = self.StaticArchers[myWuidStr]
        if not rec then return end        -- not registered (e.g. after a reload)

        -- Don't start combat while he's still being dropped onto his spot: the
        -- placement SetPos teleports him every 400ms, which resets his AI and
        -- yanks any combat mid-shot - that was the "enters and exits combat for a
        -- few seconds" on a fresh tower archer. Hold fire until he's landed.
        if self.StaticArcherPending[myWuidStr] then
            data.currentTarget = nil
            return
        end

        -- A watchtower over a camp that has not noticed anything holds its fire - but only
        -- until someone is inside HIS range, not the camp's. He is posted up there to see
        -- further than the men round the fire, so he is decoupled from their 10m rule and
        -- opens at BanditCampArcherAlertRange. Suppression still applies past that, so the
        -- camp is not shooting at the player from across the valley.
        if self.SiegePeace and self:SiegeSuppressed(myWuidStr) then
            data.currentTarget = nil
            self.StaticArcherTargetOf[myWuidStr] = nil
            return
        end

        if self.BanditCampSuppressed and self:BanditCampSuppressed(myWuidStr) then
            local inReach = false
            if player then
                pcall(function()
                    local me2 = XGenAIModule.GetEntityByWUID(myWuid)
                    local ap, pp = me2 and me2:GetPos(), player:GetWorldPos()
                    if ap and pp then
                        local dx, dy, dz = pp.x - ap.x, pp.y - ap.y, pp.z - ap.z
                        local r = self.BanditCampArcherAlertRange
                        inReach = (dx * dx + dy * dy + dz * dz) <= (r * r)
                    end
                end)
            end
            if not inReach then
                data.currentTarget = nil
                self.StaticArcherTargetOf[myWuidStr] = nil
                return
            end
        end

        local mode = rec.mode or self.StaticArcherDefaultMode

        local me = XGenAIModule.GetEntityByWUID(myWuid)
        if not me then return end
        local mp = me:GetPos()
        if not mp then return end

        -- Keep the current target while it is alive and in range.
        if data.currentTarget then
            local cur = XGenAIModule.GetEntityByWUID(data.currentTarget)
            if cur and self:IsCombatViable(cur) then
                local cp = cur:GetPos()
                if cp then
                    local dx, dy, dz = cp.x - mp.x, cp.y - mp.y, cp.z - mp.z
                    if (dx * dx + dy * dy + dz * dz) <= (self.StaticArcherStickRange * self.StaticArcherStickRange) then
                        return
                    end
                end
            end
        end

        local best
        if mode == "defend" then
            best = self:FindStaticArcherDefendTarget(data, myWuid, me, mp)
        else
            -- "hostile" / "mod_enemies": these deliberately ignore the squad's
            -- notion of an enemy (they shoot the player, or only our own spawns),
            -- so they use the explicit per-mode test and a plain nearest-first sweep.
            local radius = self.StaticArcherRange
            local r2 = radius * radius
            local bestD2 = nil

            local function consider(wuid, p)
                local dx, dy, dz = p.x - mp.x, p.y - mp.y, p.z - mp.z
                local d2 = dx * dx + dy * dy + dz * dz
                if d2 <= r2 and (not bestD2 or d2 < bestD2) then best, bestD2 = wuid, d2 end
            end

            if player and self:StaticArcherWantsTarget(mode, player, true) then
                local pp = player:GetPos()
                if pp and self:IsCombatViable(player) then consider(player.this.id, pp) end
            end

            local ents = System.GetPhysicalEntitiesInBoxByClass(mp, radius, "NPC")
            if ents then
                for _, ent in pairs(ents) do
                    if ent and type(ent) == "table" and ent.soul and ent.this and ent.this.id then
                        if tostring(ent.this.id) ~= myWuidStr and self:IsCombatViable(ent)
                           and self:StaticArcherWantsTarget(mode, ent, false) then
                            local ep = ent:GetPos()
                            if ep then consider(ent.this.id, ep) end
                        end
                    end
                end
            end
        end

        data.currentTarget = best
        self.StaticArcherTargetOf[myWuidStr] = best and tostring(best) or nil
    end)
    if not ok then System.LogAlways("[StaticArcher] FindStaticArcherTarget error: " .. tostring(err)) end
end

-- Called from combat_archer_static.xml: is the target still worth shooting, and
-- do we still have ammo? (No distance/leash checks - a tower archer never moves.)
function mercenaries:UpdateStaticArcherCombatData(data, myWuid)
    local ok, err = pcall(function()
        data.isTargetAlive = false
        data.distanceToTarget = 9999.0

        local me = XGenAIModule.GetEntityByWUID(myWuid)
        local myPos = me and me:GetPos()

        if data.attackData and data.attackData.target then
            local t = XGenAIModule.GetEntityByWUID(data.attackData.target)
            if t and self:IsCombatViable(t) then
                data.isTargetAlive = true
                local tp = t:GetPos()
                if tp and myPos then
                    local dx, dy, dz = tp.x - myPos.x, tp.y - myPos.y, tp.z - myPos.z
                    data.distanceToTarget = math.sqrt(dx * dx + dy * dy + dz * dz)
                end
            end
        end

        data.outOfAmmo = false
        local weaponType = self:GetArcherWeaponType()
        if me and me.inventory and me.inventory.GetCountOfClass then
            local ammoClasses = self.ArcherArrowClasses
            if weaponType == "crossbow" then ammoClasses = self.ArcherBoltClasses
            elseif weaponType == "handcannon" then ammoClasses = self.ArcherShotClasses end
            local total = 0
            for _, c in ipairs(ammoClasses) do
                local ok2, n = pcall(function() return me.inventory:GetCountOfClass(c) end)
                if ok2 and n then total = total + n end
            end
            data.outOfAmmo = (total == 0)
        end
    end)
    if not ok then System.LogAlways("[StaticArcher] UpdateStaticArcherCombatData error: " .. tostring(err)) end
end

-- Keep their quivers full - they never walk to a resupply. Called from
-- LowPriorityMonitorLoop alongside the mercs' own resupply.
function mercenaries:ResupplyStaticArchers()
    local ok, err = pcall(function()
        local weaponType = self:GetArcherWeaponType()
        local ammoClass = self.ArcherAmmoClass[weaponType] or self.ArcherAmmoClass["bow"]
        for _, rec in pairs(self.StaticArchers) do
            local ent = rec.ent
            if ent and ent.inventory then
                local have = 0
                pcall(function() have = ent.inventory:GetCountOfClass(ammoClass) or 0 end)
                if have < 10 then self:GiveArcherAmmo(ent, weaponType, 40) end
            end
        end
    end)
    if not ok then System.LogAlways("[StaticArcher] ResupplyStaticArchers error: " .. tostring(err)) end
end

-- Console: a plain ground-standing static archer, 3m in front of you and snapped
-- to the terrain, facing you. Mode defaults to defend. Use this to test the archer
-- itself (targeting/shooting) away from the tower's placement complications.
function mercenaries:SpawnStaticArcherHere(mode)
    if not player then return end
    local o = player:GetWorldPos()
    local ang; pcall(function() ang = player:GetWorldAngles() end)
    local yaw = (ang and ang.z) or 0
    local pos = { x = o.x + math.cos(yaw) * 3.0, y = o.y + math.sin(yaw) * 3.0, z = o.z }
    if self.CampSnapToGround then pos = self:CampSnapToGround(pos) end
    self:SpawnStaticArcher(pos, self:ResolveStaticArcherMode(mode), yaw + math.pi)
end

System.AddCCommand("merc_static_archer",       "mercenaries:SpawnStaticArcherHere(%1)", "Spawn a static archer 3m ahead on the ground: merc_static_archer [mode]  (mode: 1=defend 2=hostile 3=mod_enemies, default 1)")
System.AddCCommand("merc_static_archer_clear", "mercenaries:ClearStaticArchers()",      "Remove all static archers")
System.AddCCommand("merc_static_archer_mode",  "mercenaries:SetStaticArcherMode(%1)",   "Set the mode of every static archer: 1=defend 2=hostile 3=mod_enemies")
System.AddCCommand("merc_static_archer_scale", "mercenaries:SetStaticArcherScale(%1)",  "Resize every static archer (1.0 = normal): merc_static_archer_scale <scale>")
