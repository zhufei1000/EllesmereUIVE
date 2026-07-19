local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.Core = NS.Core or {}
NS.Core.CastSuccess = NS.Core.CastSuccess or {}
local CastSuccess = NS.Core.CastSuccess

local byTrigger = {}
local recent = {}

function CastSuccess:Rebuild()
    wipe(byTrigger)
    local entries = type(NS.GetCurrentEntries) == "function" and NS:GetCurrentEntries("cast") or {}
    for _, entry in ipairs(entries) do
        if type(entry) == "table" and entry.entryType == "cast" and entry.voiceEnabled ~= false then
            local trigger = tonumber(entry.triggerSpellID) or tonumber(entry.spellId)
            if trigger and trigger > 0 then
                byTrigger[trigger] = byTrigger[trigger] or {}
                byTrigger[trigger][#byTrigger[trigger] + 1] = {
                    entryUID = entry.entryUID,
                    spellId = tonumber(entry.spellId),
                    triggerSpellID = trigger,
                    spellName = tostring(entry.spellName or ""),
                    soundSource = tostring(entry.soundSource or "custom"),
                    soundPath = tostring(entry.soundPath or ""),
                    builtinSoundPath = tostring(entry.builtinSoundPath or ""),
                    customSoundPath = tostring(entry.customSoundPath or ""),
                    sharedMediaSound = tostring(entry.sharedMediaSound or ""),
                    notifyMode = tostring(entry.notifyMode or "sound"),
                    ttsText = tostring(entry.ttsText or ""),
                    ttsRate = tonumber(entry.ttsRate) or 0,
                    voiceEnabled = true,
                    delayEnabled = entry.delayEnabled == true,
                    delaySeconds = math.max(0, tonumber(entry.delaySeconds) or 0),
                }
            end
        end
    end
    return true
end

function CastSuccess:HandleSpellcast(spellID)
    spellID = tonumber(spellID)
    local list = spellID and byTrigger[spellID]
    if not list then return false end

    local now = GetTime and GetTime() or 0
    if recent[spellID] and now - recent[spellID] < 0.05 then return false end
    recent[spellID] = now

    local player = NS.Core and NS.Core.VoicePlayer
    local scheduler = NS.Core and NS.Core.CastSuccessSchedulerBridge
    if not player or not scheduler then return false end
    local queued = false
    for _, entry in ipairs(list) do
        if scheduler:Queue(spellID, entry, function(cfg)
            player:PlayCastSuccess(cfg)
        end) then queued = true end
    end
    return queued
end

function CastSuccess:Reset()
    wipe(recent)
    if NS.Core and NS.Core.CastSuccessSchedulerBridge then NS.Core.CastSuccessSchedulerBridge:ClearAll() end
end
