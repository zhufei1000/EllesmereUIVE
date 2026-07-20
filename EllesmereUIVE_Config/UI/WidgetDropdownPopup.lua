local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.Widgets = NS.UI.Widgets or {}
NS.UI.WidgetDropdownPopup = NS.UI.WidgetDropdownPopup or {}

local Widgets = NS.UI.Widgets
local Popup = NS.UI.WidgetDropdownPopup
local ScrollBar = NS.UI.ScrollBar
local WidgetUtils = NS.UI.WidgetUtils or {}
local MakeSingleLine = WidgetUtils.MakeSingleLine
local SafeCreateFrame = WidgetUtils.SafeCreateFrame
local Clamp = WidgetUtils.Clamp

local DROPDOWN_ROW_HEIGHT = 22
local DROPDOWN_MAX_VISIBLE_ROWS = 10
local DROPDOWN_POPUP_PADDING = 6
local DROPDOWN_AUTO_CLOSE_DELAY = 0.20
local DROPDOWN_SEARCH_HEIGHT = 30

local function NormalizeSearchText(value)
    return tostring(value or "")
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
        :gsub("|T.-|t", " ")
        :gsub("|A.-|a", " ")
        :lower()
end

local function FilterItems(items, query)
    local filtered = {}
    query = NormalizeSearchText(query)
    for index, item in ipairs(type(items) == "table" and items or {}) do
        local haystack = NormalizeSearchText(item.searchText or (tostring(item.text or "") .. " " .. tostring(item.value or "")))
        if query == "" or haystack:find(query, 1, true) then
            filtered[#filtered + 1] = { item = item, originalIndex = index }
        end
    end
    return filtered
end

Popup.NormalizeSearchText = NormalizeSearchText
Popup.FilterItems = FilterItems

local function SelectDropdownValue(dropdown, value, text)
    if not dropdown then
        return
    end
    dropdown.qfxsaValue = value
    dropdown.qfxsaText = tostring(text or "")
    if type(dropdown.qfxsaSetVisualText) == "function" then
        dropdown.qfxsaSetVisualText(dropdown, dropdown.qfxsaText)
    elseif dropdown.SetText then
        dropdown:SetText(dropdown.qfxsaText)
    end
    if type(dropdown.qfxsaOnValueChanged) == "function" then
        dropdown.qfxsaOnValueChanged(dropdown.qfxsaValue)
    end
end

local function RefreshMultiDropdownText(dropdown)
    if not dropdown then
        return
    end
    local selected = dropdown.qfxsaSelectedValues or {}
    local parts = {}
    for _, item in ipairs(dropdown.qfxsaItems or {}) do
        if selected[item.value] == true then
            parts[#parts + 1] = tostring(item.text or item.value or "")
        end
    end
    local text = #parts > 0 and table.concat(parts, ", ") or tostring(dropdown.qfxsaFallbackText or "")
    dropdown.qfxsaText = text
    dropdown.qfxsaValue = selected
    if type(dropdown.qfxsaSetVisualText) == "function" then
        dropdown.qfxsaSetVisualText(dropdown, text)
    elseif dropdown.SetText then
        dropdown:SetText(text)
    end
end

local function ToggleDropdownMultiValue(dropdown, value)
    if not dropdown then
        return
    end
    dropdown.qfxsaSelectedValues = dropdown.qfxsaSelectedValues or {}
    dropdown.qfxsaSelectedValues[value] = dropdown.qfxsaSelectedValues[value] ~= true
    RefreshMultiDropdownText(dropdown)
    if type(dropdown.qfxsaOnValueChanged) == "function" then
        dropdown.qfxsaOnValueChanged(dropdown.qfxsaSelectedValues)
    end
end

local function GetDropdownBlocker()
    if Widgets._nativeDropdownBlocker then
        return Widgets._nativeDropdownBlocker
    end
    local blocker = CreateFrame("Frame", "EllesmereUIVENativeDropDownBlocker", UIParent)
    blocker:SetAllPoints(UIParent)
    blocker:SetFrameStrata("TOOLTIP")
    blocker:SetFrameLevel(9990)
    blocker:SetToplevel(true)
    blocker:EnableMouse(true)
    blocker:Hide()
    blocker:SetScript("OnMouseDown", function()
        local popup = Widgets._nativeDropdownPopup
        if popup and popup:IsShown() then
            popup:Hide()
        end
    end)
    Widgets._nativeDropdownBlocker = blocker
    return blocker
end

local function RaiseDropdownPopup(popup, dropdown)
    if not popup then
        return
    end
    local blocker = GetDropdownBlocker()
    blocker:SetFrameStrata("TOOLTIP")
    blocker:SetFrameLevel(9990)
    blocker:Show()
    blocker:Raise()

    popup:SetParent(blocker)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetFrameLevel((blocker:GetFrameLevel() or 9990) + 10)
    popup:SetToplevel(true)
    popup:Raise()
end

local function ApplyDropdownRowHover(row, hovering)
    if not row then
        return
    end
    if hovering and row.LockHighlight then
        row:LockHighlight()
    elseif row.UnlockHighlight then
        row:UnlockHighlight()
    end
    if row.qfxsaHover then
        row.qfxsaHover:SetShown(hovering and true or false)
    end
    if not row.label or not row.label.SetTextColor then
        return
    end
    local color = hovering and rawget(_G, "HIGHLIGHT_FONT_COLOR") or rawget(_G, "NORMAL_FONT_COLOR")
    if color and color.GetRGB then
        local r, g, b = color:GetRGB()
        row.label:SetTextColor(r, g, b, 1)
    elseif hovering then
        row.label:SetTextColor(1, 1, 1, 1)
    else
        row.label:SetTextColor(1, 0.82, 0, 1)
    end
end

local function EnsureDropdownRow(popup, index)
    local row = popup.rows[index]
    if row then
        return row
    end

    row = CreateFrame("Button", nil, popup)
    row:SetFrameStrata("TOOLTIP")
    row:SetFrameLevel((popup:GetFrameLevel() or 1) + 20)
    row:SetSize(120, DROPDOWN_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", popup, "TOPLEFT", DROPDOWN_POPUP_PADDING, -DROPDOWN_POPUP_PADDING - ((index - 1) * DROPDOWN_ROW_HEIGHT))
    row:EnableMouse(true)
    if row.Enable then
        row:Enable()
    end

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(row)
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    highlight:SetBlendMode("ADD")
    row:SetHighlightTexture(highlight)

    local hover = row:CreateTexture(nil, "ARTWORK")
    hover:SetAllPoints(row)
    hover:SetColorTexture(1.0, 0.82, 0.0, 0.24)
    hover:Hide()
    row.qfxsaHover = hover

    -- Multi-select rows need both halves of a checkbox.  The previous code
    -- only drew UI-CheckBox-Check, so every unselected row had no visible box.
    local checkBox = row:CreateTexture(nil, "ARTWORK", nil, 3)
    checkBox:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    checkBox:SetSize(20, 20)
    checkBox:SetPoint("LEFT", row, "LEFT", 1, 0)
    checkBox:Hide()
    row.checkBox = checkBox

    local check = row:CreateTexture(nil, "ARTWORK", nil, 4)
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetSize(20, 20)
    check:SetPoint("CENTER", checkBox, "CENTER", 0, 0)
    check:Hide()
    row.check = check

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", row, "LEFT", 27, 0)
    label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    if MakeSingleLine then
        MakeSingleLine(label)
    end
    row.label = label

    row:SetScript("OnEnter", function(self) ApplyDropdownRowHover(self, true) end)
    row:SetScript("OnLeave", function(self) ApplyDropdownRowHover(self, false) end)

    local function OnRowSelect(self, button)
        if button and button ~= "LeftButton" then
            return
        end
        popup.skipMouseUpSelection = true
        if popup.SelectRow then
            popup.SelectRow(self)
        end
    end
    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", OnRowSelect)

    popup.rows[index] = row
    return row
end

local function GetScrollableDropdownPopup()
    if Widgets._nativeDropdownPopup then
        return Widgets._nativeDropdownPopup
    end

    local popup = CreateFrame("Frame", "EllesmereUIVENativeDropDownPopup", UIParent, "BackdropTemplate")
    popup:SetFrameStrata("TOOLTIP")
    popup:SetFrameLevel(10000)
    popup:SetToplevel(true)
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:EnableMouseWheel(true)
    popup:Hide()
    popup.rows = {}
    popup.offset = 0
    popup.visibleRows = 0
    local RenderRows, RefreshFilter, SelectItemByIndex

    if popup.SetBackdrop then
        popup:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        popup:SetBackdropColor(0, 0, 0, 0.98)
        popup:SetBackdropBorderColor(0.75, 0.75, 0.75, 0.98)
    end

    local searchBox = SafeCreateFrame("EditBox", "EllesmereUIVENativeDropDownSearchBox", popup, {
        "SearchBoxTemplate", "InputBoxTemplate",
    })
    searchBox:SetHeight(24)
    searchBox:SetPoint("TOPLEFT", popup, "TOPLEFT", 8, -7)
    searchBox:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -8, -7)
    searchBox:SetAutoFocus(false)
    searchBox:Hide()
    searchBox:HookScript("OnTextChanged", function(self)
        local owner = popup.owner
        if not owner or not owner.qfxsaSearchable then return end
        owner.qfxsaSearchText = tostring(self:GetText() or "")
        if RefreshFilter then RefreshFilter(true) end
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        if tostring(self:GetText() or "") ~= "" then self:SetText("") else popup:Hide() end
    end)
    searchBox:SetScript("OnEnterPressed", function()
        local filtered = popup.filteredItems or {}
        local record = filtered[1]
        if #filtered == 1 and record and SelectItemByIndex then
            SelectItemByIndex(record.originalIndex)
        elseif #filtered > 1 and SelectItemByIndex then
            local highlighted
            for _, row in ipairs(popup.rows or {}) do
                if row.qfxsaHover and row.qfxsaHover:IsShown() then highlighted = row.itemIndex break end
            end
            SelectItemByIndex(highlighted or filtered[1].originalIndex)
        end
    end)

    local noResults = popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    noResults:SetPoint("CENTER", popup, "CENTER", 0, -12)
    noResults:SetText(NS.L and NS.L("NO_MATCHING_SOUNDS") or "No matching sounds")
    noResults:Hide()

    local scrollBar = ScrollBar and ScrollBar.Create and ScrollBar:Create(popup, "EllesmereUIVENativeDropDownPopupScrollBar", {
        orientation = "VERTICAL",
        width = 16,
        minValue = 0,
        maxValue = 0,
        valueStep = 1,
        value = 0,
        obeyStepOnDrag = false,
    }) or SafeCreateFrame("Slider", "EllesmereUIVENativeDropDownPopupScrollBar", popup, {
        "UIPanelScrollBarTemplate",
        "OptionsSliderTemplate",
        "BackdropTemplate",
    })
    if ScrollBar and ScrollBar.ClearInheritedScripts then
        ScrollBar:ClearInheritedScripts(scrollBar)
    end
    scrollBar:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -6, -18)
    scrollBar:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -6, 18)
    scrollBar:SetFrameLevel((popup:GetFrameLevel() or 1) + 30)

    RenderRows = function()
        local owner = popup.owner
        if not owner then
            return
        end
        local items = popup.filteredItems or owner.qfxsaItems or {}
        local offset = math.floor(tonumber(popup.offset) or 0)
        local visibleRows = tonumber(popup.visibleRows) or 0
        local width = tonumber(popup.rowWidth) or 120
        local selected = owner.qfxsaValue
        local selectedValues = owner.qfxsaSelectedValues or {}
        for i = 1, visibleRows do
            local row = popup.rows[i]
            if row then
                local itemIndex = offset + i
                local record = items[itemIndex]
                local item = type(record) == "table" and (record.item or record) or nil
                if item then
                    row.itemIndex = record.originalIndex or itemIndex
                    row.itemValue = item.value
                    row.dropdown = owner
                    row.label:SetText(tostring(item.text or ""))
                    row.label:SetWidth(math.max(1, width - 32))
                    if row.label.SetTextColor then
                        local color = rawget(_G, "NORMAL_FONT_COLOR")
                        if color and color.GetRGB then
                            local r, g, b = color:GetRGB()
                            row.label:SetTextColor(r, g, b, 1)
                        else
                            row.label:SetTextColor(1, 0.82, 0, 1)
                        end
                    end
                    ApplyDropdownRowHover(row, false)
                    if owner.qfxsaMultiSelect then
                        row.checkBox:Show()
                        if selectedValues[item.value] == true then
                            row.check:Show()
                        else
                            row.check:Hide()
                        end
                    else
                        row.checkBox:Hide()
                        if selected == item.value then
                            row.check:Show()
                        else
                            row.check:Hide()
                        end
                    end
                    row:Show()
                else
                    row:Hide()
                    row.itemIndex = nil
                    row.itemValue = nil
                    row.dropdown = nil
                end
            end
        end
        for i = visibleRows + 1, #popup.rows do
            popup.rows[i]:Hide()
        end
        noResults:SetShown(#items == 0 and owner.qfxsaSearchable == true)
    end

    SelectItemByIndex = function(itemIndex)
        local owner = popup.owner
        if not owner then
            return
        end
        local item = (owner.qfxsaItems or {})[tonumber(itemIndex) or 0]
        if not item then
            return
        end
        if owner.qfxsaMultiSelect then
            ToggleDropdownMultiValue(owner, item.value)
            RenderRows()
            return
        end
        SelectDropdownValue(owner, item.value, item.text)
        popup:Hide()
    end

    local function SelectRow(row)
        if row and row.itemIndex then
            SelectItemByIndex(row.itemIndex)
        end
    end

    local function GetRowNumberAtCursor(self)
        local cx, cy = GetCursorPosition()
        local scale = self.GetEffectiveScale and self:GetEffectiveScale() or UIParent:GetEffectiveScale() or 1
        local left, top = self:GetLeft(), self:GetTop()
        local width = self:GetWidth() or 0
        if not cx or not cy or not scale or scale == 0 or not left or not top then
            return nil
        end
        local x = (cx / scale) - left
        local y = top - (cy / scale)
        local rightLimit = width - ((self.hasScroll and 28) or DROPDOWN_POPUP_PADDING)
        if x < DROPDOWN_POPUP_PADDING or x > rightLimit then
            return nil
        end
        local rowNumber = math.floor((y - (self.contentTop or DROPDOWN_POPUP_PADDING)) / DROPDOWN_ROW_HEIGHT) + 1
        if rowNumber < 1 or rowNumber > (self.visibleRows or 0) then
            return nil
        end
        return rowNumber
    end

    local function SelectByCursor(button)
        if button and button ~= "LeftButton" then
            return
        end
        if popup.skipMouseUpSelection then
            popup.skipMouseUpSelection = nil
            return
        end
        if not popup.owner or not popup:IsShown() then
            return
        end
        local rowNumber = GetRowNumberAtCursor(popup)
        if rowNumber then
            local row = popup.rows[rowNumber]
            if row and row.itemIndex then SelectItemByIndex(row.itemIndex) end
        end
    end

    local function UpdateHoverFromCursor(self)
        if not self.owner or not self:IsShown() then
            return
        end
        local hoverRowNumber = GetRowNumberAtCursor(self)
        for i = 1, (self.visibleRows or 0) do
            local row = self.rows[i]
            if row and row:IsShown() then
                ApplyDropdownRowHover(row, i == hoverRowNumber)
            end
        end
    end

    local function IsCursorInsideFrame(frame)
        if not frame or not frame.IsShown or not frame:IsShown() then
            return false
        end
        local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
        local cx, cy = GetCursorPosition()
        local scale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
        if not left or not right or not top or not bottom or not cx or not cy or not scale or scale == 0 then
            return false
        end
        cx = cx / scale
        cy = cy / scale
        return cx >= left and cx <= right and cy >= bottom and cy <= top
    end

    local function UpdatePopup(self)
        UpdateHoverFromCursor(self)
        if not self.owner or not self:IsShown() then
            self.autoCloseAt = nil
            return
        end
        if self.searchBox and self.searchBox.HasFocus and self.searchBox:HasFocus() then
            self.autoCloseAt = nil
            return
        end
        if IsCursorInsideFrame(self) or IsCursorInsideFrame(self.owner) then
            self.autoCloseAt = nil
            return
        end
        local now = GetTime()
        if not self.autoCloseAt then
            self.autoCloseAt = now + DROPDOWN_AUTO_CLOSE_DELAY
        elseif now >= self.autoCloseAt then
            self:Hide()
        end
    end

    local function SetScroll(value, fromSlider)
        local maxOffset = math.max(0, tonumber(popup.maxOffset) or 0)
        value = math.floor(Clamp(tonumber(value) or 0, 0, maxOffset) + 0.5)
        popup.offset = value
        if not fromSlider then
            scrollBar:SetValue(value)
        end
        RenderRows()
    end

    RefreshFilter = function(fromSearch)
        local owner = popup.owner
        if not owner then return end
        local items = owner.qfxsaItems or {}
        popup.filteredItems = owner.qfxsaSearchable and FilterItems(items, owner.qfxsaSearchText or "") or nil
        local view = popup.filteredItems or items
        local count = #view
        local visibleRows = math.min(count, DROPDOWN_MAX_VISIBLE_ROWS)
        local hasScroll = count > visibleRows
        local width = tonumber(popup.baseWidth) or 180
        local searchSpace = owner.qfxsaSearchable and DROPDOWN_SEARCH_HEIGHT or 0
        local displayRows = math.max(1, visibleRows)
        popup:SetSize(width, (displayRows * DROPDOWN_ROW_HEIGHT) + (DROPDOWN_POPUP_PADDING * 2) + searchSpace)
        popup.visibleRows = visibleRows
        popup.maxOffset = math.max(0, count - visibleRows)
        popup.hasScroll = hasScroll
        popup.contentTop = DROPDOWN_POPUP_PADDING + searchSpace
        popup.rowWidth = width - (hasScroll and 34 or 12)
        if hasScroll then
            scrollBar:Show()
            scrollBar:SetMinMaxValues(0, popup.maxOffset)
            scrollBar:SetValueStep(1)
        else
            scrollBar:Hide()
            scrollBar:SetMinMaxValues(0, 0)
        end
        local initialOffset = 0
        if not fromSearch then
            local selectedIndex = 1
            for index, record in ipairs(view) do
                local item = record.item or record
                if (owner.qfxsaMultiSelect and owner.qfxsaSelectedValues and owner.qfxsaSelectedValues[item.value] == true)
                    or (not owner.qfxsaMultiSelect and owner.qfxsaValue == item.value) then selectedIndex = index break end
            end
            if hasScroll and selectedIndex > 1 then initialOffset = selectedIndex - math.ceil(visibleRows / 2) end
        end
        for i = 1, math.max(visibleRows, 1) do
            local row = EnsureDropdownRow(popup, i)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", popup, "TOPLEFT", DROPDOWN_POPUP_PADDING, -popup.contentTop - ((i - 1) * DROPDOWN_ROW_HEIGHT))
            row:SetSize(math.max(1, popup.rowWidth), DROPDOWN_ROW_HEIGHT)
        end
        SetScroll(fromSearch and 0 or Clamp(initialOffset, 0, popup.maxOffset), false)
    end

    scrollBar:SetScript("OnValueChanged", function(_, value)
        SetScroll(value, true)
    end)

    local function OnMouseWheel(_, delta)
        local maxOffset = tonumber(popup.maxOffset) or 0
        if maxOffset <= 0 then
            return
        end
        SetScroll((popup.offset or 0) - ((delta or 0) * 3))
    end

    popup:SetScript("OnMouseWheel", OnMouseWheel)
    popup:SetScript("OnMouseUp", function(_, button)
        SelectByCursor(button)
    end)
    popup:SetScript("OnUpdate", UpdatePopup)
    popup:SetScript("OnShow", function(self)
        self.autoCloseAt = nil
        RaiseDropdownPopup(self, self.owner)
        RenderRows()
    end)
    popup:SetScript("OnHide", function(self)
        for i = 1, (self.visibleRows or 0) do
            local row = self.rows[i]
            if row then
                ApplyDropdownRowHover(row, false)
            end
        end
        local closingOwner = self.owner
        if closingOwner then closingOwner.qfxsaSearchText = "" end
        self.owner = nil
        self.filteredItems = nil
        searchBox:ClearFocus()
        searchBox:SetText("")
        searchBox:Hide()
        self.offset = 0
        self.hasScroll = nil
        self.skipMouseUpSelection = nil
        self.autoCloseAt = nil
        local blocker = Widgets._nativeDropdownBlocker
        if blocker then
            blocker:Hide()
        end
    end)

    popup.scrollBar = scrollBar
    popup.searchBox = searchBox
    popup.noResults = noResults
    popup.SetPopupScroll = SetScroll
    popup.RenderRows = RenderRows
    popup.RefreshFilter = RefreshFilter
    popup.SelectRow = SelectRow
    popup.SelectByCursor = SelectByCursor
    Widgets._nativeDropdownPopup = popup
    return popup
end

function Popup:HideForOwner(dropdown)
    local popup = Widgets._nativeDropdownPopup
    if popup and (not dropdown or popup.owner == dropdown) then
        popup:Hide()
    end
end

function Popup:Show(dropdown)
    if not dropdown or dropdown.qfxsaDisabled then
        return
    end

    local popup = GetScrollableDropdownPopup()
    if popup:IsShown() and popup.owner == dropdown then
        popup:Hide()
        return
    end

    local items = dropdown.qfxsaItems or {}
    if #items <= 0 then return end

    popup.owner = dropdown
    RaiseDropdownPopup(popup, dropdown)

    local width = math.max(120, math.floor(tonumber(dropdown.qfxsaOuterWidth) or ((dropdown.GetWidth and dropdown:GetWidth()) or 180)))
    popup.baseWidth = width
    popup.scrollBar:SetFrameLevel((popup:GetFrameLevel() or 1) + 30)
    popup.scrollBar:ClearAllPoints()
    popup.scrollBar:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -6, dropdown.qfxsaSearchable and -42 or -18)
    popup.scrollBar:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -6, 18)
    popup:ClearAllPoints()
    popup:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)

    for i = 1, DROPDOWN_MAX_VISIBLE_ROWS do
        local row = EnsureDropdownRow(popup, i)
        row:SetFrameStrata("TOOLTIP")
        row:SetFrameLevel((popup:GetFrameLevel() or 1) + 50 + i)
        row:EnableMouse(true)
        if row.Enable then row:Enable() end
    end

    dropdown.qfxsaSearchText = ""
    popup.noResults:SetText(NS.L and NS.L("NO_MATCHING_SOUNDS") or "No matching sounds")
    popup.searchBox:SetShown(dropdown.qfxsaSearchable == true)
    if popup.searchBox.Instructions then popup.searchBox.Instructions:SetText(dropdown.qfxsaSearchPlaceholder or "") end
    popup.searchBox:SetText("")
    popup:Show()
    popup.RefreshFilter(false)
    if dropdown.qfxsaSearchable then popup.searchBox:SetFocus() end
end
