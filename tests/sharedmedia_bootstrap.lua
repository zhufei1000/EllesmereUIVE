local loaded = { EllesmereUI = false, EllesmereUICooldownManager = false }
local sounds = {}
local eventHandler

C_AddOns = { IsAddOnLoaded = function(name) return loaded[name] == true end }
InCombatLockdown = function() return false end
UnitClass = function() return "Death Knight", "DEATHKNIGHT", 6 end
UnitRace = function() return "Human", "Human", 1 end
GetSpecialization = function() return 1 end
C_SpecializationInfo = { GetSpecializationInfo = function() return 252 end }
_ECME_GetCurrentSpecKey = function() return "252" end
CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function(_, _, callback) eventHandler = callback end,
    }
end
LibStub = {
    GetLibrary = function()
        return {
            Fetch = function(_, _, key) return sounds[key] end,
            Register = function(_, _, key, path) sounds[key] = path; return true end,
        }
    end,
}

EllesmereUIVEBootstrapNS = { SoundManifest = {} }
EllesmereUIVEDB = {
    settings = {},
    specConfigs = { [6] = { [0] = { [1] = {
        entryUID = "00000207", entryType = "euiVoice", objectType = "spell",
        spellId = 207167, euiTriggerType = "cdReady",
        alertClassIDs = { [6] = true }, alertSpecIDs = { [0] = true },
        soundSource = "sharedmedia", sharedMediaSound = "Test Sound",
        enabled = true, voiceEnabled = true,
    } } } },
}

assert(loadfile("!EllesmereUIVE_Bootstrap/Bootstrap.lua"))()
local entry = EllesmereUIVEDB.specConfigs[6][0][1]
assert(entry.soundKey == "Test Sound" and entry.bootstrapMediaMissing == true)

EllesmereUIDB = {
    activeProfile = "Default",
    spellAssignments = { profiles = { Default = { specProfiles = { ["252"] = {
        barSpells = { main = { assignedSpells = { 207167 } } },
    } } } } },
    profiles = { Default = { addons = { EllesmereUICooldownManager = {} } } },
}
loaded.EllesmereUI = true
eventHandler(nil, nil, "EllesmereUI")
local profile = EllesmereUIDB.spellAssignments.profiles.Default.specProfiles["252"]
assert(profile.spellSettingsCD[207167].cdReadySoundKey == "sm:Test Sound")
assert(EllesmereUIVEBootstrapAPI.IsSoundRegisteredBeforeEUI("Test Sound"))
assert(EllesmereUIVEBootstrapAPI.IsFamilyArmed("cd"))

sounds["Test Sound"] = "Interface\\AddOns\\SharedMedia_Test\\test.ogg"
local key, status = EllesmereUIVEBootstrapAPI.RegisterSavedEntry(entry)
assert(key == "Test Sound" and status == "sharedmedia_ready")
local toc = assert(io.open("!EllesmereUIVE_Bootstrap/!EllesmereUIVE_Bootstrap.toc", "r")):read("*a")
assert(toc:find("SharedMedia_Causese", 1, true) and toc:find("EllesmereUICooldownManager", 1, true))
print("SHAREDMEDIA_BOOTSTRAP_OK")
