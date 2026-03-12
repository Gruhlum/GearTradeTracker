local addonName = ...

GearTradeTrackerDB = GearTradeTrackerDB or {}
local pending = {}

-- Options constants
local MIN_TARGET_ILVL = 224
local MAX_TARGET_ILVL = 282
local DEFAULT_TARGET_ILVL = 272

local panelOpen = false
local SelectedCharacter = nil
local isRefreshing = false

if GearTradeTrackerDB.targetItemLevel == nil then 
GearTradeTrackerDB.targetItemLevel = DEFAULT_TARGET_ILVL 
end

local function GetCharKey()
    local name, realm = UnitName("player")
    realm = realm or GetRealmName()
    return name .. "-" .. realm
end

local function InitChar()
    local key = GetCharKey()
    GearTradeTrackerDB[key] = GearTradeTrackerDB[key] or {}

    -- Store the character's class (2nd return value = "WARRIOR", "MAGE", etc.)
    GearTradeTrackerDB[key].CLASS = select(2, UnitClass("player"))

    if type(GearTradeTrackerDB[key]) ~= "table" then
        GearTradeTrackerDB[key] = {}
    end

    GearTradeTrackerDB[key].FINGER = nil
    GearTradeTrackerDB[key].TRINKET = nil
end

local OutputOrder = {
    "HEAD",
    "NECK",
    "SHOULDER",
    "CHEST",
    "WAIST",
    "LEGS",
    "FEET",
    "WRIST",
    "HANDS",
    "FINGER",
    "TRINKET",
    "BACK",
    "MAINHAND 1H STR",
    "MAINHAND 1H AGI",
    "MAINHAND 1H INT",
    "MAINHAND 2H STR",
    "MAINHAND 2H AGI",
    "MAINHAND 2H INT",
    "OFFHAND SHIELD",
    "OFFHAND FRILL",
}


local ArmorBySlotID = {
    [1]  = "HEAD",
    [2]  = "NECK",
    [3]  = "SHOULDER",
    [5]  = "CHEST",
    [6]  = "WAIST",
    [7]  = "LEGS",
    [8]  = "FEET",
    [9]  = "WRIST",
    [10] = "HANDS",
    [11] = "FINGER1",
    [12] = "FINGER2",
    [13] = "TRINKET1",
    [14] = "TRINKET2",
    [15] = "BACK",
}

local AllSlots = {
    Armor = {
        "HEAD", "NECK", "SHOULDER", "CHEST", "WAIST",
        "LEGS", "FEET", "WRIST", "HANDS",
        "FINGER1", "FINGER2",
        "TRINKET1", "TRINKET2",
        "BACK",
    },

    Weapons = {
        { slot = "MAINHAND", hand = "1H", stat = "INT" },
        { slot = "MAINHAND", hand = "1H", stat = "STR" },
        { slot = "MAINHAND", hand = "1H", stat = "AGI" },

        { slot = "MAINHAND", hand = "2H", stat = "INT" },
        { slot = "MAINHAND", hand = "2H", stat = "STR" },
        { slot = "MAINHAND", hand = "2H", stat = "AGI" },

        { slot = "OFFHAND", hand = "SHIELD", stat = nil },
        { slot = "OFFHAND", hand = "FRILL",  stat = nil },
    }
}

local ClassPrimaryStats = {
    WARRIOR   = { STR = true },
    PALADIN   = { STR = true, INT = true }, -- Holy uses INT, others STR
    HUNTER    = { AGI = true },
    ROGUE     = { AGI = true },
    PRIEST    = { INT = true },
    SHAMAN    = { INT = true, AGI = true }, -- depends on spec
    MAGE      = { INT = true },
    WARLOCK   = { INT = true },
    DRUID     = { INT = true, AGI = true }, -- depends on form/spec
    DEATHKNIGHT = { STR = true },
    MONK      = { AGI = true, INT = true }, -- MW INT, others AGI
    DEMONHUNTER = { AGI = true },
    EVOKER    = { INT = true },
}

local ClassWeaponTypes = {
    WARRIOR      = { ["1H"]=true, ["2H"]=true, SHIELD=true },
    PALADIN      = { ["1H"]=true, ["2H"]=true, SHIELD=true },
    HUNTER       = { ["1H"]=true, ["2H"]=true },
    ROGUE        = { ["1H"]=true },
    PRIEST       = { ["1H"]=true, ["2H"]=true, FRILL=true },
    SHAMAN       = { ["1H"]=true, ["2H"]=true, SHIELD=true },
    MAGE         = { ["1H"]=true, ["2H"]=true, FRILL=true },
    WARLOCK      = { ["1H"]=true, ["2H"]=true, FRILL=true },
    DRUID        = { ["1H"]=true, ["2H"]=true, FRILL=true },
    DEATHKNIGHT  = { ["1H"]=true, ["2H"]=true },
    MONK         = { ["1H"]=true, ["2H"]=true },
    DEMONHUNTER  = { ["1H"]=true, ["2H"]=true },
    EVOKER       = { ["1H"]=true, ["2H"]=true, FRILL=true },
}

------------------------------------------------------------
-- Export Popup (must be defined before use)
------------------------------------------------------------
exportFrame = CreateFrame("Frame", "GTT_ExportFrame", UIParent, "BasicFrameTemplateWithInset")
exportFrame:SetSize(400, 300)
exportFrame:SetPoint("CENTER")
exportFrame:Hide()

exportFrame:SetFrameStrata("DIALOG")
exportFrame:SetFrameLevel(1000)

exportFrame.title = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
exportFrame.title:SetPoint("TOP", 0, -10)
exportFrame.title:SetText("Copy Text")

local exportScroll = CreateFrame("ScrollFrame", nil, exportFrame, "UIPanelScrollFrameTemplate")
exportScroll:SetPoint("TOPLEFT", 10, -40)
exportScroll:SetPoint("BOTTOMRIGHT", -30, 10)

exportBox = CreateFrame("EditBox", nil, exportScroll)
exportBox:SetMultiLine(true)
exportBox:SetFontObject(ChatFontNormal)
exportBox:SetWidth(350)
exportBox:SetAutoFocus(true)
exportBox:SetScript("OnEscapePressed", function() exportFrame:Hide() end)

exportScroll:SetScrollChild(exportBox)

function ShowExportPopup(text)
    exportFrame:Show()
    exportBox:SetText(text)
    exportBox:HighlightText()
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


local function GetWeaponSlotAndType(equipLoc)
    if equipLoc == "INVTYPE_2HWEAPON" then
        return "MAINHAND", "2H"
    elseif equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND" then
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
    GearTradeTrackerDB[key][slotKey] = GearTradeTrackerDB[key][slotKey] or {}
    GearTradeTrackerDB[key][slotKey][handType] = GearTradeTrackerDB[key][slotKey][handType] or {}

    if stat then
        GearTradeTrackerDB[key][slotKey][handType][stat] =
            GearTradeTrackerDB[key][slotKey][handType][stat] or 0
    else
        GearTradeTrackerDB[key][slotKey][handType] =
            GearTradeTrackerDB[key][slotKey][handType] or 0
    end
end

local function UpdateArmor(key, slotID, itemLevel)
    local slotName = ArmorBySlotID[slotID]
    if not slotName then return end

    local current = GearTradeTrackerDB[key][slotName] or 0
    if itemLevel > current then
        GearTradeTrackerDB[key][slotName] = itemLevel
    end
end


local function UpdateWeapon(key, itemLink, itemLevel, equipLoc)
    local slotKey, handType = GetWeaponSlotAndType(equipLoc)
    if not slotKey or not handType then return end

    local stat = GetPrimaryStat(itemLink)

    -- 1H / 2H weapons (stat-based)
    if handType == "1H" or handType == "2H" then
        if not stat then return end

        GearTradeTrackerDB[key][slotKey] = GearTradeTrackerDB[key][slotKey] or {}
        GearTradeTrackerDB[key][slotKey][handType] = GearTradeTrackerDB[key][slotKey][handType] or {}

        local current = GearTradeTrackerDB[key][slotKey][handType][stat] or 0
        if itemLevel > current then
            GearTradeTrackerDB[key][slotKey][handType][stat] = itemLevel
        end
        return
    end

    -- SHIELD / FRILL (single numeric value)
    GearTradeTrackerDB[key][slotKey] = GearTradeTrackerDB[key][slotKey] or {}

    local current = tonumber(GearTradeTrackerDB[key][slotKey][handType]) or 0
    if itemLevel > current then
        GearTradeTrackerDB[key][slotKey][handType] = itemLevel
    end
end


local function ProcessItem(itemLink, slotID)
    local key = GetCharKey()

    local name, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemLink)
    if not name then
        pending[itemLink] = pending[itemLink] or {}
        pending[itemLink][slotID] = true
        return
    end

    local itemLevel = GetDetailedItemLevelInfo(itemLink)
    if not itemLevel or itemLevel == 0 then return end

    -- Weapon detection by exact equipLoc
    if equipLoc == "INVTYPE_2HWEAPON"
    or equipLoc == "INVTYPE_WEAPON"
    or equipLoc == "INVTYPE_WEAPONMAINHAND"
    or equipLoc == "INVTYPE_WEAPONOFFHAND"
    or equipLoc == "INVTYPE_SHIELD"
    or equipLoc == "INVTYPE_HOLDABLE"
    then
        UpdateWeapon(key, itemLink, itemLevel, equipLoc)
        return
    end

    -- Otherwise armor
    if ArmorBySlotID[slotID] then
        UpdateArmor(key, slotID, itemLevel)
    end
end

local function SortByOutputOrder(list) 
table.sort(list, function(a, b) 
    local ai, bi = 999, 999 
    for i, name in ipairs(OutputOrder) do 
        if a == name then ai = i end
        if b == name then bi = i end
    end 
    return ai < bi end) 
end

local function ProcessSlot(slotID)
    local itemLink = GetInventoryItemLink("player", slotID)
    if itemLink then
        ProcessItem(itemLink, slotID)
    end
end

local function ColorizeIlvl(ilvl, target)
    if not ilvl then
        return "|cffff0000—|r" -- red dash for missing
    end

    if ilvl >= target then
        return "|cff00ff00" .. ilvl .. "|r" -- green
    else
        return "|cffff0000" .. ilvl .. "|r" -- red
    end
end

local function GroupSlots(list)
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

local function GetUntradeableSlots(key)
    local data = GearTradeTrackerDB[key] or {}
    local playerClass = data.CLASS
    local target = GearTradeTrackerDB.targetItemLevel
    local list = {}

    -- Armor
    for _, slot in ipairs(AllSlots.Armor) do
        local ilvl = SanitizeValue(data[slot])
        if not ilvl or ilvl < target then
            table.insert(list, slot)
        end
    end

   -- Weapons
for _, w in ipairs(AllSlots.Weapons) do

    -- 1) Stat-based weapons (1H/2H INT/STR/AGI)
    if w.stat then
        if ClassPrimaryStats[playerClass][w.stat] then

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
        if ClassWeaponTypes[playerClass][w.hand] then

            local raw = data[w.slot]
                and data[w.slot][w.hand]

            local stored = SanitizeValue(raw)

            if not stored or stored < target then
                table.insert(list, w.slot .. " " .. w.hand)
            end
        end
    end
end
    return list
end


-- Create options panel
local options = CreateFrame("Frame")
options.name = "GearTradeTracker"

-- Create a tab container
local tabs = {}
local activeTab = nil

local function SelectTab(index)
    for i, tab in ipairs(tabs) do
        if i == index then
            PanelTemplates_SelectTab(tab)
            tab.content:Show()
        else
            PanelTemplates_DeselectTab(tab)
            tab.content:Hide()
        end
    end
    activeTab = index
end

local function CreateTab(parent, index, text)
    local tab = CreateFrame("Button", nil, parent, "PanelTabButtonTemplate")
    tab:SetID(index)
    tab:SetText(text)
    tab:SetScript("OnClick", function() SelectTab(index) end)

    if index == 1 then
        tab:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, 0)
    else
        tab:SetPoint("LEFT", tabs[index-1], "RIGHT", 10, 0)
    end

    PanelTemplates_TabResize(tab, 0)
    tabs[index] = tab

    -- Create the content frame for this tab
    tab.content = CreateFrame("Frame", nil, parent)
    tab.content:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -80)
    tab.content:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 10)

    return tab
end

local tabOverview   = CreateTab(options, 1, "Overview")
local settings     = CreateTab(options, 2, "Settings")

local title = tabOverview.content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, 0)

-- Register parent category
local category = Settings.RegisterCanvasLayoutCategory(options, "GearTradeTracker")
Settings.RegisterAddOnCategory(category)

SettingsPanel:HookScript("OnHide", function()
    panelOpen = false
end)

SettingsPanel:HookScript("OnShow", function()
    -- Only mark as open if our category is shown
    local current = SettingsPanel:GetCurrentCategory()
    if current and current:GetID() == category:GetID() then
        panelOpen = true
    end
end)

------------------------------------------------------------
-- Minimap Button
------------------------------------------------------------

local minimapButton = CreateFrame("Button", "GTT_MinimapButton", Minimap)
minimapButton:SetSize(24, 24)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:EnableMouse(true)
minimapButton:RegisterForDrag("LeftButton")

local icon = minimapButton:CreateTexture(nil, "ARTWORK")
icon:SetTexture("Interface\\AddOns\\GearTradeTracker\\icon.tga")
icon:SetPoint("CENTER")
icon:SetSize(24, 24)

minimapButton.icon = icon

local function UpdateMinimapButtonPosition()
    local angle = GearTradeTrackerDB.minimapAngle or 45
    local radius = 100

    local x = math.cos(math.rad(angle)) * radius
    local y = math.sin(math.rad(angle)) * radius

    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end


------------------------------------------------------------
-- Click: open settings
------------------------------------------------------------
minimapButton:SetScript("OnClick", function()
    if panelOpen then
        HideUIPanel(SettingsPanel)
        panelOpen = false
    else
        Settings.OpenToCategory(category:GetID())
        panelOpen = true
    end
end)

------------------------------------------------------------
-- Dragging
------------------------------------------------------------
minimapButton:SetScript("OnDragStart", function(self)
    self.isDragging = true
end)

minimapButton:SetScript("OnDragStop", function(self)
    self.isDragging = false
end)

minimapButton:SetScript("OnUpdate", function(self)
    if not self.isDragging then return end

    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()

    cx = cx / scale
    cy = cy / scale

    local angle = math.deg(math.atan2(cy - my, cx - mx))
    GearTradeTrackerDB.minimapAngle = angle

    UpdateMinimapButtonPosition()
end)

------------------------------------------------------------
-- Character Selection Dropdown
------------------------------------------------------------
local dropdown = CreateFrame("Frame", "GTT_CharacterDropdown", tabOverview.content, "UIDropDownMenuTemplate")
dropdown:SetPoint("TOPLEFT", tabOverview.content, "TOPLEFT", -16, 0)

local function GetAllCharacterKeys()
    local keys = {}
    for key, value in pairs(GearTradeTrackerDB) do
        if type(value) == "table" and key ~= "targetItemLevel" and key ~= "minimapAngle" then
            table.insert(keys, key)
        end
    end
    table.sort(keys)
    return keys
end

local function OnCharacterSelected(self, arg1)
    SelectedCharacter = arg1
    UIDropDownMenu_SetText(dropdown, arg1)
    RefreshCharacterOverview()
end

UIDropDownMenu_Initialize(dropdown, function(self, level)
    local keys = GetAllCharacterKeys()
    for _, key in ipairs(keys) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = key
        info.arg1 = key
        info.func = OnCharacterSelected
        info.checked = (SelectedCharacter == key)
        UIDropDownMenu_AddButton(info)
    end
end)

------------------------------------------------------------
-- Target Item Level Slider
------------------------------------------------------------
local slider = CreateFrame("Slider", nil, tabOverview.content, "OptionsSliderTemplate")
slider:SetPoint("LEFT", GTT_CharacterDropdownButton, "RIGHT", 26, 0)
slider:SetWidth(200)
slider:SetMinMaxValues(MIN_TARGET_ILVL, MAX_TARGET_ILVL)
slider:SetValueStep(1)
slider:SetObeyStepOnDrag(true)

-- Label text
slider.Text:SetText("Target Item Level")
slider.Low:SetText(MIN_TARGET_ILVL)
slider.High:SetText(MAX_TARGET_ILVL)

-- Set initial value
slider:SetValue(GearTradeTrackerDB.targetItemLevel)

------------------------------------------------------------
-- Numeric Input Box
------------------------------------------------------------
local editBox = CreateFrame("EditBox", nil, tabOverview.content, "InputBoxTemplate")
editBox:SetSize(60, 30)
editBox:SetPoint("LEFT", slider, "RIGHT", 36, 0)
editBox:SetAutoFocus(false)
editBox:SetNumeric(true)

-- Replace Blizzard's OnShow so it can't clear the text
editBox:SetScript("OnShow", function(self)
    editBox:SetNumber(GearTradeTrackerDB.targetItemLevel)
    editBox:SetCursorPosition(0)
    editBox:HighlightText(0, 0)
end)
------------------------------------------------------------
-- Hint Button (Tooltip)
------------------------------------------------------------
local hintButton = CreateFrame("Button", nil, tabOverview.content)
hintButton:SetSize(20, 20)
hintButton:SetPoint("LEFT", editBox, "RIGHT", 0, 0)

local hintIcon = hintButton:CreateTexture(nil, "ARTWORK")
hintIcon:SetAllPoints()
hintIcon:SetTexture("Interface\\COMMON\\help-i") -- Blizzard's default "i" icon

hintButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Item Level Reference", 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(" +0: 240", 0.8, 0.8, 0.8)
    GameTooltip:AddLine(" +2: 250", 0.8, 0.8, 0.8)
    GameTooltip:AddLine(" +4: 253", 0.8, 0.8, 0.8)
    GameTooltip:AddLine(" +5: 256", 0.8, 0.8, 0.8)
    GameTooltip:AddLine(" +6: 259", 0.8, 0.8, 0.8)
    GameTooltip:AddLine(" +8: 263", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("+10: 266", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)

hintButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)


------------------------------------------------------------
-- Sync slider → editbox
------------------------------------------------------------
slider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    GearTradeTrackerDB.targetItemLevel = value
    editBox:SetNumber(value)

    RefreshCharacterOverview() -- update colors live
end)

------------------------------------------------------------
-- Sync editbox → slider
------------------------------------------------------------
editBox:SetScript("OnEnterPressed", function(self)
    local value = tonumber(self:GetText())
    if value then
        value = math.min(MAX_TARGET_ILVL, math.max(MIN_TARGET_ILVL, value))
        GearTradeTrackerDB.targetItemLevel = value
        slider:SetValue(value)
    end
    self:ClearFocus()
end)

------------------------------------------------------------
-- Character Slot Overview (NO SCROLLBAR)
------------------------------------------------------------
local overviewTitle = tabOverview.content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
overviewTitle:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 40, -20)

-- Simple container frame (no scroll)
local overviewFrame = CreateFrame("Frame", nil, tabOverview.content)
overviewFrame:SetPoint("TOPLEFT", overviewTitle, "BOTTOMLEFT", 0, -10)
overviewFrame:SetPoint("BOTTOMRIGHT", tabOverview.content, "BOTTOMRIGHT", -10, 10)

-- This is where lines will be added
local overviewChild = CreateFrame("Frame", nil, overviewFrame)
overviewChild:SetPoint("TOPLEFT")
overviewChild:SetPoint("TOPRIGHT")
overviewChild:SetHeight(1) -- will expand dynamically


function RefreshCharacterOverview()
    if isRefreshing then return end
    isRefreshing = true

    -- Clear previous lines
    for _, child in ipairs({overviewChild:GetChildren()}) do
        child:Hide()
    end

    local key = SelectedCharacter or GetCharKey()
    local data = GearTradeTrackerDB[key] or {}
    local playerClass = data.CLASS

    ------------------------------------------------------------
    -- Layout configuration
    ------------------------------------------------------------
    local col1X = 0
    local col2X = 220
    local rowHeight = 22

    local rowLeft = 0
    local rowRight = 0

    local function AddLine(parent, x, y, labelText, valueText)
        local line = CreateFrame("Frame", nil, parent)
        line:SetSize(200, 20)
        line:SetPoint("TOPLEFT", x, y)

        local label = line:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT")
        label:SetText(labelText)

        local value = line:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        value:SetPoint("LEFT", label, "RIGHT", 10, 0)
        value:SetText(valueText)

        return line
    end

    ------------------------------------------------------------
    -- Column definitions (mirroring WoW character sheet)
    ------------------------------------------------------------
    local LeftColumnOrder = {
        "HEAD",
        "NECK",
        "SHOULDER",
        "BACK",
        "CHEST",
        "WRIST",
    }

    local RightColumnOrder = {
        "HANDS",
        "WAIST",
        "LEGS",
        "FEET",
        "FINGER1",
        "FINGER2",
        "TRINKET1",
        "TRINKET2",
    }

    ------------------------------------------------------------
    -- Fill LEFT column (armor)
    ------------------------------------------------------------
    for _, slot in ipairs(LeftColumnOrder) do
        local ilvl = SanitizeValue(data[slot])
        local y = -rowLeft * rowHeight
        AddLine(overviewChild, col1X, y, slot .. ":", ColorizeIlvl(ilvl, GearTradeTrackerDB.targetItemLevel))
        rowLeft = rowLeft + 1
    end

    ------------------------------------------------------------
    -- Fill RIGHT column (armor)
    ------------------------------------------------------------
    for _, slot in ipairs(RightColumnOrder) do
        local ilvl = SanitizeValue(data[slot])
        local y = -rowRight * rowHeight
        AddLine(overviewChild, col2X, y, slot .. ":", ColorizeIlvl(ilvl, GearTradeTrackerDB.targetItemLevel))
        rowRight = rowRight + 1
    end

    ------------------------------------------------------------
    -- Weapons (added below left column)
    ------------------------------------------------------------
    for _, w in ipairs(AllSlots.Weapons) do
        if ClassWeaponTypes[playerClass][w.hand] then
            if not w.stat or ClassPrimaryStats[playerClass][w.stat] then

                local name = w.stat
                    and string.format("%s %s %s", w.slot, w.hand, w.stat)
                    or string.format("%s %s", w.slot, w.hand)

                local raw
                if w.stat then
                    raw = data[w.slot]
                        and data[w.slot][w.hand]
                        and data[w.slot][w.hand][w.stat]
                else
                    raw = data[w.slot]
                        and data[w.slot][w.hand]
                end

                local stored = SanitizeValue(raw)

                local y = -rowLeft * rowHeight
                AddLine(overviewChild, col1X, y, name .. ":", ColorizeIlvl(stored, GearTradeTrackerDB.targetItemLevel))
                rowLeft = rowLeft + 1
            end
        end
    end

    ------------------------------------------------------------
    -- Adjust container height
    ------------------------------------------------------------
    local totalRows = math.max(rowLeft, rowRight)
    overviewChild:SetHeight(totalRows * rowHeight + 20)

    isRefreshing = false
end


------------------------------------------------------------
-- Text Generate Button
------------------------------------------------------------

local generateButton = CreateFrame("Button", nil, tabOverview.content, "UIPanelButtonTemplate")
generateButton:SetSize(140, 25)
generateButton:SetPoint("BOTTOMRIGHT", overviewFrame, "BOTTOMRIGHT", 0, 0)
generateButton:SetText("Generate Text")

generateButton:SetScript("OnClick", function()
    local key = SelectedCharacter or GetCharKey()
    local list = GetUntradeableSlots(key)

    local grouped = GroupSlots(list)
    SortByOutputOrder(grouped)

    local text
    if #grouped == 0 then
        text = "Trade All"
    else
        text = "Can't trade: " .. table.concat(grouped, ", ")
    end

    ShowExportPopup(text)
end)


options:SetScript("OnShow", function()
    if not SelectedCharacter then
        SelectedCharacter = GetCharKey()
        UIDropDownMenu_SetText(dropdown, SelectedCharacter)
    end
    RefreshCharacterOverview()
end)



SLASH_GTTRESET1 = "/gttreset"
SlashCmdList["GTTRESET"] = function()
    print("GearTradeTracker: Clearing all saved data...")
    GearTradeTrackerDB = {}
    ReloadUI()
end


SLASH_GEARTRADETRACKER1 = "/gtt"
SlashCmdList["GEARTRADETRACKER"] = function()
    local key = GetCharKey()

    print("Armor:")
    for _, name in pairs(AllSlots) do
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

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        InitChar()

        C_Timer.After(0.5, function()
    for slotID = 1, 17 do
        if slotID ~= 4 then ProcessSlot(slotID) end
    end
    if panelOpen then RefreshCharacterOverview() end
    end)

        if GearTradeTrackerDB.targetItemLevel == nil then
            GearTradeTrackerDB.targetItemLevel = DEFAULT_TARGET_ILVL
        end

        if GearTradeTrackerDB.minimapAngle == nil then
            GearTradeTrackerDB.minimapAngle = 45
        end

        UpdateMinimapButtonPosition()
        slider:SetValue(GearTradeTrackerDB.targetItemLevel)
        editBox:SetNumber(GearTradeTrackerDB.targetItemLevel)

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        local slotID = arg1
        if slotID and slotID ~= 4 then
            ProcessSlot(slotID)
            if panelOpen then
                RefreshCharacterOverview()
            end
        end
    end
end)
