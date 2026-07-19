local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.Core = NS.Core or {}
NS.Core.ConfigPanel = NS.Core.ConfigPanel or {}
local ConfigPanel = NS.Core.ConfigPanel

function ConfigPanel:Initialize()
    if self.initialized then return true end
    self.initialized = true
    local panel = CreateFrame("Frame", "EllesmereUIVEOptionsPanel", UIParent)
    panel.name = "EllesmereUIVE"
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -18); title:SetText("EllesmereUIVE")
    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)
    description:SetWidth(600); description:SetJustifyH("LEFT")
    description:SetText("Voice editor for EllesmereUI Cooldown Manager, with cast-success and Bloodlust voice alerts.")
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(190, 30); open:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -20)
    open:SetText("Open EllesmereUIVE"); open:SetScript("OnClick", function() NS:OpenMainFrame() end)
    self.panel = panel
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "EllesmereUIVE")
        Settings.RegisterAddOnCategory(category); self.categoryID = category and category.ID
    elseif InterfaceOptions_AddCategory then InterfaceOptions_AddCategory(panel) end
    return true
end
