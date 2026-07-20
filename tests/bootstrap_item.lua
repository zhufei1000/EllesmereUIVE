function InCombatLockdown() return false end
function GetSpecialization() return 1 end
function UnitClass() return "Mage", "MAGE", 8 end
function UnitRace() return "Human", "Human", 1 end
function _ECME_GetCurrentSpecKey() return "62" end
C_SpecializationInfo = { GetSpecializationInfo = function() return 62 end }
C_AddOns = {
    IsAddOnLoaded = function(name) return name == "EllesmereUI" or name == "EllesmereUICooldownManager" end,
}

local media = {
    Fetch = function() return nil end,
    Register = function() return true end,
}
LibStub = { GetLibrary = function() return media end }
CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function() end,
    }
end

EllesmereUIVEBootstrapNS = { SoundManifest = {} }
EllesmereUIVEDB = {
    settings = { overwriteEUI = false },
    euiInjectionRecords = {},
    specConfigs = { [8] = { [62] = { {
        entryUID = "boot-item", entryType = "euiVoice", objectType = "item",
        spellId = 245898, itemID = 245898, resolvedSpellID = 99999,
        euiTriggerType = "cdReady", soundSource = "custom", soundPath = "Sound\\Item.ogg",
        enabled = true, voiceEnabled = true,
    } } } },
}
EllesmereUIDB = {
    activeProfile = "Default",
    spellAssignments = { profiles = { Default = { specProfiles = {
        ["62"] = { barSpells = { primary = { barType = "cooldowns", assignedSpells = { -241308 } } } },
    } } } },
    profiles = { Default = { addons = { EllesmereUICooldownManager = { customActiveStates = {} } } } },
}

assert(loadfile("!EllesmereUIVE_Bootstrap/Bootstrap.lua"))()
local states = EllesmereUIDB.profiles.Default.addons.EllesmereUICooldownManager.customActiveStates
assert(states[-241308].cdReadySoundKey ~= nil)
assert(states[-245898] == nil)
assert(states[99999] == nil)
local record = EllesmereUIVEDB.euiInjectionRecords.Default["62"][245898].cdReady
assert(record.objectType == "item" and record.itemID == 245898 and record.euiItemID == 241308)
assert(record.lookupID == -241308 and record.lookupType == "itemID" and record.spellID == nil)
assert(record.itemMatchType == "preset_group")

local missing = {
    entryUID = "boot-missing", entryType = "euiVoice", objectType = "item",
    spellId = 900001, itemID = 900001, euiTriggerType = "cdReady",
    soundSource = "custom", soundPath = "Sound\\Missing.ogg", enabled = true, voiceEnabled = true,
}
local ok, status = EllesmereUIVEBootstrapAPI.PreseedEntryForSpec(missing, 8, 62)
assert(ok == false and status == "waiting_for_item_target")
assert(states[-900001] == nil)

print("BOOTSTRAP_ITEM_OK")
