local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.TestController = NS.TestController or {}

local TestController = NS.TestController
local CONST = NS.Constants or {}
local Utils = NS.Utils or {}
local OBJECT_TYPE_SPELL = CONST.OBJECT_TYPE_SPELL or "spell"

local function GetApi()
    return NS.API
end

local function BuildVisualFields(state)
    local fields = {
        voiceEnabled = state.voiceEnabled ~= false,
        voiceConditionOp = tostring(state.voiceConditionOp or "<="),
        voiceConditionTime = math.max(0, tonumber(state.voiceConditionTime) or 0),
        imageEnabled = state.imageEnabled == true,
        imageConditionOp = tostring(state.imageConditionOp or "<="),
        imageConditionTime = math.max(0, tonumber(state.imageConditionTime) or 0),
        imageSource = tostring(state.imageSource or "auto"),
        imageIconID = math.max(0, tonumber(state.imageIconID) or 0),
        imagePath = tostring(state.imagePath or ""),
        imageSize = math.max(16, tonumber(state.imageSize) or 96),
        imageDurationEnabled = state.imageDurationEnabled == true,
        imageDuration = math.max(0.1, tonumber(state.imageDuration) or 2),
        imageX = tonumber(state.imageX) or 0,
        imageY = tonumber(state.imageY) or 120,
        textEnabled = state.textEnabled == true,
        textConditionOp = tostring(state.textConditionOp or "<="),
        textConditionTime = math.max(0, tonumber(state.textConditionTime) or 0),
        textAlert = tostring(state.textAlert or ""),
        textSize = math.max(8, tonumber(state.textSize) or 24),
        textDurationEnabled = state.textDurationEnabled == true,
        textDuration = math.max(0.1, tonumber(state.textDuration) or 2),
        textX = tonumber(state.textX) or 0,
        textY = tonumber(state.textY) or 120,
        textAttachMode = tostring(state.textAttachMode or "outside"),
        textVAlign = tostring(state.textVAlign or "bottom"),
        textHAlign = tostring(state.textHAlign or "center"),
        textOffsetX = tonumber(state.textOffsetX) or 0,
        textOffsetY = tonumber(state.textOffsetY) or 0,
        delayEnabled = state.delayEnabled == true,
        delaySeconds = math.max(0, tonumber(state.delaySeconds) or 0),
        castDelayMode = "show",
    }
    if Utils.SyncLinkedVisualDurations then
        Utils.SyncLinkedVisualDurations(fields)
    end
    return fields
end

function TestController:TestBloodlustConfig(aceOptions)
    local api = GetApi()
    local state = aceOptions and aceOptions.GetState and aceOptions:GetState() or {}
    if not api or type(api.PlayBloodlustNotification) ~= "function" then
        return
    end

    local modeTts, modeSound = api.GetModes()
    local soundFields = aceOptions:ResolveSoundSourceFields(state, modeTts, modeSound)
    local cfg = BuildVisualFields(state)
    cfg.notifyMode = soundFields.notifyMode
    cfg.soundSource = soundFields.soundSource
    cfg.soundPath = aceOptions:NormalizeSoundPath(soundFields.soundPath or "")
    cfg.customSoundPaths = { "", "", "", "", "" }
    local statePaths = type(state.customSoundPaths) == "table" and state.customSoundPaths or { state.customSoundPath or "", "", "", "", "" }
    local firstCustomPath = ""
    for i = 1, 5 do
        cfg.customSoundPaths[i] = aceOptions:NormalizeSoundPath(statePaths[i] or "")
        if firstCustomPath == "" and cfg.customSoundPaths[i] ~= "" then
            firstCustomPath = cfg.customSoundPaths[i]
        end
    end
    cfg.customSoundPath = aceOptions:NormalizeSoundPath(firstCustomPath ~= "" and firstCustomPath or soundFields.customSoundPath or state.customSoundPath or "")
    cfg.sharedMediaSound = tostring(soundFields.sharedMediaSound or state.sharedMediaSound or "")
    cfg.ttsText = tostring(state.ttsText or "")
    cfg.ttsRate = math.max(-10, math.min(10, tonumber(state.ttsRate) or 0))
    cfg.spellName = NS.L and NS.L("ENTRY_TYPE_BLOODLUST") or "Bloodlust"
    api.PlayBloodlustNotification(cfg)
end

function TestController:TestCurrent(aceOptions)
    local api = GetApi()
    local state = aceOptions and aceOptions.GetState and aceOptions:GetState() or {}
    if not api then
        return
    end

    local modeTts, modeSound = api.GetModes()
    local soundFields = aceOptions:ResolveSoundSourceFields(state, modeTts, modeSound)
    local notifyMode = soundFields.notifyMode
    local soundPath = aceOptions:NormalizeSoundPath(soundFields.soundPath or "")

    local cfg = BuildVisualFields(state)
    cfg.spellId = tonumber(state.spellId) or 0
    cfg.objectType = tostring(state.objectType or OBJECT_TYPE_SPELL)
    cfg.spellName = tostring(state.spellName or "")
    cfg.notifyMode = notifyMode
    cfg.ttsText = tostring(state.ttsText or "")
    cfg.ttsRate = math.max(-10, math.min(10, tonumber(state.ttsRate) or 0))
    cfg.soundPath = soundPath
    cfg.soundSource = tostring(soundFields.soundSource or state.soundSource or "")
    cfg.sharedMediaSound = tostring(soundFields.sharedMediaSound or state.sharedMediaSound or "")

    if tostring(state.entryType or "") == "bloodlust" and type(api.PlayBloodlustNotification) == "function" then
        api.PlayBloodlustNotification(cfg)
    elseif tostring(state.entryType or "") == "cast" then
        local triggerSpellID = tonumber(state.triggerSpellID or state.spellId) or tonumber(state.spellId) or 0
        if type(api.QueueCastSuccessNotification) == "function" then
            api.QueueCastSuccessNotification(triggerSpellID, cfg)
        elseif type(api.PlayCastSuccessNotification) == "function" then
            api.PlayCastSuccessNotification(cfg)
        end
    elseif type(api.PlayReadyNotification) == "function" then
        api.PlayReadyNotification(cfg)
    end
end
