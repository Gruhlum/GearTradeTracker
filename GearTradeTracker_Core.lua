-- Core logic: item processing, data calculations

local pending = {}

function GearTradeTracker_GetCharKey()
    local name, realm = UnitFullName("player")
    if not realm or realm == "" then
        realm = GetRealmName()
    end
    return name .. "-" .. realm
end



function GearTradeTracker_InitChar()
    local key = GearTradeTracker_GetCharKey()

    -- Ensure root tables exist
    GearTradeTrackerDB.characters = GearTradeTrackerDB.characters or {}

    -- Ensure character table exists
    GearTradeTrackerDB.characters[key] = GearTradeTrackerDB.characters[key] or {}

    local charDB = GearTradeTrackerDB.characters[key]

    if type(charDB) ~= "table" then
        charDB = {}
        GearTradeTrackerDB.characters[key] = charDB
    end

    charDB.CLASS = select(2, UnitClass("player"))
end


local function DebugPrintStats(itemLink)
    local stats = C_Item.GetItemStats(itemLink)
    if not stats then
        print("No stats returned for", itemLink)
        return
    end

    print("Stats for:", itemLink)
    for stat, value in pairs(stats) do
        print("  ", stat, "=", value)
    end
end

local function GetPrimaryStat(itemLink)
    local stats = C_Item.GetItemStats(itemLink)
    if not stats then return nil end

    if stats["ITEM_MOD_INTELLECT_SHORT"] then return "INT" end
    if stats["ITEM_MOD_STRENGTH_SHORT"] then return "STR" end
    if stats["ITEM_MOD_AGILITY_SHORT"] then return "AGI" end

    return nil
end

local function StatAbbrevToKey(statAbbrev)
    local mapping = {
        INT = "ITEM_MOD_INTELLECT_SHORT",
        STR = "ITEM_MOD_STRENGTH_SHORT",
        AGI = "ITEM_MOD_AGILITY_SHORT",
    }
    return mapping[statAbbrev]
end

local function GetWeaponSlotAndType(equipLoc, slotID)
    if equipLoc == "INVTYPE_2HWEAPON" then
        return "MAINHAND", "2H"
    elseif equipLoc == "INVTYPE_WEAPON" then
        -- INVTYPE_WEAPON can be mainhand or offhand; use slotID to determine
        -- Slot 16 = mainhand, Slot 17 = offhand
        if slotID == 17 then
            return "OFFHAND", "1H"
        else
            return "MAINHAND", "1H"
        end
    elseif equipLoc == "INVTYPE_WEAPONMAINHAND" then
        return "MAINHAND", "1H"
    elseif equipLoc == "INVTYPE_WEAPONOFFHAND" then
        return "OFFHAND", "1H"
    elseif equipLoc == "INVTYPE_SHIELD" then
        return "OFFHAND", "SHIELD"
    elseif equipLoc == "INVTYPE_HOLDABLE" then
        return "OFFHAND", "FRILL"
    end
    return nil, nil
end

local function EnsureWeaponPath(key, slotKey, handType, stat)
    local charDB = GearTradeTrackerDB.characters[key]
    charDB[slotKey] = charDB[slotKey] or {}
    charDB[slotKey][handType] = charDB[slotKey][handType] or {}

    if stat then
        charDB[slotKey][handType][stat] =
            charDB[slotKey][handType][stat] or 0
    else
        charDB[slotKey][handType] =
            charDB[slotKey][handType] or 0
    end
end


local function UpdateArmor(key, slotID, itemLevel)
    -- Ensure character table exists
    GearTradeTrackerDB.characters[key] = GearTradeTrackerDB.characters[key] or {}

    local slotName = GearTradeTracker_ArmorBySlotID[slotID]
    if not slotName then return end
    -- Check if this slot belongs to a group (finger/trinket)
    for groupName, slots in pairs(GearTradeTracker_SlotGroups) do
        for _, s in ipairs(slots) do
            if s == slotName then
                -- Update the individual slot
                GearTradeTrackerDB.characters[key][s] = itemLevel

                -- Recalculate the group value = lowest of the two slots
                local a = GearTradeTrackerDB.characters[key][slots[1]] or 0
                local b = GearTradeTrackerDB.characters[key][slots[2]] or 0
                local lowest = math.min(a, b)

                GearTradeTrackerDB.characters[key][groupName] = lowest
                return
            end
        end
    end

    -- Normal non-group slot
    local current = GearTradeTrackerDB.characters[key][slotName] or 0
    if itemLevel > current then
        GearTradeTrackerDB.characters[key][slotName] = itemLevel
    end
end


local function UpdateWeapon(key, itemLink, itemLevel, equipLoc, slotID, playerClass)
    local slotKey, handType = GetWeaponSlotAndType(equipLoc, slotID)
    if not slotKey or not handType then return end

    -- Ensure character table exists
    GearTradeTrackerDB.characters[key] = GearTradeTrackerDB.characters[key] or {}
    local charDB = GearTradeTrackerDB.characters[key]

    -- 1H / 2H weapons (stat-based)
    if handType == "1H" or handType == "2H" then
        local stats = C_Item.GetItemStats(itemLink)
        if not stats then return end

        charDB[slotKey] = charDB[slotKey] or {}
        charDB[slotKey][handType] = charDB[slotKey][handType] or {}

        if playerClass and GearTradeTracker_ClassPrimaryStats[playerClass] then
            for stat, _ in pairs(GearTradeTracker_ClassPrimaryStats[playerClass]) do
                local statKey = StatAbbrevToKey(stat)
                if statKey and stats[statKey] then
                    local current = charDB[slotKey][handType][stat] or 0
                    if itemLevel > current then
                        charDB[slotKey][handType][stat] = itemLevel
                    end
                end
            end
        end
        return
    end

    -- SHIELD / FRILL (single numeric value)
    charDB[slotKey] = charDB[slotKey] or {}

    local current = tonumber(charDB[slotKey][handType]) or 0
    if itemLevel > current then
        charDB[slotKey][handType] = itemLevel
    end
end

local function ProcessItem(itemLink, slotID)
    local key = GearTradeTracker_GetCharKey()

    local name, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemLink)
    if not name then
        pending[itemLink] = pending[itemLink] or {}
        pending[itemLink][slotID] = true
        return
    end

    local itemLevel = GetDetailedItemLevelInfo(itemLink)
    if not itemLevel or itemLevel == 0 then return end

    local data = GearTradeTrackerDB.characters[key] or {}
    local playerClass = data.CLASS

    -- Weapon detection by exact equipLoc
    if equipLoc == "INVTYPE_2HWEAPON"
    or equipLoc == "INVTYPE_WEAPON"
    or equipLoc == "INVTYPE_WEAPONMAINHAND"
    or equipLoc == "INVTYPE_WEAPONOFFHAND"
    or equipLoc == "INVTYPE_SHIELD"
    or equipLoc == "INVTYPE_HOLDABLE"
    then
        UpdateWeapon(key, itemLink, itemLevel, equipLoc, slotID, playerClass)
        return
    end

    -- Otherwise armor
    if GearTradeTracker_ArmorBySlotID[slotID] then
        UpdateArmor(key, slotID, itemLevel)
    end
end

function GearTradeTracker_SortByOutputOrder(list) 
    table.sort(list, function(a, b) 
        local ai, bi = 999, 999 
        for i, name in ipairs(GearTradeTracker_OutputOrder) do 
            if a == name then ai = i end
            if b == name then bi = i end
        end 
        return ai < bi end) 
end

function GearTradeTracker_ProcessSlot(slotID)
    local itemLink = GetInventoryItemLink("player", slotID)
    if itemLink then
        ProcessItem(itemLink, slotID)
    end
end

function GearTradeTracker_RetryPendingSlots()
    -- Retry any items that were pending
    if pending and next(pending) then
        for itemLink, slots in pairs(pending) do
            for slotID in pairs(slots) do
                ProcessItem(itemLink, slotID)
            end
        end
        pending = {}
    end
end

function GearTradeTracker_ColorizeIlvl(ilvl, target)
    if not ilvl then
        return "|cffff0000—|r"
    end

    if ilvl >= target then
        return "|cff00ff00" .. ilvl .. "|r"
    else
        return "|cffff0000" .. ilvl .. "|r"
    end
end

function GearTradeTracker_GroupSlots(list)
    local set = {}
    for _, slot in ipairs(list) do
        set[slot] = true
    end

    local output = {}

    -- Fingers
    if set["FINGER1"] or set["FINGER2"] then
        table.insert(output, "FINGER")
        set["FINGER1"] = nil
        set["FINGER2"] = nil
    end

    -- Trinkets
    if set["TRINKET1"] or set["TRINKET2"] then
        table.insert(output, "TRINKET")
        set["TRINKET1"] = nil
        set["TRINKET2"] = nil
    end

    -- Everything else
    for slot, _ in pairs(set) do
        table.insert(output, slot)
    end

    return output
end

local function SanitizeValue(v)
    return type(v) == "number" and v or nil
end

function GearTradeTracker_GetUntradeableSlots(key)
    local data = GearTradeTrackerDB.characters[key] or {}
    local playerClass = data.CLASS
    local target = GearTradeTrackerDB.targetItemLevel
    local list = {}

    -- Armor
    for _, slot in ipairs(GearTradeTracker_AllSlots.Armor) do
        local ilvl = SanitizeValue(data[slot])
        if not ilvl or ilvl < target then
            table.insert(list, slot)
        end
    end

   -- Weapons
    if playerClass and GearTradeTracker_ClassWeaponTypes[playerClass] then
        for _, w in ipairs(GearTradeTracker_AllSlots.Weapons) do
           if w.stat then
                    if GearTradeTracker_ClassPrimaryStats[playerClass] and GearTradeTracker_ClassPrimaryStats[playerClass][w.stat] then

                        local raw = data[w.slot]
                            and data[w.slot][w.hand]
                            and data[w.slot][w.hand][w.stat]

                        local stored = SanitizeValue(raw)

                        if not stored or stored < target then
                            table.insert(list, w.slot .. " " .. w.hand .. " " .. w.stat)
                        end
                    end

                -- 2) Stat-less offhands (SHIELD / FRILL)
                else
                    if GearTradeTracker_ClassWeaponTypes[playerClass][w.hand] then

                        local raw = data[w.slot]
                            and data[w.slot][w.hand]

                        local stored = SanitizeValue(raw)

                        if not stored or stored < target then
                            table.insert(list, w.slot .. " " .. w.hand)
                        end
                    end
                end
        end
    end
    return list
end
