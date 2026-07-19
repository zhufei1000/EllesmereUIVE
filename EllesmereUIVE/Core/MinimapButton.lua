local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.Core = NS.Core or {}
NS.Core.MinimapButton = NS.Core.MinimapButton or {}
local MinimapButton = NS.Core.MinimapButton

function MinimapButton:Initialize()
    if self.initialized then return true end
    local libStub = rawget(_G, "LibStub")
    local ldb = type(libStub) == "table" and libStub:GetLibrary("LibDataBroker-1.1", true) or nil
    local icon = type(libStub) == "table" and libStub:GetLibrary("LibDBIcon-1.0", true) or nil
    if not ldb or not icon then return false end
    local broker = ldb:NewDataObject("EllesmereUIVE", {
        type = "launcher",
        text = "EllesmereUIVE",
        icon = "Interface\\AddOns\\EllesmereUIVE\\AppIcon.png",
        OnClick = function(_, button)
            if button == "RightButton" then
                EllesmereUIVEDB.minimap.hide = true
                icon:Hide("EllesmereUIVE")
            elseif NS.ToggleMainFrame then
                NS:ToggleMainFrame()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("EllesmereUIVE")
            tooltip:AddLine("Left click: open settings", 0.8, 0.8, 0.8)
            tooltip:AddLine("Right click: hide minimap button", 0.8, 0.8, 0.8)
        end,
    })
    icon:Register("EllesmereUIVE", broker, EllesmereUIVEDB.minimap)
    self.icon = icon
    self.initialized = true
    return true
end

function MinimapButton:SetShown(shown)
    if not self.initialized then self:Initialize() end
    if not self.icon then return false end
    EllesmereUIVEDB.minimap.hide = not shown
    if shown then self.icon:Show("EllesmereUIVE") else self.icon:Hide("EllesmereUIVE") end
    return true
end
