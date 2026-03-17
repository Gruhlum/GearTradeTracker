-- GearTradeTracker - Gear Item Level Tracker for WoW
-- Main addon initialization and event handling

local addonName = ...

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")

f:SetScript("OnEvent", function(self, event, name)
    if name ~= addonName then return end

    -- Initialize DB
    GearTradeTrackerDB = GearTradeTrackerDB or {}
    GearTradeTrackerDB.characters = GearTradeTrackerDB.characters or {}
    GearTradeTrackerDB.settings = GearTradeTrackerDB.settings or {}
    GearTradeTrackerDB.settings.minimap = GearTradeTrackerDB.settings.minimap or { hide = false }

    -- Initialize minimap
    if GearTradeTracker_InitMinimap then
        GearTradeTracker_InitMinimap()
    end

    -- Default target ilvl
    if GearTradeTrackerDB.targetItemLevel == nil then 
        GearTradeTrackerDB.targetItemLevel = 272 
    end
    
     -- Ignore characters that are not max level (90)
    if UnitLevel("player") ~= 90 then return end
    -- Add current character using NEW key format
    local charKey = GearTradeTracker_GetCharKey()
    GearTradeTrackerDB.characters[charKey] = GearTradeTrackerDB.characters[charKey] or {}
end)

------------------------------------------------------------
-- PLAYER_ENTERING_WORLD / EQUIPMENT_CHANGED
------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then

        GearTradeTracker_InitMinimap()
        -- Ignore characters that are not max level (90)
        if UnitLevel("player") ~= 90 then return end

        GearTradeTracker_InitChar()

        C_Timer.After(2, function()
            for slotID = 1, 17 do
                if slotID ~= 4 then GearTradeTracker_ProcessSlot(slotID) end
            end
            GearTradeTracker_RefreshCharacterOverview()

            C_Timer.After(1, function()
                GearTradeTracker_RetryPendingSlots()
                GearTradeTracker_RefreshCharacterOverview()
            end)
        end)

        if slider then slider:SetValue(GearTradeTrackerDB.targetItemLevel) end
        if editBox then editBox:SetNumber(GearTradeTrackerDB.targetItemLevel) end

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        -- Ignore characters that are not max level (90)
        if UnitLevel("player") ~= 90 then return end

        local slotID = arg1
        if slotID and slotID ~= 4 then
            GearTradeTracker_ProcessSlot(slotID)
            if panelOpen then
                GearTradeTracker_RefreshCharacterOverview()
            end
        end
    end
end)

------------------------------------------------------------
-- Slash Commands
------------------------------------------------------------

SLASH_GTTRESET1 = "/gttreset"
SlashCmdList["GTTRESET"] = function()
    print("GearTradeTracker: Clearing all saved data...")
    GearTradeTrackerDB = {}
    ReloadUI()
end

SLASH_GEARTRADETRACKER1 = "/gtt"
SlashCmdList["GEARTRADETRACKER"] = function()
    local key = GearTradeTracker_GetCharKey()
    local data = GearTradeTrackerDB.characters[key] or {}

    print("Armor:")
    for _, name in pairs(GearTradeTracker_AllSlots.Armor) do
        local ilvl = data[name]
        if ilvl then
            print("  " .. name .. ": " .. ilvl)
        end
    end

    print("Weapons:")
    for slotKey, slotData in pairs(data) do
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
    local data = GearTradeTrackerDB.characters[key] or {}
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
