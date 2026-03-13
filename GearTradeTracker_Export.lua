-- Export popup frame for displaying untradeability results

local exportFrame = CreateFrame("Frame", "GTT_ExportFrame", UIParent, "BasicFrameTemplateWithInset")
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

local exportBox = CreateFrame("EditBox", nil, exportScroll)
exportBox:SetMultiLine(true)
exportBox:SetFontObject(ChatFontNormal)
exportBox:SetWidth(350)
exportBox:SetAutoFocus(true)
exportBox:SetScript("OnEscapePressed", function() exportFrame:Hide() end)

exportScroll:SetScrollChild(exportBox)

function GearTradeTracker_ShowExportPopup(text)
    exportFrame:Show()
    exportBox:SetText(text)
    exportBox:HighlightText()
end
