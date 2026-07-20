local soundPath = "Interface\\AddOns\\SharedMedia_Test\\test.ogg"

LibStub = {
    GetLibrary = function(_, name)
        if name ~= "LibSharedMedia-3.0" then return nil end
        return {
            Fetch = function(_, mediaType, key) return mediaType == "sound" and key == "Test Sound" and soundPath or nil end,
        }
    end,
}
C_AddOns = { IsAddOnLoaded = function() return true end }
InCombatLockdown = function() return false end
GetSpecialization = function() return 1 end
C_SpecializationInfo = { GetSpecializationInfo = function() return 252 end }
_ECME_GetCurrentSpecKey = function() return "252" end

EllesmereUIVENS = {
    VERSION = "1.0.4",
    Core = {
        BootstrapBridge = {
            NormalizePath = function(_, path) return tostring(path or "") end,
            RegisterSavedEntry = function() return true, "sharedmedia_ready" end,
            IsSoundRegisteredBeforeEUI = function() return false end,
            IsCDMLoaded = function() return true end,
            IsFamilyArmed = function() return true end,
        },
        ScopeResolver = { EntryMatchesScope = function() return true end },
    },
    Constants = { DEFAULT_SOUND = "Interface\\test.ogg" },
    GetCurrentClassSpec = function() return 6, 252 end,
    GetCurrentRaceID = function() return 0 end,
}

local entry = {
    entryUID = "00000207", entryType = "euiVoice", objectType = "spell",
    spellId = 207167, spellName = "Blinding Sleet", euiTriggerType = "cdReady",
    alertClassIDs = { [6] = true }, alertSpecIDs = { [0] = true },
    soundSource = "sharedmedia", sharedMediaSound = "Test Sound",
    enabled = true, voiceEnabled = true,
    injectionStatus = "batch_complete",
    injectionStats = { reloadRequired = 1, waiting = 1 },
    requiresReload = true,
}
EllesmereUIVEDB = {
    entrySerial = 0,
    specConfigs = { [6] = { [0] = { [1] = entry } } },
    euiInjectionRecords = { Default = { ["252"] = { [207167] = { cdReady = {
        entryUID = entry.entryUID, family = "spellSettingsCD", field = "cdReadySoundKey",
        injectedValue = "sm:Test Sound", requiresReload = true,
    } } } } },
}
EllesmereUIDB = {
    activeProfile = "Default",
    spellAssignments = { profiles = { Default = { specProfiles = { ["252"] = {
        barSpells = { main = { assignedSpells = { 207167 } } },
        spellSettingsCD = { [207167] = { cdReadySoundKey = "sm:Test Sound" } },
    } } } } },
    profiles = { Default = { addons = { EllesmereUICooldownManager = {} } } },
}

assert(loadfile("EllesmereUIVE/Core/Database.lua"))()
EllesmereUIVENS.Core.Database:Initialize()
assert(entry.injectionStatus == nil and entry.injectionStats == nil)
print("RELOAD_STATUS_OK")

assert(loadfile("EllesmereUIVE/Core/EUISoundRegistry.lua"))()
assert(loadfile("EllesmereUIVE/Integrations/EllesmereUI.lua"))()
local status = EllesmereUIVENS.Integrations.EllesmereUI:GetInjectionStatus(entry)
assert(status == "native_ready", status)
assert(entry.requiresReload == false)
assert(EllesmereUIVEDB.euiInjectionRecords.Default["252"][207167].cdReady.requiresReload == false)
print("CURRENT_STATUS_RECALCULATED")
