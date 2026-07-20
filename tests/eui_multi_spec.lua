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
        ["62"] = SpecProfile({ 12345, 22222, 33333, -212454, -241308 }),
        ["63"] = SpecProfile({ 12345, 22222, 33333, -212454, -241308 }),
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

local itemEntry = {
    entryUID = "item1", entryType = "euiVoice", objectType = "item",
    spellId = 212454, itemID = 212454, resolvedSpellID = 99999,
    euiTriggerType = "cdReady", soundSource = "builtin", soundPath = "Bell.ogg",
    enabled = true, voiceEnabled = true,
}
local beforeItem = refreshCount
local _, _, itemStats = integration:InjectEntryToTargets(itemEntry, targets, false)
assert(itemStats.injected == 1 and itemStats.upToDate == 1)
assert(customStates[-212454].cdReadySoundKey == "sm:EUIVE_item1")
assert(customStates[99999] == nil)
local itemRecord = EllesmereUIVEDB.euiInjectionRecords.Default["62"][212454].cdReady
assert(itemRecord.objectType == "item")
assert(itemRecord.itemID == 212454 and itemRecord.lookupID == -212454 and itemRecord.lookupType == "itemID")
assert(itemRecord.spellID == nil and refreshCount == beforeItem + 1)
assert(integration:GetInjectionStatus(itemEntry) == "item_id_injected")
local itemIdentifier = integration:ResolveManagedIdentifier(itemEntry, 62)
assert(itemIdentifier.itemID == 212454 and itemIdentifier.lookupID == -212454 and itemIdentifier.lookupType == "itemID")

local missingItem = {
    entryUID = "item2", entryType = "euiVoice", objectType = "item",
    spellId = 999001, itemID = 999001, resolvedSpellID = 12345,
    euiTriggerType = "cdReady", soundSource = "builtin", soundPath = "Bell.ogg",
    enabled = true, voiceEnabled = true,
}
local _, _, missingStats = integration:InjectEntryToTargets(missingItem, targets, false)
assert(missingStats.waiting == 2)
assert(customStates[-999001] == nil and customStates[12345] == nil)

local itemRemoved, itemRemoveStatus = integration:RemoveEntryFromAllRecordedScopes(itemEntry, true)
assert(itemRemoved and itemRemoveStatus == "removed")
assert(customStates[-212454].cdReadySoundKey == nil)

-- EUI stores only the preset's primary itemID but monitors every altItemID.
local qualityItem = {
    entryUID = "item-quality", entryType = "euiVoice", objectType = "item",
    spellId = 245898, itemID = 245898, euiTriggerType = "cdReady",
    soundSource = "builtin", soundPath = "Bell.ogg", enabled = true, voiceEnabled = true,
}
local _, _, qualityStats = integration:InjectEntryToTargets(qualityItem, targets, false)
assert(qualityStats.injected == 1 and qualityStats.upToDate == 1)
assert(customStates[-241308].cdReadySoundKey == "sm:EUIVE_item-quality")
assert(customStates[-245898] == nil)
local qualityRecord = EllesmereUIVEDB.euiInjectionRecords.Default["62"][245898].cdReady
assert(qualityRecord.itemID == 245898 and qualityRecord.euiItemID == 241308)
assert(qualityRecord.lookupID == -241308 and qualityRecord.itemMatchType == "preset_group")
local qualityIdentifier = integration:ResolveManagedIdentifier(qualityItem, 62)
assert(qualityIdentifier.itemID == 245898 and qualityIdentifier.euiItemID == 241308)
assert(qualityIdentifier.lookupID == -241308 and qualityIdentifier.itemMatchType == "preset_group")

print("EUI_MULTI_SPEC_OK")
