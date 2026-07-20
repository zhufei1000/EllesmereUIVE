local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.EditorFrameBuilder = NS.UI.EditorFrameBuilder or {}
local Builder = NS.UI.EditorFrameBuilder
local Widgets = NS.UI.Widgets
local Skin = NS.UI.Skin
local L = NS.L or function(key) return tostring(key) end

local function Label(parent, text, x, y, width)
    local label = Widgets:CreateLabel(parent, text, "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetWidth(width or 180)
    label:SetJustifyH("LEFT")
    return label
end

local function Section(parent, title, x, y, width, height)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    frame:SetSize(width, height)
    Widgets:ApplyPanelChrome(frame, { inset = true, noFooter = true, topHeight = 24 })
    local heading = Widgets:CreateLabel(frame, title, "GameFontNormal")
    heading:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -9)
    if Skin and Skin.StyleFont then Skin:StyleFont(heading, "section") end
    frame.heading = heading
    return frame
end

local function Edit(parent, labelText, x, y, width, numeric)
    local label = Label(parent, labelText, x, y, width)
    local edit = Widgets:CreateEditBox(parent, width, 28, numeric)
    edit:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 20)
    return label, edit
end

local function Drop(parent, name, labelText, x, y, width)
    local label = Label(parent, labelText, x, y, width)
    local drop = Widgets:CreateDropdown(parent, name, width)
    drop:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 20)
    return label, drop
end

function Builder:EnsureFrame(owner)
    if owner.frame then return owner.frame end

    local frame = CreateFrame("Frame", "EllesmereUIVEEditorFrame", UIParent, "BackdropTemplate")
    frame:SetSize(860, 720)
    frame:SetPoint("CENTER", UIParent, "CENTER", 40, 0)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(100)
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()
    Widgets:ApplyPanelChrome(frame, { footerHeight = 66 })
    tinsert(UISpecialFrames, frame:GetName())

    local title = Widgets:CreateLabel(frame, L("TITLE_NEW_CONFIG"), "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -18)
    title:SetWidth(650)
    title:SetJustifyH("CENTER")
    if Skin and Skin.StyleFont then Skin:StyleFont(title, "title") end
    frame.title = title

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    if Skin and Skin.SkinCloseButton then Skin:SkinCloseButton(close) end

    local tabEUI = Widgets:CreateButton(frame, L("TAB_COOLDOWN"), 170, 30)
    local tabCast = Widgets:CreateButton(frame, L("TAB_CAST"), 150, 30)
    local tabBloodlust = Widgets:CreateButton(frame, L("TAB_BLOODLUST"), 150, 30)
    tabEUI:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -54)
    tabCast:SetPoint("LEFT", tabEUI, "RIGHT", 8, 0)
    tabBloodlust:SetPoint("LEFT", tabCast, "RIGHT", 8, 0)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -96)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 72)
    frame.contentHost = content

    local scopeSection = Section(content, L("SECTION_CLASS_SPEC"), 0, 0, 820, 104)
    local scopeButton = Widgets:CreateButton(scopeSection, L("SECTION_CLASS_SPEC"), 150, 28)
    scopeButton:SetPoint("TOPLEFT", scopeSection, "TOPLEFT", 16, -48)
    local scopeSummary = Label(scopeSection, "", 188, -54, 610)

    local spellSection = Section(content, L("SECTION_SPELL_PARAMS"), 0, -116, 820, 142)
    local spellIdLabel, spellId = Edit(spellSection, L("LABEL_SPELL_ID"), 16, -38, 180, true)
    local spellNameLabel, spellName = Edit(spellSection, L("LABEL_SPELL_NAME"), 214, -38, 300, false)
    local euiTriggerLabel, euiTriggerDrop = Drop(spellSection, "EllesmereUIVEEditorTriggerDropDown", L("LABEL_EUI_TRIGGER"), 532, -38, 250)

    local notifySection = Section(content, L("SECTION_NOTIFY"), 0, -270, 820, 196)
    local sourceLabel, soundSourceDrop = Drop(notifySection, "EllesmereUIVEEditorSoundSourceDropDown", L("SOUND_SOURCE"), 16, -38, 220)
    local builtinLabel, builtinDrop = Drop(notifySection, "EllesmereUIVEEditorBuiltinDropDown", L("LABEL_BUILTIN_SOUND"), 254, -38, 528)
    local sharedMediaLabel, sharedMediaDrop = Drop(notifySection, "EllesmereUIVEEditorSharedMediaDropDown", "LibSharedMedia", 254, -38, 528)
    Widgets:SetDropdownSearchable(builtinDrop, true, L("SEARCH_SOUNDS_PLACEHOLDER"))
    Widgets:SetDropdownSearchable(sharedMediaDrop, true, L("SEARCH_SOUNDS_PLACEHOLDER"))
    local customPathLabel, customPath = Edit(notifySection, L("LABEL_CUSTOM_SOUND_PATH"), 254, -38, 528, false)
    local ttsLabel, ttsText = Edit(notifySection, L("LABEL_TTS_TEXT"), 254, -38, 390, false)
    local ttsRateLabel, ttsRate = Edit(notifySection, L("LABEL_TTS_RATE"), 662, -38, 120, true)
    local voiceEnabled = Widgets:CreateCheckButton(notifySection, L("LABEL_ENABLE_VOICE_ALERT"), 220)
    voiceEnabled:SetPoint("TOPLEFT", notifySection, "TOPLEFT", 16, -118)
    local hint = Label(notifySection, L("EDITOR_HINT"), 254, -118, 528)
    if hint.SetWordWrap then hint:SetWordWrap(true) end

    local castSection = Section(content, L("TAB_CAST"), 0, -478, 820, 86)
    local castDelayEnabled = Widgets:CreateCheckButton(castSection, L("LABEL_CAST_DELAY_EXECUTE"), 240)
    castDelayEnabled:SetPoint("TOPLEFT", castSection, "TOPLEFT", 16, -42)
    local castDelayLabel, castDelaySeconds = Edit(castSection, L("LABEL_DELAY_SECONDS"), 300, -36, 150, true)

    local bloodlustSection = Section(content, L("SECTION_BLOODLUST_SOUND"), 0, -116, 820, 350)
    local bloodlustPaths, bloodlustLabels = {}, {}
    for index = 1, 5 do
        local row = index - 1
        local x = (row % 2) * 398 + 16
        local y = -38 - math.floor(row / 2) * 76
        bloodlustLabels[index], bloodlustPaths[index] = Edit(bloodlustSection, L("LABEL_SOUND_PATH_N", index), x, y, 374, false)
    end

    local actionTest = Widgets:CreateButton(frame, L("BTN_TEST"), 100, 32)
    local saveOnly = Widgets:CreateButton(frame, L("BTN_SAVE_ONLY"), 120, 32)
    local saveInject = Widgets:CreateButton(frame, L("BTN_SAVE_AND_INJECT"), 150, 32)
    local actionSave = Widgets:CreateButton(frame, L("BTN_SAVE"), 120, 32)
    local actionClose = Widgets:CreateButton(frame, L("BTN_CLOSE"), 100, 32)
    actionTest:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 20)
    saveOnly:SetPoint("LEFT", actionTest, "RIGHT", 10, 0)
    saveInject:SetPoint("LEFT", saveOnly, "RIGHT", 10, 0)
    actionSave:SetPoint("LEFT", actionTest, "RIGHT", 10, 0)
    actionClose:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 20)

    frame.widgets = {
        tabEUI = tabEUI, tabCast = tabCast, tabBloodlust = tabBloodlust,
        close = close, scopeSection = scopeSection, scopeButton = scopeButton, scopeSummary = scopeSummary,
        spellSection = spellSection, spellIdLabel = spellIdLabel, spellId = spellId,
        spellNameLabel = spellNameLabel, spellName = spellName,
        euiTriggerLabel = euiTriggerLabel, euiTriggerDrop = euiTriggerDrop,
        notifySection = notifySection, sourceLabel = sourceLabel, soundSourceDrop = soundSourceDrop,
        builtinLabel = builtinLabel, builtinDrop = builtinDrop,
        sharedMediaLabel = sharedMediaLabel, sharedMediaDrop = sharedMediaDrop,
        customPathLabel = customPathLabel, customPath = customPath,
        ttsLabel = ttsLabel, ttsText = ttsText, ttsRateLabel = ttsRateLabel, ttsRate = ttsRate,
        voiceEnabled = voiceEnabled, hint = hint,
        castSection = castSection, castDelayEnabled = castDelayEnabled,
        castDelayLabel = castDelayLabel, castDelaySeconds = castDelaySeconds,
        bloodlustSection = bloodlustSection, bloodlustPaths = bloodlustPaths, bloodlustLabels = bloodlustLabels,
        actionTest = actionTest, saveOnly = saveOnly, saveInject = saveInject,
        actionSave = actionSave, actionClose = actionClose,
    }
    owner.frame = frame
    owner.widgets = frame.widgets
    if NS.UI.EditorActions and type(NS.UI.EditorActions.Install) == "function" then
        NS.UI.EditorActions:Install(owner, frame)
    end
    return frame
end
