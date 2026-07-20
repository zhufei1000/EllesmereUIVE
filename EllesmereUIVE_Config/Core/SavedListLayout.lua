local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.SavedListLayout = NS.SavedListLayout or {}
local SavedListLayout = NS.SavedListLayout

local L = NS.L or function(key, ...) if select("#", ...) > 0 then return string.format(tostring(key), ...) end return tostring(key) end
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
local DEFAULT_COLLECTION_ICON = CONST.DEFAULT_COLLECTION_ICON or "Interface\\Icons\\INV_Misc_Note_01"

local ENTRY_ROW_CACHE = {}

local function CopyTableShallow(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function TrimText(value)
    if Utils.TrimText then
        return Utils.TrimText(value)
    end
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function NormalizeIconID(value)
    if Utils.NormalizeIconID then
        return Utils.NormalizeIconID(value)
    end
    local iconID = tonumber(TrimText(value))
    if iconID and iconID > 0 then
        return math.floor(iconID)
    end
    return nil
end

local function GetFileNameFromPath(value)
    if Utils.GetFileNameFromPath then
        return Utils.GetFileNameFromPath(value)
    end
    local path = tostring(value or ""):gsub("/", "\\")
    return path:match("([^\\]+)$") or path
end

local function GetApi()
    return NS.API
end

local function NormalizeItemLoadMode(value)
    value = tostring(value or ITEM_LOAD_NONE):lower()
    if value == ITEM_LOAD_EQUIPPED or value == ITEM_LOAD_BAGS then
        return value
    end
    return ITEM_LOAD_NONE
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

local function NumberBoolMapSignature(source)
    local keys = {}
    for key, value in pairs(CopyNumberBoolMap(source)) do
        if value == true then
            keys[#keys + 1] = tonumber(key) or 0
        end
    end
    table.sort(keys)
    if #keys == 0 then
        return ""
    end
    return table.concat(keys, ",")
end

local function NumberBoolMapMatchesCurrent(source, currentID, allID)
    local map = CopyNumberBoolMap(source)
    if next(map) == nil then
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

local function IsEntryLoadedForActiveScope(api, entry, rowClassID, rowSpecID, currentClassID, currentSpecID)
    if not IsLoadedScope(api, rowClassID, rowSpecID, currentClassID, currentSpecID) then
        return false
    end
    if type(entry) ~= "table" then
        return false
    end
    local classIDs = entry.alertClassIDs or entry.customClassIDs
    local specIDs = entry.alertSpecIDs or entry.customSpecIDs
    local raceIDs = entry.alertRaceIDs
    if not NumberBoolMapMatchesCurrent(raceIDs, GetCurrentRaceID(), ALL_RACES_ID)
        or not NumberBoolMapMatchesCurrent(classIDs, currentClassID, ALL_CLASSES_ID)
        or not NumberBoolMapMatchesCurrent(specIDs, currentSpecID, ALL_SPECS_ID) then
        return false
    end
    local objectType = tostring(entry.objectType or OBJECT_TYPE_SPELL):lower()
    if objectType == OBJECT_TYPE_ITEM and api and type(api.IsItemLoadRequirementMet) == "function" then
        return api.IsItemLoadRequirementMet(entry) ~= false
    end
    return true
end

local function BuildEntryKey(classID, specID, index)
    return CollectionStore.BuildEntryKey(classID, specID, index)
end

local function BuildGroupKey(classID, specID, groupID)
    return CollectionStore.BuildGroupKey(classID, specID, groupID)
end

local function EntryRefToKey(scopeClassID, scopeSpecID, ref)
    return CollectionStore.EntryRefToKey(scopeClassID, scopeSpecID, ref)
end

local function EnsureCollectionScope(classID, specID)
    return CollectionStore.EnsureCollectionScope(classID, specID)
end

local function NormalizeCollectionScope(scope, entryMap, scopeClassID, scopeSpecID)
    return CollectionStore.NormalizeCollectionScope(scope, entryMap, scopeClassID, scopeSpecID, GetApi())
end

local function IsSameScopeGroupRef(scopeClassID, scopeSpecID, ref)
    return CollectionStore.IsSameScopeGroupRef(scopeClassID, scopeSpecID, ref)
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

local function BuildSoundDetailForEntry(entry, modeTts, modeSound)
    if type(entry) ~= "table" then
        return ""
    end

    local ace = NS.AceOptions or {}
    local fields = type(ace.ResolveSoundSourceFields) == "function" and ace:ResolveSoundSourceFields(entry, modeTts, modeSound) or {}
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

    local normalizedPath = type(ace.NormalizeSoundPath) == "function" and ace:NormalizeSoundPath(fields.soundPath or entry.soundPath or "") or tostring(fields.soundPath or entry.soundPath or "")
    if fields.soundSource == "builtin" or (normalizedPath ~= "" and type(ace.IsBuiltinSoundPath) == "function" and ace:IsBuiltinSoundPath(normalizedPath)) then
        local displayName = type(ace.GetBuiltinSoundDisplayName) == "function" and ace:GetBuiltinSoundDisplayName(normalizedPath) or GetFileNameFromPath(normalizedPath)
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

local function GetEUIStatus(entry)
    if type(entry) ~= "table" or tostring(entry.entryType or "") ~= "euiVoice" then return nil, nil end
    if tostring(entry.injectionStatus or "") == "batch_complete" and type(entry.injectionStats) == "table" then
        local stats = entry.injectionStats
        local targetCount = math.max(0, tonumber(stats.targetCount) or 0)
        local synced = math.max(0, (tonumber(stats.injected) or 0) + (tonumber(stats.upToDate) or 0))
        local parts = { L("BATCH_SYNCED", synced, targetCount) }
        if (tonumber(stats.conflict) or 0) > 0 then parts[#parts + 1] = L("BATCH_CONFLICT", stats.conflict) end
        if (tonumber(stats.waiting) or 0) > 0 then parts[#parts + 1] = L("BATCH_WAITING", stats.waiting) end
        return "batch_complete", table.concat(parts, " · ")
    end
    local integration = NS.Integrations and NS.Integrations.EllesmereUI
    local status = integration and type(integration.GetInjectionStatus) == "function"
        and integration:GetInjectionStatus(entry) or "saved_waiting_sync"
    return tostring(status or "saved_waiting_sync"), L("STATUS_" .. tostring(status or "saved_waiting_sync"))
end

local function GetEUITriggerText(entry)
    local trigger = tostring(entry and entry.euiTriggerType or "cdReady")
    if trigger == "buffGain" then return L("TRIGGER_GAIN") end
    if trigger == "buffLoss" then return L("TRIGGER_LOSS") end
    return L("TRIGGER_CD")
end

function SavedListLayout:GetSavedListLayoutForScope(owner, classID, specID, includeScopeText)
    local api = GetApi()
    if not api then
        return {}
    end
    classID = tonumber(classID) or 0
    specID = tonumber(specID) or 0
    if classID < 0 or specID < 0 then
        return {}
    end

    local storedEntryMapCache = {}
    local loadedScopeCache = {}
    local classNameCache = {}
    local specNameCache = {}

    local function getStoredEntryMap(rowClassID, rowSpecID)
        rowClassID = tonumber(rowClassID) or 0
        rowSpecID = tonumber(rowSpecID) or 0
        local cacheKey = rowClassID .. ":" .. rowSpecID
        if storedEntryMapCache[cacheKey] then
            return storedEntryMapCache[cacheKey]
        end
        local map = api.GetStoredEntryMap(rowClassID, rowSpecID)
        storedEntryMapCache[cacheKey] = map
        return map
    end

    local specMap = getStoredEntryMap(classID, specID)
    local scope = EnsureCollectionScope(classID, specID)
    NormalizeCollectionScope(scope, specMap, classID, specID)

    local modeTts, modeSound = api.GetModes()
    local currentClassID, currentSpecID = api.GetCurrentClassSpec()

    local function isLoadedScopeCached(rowClassID, rowSpecID)
        rowClassID = tonumber(rowClassID) or 0
        rowSpecID = tonumber(rowSpecID) or 0
        local cacheKey = rowClassID .. ":" .. rowSpecID
        if loadedScopeCache[cacheKey] ~= nil then
            return loadedScopeCache[cacheKey]
        end
        local loaded = IsLoadedScope(api, rowClassID, rowSpecID, currentClassID, currentSpecID)
        loadedScopeCache[cacheKey] = loaded
        return loaded
    end

    local function resolveClassNameCached(rowClassID)
        rowClassID = tonumber(rowClassID) or 0
        if classNameCache[rowClassID] == nil then
            classNameCache[rowClassID] = api.ResolveClassName(rowClassID)
        end
        return classNameCache[rowClassID]
    end

    local function resolveSpecNameCached(rowClassID, rowSpecID)
        rowClassID = tonumber(rowClassID) or 0
        rowSpecID = tonumber(rowSpecID) or 0
        local cacheKey = rowClassID .. ":" .. rowSpecID
        if specNameCache[cacheKey] == nil then
            specNameCache[cacheKey] = api.ResolveSpecName(rowClassID, rowSpecID)
        end
        return specNameCache[cacheKey]
    end

    local function collectSelectedIDs(source, allID, fallbackID)
        local map = CopyNumberBoolMap(source)
        if next(map) == nil then
            map[tonumber(fallbackID) or allID] = true
        end
        if map[allID] == true then
            return { allID }
        end
        local ids = {}
        for id, enabled in pairs(map) do
            id = tonumber(id) or allID
            if enabled == true and id > allID then
                ids[#ids + 1] = id
            end
        end
        table.sort(ids)
        return ids
    end

    local function buildEntryScopeText(entry, rowClassID, rowSpecID, loadedTag)
        local classIDs = collectSelectedIDs(entry.alertClassIDs or entry.customClassIDs, ALL_CLASSES_ID, rowClassID)
        local specIDs = collectSelectedIDs(entry.alertSpecIDs or entry.customSpecIDs, ALL_SPECS_ID, rowSpecID)

        local classText
        if classIDs[1] == ALL_CLASSES_ID then
            classText = resolveClassNameCached(ALL_CLASSES_ID)
        elseif #classIDs > 3 then
            classText = L("SCOPE_CLASS_COUNT", #classIDs)
        else
            local names = {}
            for _, classID in ipairs(classIDs) do
                names[#names + 1] = resolveClassNameCached(classID)
            end
            classText = table.concat(names, "/")
        end

        local specText
        if specIDs[1] == ALL_SPECS_ID then
            specText = L("SCOPE_ALL_SPECS")
        elseif #specIDs > 3 or #classIDs ~= 1 or classIDs[1] == ALL_CLASSES_ID then
            specText = L("SCOPE_SPEC_COUNT", #specIDs)
        else
            local names = {}
            for _, specID in ipairs(specIDs) do
                names[#names + 1] = resolveSpecNameCached(classIDs[1], specID)
            end
            specText = table.concat(names, "/")
        end

        return string.format("%s / %s%s", classText, specText, loadedTag)
    end

    local function buildEntryRow(rowClassID, rowSpecID, rowIndex, depth, parentGroupID, parentGroupKey)
        rowClassID = tonumber(rowClassID) or 0
        rowSpecID = tonumber(rowSpecID) or 0
        rowIndex = tonumber(rowIndex) or 0
        if rowClassID < 0 or rowSpecID < 0 or rowIndex <= 0 then
            return nil
        end

        local map = getStoredEntryMap(rowClassID, rowSpecID)
        local entry = api.GetEntry(map, rowIndex)
        if not entry then
            return nil
        end

        local entryKey = BuildEntryKey(rowClassID, rowSpecID, rowIndex)
        local spellId = tonumber(entry.spellId) or 0
        local objectTypeRaw = tostring(entry.objectType or OBJECT_TYPE_SPELL):lower()
        local cacheKey = table.concat({ entryKey, includeScopeText and "scope" or "plain", tostring(currentClassID or 0), tostring(currentSpecID or 0), tostring(GetCurrentRaceID()) }, ":")
        local signature = table.concat({
            tostring(spellId),
            objectTypeRaw,
            tostring(NormalizeItemLoadMode(entry.itemLoadMode)),
            tostring(entry.itemLoadSameName == true),
            (objectTypeRaw == OBJECT_TYPE_ITEM and api and type(api.IsItemLoadRequirementMet) == "function") and tostring(api.IsItemLoadRequirementMet(entry) ~= false) or "",
            TrimText(entry.spellName),
            tostring(entry.entryType or "cooldown"),
            tostring(entry.euiTriggerType or ""),
            tostring(select(1, GetEUIStatus(entry)) or ""),
            tostring(type(entry.injectionStats) == "table" and entry.injectionStats.targetCount or ""),
            tostring(type(entry.injectionStats) == "table" and entry.injectionStats.injected or ""),
            tostring(type(entry.injectionStats) == "table" and entry.injectionStats.upToDate or ""),
            tostring(type(entry.injectionStats) == "table" and entry.injectionStats.waiting or ""),
            tostring(type(entry.injectionStats) == "table" and entry.injectionStats.conflict or ""),
            tostring(entry.notifyMode or modeSound),
            tostring(entry.soundSource or ""),
            tostring(entry.soundPath or ""),
            tostring(entry.builtinSoundPath or ""),
            tostring(entry.customSoundPath or ""),
            tostring(entry.sharedMediaSound or ""),
            tostring(entry.sharedMediaKey or ""),
            tostring(entry.ttsText or ""),
            tostring(entry.voiceEnabled ~= false),
            tostring(entry.imageEnabled == true),
            tostring(entry.textEnabled == true),
            tostring(entry.voiceConditionOp or ""),
            tostring(tonumber(entry.voiceConditionTime) or 0),
            tostring(entry.imageConditionOp or ""),
            tostring(tonumber(entry.imageConditionTime) or 0),
            tostring(entry.textConditionOp or ""),
            tostring(tonumber(entry.textConditionTime) or 0),
            tostring(entry.imageSource or ""),
            tostring(tonumber(entry.imageIconID) or 0),
            tostring(entry.imagePath or ""),
            tostring(tonumber(entry.imageSize) or 0),
            tostring(entry.imageDurationEnabled == true),
            tostring(tonumber(entry.imageDuration) or 0),
            tostring(entry.textAlert or ""),
            tostring(tonumber(entry.textSize) or 0),
            tostring(entry.textDurationEnabled == true),
            tostring(tonumber(entry.textDuration) or 0),
            tostring(entry.textAttachMode or ""),
            tostring(entry.textVAlign or ""),
            tostring(entry.textHAlign or ""),
            tostring(tonumber(entry.textOffsetX) or 0),
            tostring(tonumber(entry.textOffsetY) or 0),
            tostring(entry.delayEnabled == true),
            tostring(tonumber(entry.delaySeconds) or 0),
            tostring(entry.checkTalent == true),
            tostring(tonumber(entry.talentId) or 0),
            TrimText(entry.talentName or ""),
            tostring(tonumber(entry.talentCD) or 0),
            NumberBoolMapSignature(entry.alertRaceIDs),
            NumberBoolMapSignature(entry.alertClassIDs or entry.customClassIDs),
            NumberBoolMapSignature(entry.alertSpecIDs or entry.customSpecIDs),
        }, "|")

        local cached = ENTRY_ROW_CACHE[cacheKey]
        if type(cached) == "table" and cached.signature == signature and type(cached.row) == "table" then
            local row = CopyTableShallow(cached.row)
            row.depth = tonumber(depth) or 0
            row.groupID = parentGroupID
            row.groupKey = parentGroupKey
            row.parentGroupKey = parentGroupKey
            return row
        end

        local entryType = tostring(entry.entryType or "euiVoice")
        local objectType = type(api.ResolveObjectType) == "function" and api.ResolveObjectType(spellId, entry.objectType) or objectTypeRaw
        local spellName = TrimText(entry.spellName)
        local icon = nil
        if entryType == "custom" then
            objectType = OBJECT_TYPE_SPELL
            spellName = TrimText(entry.customName or entry.spellName)
            if spellName == "" then spellName = L("ENTRY_TYPE_CUSTOM") end
            icon = (tonumber(entry.imageIconID) or 0) > 0 and math.floor(tonumber(entry.imageIconID) or 0) or nil
        elseif spellName == "" and spellId > 0 then
            spellName = type(api.ResolveObjectName) == "function" and api.ResolveObjectName(spellId, objectType) or api.ResolveSpellName(spellId)
        end
        if not icon then
            icon = type(api.ResolveObjectIcon) == "function" and api.ResolveObjectIcon(spellId, objectType) or (type(api.ResolveSpellIcon) == "function" and api.ResolveSpellIcon(spellId) or nil)
        end

        local isLoaded = IsEntryLoadedForActiveScope(api, entry, rowClassID, rowSpecID, currentClassID, currentSpecID)
        local loadedTag = isLoaded and L("LOADED_TAG") or L("UNLOADED_TAG")

        local euiStatus, euiStatusText = GetEUIStatus(entry)
        local row = {
            itemType = "entry",
            key = entryKey,
            entryType = entryType,
            objectType = objectType,
            itemLoadMode = (objectType == OBJECT_TYPE_ITEM) and NormalizeItemLoadMode(entry.itemLoadMode) or ITEM_LOAD_NONE,
            itemLoadSameName = objectType == OBJECT_TYPE_ITEM and NormalizeItemLoadMode(entry.itemLoadMode) == ITEM_LOAD_BAGS and entry.itemLoadSameName == true,
            alertRaceIDs = entry.alertRaceIDs,
            alertClassIDs = entry.alertClassIDs or entry.customClassIDs,
            alertSpecIDs = entry.alertSpecIDs or entry.customSpecIDs,
            classID = rowClassID,
            specID = rowSpecID,
            index = rowIndex,
            spellId = spellId,
            spellName = spellName ~= "" and spellName or tostring(spellId),
            modeText = entryType == "euiVoice" and GetEUITriggerText(entry) or BuildAlertActionDetailForEntry(entry, modeTts, modeSound),
            soundDetail = BuildSoundDetailForEntry(entry, modeTts, modeSound),
            notifyMode = tostring(entry.notifyMode or modeSound),
            soundPath = tostring(entry.soundPath or ""),
            ttsText = tostring(entry.ttsText or ""),
            delayEnabled = entry.delayEnabled == true,
            delaySeconds = math.max(0, tonumber(entry.delaySeconds) or 0),
            checkTalent = entry.checkTalent == true and (tonumber(entry.talentId) or 0) > 0,
            talentId = tonumber(entry.talentId) or 0,
            talentName = TrimText(entry.talentName or ""),
            talentCD = tonumber(entry.talentCD) or 0,
            icon = icon,
            scopeText = includeScopeText and buildEntryScopeText(entry, rowClassID, rowSpecID, loadedTag) or "",
            isLoaded = isLoaded,
            enabledText = (entry.enabled ~= false and entry.voiceEnabled ~= false) and L("ENABLED") or L("DISABLED"),
            euiStatus = euiStatus,
            euiStatusText = euiStatusText,
        }
        ENTRY_ROW_CACHE[cacheKey] = { signature = signature, row = row }

        local result = CopyTableShallow(row)
        result.depth = tonumber(depth) or 0
        result.groupID = parentGroupID
        result.groupKey = parentGroupKey
        result.parentGroupKey = parentGroupKey
        return result
    end

    local rows = {}
    local entriesByIndex = {}
    local indices = type(api.GetOrderedEntryIndices) == "function" and api.GetOrderedEntryIndices(specMap) or {}
    for _, index in ipairs(indices) do
        entriesByIndex[tonumber(index) or 0] = buildEntryRow(classID, specID, index, 0)
    end

    local collapsedCountCache = {}

    local function appendGroup(groupID, depth, parentGroupID, parentGroupKey, stack)
        groupID = tostring(groupID or "")
        local group = scope.groups[groupID]
        if groupID == "" or type(group) ~= "table" then
            return 0, 0, 0
        end

        stack = stack or {}
        if stack[groupID] then
            return 0, 0, 0
        end
        stack[groupID] = true

        local groupKey = BuildGroupKey(classID, specID, groupID)
        local groupRowIndex = #rows + 1
        rows[groupRowIndex] = {
            itemType = "group",
            key = groupKey,
            groupKey = groupKey,
            groupID = groupID,
            parentGroupID = parentGroupID,
            parentGroupKey = parentGroupKey,
            classID = classID,
            specID = specID,
            name = TrimText(group.name) ~= "" and TrimText(group.name) or L("COLLECTION_UNNAMED"),
            count = 0,
            icon = NormalizeIconID(group.iconID) or DEFAULT_COLLECTION_ICON,
            scopeText = "",
            isLoaded = true,
            depth = tonumber(depth) or 0,
            collapsed = group.collapsed == true,
            loadState = "green",
        }

        local totalCount, loadedCount, unloadedCount = 0, 0, 0

        if not (group.collapsed == true) then
            for _, ref in ipairs(group.entries or {}) do
                local childGroupKey, childGroupID = IsSameScopeGroupRef(classID, specID, ref)
                if childGroupKey and childGroupID and type(scope.groups[childGroupID]) == "table" then
                    local childTotal, childLoaded, childUnloaded = appendGroup(childGroupID, (tonumber(depth) or 0) + 1, groupID, groupKey, stack)
                    totalCount = totalCount + childTotal
                    loadedCount = loadedCount + childLoaded
                    unloadedCount = unloadedCount + childUnloaded
                else
                    local entryKey, rowClassID, rowSpecID, rowIndex = EntryRefToKey(classID, specID, ref)
                    local entryRow = entryKey and buildEntryRow(rowClassID, rowSpecID, rowIndex, (tonumber(depth) or 0) + 1, groupID, groupKey) or nil
                    if entryRow then
                        rows[#rows + 1] = entryRow
                        totalCount = totalCount + 1
                        if entryRow.isLoaded == false then
                            unloadedCount = unloadedCount + 1
                        else
                            loadedCount = loadedCount + 1
                        end
                    end
                end
            end
        else
            -- 折叠时仍然计算合集载入状态，但不输出子行。
            local function countCollapsed(gid, seen)
                gid = tostring(gid or "")
                local g = scope.groups[gid]
                if gid == "" or type(g) ~= "table" then
                    return 0, 0, 0
                end
                seen = seen or {}
                if seen[gid] then
                    return 0, 0, 0
                end
                local cached = collapsedCountCache[gid]
                if type(cached) == "table" then
                    return cached[1] or 0, cached[2] or 0, cached[3] or 0
                end
                seen[gid] = true
                local total, loaded, unloaded = 0, 0, 0
                for _, ref in ipairs(g.entries or {}) do
                    local _, childGroupID = IsSameScopeGroupRef(classID, specID, ref)
                    if childGroupID and type(scope.groups[childGroupID]) == "table" then
                        local ct, cl, cu = countCollapsed(childGroupID, seen)
                        total = total + ct
                        loaded = loaded + cl
                        unloaded = unloaded + cu
                    else
                        local entryKey, rowClassID, rowSpecID, rowIndex = EntryRefToKey(classID, specID, ref)
                        if entryKey and rowIndex and rowIndex > 0 then
                            local rowMap = getStoredEntryMap(rowClassID, rowSpecID)
                            local rowEntry = api.GetEntry(rowMap, rowIndex)
                            if rowEntry then
                                total = total + 1
                                if IsEntryLoadedForActiveScope(api, rowEntry, rowClassID, rowSpecID, currentClassID, currentSpecID) then
                                    loaded = loaded + 1
                                else
                                    unloaded = unloaded + 1
                                end
                            end
                        end
                    end
                end
                seen[gid] = nil
                collapsedCountCache[gid] = { total, loaded, unloaded }
                return total, loaded, unloaded
            end
            totalCount, loadedCount, unloadedCount = countCollapsed(groupID, {})
        end

        local groupRow = rows[groupRowIndex]
        groupRow.count = totalCount
        groupRow.loadedCount = loadedCount
        groupRow.unloadedCount = unloadedCount
        if totalCount <= 0 then
            groupRow.loadState = "green"
            groupRow.isLoaded = true
        elseif loadedCount > 0 and unloadedCount > 0 then
            groupRow.loadState = "yellow"
            groupRow.isLoaded = true
        elseif loadedCount > 0 then
            groupRow.loadState = "green"
            groupRow.isLoaded = true
        else
            groupRow.loadState = "red"
            groupRow.isLoaded = false
        end

        stack[groupID] = nil
        return totalCount, loadedCount, unloadedCount
    end

    for _, item in ipairs(scope.root or {}) do
        if type(item) == "table" and item.type == "group" then
            appendGroup(tostring(item.id or ""), 0, nil, nil, {})
        elseif type(item) == "table" and item.type == "entry" then
            local entryRow = entriesByIndex[tonumber(item.index) or 0]
            if entryRow then
                rows[#rows + 1] = entryRow
            end
        end
    end

    return rows
end
