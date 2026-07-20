local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.Widgets = NS.UI.Widgets or {}

local Widgets = NS.UI.Widgets
local Skin = NS.UI.Skin
local ScrollBar = NS.UI.ScrollBar

local WidgetUtils = NS.UI.WidgetUtils or {}
local MakeSingleLine = WidgetUtils.MakeSingleLine
local SafeCreateFrame = WidgetUtils.SafeCreateFrame

local widgetSerial = 0

local function NextWidgetName(prefix)
    widgetSerial = widgetSerial + 1
    return "EllesmereUIVE" .. tostring(prefix or "Widget") .. tostring(widgetSerial)
end

local function ApplyFallbackCheckTextures(button)
    if not button then
        return
    end
    if button.SetNormalTexture and not button:GetNormalTexture() then
        button:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    end
    if button.SetPushedTexture and not button:GetPushedTexture() then
        button:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    end
    if button.SetHighlightTexture and not button:GetHighlightTexture() then
        button:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    end
    if button.SetCheckedTexture and not button:GetCheckedTexture() then
        button:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    end
    if button.SetDisabledCheckedTexture and not button:GetDisabledCheckedTexture() then
        button:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
    end
end

function Widgets:ApplyPanelChrome(frame, opts)
    if Skin and Skin.ApplyWindowChrome then
        Skin:ApplyWindowChrome(frame, opts)
    end
end

function Widgets:CreateLabel(parent, text, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    label:SetJustifyH("LEFT")
    label:SetText(tostring(text or ""))
    if Skin and Skin.StyleFont then
        local role = template == "GameFontNormalLarge" and "title" or "body"
        if template == "GameFontHighlightSmall" then
            role = "muted"
        end
        Skin:StyleFont(label, role)
    end
    return label
end

function Widgets:CreateSection(parent, title)
    if Skin and Skin.CreateSectionHeader then
        return Skin:CreateSectionHeader(parent, title)
    end
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(20)
    local label = self:CreateLabel(frame, title, "GameFontNormal")
    label:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.label = label
    return frame
end

function Widgets:CreateModuleCard(parent, title, description, width, height)
    -- Native-friendly module group. Keep the layout architecture, but use the
    -- same Blizzard-style inset chrome as the rest of the popup instead of
    -- custom black/gold painted widgets.
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(width or 640, height or 100)
    -- Module cards are real hit-test panels.  Do not let the main frame behind
    -- the editor receive clicks through transparent empty areas.
    card:EnableMouse(true)
    -- Do not clip native child controls here.  The layout is responsible for
    -- keeping controls inside the module; clipping made native dropdown arrows
    -- and external-skin decorations look cut off on some clients.
    if card.SetClipsChildren then
        card:SetClipsChildren(false)
    end
    if Skin and Skin.MarkExternalSkinTarget then
        Skin:MarkExternalSkinTarget(card, "frame")
    end
    if Skin and Skin.ApplyWindowChrome then
        Skin:ApplyWindowChrome(card, { inset = true, noFooter = true })
    elseif card.SetBackdrop then
        card:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        card:SetBackdropColor(0, 0, 0, 0.82)
        card:SetBackdropBorderColor(0.55, 0.55, 0.55, 0.82)
    end

    local label = self:CreateLabel(card, title or "", "GameFontNormal")
    label:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -8)
    label:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    label:SetJustifyH("LEFT")
    if Skin and Skin.StyleFont then
        Skin:StyleFont(label, "section")
    end
    card.label = label
    card.qfxsaLabel = label

    if description and tostring(description) ~= "" then
        local desc = self:CreateLabel(card, description, "GameFontHighlightSmall")
        desc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
        desc:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        desc:SetJustifyH("LEFT")
        if Skin and Skin.StyleFont then
            Skin:StyleFont(desc, "muted")
        end
        card.description = desc
    end

    return card
end

function Widgets:CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 96, height or 26)
    local label = tostring(text or "")
    button:SetText(label)
    if Skin and Skin.SkinButton then
        local isPrimary = label == "\228\191\157\229\173\152" or label == "\230\150\176\229\162\158"
        local isDanger = label == "\229\136\160\233\153\164"
        Skin:SkinButton(button, isPrimary and "primary" or isDanger and "danger" or "secondary")
    end
    return button
end
function Widgets:CreateEditBox(parent, width, height, numeric)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate,BackdropTemplate")
    box:SetAutoFocus(false)
    box:SetSize(width or 180, height or 20)
    box:SetTextInsets(8, 8, 0, 0)
    if numeric and box.SetNumeric then
        box:SetNumeric(true)
    end
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    if Skin and Skin.SkinEditBox then
        Skin:SkinEditBox(box)
    end
    return box
end

function Widgets:CreateCheckButton(parent, text, labelWidth)
    -- Native Blizzard checkbox model:
    -- 1) the CheckButton itself is always only the 24x24 checkbox;
    -- 2) the text is a FontString owned by the CheckButton, anchored outside it;
    -- 3) never widen the CheckButton frame, otherwise the Blizzard checkbox
    --    textures stretch into the long black bar shown in 1.0.65.
    local button = SafeCreateFrame("CheckButton", NextWidgetName("Check"), parent, {
        "UICheckButtonTemplate",
        "InterfaceOptionsCheckButtonTemplate",
        "ChatConfigCheckButtonTemplate",
    })
    button:SetSize(24, 24)
    ApplyFallbackCheckTextures(button)

    -- Reuse the template label when available; otherwise create a child label.
    -- The label must be a child of the CheckButton so it hides together with
    -- the checkbox when switching tabs.
    local label = (type(button.qfxsaLabel) == "table" and button.qfxsaLabel)
        or (type(button.Text) == "table" and button.Text)
        or (type(button.text) == "table" and button.text)
    if not label then
        label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end
    button.qfxsaLabel = label
    button.Text = label
    button.text = label

    label:ClearAllPoints()
    label:SetPoint("LEFT", button, "RIGHT", 4, 0)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetText(tostring(text or ""))
    MakeSingleLine(label, labelWidth or 180)
    if label.SetHeight then
        label:SetHeight(24)
    end

    -- Make the label area clickable without stretching the checkbox texture.
    if button.SetHitRectInsets then
        button:SetHitRectInsets(0, -math.max(0, tonumber(labelWidth) or 180), 0, 0)
    end

    if Skin and Skin.SkinCheckButton then
        Skin:SkinCheckButton(button)
    end
    return button
end
