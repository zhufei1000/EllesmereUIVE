local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.Core = NS.Core or {}
NS.Core.VoicePlayer = NS.Core.VoicePlayer or {}
local VoicePlayer = NS.Core.VoicePlayer

local function Trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

function VoicePlayer:NormalizePath(path)
    path = Trim(path):gsub("/", "\\")
    return path
end

function VoicePlayer:GetChannel(config)
    local db = rawget(_G, "EllesmereUIVEDB")
    local fallback = type(db) == "table" and type(db.settings) == "table" and db.settings.soundChannel or "Master"
    local channel = tostring(type(config) == "table" and config.soundChannel or fallback or "Master")
    if channel ~= "Master" and channel ~= "SFX" and channel ~= "Music" and channel ~= "Ambience" and channel ~= "Dialog" then
        channel = "Master"
    end
    return channel
end

function VoicePlayer:ResolveSharedMedia(name)
    name = Trim(name):gsub("^sm:", "")
    if name == "" then return "" end
    local libStub = rawget(_G, "LibStub")
    local lsm = type(libStub) == "table" and libStub:GetLibrary("LibSharedMedia-3.0", true) or nil
    if not lsm then return "" end
    local ok, path = pcall(lsm.Fetch, lsm, "sound", name, true)
    return ok and self:NormalizePath(path) or ""
end

function VoicePlayer:ResolvePath(config)
    config = type(config) == "table" and config or {}
    local source = tostring(config.soundSource or "custom")
    if source == "sharedmedia" or source == "sharedMedia" then
        return self:ResolveSharedMedia(config.sharedMediaSound or config.sharedMediaName)
    elseif source == "builtin" then
        return self:NormalizePath(config.builtinSoundPath or config.soundPath)
    end
    return self:NormalizePath(config.customSoundPath or config.soundPath or config.builtinSoundPath)
end

function VoicePlayer:PlaySoundPath(path, config)
    path = self:NormalizePath(path)
    if path == "" or type(PlaySoundFile) ~= "function" then return false end
    local ok, played = pcall(PlaySoundFile, path, self:GetChannel(config))
    if ok and played == true then return true end
    if NS.Print then NS:Print(NS.L("SOUND_FAILED", path)) end
    return false
end

function VoicePlayer:PlaySharedMediaSound(key, config)
    return self:PlaySoundPath(self:ResolveSharedMedia(key), config)
end

function VoicePlayer:GetVoiceID()
    if not (C_VoiceChat and C_VoiceChat.GetTtsVoices) then return nil end
    local ok, voices = pcall(C_VoiceChat.GetTtsVoices)
    if not ok or type(voices) ~= "table" then return nil end
    for _, voice in ipairs(voices) do
        local id = tonumber(type(voice) == "table" and (voice.voiceID or voice[1]))
        if id and id >= 0 then return id end
    end
    return nil
end

function VoicePlayer:SpeakTTS(text, rate)
    text = Trim(text)
    if text == "" then return false end
    rate = math.max(-10, math.min(10, tonumber(rate) or 0))
    local voiceID = self:GetVoiceID()
    if voiceID and C_VoiceChat and C_VoiceChat.SpeakText then
        local ok = pcall(C_VoiceChat.SpeakText, voiceID, text, rate, 100, false)
        if ok then return true end
    end
    local legacy = rawget(_G, "TextToSpeech_SpeakText")
    if type(legacy) == "function" and pcall(legacy, text) then return true end
    if NS.Print then NS:Print(NS.L("TTS_FAILED")) end
    return false
end

function VoicePlayer:PreviewSound(config)
    config = type(config) == "table" and config or {}
    if config.voiceEnabled == false or config.enabled == false then return false end
    local source = tostring(config.soundSource or "custom")
    if source == "tts" or tostring(config.notifyMode or "") == "tts" then
        return self:SpeakTTS(config.ttsText or config.spellName or "", config.ttsRate)
    elseif source == "sharedmedia" or source == "sharedMedia" then
        return self:PlaySharedMediaSound(config.sharedMediaSound or config.sharedMediaName, config)
    end
    return self:PlaySoundPath(self:ResolvePath(config), config)
end

function VoicePlayer:NotifyCastSuccess(config)
    return self:PreviewSound(config)
end

function VoicePlayer:NotifyBloodlust(config)
    config = type(config) == "table" and config or {}
    if config.voiceEnabled == false or config.enabled == false then return false end
    if tostring(config.soundSource or "custom") == "custom" and type(config.customSoundPaths) == "table" then
        local paths = {}
        for i = 1, 5 do
            local path = config.customSoundPaths[i]
            path = self:NormalizePath(path)
            if path ~= "" then paths[#paths + 1] = path end
        end
        if #paths > 0 then
            return self:PlaySoundPath(paths[math.random(1, #paths)], config)
        end
    end
    return self:PreviewSound(config)
end

VoicePlayer.Preview = VoicePlayer.PreviewSound
VoicePlayer.PlayCastSuccess = VoicePlayer.NotifyCastSuccess
VoicePlayer.PlayBloodlust = VoicePlayer.NotifyBloodlust
