local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.EditorDrafts = NS.UI.EditorDrafts or {}

local Drafts = NS.UI.EditorDrafts

local EDITOR_DRAFT_FIELDS = {
    "spellId", "objectType", "spellName", "itemLoadMode", "itemLoadSameName", "euiTriggerType",
    "baseCD", "fixedCD", "checkTalent", "talentId", "talentName", "talentCD",
    "delayEnabled", "delaySeconds", "castDelayMode", "cooldownAlertTime",
    "alertRaceIDs", "alertClassIDs", "alertSpecIDs",
    "notifyMode", "ttsText", "ttsRate", "voiceEnabled", "voiceConditionOp", "voiceConditionTime",
    "builtinSoundPath", "sharedMediaSound", "useSharedMediaSound",
    "customSoundPath", "customSoundPaths", "useCustomSound", "soundSource", "soundPath",
    "activeAlertTab", "imageEnabled", "imageConditionOp", "imageConditionTime", "imageSource", "imageIconID", "imagePath", "imageSize", "imageDurationEnabled", "imageDuration", "imageX", "imageY",
    "textEnabled", "textConditionOp", "textConditionTime", "textAlert", "textSize", "textDurationEnabled", "textDuration", "textX", "textY", "textAttachMode", "textVAlign", "textHAlign", "textOffsetX", "textOffsetY",
}

function Drafts:NormalizeEntryType(value)
    value = tostring(value or "euiVoice")
    if value == "cast" then
        return "cast"
    elseif value == "bloodlust" then
        return "bloodlust"
    end
    return "euiVoice"
end

function Drafts:Save(state, entryType)
    if not state then
        return
    end
    entryType = self:NormalizeEntryType(entryType or state.entryType)
    state._editorDrafts = state._editorDrafts or {}
    local draft = {}
    for _, key in ipairs(EDITOR_DRAFT_FIELDS) do
        draft[key] = state[key]
    end
    state._editorDrafts[entryType] = draft
end

function Drafts:ApplyBlank(state, entryType)
    if not state then
        return
    end
    local api = NS.API
    local modeSound = "SOUND"
    if api and type(api.GetModes) == "function" then
        local _modeTts
        _modeTts, modeSound = api.GetModes()
    end
    local defaultSound = NS.AceOptions and NS.AceOptions.GetDefaultBuiltinSoundPath and NS.AceOptions:GetDefaultBuiltinSoundPath() or ""

    state.spellId = 0
    state.objectType = nil
    state.spellName = ""
    state.baseCD = 0
    state.fixedCD = true
    state.checkTalent = false
    state.talentId = 0
    state.talentName = ""
    state.talentCD = 0
    state.delayEnabled = false
    state.delaySeconds = 0
    state.castDelayMode = "show"
    state.cooldownAlertTime = 0
    state.euiTriggerType = "cdReady"
    state.injectOnSave = false
    local classID, specID = 0, 0
    if NS.API and type(NS.API.GetCurrentClassSpec) == "function" then
        classID, specID = NS.API.GetCurrentClassSpec()
    end
    classID = tonumber(classID) or 0
    specID = tonumber(specID) or 0
    state.alertClassIDs = { [classID > 0 and classID or 0] = true }
    state.alertSpecIDs = { [specID > 0 and specID or 0] = true }
    state.alertRaceIDs = { [0] = true }
    state.notifyMode = modeSound
    state.ttsText = ""
    state.ttsRate = 0
    state.voiceEnabled = true
    state.voiceConditionOp = "<="
    state.voiceConditionTime = 0
    state.activeAlertTab = "settings"
    state.imageEnabled = false
    state.imageConditionOp = "<="
    state.imageConditionTime = 0
    state.imageSource = "auto"
    state.imageIconID = 0
    state.imagePath = ""
    state.imageSize = 96
    state.imageDurationEnabled = false
    state.imageDuration = 2
    state.imageX = 0
    state.imageY = 120
    state.textEnabled = false
    state.textConditionOp = "<="
    state.textConditionTime = 0
    state.textAlert = ""
    state.textSize = 24
    state.textDurationEnabled = false
    state.textDuration = 2
    state.textX = 0
    state.textY = 120
    state.textAttachMode = "outside"
    state.textVAlign = "bottom"
    state.textHAlign = "center"
    state.textOffsetX = 0
    state.textOffsetY = 0
    state.builtinSoundPath = defaultSound
    state.sharedMediaSound = ""
    state.useSharedMediaSound = false
    state.customSoundPath = ""
    state.customSoundPaths = { "", "", "", "", "" }
    state.useCustomSound = false
    state.soundSource = "builtin"
    state.soundPath = defaultSound
    state.entryType = self:NormalizeEntryType(entryType)
end

function Drafts:Restore(state, entryType)
    if not state then
        return
    end
    entryType = self:NormalizeEntryType(entryType)
    local draft = state._editorDrafts and state._editorDrafts[entryType]
    if type(draft) ~= "table" then
        self:ApplyBlank(state, entryType)
        return
    end
    for _, key in ipairs(EDITOR_DRAFT_FIELDS) do
        state[key] = draft[key]
    end
    state.entryType = entryType
    state.fixedCD = true
end
