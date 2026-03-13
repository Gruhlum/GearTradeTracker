-- Minimap button integration with LibDBIcon and LibDataBroker

local minimapIcon = LibStub("LibDBIcon-1.0")
local minimapInitialized = false

-- Create the LDB object (this defines the minimap button)
local GTT_LDB = LibStub("LibDataBroker-1.1"):NewDataObject("GearTradeTracker", {
    type = "launcher",
    icon = "Interface\\AddOns\\GearTradeTracker\\icon.tga",
    label = "GearTradeTracker",

    OnClick = function(_, button)
        GearTradeTracker_ToggleUI()
    end,

    OnTooltipShow = function(tooltip)
        tooltip:AddLine("GearTradeTracker")
    end,
})

function GearTradeTracker_InitMinimap()
    -- avoid repeating registration if called multiple times
    if minimapInitialized then return end
    minimapInitialized = true

    GearTradeTrackerDB = GearTradeTrackerDB or {}
    GearTradeTrackerDB.minimap = GearTradeTrackerDB.minimap or { hide = false }

    minimapIcon:Register("GearTradeTracker", GTT_LDB, GearTradeTrackerDB.minimap)

    if GearTradeTrackerDB.minimap.hide then
        minimapIcon:Hide("GearTradeTracker")
    else
        minimapIcon:Show("GearTradeTracker")
    end
end

function GearTradeTracker_ToggleMinimap()
    local db = GearTradeTrackerDB.minimap
    db.hide = not db.hide

    if db.hide then
        minimapIcon:Hide("GearTradeTracker")
    else
        minimapIcon:Show("GearTradeTracker")
    end
end

-- Defined in UI module but declared here for reference
-- function GearTradeTracker_ToggleUI() is in GearTradeTracker_UI.lua
