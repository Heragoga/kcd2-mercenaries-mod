-- This is the main mod file, it handles two things: 
-- 1. Communication to skald via token items, if id detects one in the players inventory it calls the appropriate funcitons (i.e. spawn merc, heal merc etc)
-- 2. The mods main loop, that performc a few different scans
-- 3. Adding cheats, other scripts and loading configuration

mercenaries = {}

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

--Custom Companion Token
mercenaries.TokenIDCustomComp = "679a655e-189d-4519-b437-ccc4b92be48d"

--retrieve mercs token
mercenaries.TokenIDReturn = "679a655e-189d-4519-b437-ccc4b92be49d"
--heal mercs token
mercenaries.TokenIDHeal = "679a655e-189d-4519-b437-ccc4b92be50d"

mercenaries.MaxCompanions = 999

mercenaries.TargetDetectionRadius = 50

mercenaries.IsHiddenForCutscene = false
mercenaries.timersStarted = false

-- =======================================================================
-- PERFORMANCE: Centralized caches — rebuilt/pruned once per second
-- instead of scanning all world entities on every hot-path call.
-- =======================================================================
mercenaries.ActiveMercs   = {}  -- [entityName] = entity ref; pruned each tick
mercenaries.CachedEnemies = {}  -- [{entity, wuid}] valid hostile enemies near player
mercenaries.FormationSlots = {} -- [tostring(wuid)] = {slot, followTarget, totalMercs}


-- Soul dictionaries for different faces (only includes the generic mercs)
mercenaries.Souls = {
    weak = {
        "a1b2c3d4-1234-4abc-8def-123456789012",
        "b2c3d4e5-2345-4bcd-9ef0-234567890123",
        "c3d4e5f6-3456-4cde-a012-345678901234",
        "d4e5f6a7-4567-4def-b123-456789012345",
        "e5f6a7b8-5678-4efa-c234-567890123456"
    },
    medium = {
        "f6a7b8c9-6789-4fab-d345-678901234567",
        "a7b8c9d0-7890-4abc-e456-789012345678",
        "b8c9d0e1-8901-4bcd-f567-890123456789",
        "c9d0e1f2-9012-4cde-a678-901234567890",
        "d0e1f2a3-0123-4def-b789-012345678901"
    },
    strong = {
        "e1f2a3b4-1234-4efa-c890-123456789012",
        "f2a3b4c5-2345-4fab-d901-234567890123",
        "a3b4c5d6-3456-4abc-e012-345678901234",
        "b4c5d6e7-4567-4bcd-f123-456789012345",
        "c5d6e7f8-5678-4cde-a234-567890123456"
    }
}

-- OUTFIT DICTIONARY
mercenaries.Outfits = {
    -- 1: Generic Mercs
    [1] = {
        weak = {
            "0083b6bd-6ebd-47f3-b324-48d64c7ee625", "010dbdae-fce7-4598-9f61-f7c6a9541bee",
            "18a63cbf-db72-435d-9b89-ea47ea6b5ec2", "18c0b32e-2a8b-4e87-88db-6b236dc74df9",
            "1e4a756f-289c-4438-8bb4-622a78cc1e54", "1e513663-3c33-4474-8965-0d47d376fc15"
        },
        medium = {
            "01234e1e-d58d-4c6b-9f5e-5eafba96e3a5", "0e9b94c7-6873-4370-9ef4-c340805991e9",
            "0f9da090-8d32-44bc-b32a-e546540ce2a6", "14be331a-6144-4ccd-a412-fa6e5c31e7b6",
            "1e36a496-0714-4321-bd87-a68d750e6acd", "1deb1422-9138-44de-9828-ffa3ac96341a"
        },
        strong = {
            "15dff4c0-790a-47b9-b513-6392eb2b2c10", "21bad5eb-9f37-480a-9a7a-9ff7b6ef7494",
            "16f9fae3-bc87-4c08-b6da-188dd4727967", "1c7677ee-afab-40db-a640-23c6ed7ba57d",
            "1db7d4c5-0000-480a-a312-f27fbef46789", "2137c08b-fff0-4fa5-8021-5e510081770f",
            "22138336-26df-4884-b0ba-af9489bad577", "41a63950-deca-4773-be7c-0465f7ef80bd"
        }
    },
    -- 2: Bandits
    [2] = {
        weak = {
            "20aba0c4-1cfb-42de-97dd-939530d6240d", "2285cbe9-3962-4093-94a9-86f556e5bf2f",
            "87d45cbe-f5af-418b-a238-9de0a541b28d", "8c3c5bb8-ffaa-4f30-b635-9af37750a4d0",
            "c8f922a2-f889-4d90-9d1d-3ffc26f90961", "e0eefec7-ac35-46eb-a07e-9cda47a926bb"
        },
        medium = {
            "07a49bb9-1b92-43c2-848f-f4abf88a3b12", "c685a814-ace0-4c6b-b8bb-9a024d073d42",
            "394c8de2-7525-4f3a-8774-17876c95b6b6", "fdec006f-b7e2-491a-8a1d-f453501b7ffc",
            "0154a9ef-ad07-4c4a-bf5b-4bca21b65d7b", "d4468c20-47e3-49dd-995e-65063040696e"
        },
        strong = {
            "48f33d37-90ab-489a-9236-d56819d25ea2", "94d6d667-139b-4d79-a25b-f2b608b86c96",
            "ed029076-0371-4dd1-86dc-bdacc427f593", "0e75824c-19de-40d2-a6fa-14d6c9964c48"
        }
    },
    -- 3: Cumans
    [3] = {
        weak = {
            "08d7d086-327a-4f95-92d3-6a6c60a494f0", "1291b696-d704-4fb0-90da-2bdf4c2eefef",
            "4163bbb6-a7bf-47a3-b5c7-bffdbe0c2062", "838f07ef-5875-4391-9fe2-5fd93ffa6501",
            "e1f7bfd8-f211-4693-9004-0fc36f166e1f", "fca2a301-45e5-4cd9-af18-09469bbd8102"
        },
        medium = {
            "70618c60-9f1e-4949-a1d2-06b1a9709e82", "3860443e-3ed3-4424-8924-115d5826b6bf",
            "9b9f92a0-7040-4f3e-85ee-1f2651ee6672"
        },
        strong = {
            "8d8951b3-af89-4c0a-a7d6-99c8f6f7fe86", "bd87c9e4-5481-4a98-8279-ec010e4c10ad",
            "978b6b0c-288b-4d0b-8cfa-f2fe1a801409", "efff8f2e-a199-4883-8bb8-3219c4103e22"
        }
    },
    -- 4: Skalitz
    [4] = {
        weak = {
            "279bf58e-8394-4306-b80b-c99145b147aa", "65eae61d-b819-4104-9dd5-cb9fbf3215f8",
            "e09441c6-e9b9-463e-be4e-4c80acf233c7"
        },
        medium = {
            "65eae61d-b819-4104-9dd5-cb9fbf3215f8", "6fb18378-7fa4-4643-a5b7-0c39fd213f44",
            "8a829b7f-6680-449b-b75e-0cf61d933c2f", "e824bdf5-43d8-4e16-b0e4-9bf9b51c8d1d"
        },
        
        strong = {
            "e3a42ab9-81c0-4f17-9120-f9cb248b17c6", "e1a42ab9-81c0-4f17-9120-f9cb248b17c1",
            "e1a42ab9-81c0-4f17-9120-f9cb248b27c2", "e1a42ab9-81c0-4f17-9120-f9cb148b17c3"
        }
    },
    -- 5: Kuttenberg
    [5] = {
        weak = {
            "267be0c6-f3c5-463a-8837-b1a08cd420df", "4489369a-a7f1-4db9-9c9e-0c967fbb2a6e",
            "596a8d71-50aa-485f-b5ee-9c6c8d362e76", "93f055f5-60ef-4fab-9950-550e691c8df3"
        },
        medium = {
            "0f5e458e-1a8b-4477-8a02-8e11d96fe371", "1346a6c9-209b-49d4-a9b5-be4a1718813b",
            "221d9f52-99ab-4195-a4bc-921849e8fac4", "418ca358-97de-47c8-acd5-92bdcd11d157",
            "16552e2b-969b-4ab8-8932-318b1bbeae86"
        },
        strong = {
            "17134a39-1eb5-41ba-a2bf-9325be31a274", "236098e4-0e5c-40f5-adb3-9a7bd1fafd3d",
            "3605e258-a641-4b99-9cca-edaa44cb0f29", "9082f7cc-b899-4161-b06c-573133d2d3e0"
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
    [1]  = { guid = "74db1d52-7360-4ed3-b716-f6a53f47f2f9", cost = 1500 }, -- Kubenka
    [2]  = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11801", cost = 1000 }, -- Vasko
    [3]  = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11802", cost = 800 },  -- Jasak
    [4]  = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11803", cost = 2000 }, -- Black Bartosch
    [5]  = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11804", cost = 2000 }, -- Gnarly (Hejtman Suk)
    [6]  = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11805", cost = 1500 }, -- Jan Posy
    [7]  = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11806", cost = 1500 }, -- Miroslav Tugbone
    [8]  = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11807", cost = 1000 }, -- Menhard
    [9]  = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11808", cost = 500 },  -- Arne
    [10] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11809", cost = 800 },  -- Janek of Skalitz
    [11] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11810", cost = 800 },  -- Jaroslav
    [12] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11811", cost = 1500 }, -- Adder (Komar)
    [13] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11812", cost = 1500 }, -- Janosh
    [14] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11813", cost = 500 },  -- Mathew the Collector
    [15] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11814", cost = 3000 }, -- Zizka
    [16] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11815", cost = 3000 }, -- The Devil
    [17] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11816", cost = 2500 }, -- Godwin
    [18] = { guid = "c2a51ce4-449f-4a2e-83b9-c098c5b11817", cost = 3000 }  -- Hans Capon
}

-- Persistent counters to guarantee we never spawn duplicate faces in a batch
mercenaries.SoulIndex = { weak = 1, medium = 1, strong = 1 }

-- Safely execute strings without equals/semicolon bugs through the console, for testing purposes
function mercenaries:ExecString(text)
    local func, err = loadstring(text)
    if func then pcall(func) end
end

function mercenaries:SetState(state)
    if state == "dismiss" then
        _G.MercenariesDismissed = true
        self:SaveString("MercenariesDismissed", "1")
        Game.SendInfoText('merc_info_dismissed', false, 0, 3)
    elseif state == "wait" then
        _G.MercIdle = true
        _G.MercPersistentIdleFlag = true
        self:SaveString("MercIdlePersistent", "1")
        Game.SendInfoText('merc_info_waiting', false, 0, 3)
    elseif state == "follow" then
        _G.MercIdle = false
        _G.MercPersistentIdleFlag = false
        mercenaries:SaveString("MercIdlePersistent", "0") 
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

    local countCustomCompanion = p:GetCountOfClass(self.TokenIDCustomComp)
    local countRetrieve = p:GetCountOfClass(self.TokenIDReturn)
    local countHeal = p:GetCountOfClass(self.TokenIDHeal)


    
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

    if countCustomCompanion and countCustomCompanion > 0 then
        p:DeleteItemOfClass(self.TokenIDCustomComp, countCustomCompanion)
        self:HireCustomCompanion(countCustomCompanion) 
    end

    if countRetrieve and countRetrieve > 0 then
        p:DeleteItemOfClass(self.TokenIDReturn, countRetrieve)

        self:SetState("follow")
        Game.SendInfoText('merc_info_returning', false, 0, 3)
    end


    --heal & wash x number of mercs
    if countHeal and countHeal > 0 then
        p:DeleteItemOfClass(self.TokenIDHeal, countHeal)
        self:FullHealAndWashNumberOfMercs(countHeal) 
    end


end

-- The looping function
function mercenaries.MonitorLoop()
    if player and player.inventory then
        mercenaries:MonitorInventory()
    end
    mercenaries:MonitorMainQuestLoop()
    mercenaries:UpdateEnemyCache()

    Script.SetTimerForFunction(1000, "mercenaries.MonitorLoop")
end

function mercenaries.LowPriorityMonitorLoop()
    mercenaries:PruneMercCache()
    mercenaries:UpdateFormationSlots()

    Script.SetTimerForFunction(5000, "mercenaries.LowPriorityMonitorLoop")

end

-- Mod Initialization
function mercenaries:OnGameplayStarted(actionName, eventName, argTable)
    System.LogAlways("[Mercenaries] Game loaded! Starting the inventory monitor loop...")
    
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
    
    -- Load OUTFIT State
    local savedOutfit = mercenaries:LoadString("MercOutfitPersistent")
    if savedOutfit and tonumber(savedOutfit) and tonumber(savedOutfit) > 0 then
        _G.MercCurrentOutfit = tonumber(savedOutfit)
        self:ChangeMercOutfit(_G.MercCurrentOutfit, true)
    else
        _G.MercCurrentOutfit = 1
    end

    self:ReleaseSpeakingLock()

    -- PERFORMANCE: Rebuild the merc entity cache after each load.
    -- This is the ONE permitted full-world NPC scan — done once on load,
    -- not every second in the monitor loop.
    Script.SetTimerForFunction(2000, "mercenaries.RebuildMercCacheDelayed")
    if not mercenaries.timersStarted then
        mercenaries.timersStarted = true
        Script.SetTimerForFunction(1000, "mercenaries.MonitorLoop")
        Script.SetTimerForFunction(5000, "mercenaries.LowPriorityMonitorLoop")
    end


end

--register other scripts, most scripts are referenced from the ai behaviour trees
Script.LoadScript("Scripts/mods/mercenaries_spawning.lua")
Script.LoadScript("Scripts/mods/mercenaries_equipment.lua")
Script.LoadScript("Scripts/mods/mercenaries_util.lua")
Script.LoadScript("Scripts/mods/mercenaries_management.lua")
Script.LoadScript("Scripts/mods/mercenaries_target_selection.lua")
Script.LoadScript("Scripts/mods/mercenaries_teleport.lua")
Script.LoadScript("Scripts/mods/mercenaries_formation_handler.lua")
Script.LoadScript("Scripts/mods/mercenaries_main_quest_handler.lua")
Script.LoadScript("Scripts/mods/mercenaries_saving.lua")
Script.LoadScript("Scripts/mods/mercenaries_lookatinteraction.lua")


-- Register commands
System.AddCCommand("merc_lua", "mercenaries:ExecString(%line)", "")

System.AddCCommand("merc_recount", "mercenaries:Recount()", "")
System.AddCCommand("merc_dismiss", "mercenaries:SetState('dismiss')", "")
System.AddCCommand("merc_wait", "mercenaries:SetState('wait')", "")
System.AddCCommand("merc_follow", "mercenaries:SetState('follow')", "")

System.AddCCommand("merc_hire_w1", "mercenaries:Hire(0, 1, 'weak')", "")
System.AddCCommand("merc_hire_w2", "mercenaries:Hire(0, 2, 'weak')", "")
System.AddCCommand("merc_hire_w3", "mercenaries:Hire(0, 3, 'weak')", "")
System.AddCCommand("merc_hire_d1", "mercenaries:Hire(0, 1, 'medium')", "")
System.AddCCommand("merc_hire_d2", "mercenaries:Hire(0, 2, 'medium')", "")
System.AddCCommand("merc_hire_d3", "mercenaries:Hire(0, 3, 'medium')", "")
System.AddCCommand("merc_hire_p1", "mercenaries:Hire(0, 1, 'strong')", "")
System.AddCCommand("merc_hire_p2", "mercenaries:Hire(0, 2, 'strong')", "")
System.AddCCommand("merc_hire_p3", "mercenaries:Hire(0, 3, 'strong')", "")

System.AddCCommand("merc_hire_strong_army", "mercenaries:Hire(0, 10, 'strong')", "")
System.AddCCommand("merc_hire_weak_horde", "mercenaries:Hire(0, 10, 'weak')", "")

-- Usage in console: merc_save_string global_idle 1|true|105.5
System.AddCCommand("merc_save_string", "mercenaries:SaveString('%1', '%2')", "Saves a string to a persistent entity. Usage: merc_save_string <tag> <data>")

-- Usage in console: merc_load_string global_idle
System.AddCCommand("merc_load_string", "mercenaries:LoadString('%1')", "Retrieves the saved string from the persistent entity. Usage: merc_load_string <tag>")


-- Register the event listener
UIAction.RegisterEventSystemListener(mercenaries, "", "OnGameplayStarted", "OnGameplayStarted")