local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.Widgets = NS.UI.Widgets or {}

local Widgets = NS.UI.Widgets
local ScrollBar = NS.UI.ScrollBar
local WidgetUtils = NS.UI.WidgetUtils or {}
local SafeCreateFrame = WidgetUtils.SafeCreateFrame
local Clamp = WidgetUtils.Clamp

function Widgets:CreateScrollableContent(parent, opts)
    opts = opts or {}
    local host = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    host:EnableMouse(true)
    self:ApplyPanelChrome(host, { inset = true, noFooter = true, topHeight = opts.topHeight or 16, noTopLine = true })

    local scrollFrame = CreateFrame("ScrollFrame", nil, host)
    scrollFrame:SetPoint("TOPLEFT", host, "TOPLEFT", opts.leftInset or 0, -(opts.topInset or 0))
    scrollFrame:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -(opts.scrollBarWidth or 22), opts.bottomInset or 0)
    scrollFrame:EnableMouseWheel(true)
    if scrollFrame.SetClipsChildren then
        scrollFrame:SetClipsChildren(true)
    end

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetPoint("TOPLEFT", 0, 0)
    content:SetHeight(opts.contentHeight or 1)
    content:SetWidth(opts.contentWidth or math.max(1, ((parent and parent.GetWidth and parent:GetWidth()) or 700) - 60))
    scrollFrame:SetScrollChild(content)

    local slider = ScrollBar and ScrollBar.Create and ScrollBar:Create(host, nil, {
        orientation = "VERTICAL",
        width = 16,
        minValue = 0,
        maxValue = 0,
        valueStep = 1,
        value = 0,
        obeyStepOnDrag = false,
    }) or SafeCreateFrame("Slider", nil, host, {
        "UIPanelScrollBarTemplate",
        "OptionsSliderTemplate",
        "BackdropTemplate",
    })
    if ScrollBar and ScrollBar.ClearInheritedScripts then
        ScrollBar:ClearInheritedScripts(slider)
    end
    slider:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 6, -16)
    slider:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 6, 16)
    slider:Hide()

    local lastScrollHasBar = nil
    local lastViewportWidth = 0
    local lastMaxScroll = -1

    local function ApplyScrollFrameAnchors(hasBar)
        if lastScrollHasBar == hasBar then
            return
        end
        lastScrollHasBar = hasBar
        scrollFrame:ClearAllPoints()
        scrollFrame:SetPoint("TOPLEFT", host, "TOPLEFT", opts.leftInset or 0, -(opts.topInset or 0))
        scrollFrame:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", hasBar and -(opts.scrollBarWidth or 22) or 0, opts.bottomInset or 0)
    end

    local function UpdateScrollRange()
        local viewportHeight = scrollFrame:GetHeight() or 0
        local viewportWidth = scrollFrame:GetWidth() or 0
        if viewportWidth and viewportWidth > 1 and math.abs(viewportWidth - lastViewportWidth) > 0.5 then
            lastViewportWidth = viewportWidth
            content:SetWidth(viewportWidth)
        end
        local contentHeight = (content:GetHeight() or 1) + (opts.bottomPadding or 30)
        local maxScroll = math.max(0, contentHeight - viewportHeight)
        local current = Clamp(slider:GetValue() or 0, 0, maxScroll)
        if math.abs(maxScroll - lastMaxScroll) > 0.5 then
            lastMaxScroll = maxScroll
            slider:SetMinMaxValues(0, maxScroll)
            slider:SetValueStep(1)
        end
        local hasBar = maxScroll > 1
        if hasBar then
            slider:Show()
        else
            slider:Hide()
        end
        ApplyScrollFrameAnchors(hasBar)
        if math.abs((slider:GetValue() or 0) - current) > 0.5 then
            slider:SetValue(current)
        end
        if math.abs((scrollFrame:GetVerticalScroll() or 0) - current) > 0.5 then
            scrollFrame:SetVerticalScroll(current)
        end
    end

    local function ScrollBy(delta)
        local minValue, maxValue = slider:GetMinMaxValues()
        local step = tonumber(opts.wheelStep) or 78
        local rawValue = (slider:GetValue() or 0) - ((delta or 0) * step)
        slider:SetValue(Clamp(rawValue, minValue or 0, maxValue or 0))
    end

    slider:SetScript("OnValueChanged", function(_, value)
        scrollFrame:SetVerticalScroll(math.floor((value or 0) + 0.5))
    end)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        ScrollBy(delta)
    end)
    host:EnableMouseWheel(true)
    host:SetScript("OnMouseWheel", function(_, delta)
        ScrollBy(delta)
    end)
    scrollFrame:SetScript("OnSizeChanged", function(_, width)
        if width and width > 0 then
            content:SetWidth(width)
        end
        UpdateScrollRange()
    end)

    function host:SetContentWidth(width)
        content:SetWidth(math.max(1, tonumber(width) or 1))
        UpdateScrollRange()
    end

    function host:SetContentHeight(height)
        content:SetHeight(math.max(1, tonumber(height) or 1))
        UpdateScrollRange()
    end

    function host:UpdateScrollRange()
        UpdateScrollRange()
    end

    function host:ScrollBy(delta)
        ScrollBy(delta)
    end

    host.scrollFrame = scrollFrame
    host.content = content
    host.slider = slider
    return host, content, scrollFrame, slider
end
