-- UI panels, frames, and display logic

local MIN_TARGET_ILVL = 224
local MAX_TARGET_ILVL = 282
local DEFAULT_TARGET_ILVL = 272

local panelOpen = false
local SelectedCharacter = nil
local isRefreshing = false
isInitializingSlider = false

-- UI elements that must be accessible from multiple scopes
local slider, editBox, hintButton
local overviewTitle, overviewFrame, overviewChild

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

local tabOverview = CreateTab(options, 1, "Overview")
local settings = CreateTab(options, 2, "Settings")

-- Hook the tab content to sync slider when visible
tabOverview.content:HookScript("OnShow", function()
    -- Ensure targetItemLevel exists
    if not GearTradeTrackerDB then GearTradeTrackerDB = {} end
    if not GearTradeTrackerDB.targetItemLevel then 
        GearTradeTrackerDB.targetItemLevel = DEFAULT_TARGET_ILVL
    end
    
    -- Update slider to match saved value without triggering OnValueChanged
    if slider then
        isInitializingSlider = true
        slider:SetValue(GearTradeTrackerDB.targetItemLevel)
        editBox:SetNumber(GearTradeTrackerDB.targetItemLevel)
        isInitializingSlider = false
    end
end)

local title = tabOverview.content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, 0)

-- Register parent category
local category = Settings.RegisterCanvasLayoutCategory(options, "GearTradeTracker")
Settings.RegisterAddOnCategory(category)
SelectTab(1)
options:HookScript("OnHide", function()
    panelOpen = false
end)

function GearTradeTracker_ToggleUI()
    if panelOpen then
        HideUIPanel(SettingsPanel)
        panelOpen = false
    else
        Settings.OpenToCategory(category:GetID())
        panelOpen = true
    end
end

------------------------------------------------------------
-- Overview Tab: Character Selection
------------------------------------------------------------
local dropdown = CreateFrame("Frame", "GTT_CharacterDropdown", tabOverview.content, "UIDropDownMenuTemplate")
dropdown:SetPoint("TOPLEFT", tabOverview.content, "TOPLEFT", -16, 0)

local function GetAllCharacterKeys()
    local keys = {}
    local reservedKeys = {
        targetItemLevel = true,
        settings = true,
        minimap = true,
        characters = true,
    }
    
    for key in pairs(GearTradeTrackerDB) do
        if not reservedKeys[key] and type(GearTradeTrackerDB[key]) == "table" then
            local record = GearTradeTrackerDB[key]
            if record.CLASS or record.HEAD or record.MAINHAND or record.OFFHAND then
                table.insert(keys, key)
            end
        end
    end
    
    table.sort(keys)
    return keys
end

local function OnCharacterSelected(self, arg1)
    SelectedCharacter = arg1
    UIDropDownMenu_SetText(dropdown, arg1)
    GearTradeTracker_RefreshCharacterOverview()
end

-- Build UI for overview tab
slider = CreateFrame("Slider", nil, tabOverview.content, "OptionsSliderTemplate")
slider:SetPoint("LEFT", GTT_CharacterDropdownButton, "RIGHT", 26, 0)
slider:SetWidth(200)
slider:SetMinMaxValues(MIN_TARGET_ILVL, MAX_TARGET_ILVL)
slider:SetValue(MIN_TARGET_ILVL)
slider:SetValueStep(1)
slider:SetObeyStepOnDrag(true)

slider.Text:SetText("Target Item Level")
slider.Low:SetText(MIN_TARGET_ILVL)
slider.High:SetText(MAX_TARGET_ILVL)

editBox = CreateFrame("EditBox", nil, tabOverview.content, "InputBoxTemplate")
editBox:SetSize(60, 30)
editBox:SetPoint("LEFT", slider, "RIGHT", 36, 0)
editBox:SetAutoFocus(false)
editBox:SetNumeric(true)

editBox:SetScript("OnShow", function(self)
    if GearTradeTrackerDB and GearTradeTrackerDB.targetItemLevel then
        editBox:SetNumber(GearTradeTrackerDB.targetItemLevel)
    end
    editBox:SetCursorPosition(0)
    editBox:HighlightText(0, 0)
end)

hintButton = CreateFrame("Button", nil, tabOverview.content)
hintButton:SetSize(20, 20)
hintButton:SetPoint("LEFT", editBox, "RIGHT", 0, 0)

local hintIcon = hintButton:CreateTexture(nil, "ARTWORK")
hintIcon:SetAllPoints()
hintIcon:SetTexture("Interface\\COMMON\\help-i")

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

-- Sync slider ↔ editbox
slider:SetScript("OnValueChanged", function(self, value)
    if isInitializingSlider then return end
    
    value = math.floor(value + 0.5)
    GearTradeTrackerDB.targetItemLevel = value
    editBox:SetNumber(value)
    GearTradeTracker_RefreshCharacterOverview()
end)

editBox:SetScript("OnEnterPressed", function(self)
    local value = tonumber(self:GetText())
    if value then
        value = math.min(MAX_TARGET_ILVL, math.max(MIN_TARGET_ILVL, value))
        GearTradeTrackerDB.targetItemLevel = value
        slider:SetValue(value)
    end
    self:ClearFocus()
end)

-- Overview container
overviewTitle = tabOverview.content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
overviewTitle:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 40, -20)

overviewFrame = CreateFrame("Frame", nil, tabOverview.content)
overviewFrame:SetPoint("TOPLEFT", overviewTitle, "BOTTOMLEFT", 0, -10)
overviewFrame:SetPoint("BOTTOMRIGHT", tabOverview.content, "BOTTOMRIGHT", -10, 10)

overviewChild = CreateFrame("Frame", nil, overviewFrame)
overviewChild:SetPoint("TOPLEFT")
overviewChild:SetPoint("TOPRIGHT")
overviewChild:SetHeight(1)

------------------------------------------------------------
-- Character Overview Display
------------------------------------------------------------
function GearTradeTracker_RefreshCharacterOverview()
    if isRefreshing then return end
    isRefreshing = true

    -- Clear previous lines
    for _, child in ipairs({overviewChild:GetChildren()}) do
        child:Hide()
    end

    local key = SelectedCharacter or GearTradeTracker_GetCharKey()
    local data = GearTradeTrackerDB[key] or {}
    local playerClass = data.CLASS

    if not playerClass then
        GearTradeTracker_InitChar()
        data = GearTradeTrackerDB[key] or {}
        playerClass = data.CLASS
    end

    -- Layout configuration
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

    -- Fill LEFT column (armor)
    for _, slot in ipairs(LeftColumnOrder) do
        local ilvl = (type(data[slot]) == "number" and data[slot]) or nil
        local y = -rowLeft * rowHeight
        AddLine(overviewChild, col1X, y, slot .. ":", GearTradeTracker_ColorizeIlvl(ilvl, GearTradeTrackerDB.targetItemLevel))
        rowLeft = rowLeft + 1
    end

    -- Fill RIGHT column (armor)
    for _, slot in ipairs(RightColumnOrder) do
        local ilvl = (type(data[slot]) == "number" and data[slot]) or nil
        local y = -rowRight * rowHeight
        AddLine(overviewChild, col2X, y, slot .. ":", GearTradeTracker_ColorizeIlvl(ilvl, GearTradeTrackerDB.targetItemLevel))
        rowRight = rowRight + 1
    end

    -- Weapons (added below left column)
    if playerClass and GearTradeTracker_ClassWeaponTypes[playerClass] then
        for _, w in ipairs(GearTradeTracker_AllSlots.Weapons) do
            -- Skip OFFHAND 1H weapons for classes that don't get them as drops
            local skipWeapon = (w.slot == "OFFHAND" and w.hand == "1H" and playerClass ~= "DEMONHUNTER" and playerClass ~= "MONK")
            if not skipWeapon then
                if GearTradeTracker_ClassWeaponTypes[playerClass][w.hand] then
                    if not w.stat or (GearTradeTracker_ClassPrimaryStats[playerClass] and GearTradeTracker_ClassPrimaryStats[playerClass][w.stat]) then
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

                        local stored = (type(raw) == "number" and raw) or nil

                        local y = -rowLeft * rowHeight
                        AddLine(overviewChild, col1X, y, name .. ":", GearTradeTracker_ColorizeIlvl(stored, GearTradeTrackerDB.targetItemLevel))
                        rowLeft = rowLeft + 1
                    end
                end
            end
        end
    end

    -- Adjust container height
    local totalRows = math.max(rowLeft, rowRight)
    overviewChild:SetHeight(totalRows * rowHeight + 20)

    isRefreshing = false
end

-- Generate Text Button
local generateButton = CreateFrame("Button", nil, tabOverview.content, "UIPanelButtonTemplate")
generateButton:SetSize(140, 25)
generateButton:SetPoint("BOTTOMRIGHT", overviewFrame, "BOTTOMRIGHT", 0, 0)
generateButton:SetText("Generate Text")

generateButton:SetScript("OnClick", function()
    local key = SelectedCharacter or GearTradeTracker_GetCharKey()
    local data = GearTradeTrackerDB[key] or {}
    local playerClass = data.CLASS
    
    local list = GearTradeTracker_GetUntradeableSlots(key)

    local grouped = GearTradeTracker_GroupSlots(list)
    GearTradeTracker_SortByOutputOrder(grouped)

    -- Count untradeeable weapons
    local untradeableWeaponCount = 0
    local filtered = {}
    
    for _, slot in ipairs(grouped) do
        if string.find(slot, "MAINHAND") or string.find(slot, "OFFHAND") then
            untradeableWeaponCount = untradeableWeaponCount + 1
        else
            table.insert(filtered, slot)
        end
    end
    
    -- Count total tradeable weapons for this class
    local totalTradeableWeapons = 0
    if playerClass and GearTradeTracker_ClassWeaponTypes[playerClass] then
        for _, w in ipairs(GearTradeTracker_AllSlots.Weapons) do
            local skipWeapon = (w.slot == "OFFHAND" and w.hand == "1H" and playerClass ~= "DEMONHUNTER" and playerClass ~= "MONK")
            if not skipWeapon then
                if w.stat then
                    if GearTradeTracker_ClassPrimaryStats[playerClass] and GearTradeTracker_ClassPrimaryStats[playerClass][w.stat] then
                        if GearTradeTracker_ClassWeaponTypes[playerClass][w.hand] then
                            totalTradeableWeapons = totalTradeableWeapons + 1
                        end
                    end
                else
                    if GearTradeTracker_ClassWeaponTypes[playerClass][w.hand] then
                        totalTradeableWeapons = totalTradeableWeapons + 1
                    end
                end
            end
        end
    end
    
    -- Only show "WEAPONS" if ALL tradeable weapons are untradeeable
    if untradeableWeaponCount > 0 and untradeableWeaponCount == totalTradeableWeapons then
        table.insert(filtered, "WEAPONS")
        GearTradeTracker_SortByOutputOrder(filtered)
    else
        filtered = grouped
    end

    local text
    if #filtered == 0 then
        text = "Trade All"
    else
        text = "Can't trade: " .. table.concat(filtered, ", ")
    end

    GearTradeTracker_ShowExportPopup(text)
end)

options:SetScript("OnShow", function()
    if not SelectedCharacter then
        SelectedCharacter = GearTradeTracker_GetCharKey()
        UIDropDownMenu_SetText(dropdown, SelectedCharacter)
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

    GearTradeTracker_RefreshCharacterOverview()
end)

------------------------------------------------------------
-- Settings Tab
------------------------------------------------------------
local settingsContent = settings.content

local settingsTitle = settingsContent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
settingsTitle:SetPoint("TOPLEFT", 16, 0)

local charLabel = settingsContent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
charLabel:SetPoint("TOPLEFT", settingsTitle, "BOTTOMLEFT", 0, -20)
charLabel:SetText("Select Character:")

local settingsDropdown = CreateFrame("Frame", "GTT_SettingsCharacterDropdown", settingsContent, "UIDropDownMenuTemplate")
settingsDropdown:SetPoint("TOPLEFT", charLabel, "BOTTOMLEFT", -15, -5)

local function SettingsDropdown_OnClick(self)
    UIDropDownMenu_SetSelectedValue(settingsDropdown, self.value)
end

local function SettingsDropdown_Initialize()
    if not GearTradeTrackerDB then return end
    
    local info = UIDropDownMenu_CreateInfo()
    local reservedKeys = {
        targetItemLevel = true,
        settings = true,
        minimap = true,
        characters = true,
    }

    for key in pairs(GearTradeTrackerDB) do
        if not reservedKeys[key] and type(GearTradeTrackerDB[key]) == "table" then
            local record = GearTradeTrackerDB[key]
            if record.CLASS or record.HEAD or record.MAINHAND or record.OFFHAND then
                info.text = key
                info.value = key
                info.func = SettingsDropdown_OnClick
                UIDropDownMenu_AddButton(info)
            end
        end
    end
end

UIDropDownMenu_SetWidth(settingsDropdown, 160)
UIDropDownMenu_Initialize(settingsDropdown, SettingsDropdown_Initialize)

local deleteCharButton = CreateFrame("Button", nil, settingsContent, "UIPanelButtonTemplate")
deleteCharButton:SetSize(180, 24)
deleteCharButton:SetPoint("TOPLEFT", settingsDropdown, "BOTTOMLEFT", 20, -10)
deleteCharButton:SetText("Delete Selected Character")

deleteCharButton:SetScript("OnClick", function()
    local selected = UIDropDownMenu_GetSelectedValue(settingsDropdown)
    if selected and GearTradeTrackerDB[selected] then
        GearTradeTrackerDB[selected] = nil
        print("GearTradeTracker: Deleted character:", selected)
        UIDropDownMenu_SetSelectedValue(settingsDropdown, nil)
        UIDropDownMenu_Initialize(settingsDropdown, SettingsDropdown_Initialize)
    end
end)

local clearDBButton = CreateFrame("Button", nil, settingsContent, "UIPanelButtonTemplate")
clearDBButton:SetSize(180, 24)
clearDBButton:SetPoint("TOPLEFT", deleteCharButton, "BOTTOMLEFT", 0, -10)
clearDBButton:SetText("Clear Entire Database")

clearDBButton:SetScript("OnClick", function()
    local reservedKeys = { targetItemLevel = true, settings = true, minimap = true, characters = true }
    for key in pairs(GearTradeTrackerDB) do
        if not reservedKeys[key] then
            GearTradeTrackerDB[key] = nil
        end
    end
    print("GearTradeTracker: All character data cleared.")
    UIDropDownMenu_SetSelectedValue(settingsDropdown, nil)
    UIDropDownMenu_Initialize(settingsDropdown, SettingsDropdown_Initialize)
end)

local minimapLabel = settingsContent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
minimapLabel:SetPoint("TOPLEFT", clearDBButton, "BOTTOMLEFT", 0, -20)
minimapLabel:SetText("Minimap Button:")

local minimapCheckbox = CreateFrame("CheckButton", nil, settingsContent, "UICheckButtonTemplate")
minimapCheckbox:SetPoint("LEFT", minimapLabel, "RIGHT", 10, 0)

minimapCheckbox:SetScript("OnClick", function(self)
    local hide = not self:GetChecked()
    GearTradeTrackerDB.minimap.hide = hide

    if hide then
        LibStub("LibDBIcon-1.0"):Hide("GearTradeTracker")
    else
        LibStub("LibDBIcon-1.0"):Show("GearTradeTracker")
    end
end)

C_Timer.After(0.1, function()
    if GearTradeTrackerDB.minimap then
        minimapCheckbox:SetChecked(not GearTradeTrackerDB.minimap.hide)
    end
end)
