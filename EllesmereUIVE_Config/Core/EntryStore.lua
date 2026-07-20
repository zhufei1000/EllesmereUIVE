local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

local EntryStore = NS.EntryStore or {}
NS.EntryStore = EntryStore

local L = NS.L or function(key, ...)
    if select("#", ...) > 0 then
        return string.format(tostring(key), ...)
    end
    return tostring(key)
end

local CONST = NS.Constants or {}
local Utils = NS.Utils or {}
local CollectionStore = NS.CollectionStore or {}

local ALL_CLASSES_ID = CONST.ALL_CLASSES_ID or 0
local ALL_SPECS_ID = CONST.ALL_SPECS_ID or 0
local ALL_RACES_ID = CONST.ALL_RACES_ID or 0
local OBJECT_TYPE_SPELL = CONST.OBJECT_TYPE_SPELL or "spell"
local OBJECT_TYPE_ITEM = CONST.OBJECT_TYPE_ITEM or "item"
local ITEM_LOAD_NONE = CONST.ITEM_LOAD_NONE or "none"
local ITEM_LOAD_EQUIPPED = CONST.ITEM_LOAD_EQUIPPED or "equipped"
local ITEM_LOAD_BAGS = CONST.ITEM_LOAD_BAGS or "bags"

local function GetOptions(owner)
    return owner or NS.AceOptions or {}
end

local function GetApi()
    return NS.API
end


local function NormalizeConditionOp(value)
    value = tostring(value or "<=")
    if value == "<" or value == "<=" or value == ">" or value == ">=" or value == "==" or value == "~=" then
        return value
    end
    if value == "=" then
        return "=="
    end
    return "<="
end

local function NormalizeConditionTime(value, fallback)
    local numeric = tonumber(value)
    if numeric == nil then
        numeric = tonumber(fallback) or 0
    end
    return math.max(0, numeric or 0)
end

local function NormalizeCastDelayMode(value)
    return "show"
end

local function NormalizeItemLoadMode(value)
    value = tostring(value or ITEM_LOAD_NONE):lower()
    if value == ITEM_LOAD_EQUIPPED or value == ITEM_LOAD_BAGS then
        return value
    end
    return ITEM_LOAD_NONE
end

local function ItemLoadModesOverlap(left, right)
    left = NormalizeItemLoadMode(left)
    right = NormalizeItemLoadMode(right)
    return left == ITEM_LOAD_NONE or right == ITEM_LOAD_NONE or left == right
end

local function TrimText(value)
    if Utils.TrimText then
        return Utils.TrimText(value)
    end
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function NormalizeSoundPath(value)
    if NS.AceOptions and type(NS.AceOptions.NormalizeSoundPath) == "function" then
        return NS.AceOptions:NormalizeSoundPath(value or "")
    end
    return TrimText(value or "")
end

local function CopyCustomSoundPaths(source, fallbackPath, preferFallback)
    local copy = { "", "", "", "", "" }
    if type(source) == "table" then
        for i = 1, 5 do
            copy[i] = NormalizeSoundPath(source[i] or "")
        end
    end
    local fallback = NormalizeSoundPath(fallbackPath or "")
    if fallback ~= "" and (preferFallback == true or TrimText(copy[1] or "") == "") then
        copy[1] = fallback
    end
    return copy
end

local function FirstCustomSoundPath(paths)
    if type(paths) ~= "table" then
        return ""
    end
    for i = 1, 5 do
        local path = NormalizeSoundPath(paths[i] or "")
        if path ~= "" then
            return path
        end
    end
    return ""
end

local function HasCustomSoundPath(paths)
    return FirstCustomSoundPath(paths) ~= ""
end

local function CopyBooleanMap(source)
    local copy = {}
    if type(source) == "table" then
        for key, value in pairs(source) do
            if value == true and type(key) == "string" and key ~= "" then
                copy[key] = true
            end
        end
    end
    return copy
end

local function CopyNumberBoolMap(source)
    local copy = {}
    if type(source) == "table" then
        for key, value in pairs(source) do
            local numberKey = tonumber(key)
            if value == true and numberKey and numberKey >= 0 then
                copy[numberKey] = true
            end
        end
    end
    return copy
end

local function NormalizeCustomClassMap(source, fallbackClassID)
    local copy = CopyNumberBoolMap(source)
    if next(copy) == nil then
        local classID = tonumber(fallbackClassID) or 0
        copy[classID > 0 and classID or ALL_CLASSES_ID] = true
    end
    if copy[ALL_CLASSES_ID] == true then
        return { [ALL_CLASSES_ID] = true }
    end
    return copy
end

local function NormalizeCustomSpecMap(source, fallbackSpecID)
    local copy = CopyNumberBoolMap(source)
    if next(copy) == nil then
        local specID = tonumber(fallbackSpecID) or 0
        copy[specID > 0 and specID or ALL_SPECS_ID] = true
    end
    if copy[ALL_SPECS_ID] == true then
        return { [ALL_SPECS_ID] = true }
    end
    return copy
end

local function NormalizeCustomRaceMap(source)
    local copy = CopyNumberBoolMap(source)
    if next(copy) == nil or copy[ALL_RACES_ID] == true then
        return { [ALL_RACES_ID] = true }
    end
    return copy
end


local function BoolMapsOverlap(left, right, allID)
    if type(left) ~= "table" or type(right) ~= "table" then
        return true
    end
    if left[allID] == true or right[allID] == true then
        return true
    end
    for key, enabled in pairs(left) do
        if enabled == true and right[key] == true then
            return true
        end
    end
    return false
end

local function EntryAlertScopeOverlaps(entry, scopeClassID, scopeSpecID, raceMap, classMap, specMap)
    if type(entry) ~= "table" then
        return true
    end
    local entryRaces = NormalizeCustomRaceMap(entry.alertRaceIDs)
    local entryClasses = NormalizeCustomClassMap(entry.alertClassIDs or entry.customClassIDs, scopeClassID)
    local entrySpecs = NormalizeCustomSpecMap(entry.alertSpecIDs or entry.customSpecIDs, scopeSpecID)
    return BoolMapsOverlap(entryRaces, raceMap, ALL_RACES_ID)
        and BoolMapsOverlap(entryClasses, classMap, ALL_CLASSES_ID)
        and BoolMapsOverlap(entrySpecs, specMap, ALL_SPECS_ID)
end

local function BoolMapMatchesCurrent(map, currentID, allID)
    if type(map) ~= "table" or next(map) == nil then
        return true
    end
    if map[allID or 0] == true then
        return true
    end
    currentID = tonumber(currentID) or 0
    return currentID > 0 and map[currentID] == true
end

local function GetCurrentRaceID()
    if type(UnitRace) ~= "function" then
        return 0
    end
    local _, _, raceID = UnitRace("player")
    return tonumber(raceID) or 0
end

local function EntryAlertScopeMatchesCurrent(entry, scopeClassID, scopeSpecID, currentClassID, currentSpecID)
    if type(entry) ~= "table" then
        return false
    end
    local entryRaces = NormalizeCustomRaceMap(entry.alertRaceIDs)
    local entryClasses = NormalizeCustomClassMap(entry.alertClassIDs or entry.customClassIDs, scopeClassID)
    local entrySpecs = NormalizeCustomSpecMap(entry.alertSpecIDs or entry.customSpecIDs, scopeSpecID)
    return BoolMapMatchesCurrent(entryRaces, GetCurrentRaceID(), ALL_RACES_ID)
        and BoolMapMatchesCurrent(entryClasses, currentClassID, ALL_CLASSES_ID)
        and BoolMapMatchesCurrent(entrySpecs, currentSpecID, ALL_SPECS_ID)
end

local function NormalizeCustomInterval(value)
    local n = tonumber(value) or 0.5
    if n < 0.2 then n = 0.2 end
    if n > 60 then n = 60 end
    return tonumber(string.format("%.2f", n)) or 0.5
end

local function NormalizeCustomConditionLogic(value)
    value = tostring(value or "or"):lower()
    if value == "and" or value == "all" then
        return "and"
    end
    return "or"
end

local MAX_CUSTOM_NOTIFY_COUNT = 8

local function CopyActionMap(source)
    local copy = {}
    if type(source) == "table" then
        copy.voice = source.voice == true
        copy.image = source.image == true
        copy.text = source.text == true
    end
    return copy
end

local function IsDefaultCustomNotification(item)
    if type(item) ~= "table" then
        return true
    end
    local resultVar = TrimText(item.resultVar or "")
    local op = NormalizeConditionOp(item.conditionOp or "<=")
    local value = tostring(item.conditionValue or "0")
    return resultVar == ""
        and op == "<="
        and (value == "" or value == "0")
end

local function GetEffectiveCustomNotifyCount(source, fallback)
    local sourceCount = type(source) == "table" and #source or 0
    local requested = tonumber(fallback and fallback.customNotifyCount) or sourceCount or 1
    local count = math.max(1, math.min(MAX_CUSTOM_NOTIFY_COUNT, requested))
    while count > 1 and IsDefaultCustomNotification(type(source) == "table" and source[count] or nil) do
        count = count - 1
    end
    return count
end

local function CopyCustomNotifications(source, fallbackState)
    local list = {}
    local fallbackState = fallbackState
    local count = GetEffectiveCustomNotifyCount(source, fallbackState)
    for i = 1, count do
        local item = type(source) == "table" and type(source[i]) == "table" and source[i] or nil
        list[i] = {
            resultVar = TrimText((item and item.resultVar) or (i == 1 and fallbackState and fallbackState.customResultVar) or ""),
            conditionOp = NormalizeConditionOp((item and item.conditionOp) or (i == 1 and fallbackState and fallbackState.customConditionOp) or "<="),
            conditionValue = tostring((item and item.conditionValue) or (i == 1 and fallbackState and fallbackState.customConditionValue) or "0"),
        }
    end
    return list, count
end

local function GetFileNameFromPath(value)
    if Utils.GetFileNameFromPath then
        return Utils.GetFileNameFromPath(value)
    end
    local path = tostring(value or ""):gsub("/", "\\")
    return path:match("([^\\]+)$") or path
end

local function BuildEntryKey(classID, specID, index)
    if CollectionStore.BuildEntryKey then
        return CollectionStore.BuildEntryKey(classID, specID, index)
    end
    return string.format("%d:%d:%d", tonumber(classID) or 0, tonumber(specID) or 0, tonumber(index) or 0)
end

local function ParseEntryKey(key)
    if CollectionStore.ParseEntryKey then
        return CollectionStore.ParseEntryKey(key)
    end
    local classID, specID, index = tostring(key or ""):match("^(%-?%d+):(%-?%d+):(%-?%d+)$")
    return tonumber(classID) or 0, tonumber(specID) or 0, tonumber(index) or 0
end

local function ParseGroupKey(key)
    if CollectionStore.ParseGroupKey then
        return CollectionStore.ParseGroupKey(key)
    end
    local classID, specID, groupID = tostring(key or ""):match("^group:(%-?%d+):(%-?%d+):(.+)$")
    return tonumber(classID) or 0, tonumber(specID) or 0, tostring(groupID or "")
end

local function EnsureRootDB()
    if CollectionStore.EnsureRootDB then
        return CollectionStore.EnsureRootDB()
    end
    if type(EllesmereUIVEDB) ~= "table" then
        EllesmereUIVEDB = {}
    end
    return EllesmereUIVEDB
end

local function EnsureCollectionScope(classID, specID)
    if CollectionStore.EnsureCollectionScope then
        return CollectionStore.EnsureCollectionScope(classID, specID)
    end
    return nil
end

local function NormalizeCollectionScope(scope, entryMap, scopeClassID, scopeSpecID)
    if CollectionStore.NormalizeCollectionScope then
        return CollectionStore.NormalizeCollectionScope(scope, entryMap, scopeClassID, scopeSpecID, GetApi())
    end
    return scope
end

local function RemoveEntryKeyFromAllCollectionScopes(entryKey)
    if CollectionStore.RemoveEntryKeyFromAllCollectionScopes then
        return CollectionStore.RemoveEntryKeyFromAllCollectionScopes(entryKey)
    end
end

local function RequestNativeUIRefresh(reason)
    if NS.UI and NS.UI.MainFrame then
        if type(NS.UI.MainFrame.RequestRefresh) == "function" then
            NS.UI.MainFrame:RequestRefresh(reason or "list")
            return true
        elseif type(NS.UI.MainFrame.Refresh) == "function" then
            NS.UI.MainFrame:Refresh()
            return true
        end
    end
    return false
end

local function HideRuntimeVisualAlerts(preserveActiveKey)
    local bridge = NS.Core and NS.Core.NotifierBridge
    if bridge and type(bridge.HideVisualAlerts) == "function" then
        bridge:HideVisualAlerts(preserveActiveKey and "__editorSave" or nil)
        return true
    end
    return false
end

local function IsLoadedScope(api, classID, specID, currentClassID, currentSpecID)
    classID = tonumber(classID) or 0
    specID = tonumber(specID) or 0
    currentClassID = tonumber(currentClassID) or 0
    currentSpecID = tonumber(currentSpecID) or 0
    if api and type(api.IsActiveScopeLoaded) == "function" then
        return api.IsActiveScopeLoaded(classID, specID, currentClassID, currentSpecID)
    end
    if classID == ALL_CLASSES_ID then
        return true
    end
    return classID == currentClassID and (specID == currentSpecID or specID == ALL_SPECS_ID)
end

local function NormalizeEntryTypeValue(value)
    value = tostring(value or "euiVoice")
    if value == "cast" then
        return value
    end
    return "euiVoice"
end

local function NormalizeObjectTypeValue(value)
    value = tostring(value or OBJECT_TYPE_SPELL):lower()
    if value ~= OBJECT_TYPE_ITEM then
        value = OBJECT_TYPE_SPELL
    end
    return value
end

local function IsEntryItemLoadRequirementMet(api, entry, objectType)
    if tostring(objectType or entry and entry.objectType or ""):lower() ~= OBJECT_TYPE_ITEM then
        return true
    end
    if api and type(api.IsItemLoadRequirementMet) == "function" then
        return api.IsItemLoadRequirementMet(entry) ~= false
    end
    return true
end

local function SameEntryIdentity(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end
    local leftID = tonumber(left.spellId or left.itemID) or 0
    local rightID = tonumber(right.spellId or right.itemID) or 0
    if leftID <= 0 or rightID <= 0 or math.floor(leftID) ~= math.floor(rightID) then
        return false
    end
    if NormalizeEntryTypeValue(left.entryType) ~= NormalizeEntryTypeValue(right.entryType) then
        return false
    end
    local objectType = NormalizeObjectTypeValue(left.objectType)
    if objectType ~= NormalizeObjectTypeValue(right.objectType) then
        return false
    end
    if objectType == OBJECT_TYPE_ITEM and NormalizeItemLoadMode(left.itemLoadMode) ~= NormalizeItemLoadMode(right.itemLoadMode) then
        return false
    end
    return true
end

local function DeleteMatchingEntriesFromMap(map, entry, classID, specID)
    if type(map) ~= "table" or type(entry) ~= "table" then
        return 0
    end
    local api = GetApi()
    local removed = 0
    for index, candidate in pairs(map) do
        local entryIndex = tonumber(index) or 0
        if entryIndex > 0 and SameEntryIdentity(candidate, entry) then
            if api and type(api.MarkEntryDeleted) == "function" then
                api.MarkEntryDeleted(classID, specID, candidate, entryIndex)
            end
            map[index] = nil
            RemoveEntryKeyFromAllCollectionScopes(BuildEntryKey(classID, specID, entryIndex))
            removed = removed + 1
        end
    end
    return removed
end

local function DeleteMatchingLegacyCastEntries(classID, specID, entry)
    if type(entry) ~= "table" or NormalizeEntryTypeValue(entry.entryType) ~= "cast" then
        return 0
    end
    local db = EnsureRootDB()
    local classMap = db.castSuccessConfigs and db.castSuccessConfigs[classID]
    local legacyMap = type(classMap) == "table" and classMap[specID] or nil
    if type(legacyMap) ~= "table" then
        return 0
    end
    local legacyProbe = {}
    for k, v in pairs(entry) do
        legacyProbe[k] = v
    end
    legacyProbe.entryType = "cast"
    return DeleteMatchingEntriesFromMap(legacyMap, legacyProbe, classID, specID)
end

local function ClearDeletedEntryMarker(classID, specID, entry, index)
    local api = GetApi()
    if api and type(api.ClearEntryDeletedMarker) == "function" then
        api.ClearEntryDeletedMarker(classID, specID, entry, index)
    end
end

local function BuildAlertActionDetailForEntry(entry, modeTts, modeSound)
    if type(entry) ~= "table" then
        return ""
    end
    local parts = {}
    if entry.voiceEnabled ~= false then
        if tostring(entry.notifyMode or modeSound or "sound") == tostring(modeTts or "tts") or tostring(entry.soundSource or "") == "tts" then
            parts[#parts + 1] = "TTS"
        else
            parts[#parts + 1] = L("TAB_VOICE")
        end
    end
    if entry.imageEnabled == true then
        parts[#parts + 1] = L("TAB_IMAGE")
    end
    if entry.textEnabled == true then
        parts[#parts + 1] = L("TAB_TEXT")
    end
    return table.concat(parts, " / ")
end

local function BuildSoundDetailForEntry(options, entry, modeTts, modeSound)
    if type(entry) ~= "table" then
        return ""
    end

    options = GetOptions(options)
    local fields = type(options.ResolveSoundSourceFields) == "function" and options:ResolveSoundSourceFields(entry, modeTts, modeSound) or entry
    if fields.soundSource == "tts" or fields.notifyMode == tostring(modeTts or "tts") then
        local text = TrimText(entry.ttsText or "")
        if text == "" then
            text = L("TTS_READY_DEFAULT")
        end
        return L("SAVED_VOICE_TTS", text)
    end

    if fields.soundSource == "sharedmedia" and TrimText(fields.sharedMediaSound or "") ~= "" then
        return L("SAVED_VOICE_SHAREDMEDIA", fields.sharedMediaSound)
    end

    local normalizedPath = type(options.NormalizeSoundPath) == "function" and options:NormalizeSoundPath(fields.soundPath or entry.soundPath or "") or tostring(fields.soundPath or entry.soundPath or "")
    if fields.soundSource == "builtin" or (normalizedPath ~= "" and type(options.IsBuiltinSoundPath) == "function" and options:IsBuiltinSoundPath(normalizedPath)) then
        local displayName = normalizedPath
        if type(options.GetBuiltinSoundDisplayName) == "function" then
            displayName = options:GetBuiltinSoundDisplayName(normalizedPath)
        end
        return L("SAVED_VOICE_BUILTIN", displayName)
    end

    local customDisplayPath = TrimText(fields.customSoundPath or "")
    if customDisplayPath == "" then
        customDisplayPath = normalizedPath
    end
    if customDisplayPath == "" then
        customDisplayPath = tostring(entry.soundPath or "")
    end
    local fileName = GetFileNameFromPath(customDisplayPath)
    if TrimText(fileName) == "" then
        fileName = L("ENTRY_UNNAMED")
    end
    return L("SAVED_VOICE_CUSTOM", fileName)
end

function EntryStore:GetEntryMap(owner)
    local api = GetApi()
    local options = GetOptions(owner)
    local state = type(options.GetState) == "function" and options:GetState() or {}
    if not api then
        return {}
    end
    return api.GetStoredEntryMap(state.classID, state.specID)
end

function EntryStore:GetCurrentScopeEntryList(owner)
    local api = GetApi()
    local options = GetOptions(owner)
    local state = type(options.GetState) == "function" and options:GetState() or {}
    if not api then
        return {}
    end

    local entries = {}
    local map = self:GetEntryMap(options)
    local indices = type(api.GetOrderedEntryIndices) == "function" and api.GetOrderedEntryIndices(map) or {}
    local modeTts, modeSound = api.GetModes()

    for _, index in ipairs(indices) do
        local entry = api.GetEntry(map, index)
        if entry then
            local spellId = tonumber(entry.spellId) or 0
            local entryType = NormalizeEntryTypeValue(entry.entryType)
            local objectType = type(api.ResolveObjectType) == "function" and api.ResolveObjectType(spellId, entry.objectType) or tostring(entry.objectType or OBJECT_TYPE_SPELL)
            local spellName = TrimText(entry.spellName)
            local icon = nil
            if spellName == "" and spellId > 0 then
                spellName = type(api.ResolveObjectName) == "function" and api.ResolveObjectName(spellId, objectType) or api.ResolveSpellName(spellId)
            end
            if not icon then
                icon = type(api.ResolveObjectIcon) == "function" and api.ResolveObjectIcon(spellId, objectType) or (type(api.ResolveSpellIcon) == "function" and api.ResolveSpellIcon(spellId) or nil)
            end

            entries[#entries + 1] = {
                key = BuildEntryKey(state.classID, state.specID, index),
                entryType = entryType,
                index = index,
                spellId = spellId,
                objectType = objectType,
                itemLoadMode = (objectType == OBJECT_TYPE_ITEM) and NormalizeItemLoadMode(entry.itemLoadMode) or ITEM_LOAD_NONE,
                itemLoadSameName = objectType == OBJECT_TYPE_ITEM and NormalizeItemLoadMode(entry.itemLoadMode) == ITEM_LOAD_BAGS and entry.itemLoadSameName == true,
                spellName = spellName ~= "" and spellName or tostring(spellId),
                modeText = BuildAlertActionDetailForEntry(entry, modeTts, modeSound),
                soundDetail = BuildSoundDetailForEntry(options, entry, modeTts, modeSound),
                notifyMode = tostring(entry.notifyMode or modeSound),
                soundPath = tostring(entry.soundPath or ""),
                ttsText = tostring(entry.ttsText or ""),
                delayEnabled = entry.delayEnabled == true,
                delaySeconds = math.max(0, tonumber(entry.delaySeconds) or 0),
                castDelayMode = NormalizeCastDelayMode(entry.castDelayMode),
                checkTalent = entry.checkTalent == true and (tonumber(entry.talentId) or 0) > 0,
                talentId = tonumber(entry.talentId) or 0,
                talentName = TrimText(entry.talentName or ""),
                talentCD = tonumber(entry.talentCD) or 0,
                alertRaceIDs = NormalizeCustomRaceMap(entry.alertRaceIDs),
                icon = icon,
            }
        end
    end

    return entries
end

function EntryStore:GetAllSavedEntryList(owner)
    local api = GetApi()
    local options = GetOptions(owner)
    if not api then
        return {}
    end

    local entries = {}
    local db = EllesmereUIVEDB
    local root = type(db) == "table" and db.specConfigs or nil
    if type(root) ~= "table" then
        return entries
    end

    local currentClassID, currentSpecID = api.GetCurrentClassSpec()
    local modeTts, modeSound = api.GetModes()

    for classIDKey, classMap in pairs(root) do
        local classID = tonumber(classIDKey)
        if classID and classID >= 0 and type(classMap) == "table" then
            local className = api.ResolveClassName(classID)
            for specIDKey, specMap in pairs(classMap) do
                local specID = tonumber(specIDKey)
                if specID and specID >= 0 and type(specMap) == "table" then
                    local specName = api.ResolveSpecName(classID, specID)
                    local scopeLoaded = IsLoadedScope(api, classID, specID, currentClassID, currentSpecID)
                    local indices = type(api.GetOrderedEntryIndices) == "function" and api.GetOrderedEntryIndices(specMap) or {}
                    for _, index in ipairs(indices) do
                        local entry = api.GetEntry(specMap, index)
                        if entry then
                            local spellId = tonumber(entry.spellId) or 0
                            local entryType = NormalizeEntryTypeValue(entry.entryType)
                            local objectType = type(api.ResolveObjectType) == "function" and api.ResolveObjectType(spellId, entry.objectType) or tostring(entry.objectType or OBJECT_TYPE_SPELL)
                            local spellName = TrimText(entry.spellName)
                            local icon = nil
                            if spellName == "" and spellId > 0 then
                                spellName = type(api.ResolveObjectName) == "function" and api.ResolveObjectName(spellId, objectType) or api.ResolveSpellName(spellId)
                            end
                            if not icon then
                                icon = type(api.ResolveObjectIcon) == "function" and api.ResolveObjectIcon(spellId, objectType) or (type(api.ResolveSpellIcon) == "function" and api.ResolveSpellIcon(spellId) or nil)
                            end

                            local entryLoaded = scopeLoaded and EntryAlertScopeMatchesCurrent(entry, classID, specID, currentClassID, currentSpecID) and IsEntryItemLoadRequirementMet(api, entry, objectType)
                            local loadedTag = entryLoaded and L("LOADED_TAG") or L("UNLOADED_TAG")

                            entries[#entries + 1] = {
                                key = BuildEntryKey(classID, specID, index),
                                entryType = entryType,
                                objectType = objectType,
                                itemLoadMode = (objectType == OBJECT_TYPE_ITEM) and NormalizeItemLoadMode(entry.itemLoadMode) or ITEM_LOAD_NONE,
                                itemLoadSameName = objectType == OBJECT_TYPE_ITEM and NormalizeItemLoadMode(entry.itemLoadMode) == ITEM_LOAD_BAGS and entry.itemLoadSameName == true,
                                alertRaceIDs = NormalizeCustomRaceMap(entry.alertRaceIDs),
                                classID = classID,
                                specID = specID,
                                index = index,
                                spellId = spellId,
                                spellName = spellName ~= "" and spellName or tostring(spellId),
                                modeText = BuildAlertActionDetailForEntry(entry, modeTts, modeSound),
                                soundDetail = BuildSoundDetailForEntry(options, entry, modeTts, modeSound),
                                notifyMode = tostring(entry.notifyMode or modeSound),
                                soundPath = tostring(entry.soundPath or ""),
                                ttsText = tostring(entry.ttsText or ""),
                                delayEnabled = entry.delayEnabled == true,
                                delaySeconds = math.max(0, tonumber(entry.delaySeconds) or 0),
                                castDelayMode = NormalizeCastDelayMode(entry.castDelayMode),
                                checkTalent = entry.checkTalent == true and (tonumber(entry.talentId) or 0) > 0,
                                talentId = tonumber(entry.talentId) or 0,
                                talentName = TrimText(entry.talentName or ""),
                                talentCD = tonumber(entry.talentCD) or 0,
                                icon = icon,
                                scopeText = string.format("%s / %s%s", className, specName, loadedTag),
                                isLoaded = entryLoaded,
                            }
                        end
                    end
                end
            end
        end
    end

    table.sort(entries, function(a, b)
        if a.classID ~= b.classID then
            return a.classID < b.classID
        end
        if a.specID ~= b.specID then
            return a.specID < b.specID
        end
        return a.index < b.index
    end)

    return entries
end

function EntryStore:LoadSelectedEntry(owner)
    local api = GetApi()
    local options = GetOptions(owner)
    local state = type(options.GetState) == "function" and options:GetState() or {}
    if not api then
        return
    end

    local classID, specID, selectedIndex = ParseEntryKey(state.selectedKey)
    if classID < 0 or specID < 0 or selectedIndex <= 0 then
        return
    end
    if classID == ALL_CLASSES_ID then
        specID = ALL_SPECS_ID
    end

    local map = api.GetStoredEntryMap(classID, specID)
    local entry = api.GetEntry(map, selectedIndex)
    if not entry then
        print("[EUIVE] " .. L("MSG_SELECTED_NOT_EXIST"))
        return
    end

    state.classID = classID
    state.specID = specID
    state.entryType = NormalizeEntryTypeValue(entry.entryType)
    state.euiTriggerType = tostring(entry.euiTriggerType or "cdReady")
    state.injectOnSave = false
    state.spellId = tonumber(entry.spellId) or 0
    state.objectType = type(api.ResolveObjectType) == "function" and api.ResolveObjectType(state.spellId, entry.objectType) or tostring(entry.objectType or OBJECT_TYPE_SPELL)
    state.itemLoadMode = (state.objectType == OBJECT_TYPE_ITEM) and NormalizeItemLoadMode(entry.itemLoadMode) or ITEM_LOAD_NONE
    state.itemLoadSameName = state.objectType == OBJECT_TYPE_ITEM and state.itemLoadMode == ITEM_LOAD_BAGS and entry.itemLoadSameName == true
    state.spellName = TrimText(entry.spellName)
    state.baseCD = tonumber(entry.baseCD) or 0
    state.fixedCD = true
    state.checkTalent = entry.checkTalent == true and (tonumber(entry.talentId) or 0) > 0
    state.talentId = tonumber(entry.talentId) or 0
    state.talentName = TrimText(entry.talentName or "")
    state.talentCD = tonumber(entry.talentCD) or 0
    state.delayEnabled = entry.delayEnabled == true
    state.delaySeconds = math.max(0, tonumber(entry.delaySeconds) or 0)
    state.castDelayMode = NormalizeCastDelayMode(entry.castDelayMode)
    state.cooldownAlertTime = math.max(0, tonumber(entry.cooldownAlertTime or entry.alertLeadTime) or 0)
    local legacyAlertTime = state.cooldownAlertTime
    local modeTts, modeSound = api.GetModes()
    state.ttsText = tostring(entry.ttsText or "")
    state.ttsRate = tonumber(entry.ttsRate) or 0
    local soundFields = type(options.ResolveSoundSourceFields) == "function" and options:ResolveSoundSourceFields(entry, modeTts, modeSound) or entry
    state.notifyMode = soundFields.notifyMode
    state.soundSource = soundFields.soundSource
    state.soundPath = soundFields.soundPath
    state.builtinSoundPath = soundFields.builtinSoundPath
    state.customSoundPath = soundFields.customSoundPath
    state.customSoundPaths = CopyCustomSoundPaths(entry.customSoundPaths, state.customSoundPath, true)
    state.customSoundPath = FirstCustomSoundPath(state.customSoundPaths) ~= "" and FirstCustomSoundPath(state.customSoundPaths) or NormalizeSoundPath(state.customSoundPath or "")
    state.sharedMediaSound = soundFields.sharedMediaSound
    state.useCustomSound = soundFields.useCustomSound == true
    state.useSharedMediaSound = soundFields.useSharedMediaSound == true
    state.voiceEnabled = entry.voiceEnabled ~= false
    state.voiceConditionOp = NormalizeConditionOp(entry.voiceConditionOp)
    state.voiceConditionTime = NormalizeConditionTime(entry.voiceConditionTime, legacyAlertTime)
    state.activeAlertTab = "settings"
    state.imageEnabled = entry.imageEnabled == true
    state.imageConditionOp = NormalizeConditionOp(entry.imageConditionOp)
    state.imageConditionTime = NormalizeConditionTime(entry.imageConditionTime, legacyAlertTime)
    state.imageSource = tostring(entry.imageSource or ((TrimText(entry.imagePath or "") ~= "") and "path" or "auto"))
    if state.imageSource ~= "spell" and state.imageSource ~= "item" and state.imageSource ~= "icon" and state.imageSource ~= "path" then state.imageSource = "auto" end
    state.imageIconID = math.max(0, tonumber(entry.imageIconID) or 0)
    state.imagePath = TrimText(entry.imagePath or "")
    state.imageSize = math.max(16, tonumber(entry.imageSize) or 96)
    state.imageDurationEnabled = entry.imageDurationEnabled == true
    state.imageDuration = math.max(0.1, tonumber(entry.imageDuration) or 2)
    state.imageX = tonumber(entry.imageX) or 0
    state.imageY = tonumber(entry.imageY) or 120
    state.textEnabled = entry.textEnabled == true
    state.textConditionOp = NormalizeConditionOp(entry.textConditionOp)
    state.textConditionTime = NormalizeConditionTime(entry.textConditionTime, legacyAlertTime)
    state.textAlert = tostring(entry.textAlert or "")
    state.textSize = math.max(8, tonumber(entry.textSize) or 24)
    state.textDurationEnabled = entry.textDurationEnabled == true
    state.textDuration = math.max(0.1, tonumber(entry.textDuration) or 2)
    state.textX = tonumber(entry.textX) or 0
    state.textY = tonumber(entry.textY) or 120
    state.textAttachMode = tostring(entry.textAttachMode or "outside")
    if state.textAttachMode ~= "inside" then state.textAttachMode = "outside" end
    state.textVAlign = tostring(entry.textVAlign or "bottom")
    if state.textVAlign ~= "top" and state.textVAlign ~= "middle" then state.textVAlign = "bottom" end
    state.textHAlign = tostring(entry.textHAlign or "center")
    if state.textHAlign ~= "left" and state.textHAlign ~= "right" then state.textHAlign = "center" end
    state.textOffsetX = tonumber(entry.textOffsetX) or 0
    state.textOffsetY = tonumber(entry.textOffsetY) or 0

    state.customName = nil
    state.customCode = nil
    state.customUseEvents = nil
    state.customEvents = nil
    state.customEventText = nil
    state.customUseTicker = nil
    state.customInterval = nil
    state.customResultVar = nil
    state.customConditionOp = nil
    state.customConditionValue = nil
    state.customConditionLogic = nil
    state.customResultVars = nil
    state.customNotifications = nil
    state.customNotifyCount = nil
    state.alertClassIDs = NormalizeCustomClassMap(entry.alertClassIDs or entry.customClassIDs, classID)
    state.alertSpecIDs = NormalizeCustomSpecMap(entry.alertSpecIDs or entry.customSpecIDs, specID)
    state.alertRaceIDs = NormalizeCustomRaceMap(entry.alertRaceIDs)
    state.customClassIDs = nil
    state.customSpecIDs = nil
    if state.spellName == "" and state.spellId > 0 then
        state.spellName = type(api.ResolveObjectName) == "function" and api.ResolveObjectName(state.spellId, state.objectType) or api.ResolveSpellName(state.spellId)
    end
end

function EntryStore:AutofillFromSpellId(owner)
    local api = GetApi()
    local options = GetOptions(owner)
    local state = type(options.GetState) == "function" and options:GetState() or {}
    if not api then
        return
    end

    local spellId = tonumber(state.spellId) or 0
    if spellId <= 0 then
        return
    end

    local objectType = type(api.ResolveObjectType) == "function" and api.ResolveObjectType(spellId, state.objectType) or OBJECT_TYPE_SPELL
    state.objectType = objectType
    local itemLoadMode = (objectType == OBJECT_TYPE_ITEM) and NormalizeItemLoadMode(state.itemLoadMode) or ITEM_LOAD_NONE
    state.itemLoadMode = itemLoadMode
    state.itemLoadSameName = objectType == OBJECT_TYPE_ITEM and itemLoadMode == ITEM_LOAD_BAGS and state.itemLoadSameName == true

    local spellName = type(api.ResolveObjectName) == "function" and api.ResolveObjectName(spellId, objectType) or api.ResolveSpellName(spellId)
    if spellName ~= "" then
        state.spellName = spellName
    end

    local baseCD = type(api.ResolveObjectBaseCooldownSeconds) == "function" and api.ResolveObjectBaseCooldownSeconds(spellId, objectType) or api.ResolveSpellBaseCooldownSeconds(spellId)
    if baseCD and baseCD > 0 then
        state.baseCD = baseCD
    end
end

function EntryStore:AutofillFromTalentId(owner)
    local api = GetApi()
    local options = GetOptions(owner)
    local state = type(options.GetState) == "function" and options:GetState() or {}
    if not api then
        return
    end

    local talentId = tonumber(state.talentId) or 0
    if talentId <= 0 then
        state.talentName = ""
        return
    end

    local talentName = ""
    if type(api.ResolveTalentName) == "function" then
        talentName = api.ResolveTalentName(talentId)
    elseif type(api.ResolveSpellName) == "function" then
        talentName = api.ResolveSpellName(talentId)
    end
    if talentName ~= "" then
        state.talentName = talentName
    end
end

function EntryStore:SaveEntry(owner)
    local api = GetApi()
    local options = GetOptions(owner)
    local state = type(options.GetState) == "function" and options:GetState() or {}
    if not api then
        return
    end

    local classID = tonumber(state.classID) or 0
    local specID = tonumber(state.specID) or 0
    local selectedCollectionKeyForSave = tostring(state.selectedCollectionKey or "")
    if selectedCollectionKeyForSave == "" and tostring(state.selectedKey or ""):match("^group:") then
        selectedCollectionKeyForSave = tostring(state.selectedKey or "")
    end
    local saveGroupClassID, saveGroupSpecID, saveGroupID = ParseGroupKey(selectedCollectionKeyForSave)
    if saveGroupID ~= "" and saveGroupClassID >= 0 and saveGroupSpecID >= 0 then
        classID = saveGroupClassID
        specID = saveGroupSpecID
    end
    if classID == ALL_CLASSES_ID then
        specID = ALL_SPECS_ID
        state.specID = ALL_SPECS_ID
    end
    local spellId = tonumber(state.spellId) or 0
    local objectType = type(api.ResolveObjectType) == "function" and api.ResolveObjectType(spellId, state.objectType) or OBJECT_TYPE_SPELL
    local baseCD = tonumber(state.baseCD) or 0
    local checkTalent = state.checkTalent == true
    local talentId = tonumber(state.talentId) or 0
    local talentName = TrimText(state.talentName or "")
    local talentCD = tonumber(state.talentCD) or 0
    local notifyMode = tostring(state.notifyMode or select(2, api.GetModes()))
    local ttsText = tostring(state.ttsText or "")
    local delayEnabled = state.delayEnabled == true
    local delaySeconds = math.max(0, tonumber(state.delaySeconds) or 0)
    local castDelayMode = NormalizeCastDelayMode(state.castDelayMode)
    local cooldownAlertTime = math.max(0, tonumber(state.cooldownAlertTime) or 0)
    local voiceEnabled = state.voiceEnabled ~= false
    local voiceConditionOp = NormalizeConditionOp(state.voiceConditionOp)
    local voiceConditionTime = NormalizeConditionTime(state.voiceConditionTime, cooldownAlertTime)
    if cooldownAlertTime <= 0 and voiceConditionTime > 0 then
        cooldownAlertTime = voiceConditionTime
    end
    local imageEnabled = state.imageEnabled == true
    local imageConditionOp = NormalizeConditionOp(state.imageConditionOp)
    local imageConditionTime = NormalizeConditionTime(state.imageConditionTime, cooldownAlertTime)
    local imageSource = tostring(state.imageSource or "auto")
    if imageSource ~= "spell" and imageSource ~= "item" and imageSource ~= "icon" and imageSource ~= "path" then imageSource = "auto" end
    local imageIconID = math.max(0, tonumber(state.imageIconID) or 0)
    local imagePath = TrimText(state.imagePath or "")
    local imageSize = math.max(16, tonumber(state.imageSize) or 96)
    local imageDurationEnabled = state.imageDurationEnabled == true
    local imageDuration = math.max(0.1, tonumber(state.imageDuration) or 2)
    local imageX = math.floor((tonumber(state.imageX) or 0) + 0.5)
    local imageY = math.floor((tonumber(state.imageY) or 120) + 0.5)
    local textEnabled = state.textEnabled == true
    local textConditionOp = NormalizeConditionOp(state.textConditionOp)
    local textConditionTime = NormalizeConditionTime(state.textConditionTime, cooldownAlertTime)
    if cooldownAlertTime <= 0 then
        cooldownAlertTime = math.max(voiceConditionTime or 0, imageConditionTime or 0, textConditionTime or 0)
    end
    state.cooldownAlertTime = cooldownAlertTime
    local textAlert = tostring(state.textAlert or "")
    local textSize = math.max(8, tonumber(state.textSize) or 24)
    local textDurationEnabled = state.textDurationEnabled == true
    local textDuration = math.max(0.1, tonumber(state.textDuration) or 2)
    local textX = math.floor((tonumber(state.textX) or 0) + 0.5)
    local textY = math.floor((tonumber(state.textY) or 120) + 0.5)
    local textAttachMode = tostring(state.textAttachMode or "outside")
    if textAttachMode ~= "inside" then textAttachMode = "outside" end
    local textVAlign = tostring(state.textVAlign or "bottom")
    if textVAlign ~= "top" and textVAlign ~= "middle" then textVAlign = "bottom" end
    local textHAlign = tostring(state.textHAlign or "center")
    if textHAlign ~= "left" and textHAlign ~= "right" then textHAlign = "center" end
    local textOffsetX = math.floor((tonumber(state.textOffsetX) or 0) + 0.5)
    local textOffsetY = math.floor((tonumber(state.textOffsetY) or 0) + 0.5)
    if imageEnabled and textEnabled and (imageDurationEnabled or textDurationEnabled) then
        imageDurationEnabled = true
        textDurationEnabled = true
        state.imageDurationEnabled = true
        state.textDurationEnabled = true
    elseif imageEnabled and textEnabled then
        state.imageDurationEnabled = false
        state.textDurationEnabled = false
    end
    state.objectType = objectType
    local itemLoadMode = (objectType == OBJECT_TYPE_ITEM) and NormalizeItemLoadMode(state.itemLoadMode) or ITEM_LOAD_NONE
    state.itemLoadMode = itemLoadMode
    local modeTts, modeSound = api.GetModes()
    local pendingCustomSoundPaths = CopyCustomSoundPaths(state.customSoundPaths, state.customSoundPath)
    local pendingCustomSoundPath = FirstCustomSoundPath(pendingCustomSoundPaths)
    local sourceForSave = {
        notifyMode = notifyMode,
        soundSource = state.soundSource,
        soundPath = state.soundPath,
        builtinSoundPath = state.builtinSoundPath,
        customSoundPath = pendingCustomSoundPath ~= "" and pendingCustomSoundPath or state.customSoundPath,
        customSoundPaths = pendingCustomSoundPaths,
        sharedMediaSound = state.sharedMediaSound,
        sharedMediaName = state.sharedMediaName,
    }
    if tostring(sourceForSave.soundSource or "") == "builtin" then
        sourceForSave.soundPath = state.builtinSoundPath or state.soundPath
    elseif tostring(sourceForSave.soundSource or "") == "custom" then
        sourceForSave.soundPath = pendingCustomSoundPath ~= "" and pendingCustomSoundPath or state.customSoundPath or state.soundPath
    end
    local soundFields = type(options.ResolveSoundSourceFields) == "function" and options:ResolveSoundSourceFields(sourceForSave, modeTts, modeSound) or sourceForSave
    notifyMode = soundFields.notifyMode
    local soundPath = type(options.NormalizeSoundPath) == "function" and options:NormalizeSoundPath(soundFields.soundPath or "") or tostring(soundFields.soundPath or "")
    local soundSource = tostring(soundFields.soundSource or "builtin")
    local sharedMediaSound = TrimText(soundFields.sharedMediaSound or "")
    state.notifyMode = notifyMode
    state.soundSource = soundSource
    state.soundPath = soundPath
    state.builtinSoundPath = soundFields.builtinSoundPath
    state.customSoundPaths = CopyCustomSoundPaths(pendingCustomSoundPaths, soundFields.customSoundPath or state.customSoundPath)
    state.customSoundPath = FirstCustomSoundPath(state.customSoundPaths) ~= "" and FirstCustomSoundPath(state.customSoundPaths) or NormalizeSoundPath(soundFields.customSoundPath or state.customSoundPath or "")
    state.sharedMediaSound = sharedMediaSound
    state.useCustomSound = soundFields.useCustomSound == true
    state.useSharedMediaSound = soundFields.useSharedMediaSound == true
    local entryType = NormalizeEntryTypeValue(state.entryType)
    local isCooldownEntry = entryType == "euiVoice"
    local isCastEntry = entryType == "cast"

    local alertRaceIDs = NormalizeCustomRaceMap(state.alertRaceIDs)
    local alertClassIDs = NormalizeCustomClassMap(state.alertClassIDs, classID)
    local alertSpecIDs = NormalizeCustomSpecMap(state.alertSpecIDs, specID)

    -- Keep the original per-class/per-specialization storage scope. The
    -- applicability maps may broaden a preset, but they do not create a second
    -- database or flatten every entry into the global bucket.
    state.alertRaceIDs = alertRaceIDs
    state.alertClassIDs = alertClassIDs
    state.alertSpecIDs = alertSpecIDs
    if classID < 0 or specID < 0 then
        print("[EUIVE] " .. L("MSG_INVALID_CLASS_SPEC"))
        return
    end
    if spellId <= 0 then
        print("[EUIVE] " .. L("MSG_INVALID_SPELL_ID"))
        return
    end
    if isCooldownEntry then
        baseCD = 0
        checkTalent = false
        talentId = 0
        talentName = ""
        talentCD = 0
        imageEnabled = false
        textEnabled = false
        voiceEnabled = true
        if soundSource == "tts" or notifyMode == modeTts then
            print("[EUIVE] " .. L("STATUS_unsupported_tts"))
            return
        end
    end
    if (not isCooldownEntry) then
        baseCD = 0
        checkTalent = false
        talentId = 0
        talentName = ""
        talentCD = 0
    else
        delayEnabled = false
        delaySeconds = 0
        castDelayMode = "show"
    end
    if isCastEntry and delayEnabled and delaySeconds <= 0 then
        print("[EUIVE] " .. L("MSG_INVALID_DELAY_SECONDS"))
        return
    end
    if checkTalent and talentId <= 0 then
        print("[EUIVE] " .. L("MSG_NEED_TALENT_ID"))
        return
    end
    if checkTalent and talentCD <= 0 then
        print("[EUIVE] " .. L("MSG_NEED_TALENT_CD"))
        return
    end
    if checkTalent and talentName == "" and type(api.ResolveTalentName) == "function" then
        talentName = api.ResolveTalentName(talentId)
        state.talentName = talentName
    end
    if not voiceEnabled and not imageEnabled and not textEnabled then
        print("[EUIVE] " .. L("MSG_NEED_ALERT_ACTIONS"))
        return
    end
    if voiceEnabled and notifyMode == modeTts and TrimText(ttsText) == "" then
        print("[EUIVE] " .. L("MSG_NEED_TTS_TEXT"))
        return
    end
    if voiceEnabled and notifyMode == modeSound and TrimText(soundPath) == "" then
        print("[EUIVE] " .. L("MSG_NEED_SOUND_PATH"))
        return
    end

    local map = api.EnsureEntryMap(classID, specID)
    local selectedClassID, selectedSpecID, selectedIndex = ParseEntryKey(state.selectedKey)
    local targetIndex = 0

    if selectedClassID == classID and selectedSpecID == specID and selectedIndex >= 1 and api.GetEntry(map, selectedIndex) then
        targetIndex = selectedIndex
    else
        targetIndex = api.FindFirstFreeIndex(map) or 0
    end

    local indices = type(api.GetOrderedEntryIndices) == "function" and api.GetOrderedEntryIndices(map) or {}
    for _, index in ipairs(indices) do
        local entry = api.GetEntry(map, index)
        local existingID = tonumber(entry and entry.spellId) or 0
        local existingType = api and type(api.ResolveObjectType) == "function" and api.ResolveObjectType(existingID, entry and entry.objectType) or tostring(entry and entry.objectType or OBJECT_TYPE_SPELL)
        if entry
            and index ~= targetIndex
            and (tonumber(entry.spellId) or 0) == spellId
            and NormalizeEntryTypeValue(entry.entryType) == entryType
            and (entryType ~= "euiVoice" or tostring(entry.euiTriggerType or "cdReady") == tostring(state.euiTriggerType or "cdReady"))
            and tostring(existingType) == tostring(objectType)
            and (objectType ~= OBJECT_TYPE_ITEM or ItemLoadModesOverlap(entry.itemLoadMode, itemLoadMode))
            and EntryAlertScopeOverlaps(entry, classID, specID, alertRaceIDs, alertClassIDs, alertSpecIDs) then
            print("[EUIVE] " .. L("MSG_DUP_SPELL"))
            return
        end
    end

    if targetIndex <= 0 then
        print("[EUIVE] " .. L("MSG_SAVE_LIMIT"))
        return
    end

    local oldEntry = api.GetEntry(map, targetIndex)
    local savedEntry = {
        entryType = entryType,
        objectType = objectType,
        spellName = tostring(state.spellName or ""),
        spellId = math.floor(spellId),
        itemID = (objectType == OBJECT_TYPE_ITEM) and math.floor(spellId) or nil,
        itemLoadMode = (objectType == OBJECT_TYPE_ITEM) and itemLoadMode or nil,
        itemLoadSameName = (objectType == OBJECT_TYPE_ITEM and itemLoadMode == ITEM_LOAD_BAGS and state.itemLoadSameName == true) or nil,
        baseCD = isCooldownEntry and tonumber(string.format("%.2f", baseCD)) or 0,
        fixedCD = true,
        checkTalent = isCooldownEntry and checkTalent and talentId > 0,
        talentId = (isCooldownEntry and checkTalent) and math.floor(talentId) or 0,
        talentName = (isCooldownEntry and checkTalent) and talentName or "",
        talentCD = (isCooldownEntry and checkTalent) and tonumber(string.format("%.2f", talentCD)) or 0,
        chargeInput = 1,
        notifyMode = notifyMode,
        ttsText = ttsText,
        ttsRate = math.max(-10, math.min(10, tonumber(state.ttsRate) or 0)),
        delayEnabled = isCastEntry and delayEnabled == true,
        delaySeconds = isCastEntry and tonumber(string.format("%.2f", delaySeconds)) or 0,
        castDelayMode = isCastEntry and castDelayMode or "show",
        cooldownAlertTime = isCooldownEntry and tonumber(string.format("%.2f", cooldownAlertTime)) or 0,
        soundPath = soundPath,
        soundSource = soundSource,
        builtinSoundPath = soundFields.builtinSoundPath or state.builtinSoundPath or "",
        customSoundPath = (soundSource == "custom" and state.customSoundPath ~= "") and state.customSoundPath or "",
        customSoundPaths = (soundSource == "custom" and HasCustomSoundPath(state.customSoundPaths)) and CopyCustomSoundPaths(state.customSoundPaths, state.customSoundPath) or nil,
        sharedMediaSound = (soundSource == "sharedmedia" and sharedMediaSound ~= "") and sharedMediaSound or nil,
        voiceEnabled = voiceEnabled,
        voiceConditionOp = isCooldownEntry and voiceConditionOp or "<=",
        voiceConditionTime = isCooldownEntry and tonumber(string.format("%.2f", voiceConditionTime)) or 0,
        imageEnabled = imageEnabled,
        imageConditionOp = isCooldownEntry and imageConditionOp or "<=",
        imageConditionTime = isCooldownEntry and tonumber(string.format("%.2f", imageConditionTime)) or 0,
        imageSource = imageSource,
        imageIconID = imageIconID,
        imagePath = imagePath,
        imageSize = imageSize,
        imageDurationEnabled = imageDurationEnabled,
        imageDuration = imageDuration,
        imageX = imageX,
        imageY = imageY,
        textEnabled = textEnabled,
        textConditionOp = isCooldownEntry and textConditionOp or "<=",
        textConditionTime = isCooldownEntry and tonumber(string.format("%.2f", textConditionTime)) or 0,
        textAlert = textAlert,
        textSize = textSize,
        textDurationEnabled = textDurationEnabled,
        textDuration = textDuration,
        textX = textX,
        textY = textY,
        textAttachMode = textAttachMode,
        textVAlign = textVAlign,
        textHAlign = textHAlign,
        textOffsetX = textOffsetX,
        textOffsetY = textOffsetY,
        alertRaceIDs = alertRaceIDs,
        alertClassIDs = alertClassIDs,
        alertSpecIDs = alertSpecIDs,
    }
    if isCooldownEntry then
        local trigger = tostring(state.euiTriggerType or "cdReady")
        if trigger ~= "buffGain" and trigger ~= "buffLoss" then trigger = "cdReady" end
        savedEntry.euiTriggerType = trigger
        savedEntry.euiTargetMode = tostring(oldEntry and oldEntry.euiTargetMode or "auto")
        savedEntry.euiTargetFamily = tostring(oldEntry and oldEntry.euiTargetFamily or "auto")
        savedEntry.enabled = voiceEnabled
        savedEntry.imageEnabled = nil
        savedEntry.textEnabled = nil
        savedEntry.ttsText = nil
        savedEntry.ttsRate = nil
    else
        savedEntry.enabled = voiceEnabled
    end

    -- 已经保存过 triggerSpellID 的同一物品，不再重复解析；只沿用旧值。
    if objectType == OBJECT_TYPE_ITEM
        and oldEntry
        and tostring(oldEntry.objectType or "") == OBJECT_TYPE_ITEM
        and (tonumber(oldEntry.spellId) or 0) == spellId
        and (tonumber(oldEntry.triggerSpellID or oldEntry.triggerSpellId) or 0) > 0 then
        savedEntry.triggerSpellID = math.floor(tonumber(oldEntry.triggerSpellID or oldEntry.triggerSpellId) or 0)
        savedEntry.triggerSpellName = tostring(oldEntry.triggerSpellName or "")
    end

    if objectType == OBJECT_TYPE_ITEM and type(api.ResolveItemTriggerForEntry) == "function" then
        local resolved = api.ResolveItemTriggerForEntry(savedEntry, true)
        if not resolved then
            print("[EUIVE] " .. L("MSG_ITEM_TRIGGER_PENDING_SAVED", tostring(spellId)))
        end
    end

    savedEntry.entryUID = oldEntry and oldEntry.entryUID or (NS.Core and NS.Core.Database and NS.Core.Database:NextEntryUID())
    savedEntry.classID, savedEntry.specID = classID, specID
    if NS.Core and NS.Core.Database and type(NS.Core.Database.NormalizeEUITarget) == "function" then
        NS.Core.Database:NormalizeEUITarget(savedEntry)
    end
    if isCooldownEntry and state.injectOnSave == true and oldEntry and oldEntry.entryType == "euiVoice"
        and NS.Integrations and NS.Integrations.EllesmereUI then
        local oldSnapshot = type(NS.SnapshotEntry) == "function" and NS.SnapshotEntry(oldEntry) or oldEntry
        local removed, removeStatus = NS.Integrations.EllesmereUI:RemoveEntry(oldSnapshot, true)
        if not removed and removeStatus ~= "removed" and removeStatus ~= "waiting_combat" and type(NS.QueueEUIRemoval) == "function" then
            NS:QueueEUIRemoval(oldSnapshot)
        end
    end
    ClearDeletedEntryMarker(classID, specID, savedEntry, targetIndex)
    map[targetIndex] = savedEntry
    if isCooldownEntry then
        local registry = NS.Core and NS.Core.EUISoundRegistry
        if registry and type(registry.RegisterEntry) == "function" then registry:RegisterEntry(savedEntry) end
        if state.injectOnSave == true and type(NS.InjectSavedEntry) == "function" then
            local _, status = NS:InjectSavedEntry(savedEntry)
            savedEntry.injectionStatus = status
        else
            savedEntry.injectionStatus = "saved_waiting_sync"
        end
    end

    if selectedIndex >= 1 and (selectedClassID ~= classID or selectedSpecID ~= specID or selectedIndex ~= targetIndex) then
        local oldMap = api.GetStoredEntryMap(selectedClassID, selectedSpecID)
        local oldSelectedEntry = api.GetEntry(oldMap, selectedIndex)
        if oldSelectedEntry and NormalizeEntryTypeValue(oldSelectedEntry.entryType) == entryType then
            oldMap[selectedIndex] = nil
            RemoveEntryKeyFromAllCollectionScopes(BuildEntryKey(selectedClassID, selectedSpecID, selectedIndex))
        end
    end

    local selectedCollectionKey = tostring(state.selectedCollectionKey or "")
    if selectedCollectionKey == "" and tostring(state.selectedKey or ""):match("^group:") then
        selectedCollectionKey = tostring(state.selectedKey or "")
    end
    if selectedCollectionKey ~= "" then
        local groupClassID, groupSpecID, groupID = ParseGroupKey(selectedCollectionKey)
        if groupID ~= "" and groupClassID == classID and groupSpecID == specID then
            local scope = EnsureCollectionScope(classID, specID)
            if scope and type(scope.groups[groupID]) == "table" then
                local entryKey = BuildEntryKey(classID, specID, targetIndex)
                RemoveEntryKeyFromAllCollectionScopes(entryKey)
                local group = scope.groups[groupID]
                if type(group.entries) ~= "table" then
                    group.entries = {}
                end
                group.entries[#group.entries + 1] = entryKey
                NormalizeCollectionScope(scope, map, classID, specID)
            end
        end
    end

    api.RebuildRuntimeConfig()
    if type(api.RebuildCastSuccessConfig) == "function" then
        api.RebuildCastSuccessConfig()
    end
    if type(api.RebuildCustomConfig) == "function" then
        api.RebuildCustomConfig()
    end
    HideRuntimeVisualAlerts(true)
    api.RefreshRuntimeCooldowns()
    state.selectedKey = BuildEntryKey(classID, specID, targetIndex)
    self:LoadSelectedEntry(options)
    if not RequestNativeUIRefresh("list") and type(api.RefreshPanel) == "function" then
        api.RefreshPanel()
    end
    print("[EUIVE] " .. L("MSG_CONFIG_SAVED"))
    return true
end

function EntryStore:DeleteSelectedEntry(owner, suppressRefresh)
    local api = GetApi()
    local options = GetOptions(owner)
    local state = type(options.GetState) == "function" and options:GetState() or {}
    if not api then
        return
    end

    local classID, specID, index = ParseEntryKey(state.selectedKey)
    if classID < 0 or specID < 0 or index <= 0 then
        print("[EUIVE] " .. L("MSG_CHOOSE_CONFIG"))
        return
    end

    local map = api.EnsureEntryMap(classID, specID)
    if not map then
        print("[EUIVE] " .. L("MSG_INVALID_CLASS_SPEC"))
        return
    end

    local deletedEntry = api.GetEntry(map, index)
    if deletedEntry and type(api.MarkEntryDeleted) == "function" then
        api.MarkEntryDeleted(classID, specID, deletedEntry, index)
    end

    if deletedEntry and deletedEntry.entryType == "euiVoice" and NS.Integrations and NS.Integrations.EllesmereUI then
        local snapshot = type(NS.SnapshotEntry) == "function" and NS.SnapshotEntry(deletedEntry) or deletedEntry
        local removed, status = NS.Integrations.EllesmereUI:RemoveEntry(snapshot)
        if not removed and status ~= "removed" and status ~= "waiting_combat" and type(NS.QueueEUIRemoval) == "function" then
            NS:QueueEUIRemoval(snapshot)
        end
    end
    map[index] = nil
    RemoveEntryKeyFromAllCollectionScopes(BuildEntryKey(classID, specID, index))
    DeleteMatchingLegacyCastEntries(classID, specID, deletedEntry)
    if type(options.ClearEditorFields) == "function" then
        options:ClearEditorFields()
    end
    api.RebuildRuntimeConfig()
    if type(api.RebuildCastSuccessConfig) == "function" then
        api.RebuildCastSuccessConfig()
    end
    if type(api.RebuildCustomConfig) == "function" then
        api.RebuildCustomConfig()
    end
    HideRuntimeVisualAlerts()
    api.RefreshRuntimeCooldowns()
    if not suppressRefresh then
        if not RequestNativeUIRefresh("list") and type(api.RefreshPanel) == "function" then
            api.RefreshPanel()
        end
    end
    print("[EUIVE] " .. L("MSG_CONFIG_DELETED"))
end
