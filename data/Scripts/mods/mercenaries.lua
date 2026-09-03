-- Main mod file. Handles: (1) communication with Skald via token items (a token
-- appearing in the player's inventory triggers the matching action - spawn, heal,
-- etc.); (2) the main loop and its scans; (3) console cheats, loading the other
-- scripts, and configuration.

mercenaries = {}

-- Console commands: every command a PLAYER can type is registered in
-- mercenaries_commands.lua. Modules collect their authoring and diagnostic commands
-- here instead, and merc_dev registers those on demand. Defined this early because
-- modules - and this file, further down - call it while loading. See docs/console.md.
mercenaries.DevCommands = {}
mercenaries.DevCommandsOn = false

function mercenaries:DevCommand(name, body, desc)
    table.insert(self.DevCommands, { name = name, body = body, desc = desc or "" })
end


-- Hire Tokens
mercenaries.TokenIDWeak = "679a655e-189d-4519-b437-ccc4b92be41d"
mercenaries.TokenIDMedium = "679a655e-189d-4519-b437-ccc4b92be42d"
mercenaries.TokenIDStrong = "679a655e-189d-4519-b437-ccc4b92be43d"

-- State Tokens
mercenaries.TokenIDDismiss = "679a655e-189d-4519-b437-ccc4b92be44d"
mercenaries.TokenIDWait = "679a655e-189d-4519-b437-ccc4b92be45d"
mercenaries.TokenIDFollow = "679a655e-189d-4519-b437-ccc4b92be46d"

-- Outfit Token
mercenaries.TokenIDChangeOutfit = "679a655e-189d-4519-b437-ccc4b92be47d"

-- Custom uniform: the gear-delivery panel result, and "the option was picked"
-- (mercenaries_custom_gear.lua, which declares both and owns the handlers)

-- Weapon loadout token (count = loadout index, see mercenaries.WeaponSets)
mercenaries.TokenIDChangeWeapon = "679a655e-189d-4519-b437-ccc4b92be55d"

-- Renegade spawn tokens (one per tier, count = how many to spawn)
mercenaries.TokenIDSpawnRenegadeWeak = "679a655e-189d-4519-b437-ccc4b92be56d"
mercenaries.TokenIDSpawnRenegadeMedium = "679a655e-189d-4519-b437-ccc4b92be57d"
mercenaries.TokenIDSpawnRenegadeStrong = "679a655e-189d-4519-b437-ccc4b92be58d"

--Custom Companion Token
mercenaries.TokenIDCustomComp = "679a655e-189d-4519-b437-ccc4b92be48d"

--retrieve mercs token
mercenaries.TokenIDReturn = "679a655e-189d-4519-b437-ccc4b92be49d"
--heal mercs token
mercenaries.TokenIDHeal = "679a655e-189d-4519-b437-ccc4b92be50d"
--squad status report token
mercenaries.TokenIDStatus = "679a655e-189d-4519-b437-ccc4b92be64d"

--camp tokens
mercenaries.TokenIDCampMake = "679a655e-189d-4519-b437-ccc4b92be65d"
mercenaries.TokenIDCampBreak = "679a655e-189d-4519-b437-ccc4b92be66d"

--quartermaster placeholder test dialog token
mercenaries.TokenIDQuartermasterTest = "679a655e-189d-4519-b437-ccc4b92be67d"

--quartermaster logistics dialog tokens
mercenaries.TokenIDQMDeliverFood     = "679a655e-189d-4519-b437-ccc4b92be68d"
mercenaries.TokenIDQMDeliverDrink    = "679a655e-189d-4519-b437-ccc4b92be69d"
mercenaries.TokenIDQMBuyFood         = "679a655e-189d-4519-b437-ccc4b92be6ad"
mercenaries.TokenIDQMAskStats        = "679a655e-189d-4519-b437-ccc4b92be6bd"
mercenaries.TokenIDQMDeposit         = "679a655e-189d-4519-b437-ccc4b92be6cd"
mercenaries.TokenIDQMWithholdWages   = "679a655e-189d-4519-b437-ccc4b92be6dd"
mercenaries.TokenIDQMWithdraw        = "679a655e-189d-4519-b437-ccc4b92be6ed"
mercenaries.TokenIDQMAskFood         = "679a655e-189d-4519-b437-ccc4b92be6fd"
mercenaries.TokenIDQMAskDrink        = "679a655e-189d-4519-b437-ccc4b92be76d"
mercenaries.TokenIDQMFoodPanel       = "679a655e-189d-4519-b437-ccc4b92be77d"
mercenaries.TokenIDQMDrinkPanel      = "679a655e-189d-4519-b437-ccc4b92be78d"
mercenaries.TokenIDQMCart            = "679a655e-189d-4519-b437-ccc4b92be70d"
mercenaries.TokenIDQMInn             = "679a655e-189d-4519-b437-ccc4b92be71d"
mercenaries.TokenIDQMHunter          = "679a655e-189d-4519-b437-ccc4b92be72d"
mercenaries.TokenIDQMSmithy          = "679a655e-189d-4519-b437-ccc4b92be73d"
mercenaries.TokenIDQMAlchemy         = "679a655e-189d-4519-b437-ccc4b92be74d"
mercenaries.TokenIDQMPractice        = "679a655e-189d-4519-b437-ccc4b92be75d"
mercenaries.TokenIDQMHouse           = "679a655e-189d-4519-b437-ccc4b92be7cd"
mercenaries.TokenIDQMTower           = "679a655e-189d-4519-b437-ccc4b92be7dd"
mercenaries.TokenIDQMArcherCart      = "679a655e-189d-4519-b437-ccc4b92be7ed"
mercenaries.TokenIDQMRemoveUpg       = "679a655e-189d-4519-b437-ccc4b92be7fd"
mercenaries.TokenIDQMWall            = "679a655e-189d-4519-b437-ccc4b92be80d"
mercenaries.TokenIDQMGate            = "679a655e-189d-4519-b437-ccc4b92bec0d"
mercenaries.TokenIDQMGates           = "679a655e-189d-4519-b437-ccc4b92bec1d"
-- Two menus that would otherwise need a GUID per option use the COUNT as the selector
-- instead: every option grants the same item, with a different Amount (the trick
-- ChangeMercOutfit/ChangeMercWeapon already use). One token, one item row, one handler.
mercenaries.TokenIDQMRemoveOne       = "679a655e-189d-4519-b437-ccc4b92bef1d"
mercenaries.TokenIDQMComposition     = "679a655e-189d-4519-b437-ccc4b92bef2d"

--quartermaster deploy (take-N mercs out of camp) tokens
mercenaries.TokenIDQMTakeAll         = "679a655e-189d-4519-b437-ccc4b92bee3d"
mercenaries.TokenIDQMTakeThreeQtr    = "679a655e-189d-4519-b437-ccc4b92bee2d"
mercenaries.TokenIDQMTakeHalf        = "679a655e-189d-4519-b437-ccc4b92be79d"
mercenaries.TokenIDQMTakeThird       = "679a655e-189d-4519-b437-ccc4b92be7ad"
mercenaries.TokenIDQMTakeQuarter     = "679a655e-189d-4519-b437-ccc4b92be7bd"

-- Hard squad cap. The formation presets are generated up to this size, so raising
-- it means regenerating data/AI/FormationDefinitions.xml with a matching ladder.
mercenaries.MaxCompanions = 50

-- Flat fee to heal & wash the whole squad in one go, regardless of size.
mercenaries.HealCost = 20

mercenaries.TargetDetectionRadius = 50

-- Half-extent of the box query UpdateEnemyCache runs around the player. This is
-- the effective aggro radius - TargetDetectionRadius above is only a far gate.
--
-- The old warning here ("keep it under the 20m disengage leash or a merc charging an
-- edge-of-range enemy trips the leash and gets pulled back") no longer applies: the melee
-- leash is measured against the merc's own TARGET and scales with squad size, so closing a
-- long distance is allowed. See MeleeTargetLeash in mercenaries_ai_modules.lua.
mercenaries.EnemyScanRadius = 18

-- ...and once a fight is actually on, the squad looks much further. Mercs could only see
-- hostiles within EnemyScanRadius of the PLAYER, so a patrol column 40m up the road simply
-- did not exist to them: nobody moved until it closed to 18m, which reads as the squad
-- taking ages to react. This is the squad's version of the patrols' gang-wide alert - one
-- contact and everyone widens their eyes - and it decays after the fight so a peaceful
-- squad is not running a 60m query forever.
mercenaries.EnemyAlertRadius   = 60
mercenaries.EnemyAlertHoldSecs = 20.0
mercenaries.EnemyAlerted       = false
-- The shipped value, kept separately because the siege OVERWRITES EnemyAlertRadius with its
-- own (160m) and only puts it back on the path where the siege is struck. Anything that has
-- to restore the field - TargetingOnLoad - restores it from here, not from whatever the
-- field happens to hold. See docs/performance.md.
mercenaries.EnemyAlertRadiusDefault = 60

-- Max number of mercs allowed to already be closer to a given enemy before
-- another merc will look for a different target instead of piling on.
--
-- This is the FLOOR, not the value actually used. With a hard cap of 2, any merc past
-- the (2 x enemies) mark found every candidate full and stood there through the whole
-- fight - the "one who never joins in". EffectiveSwarmCap (recomputed each
-- UpdateEnemyCache pass) opens the cap up to SwarmCapMax when the squad outnumbers the
-- enemy, so everyone has somewhere to go, and stays at SwarmCap when there is plenty to
-- fight. PickCombatTarget then has an at-cap fallback behind that, bounded by
-- SwarmCapHard and SwarmOverflowRange - see docs/combat-target-selection.md.
mercenaries.SwarmCap = 2
-- Ceiling when the squad only modestly outnumbers the enemy...
mercenaries.SwarmCapMax = 4
-- ...and the hard stop when it massively does. A 50-man squad against three bandits will
-- commit up to this many per enemy; the rest hold formation. Without a rising ceiling a big
-- squad simply refused most of its own mercs a target and they stood at the back.
mercenaries.SwarmCapHard = 10
mercenaries.EffectiveSwarmCap = 2

mercenaries.IsHiddenForCutscene = false

-- Centralized caches, rebuilt/pruned once per second instead of scanning all
-- world entities on every hot-path call.
mercenaries.ActiveMercs   = {}  -- [entityName] = entity ref; pruned each tick
mercenaries.CachedEnemies = {}  -- [{entity, wuid}] valid hostile enemies near player
-- Armed candidates the cache gates refused. Offered to the behaviour tree by
-- ScanForEnemies so its GetTarget node can find the ones actually fighting us - the only
-- working way to ask. See NoteAttacker in mercenaries_target_selection.lua.
mercenaries.MaybeEnemies  = {}
mercenaries.FormationSlots = {} -- [tostring(wuid)] = {slot, followTarget, totalMercs}

-- Anti-swarm bookkeeping. MercTargetOf tracks each merc's current combat target and
-- TargetLoad counts the claims on each enemy, so "is this target already swarmed" is a
-- plain table lookup. Write them ONLY through MercSetClaim / MercDropClaim, which keep
-- the two in step: a load map that is merely rebuilt each pass is a pass out of date,
-- and every merc evaluating inside that window then judges the cap against the same
-- stale snapshot. See docs/combat-target-selection.md.
mercenaries.MercTargetOf = {} -- [myWuidStr] = targetWuidStr
mercenaries.TargetLoad = {}   -- [targetWuidStr] = number of mercs currently on it

_G.MercHorseState = {}
_G.PlayerMounted = false
-- Soul dictionaries for different faces (only includes the generic mercs)
mercenaries.Souls = {
    weak = {
        "a1b2c3d4-1234-4abc-8def-123456789012",
        "b2c3d4e5-2345-4bcd-9ef0-234567890123",
        "c3d4e5f6-3456-4cde-a012-345678901234",
        "d4e5f6a7-4567-4def-b123-456789012345",
        "e5f6a7b8-5678-4efa-c234-567890123456",
        "4c8d59ed-f203-4e49-9217-104440b45a51",
        "d619884a-8969-429a-b47b-2fe407dacd7d",
        "f0c56057-0fc9-49a6-94f1-a48b4e966185",
        "9bdecddd-5ed4-4e0a-b092-7a7c71b4f037",
        "61ae064f-997d-490a-a391-c67150afaf24"
    },
    medium = {
        "f6a7b8c9-6789-4fab-d345-678901234567",
        "a7b8c9d0-7890-4abc-e456-789012345678",
        "b8c9d0e1-8901-4bcd-f567-890123456789",
        "c9d0e1f2-9012-4cde-a678-901234567890",
        "d0e1f2a3-0123-4def-b789-012345678901",
        "cf3146a1-0690-4c47-b778-7d099794490c",
        "e1a181c8-82b7-471c-b7fa-a87f33c92ae2",
        "9dd1c7c7-21a0-43fa-ac10-49dfb24842c3",
        "38a95e49-dc1e-4e76-87b7-7e40c7e1e546",
        "9ee391c6-9a08-463e-9e7e-b73383f05b19"
    },
    strong = {
        "e1f2a3b4-1234-4efa-c890-123456789012",
        "f2a3b4c5-2345-4fab-d901-234567890123",
        "a3b4c5d6-3456-4abc-e012-345678901234",
        "b4c5d6e7-4567-4bcd-f123-456789012345",
        "c5d6e7f8-5678-4cde-a234-567890123456",
        "5a51c02e-1b4d-4627-9d14-2c12a2951b4a",
        "e99dd9dc-b2c4-43b8-951d-ee7bb62297a1",
        "725183ee-670a-4c45-837e-f487e864acc6",
        "3642ce84-c6d4-43a2-9ca2-1f0a911ebd9f",
        "3ac796a9-9aee-4155-843e-2f5b0fed4ee6",
        "908d1e8c-ea09-4c6e-8f08-8d56a87b7778",
        "f9948fb0-58ee-49bf-b24b-ebc652c3658a",
        "14bdb3fd-1965-4118-b725-a59ed3a248de",
        "01df2788-7c3a-41af-a125-54f2c506e64c",
        "bca70ad5-b4a1-434d-9064-553becb1a56d",
        "c2b686a6-40fc-4df4-af23-85c7779ef81b",
        "a69740bc-9ab7-4c8e-a862-58c0ce9b983c",
        "225f6d3c-2b36-435c-be2d-aba2e721a71b",
        "7420ece1-4bd5-41ca-b180-df017d21da3a",
        "66ba3d6d-84e3-4e4d-a6f3-4d9c286ed37c",
        "e22a11d1-4330-4df1-8965-03aea16fc773",
        "7b40916c-f3a2-4931-8875-a9844abb57b4",
        "a3e275ff-18b2-4662-9981-8938e95b8528",
        "4832970f-6894-4063-8ece-4a049539f4fd",
        "7c14e246-3adc-4c53-8fae-b3550dfb6a62",
        "c934ed82-d767-4525-aa59-7512a1c308f1",
        "9ffca017-d072-4286-a2fe-ef639ac874f5",
        "7c1af7f9-af2c-45da-b181-545441ae2012",
        "000af03d-249f-41ff-969a-d8941c792094",
        "4dbeadb9-3019-4ca8-a18a-2509a4bab08b"
    }
}

-- OUTFIT DICTIONARY
-- Ten presets per style per tier, every one solved to the same armour
-- budget for its tier (weak 600, medium 1300, strong 1850, sum of stab +
-- slash + smash across the whole outfit), so switching style never
-- changes how tough a merc is - only how he looks. See docs/outfits.md.
mercenaries.Outfits = {
    -- 1: Generic Mercs
    [1] = {
        weak = {
            "6d657263-0101-4b00-9000-000000000001", "6d657263-0101-4b00-9000-000000000002",
            "6d657263-0101-4b00-9000-000000000003", "6d657263-0101-4b00-9000-000000000004",
            "6d657263-0101-4b00-9000-000000000005", "6d657263-0101-4b00-9000-000000000006",
            "6d657263-0101-4b00-9000-000000000007", "6d657263-0101-4b00-9000-000000000008",
            "6d657263-0101-4b00-9000-000000000009", "6d657263-0101-4b00-9000-00000000000a"
        },
        medium = {
            "6d657263-0102-4b00-9000-000000000001", "6d657263-0102-4b00-9000-000000000002",
            "6d657263-0102-4b00-9000-000000000003", "6d657263-0102-4b00-9000-000000000004",
            "6d657263-0102-4b00-9000-000000000005", "6d657263-0102-4b00-9000-000000000006",
            "6d657263-0102-4b00-9000-000000000007", "6d657263-0102-4b00-9000-000000000008",
            "6d657263-0102-4b00-9000-000000000009", "6d657263-0102-4b00-9000-00000000000a"
        },
        strong = {
            "6d657263-0103-4b00-9000-000000000001", "6d657263-0103-4b00-9000-000000000002",
            "6d657263-0103-4b00-9000-000000000003", "6d657263-0103-4b00-9000-000000000004",
            "6d657263-0103-4b00-9000-000000000005", "6d657263-0103-4b00-9000-000000000006",
            "6d657263-0103-4b00-9000-000000000007", "6d657263-0103-4b00-9000-000000000008",
            "6d657263-0103-4b00-9000-000000000009", "6d657263-0103-4b00-9000-00000000000a"
        }
    },
    -- 2: Bandits
    [2] = {
        weak = {
            "6d657263-0201-4b00-9000-000000000001", "6d657263-0201-4b00-9000-000000000002",
            "6d657263-0201-4b00-9000-000000000003", "6d657263-0201-4b00-9000-000000000004",
            "6d657263-0201-4b00-9000-000000000005", "6d657263-0201-4b00-9000-000000000006",
            "6d657263-0201-4b00-9000-000000000007", "6d657263-0201-4b00-9000-000000000008",
            "6d657263-0201-4b00-9000-000000000009", "6d657263-0201-4b00-9000-00000000000a"
        },
        medium = {
            "6d657263-0202-4b00-9000-000000000001", "6d657263-0202-4b00-9000-000000000002",
            "6d657263-0202-4b00-9000-000000000003", "6d657263-0202-4b00-9000-000000000004",
            "6d657263-0202-4b00-9000-000000000005", "6d657263-0202-4b00-9000-000000000006",
            "6d657263-0202-4b00-9000-000000000007", "6d657263-0202-4b00-9000-000000000008",
            "6d657263-0202-4b00-9000-000000000009", "6d657263-0202-4b00-9000-00000000000a"
        },
        strong = {
            "6d657263-0203-4b00-9000-000000000001", "6d657263-0203-4b00-9000-000000000002",
            "6d657263-0203-4b00-9000-000000000003", "6d657263-0203-4b00-9000-000000000004",
            "6d657263-0203-4b00-9000-000000000005", "6d657263-0203-4b00-9000-000000000006",
            "6d657263-0203-4b00-9000-000000000007", "6d657263-0203-4b00-9000-000000000008",
            "6d657263-0203-4b00-9000-000000000009", "6d657263-0203-4b00-9000-00000000000a"
        }
    },
    -- 3: Cumans
    [3] = {
        weak = {
            "6d657263-0301-4b00-9000-000000000001", "6d657263-0301-4b00-9000-000000000002",
            "6d657263-0301-4b00-9000-000000000003", "6d657263-0301-4b00-9000-000000000004",
            "6d657263-0301-4b00-9000-000000000005", "6d657263-0301-4b00-9000-000000000006",
            "6d657263-0301-4b00-9000-000000000007", "6d657263-0301-4b00-9000-000000000008",
            "6d657263-0301-4b00-9000-000000000009", "6d657263-0301-4b00-9000-00000000000a"
        },
        medium = {
            "6d657263-0302-4b00-9000-000000000001", "6d657263-0302-4b00-9000-000000000002",
            "6d657263-0302-4b00-9000-000000000003", "6d657263-0302-4b00-9000-000000000004",
            "6d657263-0302-4b00-9000-000000000005", "6d657263-0302-4b00-9000-000000000006",
            "6d657263-0302-4b00-9000-000000000007", "6d657263-0302-4b00-9000-000000000008",
            "6d657263-0302-4b00-9000-000000000009", "6d657263-0302-4b00-9000-00000000000a"
        },
        strong = {
            "6d657263-0303-4b00-9000-000000000001", "6d657263-0303-4b00-9000-000000000002",
            "6d657263-0303-4b00-9000-000000000003", "6d657263-0303-4b00-9000-000000000004",
            "6d657263-0303-4b00-9000-000000000005", "6d657263-0303-4b00-9000-000000000006",
            "6d657263-0303-4b00-9000-000000000007", "6d657263-0303-4b00-9000-000000000008",
            "6d657263-0303-4b00-9000-000000000009", "6d657263-0303-4b00-9000-00000000000a"
        }
    },
    -- 4: Leipa
    [4] = {
        weak = {
            "6d657263-0401-4b00-9000-000000000001", "6d657263-0401-4b00-9000-000000000002",
            "6d657263-0401-4b00-9000-000000000003", "6d657263-0401-4b00-9000-000000000004",
            "6d657263-0401-4b00-9000-000000000005", "6d657263-0401-4b00-9000-000000000006",
            "6d657263-0401-4b00-9000-000000000007", "6d657263-0401-4b00-9000-000000000008",
            "6d657263-0401-4b00-9000-000000000009", "6d657263-0401-4b00-9000-00000000000a"
        },
        medium = {
            "6d657263-0402-4b00-9000-000000000001", "6d657263-0402-4b00-9000-000000000002",
            "6d657263-0402-4b00-9000-000000000003", "6d657263-0402-4b00-9000-000000000004",
            "6d657263-0402-4b00-9000-000000000005", "6d657263-0402-4b00-9000-000000000006",
            "6d657263-0402-4b00-9000-000000000007", "6d657263-0402-4b00-9000-000000000008",
            "6d657263-0402-4b00-9000-000000000009", "6d657263-0402-4b00-9000-00000000000a"
        },
        strong = {
            "6d657263-0403-4b00-9000-000000000001", "6d657263-0403-4b00-9000-000000000002",
            "6d657263-0403-4b00-9000-000000000003", "6d657263-0403-4b00-9000-000000000004",
            "6d657263-0403-4b00-9000-000000000005", "6d657263-0403-4b00-9000-000000000006",
            "6d657263-0403-4b00-9000-000000000007", "6d657263-0403-4b00-9000-000000000008",
            "6d657263-0403-4b00-9000-000000000009", "6d657263-0403-4b00-9000-00000000000a"
        }
    },
    -- 5: Kuttenberg
    [5] = {
        weak = {
            "6d657263-0501-4b00-9000-000000000001", "6d657263-0501-4b00-9000-000000000002",
            "6d657263-0501-4b00-9000-000000000003", "6d657263-0501-4b00-9000-000000000004",
            "6d657263-0501-4b00-9000-000000000005", "6d657263-0501-4b00-9000-000000000006",
            "6d657263-0501-4b00-9000-000000000007", "6d657263-0501-4b00-9000-000000000008",
            "6d657263-0501-4b00-9000-000000000009", "6d657263-0501-4b00-9000-00000000000a"
        },
        medium = {
            "6d657263-0502-4b00-9000-000000000001", "6d657263-0502-4b00-9000-000000000002",
            "6d657263-0502-4b00-9000-000000000003", "6d657263-0502-4b00-9000-000000000004",
            "6d657263-0502-4b00-9000-000000000005", "6d657263-0502-4b00-9000-000000000006",
            "6d657263-0502-4b00-9000-000000000007", "6d657263-0502-4b00-9000-000000000008",
            "6d657263-0502-4b00-9000-000000000009", "6d657263-0502-4b00-9000-00000000000a"
        },
        strong = {
            "6d657263-0503-4b00-9000-000000000001", "6d657263-0503-4b00-9000-000000000002",
            "6d657263-0503-4b00-9000-000000000003", "6d657263-0503-4b00-9000-000000000004",
            "6d657263-0503-4b00-9000-000000000005", "6d657263-0503-4b00-9000-000000000006",
            "6d657263-0503-4b00-9000-000000000007", "6d657263-0503-4b00-9000-000000000008",
            "6d657263-0503-4b00-9000-000000000009", "6d657263-0503-4b00-9000-00000000000a"
        }
    },
    -- 6: Skalitz
    [6] = {
        weak = {
            "c2f6f619-3905-4188-91be-fa59aa25c219", "fbab5364-5cb5-4723-aecf-2ad16592f330",
            "1a2b3c4d-5e6f-4789-a0b1-c2d3e4f5a6b7", "2b3c4d5e-6f7a-4890-b1c2-d3e4f5a6b7c8"
        },
        medium = {
            "54d71294-d3b8-4adf-acae-253cf81f5a92", "e76a4de0-120a-43f5-b217-7faeae96d6b9",
            "3c4d5e6f-7a8b-4901-8c2d-e4f5a6b7c8d9", "4d5e6f7a-8b9c-4a12-9d3e-f5a6b7c8d9e0"
        },
        strong = {
            "6583e2ea-f771-479b-b3d9-2b0bff23d3d6", "1487b173-f584-48b2-8dca-8f7ebcf56156",
            "5e6f7a8b-9c0d-4b23-8e4f-a6b7c8d9e0f1", "6f7a8b9c-0d1e-4c34-9f5a-b7c8d9e0f1a2"
        }
    },
    -- 7 is the custom uniform (mercenaries_custom_gear.lua): the player hands the
    -- quartermaster a set of gear and the company copies it, so it has no preset
    -- pool here. New liveries start at 8.
    -- 8: Prague
    [8] = {
        weak = {
            "6d657263-0801-4b00-9000-000000000001", "6d657263-0801-4b00-9000-000000000002",
            "6d657263-0801-4b00-9000-000000000003", "6d657263-0801-4b00-9000-000000000004",
            "6d657263-0801-4b00-9000-000000000005", "6d657263-0801-4b00-9000-000000000006",
            "6d657263-0801-4b00-9000-000000000007", "6d657263-0801-4b00-9000-000000000008",
            "6d657263-0801-4b00-9000-000000000009", "6d657263-0801-4b00-9000-00000000000a"
        },
        medium = {
            "6d657263-0802-4b00-9000-000000000001", "6d657263-0802-4b00-9000-000000000002",
            "6d657263-0802-4b00-9000-000000000003", "6d657263-0802-4b00-9000-000000000004",
            "6d657263-0802-4b00-9000-000000000005", "6d657263-0802-4b00-9000-000000000006",
            "6d657263-0802-4b00-9000-000000000007", "6d657263-0802-4b00-9000-000000000008",
            "6d657263-0802-4b00-9000-000000000009", "6d657263-0802-4b00-9000-00000000000a"
        },
        strong = {
            "6d657263-0803-4b00-9000-000000000001", "6d657263-0803-4b00-9000-000000000002",
            "6d657263-0803-4b00-9000-000000000003", "6d657263-0803-4b00-9000-000000000004",
            "6d657263-0803-4b00-9000-000000000005", "6d657263-0803-4b00-9000-000000000006",
            "6d657263-0803-4b00-9000-000000000007", "6d657263-0803-4b00-9000-000000000008",
            "6d657263-0803-4b00-9000-000000000009", "6d657263-0803-4b00-9000-00000000000a"
        }
    },
    -- 9: Sigismund (Hungarian)
    [9] = {
        weak = {
            "6d657263-0901-4b00-9000-000000000001", "6d657263-0901-4b00-9000-000000000002",
            "6d657263-0901-4b00-9000-000000000003", "6d657263-0901-4b00-9000-000000000004",
            "6d657263-0901-4b00-9000-000000000005", "6d657263-0901-4b00-9000-000000000006",
            "6d657263-0901-4b00-9000-000000000007", "6d657263-0901-4b00-9000-000000000008",
            "6d657263-0901-4b00-9000-000000000009", "6d657263-0901-4b00-9000-00000000000a"
        },
        medium = {
            "6d657263-0902-4b00-9000-000000000001", "6d657263-0902-4b00-9000-000000000002",
            "6d657263-0902-4b00-9000-000000000003", "6d657263-0902-4b00-9000-000000000004",
            "6d657263-0902-4b00-9000-000000000005", "6d657263-0902-4b00-9000-000000000006",
            "6d657263-0902-4b00-9000-000000000007", "6d657263-0902-4b00-9000-000000000008",
            "6d657263-0902-4b00-9000-000000000009", "6d657263-0902-4b00-9000-00000000000a"
        },
        strong = {
            "6d657263-0903-4b00-9000-000000000001", "6d657263-0903-4b00-9000-000000000002",
            "6d657263-0903-4b00-9000-000000000003", "6d657263-0903-4b00-9000-000000000004",
            "6d657263-0903-4b00-9000-000000000005", "6d657263-0903-4b00-9000-000000000006",
            "6d657263-0903-4b00-9000-000000000007", "6d657263-0903-4b00-9000-000000000008",
            "6d657263-0903-4b00-9000-000000000009", "6d657263-0903-4b00-9000-00000000000a"
        }
    },
    -- 10: Order of the Red Star
    [10] = {
        weak = {
            "6d657263-1001-4b00-9000-000000000001", "6d657263-1001-4b00-9000-000000000002",
            "6d657263-1001-4b00-9000-000000000003", "6d657263-1001-4b00-9000-000000000004",
            "6d657263-1001-4b00-9000-000000000005", "6d657263-1001-4b00-9000-000000000006",
            "6d657263-1001-4b00-9000-000000000007", "6d657263-1001-4b00-9000-000000000008",
            "6d657263-1001-4b00-9000-000000000009", "6d657263-1001-4b00-9000-00000000000a"
        },
        medium = {
            "6d657263-1002-4b00-9000-000000000001", "6d657263-1002-4b00-9000-000000000002",
            "6d657263-1002-4b00-9000-000000000003", "6d657263-1002-4b00-9000-000000000004",
            "6d657263-1002-4b00-9000-000000000005", "6d657263-1002-4b00-9000-000000000006",
            "6d657263-1002-4b00-9000-000000000007", "6d657263-1002-4b00-9000-000000000008",
            "6d657263-1002-4b00-9000-000000000009", "6d657263-1002-4b00-9000-00000000000a"
        },
        strong = {
            "6d657263-1003-4b00-9000-000000000001", "6d657263-1003-4b00-9000-000000000002",
            "6d657263-1003-4b00-9000-000000000003", "6d657263-1003-4b00-9000-000000000004",
            "6d657263-1003-4b00-9000-000000000005", "6d657263-1003-4b00-9000-000000000006",
            "6d657263-1003-4b00-9000-000000000007", "6d657263-1003-4b00-9000-000000000008",
            "6d657263-1003-4b00-9000-000000000009", "6d657263-1003-4b00-9000-00000000000a"
        }
    },
    -- 11: Bergov
    [11] = {
        weak = {
            "6d657263-1101-4b00-9000-000000000001", "6d657263-1101-4b00-9000-000000000002",
            "6d657263-1101-4b00-9000-000000000003", "6d657263-1101-4b00-9000-000000000004",
            "6d657263-1101-4b00-9000-000000000005", "6d657263-1101-4b00-9000-000000000006",
            "6d657263-1101-4b00-9000-000000000007", "6d657263-1101-4b00-9000-000000000008",
            "6d657263-1101-4b00-9000-000000000009", "6d657263-1101-4b00-9000-00000000000a"
        },
        medium = {
            "6d657263-1102-4b00-9000-000000000001", "6d657263-1102-4b00-9000-000000000002",
            "6d657263-1102-4b00-9000-000000000003", "6d657263-1102-4b00-9000-000000000004",
            "6d657263-1102-4b00-9000-000000000005", "6d657263-1102-4b00-9000-000000000006",
            "6d657263-1102-4b00-9000-000000000007", "6d657263-1102-4b00-9000-000000000008",
            "6d657263-1102-4b00-9000-000000000009", "6d657263-1102-4b00-9000-00000000000a"
        },
        strong = {
            "6d657263-1103-4b00-9000-000000000001", "6d657263-1103-4b00-9000-000000000002",
            "6d657263-1103-4b00-9000-000000000003", "6d657263-1103-4b00-9000-000000000004",
            "6d657263-1103-4b00-9000-000000000005", "6d657263-1103-4b00-9000-000000000006",
            "6d657263-1103-4b00-9000-000000000007", "6d657263-1103-4b00-9000-000000000008",
            "6d657263-1103-4b00-9000-000000000009", "6d657263-1103-4b00-9000-00000000000a"
        }
    },
    -- 12: Nebakov
    [12] = {
        weak = {
            "6d657263-1201-4b00-9000-000000000001", "6d657263-1201-4b00-9000-000000000002",
            "6d657263-1201-4b00-9000-000000000003", "6d657263-1201-4b00-9000-000000000004",
            "6d657263-1201-4b00-9000-000000000005", "6d657263-1201-4b00-9000-000000000006",
            "6d657263-1201-4b00-9000-000000000007", "6d657263-1201-4b00-9000-000000000008",
            "6d657263-1201-4b00-9000-000000000009", "6d657263-1201-4b00-9000-00000000000a"
        },
        medium = {
            "6d657263-1202-4b00-9000-000000000001", "6d657263-1202-4b00-9000-000000000002",
            "6d657263-1202-4b00-9000-000000000003", "6d657263-1202-4b00-9000-000000000004",
            "6d657263-1202-4b00-9000-000000000005", "6d657263-1202-4b00-9000-000000000006",
            "6d657263-1202-4b00-9000-000000000007", "6d657263-1202-4b00-9000-000000000008",
            "6d657263-1202-4b00-9000-000000000009", "6d657263-1202-4b00-9000-00000000000a"
        },
        strong = {
            "6d657263-1203-4b00-9000-000000000001", "6d657263-1203-4b00-9000-000000000002",
            "6d657263-1203-4b00-9000-000000000003", "6d657263-1203-4b00-9000-000000000004",
            "6d657263-1203-4b00-9000-000000000005", "6d657263-1203-4b00-9000-000000000006",
            "6d657263-1203-4b00-9000-000000000007", "6d657263-1203-4b00-9000-000000000008",
            "6d657263-1203-4b00-9000-000000000009", "6d657263-1203-4b00-9000-00000000000a"
        }
    },
    -- 13: Semine
    [13] = {
        weak = {
            "6d657263-1301-4b00-9000-000000000001", "6d657263-1301-4b00-9000-000000000002",
            "6d657263-1301-4b00-9000-000000000003", "6d657263-1301-4b00-9000-000000000004",
            "6d657263-1301-4b00-9000-000000000005", "6d657263-1301-4b00-9000-000000000006",
            "6d657263-1301-4b00-9000-000000000007", "6d657263-1301-4b00-9000-000000000008",
            "6d657263-1301-4b00-9000-000000000009", "6d657263-1301-4b00-9000-00000000000a"
        },
        medium = {
            "6d657263-1302-4b00-9000-000000000001", "6d657263-1302-4b00-9000-000000000002",
            "6d657263-1302-4b00-9000-000000000003", "6d657263-1302-4b00-9000-000000000004",
            "6d657263-1302-4b00-9000-000000000005", "6d657263-1302-4b00-9000-000000000006",
            "6d657263-1302-4b00-9000-000000000007", "6d657263-1302-4b00-9000-000000000008",
            "6d657263-1302-4b00-9000-000000000009", "6d657263-1302-4b00-9000-00000000000a"
        },
        strong = {
            "6d657263-1303-4b00-9000-000000000001", "6d657263-1303-4b00-9000-000000000002",
            "6d657263-1303-4b00-9000-000000000003", "6d657263-1303-4b00-9000-000000000004",
            "6d657263-1303-4b00-9000-000000000005", "6d657263-1303-4b00-9000-000000000006",
            "6d657263-1303-4b00-9000-000000000007", "6d657263-1303-4b00-9000-000000000008",
            "6d657263-1303-4b00-9000-000000000009", "6d657263-1303-4b00-9000-00000000000a"
        }
    },
    -- 14: Pisek
    [14] = {
        weak = {
            "6d657263-1401-4b00-9000-000000000001", "6d657263-1401-4b00-9000-000000000002",
            "6d657263-1401-4b00-9000-000000000003", "6d657263-1401-4b00-9000-000000000004",
            "6d657263-1401-4b00-9000-000000000005", "6d657263-1401-4b00-9000-000000000006",
            "6d657263-1401-4b00-9000-000000000007", "6d657263-1401-4b00-9000-000000000008",
            "6d657263-1401-4b00-9000-000000000009", "6d657263-1401-4b00-9000-00000000000a"
        },
        medium = {
            "6d657263-1402-4b00-9000-000000000001", "6d657263-1402-4b00-9000-000000000002",
            "6d657263-1402-4b00-9000-000000000003", "6d657263-1402-4b00-9000-000000000004",
            "6d657263-1402-4b00-9000-000000000005", "6d657263-1402-4b00-9000-000000000006",
            "6d657263-1402-4b00-9000-000000000007", "6d657263-1402-4b00-9000-000000000008",
            "6d657263-1402-4b00-9000-000000000009", "6d657263-1402-4b00-9000-00000000000a"
        },
        strong = {
            "6d657263-1403-4b00-9000-000000000001", "6d657263-1403-4b00-9000-000000000002",
            "6d657263-1403-4b00-9000-000000000003", "6d657263-1403-4b00-9000-000000000004",
            "6d657263-1403-4b00-9000-000000000005", "6d657263-1403-4b00-9000-000000000006",
            "6d657263-1403-4b00-9000-000000000007", "6d657263-1403-4b00-9000-000000000008",
            "6d657263-1403-4b00-9000-000000000009", "6d657263-1403-4b00-9000-00000000000a"
        }
    },
    -- 15: Teutonic Order
    [15] = {
        weak = {
            "6d657263-1501-4b00-9000-000000000001", "6d657263-1501-4b00-9000-000000000002",
            "6d657263-1501-4b00-9000-000000000003", "6d657263-1501-4b00-9000-000000000004",
            "6d657263-1501-4b00-9000-000000000005", "6d657263-1501-4b00-9000-000000000006",
            "6d657263-1501-4b00-9000-000000000007", "6d657263-1501-4b00-9000-000000000008",
            "6d657263-1501-4b00-9000-000000000009", "6d657263-1501-4b00-9000-00000000000a"
        },
        medium = {
            "6d657263-1502-4b00-9000-000000000001", "6d657263-1502-4b00-9000-000000000002",
            "6d657263-1502-4b00-9000-000000000003", "6d657263-1502-4b00-9000-000000000004",
            "6d657263-1502-4b00-9000-000000000005", "6d657263-1502-4b00-9000-000000000006",
            "6d657263-1502-4b00-9000-000000000007", "6d657263-1502-4b00-9000-000000000008",
            "6d657263-1502-4b00-9000-000000000009", "6d657263-1502-4b00-9000-00000000000a"
        },
        strong = {
            "6d657263-1503-4b00-9000-000000000001", "6d657263-1503-4b00-9000-000000000002",
            "6d657263-1503-4b00-9000-000000000003", "6d657263-1503-4b00-9000-000000000004",
            "6d657263-1503-4b00-9000-000000000005", "6d657263-1503-4b00-9000-000000000006",
            "6d657263-1503-4b00-9000-000000000007", "6d657263-1503-4b00-9000-000000000008",
            "6d657263-1503-4b00-9000-000000000009", "6d657263-1503-4b00-9000-00000000000a"
        }
    },
    -- 16: Ruthard
    [16] = {
        weak = {
            "6d657263-1601-4b00-9000-000000000001", "6d657263-1601-4b00-9000-000000000002",
            "6d657263-1601-4b00-9000-000000000003", "6d657263-1601-4b00-9000-000000000004",
            "6d657263-1601-4b00-9000-000000000005", "6d657263-1601-4b00-9000-000000000006",
            "6d657263-1601-4b00-9000-000000000007", "6d657263-1601-4b00-9000-000000000008",
            "6d657263-1601-4b00-9000-000000000009", "6d657263-1601-4b00-9000-00000000000a"
        },
        medium = {
            "6d657263-1602-4b00-9000-000000000001", "6d657263-1602-4b00-9000-000000000002",
            "6d657263-1602-4b00-9000-000000000003", "6d657263-1602-4b00-9000-000000000004",
            "6d657263-1602-4b00-9000-000000000005", "6d657263-1602-4b00-9000-000000000006",
            "6d657263-1602-4b00-9000-000000000007", "6d657263-1602-4b00-9000-000000000008",
            "6d657263-1602-4b00-9000-000000000009", "6d657263-1602-4b00-9000-00000000000a"
        },
        strong = {
            "6d657263-1603-4b00-9000-000000000001", "6d657263-1603-4b00-9000-000000000002",
            "6d657263-1603-4b00-9000-000000000003", "6d657263-1603-4b00-9000-000000000004",
            "6d657263-1603-4b00-9000-000000000005", "6d657263-1603-4b00-9000-000000000006",
            "6d657263-1603-4b00-9000-000000000007", "6d657263-1603-4b00-9000-000000000008",
            "6d657263-1603-4b00-9000-000000000009", "6d657263-1603-4b00-9000-00000000000a"
        }
    },
    -- 17: Papal Legate
    [17] = {
        weak = {
            "6d657263-1701-4b00-9000-000000000001", "6d657263-1701-4b00-9000-000000000002",
            "6d657263-1701-4b00-9000-000000000003", "6d657263-1701-4b00-9000-000000000004",
            "6d657263-1701-4b00-9000-000000000005", "6d657263-1701-4b00-9000-000000000006",
            "6d657263-1701-4b00-9000-000000000007", "6d657263-1701-4b00-9000-000000000008",
            "6d657263-1701-4b00-9000-000000000009", "6d657263-1701-4b00-9000-00000000000a"
        },
        medium = {
            "6d657263-1702-4b00-9000-000000000001", "6d657263-1702-4b00-9000-000000000002",
            "6d657263-1702-4b00-9000-000000000003", "6d657263-1702-4b00-9000-000000000004",
            "6d657263-1702-4b00-9000-000000000005", "6d657263-1702-4b00-9000-000000000006",
            "6d657263-1702-4b00-9000-000000000007", "6d657263-1702-4b00-9000-000000000008",
            "6d657263-1702-4b00-9000-000000000009", "6d657263-1702-4b00-9000-00000000000a"
        },
        strong = {
            "6d657263-1703-4b00-9000-000000000001", "6d657263-1703-4b00-9000-000000000002",
            "6d657263-1703-4b00-9000-000000000003", "6d657263-1703-4b00-9000-000000000004",
            "6d657263-1703-4b00-9000-000000000005", "6d657263-1703-4b00-9000-000000000006",
            "6d657263-1703-4b00-9000-000000000007", "6d657263-1703-4b00-9000-000000000008",
            "6d657263-1703-4b00-9000-000000000009", "6d657263-1703-4b00-9000-00000000000a"
        }
    }
}

-- Armour grade of the vanilla clothing presets the enemy groups draw from.
-- Not worn by the squad; DiffClothingTierIndex folds this in so
-- DiffWardrobe can still sort an enemy group into a ragged and a good
-- half. Graded by measured armour value, not by hand.
mercenaries.OutfitTierHints = {
    weak = {
        "efff8f2e-a199-4883-8bb8-3219c4103e22", -- cuman_4_04 (946)
        "1291b696-d704-4fb0-90da-2bdf4c2eefef", -- cuman_3_02 (844)
        "9b9f92a0-7040-4f3e-85ee-1f2651ee6672", -- cuman_3_03 (761)
        "70618c60-9f1e-4949-a1d2-06b1a9709e82", -- cuman_3_01 (542)
        "c685a814-ace0-4c6b-b8bb-9a024d073d42", -- sedmStatecnych_bandit_3 (384)
        "07a49bb9-1b92-43c2-848f-f4abf88a3b12", -- zbranePanaSemina_bandit_5 (279)
        "20aba0c4-1cfb-42de-97dd-939530d6240d", -- soldierShady_generic_1_01 (230)
        "fca2a301-45e5-4cd9-af18-09469bbd8102", -- cuman_2_04 (192)
        "e1f7bfd8-f211-4693-9004-0fc36f166e1f", -- cuman_2_03 (141)
        "08d7d086-327a-4f95-92d3-6a6c60a494f0", -- cuman_2_05 (137)
        "2285cbe9-3962-4093-94a9-86f556e5bf2f", -- soldierShady_generic_1_02 (132)
        "838f07ef-5875-4391-9fe2-5fd93ffa6501", -- cuman_2_02 (128)
        "4163bbb6-a7bf-47a3-b5c7-bffdbe0c2062", -- cuman_2_01 (126)
    },
    medium = {
        "48f33d37-90ab-489a-9236-d56819d25ea2", -- kvrc_bandit_1 (1532)
        "d4468c20-47e3-49dd-995e-65063040696e", -- prepadeni_pivec (1433)
        "394c8de2-7525-4f3a-8774-17876c95b6b6", -- _pr_sonybandit04 (1287)
        "0154a9ef-ad07-4c4a-bf5b-4bca21b65d7b", -- taboryUCesty_dealer_raubritter (1243)
        "8d8951b3-af89-4c0a-a7d6-99c8f6f7fe86", -- cuman_4_02 (1173)
        "94d6d667-139b-4d79-a25b-f2b608b86c96", -- kvrc_bandit_2 (1169)
        "978b6b0c-288b-4d0b-8cfa-f2fe1a801409", -- cuman_4_03 (1062)
        "bd87c9e4-5481-4a98-8279-ec010e4c10ad", -- cuman_4_01 (1023)
        "fdec006f-b7e2-491a-8a1d-f453501b7ffc", -- taboryUCesty_dealer_raubritter_man (987)
    },
    strong = {
    },
}

-- WEAPON LOADOUT DICTIONARY
-- Index 1 ("Random") has no entry here — it's handled specially in
-- EquipMercenaryWeapon by picking a random category from 2-12 each time.
-- Values are weapon_preset_id GUIDs from weapon_preset__mercenaries.xml.
mercenaries.WeaponSets = {
    -- 2: Sword and shield
    [2] = {
        weak = {
            "aef0bb38-59a8-46cb-99bd-f4447e849a04", "4c06c342-1f4e-4259-ae48-94c636ae3d3e",
            "b6e1c2a4-3f8d-4c11-9a2e-7d5f8b3c1a90", "a17f9d2b-6c4e-4a83-8b1f-3e9c7d2a5b64"
        },
        medium = {
            "e6b2dd31-5e6f-4ba9-a221-dfa8ec993d8e", "cb12a1ab-b658-45bc-abdd-7e7d9e632bd6",
            "c3d8a1f5-2b7e-4f96-8c3a-1d6e9b4f7c22", "d4e9b2a6-3c8f-4a09-9d4b-2e7f0a5c8d33"
        },
        strong = {
            "85741a9f-1e35-45b8-879e-cfa17fc87dc0", "f21f88f7-d0d7-4b72-8c6d-abebe945f071",
            "e5fa3b7c-4d9a-4b12-8e5c-3f8a1b6d9e44", "f60b4c8d-5eab-4c23-9f6d-4a9b2c7e0f55"
        }
    },
    -- 3: Axe and shield
    [3] = {
        weak = {
            "1231bf2d-a4a2-4afe-bc46-e90a89aeb693", "3730631f-7bf6-42b0-9141-34a32ac3e0a0",
            "04cdf545-216f-40a9-8bbe-e3df62c6c9c4", "8cadc064-2b10-4c83-b623-baa48ed00887"
        },
        medium = {
            "75619084-5ad1-4b57-9367-3cf4b5564d4c", "841b2ea4-fc4a-4b9c-8bda-7e982f90945d",
            "67b28c22-75ae-46c1-9fbb-74c4e5404bc8", "d5320f5a-4b3f-4b24-a396-642e82ede04e"
        },
        strong = {
            "a1bdde2f-5c26-4cc8-8f97-97e7e5120832", "4f4e5cd2-fea7-486d-86c1-b0636631ff54",
            "4da2558e-7c3b-4e71-9a0f-4e0fb96e31f7", "a03246b9-5795-4b88-8a09-2558cd3f2b21"
        }
    },
    -- 4: Longsword
    [4] = {
        weak = {
            "38118d03-1fed-4b1b-a8ba-7e195ea7ebc7", "fc3dd411-ca51-49cd-bc1b-480caf1f2f20",
            "54e2ff1a-cd9c-4558-9533-ded96a3f0603", "e84ebb37-bf5c-45ea-abe9-a416a5ad38e2",
            "b53518cb-e7d6-4eb6-9d6e-211a14adcaa1"
        },
        medium = {
            "5539c7d7-15e5-49a0-8db7-aeff9f3ce550", "73fbc897-2756-4d34-9e7a-57959de342b2",
            "b3072196-f572-401b-a213-5c023d8d1a92", "eb316792-4ebd-43c7-b554-d0cbdef360f8",
            "c0638095-60c3-40d0-b93d-3f42f237a20e"
        },
        strong = {
            "890cca0b-6489-47f0-9331-706a015ff21e", "d9c83f05-f0d7-4304-9dee-c3106d6ab3fe",
            "94be3211-a101-4de7-b29d-a5dfde474f57", "31a30fb0-4d4e-4ed8-925d-fc481bd1063b"
        }
    },
    -- 5: Mace and shield
    [5] = {
        weak = {
            "e9304794-d205-41a9-bc2c-4b91ef966d81", "cb350569-6753-40c2-bca8-e9bd059dfe56",
            "8cd52efe-5c75-4ca4-a73e-d742856de6ad", "05de7ab9-82dd-44db-8dcf-c065a3f88f4f"
        },
        medium = {
            "65804416-c27f-4a7b-bae2-40cc77d3bbec", "946bd250-054d-49c7-a773-de35475c7f1a",
            "e72434c6-0ce9-4a03-a9a1-a34586b5f141", "b5a967b8-4ed8-4814-b233-a7b4125375d2"
        },
        strong = {
            "45ca9e2a-16a1-445c-8b25-040f60987283", "56035f56-6a73-4ed7-87bf-8896f24ec33f",
            "232574b9-4aef-42f2-8b78-8218d8702ddb"
        }
    },
    -- 6: Shortsword
    [6] = {
        weak = {
            "2c28935e-103c-4f0a-b154-36890bac73f2", "11bd007a-0312-4e4d-968d-2c4cb9fe6286"
        },
        medium = {
            "8c38d157-2403-41fb-a573-c2a396a29235", "e4266b99-79fb-40ef-84fa-0b721a6ba3c2"
        },
        strong = {
            "0d4fc137-2b83-4d2d-970e-cf09871f29d6", "8d7d2c25-874e-41f8-a169-c3e731b23249"
        }
    },
    -- 7: Mace
    [7] = {
        weak = {
            "720fcde5-15b8-4f3b-b0c9-489a99e7043e", "533bd7b4-d70a-4af2-abaa-fe09b5c8fb28",
            "122e7230-d72f-4d84-a1a0-59f9f0f7d235", "0d951547-9012-48cd-8e43-9d502e01e9a7"
        },
        medium = {
            "c66f0c6e-c281-4024-a1c5-3ebb1fc69cc0", "10e96c57-99a6-43ee-9279-fd7bc7132972",
            "439fe662-b7ec-4605-9729-e8f3e8df4bc7", "83142d88-9463-4930-9d6e-aa86dae6d35a"
        },
        strong = {
            "2ae255da-ed23-46b6-aec7-0deeac7d5e2e", "97c91389-882c-4387-9cb4-9abfee9ded51",
            "9367c4d6-2897-42dd-9697-8adfa4356ecb"
        }
    },
    -- 8: Axe
    [8] = {
        weak = {
            "1fd54037-8eb6-4ce4-9f02-63acce98183d", "67cb04b2-2a7c-40dc-9f93-4b1ef6fd58c4",
            "5076de8f-f9f2-4c4b-a1bd-e23034219359", "6aba5df6-a2cf-4a2e-8ec4-e69de02dcab4"
        },
        medium = {
            "986244d4-e276-40f4-a6b4-649a934cc450", "d5f3e8de-5abf-4bea-be19-9a9d3c756f00",
            "81787f5f-80a0-42fc-a742-46f0f3a8015e", "7803affa-1a74-42c6-9fcf-ed6c1d3289b0"
        },
        strong = {
            "9d139c04-b054-4e98-b4d3-8054a639f485", "d834a864-7b9a-4557-93ad-024555604735",
            "59418607-6a33-45cc-9903-582a07f22a5c", "a1554b5a-a4b8-4541-8706-c97b8657672c"
        }
    },
    -- 9: Polearm
    [9] = {
        weak = {
            "5d4c7a48-c95c-4e59-96c4-54851e75160b", "ad5922d0-0614-4912-b98c-adb2241602b4",
            "482d2d35-87d2-47e1-8edd-4ed85d28912e", "8baedacf-d744-451a-8acd-332c32165120"
        },
        medium = {
            "d72d9727-43ab-4e85-a0fa-bd6664fff2e7", "1b086963-8c38-41c9-867e-b79174b6206d",
            "3deb122d-a168-4bfb-9ae0-143d24ae029d"
        },
        strong = {
            "9a8dccf1-9948-49d1-81f9-8b50d62cd373", "2cd35a00-09e3-4b76-b2c5-f13e2251cb65",
            "b1b35d6f-3daa-46df-b3bf-96eda006833c"
        }
    },
    -- 10: Archer (bow)
    [10] = {
        weak = {
            "e3e35ccf-4eac-47d6-93ed-9dd343540998", "4a2525e0-0787-4eb9-a56a-9ac9c105a8f4"
        },
        medium = {
            "104b4d63-519f-4d76-8826-e8ffdc3b520f", "4797ce5f-954d-4df4-ad4b-115b4004850c"
        },
        strong = {
            "832e27a6-f6a9-4f86-aa99-bf42066cd7ad", "d582651e-129b-4230-b6c1-b1c783a0566d"
        }
    },
    -- 11: Crossbow
    [11] = {
        weak = {
            "8e256398-37a8-4c16-81eb-4535296a2c9c", "3b297403-b517-441e-b219-d58fa7e078fc"
        },
        medium = {
            "6b0e8574-0486-4990-8dcc-8aef99aeee85", "947a178c-5a0b-4040-9d71-534544c0e3b3"
        },
        strong = {
            "7b026220-fd56-48fa-9f9c-7b8e33294118", "9f8743e4-6a5a-4a86-a74c-6ee33b2d1f45"
        }
    },
    -- 12: Handcannon
    [12] = {
        weak = {
            "b785e210-1881-4c93-aa76-52d87dad0620", "4e80ca93-ebca-4397-9ed8-353c4fab2fec"
        },
        medium = {
            "53c9970d-531a-4c72-af42-867f20549fd8"
        },
        strong = {
            "01aaaac4-be90-45cf-9f66-9392783f2c84"
        }
    }
}

--easter egg equipment sets
mercenaries.Clowns = {
    "21461dcf-a13e-4d0f-a273-655ad78d55b0",
    "926d3384-5b71-4f78-a59e-dd72fb9110a0",
    "bf4cd819-438c-4836-bbd3-0c2cce81a152",

    "c4b61546-ed82-4b7c-91bb-e7daea254af1"
}

-- Custom Companion Dictionary (Maps ccID to Soul GUID and Cost)
mercenaries.CustomCompanionsData = {
    [1] = { guid = "74db1d52-7360-4ed3-b716-f6a53f47f2f9", cost = 1500, name = "Kubenka" },
    [2] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11801", cost = 1000, name = "Vasko" },
    [3] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11802", cost = 800, name = "Jasak" },
    [4] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11803", cost = 2000, name = "Black Bartosch" },
    [5] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11804", cost = 2000, name = "Gnarly (Hejtman Suk)" },
    [6] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11805", cost = 1500, name = "Jan Posy" },
    [7] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11806", cost = 1500, name = "Miroslav Tugbone" },
    [8] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11807", cost = 1000, name = "Menhard" },
    [9] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11808", cost = 500, name = "Arne" },
    [10] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11809", cost = 800, name = "Janek of Skalitz" },
    [11] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11810", cost = 800, name = "Jaroslav" },
    [12] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11811", cost = 1500, name = "Adder (Komar)" },
    [13] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11812", cost = 1500, name = "Janosh (Hans of Uher)" },
    [14] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11813", cost = 500, name = "Mathew the Collector" },
    [15] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11814", cost = 3000, name = "Jan Zizka" },
    [16] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11815", cost = 3000, name = "The Devil" },
    [17] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11816", cost = 2500, name = "Godwin" },
    [18] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11817", cost = 3000, name = "Hans Capon" },
    -- BEGIN generated companions - tools/gen_companions.py - do not edit by hand
    [19] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11818", cost = 3500, name = "Racek Kobyla" },
    [20] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11819", cost = 3500, name = "Sir Hanush of Leipa" },
    [21] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11820", cost = 3500, name = "Erik" },
    [22] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11821", cost = 3000, name = "Sir Markvart von Aulitz" },
    [23] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11822", cost = 3000, name = "Jobst of Moravia" },
    [24] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11823", cost = 2500, name = "Sir Otto von Bergov" },
    [25] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11824", cost = 2500, name = "Oldrich Vavak" },
    [26] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11825", cost = 2500, name = "Kunzlin Ruthard" },
    [27] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11826", cost = 2500, name = "Samuel" },
    [28] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11827", cost = 2000, name = "Martin Oderin" },
    [29] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11828", cost = 3000, name = "Sir Istvan Toth" },
    [30] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11829", cost = 1500, name = "The Chamberlain of Trosky" },
    [31] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11830", cost = 5000, name = "King Sigismund" },
    [32] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11831", cost = 3000, name = "Jan II of Lichtenstein" },
    [33] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11832", cost = 2500, name = "Baron Vaquelin Brabant" },
    [34] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11833", cost = 2500, name = "Musa of Mali" },
    [35] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11834", cost = 2500, name = "Zacharias" },
    [36] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11835", cost = 2000, name = "Martin, Henry's father" },
    [37] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11836", cost = 1000, name = "Levej Bocek" },
    [38] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11837", cost = 1200, name = "Petr of Pisek" },
    [39] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11838", cost = 800, name = "The Painter" },
    [40] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11839", cost = 1200, name = "Hertl" },
    [41] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11840", cost = 1000, name = "Pelcl" },
    [42] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11841", cost = 1200, name = "Marek" },
    [43] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11842", cost = 1000, name = "Cverk" },
    [44] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11843", cost = 1000, name = "Volek" }
    -- end generated companions
}

-- Persistent counters to guarantee we never spawn duplicate faces in a batch
mercenaries.SoulIndex = { weak = 1, medium = 1, strong = 1 }

-- Run an arbitrary Lua string from the console (avoids equals/semicolon quirks).
function mercenaries:ExecString(text)
    local func, err = loadstring(text)
    if func then pcall(func) end
end

function mercenaries:SetState(state)
    -- An explicit dismiss/follow order breaks camp first (silently - the
    -- order's own info text already tells the player what happened), since
    -- otherwise the camp props would stand there empty/unused.
    if (state == "dismiss" or state == "follow") and self.CampActive then
        self:BreakMercCamp(true)
    end

    if state == "dismiss" then
        self:HoldEnd(true)
        self:EscortEnd(true)
        _G.MercenariesDismissed = true
        self:SaveString("MercenariesDismissed", "1")
        self:LogiUpdateStatusBuffs()   -- clear the HUD icons now, not on the next tick
        Game.SendInfoText('merc_info_dismissed', false, 0, 3)
        -- Paid-off men must eventually LEAVE THE WORLD. This never happened: the flag was
        -- set, the cache skipped them, and the entities walked around for the rest of the
        -- session - and, saved, into every session after it (the save-residue leak, see
        -- RebuildMercCache). A short delay so the dismissal doesn't read as a vanishing
        -- act; if the player saves inside it, the timer dies but the load sweep catches
        -- them on the next load - flag and sweep back each other up.
        for _, ent in pairs(self.ActiveMercs or {}) do
            if ent and ent.id then
                Script.SetTimerForFunction(15000, "mercenaries.DespawnMerc", ent.id)
            end
        end
    elseif state == "wait" then
        -- NOT a toggle. Every menu that fires this token - the order wheel and the
        -- E-dialog both - shows "Follow me" and "Wait here" as two separate, statically
        -- labelled options, so making a second "wait" mean "fall in" would do the exact
        -- opposite of the label the player just clicked. The one genuinely toggling
        -- control is the look-at prompt, and that passes an explicit boolean through
        -- SetSortieWait rather than coming through here.
        --
        -- "Wait here" is a real hold order now: they form a line on this ground and
        -- fight only what comes to it, instead of standing wherever they happened to
        -- be evicted with nothing pulling them back.
        --
        -- MercIdle is deliberately NOT set. The scheduler's idle arm evicts the
        -- follow tree and then parks the man on a 500ms Wait forever, which would sit
        -- on the same interrupt slot nav_goto needs to walk him to his station. Hold
        -- carries its own guards in the formation and straggler sweeps instead, and
        -- the persistent flag is cleared so a save taken mid-hold cannot come back
        -- permanently idle.
        _G.MercIdle = false
        _G.MercPersistentIdleFlag = false
        self:SaveString("MercIdlePersistent", "0")
        self:HoldBegin()
    elseif state == "follow" then
        self:HoldEnd(true)
        self:EscortEnd(true)
        -- Watch the squad for a few seconds and re-fire anyone who does not actually
        -- start walking. HoldEnd already opens this window when an order was standing;
        -- doing it here as well covers "follow me" given when nothing was.
        pcall(function() self:BeginFollowVerify("follow order") end)
        _G.MercIdle = false
        _G.MercPersistentIdleFlag = false
        mercenaries:SaveString("MercIdlePersistent", "0")
        Game.SendInfoText('merc_info_following', false, 0, 3)
    end
end

-- Each order category maps to a pool of single-line monolog dialogs (one Dialog =
-- one Decision = one Sequence); RequestBark picks one at random for variety.
mercenaries.BarkPools = {
    merc_bark_ack     = { "merc_bark_ack_1", "merc_bark_ack_2", "merc_bark_ack_3" },
    merc_bark_wait    = { "merc_bark_wait_1", "merc_bark_wait_2" },
    merc_bark_follow  = { "merc_bark_follow_1", "merc_bark_follow_2" },
    merc_bark_moveout = { "merc_bark_moveout_1" },
}

-- Queue an order bark on a merc; the follow BT reads _G.MercBarkReq[wuid] next
-- tick, plays it once, and clears it. wuid MUST be the entity id (entity.this.id,
-- the key the BT looks up), NOT the AI WUID from GetMyWUID - a different id space.
function mercenaries:RequestBark(wuid, alias)
    if not wuid or not alias then return end
    -- Named companions never speak. The mod's bark lines are written for anonymous
    -- sellswords and are played on the soul's own voice, so putting one in Zizka's
    -- mouth is worse than silence. This is the queue every order bark goes through,
    -- so one check here covers all of them.
    local ent; pcall(function() ent = System.GetEntity(wuid) end)
    if ent and self:IsHero(ent) then return end
    local pool = self.BarkPools[alias]
    if pool and #pool > 0 then alias = pool[math.random(#pool)] end
    _G.MercBarkReq = _G.MercBarkReq or {}
    _G.MercBarkReq[tostring(wuid)] = alias
end

-- Debug: fire an order bark on the nearest living merc, forcing the speaking lock
-- to it first so the test plays even if another merc holds the lock.
function mercenaries:BarkTest(alias)
    if not alias or alias == "" or alias == "%1" then alias = "merc_bark_ack" end
    if not player then return end
    local o = player:GetWorldPos()
    local best, bestD
    for _, ent in pairs(self.ActiveMercs) do
        if ent and self:IsAliveAndWell(ent, false) then
            local p = ent.GetWorldPos and ent:GetWorldPos()
            if p then
                local dd = (p.x - o.x) ^ 2 + (p.y - o.y) ^ 2 + (p.z - o.z) ^ 2
                if not bestD or dd < bestD then best, bestD = ent, dd end
            end
        end
    end
    if not best then System.LogAlways("[BarkTest] no merc found"); return end
    _G.MercSpeakingLock = false; _G.MercSpeakingOwner = nil   -- clear so the test always gets the lock
    local wuid = best.this and best.this.id or best.id   -- entity id, matches the BT lookup
    self:RequestBark(wuid, alias)
    System.LogAlways("[BarkTest] requested '" .. tostring(alias) .. "' on nearest merc (wuid " .. tostring(wuid) .. ")")
end
mercenaries:DevCommand("merc_bark_test", "mercenaries:BarkTest('%1')", "Manually fire an order bark on the nearest merc (arg=alias, default merc_bark_ack)")

-- The player's "wait here" / "follow me" toggle for the SORTIE (the mercs out of
-- camp, or the whole squad when there's no camp). Sets the global idle order but,
-- unlike SetState('follow'), does NOT break camp - the mercs who stayed in camp
-- ignore this flag and keep camping. In-camp mercs are held by their roles, so a
-- wait order only stops the sortie.
function mercenaries:SetSortieWait(wait)
    -- Same hold order as SetState('wait'); see the note there for why MercIdle stays
    -- off. The men in camp are held by their roles either way.
    _G.MercIdle = false
    _G.MercPersistentIdleFlag = false
    self:SaveString("MercIdlePersistent", "0")
    if wait then
        self:HoldBegin()
    else
        self:HoldEnd(true)
        self:EscortEnd(true)
        pcall(function() self:BeginFollowVerify("follow order") end)
        Game.SendInfoText('merc_info_following', false, 0, 3)
    end
end

-- inventory monitoring
function mercenaries:MonitorInventory()
    local p = player.inventory
    
    local countWeak = p:GetCountOfClass(self.TokenIDWeak)
    local countMedium = p:GetCountOfClass(self.TokenIDMedium)
    local countStrong = p:GetCountOfClass(self.TokenIDStrong)
    
    local countDismiss = p:GetCountOfClass(self.TokenIDDismiss)
    local countWait = p:GetCountOfClass(self.TokenIDWait)
    local countFollow = p:GetCountOfClass(self.TokenIDFollow)

    -- Grab the clothing token count
    local countChangeOutfit = p:GetCountOfClass(self.TokenIDChangeOutfit)

    -- Grab the weapon loadout token count
    local countChangeWeapon = p:GetCountOfClass(self.TokenIDChangeWeapon)

    local countCustomCompanion = p:GetCountOfClass(self.TokenIDCustomComp)
    local countRetrieve = p:GetCountOfClass(self.TokenIDReturn)
    local countHeal = p:GetCountOfClass(self.TokenIDHeal)
    local countStatus = p:GetCountOfClass(self.TokenIDStatus)
    local countCampMake = p:GetCountOfClass(self.TokenIDCampMake)
    local countCampBreak = p:GetCountOfClass(self.TokenIDCampBreak)
    local countQuartermasterTest = p:GetCountOfClass(self.TokenIDQuartermasterTest)

    local countSpawnRenegadeWeak = p:GetCountOfClass(self.TokenIDSpawnRenegadeWeak)
    local countSpawnRenegadeMedium = p:GetCountOfClass(self.TokenIDSpawnRenegadeMedium)
    local countSpawnRenegadeStrong = p:GetCountOfClass(self.TokenIDSpawnRenegadeStrong)

    -- 1. Process State Commands
    if countDismiss and countDismiss > 0 then
        System.LogAlways("[Mercenaries] Dismiss Token detected!")
        p:DeleteItemOfClass(self.TokenIDDismiss, countDismiss)
        self:SetState("dismiss") 
    end

    if countWait and countWait > 0 then
        System.LogAlways("[Mercenaries] Wait Token detected!")
        p:DeleteItemOfClass(self.TokenIDWait, countWait)
        self:SetState("wait") 
    end

    if countFollow and countFollow > 0 then
        System.LogAlways("[Mercenaries] Follow Token detected!")
        p:DeleteItemOfClass(self.TokenIDFollow, countFollow)
        self:SetState("follow") 
    end

    -- 2. Process Hire Commands
    if countWeak and countWeak > 0 then
        p:DeleteItemOfClass(self.TokenIDWeak, countWeak)
        self:Hire(50 * countWeak, countWeak, "weak") 
    end

    if countMedium and countMedium > 0 then
        p:DeleteItemOfClass(self.TokenIDMedium, countMedium)
        self:Hire(100 * countMedium, countMedium, "medium") 
    end

    if countStrong and countStrong > 0 then
        p:DeleteItemOfClass(self.TokenIDStrong, countStrong)
        self:Hire(300 * countStrong, countStrong, "strong") 
    end

    -- 3. Process Clothing Tokens
    if countChangeOutfit and countChangeOutfit > 0 then
        p:DeleteItemOfClass(self.TokenIDChangeOutfit, countChangeOutfit)
        -- Pass the count to the function (e.g. 2 tokens = Bandits)
        self:ChangeMercOutfit(countChangeOutfit, false)
    end

    -- 3b. Process Weapon Loadout Tokens
    if countChangeWeapon and countChangeWeapon > 0 then
        p:DeleteItemOfClass(self.TokenIDChangeWeapon, countChangeWeapon)
        -- Pass the count to the function (e.g. 4 tokens = Longsword)
        self:ChangeMercWeapon(countChangeWeapon, false)
    end

    if countCustomCompanion and countCustomCompanion > 0 then
        p:DeleteItemOfClass(self.TokenIDCustomComp, countCustomCompanion)
        self:HireCustomCompanion(countCustomCompanion) 
    end

    if countRetrieve and countRetrieve > 0 then
        p:DeleteItemOfClass(self.TokenIDReturn, countRetrieve)

        self:SetState("follow")
        Game.SendInfoText('merc_info_returning', false, 0, 3)
    end

    -- heal & wash the whole squad for a flat fee
    if countHeal and countHeal > 0 then
        p:DeleteItemOfClass(self.TokenIDHeal, countHeal)
        self:HealMercsForFlatFee()
    end

    -- squad status report chosen via dialogue
    if countStatus and countStatus > 0 then
        p:DeleteItemOfClass(self.TokenIDStatus, countStatus)
        self:ShowSquadStatus()
    end

    -- camp make/break chosen via dialogue
    if countCampMake and countCampMake > 0 then
        p:DeleteItemOfClass(self.TokenIDCampMake, countCampMake)
        self:SpawnMercCamp()
    end

    if countCampBreak and countCampBreak > 0 then
        p:DeleteItemOfClass(self.TokenIDCampBreak, countCampBreak)
        self:BreakMercCamp()
    end

    -- quartermaster placeholder test dialog
    if countQuartermasterTest and countQuartermasterTest > 0 then
        p:DeleteItemOfClass(self.TokenIDQuartermasterTest, countQuartermasterTest)
        self:QuartermasterTest()
    end

    -- quartermaster logistics actions
    -- The count is passed on: most handlers ignore it, the count-as-selector menus
    -- (LogiRemoveUpgrade, CampSetComposition) read it as "which option was picked".
    local function tok(id, fn)
        local c = p:GetCountOfClass(id)
        if c and c > 0 then
            p:DeleteItemOfClass(id, c)
            fn(c)
        end
    end
    tok(self.TokenIDQMDeliverFood,   function() self:LogiDeliverFood() end)
    tok(self.TokenIDQMDeliverDrink,  function() self:LogiDeliverDrink() end)
    tok(self.TokenIDQMBuyFood,       function() self:LogiBuyFood() end)
    tok(self.TokenIDQMAskStats,      function() self:LogiAskStats() end)
    tok(self.TokenIDQMAskFood,       function() self:LogiAskFood() end)
    tok(self.TokenIDQMAskDrink,      function() self:LogiAskDrink() end)
    tok(self.TokenIDQMDeposit,       function() self:LogiDepositCoffer() end)
    tok(self.TokenIDQMWithholdWages, function() self:LogiToggleWithholdWages() end)
    tok(self.TokenIDQMWithdraw,      function() self:LogiWithdrawCoffer() end)
    tok(self.TokenIDQMCart,          function() self:LogiBuyFoodCart() end)
    tok(self.TokenIDQMInn,           function() self:LogiBuyInn() end)
    tok(self.TokenIDQMHunter,        function() self:LogiBuyHunter() end)
    tok(self.TokenIDQMSmithy,        function() self:LogiBuySmithy() end)
    tok(self.TokenIDQMAlchemy,       function() self:LogiBuyAlchemy() end)
    tok(self.TokenIDQMPractice,      function() self:LogiBuyPractice() end)
    tok(self.TokenIDQMHouse,         function() self:LogiBuyHouse() end)
    tok(self.TokenIDQMTower,         function() self:LogiBuyTower() end)
    tok(self.TokenIDQMArcherCart,    function() self:LogiBuyArcherCart() end)
    tok(self.TokenIDQMRemoveUpg,     function() self:LogiRemoveAllUpgrades() end)
    tok(self.TokenIDQMRemoveOne,     function(n) self:LogiRemoveUpgrade(n) end)
    tok(self.TokenIDQMComposition,   function(n) self:CampSetComposition(n) end)
    tok(self.TokenIDQMWall,          function() self:LogiBuyWall() end)
    tok(self.TokenIDQMGate,          function() self:LogiBuyGate() end)
    tok(self.TokenIDQMGates,         function() self:LogiToggleGates() end)
    tok(self.TokenIDBanditCamp,      function() self:BanditCampAccept() end)
    tok(self.TokenIDBanditCampHandIn, function() self:BanditCampDeliverLetter() end)
    tok(self.TokenIDBountyAccept,     function() self:BountyAccept() end)
    tok(self.TokenIDBountyHandIn,     function() self:BountyReport() end)

    -- Aleksej of Zaslawye: the Skald->Lua half. The quest graph drops one of these when a beat
    -- opens AND again on every level wake while that beat is still live and unfinished
    -- (exec_alx_spawn_N / alx_wake_N), which is how a camp comes back after a load without being
    -- save data. Everything about the PROGRESSION is Skald's; this only stands the camp up.
    for n, cls in pairs(self.AlxSpawnToken or {}) do
        tok(cls, function() self:AlxSpawnBeat(n) end)
    end
    tok(self.TokenIDAlxLodgingGone, function()
        if not self.AlxLodgingGone then self:AlxLodgingRemove() end
    end)
    tok(self.TokenIDQMTakeAll,       function() self:CampTakeParty(1.0) end)
    tok(self.TokenIDQMTakeThreeQtr,  function() self:CampTakeParty(0.75) end)
    tok(self.TokenIDQMTakeHalf,      function() self:CampTakeParty(0.5) end)
    tok(self.TokenIDQMTakeThird,     function() self:CampTakeParty(0.3333) end)
    tok(self.TokenIDQMTakeQuarter,   function() self:CampTakeParty(0.25) end)

    -- Custom-uniform panel result: like the food panel, the token is only a "a
    -- delivery happened" signal - what was handed over is read off the
    -- quartermaster's inventory.
    tok(self.TokenIDGearOpened, function() self:GearOpenWardrobe() end)

    -- Food-delivery panel result: the token COUNT is the delivered food amount,
    -- so this one is handled specially (passes the count through).
    local cFoodPanel = p:GetCountOfClass(self.TokenIDQMFoodPanel)
    if cFoodPanel and cFoodPanel > 0 then
        p:DeleteItemOfClass(self.TokenIDQMFoodPanel, cFoodPanel)
        self:LogiPanelFood(cFoodPanel)
    end

    -- Drink-delivery panel result: same deal, the token COUNT is the amount.
    local cDrinkPanel = p:GetCountOfClass(self.TokenIDQMDrinkPanel)
    if cDrinkPanel and cDrinkPanel > 0 then
        p:DeleteItemOfClass(self.TokenIDQMDrinkPanel, cDrinkPanel)
        self:LogiPanelDrink(cDrinkPanel)
    end

    -- Renegade spawn requests chosen via dialogue. Count on the token is
    -- how many to spawn; equipment is whatever the squad's current
    -- outfit/weapon preset is (SpawnRenegade defaults to those when nil).
    if countSpawnRenegadeWeak and countSpawnRenegadeWeak > 0 then
        p:DeleteItemOfClass(self.TokenIDSpawnRenegadeWeak, countSpawnRenegadeWeak)
        self:SpawnRenegade(countSpawnRenegadeWeak, nil, "weak", nil)
    end

    if countSpawnRenegadeMedium and countSpawnRenegadeMedium > 0 then
        p:DeleteItemOfClass(self.TokenIDSpawnRenegadeMedium, countSpawnRenegadeMedium)
        self:SpawnRenegade(countSpawnRenegadeMedium, nil, "medium", nil)
    end

    if countSpawnRenegadeStrong and countSpawnRenegadeStrong > 0 then
        p:DeleteItemOfClass(self.TokenIDSpawnRenegadeStrong, countSpawnRenegadeStrong)
        self:SpawnRenegade(countSpawnRenegadeStrong, nil, "strong", nil)
    end

    -- Archer (ranged merc) hire / stance / AI-variant tokens
    self:MonitorArcherTokens(p)

    -- Formation shape chosen from dialogue or the order wheel
    self:MonitorFormationTokens(p)

    -- Engagement stance, aggression preset and called targets
    self:MonitorOrderTokens(p)
    self:MonitorHoldTokens(p)

    -- How hard the quartermaster lets the fighting get
    self:MonitorDifficultyTokens(p)

end

-- Slot body: work only. The scheduler calls this; MonitorLoop below is the
-- legacy self-arming path used when merc_sched is off. See docs/performance.md.
function mercenaries:MonitorLoopBody()

    if player and player.inventory then
        mercenaries:ProfCall("mon.MonitorInventory", "MonitorInventory")
    end
    mercenaries:ProfCall("mon.MainQuestLoop", "MonitorMainQuestLoop")

    -- What the crosshair is on, remembered so an order fired a second later still
    -- knows what the player meant; plus the staggered bark queue and the one-shot
    -- shout when the squad first notices a fight.
    mercenaries:ProfCall("mon.OrderLookTick", "OrderLookTick")
    mercenaries:ProfCall("mon.OrderBarkDrain", "OrderBarkDrain")

    -- Torches at night, camp or no camp: a company on a road after dark carries
    -- light too. The camp's own lamps stay on the camp tick.
    mercenaries:ProfCall("mon.NightTorches", "CampNightTorchTick")

    if next(mercenaries.ActiveMercs) then
        -- One shared "fell too far behind" pass over the whole squad instead
        -- of every merc's behavior tree running its own raycast sweep.
        mercenaries:ProfCall("mon.DistanceAndTeleport", "MonitorDistanceAndTeleport")

        -- Delayed "return to camp" teleports (mercs bark + jog first).
        mercenaries:ProfCall("mon.ProcessReturnPending", "ProcessReturnPending")
    end

    -- Tower archers stand off the navmesh, and the AI ground-snaps its actors, so
    -- one that has been knocked/snapped down gets put back. Runs regardless of
    -- ActiveMercs - static archers are not squad members. See KeepStaticArchersUp.
    mercenaries:ProfCall("mon.KeepStaticArchersUp", "KeepStaticArchersUp")

    -- Ambush trigger boxes. Independent of ActiveMercs - an ambush can catch a
    -- player travelling alone. See docs/encounters.md.
    mercenaries:ProfCall("mon.AmbushMonitor", "AmbushMonitor")

    -- Sleeping in the camp bed saves the game (see docs/camp.md "The player tent").
    mercenaries:ProfCall("mon.CampBedSleepWatch", "CampBedSleepWatch")

    -- The bandit-camp contract: kill tracking, payout, and building/unloading the camp
    -- as the player comes and goes. See docs/bandit-camp-quest.md.
    mercenaries:ProfCall("mon.BanditCampMonitor", "BanditCampMonitor")

    -- The siege of Raborsch: watches for the player closing on it. See docs/raborsch.md.
    mercenaries:ProfCall("mon.RaborschMonitor", "RaborschMonitor")

    -- The pre-combat speech test NPC (docs/aleksej.md).
    mercenaries:ProfCall("mon.AlxTalkTick", "AlxTalkTick")
    mercenaries:ProfCall("mon.AlxLodgingTick", "AlxLodgingTick")
end

function mercenaries.MonitorLoop()
    mercenaries:MonitorLoopBody()
    if not mercenaries.SchedRunning then
        Script.SetTimerForFunction(1000, "mercenaries.MonitorLoop")
    end
end

-- Enemy detection runs on its own faster tick: it is the squad's reaction time
-- to a threat, and the merc behaviour trees only see what this leaves behind in
-- CachedEnemies. Aggro applies whether the squad is following, waiting or
-- camped, so the cache is kept fresh regardless of idle state.
-- PERFORMANCE: skipped entirely when there's no squad to act on it - nothing
-- reads CachedEnemies if ActiveMercs is empty.
function mercenaries:CombatScanLoopBody()
    -- Outside the ActiveMercs gate: it only reads a global and a clock, and it
    -- must see the dismount edge even on a tick where the roster is momentarily
    -- empty. See DismountWatch.
    mercenaries:ProfCall("cmb.DismountWatch", "DismountWatch")
    -- Player speed, smoothed. Read by the mounted leader so he can match it.
    mercenaries:ProfCall("cmb.UpdatePlayerSpeed", "UpdatePlayerSpeed")

    if next(mercenaries.ActiveMercs) then
        -- One NPC box query for this whole pass. UpdateEnemyCache and any other
        -- consumer slice it by radius instead of running their own. It reads last
        -- pass's EnemyAlerted to size itself; on the tick the alert first rises the
        -- slice is too narrow, PerfNpcsNear returns nil and the consumer falls back
        -- to its own query. See docs/performance.md.
        mercenaries:ProfCall("cmb.PerfScanNpcs", "PerfScanNpcs")
        mercenaries:ProfCall("cmb.UpdateEnemyCache", "UpdateEnemyCache")
        -- One squad-wide "is there a fight" flag, off the cache this pass just built.
        -- Mounted mercs poll it to break out of their riding block early; doing that
        -- per merc would be a target scan each, several times a second, per rider.
        mercenaries:ProfCall("cmb.UpdateSquadThreat", "UpdateSquadThreat")
        -- ...and the tighter, latched version of it that decides whether riders get
        -- down and fight on foot. See UpdateDismountThreat.
        mercenaries:ProfCall("cmb.UpdateDismountThreat", "UpdateDismountThreat")
    else
        mercenaries.CachedEnemies = {}
        _G.MercSquadThreat = false
        _G.MercDismountThreat = false
    end

    -- Outside the ActiveMercs gate: a battle can be under way with the squad wiped or in
    -- camp, and the boost must still come back down afterwards.
    mercenaries:ProfCall("cmb.LodBoostTick", "LodBoostTick")

    -- Drives the scheduler's 300ms -> 600ms backoff. Re-evaluated every master tick,
    -- never latched, so a squad going alert is picked up on the very next tick.
    if self.SchedMarkIdle then
        self:SchedMarkIdle("combatscan",
            not (self.EnemyAlerted or next(self.CachedEnemies or {}) ~= nil))
    end
end

function mercenaries.CombatScanLoop()
    mercenaries:CombatScanLoopBody()
    if not mercenaries.SchedRunning then
        Script.SetTimerForFunction(300, "mercenaries.CombatScanLoop")
    end
end

function mercenaries:LowPriorityMonitorLoopBody()
    -- The company list, kept current for the load-time rebuild (mercenaries_roster.lua).
    if mercenaries.RosterKeepTick then pcall(function() mercenaries:RosterKeepTick() end) end
    if next(mercenaries.ActiveMercs) then
        -- Pruning matters even while idle now that aggro applies at rest.
        mercenaries:ProfCall("low.PruneMercCache", "PruneMercCache")

        if not _G.MercIdle then
            mercenaries:ProfCall("low.UpdateFormationSlots", "UpdateFormationSlots")
        end

        -- Archers that emptied their quiver in a fight refill once it's over.
        mercenaries:ProfCall("low.ResupplyArchers", "ResupplyArchersOutOfCombat")
    end

    -- Static (tower) archers are not in ActiveMercs, so they resupply outside the
    -- block above - they never walk anywhere to restock.
    mercenaries:ProfCall("low.ResupplyStaticArchers", "ResupplyStaticArchers")

    -- Outside the ActiveMercs gate on purpose: ambushes and roaming patrols hold
    -- combat claims with no merc anywhere near.
    mercenaries:ProfCall("low.PruneCombatClaims", "PruneCombatClaims")

    -- Re-pin renderer view distance; anything that rebuilds an entity can drop it.
    mercenaries:ProfCall("low.RefreshRenderPins", "RefreshRenderPins")

    -- Three cvar READS. Writes nothing unless a level context has stomped the shipped
    -- simulation defaults; see PerfDefaultsVerify for why this is not on a fast tick.
    mercenaries:ProfCall("low.PerfDefaultsVerify", "PerfDefaultsVerify")

    -- Roaming patrols run on their own timer; re-arm it if it has died (level change).
    mercenaries:ProfCall("low.LivePatrolWatchdog", "LivePatrolWatchdog")

    -- Camp patrol tick runs regardless of ActiveMercs being empty, since a
    -- camp can (briefly) outlive its squad's cache entry.
    mercenaries:ProfCall("low.MonitorCamp", "MonitorCamp")

    -- Quartermaster logistics: tiredness / food / drink / wages upkeep.
    mercenaries:ProfCall("low.LogiTick", "LogiTick")

    -- The camp's defences: put the layout back if its restore timer died with a level
    -- change, and re-hang any gate whose prop has been swept out from under its record.
    mercenaries:ProfCall("low.DefWatchdog", "DefWatchdog")
    mercenaries:ProfCall("low.GateWatchdog", "GateWatchdog")
end

function mercenaries.LowPriorityMonitorLoop()
    mercenaries:LowPriorityMonitorLoopBody()
    if not mercenaries.SchedRunning then
        Script.SetTimerForFunction(5000, "mercenaries.LowPriorityMonitorLoop")
    end
end

-- Mod Initialization
function mercenaries:OnGameplayStarted(actionName, eventName, argTable)
    System.LogAlways("[Mercenaries] Game loaded! Starting the inventory monitor loop...")

    -- FIRST, before anything arms a timer: every Script.SetTimerForFunction chain died
    -- with the level we just left, so the latches guarding them have to be cleared or
    -- they lock the timers out for the rest of the session. See SchedOnLoad.
    if self.SchedOnLoad then self:SchedOnLoad() end
    if self.MQWOnLoad then pcall(function() self:MQWOnLoad() end) end
    if self.RosterOnGameplayLoad then pcall(function() self:RosterOnGameplayLoad() end) end
    if self.TravelWatchOnLoad then pcall(function() self:TravelWatchOnLoad() end) end

    -- ...and the same asymmetry one level up. Timers are not the only thing that dies with
    -- the level: so do the behaviour trees, the spawned entities and the siege. What does
    -- NOT die is every plain Lua table describing them, and three of those decide how wide
    -- the mod's hot loops sweep - the combat claims that hold EnemyAlerted open, the siege's
    -- 160m alert radius and SiegePeace, and the pinned global LOD cvars. Left over, they
    -- make a fresh load pay a battle's costs with no battle on. Each module releases its own
    -- and every one of them is re-established from the live world within a tick if it is
    -- genuinely still warranted. See docs/performance.md.
    if self.RaborschOnLoad  then pcall(function() self:RaborschOnLoad()  end) end
    if self.TargetingOnLoad then pcall(function() self:TargetingOnLoad() end) end
    if self.LodBoostOnLoad  then pcall(function() self:LodBoostOnLoad()  end) end
    -- The bench's timer chain died with the level; the latch must not outlive it.
    self.BenchRunning, self._benchState = false, nil
    -- Once per load: mod.cfg applies these at LAUNCH, but a level load re-applies that
    -- level's own cvar context on top. One pass here, then PerfDefaultsVerify only reads.
    if self.PerfDefaultsApply then pcall(function() self:PerfDefaultsApply() end) end
    if self.CrimeWatchOnLoad then pcall(function() self:CrimeWatchOnLoad() end) end
    if self.TownWatchOnLoad  then pcall(function() self:TownWatchOnLoad()  end) end
    if self.FollowWatchOnLoad then pcall(function() self:FollowWatchOnLoad() end) end

    -- Saver entities belong to the save just loaded, so the tag map must be rebuilt
    -- before the LoadString calls below read from it.
    if self.SaverForget then self:SaverForget() end

    -- Hook Player.OnAction (mouse input for tower placement). Delayed so that a mod
    -- which replaced the callback without chaining cannot lock us out - the same
    -- reasoning as references/CompanionMerchant. See mercenaries_tower.lua.
    Script.SetTimerForFunction(1000, "mercenaries.UpdateOnAction")

    -- Load IDLE State
    local savedIdle = mercenaries:LoadString("MercIdlePersistent")
    if savedIdle == "1" then
        _G.MercIdle = true
        _G.MercPersistentIdleFlag = true
    else
        _G.MercIdle = false
        _G.MercPersistentIdleFlag = false
    end

    -- Load DISMISSED State
    local savedDismissed = mercenaries:LoadString("MercenariesDismissed")
    if savedDismissed == "1" then
        _G.MercenariesDismissed = true
    else
        _G.MercenariesDismissed = false 
    end
    
    -- Load the CUSTOM UNIFORM before the outfit, or a squad saved wearing it
    -- re-dresses out of an empty pattern.
    self:GearLoadState()

    -- Load OUTFIT State
    local savedOutfit = mercenaries:LoadString("MercOutfitPersistent")
    if savedOutfit and tonumber(savedOutfit) and tonumber(savedOutfit) > 0 then
        _G.MercCurrentOutfit = tonumber(savedOutfit)
        self:ChangeMercOutfit(_G.MercCurrentOutfit, true)
    else
        _G.MercCurrentOutfit = 1
    end

    -- Load WEAPON LOADOUT State
    local savedWeapon = mercenaries:LoadString("MercWeaponPersistent")
    if savedWeapon and tonumber(savedWeapon) and tonumber(savedWeapon) > 0 then
        _G.MercCurrentWeapon = tonumber(savedWeapon)
        self:ChangeMercWeapon(_G.MercCurrentWeapon, true)
    else
        _G.MercCurrentWeapon = 1
    end

    -- Load archer stance + skirmish AI variant
    self:LoadArcherState()

    -- Engagement stance and anti-swarm preset. Hold/escort are deliberately NOT
    -- restored: they are anchored to a spot in the world the player picked, and a
    -- squad that reloads still planted on ground he has since left reads as a bug.
    self:LoadOrderState()
    self.HoldActive, self.HoldStations, self.EscortEnt = false, {}, nil

    -- Company survival mode: this also rescales the consumption and spoils rates, so
    -- it has to run before the first logistics tick.
    self:UpkeepLoad()

    -- Camp props are runtime-spawned and don't survive a save, so sweep any that
    -- lingered. The camp itself IS persistent: only its anchor is saved, and
    -- RestoreCampDelayed below rebuilds it there once the merc cache exists.
    self:ClearAnyLeftoverCamp()

    -- Load the quartermaster logistics state (tiredness / food / drink / wages).
    self:LogiLoad()

    -- NO F-KEY IS EVER BOUND. The mod used to bind F4 (recall) plus the bench/torture
    -- triggers on F6-F10, and players kept firing test campaigns - some of which QUIT
    -- the game - by accident. Recall is the console command merc_camp_recall (players
    -- can bind it themselves: bind <key> merc_camp_recall). The test harness re-binds
    -- its keys through merc_bench_bindkeys / merc_torture_bindkeys, which exist only
    -- after merc_dev - and merc_dev itself refuses outside a -devmode launch.

    -- F5-F11 ARE NOT BOUND. Four in-game editors want them - the bandit camp builder
    -- (docs/bandit-camps.md), the siege builder, the Aleksej lodging editor and the patrol
    -- route recorder - and every one of their binders is commented out in its own module, so
    -- the F-keys stay free for the game. Every merc_bcamp_* / merc_siege_* / merc_alx_* /
    -- merc_route_* command still works from the console. To re-enable ONE editor: uncomment
    -- its binder body, then uncomment the matching call below.
    -- pcall(function() mercenaries:AlxBinds(true) end)
    pcall(function() mercenaries:RouteLoad() end)
    -- Roaming patrols do not survive a save: sweep anything the engine serialised before the
    -- tick re-rolls fresh records. See mercenaries_patrols_live.lua.
    pcall(function() mercenaries:ClearAnyLeftoverPatrols() end)
    pcall(function() mercenaries:LivePatrolStart() end)
    -- A bandit-camp contract in progress. Only the CONTRACT is restored here; the camp
    -- itself is rebuilt by the monitor once the player is near it again.
    pcall(function() mercenaries:BanditCampRestore() end)
    -- Aleksej's camp is NOT save data and nothing here restores it: this drops whatever the last
    -- session left standing. The quest re-issues that beat's spawn token on the level's own
    -- OnWake if it is still live, and MonitorInventory stands the camp back up - no distance gate
    -- anywhere in that path. See docs/aleksej.md.
    pcall(function() mercenaries:AlxOnLoad() end)
    -- ...and then drop everything this session cached in memory rather than saved, so the
    -- quartermaster's dialog, the arc position and the marching column are all re-derived
    -- from the save that was actually loaded. Runs whether or not a contract was in progress.
    pcall(function() mercenaries:BanditCampResync() end)

    self:ReleaseSpeakingLock()

    _G.PlayerMounted = false

    -- Drop every shared cache: entity handles, positions and the patrol index all
    -- refer to the previous session. See docs/performance.md.
    if self.PerfReset then self:PerfReset() end

    -- Wrap the BT hooks and the remaining timers with timing. Done here, not at load:
    -- the profiler loads first and the functions it wraps do not exist yet at that point.
    if self.ProfEnabled and self.ProfInstrumentAll then
        pcall(function() self:ProfInstrumentAll() end)
    end
    -- Armed regardless of the SCHEDULER (a stalled or disabled master tick is exactly when
    -- an independent observer is needed), but not when profiling is off - there is nothing
    -- for it to observe, and `self.ProfHeartbeat` is a function reference, so the old
    -- condition was always true and left a 4Hz no-op timer running every session.
    -- merc_prof 1 arms it (see ProfSet).
    if self.ProfEnabled and self.ProfHeartbeat and not self._profHbArmed then
        self._profHbArmed = true
        Script.SetTimerForFunction(self.ProfHeartbeatMs or 250, "mercenaries.ProfHeartbeat")
    end

    -- Rebuild the merc cache: the one permitted full-world NPC scan, on load only.
    Script.SetTimerForFunction(2000, "mercenaries.RebuildMercCacheDelayed")
    -- Put a saved camp back up - after the cache above, since it hands out tents
    -- from ActiveMercs (see RestoreCampDelayed). The retry counter is per-load
    -- state and plain Lua, so it is reset here rather than trusted.
    self._campRestoreTries = 0
    Script.SetTimerForFunction(4000, "mercenaries.RestoreCampDelayed")
    -- NO torture hook here. Phase B once armed itself from this event and auto-quit
    -- the USER'S game whenever their newest save carried a torture stamp (they hit
    -- Continue, phase B ran, the game closed - reported as "the mod keeps crashing").
    -- Phase B now runs only from an explicit merc_torture command on a stamped save
    -- (mercenaries_torture.lua) - and those commands exist only after merc_dev.
    -- One master tick drives these four instead of four independent timers, so they
    -- are phase-offset, gated and backed off when idle. merc_sched 0 restores the
    -- legacy timers at the next load. See docs/performance.md.
    if self.SchedEnabled and self.SchedRegisterAll then
        self:SchedRegisterAll()
        self:SchedStart()
    elseif self.SchedArmLegacy then
        self:SchedArmLegacy()
    else
        Script.SetTimerForFunction(1000, "mercenaries.MonitorLoop")
        Script.SetTimerForFunction(300,  "mercenaries.CombatScanLoop")
        Script.SetTimerForFunction(5000, "mercenaries.LowPriorityMonitorLoop")
        Script.SetTimerForFunction(mercenaries.FormationTickMs, "mercenaries.FormationLoop")
    end
    -- Post-battle loot sweep. Own tick: it must keep watching CachedEnemies drain
    -- even with no squad orders pending. See docs/loot-sweep.md.
    -- One chain per load, and the previous load's chain retires itself. It used to be armed
    -- here unconditionally and re-arm itself unconditionally - the only loop in the mod with
    -- no guard at either end. See the note above LootSweepArm.
    pcall(function() mercenaries:LootSweepArm() end)
    -- Scheduled raids on the camp. Safe to arm with no camp: the tick does nothing
    -- until one is pitched and the player is standing in it.
    pcall(function() mercenaries:RaidStart() end)

end

-- Register the other scripts (most are also referenced from the AI behaviour trees).
-- FIRST, because every module registers its console commands through it as it loads.
Script.LoadScript("Scripts/mods/mercenaries_commands.lua")
Script.LoadScript("Scripts/mods/mercenaries_profiler.lua")
Script.LoadScript("Scripts/mods/mercenaries_perf.lua")
Script.LoadScript("Scripts/mods/mercenaries_spawning.lua")
-- Before every system that fields hostiles (raids, patrols, bounty/Kleinkrieg):
-- they all read the tier at runtime, but it should exist by the time they load.
Script.LoadScript("Scripts/mods/mercenaries_difficulty.lua")
Script.LoadScript("Scripts/mods/mercenaries_ai_modules.lua")
Script.LoadScript("Scripts/mods/mercenaries_equipment.lua")
Script.LoadScript("Scripts/mods/mercenaries_gear_data.lua")
Script.LoadScript("Scripts/mods/mercenaries_custom_gear.lua")
-- Generated from data/libs/tables/item/item__mercenaries.xml (tools/gen_item_ids.py):
-- every item class the mod defines, for the inventory audit and the uninstall purge.
-- Pure data, so it loads before anything that might want it.
Script.LoadScript("Scripts/mods/mercenaries_item_ids.lua")
-- Generated from data/libs/tables/rpg/buff__mercenaries.xml (tools/gen_buff_ids.py):
-- every buff the mod defines, for merc_purge_buffs and the save audit.
Script.LoadScript("Scripts/mods/mercenaries_buff_ids.lua")
Script.LoadScript("Scripts/mods/mercenaries_util.lua")
Script.LoadScript("Scripts/mods/mercenaries_management.lua")
Script.LoadScript("Scripts/mods/mercenaries_target_selection.lua")
Script.LoadScript("Scripts/mods/mercenaries_teleport.lua")
-- Squad combat orders (engagement stance, aggression, called targets) and the two
-- standing orders that put the men somewhere specific. See docs/squad-orders.md.
Script.LoadScript("Scripts/mods/mercenaries_orders.lua")
Script.LoadScript("Scripts/mods/mercenaries_hold.lua")
Script.LoadScript("Scripts/mods/mercenaries_formation_handler.lua")
Script.LoadScript("Scripts/mods/mercenaries_formation.lua")
Script.LoadScript("Scripts/mods/mercenaries_main_quest_handler.lua")
-- Recognises "we are inside a scripted main-quest battle" (the coming merc/patrol
-- temp-despawn hangs off its hooks). Ticked from MonitorMainQuestLoop.
Script.LoadScript("Scripts/mods/mercenaries_mainquest_watchdog.lua")
Script.LoadScript("Scripts/mods/mercenaries_saving.lua")
Script.LoadScript("Scripts/mods/mercenaries_lookatinteraction.lua")
Script.LoadScript("Scripts/mods/mercenaries_archers.lua")
Script.LoadScript("Scripts/mods/mercenaries_camp.lua")
Script.LoadScript("Scripts/mods/mercenaries_forge.lua")
Script.LoadScript("Scripts/mods/mercenaries_alchemy.lua")
Script.LoadScript("Scripts/mods/mercenaries_hunting.lua")
Script.LoadScript("Scripts/mods/mercenaries_inn.lua")
Script.LoadScript("Scripts/mods/mercenaries_foodcart.lua")
Script.LoadScript("Scripts/mods/mercenaries_house.lua")
Script.LoadScript("Scripts/mods/mercenaries_tower.lua")
Script.LoadScript("Scripts/mods/mercenaries_static_archer.lua")
Script.LoadScript("Scripts/mods/mercenaries_archer_cart.lua")
Script.LoadScript("Scripts/mods/mercenaries_wall.lua")
Script.LoadScript("Scripts/mods/mercenaries_gate.lua")
Script.LoadScript("Scripts/mods/mercenaries_navmesh.lua")
Script.LoadScript("Scripts/mods/mercenaries_defences.lua")
Script.LoadScript("Scripts/mods/mercenaries_wallbattle.lua")
Script.LoadScript("Scripts/mods/mercenaries_raids.lua")
Script.LoadScript("Scripts/mods/mercenaries_patrol.lua")
Script.LoadScript("Scripts/mods/mercenaries_routes.lua")
Script.LoadScript("Scripts/mods/mercenaries_patrol_routes.lua")
Script.LoadScript("Scripts/mods/mercenaries_patrol_routes_trosky.lua")
Script.LoadScript("Scripts/mods/mercenaries_patrols_live.lua")
Script.LoadScript("Scripts/mods/mercenaries_ambush_road.lua")
Script.LoadScript("Scripts/mods/mercenaries_testnpc.lua")
Script.LoadScript("Scripts/mods/mercenaries_weapon_audit.lua")
Script.LoadScript("Scripts/mods/mercenaries_companion_lineup.lua")
-- The rewritten hostile AI (idle until alerted, then everyone engages). Own brain,
-- souls, faction and trees - shares nothing with the enemy groups. See docs/foe-ai.md.
Script.LoadScript("Scripts/mods/mercenaries_foe.lua")
Script.LoadScript("Scripts/mods/mercenaries_ambush.lua")
Script.LoadScript("Scripts/mods/mercenaries_ambush_scenes.lua")
Script.LoadScript("Scripts/mods/mercenaries_camp_debug.lua")
Script.LoadScript("Scripts/mods/mercenaries_upgrade_preview.lua")
Script.LoadScript("Scripts/mods/mercenaries_quartermaster.lua")
Script.LoadScript("Scripts/mods/mercenaries_logistics.lua")
Script.LoadScript("Scripts/mods/mercenaries_lootsweep.lua")
-- Watch-only: who the company kills in a settlement, and how the town feels about the
-- player. Reads the combat tables the modules above fill in, so it loads after them.
Script.LoadScript("Scripts/mods/mercenaries_crimewatch.lua")
-- After it: the watchdog hands every attributed kill to TownWatchNoteKill.
Script.LoadScript("Scripts/mods/mercenaries_townwatch.lua")
Script.LoadScript("Scripts/mods/mercenaries_hide_others.lua")
Script.LoadScript("Scripts/mods/mercenaries_lodboost.lua")
Script.LoadScript("Scripts/mods/mercenaries_banditcamp.lua")
Script.LoadScript("Scripts/mods/mercenaries_banditcamp_quest.lua")
-- After the contract machinery: the bounty rides its camp slots and its leader soul is
-- pinned onto BCQ_BO at load.
Script.LoadScript("Scripts/mods/mercenaries_bounty.lua")
-- After the camp builder: its catalogue is reused for the siege editor's props page.
Script.LoadScript("Scripts/mods/mercenaries_siege.lua")
-- After the siege builder: the siege replay resolves its pieces against that catalogue.
Script.LoadScript("Scripts/mods/mercenaries_raborsch.lua")
Script.LoadScript("Scripts/mods/mercenaries_aleksej.lua")
-- Last: every slot body it registers must already be defined.
Script.LoadScript("Scripts/mods/mercenaries_roster.lua")
Script.LoadScript("Scripts/mods/mercenaries_travelwatch.lua")
Script.LoadScript("Scripts/mods/mercenaries_scheduler.lua")
Script.LoadScript("Scripts/mods/mercenaries_bench.lua")
Script.LoadScript("Scripts/mods/mercenaries_torture.lua")
-- Immediately after it: the quest plan reuses the torture framework's step machine, its
-- safety arming and its walk/log helpers, all of which the file above defines.
Script.LoadScript("Scripts/mods/mercenaries_torture_quest.lua")

-- Prints every merc console command with a one-line description.
function mercenaries:PrintHelp()
    local lines = {
        "===== Mercenaries mod commands =====",
        "The mod's SETTINGS live in the quartermaster's dialogue, under \"[Mod settings]\":",
        "  difficulty, random encounters, upkeep and the HUD icons. Everything below is the console equivalent.",
        "merc_status                          one-line squad report (count, health, orders, archer stance)",
        "merc_heal                            heal & wash the squad (flat " .. tostring(self.HealCost) .. " groschen)",
        "merc_wait / merc_follow / merc_dismiss   squad orders",
        "merc_camp_make / merc_camp_break     spawn/break a procedural camp for the squad",
        "merc_camp_recall                     bring the whole squad to you from anywhere (doesn't break camp)",
        "merc_camp_scan [radius] [spacing]    classify the ground around you (flag=valid, barrel=tree/rock, crate=building); merc_camp_scan_clear to remove",
        "merc_hold / merc_hold_end            hold this ground: every man stands fast where he is, with a leash (docs/squad-orders.md)",
        "merc_hold_formup 0|1                 hold shape: 1 draws them up in a block instead of standing fast",
        "merc_escort / merc_escort_end        escort whoever you are looking at, in column",
        "merc_focus / merc_focus_clear        call the target you are looking at (or locked onto) for the whole squad",
        "merc_engage_default|aggressive|defend|hold   rules of engagement",
        "merc_aggro_tight|balanced|loose      how hard they pile onto one enemy",
        "merc_orders_status / merc_hold_status        report the squad's combat and standing orders",
        "merc_difficulty easy|medium|difficult|extreme|impossible|horde   raid/patrol/contract difficulty (docs/difficulty.md)",
        "merc_difficulty_status               the tier and the ceilings it implies",
        "merc_autodismount 0|1                mercs get off their horses to fight",
        "merc_formation_column|line|square|wedge|circle|escort|vanilla   marching shape (see docs/formations.md)",
        "merc_formation_relaxed|keepshape|movehistory              how followers hold the shape",
        "merc_formation_relocate_on|off / merc_formation_status    crowding + diagnostics",
        "merc_formation_control / merc_follow_stats 1   is the squad REALLY in formation, or on the chain?",
        "merc_hire_w1/w2/w3, d1/d2/d3, p1/p2/p3   hire weak/medium/strong mercs (debug, free)",
        "merc_weapon_random|swordshield|axeshield|longsword|maceshield|shortsword|mace|axe|polearm   melee loadout",
        "archer_hire_1/3                     hire archers (debug, free)",
        "archer_stance_skirmish|melee|hold   archer combat stance (default: skirmish)",
        "archer_weapon_bow|crossbow|handcannon    archer ranged weapon type",
        "enemy_spawn_looters|bandits|sigi|prague|cumans|knights[_1|_20]   spawn an enemy group; base = row of 10 (debug)",
        "enemy_spawn_heinrich[_3]            spawn the overpowered Heinrich boss (debug)",
        "foe_spawn[_1|_20] / foe_spawn_scout  new hostile AI: unalerted foes that shout and all engage (docs/foe-ai.md)",
        "foe_status / foe_alert / foe_calm / foe_clear / foe_ranges   foe AI state, engage delays and tuning",
        "merc_banditcamp_start|status|abandon|clear   the quartermaster's bandit-camp contract (docs/bandit-camp-quest.md)",
        "merc_bounty_start|status|report|clear|abandon   the quartermaster's repeatable camp bounty (docs/bounty.md)",
        "merc_bcamp_site_here                 print a BanditCampSites row for where you stand",
        "merc_spawn_battle / merc_battle      spawn a full test battle (debug)",
        "merc_buff_list                       squad status HUD icons (auto-driven by logistics); merc_buff_all tests them, merc_buff_auto hands back",
        "merc_wpn_audit[_p1..p5|_enemy]       lineup with one NPC per weapon preset; _who names the one beside you, _report/_static list the broken ones (docs/weapon-audit.md)",
        "merc_cc_lineup[_p1..p4]              lineup with one NPC per custom companion; _who names the one beside you, _draw arms them, _clear despawns",
        "merc_cc_diag                        why a companion is not behaving like a merc: every gate, next to a regular merc as a control",
        "merc_recount                         re-sync the merc counter",
        "merc_face [clip]                     play a facial animation on the quartermaster (docs/lipsync.md)",
        "merc_lua <code>                      run raw Lua (debug)",
    }
    for _, line in ipairs(lines) do
        System.LogAlways(line)
    end
end

-- Lipsync diagnostics (docs/lipsync.md). No arg = generic talking clip.
mercenaries:DevCommand("merc_face", "mercenaries:FaceTest(\"%line\")", "Play a facial animation on the quartermaster (arg=clip name, default fa_cin_talk_neutral_01)")

mercenaries:DevCommand("merc_testmerc", "mercenaries:SpawnTestMerc()", "Control test: spawn ONE merc on the fixed test soul guid (free, no cap). See docs/quest-override-test.md")
mercenaries:DevCommand("merc_recount", "mercenaries:Recount()", "")

-- Player status buffs: cosmetic HUD/inventory indicators for the management layer.
-- One no-arg command per variant (merc_buff_1 .. merc_buff_9), each clearing the
-- others so only one is ever on screen. merc_buff_list prints the mapping.
-- The logistics tick normally drives these from the squad's real state. The
-- manual commands flip on a test-mode freeze so they aren't overwritten within
-- 5s; merc_buff_auto returns control to the system.
mercenaries:DevCommand("merc_buff_list", "mercenaries:ListPlayerStatusBuffs()", "Lists the player status buffs, their trigger conditions, and which are on.")
mercenaries:DevCommand("merc_buff_all", "mercenaries:ShowAllPlayerStatusBuffs()", "TEST: shows every player status buff at once (freezes the system until merc_buff_auto).")
mercenaries:DevCommand("merc_buff_off_all", "mercenaries:ClearPlayerStatusBuffs()", "Removes every player status buff.")
mercenaries:DevCommand("merc_buff_auto", "mercenaries:AutoPlayerStatusBuffs()", "Hands the status buffs back to the logistics system after testing.")
for i, def in ipairs(mercenaries.PlayerStatusBuffs) do
    mercenaries:DevCommand("merc_buff_" .. i, "mercenaries:OnlyPlayerStatusBuff(" .. i .. ")", "TEST: " .. def.name .. " (" .. def.note .. ")")
end

-- Usage in console: merc_save_string global_idle 1|true|105.5
mercenaries:DevCommand("merc_save_string", "mercenaries:SaveString('%1', '%2')", "Saves a string to a persistent entity. Usage: merc_save_string <tag> <data>")

-- Usage in console: merc_load_string global_idle
mercenaries:DevCommand("merc_load_string", "mercenaries:LoadString('%1')", "Retrieves the saved string from the persistent entity. Usage: merc_load_string <tag>")

-- Register the event listener
UIAction.RegisterEventSystemListener(mercenaries, "", "OnGameplayStarted", "OnGameplayStarted")
