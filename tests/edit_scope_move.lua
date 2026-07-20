EllesmereUIVENS = {
    Constants = {
        ALL_CLASSES_ID = 0, ALL_SPECS_ID = 0, ALL_RACES_ID = 0,
        OBJECT_TYPE_SPELL = "spell", OBJECT_TYPE_ITEM = "item",
        ITEM_LOAD_NONE = "none", ITEM_LOAD_EQUIPPED = "equipped", ITEM_LOAD_BAGS = "bags",
    },
    Utils = {}, Core = {}, Integrations = {}, UI = {},
    L = function(key) return key end,
}
local NS = EllesmereUIVENS
local serial = 207
local function deepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}; if seen[value] then return seen[value] end
    local result = {}; seen[value] = result
    for key, child in pairs(value) do result[deepCopy(key, seen)] = deepCopy(child, seen) end
    return result
end
NS.Core.Database = {
    DeepCopy = deepCopy,
    NextEntryUID = function() serial = serial + 1; return string.format("%08d", serial) end,
    NormalizeEUITarget = function(_, entry) entry.euiTargetMode, entry.euiTargetFamily = "auto", "auto" end,
}
NS.Core.EUISoundRegistry = { RegisterEntry = function() return "sm:Test Sound", "sharedmedia_ready", false, true end }
local removedUID
NS.Integrations.EllesmereUI = {
    RemoveEntryFromAllRecordedScopes = function(_, entry) removedUID = entry.entryUID; return true, "removed", true end,
    Refresh = function() end,
    GetInjectionStatus = function() return "saved_waiting_sync" end,
}
NS.SnapshotEntry = function(entry) return deepCopy(entry) end
NS.EUIDefinitionChanged = function(_, _, oldClass, oldSpec, newClass, newSpec)
    return oldClass ~= newClass or oldSpec ~= newSpec
end
NS.SavedListLayout = { InvalidateCache = function() end }

EllesmereUIVEDB = { specConfigs = {}, collectionData = {}, savedListOrder = { loaded = {}, unloaded = {} } }
local function scopeMap(classID, specID, create)
    if create then
        EllesmereUIVEDB.specConfigs[classID] = EllesmereUIVEDB.specConfigs[classID] or {}
        EllesmereUIVEDB.specConfigs[classID][specID] = EllesmereUIVEDB.specConfigs[classID][specID] or {}
    end
    return EllesmereUIVEDB.specConfigs[classID] and EllesmereUIVEDB.specConfigs[classID][specID] or {}
end
NS.API = {
    GetModes = function() return "tts", "sound" end,
    ResolveObjectType = function(_, value) return value or "spell" end,
    GetStoredEntryMap = function(classID, specID) return scopeMap(classID, specID, false) end,
    EnsureEntryMap = function(classID, specID) return scopeMap(classID, specID, true) end,
    FindFirstFreeIndex = function(map) for i = 1, 100 do if map[i] == nil then return i end end end,
    GetOrderedEntryIndices = function(map) local out = {}; for i in pairs(map) do if tonumber(i) then out[#out + 1] = tonumber(i) end end; table.sort(out); return out end,
    GetEntry = function(map, index) return map and map[index] end,
    ClearEntryDeletedMarker = function() end,
    RebuildRuntimeConfig = function() end, RebuildCastSuccessConfig = function() end,
    RebuildCustomConfig = function() end, RefreshRuntimeCooldowns = function() end,
    ResolveObjectName = function(id) return tostring(id) end, ResolveObjectIcon = function() return nil end,
    ResolveClassName = function(id) return tostring(id) end, ResolveSpecName = function(_, id) return tostring(id) end,
    GetCurrentClassSpec = function() return 6, 252 end, RefreshPanel = function() end,
}

local state = {
    selectedKey = "6:0:1", editingEntryUID = "00000207",
    classID = 6, specID = 252, alertClassIDs = { [6] = true }, alertSpecIDs = { [252] = true }, alertRaceIDs = { [0] = true },
    entryType = "euiVoice", objectType = "spell", spellId = 207167, spellName = "Blinding Sleet", euiTriggerType = "cdReady",
    notifyMode = "sound", soundSource = "builtin", soundPath = "Interface\\test.ogg", builtinSoundPath = "Interface\\test.ogg",
    voiceEnabled = true, imageEnabled = false, textEnabled = false, injectOnSave = false,
}
NS.AceOptions = {
    GetState = function() return state end,
    ResolveSoundSourceFields = function(_, source) return source end,
    NormalizeSoundPath = function(_, path) return path end,
}

assert(loadfile("EllesmereUIVE_Config/Core/CollectionStore.lua"))()
assert(loadfile("EllesmereUIVE_Config/Core/EntryStore.lua"))()

local oldEntry = deepCopy(state)
oldEntry.selectedKey, oldEntry.editingEntryUID, oldEntry.classID, oldEntry.specID = nil, nil, 6, 0
oldEntry.entryUID, oldEntry.alertSpecIDs = "00000207", { [0] = true }
scopeMap(6, 0, true)[1] = oldEntry
local scope = NS.CollectionStore.EnsureCollectionScope(6, 0)
scope.groups.dk = { name = "DK", entries = { "6:0:1" } }
scope.root = { { type = "group", id = "dk" } }
local targetScope = NS.CollectionStore.EnsureCollectionScope(6, 252)
targetScope.groups.unholy = { name = "Unholy", entries = { "6:0:1" } }
targetScope.root = { { type = "group", id = "unholy" } }
EllesmereUIVEDB.savedListOrder.loaded = { "6:0:1" }

local conflict = deepCopy(oldEntry)
conflict.entryUID, conflict.classID, conflict.specID, conflict.alertSpecIDs = "00000999", 6, 252, { [252] = true }
scopeMap(6, 252, true)[1] = conflict
local failed, failureReason = NS.EntryStore:SaveEntry(NS.AceOptions)
assert(not failed and failureReason == "duplicate")
assert(scopeMap(6, 0, false)[1] == oldEntry and scope.groups.dk.entries[1] == "6:0:1" and removedUID == nil)
scopeMap(6, 252, false)[1] = nil

local ok, result = NS.EntryStore:SaveEntry(NS.AceOptions)
assert(ok and (result == "saved" or result == "saved_and_injected"), result)
assert(scopeMap(6, 0, false)[1] == nil)
local moved = scopeMap(6, 252, false)[1]
assert(moved and moved.entryUID == "00000207" and moved.alertSpecIDs[252] == true)
assert(removedUID == "00000207")
print("EDIT_SCOPE_MOVE_OK")

local selfCopy = deepCopy(moved)
scopeMap(6, 252, false)[2] = selfCopy
state.selectedKey, state.editingEntryUID, state.spellName = "6:252:1", "00000207", "Blinding Sleet edited"
ok, result = NS.EntryStore:SaveEntry(NS.AceOptions)
assert(ok and scopeMap(6, 252, false)[1].spellName == "Blinding Sleet edited")
scopeMap(6, 252, false)[2] = nil
print("SELF_DUPLICATE_EXCLUDED")
assert(#scope.groups.dk.entries == 0)
print("OLD_SCOPE_CLEANUP_OK")
assert(scope.groups.dk and targetScope.groups.unholy.entries[1] == "6:252:1")
assert(EllesmereUIVEDB.savedListOrder.loaded[1] == "6:252:1")
print("COLLECTION_SCOPE_OK")
