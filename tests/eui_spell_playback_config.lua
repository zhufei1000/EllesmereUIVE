local assigned = {}
LibStub = {
    GetLibrary = function()
        return { Fetch = function(_, _, key) return key == "Test Sound" and "Interface\\test.ogg" or nil end }
    end,
}
C_AddOns = { IsAddOnLoaded = function() return true end }
InCombatLockdown = function() return false end
_ECME_GetCurrentSpecKey = function() return "252" end
GetSpecialization = function() return 1 end
C_SpecializationInfo = { GetSpecializationInfo = function() return 252 end }

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
    GetCurrentClassSpec = function() return 6, 252 end,
    GetCurrentRaceID = function() return 0 end,
}
EllesmereUIVEDB = { settings = {}, euiInjectionRecords = {} }
EllesmereUIDB = {
    activeProfile = "Default",
    spellAssignments = { profiles = { Default = { specProfiles = { ["252"] = {
        barSpells = { main = { assignedSpells = assigned } },
    } } } } },
    profiles = { Default = { addons = { EllesmereUICooldownManager = {} } } },
}
local entry = {
    entryUID = "00000207", entryType = "euiVoice", objectType = "spell",
    spellId = 207167, euiTriggerType = "cdReady", soundSource = "sharedmedia",
    sharedMediaSound = "Test Sound", enabled = true, voiceEnabled = true,
    alertClassIDs = { [6] = true }, alertSpecIDs = { [0] = true },
}

assert(loadfile("EllesmereUIVE/Core/EUISoundRegistry.lua"))()
assert(loadfile("EllesmereUIVE/Integrations/EllesmereUI.lua"))()
local integration = EllesmereUIVENS.Integrations.EllesmereUI
local ok, status = integration:InjectEntryToSpec(entry, 6, 252, false, true)
assert(ok and status == "waiting_for_skill", status)
assert(integration:GetInjectionStatus(entry) == "waiting_for_skill")

assigned[1] = 207167
ok, status = integration:InjectEntryToSpec(entry, 6, 252, false, true)
assert(ok and status == "native_ready", status)
assert(integration:GetInjectionStatus(entry) == "native_ready")
local settings = EllesmereUIDB.spellAssignments.profiles.Default.specProfiles["252"].spellSettingsCD
assert(settings[207167].cdReadySoundKey == "sm:Test Sound")
print("EUI_207167_TARGET_OK")
