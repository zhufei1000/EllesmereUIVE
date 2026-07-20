local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.EditorFields = NS.UI.EditorFields or {}
local Fields = NS.UI.EditorFields
local Widgets = NS.UI.Widgets
local SoundFields = NS.UI.EditorSoundFields
local L = NS.L or function(key) return tostring(key) end

local function Trim(value)
    return NS.Utils and NS.Utils.TrimText(value) or tostring(value or ""):match("^%s*(.-)%s*$")
end

local function GetValue(control, fallback)
    if control and Widgets and type(Widgets.GetDropdownValue) == "function" then
        local value = Widgets:GetDropdownValue(control)
        if value ~= nil then return value end
    end
    return fallback
end

local function SetValue(control, value, fallback)
    if control and Widgets and type(Widgets.SetDropdownValue) == "function" then
        Widgets:SetDropdownValue(control, value, fallback)
    end
end

local function SetShown(frame, shown)
    if frame then frame:SetShown(shown == true) end
end

function Fields:PullFromWidgets(editor)
    local frame = editor and editor.frame
    local w = frame and frame.widgets
    if not w then return end
    local state = NS.AceOptions:GetState()

    state.spellId = tonumber(w.spellId:GetText()) or 0
    state.spellName = Trim(w.spellName:GetText())
    state.euiTriggerType = tostring(GetValue(w.euiTriggerDrop, state.euiTriggerType or "cdReady"))
    state.soundSource = tostring(GetValue(w.soundSourceDrop, state.soundSource or "builtin"))
    if state.entryType == "euiVoice" and state.soundSource == "tts" then state.soundSource = "builtin" end
    state.builtinSoundPath = tostring(GetValue(w.builtinDrop, state.builtinSoundPath or NS.AceOptions:GetDefaultBuiltinSoundPath()))
    state.sharedMediaSound = tostring(GetValue(w.sharedMediaDrop, state.sharedMediaSound or ""))
    state.customSoundPath = NS.AceOptions:NormalizeSoundPath(w.customPath:GetText())
    state.customSoundPaths = state.customSoundPaths or { "", "", "", "", "" }
    state.customSoundPaths[1] = state.customSoundPath
    state.ttsText = w.ttsText:GetText() or ""
    state.ttsRate = tonumber(w.ttsRate:GetText()) or 0
    state.voiceEnabled = w.voiceEnabled:GetChecked() == true
    state.enabled = state.voiceEnabled
    state.delayEnabled = w.castDelayEnabled:GetChecked() == true
    state.delaySeconds = math.max(0, tonumber(w.castDelaySeconds:GetText()) or 0)
    state.castDelayMode = "show"

    if state.entryType == "bloodlust" then
        state.customSoundPaths = {}
        for index = 1, 5 do
            state.customSoundPaths[index] = NS.AceOptions:NormalizeSoundPath(w.bloodlustPaths[index]:GetText())
        end
        state.customSoundPath = state.customSoundPaths[1] or ""
    end

    local resolved = SoundFields:Resolve(state)
    NS.AceOptions:ApplySoundSourceToState(resolved)
    state.imageEnabled = false
    state.textEnabled = false
    return state
end

function Fields:PushToWidgets(editor)
    local frame = editor and editor.frame
    local w = frame and frame.widgets
    if not w then return end
    local state = NS.AceOptions:GetState()
    local entryType = tostring(state.entryType or "euiVoice")
    local isEUI, isCast, isBloodlust = entryType == "euiVoice", entryType == "cast", entryType == "bloodlust"

    if Widgets then
        Widgets:SetDropdownItems(w.euiTriggerDrop, {
            { value = "cdReady", text = L("TRIGGER_CD") },
            { value = "buffGain", text = L("TRIGGER_GAIN") },
            { value = "buffLoss", text = L("TRIGGER_LOSS") },
        })
        Widgets:SetDropdownItems(w.soundSourceDrop, SoundFields:GetSourceItems(not isEUI))
        Widgets:SetDropdownItems(w.builtinDrop, SoundFields:GetBuiltinItems())
        Widgets:SetDropdownItems(w.sharedMediaDrop, SoundFields:GetSharedMediaItems())
        Widgets:SetDropdownSearchable(w.builtinDrop, true, L("SEARCH_SOUNDS_PLACEHOLDER"))
        Widgets:SetDropdownSearchable(w.sharedMediaDrop, true, L("SEARCH_SOUNDS_PLACEHOLDER"))
    end

    SetValue(w.euiTriggerDrop, state.euiTriggerType or "cdReady", L("TRIGGER_CD"))
    if isEUI and state.soundSource == "tts" then state.soundSource = "builtin" end
    SetValue(w.soundSourceDrop, state.soundSource or "builtin", L("LABEL_BUILTIN_SOUND"))
    SetValue(w.builtinDrop, state.builtinSoundPath or NS.AceOptions:GetDefaultBuiltinSoundPath(), L("PLACEHOLDER_SELECT_BUILTIN_SOUND"))
    SetValue(w.sharedMediaDrop, state.sharedMediaSound or "", "LibSharedMedia")
    w.spellId:SetText((tonumber(state.spellId) or 0) > 0 and tostring(state.spellId) or "")
    w.spellName:SetText(state.spellName or "")
    w.customPath:SetText(state.customSoundPath or state.soundPath or "")
    w.ttsText:SetText(state.ttsText or "")
    w.ttsRate:SetText(tostring(tonumber(state.ttsRate) or 0))
    w.voiceEnabled:SetChecked(state.voiceEnabled ~= false)
    w.castDelayEnabled:SetChecked(state.delayEnabled == true)
    w.castDelaySeconds:SetText(tostring(tonumber(state.delaySeconds) or 0))
    for index = 1, 5 do
        w.bloodlustPaths[index]:SetText(type(state.customSoundPaths) == "table" and state.customSoundPaths[index] or "")
    end

    local source = tostring(state.soundSource or "builtin")
    SetShown(w.scopeSection, not isBloodlust)
    SetShown(w.spellSection, not isBloodlust)
    w.notifySection:ClearAllPoints()
    if isBloodlust then
        w.notifySection:SetPoint("TOPLEFT", frame.contentHost, "TOPLEFT", 0, 0)
        w.bloodlustSection:ClearAllPoints()
        w.bloodlustSection:SetPoint("TOPLEFT", frame.contentHost, "TOPLEFT", 0, -208)
    else
        w.notifySection:SetPoint("TOPLEFT", frame.contentHost, "TOPLEFT", 0, -270)
    end
    SetShown(w.euiTriggerLabel, isEUI)
    SetShown(w.euiTriggerDrop, isEUI)
    SetShown(w.builtinLabel, source == "builtin")
    SetShown(w.builtinDrop, source == "builtin")
    SetShown(w.sharedMediaLabel, source == "sharedmedia")
    SetShown(w.sharedMediaDrop, source == "sharedmedia")
    SetShown(w.customPathLabel, source == "custom")
    SetShown(w.customPath, source == "custom")
    SetShown(w.ttsLabel, source == "tts" and not isEUI)
    SetShown(w.ttsText, source == "tts" and not isEUI)
    SetShown(w.ttsRateLabel, source == "tts" and not isEUI)
    SetShown(w.ttsRate, source == "tts" and not isEUI)
    SetShown(w.castSection, isCast)
    SetShown(w.bloodlustSection, isBloodlust)
    SetShown(w.saveOnly, isEUI)
    SetShown(w.saveInject, isEUI)
    SetShown(w.actionSave, not isEUI)
    w.tabEUI:SetEnabled(not isEUI)
    w.tabCast:SetEnabled(not isCast)
    w.tabBloodlust:SetEnabled(not isBloodlust)
    if w.scopeSummary and NS.UI.ScopeSelector and type(NS.UI.ScopeSelector.BuildSummary) == "function" then
        w.scopeSummary:SetText(NS.UI.ScopeSelector:BuildSummary(state))
    end
    frame.title:SetText(editor.mode == "edit" and L("TITLE_EDIT_CONFIG") or L("TITLE_NEW_CONFIG"))
end

function Fields:RefreshLocale(editor)
    local frame = editor and editor.frame
    local w = frame and frame.widgets
    if not w then return end
    w.tabEUI:SetText(L("TAB_COOLDOWN"))
    w.tabCast:SetText(L("TAB_CAST"))
    w.tabBloodlust:SetText(L("TAB_BLOODLUST"))
    w.saveOnly:SetText(L("BTN_SAVE_ONLY"))
    w.saveInject:SetText(L("BTN_SAVE_AND_INJECT"))
    w.actionSave:SetText(L("BTN_SAVE"))
    w.actionTest:SetText(L("BTN_TEST"))
    w.actionClose:SetText(L("BTN_CLOSE"))
    self:PushToWidgets(editor)
end
