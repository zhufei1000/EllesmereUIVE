local currentClassID, currentSpecID = 8, 62
function UnitClass() return "Player", "PLAYER", currentClassID end
function UnitRace() return "Human", "Human", 1 end
function GetSpecialization() return 1 end
C_SpecializationInfo = { GetSpecializationInfo = function() return currentSpecID end }
function GetNumClasses() return 2 end
function GetClassInfo(index) return index == 1 and "Death Knight" or "Mage", "CLASS", index == 1 and 6 or 8 end
function GetNumSpecializationsForClassID(classID) return classID == 6 and 3 or 3 end
function GetSpecializationInfoForClassID(classID, index)
    local values = classID == 6 and { 250, 251, 252 } or { 62, 63, 64 }
    return values[index]
end
function wipe(value) for key in pairs(value) do value[key] = nil end end
function InCombatLockdown() return false end
function hooksecurefunc() end
function CreateFrame()
    return { RegisterEvent = function() end, SetScript = function() end }
end
C_Timer = { After = function(_, callback) callback() end }
C_AddOns = { LoadAddOn = function() return false end }
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
SlashCmdList = {}
UISpecialFrames = {}

local played = 0
EllesmereUIVENS = { Core = {}, Integrations = { EllesmereUI = {} } }
local NS = EllesmereUIVENS
NS.L = function(key) return key end
NS.Core.Database = {
    NormalizeEUITarget = function() end, NextEntryUID = function() return "new" end,
    DeepCopy = function(value) return value end, Initialize = function() end,
}
NS.Core.EUISoundRegistry = { BuildStableSoundKey = function() return "key" end, RegisterAllSavedEntries = function() return 0, 0 end }
NS.Core.VoicePlayer = { PlayCastSuccess = function() played = played + 1 end }
NS.Core.CastSuccessSchedulerBridge = {
    Queue = function(_, _, config, callback) callback(config); return true end,
    ClearAll = function() end,
}
NS.Core.Bloodlust = { HandleUnitAura = function() end }
NS.Core.MinimapButton = { Initialize = function() end }
NS.Core.ConfigPanel = { Initialize = function() end }
NS.Integrations.EllesmereUI.GetCurrentProfileKey = function() return "Default" end
NS.Integrations.EllesmereUI.GetCurrentSpecKey = function() return tostring(currentSpecID) end
NS.Integrations.EllesmereUI.RemoveEntryFromAllRecordedScopes = function() return true, "removed", false end
NS.Integrations.EllesmereUI.SyncCurrentSpec = function() return {}, "complete", {} end
NS.Integrations.EllesmereUI.Refresh = function() end

local dkEntry = {
    entryUID = "dk", entryType = "cast", spellId = 100, triggerSpellID = 100, voiceEnabled = true,
    alertClassIDs = { [6] = true }, alertSpecIDs = { [0] = true }, alertRaceIDs = { [0] = true },
}
local mageEntry = {
    entryUID = "mage", entryType = "cast", spellId = 200, triggerSpellID = 200, voiceEnabled = true,
    alertClassIDs = { [8] = true }, alertSpecIDs = { [62] = true }, alertRaceIDs = { [0] = true },
}
local duplicateDK = {}
for key, value in pairs(dkEntry) do duplicateDK[key] = value end
EllesmereUIVEDB = {
    specConfigs = { [0] = { [0] = { dkEntry, mageEntry } }, [6] = { [0] = { duplicateDK } } },
    settings = { autoInjectOnSave = true, overwriteEUI = false, showLoadMessage = false },
    collectionData = {}, savedListOrder = {}, euiInjectionRecords = {}, bloodlust = {},
}

assert(loadfile("EllesmereUIVE/Core/ScopeResolver.lua"))()
assert(loadfile("EllesmereUIVE/Core/CastSuccess.lua"))()
assert(loadfile("EllesmereUIVE/EllesmereUIVE.lua"))()

local mageCurrent = NS:GetCurrentEntries("cast")
assert(#mageCurrent == 1 and mageCurrent[1].entryUID == "mage")
NS.Core.CastSuccess:Rebuild()
assert(not NS.Core.CastSuccess:HandleSpellcast(100))
assert(NS.Core.CastSuccess:HandleSpellcast(200) and played == 1)

currentClassID, currentSpecID = 6, 251
local dkCurrent = NS:GetCurrentEntries("cast")
assert(#dkCurrent == 1 and dkCurrent[1].entryUID == "dk")
NS.Core.CastSuccess:Rebuild()
assert(NS.Core.CastSuccess:HandleSpellcast(100) and played == 2)

print("SCOPE_RUNTIME_OK")
