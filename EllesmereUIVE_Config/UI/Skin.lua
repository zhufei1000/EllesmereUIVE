local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.Skin = NS.UI.Skin or {}

local Skin = NS.UI.Skin

--[[
Native / external-skin friendly UI layer
---------------------------------------
1. The UI structure is still unified by PopupLayout / Widgets.
2. Visual chrome is intentionally close to Blizzard native frames.
3. Buttons, edit boxes, check boxes, sliders and dropdowns should keep their
   native templates whenever possible so ElvUI / NDui can skin them naturally.
4. This file is only a light fallback.  It should not force the old black-gold
   self-drawn style back onto the addon.
]]

Skin.Theme = Skin.Theme or {
    bg = { 0.00, 0.00, 0.00, 0.78 },
    panel = { 0.00, 0.00, 0.00, 0.55 },
    inset = { 0.00, 0.00, 0.00, 0.35 },
    border = { 0.44, 0.44, 0.44, 0.75 },
    text = { 1.00, 0.82, 0.00, 1.00 }, -- Blizzard GameFontNormal-like fallback
    highlight = { 1.00, 1.00, 1.00, 1.00 },
    muted = { 0.72, 0.72, 0.72, 1.00 },
    selected = { 0.18, 0.37, 0.82, 0.22 },
}

local FONT = "Fonts\\FRIZQT__.TTF"
local DIALOG_BG = "Interface\\DialogFrame\\UI-DialogBox-Background"
local DIALOG_BORDER = "Interface\\DialogFrame\\UI-DialogBox-Border"
local TOOLTIP_BG = "Interface\\Tooltips\\UI-Tooltip-Background"
local TOOLTIP_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"

local function SafeUnpack(value)
    local unpackFunc = rawget(_G, "unpack") or table.unpack
    if type(value) == "table" and type(unpackFunc) == "function" then
        return unpackFunc(value)
    end
    return nil
end

local function ApplyFont(fontString, size, flags)
    if not fontString or not fontString.SetFont then
        return
    end

    local font = rawget(_G, "STANDARD_TEXT_FONT") or FONT
    if not fontString:SetFont(font, size, flags or "") then
        fontString:SetFont(FONT, size, flags or "")
    end
end

local function SetFontStringColor(fontString, color)
    if fontString and fontString.SetTextColor and type(color) == "table" then
        fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    end
end

local function GetButtonText(button)
    return button and button.GetFontString and button:GetFontString() or (button and button.Text) or nil
end

local function ApplyDialogBackdrop(frame)
    if not frame or not frame.SetBackdrop then
        return
    end
    frame:SetBackdrop({
        bgFile = DIALOG_BG,
        edgeFile = DIALOG_BORDER,
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetBackdropColor(1, 1, 1, 1)
    frame:SetBackdropBorderColor(1, 1, 1, 1)
end

local function ApplyInsetBackdrop(frame)
    if not frame or not frame.SetBackdrop then
        return
    end
    frame:SetBackdrop({
        bgFile = TOOLTIP_BG,
        edgeFile = TOOLTIP_BORDER,
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    -- Inset panels must be solid enough to hide the parent window behind the
    -- editor popup.  The previous 0.34 alpha made the main list/buttons show
    -- through module cards, which looked like controls were overflowing and
    -- also caused confusing hit areas.
    frame:SetBackdropColor(0, 0, 0, 0.84)
    frame:SetBackdropBorderColor(0.55, 0.55, 0.55, 0.82)
end

function Skin:GetSkinMode()
    -- Skin mode is automatic and not exposed in the UI.  Legacy db values are
    -- tolerated, but "auto" remains the default.
    local db = rawget(_G, "EllesmereUIVEDB")
    local mode = type(db) == "table" and tostring(db.uiSkinMode or "auto") or "auto"
    if mode ~= "auto" and mode ~= "external" and mode ~= "qfx" then
        mode = "auto"
    end
    return mode
end

function Skin:SetSkinMode(mode)
    mode = tostring(mode or "auto")
    if mode ~= "auto" and mode ~= "external" and mode ~= "qfx" then
        mode = "auto"
    end
    local db = rawget(_G, "EllesmereUIVEDB")
    if type(db) == "table" then
        db.uiSkinMode = mode
    end
end

function Skin:DetectExternalSkin()
    if rawget(_G, "ElvUI") then
        return "ElvUI"
    end
    if rawget(_G, "NDui") or rawget(_G, "NDuiDB") or rawget(_G, "NDuiADB") then
        return "NDui"
    end
    return nil
end

function Skin:UseExternalSkin()
    local mode = self:GetSkinMode()
    if mode == "qfx" then
        return false
    end
    if mode == "external" then
        return true
    end
    return self:DetectExternalSkin() ~= nil
end

function Skin:MarkExternalSkinTarget(frame, kind)
    if not frame then
        return frame
    end
    frame.qfxsaExternalSkinFriendly = true
    frame.qfxsaSkinKind = kind or frame.qfxsaSkinKind or "frame"
    frame.qfxSkinTarget = true
    frame.qfxSkinGroup = "EllesmereUIVE:" .. tostring(kind or "frame")
    return frame
end

local ELVUI_METHODS = {
    frame = { "HandleFrame" },
    button = { "HandleButton" },
    close = { "HandleCloseButton", "HandleButton" },
    editbox = { "HandleEditBox" },
    checkbox = { "HandleCheckBox" },
    dropdown = { "HandleDropDownBox", "HandleButton" },
    scrollbar = { "HandleScrollBar" },
    slider = { "HandleSliderFrame", "HandleSlider" },
    tab = { "HandleTab", "HandleButton" },
}

function Skin:TryExternalSkin(frame, kind)
    if not frame then
        return false
    end
    self:MarkExternalSkinTarget(frame, kind)

    local ext = self:DetectExternalSkin()
    if ext == "ElvUI" then
        local E = SafeUnpack(rawget(_G, "ElvUI"))
        local S = E and E.GetModule and E:GetModule("Skins", true)
        local methods = ELVUI_METHODS[kind or "frame"] or ELVUI_METHODS.frame
        if S then
            for _, methodName in ipairs(methods) do
                local method = S[methodName]
                if type(method) == "function" then
                    local ok = pcall(method, S, frame)
                    if ok then
                        return true
                    end
                end
            end
        end
    end

    -- NDui usually skins Blizzard templates globally.  Marking the frame is enough;
    -- keep the native template intact so NDui can recognize it naturally.
    if ext == "NDui" then
        return true
    end

    return false
end

function Skin:StyleFont(fontString, role)
    if not fontString then
        return fontString
    end

    -- Keep the Blizzard color roles instead of forcing the old black-gold theme.
    if role == "title" then
        ApplyFont(fontString, 18, "OUTLINE")
        local color = rawget(_G, "NORMAL_FONT_COLOR")
        if color and color.GetRGB then
            local r, g, b = color:GetRGB()
            fontString:SetTextColor(r, g, b, 1)
        end
    elseif role == "section" or role == "accent" then
        ApplyFont(fontString, 13, "")
        local color = rawget(_G, "NORMAL_FONT_COLOR")
        if color and color.GetRGB then
            local r, g, b = color:GetRGB()
            fontString:SetTextColor(r, g, b, 1)
        end
    elseif role == "muted" then
        ApplyFont(fontString, 12, "")
        local color = rawget(_G, "GRAY_FONT_COLOR")
        if color and color.GetRGB then
            local r, g, b = color:GetRGB()
            fontString:SetTextColor(r, g, b, 1)
        else
            SetFontStringColor(fontString, self.Theme.muted)
        end
    else
        ApplyFont(fontString, 13, "")
        local color = rawget(_G, "HIGHLIGHT_FONT_COLOR")
        if color and color.GetRGB then
            local r, g, b = color:GetRGB()
            fontString:SetTextColor(r, g, b, 1)
        end
    end
    return fontString
end

function Skin:ApplyWindowChrome(frame, opts)
    if not frame then
        return
    end

    opts = opts or {}
    self:MarkExternalSkinTarget(frame, "frame")
    if self:UseExternalSkin() and self:TryExternalSkin(frame, "frame") then
        return
    end

    if opts.inset then
        ApplyInsetBackdrop(frame)
    else
        ApplyDialogBackdrop(frame)
    end
end

function Skin:SkinButton(button, variant)
    if not button then
        return button
    end

    self:MarkExternalSkinTarget(button, "button")
    if self:UseExternalSkin() then
        self:TryExternalSkin(button, "button")
        return button
    end

    -- Native fallback: keep Blizzard button textures and text behavior.
    local text = GetButtonText(button)
    if type(text) == "table" and text.SetTextColor and variant == "danger" then
        text:SetTextColor(1.0, 0.35, 0.28, 1)
    end
    return button
end

function Skin:SkinCloseButton(button)
    if not button then
        return button
    end
    self:MarkExternalSkinTarget(button, "close")
    if self:UseExternalSkin() then
        self:TryExternalSkin(button, "close")
    end
    return button
end

function Skin:SkinEditBox(editBox)
    if not editBox then
        return editBox
    end

    self:MarkExternalSkinTarget(editBox, "editbox")
    if self:UseExternalSkin() then
        self:TryExternalSkin(editBox, "editbox")
    end
    return editBox
end

function Skin:SkinCheckButton(checkButton)
    if not checkButton then
        return checkButton
    end

    self:MarkExternalSkinTarget(checkButton, "checkbox")
    if self:UseExternalSkin() then
        self:TryExternalSkin(checkButton, "checkbox")
    end

    local label = checkButton.qfxsaLabel or checkButton.Text or checkButton.text
    if label then
        self:StyleFont(label, "accent")
        label:SetJustifyH("LEFT")
    end
    return checkButton
end

function Skin:SkinDropDown(dropdown)
    if not dropdown then
        return dropdown
    end

    self:MarkExternalSkinTarget(dropdown, "dropdown")
    if self:UseExternalSkin() then
        self:TryExternalSkin(dropdown, "dropdown")
    end
    return dropdown
end

function Skin:SkinScrollBar(slider)
    if not slider then
        return slider
    end

    self:MarkExternalSkinTarget(slider, "scrollbar")
    if self:UseExternalSkin() then
        self:TryExternalSkin(slider, "scrollbar")
    end
    return slider
end

function Skin:SkinSlider(slider)
    if not slider then
        return slider
    end

    self:MarkExternalSkinTarget(slider, "slider")
    if self:UseExternalSkin() then
        self:TryExternalSkin(slider, "slider")
    end
    return slider
end

function Skin:SkinTabButton(button)
    if not button then
        return button
    end
    self:MarkExternalSkinTarget(button, "tab")
    if self:UseExternalSkin() then
        self:TryExternalSkin(button, "tab")
        return button
    end
    self:SkinButton(button, "secondary")
    return button
end

function Skin:SetTabSelected(button, selected)
    if not button then
        return
    end

    self:SkinTabButton(button)
    button:SetButtonState(selected and "PUSHED" or "NORMAL")
    local text = GetButtonText(button)
    if type(text) == "table" and text.SetTextColor then
        local color = selected and rawget(_G, "HIGHLIGHT_FONT_COLOR") or rawget(_G, "NORMAL_FONT_COLOR")
        if color and color.GetRGB then
            local r, g, b = color:GetRGB()
            text:SetTextColor(r, g, b, 1)
        end
    end
end

function Skin:CreateSectionHeader(parent, text)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(22)
    self:MarkExternalSkinTarget(frame, "frame")

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", frame, "LEFT", 0, 0)
    label:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetText(tostring(text or ""))
    self:StyleFont(label, "section")
    frame.label = label
    return frame
end
