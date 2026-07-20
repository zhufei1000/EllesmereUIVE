local refreshCount = 0
function InCombatLockdown() return false end
function GetSpecialization() return 1 end
function _ECME_GetCurrentSpecKey() return "62" end
function _ECME_Apply() refreshCount = refreshCount + 1 end
C_SpecializationInfo = { GetSpecializationInfo = function() return 62 end }
C_AddOns = {
    IsAddOnLoaded = function(name) return name == "EllesmereUI" or name == "EllesmereUICooldownManager" end,
    LoadAddOn = function() return true end,
}

local function SpecProfile(spells)
    return { barSpells = { primary = { assignedSpells = spells or {}, barType = "cooldowns" } } }
end

EllesmereUIDB = {
    activeProfile = "Default",
    spellAssignments = { profiles = { Default = { specProfiles = {
        ["62"] = SpecProfile({ 12345, 22222, 33333 }),
        ["63"] = SpecProfile({ 12345, 22222, 33333 }),
    } } } },
    profiles = { Default = { addons = { EllesmereUICooldownManager = { customActiveStates = {} } } } },
}
EllesmereUIVEDB = { settings = { overwriteEUI = false }, euiInjectionRecords = {} }
EllesmereUIVENS = {
    VERSION = "1.0.3",
    Core = { EUISoundRegistry = {
        RegisterEntry = function(_, entry) return "sm:EUIVE_" .. tostring(entry.entryUID), "native_ready", false end,
        GetNativeReadiness = function() return "native_ready" end,
        ResolveSoundPath = function(_, entry) return entry.soundPath end,
        BuildStableSoundKey = function(_, entry) return "EUIVE_" .. tostring(entry.entryUID) end,
    } },
    Integrations = {},
}
local NS = EllesmereUIVENS
function NS:GetCurrentClassSpec() return 8, 62 end
function NS:RequestEUISync() return true end
assert(loadfile("EllesmereUIVE/Integrations/EllesmereUI.lua"))()
local integration = NS.Integrations.EllesmereUI

local targets = { { classID = 8, specID = 62 }, { classID = 8, specID = 63 } }
local entry = {
    entryUID = "voice1", entryType = "euiVoice", spellId = 12345, euiTriggerType = "cdReady",
    euiTargetMode = "auto", euiTargetFamily = "auto", soundSource = "builtin", soundPath = "AirHorn.ogg",
    enabled = true, voiceEnabled = true,
}
local _, status, stats = integration:InjectEntryToTargets(entry, targets, false)
assert(status == "batch_complete" and stats.targetCount == 2 and stats.injected == 2)
assert(refreshCount == 1)
assert(EllesmereUIDB.spellAssignments.profiles.Default.specProfiles["62"].spellSettingsCD[12345].cdReadySoundKey == "sm:EUIVE_voice1")
assert(EllesmereUIDB.spellAssignments.profiles.Default.specProfiles["63"].spellSettingsCD[12345].cdReadySoundKey == "sm:EUIVE_voice1")
assert(EllesmereUIVEDB.euiInjectionRecords.Default["62"][12345].cdReady.entryUID == "voice1")
assert(EllesmereUIVEDB.euiInjectionRecords.Default["63"][12345].cdReady.entryUID == "voice1")

local conflictEntry = {
    entryUID = "voice2", entryType = "euiVoice", spellId = 22222, euiTriggerType = "cdReady",
    soundSource = "builtin", soundPath = "Bell.ogg", enabled = true, voiceEnabled = true,
}
EllesmereUIDB.spellAssignments.profiles.Default.specProfiles["63"].spellSettingsCD[22222] = { cdReadySoundKey = "sm:UserSound" }
local _, _, conflictStats = integration:InjectEntryToTargets(conflictEntry, targets, false)
assert(conflictStats.injected == 1 and conflictStats.conflict == 1)
assert(EllesmereUIDB.spellAssignments.profiles.Default.specProfiles["63"].spellSettingsCD[22222].cdReadySoundKey == "sm:UserSound")

local beforeNonCurrent = refreshCount
local nonCurrent = {
    entryUID = "voice3", entryType = "euiVoice", spellId = 33333, euiTriggerType = "cdReady",
    soundSource = "builtin", soundPath = "Bell.ogg", enabled = true, voiceEnabled = true,
}
integration:InjectEntryToTargets(nonCurrent, { { classID = 8, specID = 63 } }, false)
assert(refreshCount == beforeNonCurrent)

EllesmereUIDB.spellAssignments.profiles.Default.specProfiles["63"].spellSettingsCD[12345].cdReadySoundKey = "sm:ManuallyChanged"
local removed, removeStatus = integration:RemoveEntryFromAllRecordedScopes(entry, true)
assert(removed and removeStatus == "removed")
assert(EllesmereUIDB.spellAssignments.profiles.Default.specProfiles["62"].spellSettingsCD[12345].cdReadySoundKey == nil)
assert(EllesmereUIDB.spellAssignments.profiles.Default.specProfiles["63"].spellSettingsCD[12345].cdReadySoundKey == "sm:ManuallyChanged")

local customStates = EllesmereUIDB.profiles.Default.addons.EllesmereUICooldownManager.customActiveStates
customStates[44444] = {}
local customEntry = {
    entryUID = "voice4", entryType = "euiVoice", spellId = 44444, euiTriggerType = "cdReady",
    euiTargetMode = "forced", euiTargetFamily = "custom", soundSource = "builtin", soundPath = "Bell.ogg",
    enabled = true, voiceEnabled = true,
}
local beforeCustom = refreshCount
integration:InjectEntryToTargets(customEntry, targets, false)
assert(customStates[44444].cdReadySoundKey == "sm:EUIVE_voice4" and refreshCount == beforeCustom + 1)
local customRecordCount = 0
for _, specs in pairs(EllesmereUIVEDB.euiInjectionRecords) do
    for _, spells in pairs(specs) do
        if spells[44444] and spells[44444].cdReady then customRecordCount = customRecordCount + 1 end
    end
end
assert(customRecordCount == 1)

print("EUI_MULTI_SPEC_OK")
