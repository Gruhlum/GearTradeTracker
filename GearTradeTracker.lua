-- GearTradeTracker - Gear Item Level Tracker for WoW
-- Main addon initialization and event handling

local addonName = ...

-- ADDON_LOADED event: Initialize SavedVariables
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")

f:SetScript("OnEvent", function(self, event, name)
    if name ~= addonName then return end

    -- Safe initialization AFTER SavedVariables are loaded
    GearTradeTrackerDB = GearTradeTrackerDB or {}
    GearTradeTrackerDB.characters = GearTradeTrackerDB.characters or {}
    GearTradeTrackerDB.settings = GearTradeTrackerDB.settings or {}
    GearTradeTrackerDB.settings.minimap = GearTradeTrackerDB.settings.minimap or { hide = false }

    -- Add current character if missing
    local charKey = UnitName("player") .. " - " .. GetRealmName()
    GearTradeTrackerDB.characters[charKey] = GearTradeTrackerDB.characters[charKey] or {}

    -- Initialize minimap button
    if GearTradeTracker_InitMinimap then
        GearTradeTracker_InitMinimap()
    end

    if GearTradeTrackerDB.targetItemLevel == nil then 
        GearTradeTrackerDB.targetItemLevel = 272 
    end
end)

-- PLAYER_ENTERING_WORLD and PLAYER_EQUIPMENT_CHANGED events
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        GearTradeTracker_InitChar()
        GearTradeTracker_InitMinimap()
        C_Timer.After(2, function()
            for slotID = 1, 17 do
                if slotID ~= 4 then GearTradeTracker_ProcessSlot(slotID) end
            end
            GearTradeTracker_RefreshCharacterOverview()
            
            -- Retry any pending items after another 1 second
            C_Timer.After(1, function()
                GearTradeTracker_RetryPendingSlots()
                GearTradeTracker_RefreshCharacterOverview()
            end)
        end)

        if GearTradeTrackerDB.targetItemLevel == nil then
            GearTradeTrackerDB.targetItemLevel = 272
        end

        if slider then slider:SetValue(GearTradeTrackerDB.targetItemLevel) end
        if editBox then editBox:SetNumber(GearTradeTrackerDB.targetItemLevel) end

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        local slotID = arg1
        if slotID and slotID ~= 4 then
            GearTradeTracker_ProcessSlot(slotID)
            if panelOpen then
                GearTradeTracker_RefreshCharacterOverview()
            end
        end
    end
end)

-- Slash commands
SLASH_GTTRESET1 = "/gttreset"
SlashCmdList["GTTRESET"] = function()
    print("GearTradeTracker: Clearing all saved data...")
    GearTradeTrackerDB = {}
    ReloadUI()
end

SLASH_GEARTRADETRACKER1 = "/gtt"
SlashCmdList["GEARTRADETRACKER"] = function()
    local key = GearTradeTracker_GetCharKey()

    print("Armor:")
    for _, name in pairs(GearTradeTracker_AllSlots.Armor) do
        local ilvl = GearTradeTrackerDB[key][name]
        if ilvl then
            print("  " .. name .. ": " .. ilvl)
        end
    end

    print("Weapons:")
    for slotKey, slotData in pairs(GearTradeTrackerDB[key]) do
        if slotKey == "MAINHAND" or slotKey == "OFFHAND" then
            print("  " .. slotKey .. ":")
            for handType, handData in pairs(slotData) do
                if type(handData) == "table" then
                    for stat, ilvl in pairs(handData) do
                        print(string.format("    %s %s: %d", handType, stat, ilvl))
                    end
                else
                    print(string.format("    %s: %d", handType, handData))
                end
            end
        end
    end
end

SLASH_GTTDEBUG1 = "/gttdebug"
SlashCmdList["GTTDEBUG"] = function()
    local key = GearTradeTracker_GetCharKey()
    local data = GearTradeTrackerDB[key] or {}
    local playerClass = data.CLASS or "UNKNOWN"
    
    print("=== GearTradeTracker Debug Info ===")
    print("Character Key:", key)
    print("Class:", playerClass)
    
    print("\nClass Configuration:")
    if GearTradeTracker_ClassWeaponTypes[playerClass] then
        print("  Weapon Types Allowed:")
        for hand, allowed in pairs(GearTradeTracker_ClassWeaponTypes[playerClass]) do
            if allowed then print("    - " .. hand) end
        end
    else
        print("  Class not found in weapon types!")
    end
    
    if GearTradeTracker_ClassPrimaryStats[playerClass] then
        print("  Primary Stats:")
        for stat, _ in pairs(GearTradeTracker_ClassPrimaryStats[playerClass]) do
            print("    - " .. stat)
        end
    end
    
    print("\nEquipped Items:")
    for slot = 1, 17 do
        local itemLink = GetInventoryItemLink("player", slot)
        if itemLink then
            local name, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemLink)
            local ilvl = GetDetailedItemLevelInfo(itemLink)
            print(string.format("  Slot %d: %s (equipLoc: %s, ilvl: %s)", slot, name, equipLoc, ilvl or "?"))
        end
    end
end
