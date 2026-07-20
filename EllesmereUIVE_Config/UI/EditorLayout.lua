local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.EditorLayout = NS.UI.EditorLayout or {}

local Layout = NS.UI.EditorLayout
local Widgets = NS.UI.Widgets
local Skin = NS.UI.Skin
local PopupLayout = NS.UI.PopupLayout

function Layout.SetNativeLabelColor(label, enabled)
    if not label or not label.SetTextColor then
        return
    end
    local color = enabled and rawget(_G, "NORMAL_FONT_COLOR") or rawget(_G, "GRAY_FONT_COLOR")
    if color and color.GetRGB then
        local r, g, b = color:GetRGB()
        label:SetTextColor(r, g, b, 1)
    elseif enabled then
        label:SetTextColor(1.00, 0.82, 0.00, 1)
    else
        label:SetTextColor(0.50, 0.50, 0.50, 1)
    end
end

function Layout.SetEnabled(frame, enabled)
    if not frame then
        return
    end
    if frame.SetEnabled then
        frame:SetEnabled(enabled)
    end
    if frame.Enable and frame.Disable then
        if enabled then
            frame:Enable()
        else
            frame:Disable()
        end
    end
    if frame.SetAlpha then
        frame:SetAlpha(enabled and 1 or 0.55)
    end

    local label = (type(frame.qfxsaLabel) == "table" and frame.qfxsaLabel)
        or (type(frame.Text) == "table" and frame.Text)
        or (type(frame.text) == "table" and frame.text)
    if not label then
        return
    end

    Layout.SetNativeLabelColor(label, enabled)
end

function Layout.SetTabVisual(button, active)
    if not button then
        return
    end
    if Skin and Skin.SetTabSelected then
        Skin:SetTabSelected(button, active)
        return
    end
    button:SetButtonState(active and "PUSHED" or "NORMAL")
end

function Layout.CreateFieldLabel(parent, text, x, y, width)
    local label = Widgets:CreateLabel(parent, text, "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    if label.SetWordWrap then label:SetWordWrap(false) end
    if label.SetNonSpaceWrap then label:SetNonSpaceWrap(false) end
    if label.SetMaxLines then label:SetMaxLines(1) end
    if label.SetHeight then label:SetHeight(18) end
    if label.SetWidth then label:SetWidth(math.max(1, tonumber(width) or 140)) end
    if Skin then
        Skin:StyleFont(label, "accent")
    end
    return label
end

function Layout.PlaceControl(control, parent, x, y)
    if not control then
        return control
    end
    control:ClearAllPoints()
    control:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return control
end

function Layout.PlaceModule(parent, title, y, height, description)
    local modules = PopupLayout and PopupLayout.Editor and PopupLayout.Editor.Modules or {}
    local grid = PopupLayout and PopupLayout.Editor and PopupLayout.Editor.Grid or {}
    local width = modules.width or ((grid.right or 680) - (modules.left or 8))
    local module = Widgets.CreateModuleCard and Widgets:CreateModuleCard(parent, title, description, width, height or 100) or Widgets:CreateSection(parent, title)
    module:SetPoint("TOPLEFT", parent, "TOPLEFT", modules.left or 8, y)
    return module
end

function Layout.SetManyShown(items, shown)
    for _, item in ipairs(items or {}) do
        if item and item.SetShown then
            item:SetShown(shown)
        end
    end
end


local valueSliderSerial = 0

local function FormatSliderNumber(value)
    local normalized = math.floor((tonumber(value) or 0) + 0.5)
    return tostring(normalized)
end

function Layout.UpdateValueSliderText(slider, value)
    if not slider or not slider.qfxsaValueText or not slider.qfxsaValueText.SetText then
        return
    end
    local formatter = slider.qfxsaFormatter
    local text = type(formatter) == "function" and formatter(value or (slider.GetValue and slider:GetValue()) or 0) or FormatSliderNumber(value or (slider.GetValue and slider:GetValue()) or 0)
    slider.qfxsaValueText:SetText(text)
end

function Layout.SetValueSliderLabelEnabled(slider, enabled)
    if not slider then
        return
    end
    local color = enabled and rawget(_G, "HIGHLIGHT_FONT_COLOR") or rawget(_G, "GRAY_FONT_COLOR")
    local r, g, b = 0.92, 0.92, 0.92
    if color and color.GetRGB then
        r, g, b = color:GetRGB()
    elseif not enabled then
        r, g, b = 0.50, 0.50, 0.50
    end
    for _, label in ipairs({ slider.qfxsaMinText, slider.qfxsaValueText, slider.qfxsaMaxText }) do
        if label and label.SetTextColor then
            label:SetTextColor(r, g, b, 1)
        end
    end
end

function Layout.CreateValueSlider(parent, minValue, maxValue, stepValue, defaultValue, formatter)
    valueSliderSerial = valueSliderSerial + 1
    minValue = tonumber(minValue) or 0
    maxValue = tonumber(maxValue) or 100
    stepValue = tonumber(stepValue) or 1
    defaultValue = tonumber(defaultValue) or minValue
    local sliderName = "EllesmereUIVEEditorValueSlider" .. tostring(valueSliderSerial)
    local slider = Layout.CreateNativeSlider(sliderName, parent)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(stepValue)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    slider:SetSize(180, 17)
    slider:SetOrientation("HORIZONTAL")
    if slider.SetHitRectInsets then
        slider:SetHitRectInsets(0, 0, -10, -14)
    end
    if slider.SetThumbTexture and not slider:GetThumbTexture() then
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    end
    Layout.ClearNativeSliderExtraText(slider)

    local minText = Widgets:CreateLabel(slider, FormatSliderNumber(minValue), "GameFontHighlightSmall")
    minText:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
    minText:SetWidth(42)
    minText:SetJustifyH("LEFT")
    minText:SetJustifyV("MIDDLE")

    local maxText = Widgets:CreateLabel(slider, FormatSliderNumber(maxValue), "GameFontHighlightSmall")
    maxText:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
    maxText:SetWidth(42)
    maxText:SetJustifyH("RIGHT")
    maxText:SetJustifyV("MIDDLE")

    local valueText = Widgets:CreateLabel(slider, FormatSliderNumber(defaultValue), "GameFontHighlightSmall")
    valueText:SetPoint("TOP", slider, "BOTTOM", 0, -2)
    valueText:SetWidth(54)
    valueText:SetJustifyH("CENTER")
    valueText:SetJustifyV("MIDDLE")

    if Skin then
        Skin:StyleFont(minText, "muted")
        Skin:StyleFont(maxText, "muted")
        Skin:StyleFont(valueText, "body")
    end
    slider.qfxsaMinText = minText
    slider.qfxsaMaxText = maxText
    slider.qfxsaValueText = valueText
    slider.qfxsaFormatter = formatter
    slider.qfxsaStep = stepValue
    slider:HookScript("OnValueChanged", function(self, value)
        value = tonumber(value) or minValue
        local step = tonumber(self.qfxsaStep) or 1
        local normalized = math.floor((value / step) + 0.5) * step
        normalized = math.max(minValue, math.min(maxValue, normalized))
        if step >= 1 then
            normalized = math.floor(normalized + 0.5)
        end
        if math.abs(normalized - value) > 0.001 and not self.qfxsaSettingValue then
            self.qfxsaSettingValue = true
            self:SetValue(normalized)
            self.qfxsaSettingValue = false
            return
        end
        Layout.UpdateValueSliderText(self, normalized)
    end)
    slider:SetValue(defaultValue)
    Layout.UpdateValueSliderText(slider, defaultValue)
    return slider
end

local rateSliderSerial = 0

function Layout.CreateNativeSlider(name, parent)
    -- UISliderTemplate is the actual Blizzard slider bar/handle template.
    -- OptionsSliderTemplate only wraps it and adds Low/Text/High font strings,
    -- which made the editor look different from the native slider in the game UI.
    local ok, slider = pcall(CreateFrame, "Slider", name, parent, "UISliderTemplate")
    if ok and slider then
        return slider
    end
    ok, slider = pcall(CreateFrame, "Slider", name, parent, "OptionsSliderTemplate")
    if ok and slider then
        return slider
    end
    return CreateFrame("Slider", name, parent)
end

function Layout.ClearNativeSliderExtraText(slider)
    if not slider or not slider.GetName then
        return
    end
    local name = slider:GetName()
    for _, suffix in ipairs({ "Text", "Low", "High" }) do
        local fs = name and rawget(_G, name .. suffix)
        if fs then
            if fs.SetText then
                fs:SetText("")
            end
            if fs.Hide then
                fs:Hide()
            end
        end
    end
end

function Layout.FormatRateValue(value)
    local normalized = math.max(-10, math.min(10, math.floor((tonumber(value) or 0) + 0.5)))
    if normalized > 0 then
        return "+" .. tostring(normalized)
    end
    return tostring(normalized)
end

function Layout.UpdateRateValueText(slider, value)
    if slider and slider.qfxsaValueText and slider.qfxsaValueText.SetText then
        slider.qfxsaValueText:SetText(Layout.FormatRateValue(value or (slider.GetValue and slider:GetValue()) or 0))
    end
end

function Layout.SetRateSliderLabelEnabled(slider, enabled)
    if not slider then
        return
    end
    local color = enabled and rawget(_G, "HIGHLIGHT_FONT_COLOR") or rawget(_G, "GRAY_FONT_COLOR")
    local r, g, b = 0.92, 0.92, 0.92
    if color and color.GetRGB then
        r, g, b = color:GetRGB()
    elseif not enabled then
        r, g, b = 0.50, 0.50, 0.50
    end
    for _, label in ipairs({ slider.qfxsaMinText, slider.qfxsaValueText, slider.qfxsaMaxText }) do
        if label and label.SetTextColor then
            label:SetTextColor(r, g, b, 1)
        end
    end
end

function Layout.CreateRateSlider(parent)
    rateSliderSerial = rateSliderSerial + 1
    local sliderName = "EllesmereUIVEEditorRateSlider" .. tostring(rateSliderSerial)
    local slider = Layout.CreateNativeSlider(sliderName, parent)
    slider:SetMinMaxValues(-10, 10)
    slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    slider:SetSize(180, 17)
    slider:SetOrientation("HORIZONTAL")
    if slider.SetHitRectInsets then
        slider:SetHitRectInsets(0, 0, -10, -14)
    end
    if slider.SetThumbTexture and not slider:GetThumbTexture() then
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    end
    Layout.ClearNativeSliderExtraText(slider)

    local minText = Widgets:CreateLabel(slider, "-10", "GameFontHighlightSmall")
    minText:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
    minText:SetWidth(42)
    minText:SetJustifyH("LEFT")
    minText:SetJustifyV("MIDDLE")

    local maxText = Widgets:CreateLabel(slider, "+10", "GameFontHighlightSmall")
    maxText:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
    maxText:SetWidth(42)
    maxText:SetJustifyH("RIGHT")
    maxText:SetJustifyV("MIDDLE")

    local valueText = Widgets:CreateLabel(slider, "0", "GameFontHighlightSmall")
    valueText:SetPoint("TOP", slider, "BOTTOM", 0, -2)
    valueText:SetWidth(54)
    valueText:SetJustifyH("CENTER")
    valueText:SetJustifyV("MIDDLE")

    if Skin then
        Skin:StyleFont(minText, "muted")
        Skin:StyleFont(maxText, "muted")
        Skin:StyleFont(valueText, "body")
    end
    slider.qfxsaMinText = minText
    slider.qfxsaMaxText = maxText
    slider.qfxsaValueText = valueText
    Layout.UpdateRateValueText(slider, 0)
    return slider
end

function Layout.InstallSpellIdAutofill(editor, editBox)
    local function autofillFromInput()
        editor:PullFromWidgets()
        NS.AceOptions:AutofillFromSpellId()
        editor:PushToWidgets()
    end

    editBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        autofillFromInput()
    end)

    editBox:SetScript("OnEditFocusLost", function()
        autofillFromInput()
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
end

function Layout.InstallTalentIdAutofill(editor, editBox)
    local function autofillFromInput()
        editor:PullFromWidgets()
        if NS.AceOptions and type(NS.AceOptions.AutofillFromTalentId) == "function" then
            NS.AceOptions:AutofillFromTalentId()
        end
        editor:PushToWidgets()
    end

    editBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        autofillFromInput()
    end)

    editBox:SetScript("OnEditFocusLost", function()
        autofillFromInput()
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
end
