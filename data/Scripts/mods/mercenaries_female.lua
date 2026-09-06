-- FEMALE MERCENARIES - a category of their own, like the archers.
--
-- Named "SpawnedFriend_female_medium_..." so they ride every squad system for free, with
-- '_female_' branching the four things that differ. That is the archers' pattern exactly
-- (SpawnedFriend_archer_medium_...), and for the same reason: the mod reads a merc's tier out
-- of his entity name with a plain string.find for '_medium_', in mercenaries_equipment.lua
-- twice and in custom_gear and util once each, so keeping the tier in the name means camp
-- housing, upkeep, difficulty scaling, formations, the roster and everything else resolve
-- them without knowing this file exists.
--
-- What is different, and nothing else is:
--
--   1. THEIR OWN WARDROBE, and they ignore the squad's outfit style. The presets are the
--      medium kit with the headgear taken out (tools/gen_female_gear.py) - a helmet hides the
--      face and hair that are the entire point of them. They are exempt from ChangeMercOutfit
--      the same way custom companions are, via the IsFemaleName branch at the top of
--      EquipMercenary. That is not a preference, it is the only thing that works: the first
--      version dressed them normally and then unequipped the head slots, and the helmets
--      stayed on through four passes over 2.8 s with no refusal in the log. A preset that
--      never contained a helmet cannot leave one on.
--
--   2. NO AUDIBLE DIALOGUE - and only that. They get the brain, the roles, the order wheel,
--      the E-dialog and every camp behaviour a regular merc has; InjectInteraction runs on
--      them exactly as it does on the men. What is off is the SOUND: RequestBark returns
--      early for them (mercenaries.lua) and the camp-chat pairing skips them
--      (mercenaries_camp.lua), because every bark and gossip line the company owns was
--      recorded by a man and playing one out of a woman is worse than silence.
--
--      This is the custom companions' arrangement exactly - see IsHeroName and
--      docs/companions.md, "Never talks is the whole rule" - and it is deliberately the same
--      two choke points, not a new mechanism. An earlier build skipped InjectInteraction
--      outright, which took the order wheel away with the voice; that was wrong.
--
--   3. ONE TIER. Like the archers: one pool, one price, medium gear.
--
--   4. FEMALE HEADS, HAIR AND VOICES, which is soul and appearance data rather than code -
--      soul__mercenaries.xml, mercenariesappearance.xml, skald_character__mercenaries.xml and
--      CharacterComponent__mercenaries.xml. See docs/female-mercenaries.md.
--
-- The souls stay soul_archetype_id="0" (male). Archetype 1 is NPC_Female, which would hand the
-- NPC the female skeleton, the female clothing config and the female animation set - and that
-- set has no combat in it at all. These are male-bodied soldiers with female heads because
-- that is the only shape the game supports; the doc has the measurements.

local fLog = function(s) System.LogAlways("[Female] " .. tostring(s)) end

-- Token (skald dialog -> lua). Count on the hire token = how many to hire.
mercenaries.TokenIDFemale = "679a655e-189d-4519-b437-ccc4b92be02d"

-- One pool, no tiers - but they still spawn under the melee mercs' "medium" tier name so the
-- tier-keyed squad systems resolve them. Same trick, same reason, as ArcherTier.
mercenaries.FemaleTier  = "medium"
mercenaries.FemalePrice = 100          -- what a medium man costs (mercenaries.lua, MonitorTokens)

-- Ten faces, soul__mercenaries.xml. Not in mercenaries.Souls: that table is keyed by strength
-- tier and these are not a strength tier.
mercenaries.FemaleSouls = {
    "7f1c9a24-3b6e-4d51-9a08-2c5e71bd0401",
    "7f1c9a24-3b6e-4d51-9a08-2c5e71bd0402",
    "7f1c9a24-3b6e-4d51-9a08-2c5e71bd0403",
    "7f1c9a24-3b6e-4d51-9a08-2c5e71bd0404",
    "7f1c9a24-3b6e-4d51-9a08-2c5e71bd0405",
    "7f1c9a24-3b6e-4d51-9a08-2c5e71bd0406",
    "7f1c9a24-3b6e-4d51-9a08-2c5e71bd0407",
    "7f1c9a24-3b6e-4d51-9a08-2c5e71bd0408",
    "7f1c9a24-3b6e-4d51-9a08-2c5e71bd0409",
    "7f1c9a24-3b6e-4d51-9a08-2c5e71bd040a"
}
mercenaries.FemaleSoulIndex = 1

-- THE COMBAT VOICE. Nothing is shipped for it - no dialog, no .ogg, no localisation.
--
-- Two halves, both of them vanilla recordings cast on the merc's own voice:
--
--   1. THE SHOUT when she picks a target. combat_melee.xml casts metarole
--      NPC_VIDI_NEPRITELE_A_BUDE_UTOCIT with an empty alias, the same free-vanilla-voice
--      trick foe_combat.xml uses. UpdateMeleeCombatData sets data.femaleShout, women only:
--      the male merc voices carry no recording for that metarole, and a voice with no
--      recording does not go quiet - voice.xml's fallback chain would hand a man somebody
--      else's voice. Rate-limited below, because combat_melee is re-fired often.
--
--   2. THE HIT, DEATH AND WOUNDED lines, which are ROLES rather than a node - see
--      libs/Storm/roles/mercenariesroles.xml, rule mercenary_female_combat_voice. These souls
--      read as <isMan /> to the engine, so vanilla hands them the _MUZ combat roles while
--      their voices only ever recorded the _ZENA ones; the rule swaps the six gendered roles.
--
-- All ten voices assigned in skald_character__mercenaries.xml were checked to carry the full
-- set (8 hit / 3 death / 3 wounded / 4 kill). Two earlier picks - aric and sphe - carried
-- none at all and were swapped out for kgri and amil.
mercenaries.FemaleShoutCooldown = 25   -- seconds between one woman's combat shouts
mercenaries.FemaleShoutAt = {}         -- [wuidStr] = last shout time

-- GENERATED by tools/gen_female_gear.py - the medium wardrobe minus the headgear.
-- Style "0f" is not a real style: nothing in mercenaries.Outfits can reach these, which is
-- exactly what keeps the squad's outfit switch off them.
mercenaries.FemalePresets = {
    "6d657263-0f01-4b00-9000-000000000001", "6d657263-0f01-4b00-9000-000000000002",
    "6d657263-0f01-4b00-9000-000000000003", "6d657263-0f01-4b00-9000-000000000004",
    "6d657263-0f01-4b00-9000-000000000005", "6d657263-0f01-4b00-9000-000000000006",
    "6d657263-0f01-4b00-9000-000000000007", "6d657263-0f01-4b00-9000-000000000008",
    "6d657263-0f01-4b00-9000-000000000009", "6d657263-0f01-4b00-9000-00000000000a"
}

function mercenaries:IsFemaleName(name)
    return name ~= nil and string.find(name, '_female_', 1, true) ~= nil
end

-- Their own wardrobe, and the squad's outfit index is deliberately ignored. Weapons are NOT:
-- EquipMercenaryWeapon reads the tier out of the name, finds '_medium_' and arms them exactly
-- like a seasoned man, which is what "equivalent to medium" should mean for a sword.
function mercenaries:EquipFemale(ent, weaponPreset)
    if not ent or not ent.actor then return end
    local pool = self.FemalePresets
    if not pool or #pool == 0 then
        fLog("no female presets - falling back to the squad wardrobe")
        return
    end
    local id = pool[math.random(1, #pool)]
    pcall(function() ent.actor:EquipClothingPreset(id) end)
    pcall(function()
        self:EquipMercenaryWeapon(ent, weaponPreset or _G.MercCurrentWeapon or 1, 1)
    end)
end

-- Everything after the spawn, shared by the hire and the roster rebuild so the two cannot
-- drift. This is the regular merc's post-spawn list in full, InjectInteraction included: they
-- are ordinary mercenaries in every respect except the sound of their voice, and the mute
-- lives in RequestBark rather than here.
function mercenaries:FemaleFinishSpawn(ent, name, weaponPreset)
    self.ActiveMercs[name] = ent
    local ok, err = pcall(function()
        self:EnsureMercIsAlwaysRendered(ent)
        self:EquipFemale(ent, weaponPreset)
        self:InjectInteraction(ent)
        if self.MQWOnHire then self:MQWOnHire(ent) end
        self:CampOnMercJoined(ent)
    end)
    if not ok then fLog("post-spawn setup failed for " .. tostring(name) .. ": " .. tostring(err)) end
end

function mercenaries:FemaleEntityName(soulGuid)
    return "SpawnedFriend_female_" .. self.FemaleTier .. "_" ..
           tostring(math.random(10000, 99999)) .. "_" .. soulGuid
end

function mercenaries:FemaleNextSoul()
    local list = self.FemaleSouls
    local guid = list[self.FemaleSoulIndex]
    self.FemaleSoulIndex = self.FemaleSoulIndex + 1
    if self.FemaleSoulIndex > #list then self.FemaleSoulIndex = 1 end
    return guid
end

function mercenaries:HireFemale(cost, amount)
    local p = player.inventory

    self:Recount()
    if not _G.MercCount then _G.MercCount = 0 end

    if _G.MercCount + amount > self.MaxCompanions then
        fLog(string.format('HireFemale: rejected - too many (count=%d + %d > max=%d)',
                           _G.MercCount, amount, self.MaxCompanions))
        Game.SendInfoText('merc_info_too_many', false, 0, 3)
        return
    end

    if p:GetMoney() < cost then
        fLog(string.format('HireFemale: rejected - not enough money (have %d, need %d)',
                           p:GetMoney(), cost))
        Game.SendInfoText('merc_info_not_enough_money', false, 0, 3)
        return
    end

    p:RemoveMoney(cost)

    if _G.MercenariesDismissed ~= false then
        _G.MercenariesDismissed = false
        self:SaveString("MercenariesDismissed", "0")
    end
    if _G.MercIdle ~= false then
        _G.MercIdle = false
        _G.MercPersistentIdleFlag = false
        self:SaveString("MercIdlePersistent", "0")
    end

    _G.MercCount = _G.MercCount + amount

    local outside = nil
    local spawned = 0

    -- Same indoor rule as Hire and HireArcher: hired at an innkeeper's they muster outside,
    -- and only the ones that actually appeared are paid for.
    local ok, err = pcall(function()
        local a = self:HireSpawnAnchor()
        if not (a and a.pos and a.rot) then
            fLog('HireFemale: no usable spawn position - nobody placed')
            return
        end
        local spawnPos, playerRot = a.pos, a.rot
        outside = a.outside
        local weaponPreset = _G.MercCurrentWeapon or 1

        for _ = 1, amount do
            local soulGuid = self:FemaleNextSoul()
            local raw = {
                x = spawnPos.x + (math.random() - 0.5) * 1.5,
                y = spawnPos.y + (math.random() - 0.5) * 1.5,
                z = spawnPos.z
            }
            local offsetPos = a.snap and self:FindValidGround(raw, spawnPos.z) or raw
            local safeRot = { x = 0, y = 0, z = playerRot.z }
            local entityName = self:FemaleEntityName(soulGuid)

            System.SpawnEntity({
                class = "NPC",
                name = entityName,
                position = offsetPos,
                orientation = safeRot,
                properties = mercenaries:RosterSpawnProps(soulGuid)
            })

            local ent = System.GetEntityByName(entityName)
            if ent then
                spawned = spawned + 1
                self:FemaleFinishSpawn(ent, entityName, weaponPreset)
            else
                fLog('HireFemale: SpawnEntity produced nothing for ' .. entityName)
            end
        end
    end)

    if not ok then fLog('HireFemale error: ' .. tostring(err)) end

    if spawned < amount then
        self:Recount()
        local refund = math.floor((cost or 0) * (amount - spawned) / math.max(amount, 1))
        if refund > 0 then self:GiveMoney(refund) end
    end

    if spawned <= 0 then
        Game.SendInfoText('merc_info_hire_failed', false, 0, 4)
        return
    end

    Game.SendInfoText(spawned == 1 and 'merc_info_female_hired_single'
                                    or 'merc_info_female_hired_multiple', false, 0, 3)
    if outside then Game.SendInfoText('merc_info_hired_outside', false, 0, 5) end

    pcall(function() mercenaries:BeginFollowVerify("hire") end)
end

-- One woman, at an exact spot. The counterpart of SpawnMercAt / SpawnArcherAt: used by the
-- roster rebuild when RosterRespawnNamed cannot recover the soul from the stored name.
function mercenaries:SpawnFemaleAt(pos, yaw, weaponPreset)
    if not pos then return nil end
    local soulGuid = self:FemaleNextSoul()
    local name = self:FemaleEntityName(soulGuid)
    local ent
    local ok, err = pcall(function()
        System.SpawnEntity({
            class = "NPC", name = name, position = pos,
            orientation = { x = 0, y = 0, z = yaw or 0 },
            properties = mercenaries:RosterSpawnProps(soulGuid),
        })
        ent = System.GetEntityByName(name)
        if not ent then return end
        self:FemaleFinishSpawn(ent, name, weaponPreset)
    end)
    if not ok then fLog("SpawnFemaleAt failed for " .. name .. ": " .. tostring(err)) end
    return ent
end

-- Skald -> Lua. Called from MonitorTokens alongside the archers'.
function mercenaries:MonitorFemaleTokens(p)
    local n = p:GetCountOfClass(self.TokenIDFemale)
    if n and n > 0 then
        p:DeleteItemOfClass(self.TokenIDFemale, n)
        self:HireFemale(self.FemalePrice * n, n)
    end
end

-- Console. Its own command rather than an argument on merc_hire, because they are their own
-- category with one tier - exactly like merc_hire_archers.
function mercenaries:CmdHireFemale(line)
    local n = tonumber(self:CmdArgs(line)[1]) or 5
    if n < 1 then n = 1 end
    self:HireFemale(0, n)
end
