local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.OptionsController = NS.OptionsController or {}
local Controller = NS.OptionsController

local L = NS.L or function(key, ...)
    if select("#", ...) > 0 then
        return string.format(tostring(key), ...)
    end
    return tostring(key)
end

local Utils = NS.Utils or {}
local CollectionStore = NS.CollectionStore or {}

local function NormalizeConditionOp(value)
    value = tostring(value or "<=")
    if value == "<" or value == "<=" or value == ">" or value == ">=" or value == "==" then
        return value
    end
    if value == "=" then
        return "=="
    end
    return "<="
end

local function TrimText(value)
    if Utils.TrimText then
        return Utils.TrimText(value)
    end
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function GetApi()
    return NS.API
end

local function ParseGroupKey(key)
    if CollectionStore and type(CollectionStore.ParseGroupKey) == "function" then
        return CollectionStore.ParseGroupKey(key)
    end
    local classID, specID, groupID = tostring(key or ""):match("^group:(%-?%d+):(%-?%d+):(.+)$")
    return tonumber(classID) or -1, tonumber(specID) or -1, tostring(groupID or "")
end

local function EnsureBloodlustConfigTable()
    local db = EllesmereUIVEDB
    if type(db) ~= "table" then
        db = {}
        EllesmereUIVEDB = db
    end

    if type(db.bloodlustConfig) ~= "table" then
        db.bloodlustConfig = {}
    end

    local cfg = db.bloodlustConfig
    if type(cfg.customSoundPaths) ~= "table" then
        cfg.customSoundPaths = { "", "", "", "", "" }
    end
    for i = 1, 5 do
        cfg.customSoundPaths[i] = TrimText(cfg.customSoundPaths[i] or "")
    end
    cfg.voiceEnabled = cfg.voiceEnabled ~= false
    cfg.voiceConditionOp = NormalizeConditionOp(cfg.voiceConditionOp)
    cfg.voiceConditionTime = math.max(0, tonumber(cfg.voiceConditionTime) or 0)
    cfg.imageEnabled = cfg.imageEnabled == true
    cfg.imageConditionOp = NormalizeConditionOp(cfg.imageConditionOp)
    cfg.imageConditionTime = math.max(0, tonumber(cfg.imageConditionTime) or 0)
    cfg.imageSource = tostring(cfg.imageSource or "auto")
    if cfg.imageSource ~= "spell" and cfg.imageSource ~= "item" and cfg.imageSource ~= "icon" and cfg.imageSource ~= "path" then cfg.imageSource = "auto" end
    cfg.imageIconID = math.max(0, tonumber(cfg.imageIconID) or 0)
    cfg.imagePath = TrimText(cfg.imagePath or "")
    cfg.imageSize = math.max(16, tonumber(cfg.imageSize) or 96)
    cfg.imageDurationEnabled = cfg.imageDurationEnabled == true
    cfg.imageDuration = math.max(0.1, tonumber(cfg.imageDuration) or 2)
    cfg.imageX = tonumber(cfg.imageX) or 0
    cfg.imageY = tonumber(cfg.imageY) or 120
    cfg.textEnabled = cfg.textEnabled == true
    cfg.textConditionOp = NormalizeConditionOp(cfg.textConditionOp)
    cfg.textConditionTime = math.max(0, tonumber(cfg.textConditionTime) or 0)
    cfg.textAlert = tostring(cfg.textAlert or "")
    cfg.textSize = math.max(8, tonumber(cfg.textSize) or 24)
    cfg.textDurationEnabled = cfg.textDurationEnabled == true
    cfg.textDuration = math.max(0.1, tonumber(cfg.textDuration) or 2)
    if Utils.SyncLinkedVisualDurations then
        Utils.SyncLinkedVisualDurations(cfg)
    end
    cfg.textX = tonumber(cfg.textX) or 0
    cfg.textY = tonumber(cfg.textY) or 120
    cfg.textAttachMode = tostring(cfg.textAttachMode or "outside")
    if cfg.textAttachMode ~= "inside" then cfg.textAttachMode = "outside" end
    cfg.textVAlign = tostring(cfg.textVAlign or "bottom")
    if cfg.textVAlign ~= "top" and cfg.textVAlign ~= "middle" then cfg.textVAlign = "bottom" end
    cfg.textHAlign = tostring(cfg.textHAlign or "center")
    if cfg.textHAlign ~= "left" and cfg.textHAlign ~= "right" then cfg.textHAlign = "center" end
    cfg.textOffsetX = tonumber(cfg.textOffsetX) or 0
    cfg.textOffsetY = tonumber(cfg.textOffsetY) or 0
    return cfg
end

local function FirstNonEmptyCustomPath(cfg)
    if TrimText(cfg.customSoundPath or "") ~= "" then
        return cfg.customSoundPath
    end
    local paths = type(cfg.customSoundPaths) == "table" and cfg.customSoundPaths or {}
    for i = 1, 5 do
        local path = TrimText(paths[i] or "")
        if path ~= "" then
            return path
        end
    end
    return ""
end

local function CopyBloodlustCustomPathsFromConfig(cfg, normalizeSoundPath)
    local result = { "", "", "", "", "" }
    local paths = type(cfg.customSoundPaths) == "table" and cfg.customSoundPaths or {}
    for i = 1, 5 do
        result[i] = normalizeSoundPath(paths[i] or "")
    end
    if TrimText(cfg.customSoundPath or "") ~= "" and TrimText(result[1] or "") == "" then
        result[1] = normalizeSoundPath(cfg.customSoundPath)
    end
    return result
end

local function FirstNonEmptyPath(paths)
    if type(paths) ~= "table" then
        return ""
    end
    for i = 1, 5 do
        local path = TrimText(paths[i] or "")
        if path ~= "" then
            return path
        end
    end
    return ""
end

function Controller:LoadBloodlustConfig(aceOptions)
    local api = GetApi()
    local state = aceOptions:GetState()
    local cfg = EnsureBloodlustConfigTable()
    local modeTts, modeSound = "tts", "sound"
    if api and type(api.GetModes) == "function" then
        modeTts, modeSound = api.GetModes()
    end

    state.entryType = "bloodlust"
    state.activeAlertTab = "settings"
    state.voiceEnabled = cfg.voiceEnabled ~= false
    state.voiceConditionOp = NormalizeConditionOp(cfg.voiceConditionOp)
    state.voiceConditionTime = math.max(0, tonumber(cfg.voiceConditionTime) or 0)
    state.ttsText = tostring(cfg.ttsText or "")
    state.ttsRate = math.max(-10, math.min(10, tonumber(cfg.ttsRate) or 0))
    state.builtinSoundPath = aceOptions:NormalizeSoundPath(cfg.builtinSoundPath or aceOptions:GetDefaultBuiltinSoundPath())
    if state.builtinSoundPath == "" or not aceOptions:IsBuiltinSoundPath(state.builtinSoundPath) then
        state.builtinSoundPath = aceOptions:GetDefaultBuiltinSoundPath()
    end
    state.sharedMediaSound = TrimText(cfg.sharedMediaSound or cfg.sharedMediaName or "")
    state.customSoundPaths = CopyBloodlustCustomPathsFromConfig(cfg, function(path) return aceOptions:NormalizeSoundPath(path or "") end)
    local firstBloodlustCustomPath = FirstNonEmptyPath(state.customSoundPaths)
    state.customSoundPath = aceOptions:NormalizeSoundPath(TrimText(state.customSoundPaths[1] or "") ~= "" and state.customSoundPaths[1] or firstBloodlustCustomPath or FirstNonEmptyCustomPath(cfg))
    state.soundPath = aceOptions:NormalizeSoundPath(TrimText(cfg.soundPath or "") ~= "" and cfg.soundPath or firstBloodlustCustomPath or "")
    state.soundSource = tostring(cfg.soundSource or "")
    state.notifyMode = tostring(cfg.notifyMode or modeSound)

    local soundFields = aceOptions:ResolveSoundSourceFields({
        notifyMode = state.notifyMode,
        soundSource = state.soundSource,
        soundPath = state.soundPath,
        builtinSoundPath = state.builtinSoundPath,
        customSoundPath = state.customSoundPath ~= "" and state.customSoundPath or firstBloodlustCustomPath,
        customSoundPaths = state.customSoundPaths,
        sharedMediaSound = state.sharedMediaSound,
    }, modeTts, modeSound)
    aceOptions:ApplySoundSourceToState(soundFields)

    state.imageEnabled = cfg.imageEnabled == true
    state.imageConditionOp = NormalizeConditionOp(cfg.imageConditionOp)
    state.imageConditionTime = math.max(0, tonumber(cfg.imageConditionTime) or 0)
    state.imageSource = tostring(cfg.imageSource or "auto")
    state.imageIconID = math.max(0, tonumber(cfg.imageIconID) or 0)
    state.imagePath = TrimText(cfg.imagePath or "")
    state.imageSize = math.max(16, tonumber(cfg.imageSize) or 96)
    state.imageDurationEnabled = cfg.imageDurationEnabled == true
    state.imageDuration = math.max(0.1, tonumber(cfg.imageDuration) or 2)
    state.imageX = tonumber(cfg.imageX) or 0
    state.imageY = tonumber(cfg.imageY) or 120
    state.textEnabled = cfg.textEnabled == true
    state.textConditionOp = NormalizeConditionOp(cfg.textConditionOp)
    state.textConditionTime = math.max(0, tonumber(cfg.textConditionTime) or 0)
    state.textAlert = tostring(cfg.textAlert or "")
    state.textSize = math.max(8, tonumber(cfg.textSize) or 24)
    state.textDurationEnabled = cfg.textDurationEnabled == true
    state.textDuration = math.max(0.1, tonumber(cfg.textDuration) or 2)
    if Utils.SyncLinkedVisualDurations then
        Utils.SyncLinkedVisualDurations(state)
    end
    state.textX = tonumber(cfg.textX) or 0
    state.textY = tonumber(cfg.textY) or 120
    state.textAttachMode = tostring(cfg.textAttachMode or "outside")
    state.textVAlign = tostring(cfg.textVAlign or "bottom")
    state.textHAlign = tostring(cfg.textHAlign or "center")
    state.textOffsetX = tonumber(cfg.textOffsetX) or 0
    state.textOffsetY = tonumber(cfg.textOffsetY) or 0
end

function Controller:GetBloodlustSummary(aceOptions)
    return L("MSG_BLOODLUST_SUMMARY")
end

function Controller:SaveBloodlustConfig(aceOptions)
    local api = GetApi()
    local state = aceOptions:GetState()
    local cfg = EnsureBloodlustConfigTable()
    local modeTts, modeSound = "tts", "sound"
    if api and type(api.GetModes) == "function" then
        modeTts, modeSound = api.GetModes()
    end
    local sourceForSave = {
        notifyMode = state.notifyMode,
        soundSource = state.soundSource,
        soundPath = state.soundPath,
        builtinSoundPath = state.builtinSoundPath,
        customSoundPath = state.customSoundPath,
        sharedMediaSound = state.sharedMediaSound,
        sharedMediaName = state.sharedMediaName,
    }
    local pendingCustomPaths = type(state.customSoundPaths) == "table" and state.customSoundPaths or { state.customSoundPath or "", "", "", "", "" }
    local firstPendingCustomPath = FirstNonEmptyPath(pendingCustomPaths)
    if tostring(sourceForSave.soundSource or "") == "builtin" then
        sourceForSave.soundPath = state.builtinSoundPath or state.soundPath
    elseif tostring(sourceForSave.soundSource or "") == "custom" then
        sourceForSave.customSoundPath = firstPendingCustomPath ~= "" and firstPendingCustomPath or state.customSoundPath or ""
        sourceForSave.soundPath = sourceForSave.customSoundPath ~= "" and sourceForSave.customSoundPath or state.soundPath
    end

    local soundFields = aceOptions:ResolveSoundSourceFields(sourceForSave, modeTts, modeSound)
    local soundSource = tostring(soundFields.soundSource or "builtin")
    local soundPath = aceOptions:NormalizeSoundPath(soundFields.soundPath or "")
    if soundSource == "custom" and soundPath == "" then
        soundPath = aceOptions:NormalizeSoundPath(firstPendingCustomPath or "")
    end
    local voiceEnabled = state.voiceEnabled ~= false
    local imageEnabled = state.imageEnabled == true
    local textEnabled = state.textEnabled == true

    if not voiceEnabled and not imageEnabled and not textEnabled then
        print("[EUIVE] " .. L("MSG_NEED_ALERT_ACTIONS"))
        return false
    end
    if voiceEnabled and tostring(soundFields.notifyMode or "") == tostring(modeTts) and TrimText(state.ttsText or "") == "" then
        print("[EUIVE] " .. L("MSG_NEED_TTS_TEXT"))
        return false
    end
    if voiceEnabled and tostring(soundFields.notifyMode or "") == tostring(modeSound) and TrimText(soundPath) == "" then
        print("[EUIVE] " .. L("MSG_NEED_SOUND_PATH"))
        return false
    end

    cfg.voiceEnabled = voiceEnabled
    cfg.voiceConditionOp = NormalizeConditionOp(state.voiceConditionOp)
    cfg.voiceConditionTime = math.max(0, tonumber(state.voiceConditionTime) or 0)
    cfg.notifyMode = soundFields.notifyMode
    cfg.soundSource = soundSource
    cfg.soundPath = soundPath
    cfg.builtinSoundPath = aceOptions:NormalizeSoundPath(soundFields.builtinSoundPath or state.builtinSoundPath or aceOptions:GetDefaultBuiltinSoundPath())
    cfg.customSoundPaths = { "", "", "", "", "" }
    for i = 1, 5 do
        cfg.customSoundPaths[i] = aceOptions:NormalizeSoundPath(pendingCustomPaths[i] or "")
    end
    cfg.customSoundPath = aceOptions:NormalizeSoundPath((soundSource == "custom" and FirstNonEmptyPath(cfg.customSoundPaths)) or soundFields.customSoundPath or state.customSoundPath or "")
    cfg.soundPath = soundSource == "custom" and cfg.customSoundPath or soundPath
    cfg.sharedMediaSound = (soundSource == "sharedmedia" and TrimText(soundFields.sharedMediaSound or "") ~= "") and TrimText(soundFields.sharedMediaSound or "") or ""
    cfg.ttsText = tostring(state.ttsText or "")
    cfg.ttsRate = math.max(-10, math.min(10, tonumber(state.ttsRate) or 0))

    cfg.imageEnabled = imageEnabled
    cfg.imageConditionOp = NormalizeConditionOp(state.imageConditionOp)
    cfg.imageConditionTime = math.max(0, tonumber(state.imageConditionTime) or 0)
    cfg.imageSource = tostring(state.imageSource or "auto")
    cfg.imageIconID = math.max(0, tonumber(state.imageIconID) or 0)
    cfg.imagePath = TrimText(state.imagePath or "")
    cfg.imageSize = math.max(16, tonumber(state.imageSize) or 96)
    cfg.imageDurationEnabled = state.imageDurationEnabled == true
    cfg.imageDuration = math.max(0.1, tonumber(state.imageDuration) or 2)
    cfg.imageX = math.floor((tonumber(state.imageX) or 0) + 0.5)
    cfg.imageY = math.floor((tonumber(state.imageY) or 120) + 0.5)
    cfg.textEnabled = textEnabled
    cfg.textConditionOp = NormalizeConditionOp(state.textConditionOp)
    cfg.textConditionTime = math.max(0, tonumber(state.textConditionTime) or 0)
    cfg.textAlert = tostring(state.textAlert or "")
    cfg.textSize = math.max(8, tonumber(state.textSize) or 24)
    cfg.textDurationEnabled = state.textDurationEnabled == true
    cfg.textDuration = math.max(0.1, tonumber(state.textDuration) or 2)
    if Utils.SyncLinkedVisualDurations then
        Utils.SyncLinkedVisualDurations(cfg)
        state.imageDurationEnabled = cfg.imageDurationEnabled == true
        state.textDurationEnabled = cfg.textDurationEnabled == true
    end
    cfg.textX = math.floor((tonumber(state.textX) or 0) + 0.5)
    cfg.textY = math.floor((tonumber(state.textY) or 120) + 0.5)
    cfg.textAttachMode = tostring(state.textAttachMode or "outside")
    cfg.textVAlign = tostring(state.textVAlign or "bottom")
    cfg.textHAlign = tostring(state.textHAlign or "center")
    cfg.textOffsetX = math.floor((tonumber(state.textOffsetX) or 0) + 0.5)
    cfg.textOffsetY = math.floor((tonumber(state.textOffsetY) or 0) + 0.5)

    self:LoadBloodlustConfig(aceOptions)

    if api and type(api.RebuildBloodlustConfig) == "function" then
        api.RebuildBloodlustConfig()
    end
    if api and type(api.RefreshPanel) == "function" then
        api.RefreshPanel()
    end

    print("[EUIVE] " .. L("MSG_BLOODLUST_SAVED"))
    return true
end

function Controller:GetCurrentScopeSummary(aceOptions)
    local api = GetApi()
    local state = aceOptions:GetState()
    if not api then
        return ""
    end

    local className = api.ResolveClassName(state.classID)
    local specName = api.ResolveSpecName(state.classID, state.specID)
    return L("MSG_CURRENT_EDIT_SCOPE", className, specName)
end

function Controller:ApplyStateToWidgets()
    if NS.UI and NS.UI.EditorFrame and NS.UI.EditorFrame.frame and NS.UI.EditorFrame.frame.IsShown and NS.UI.EditorFrame.frame:IsShown() then
        NS.UI.EditorFrame:Refresh()
    end
    return true
end

function Controller:OpenEditorPopup()
    if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.Open) == "function" then
        return NS.UI.MainFrame:Open()
    end
    return false
end

function Controller:ToggleCollectionCollapsed(groupKey)
    local classID, specID, groupID = ParseGroupKey(groupKey)
    if classID < 0 or specID < 0 or tostring(groupID or "") == "" then
        return false
    end

    local scope = EnsureCollectionScope(classID, specID)
    local group = scope and scope.groups and scope.groups[tostring(groupID)]
    if type(group) ~= "table" then
        return false
    end

    group.collapsed = not (group.collapsed == true)
    return true
end

function Controller:Initialize(aceOptions)
    aceOptions.initialized = true
    aceOptions.available = true
    aceOptions.AceGUI = nil
    aceOptions.frameWidget = nil
    return true
end

function Controller:Open()
    if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.Open) == "function" then
        return NS.UI.MainFrame:Open()
    end
    return false
end

function Controller:CreateWindow(aceOptions)
    aceOptions.frameWidget = nil
    return self:Open()
end

function Controller:RefreshSavedList()
    if NS.UI and NS.UI.MainFrame and NS.UI.MainFrame.savedList and type(NS.UI.MainFrame.savedList.Refresh) == "function" then
        NS.UI.MainFrame.savedList:Refresh()
        return true
    end
    return false
end

function Controller:RefreshUI()
    if NS.UI and NS.UI.MainFrame and NS.UI.MainFrame.frame and type(NS.UI.MainFrame.Refresh) == "function" then
        NS.UI.MainFrame:Refresh()
    end
    if NS.UI and NS.UI.EditorFrame and NS.UI.EditorFrame.frame and NS.UI.EditorFrame.frame.IsShown and NS.UI.EditorFrame.frame:IsShown() and type(NS.UI.EditorFrame.Refresh) == "function" then
        NS.UI.EditorFrame:Refresh()
    end
    return true
end

local AceOptions = NS.AceOptions or {}
NS.AceOptions = AceOptions

function AceOptions:LoadBloodlustConfig()
    return Controller:LoadBloodlustConfig(self)
end

function AceOptions:GetBloodlustSummary()
    return Controller:GetBloodlustSummary(self)
end

function AceOptions:SaveBloodlustConfig()
    return Controller:SaveBloodlustConfig(self)
end

function AceOptions:TestBloodlustConfig()
    if NS.TestController and type(NS.TestController.TestBloodlustConfig) == "function" then
        return NS.TestController:TestBloodlustConfig(self)
    end
end

function AceOptions:GetCurrentScopeSummary()
    return Controller:GetCurrentScopeSummary(self)
end

function AceOptions:LoadSelectedEntry()
    if NS.EntryStore and type(NS.EntryStore.LoadSelectedEntry) == "function" then
        return NS.EntryStore:LoadSelectedEntry(self)
    end
end

function AceOptions:AutofillFromSpellId()
    if NS.EntryStore and type(NS.EntryStore.AutofillFromSpellId) == "function" then
        return NS.EntryStore:AutofillFromSpellId(self)
    end
end

function AceOptions:AutofillFromTalentId()
    if NS.EntryStore and type(NS.EntryStore.AutofillFromTalentId) == "function" then
        return NS.EntryStore:AutofillFromTalentId(self)
    end
end

function AceOptions:SaveEntry()
    if NS.EntryStore and type(NS.EntryStore.SaveEntry) == "function" then
        return NS.EntryStore:SaveEntry(self)
    end
end

function AceOptions:DeleteSelectedEntry(suppressRefresh)
    if NS.EntryStore and type(NS.EntryStore.DeleteSelectedEntry) == "function" then
        return NS.EntryStore:DeleteSelectedEntry(self, suppressRefresh)
    end
end

function AceOptions:TestCurrent()
    if NS.TestController and type(NS.TestController.TestCurrent) == "function" then
        return NS.TestController:TestCurrent(self)
    end
end

function AceOptions:SyncStateFromWidgets()
    if NS.OptionsState and type(NS.OptionsState.SyncStateFromWidgets) == "function" then
        return NS.OptionsState:SyncStateFromWidgets(self)
    end
end

function AceOptions:ApplyStateToWidgets()
    return Controller:ApplyStateToWidgets(self)
end

function AceOptions:OpenEditorPopup()
    return Controller:OpenEditorPopup(self)
end

function AceOptions:ToggleCollectionCollapsed(groupKey)
    return Controller:ToggleCollectionCollapsed(groupKey)
end

function AceOptions:Initialize()
    return Controller:Initialize(self)
end

function AceOptions:Open()
    return Controller:Open(self)
end

function AceOptions:CreateWindow()
    return Controller:CreateWindow(self)
end

function AceOptions:RefreshSavedList()
    return Controller:RefreshSavedList(self)
end

function AceOptions:RefreshUI()
    return Controller:RefreshUI(self)
end
