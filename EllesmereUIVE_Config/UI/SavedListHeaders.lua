local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.SavedListHeaders = NS.UI.SavedListHeaders or {}

local Headers = NS.UI.SavedListHeaders
local Skin = NS.UI.Skin

local HEADER_HEIGHT = 32

function Headers:GetHeight()
    return HEADER_HEIGHT
end

function Headers:EnsureHeader(list, index)
    if not list then
        return nil
    end
    list.headers = list.headers or {}
    if list.headers[index] then
        return list.headers[index]
    end

    local header = Skin and Skin:CreateSectionHeader(list.content, "") or CreateFrame("Button", nil, list.content)
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("LEFT", list.content, "LEFT", 0, 0)
    header:SetPoint("RIGHT", list.content, "RIGHT", -4, 0)

    local arrow = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrow:SetPoint("RIGHT", header, "RIGHT", -8, 0)
    if Skin then
        Skin:StyleFont(arrow, "accent")
    end
    arrow:SetText("-")
    header.arrow = arrow

    if type(header.rightLine) == "table" and type(header.label) == "table" then
        header.rightLine:ClearAllPoints()
        header.rightLine:SetPoint("LEFT", header.label, "RIGHT", 10, 0)
        header.rightLine:SetPoint("RIGHT", arrow, "LEFT", -8, 0)
    end

    local function ToggleHeaderCollapse()
        list.state = list.state or {}
        if header.sectionKey == "loaded" then
            list.state.loadedCollapsed = not (list.state.loadedCollapsed == true)
        else
            list.state.unloadedCollapsed = not (list.state.unloadedCollapsed == true)
        end
        -- Header collapse only changes visibility. Prefer cached rendering so we
        -- do not rebuild all saved/group layout data for a simple open/close.
        if type(list.RenderCached) == "function" and list:RenderCached() then
            return
        end
        if type(list.Refresh) == "function" then
            list:Refresh()
        end
    end

    if header.EnableMouse then
        header:EnableMouse(true)
    end

    if header.IsObjectType and header:IsObjectType("Button") then
        if header.RegisterForClicks then
            header:RegisterForClicks("LeftButtonUp")
        end
        header:SetScript("OnClick", function(_, button)
            if button and button ~= "LeftButton" then
                return
            end
            ToggleHeaderCollapse()
        end)
    else
        header:SetScript("OnMouseUp", function(_, button)
            if button and button ~= "LeftButton" then
                return
            end
            ToggleHeaderCollapse()
        end)
    end

    list.headers[index] = header
    return header
end
