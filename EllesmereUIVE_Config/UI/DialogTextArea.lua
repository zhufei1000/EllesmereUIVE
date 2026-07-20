local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.DialogTextArea = NS.UI.DialogTextArea or {}

local DialogTextArea = NS.UI.DialogTextArea
local Skin = NS.UI.Skin

function DialogTextArea:Create(parent, width, height)
    width = tonumber(width) or 650
    height = tonumber(height) or 300

    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate,BackdropTemplate")
    scrollFrame:SetSize(width, height)
    if Skin and Skin.ApplyWindowChrome then
        Skin:ApplyWindowChrome(scrollFrame, { inset = true, noFooter = true, noTopLine = true, topHeight = 0 })
    end

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetSize(math.max(1, width - 34), height)
    editBox:SetTextInsets(8, 8, 8, 8)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    editBox:SetScript("OnTextChanged", function(self)
        local textHeight = self:GetHeight() or height
        if self.GetNumLines then
            textHeight = math.max(height, (self:GetNumLines() or 1) * 18 + 20)
        end
        self:SetHeight(textHeight)
    end)
    scrollFrame:SetScrollChild(editBox)

    local function FindOuterScrollable(frame)
        local p = frame and frame:GetParent()
        while p do
            if p.ScrollBy and type(p.ScrollBy) == "function" then
                return p
            end
            p = p.GetParent and p:GetParent() or nil
        end
    end

    local function ClampScroll(value, minValue, maxValue)
        value = tonumber(value) or 0
        minValue = tonumber(minValue) or 0
        maxValue = tonumber(maxValue) or 0
        if value < minValue then return minValue end
        if value > maxValue then return maxValue end
        return value
    end

    local function OnWheel(self, delta)
        local range = scrollFrame.GetVerticalScrollRange and (scrollFrame:GetVerticalScrollRange() or 0) or 0
        local current = scrollFrame.GetVerticalScroll and (scrollFrame:GetVerticalScroll() or 0) or 0
        local atTop = current <= 0.5
        local atBottom = current >= (range - 0.5)
        local canScrollInner = range > 1 and not ((delta or 0) > 0 and atTop) and not ((delta or 0) < 0 and atBottom)
        if canScrollInner then
            scrollFrame:SetVerticalScroll(ClampScroll(current - ((delta or 0) * 54), 0, range))
            return
        end
        local outer = FindOuterScrollable(scrollFrame)
        if outer then
            outer:ScrollBy(delta)
        end
    end

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", OnWheel)
    editBox:EnableMouseWheel(true)
    editBox:SetScript("OnMouseWheel", OnWheel)

    if Skin and Skin.SkinEditBox then
        Skin:SkinEditBox(editBox)
    end

    local scrollBar = scrollFrame.ScrollBar or (scrollFrame.GetName and rawget(_G, tostring(scrollFrame:GetName() or "") .. "ScrollBar"))
    if scrollBar and Skin and Skin.SkinScrollBar then
        Skin:SkinScrollBar(scrollBar)
    end

    return scrollFrame, editBox
end
