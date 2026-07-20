local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.ImportFullProcessor = NS.ImportFullProcessor or {}

local Processor = NS.ImportFullProcessor
local CONST = NS.Constants or {}
local CollectionStore = NS.CollectionStore or {}
local ImportExportUtil = NS.ImportExportUtil or {}
local ImportEntryProcessor = NS.ImportEntryProcessor or {}

local ALL_CLASSES_ID = CONST.ALL_CLASSES_ID or 0
local ALL_SPECS_ID = CONST.ALL_SPECS_ID or 0

local function GetApi()
    return NS.API
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

local function EnsureSavedListOrderDB()
    local db = EnsureRootDB()
    if type(db.savedListOrder) ~= "table" then
        db.savedListOrder = {}
    end
    if type(db.savedListOrder.loaded) ~= "table" then
        db.savedListOrder.loaded = {}
    end
    if type(db.savedListOrder.unloaded) ~= "table" then
        db.savedListOrder.unloaded = {}
    end
    return db.savedListOrder
end

local function NormalizeCollectionScope(scope, entryMap, scopeClassID, scopeSpecID)
    if CollectionStore.NormalizeCollectionScope then
        return CollectionStore.NormalizeCollectionScope(scope, entryMap, scopeClassID, scopeSpecID, GetApi())
    end
    return scope
end

local function DeepCopyTable(value, seen)
    if ImportExportUtil and type(ImportExportUtil.DeepCopyTable) == "function" then
        return ImportExportUtil:DeepCopyTable(value, seen)
    end
    return value
end

local function SanitizeEntryForImport(entry)
    if ImportExportUtil and type(ImportExportUtil.SanitizeEntryForImport) == "function" then
        return ImportExportUtil:SanitizeEntryForImport(entry)
    end
    return nil
end

local function ClearDeletedEntryMarker(classID, specID, entry, index)
    local api = GetApi()
    if api and type(api.ClearEntryDeletedMarker) == "function" then
        api.ClearEntryDeletedMarker(classID, specID, entry, index)
    end
end

local function FindMatchingEntryIndexBySpell(map, spellId, entryType, objectType)
    if ImportEntryProcessor and type(ImportEntryProcessor.FindMatchingEntryIndexBySpell) == "function" then
        return ImportEntryProcessor:FindMatchingEntryIndexBySpell(map, spellId, entryType, objectType)
    end
    return nil
end

local function BuildImportedSpecRoot(payload)
    local importedRoot = DeepCopyTable(type(payload.specConfigs) == "table" and payload.specConfigs or {})
    if type(payload.castSuccessConfigs) == "table" then
        local temp = {
            specConfigs = importedRoot,
            castSuccessConfigs = DeepCopyTable(payload.castSuccessConfigs),
        }
        if ImportExportUtil and type(ImportExportUtil.MergeLegacyCastSuccessConfigsIntoSpecConfigs) == "function" then
            ImportExportUtil:MergeLegacyCastSuccessConfigsIntoSpecConfigs(temp, false)
            importedRoot = temp.specConfigs or importedRoot
        end
    end
    return importedRoot
end

local function FindFreeIndex(map, preferredIndex)
    map = type(map) == "table" and map or {}
    preferredIndex = tonumber(preferredIndex) or 0
    if preferredIndex > 0 and type(map[preferredIndex]) ~= "table" then
        return preferredIndex
    end
    for index = 1, 999 do
        if type(map[index]) ~= "table" then
            return index
        end
    end
    return nil
end

local function NormalizeImportedCollections(db, api)
    if type(db.collectionData) ~= "table" then
        db.collectionData = {}
        return
    end
    for classIDKey, classMap in pairs(db.collectionData) do
        local classID = tonumber(classIDKey)
        if classID and classID >= 0 and type(classMap) == "table" then
            for specIDKey, scope in pairs(classMap) do
                local specID = tonumber(specIDKey)
                if specID and specID >= 0 and type(scope) == "table" then
                    if classID == ALL_CLASSES_ID then
                        specID = ALL_SPECS_ID
                    end
                    NormalizeCollectionScope(scope, api.GetStoredEntryMap(classID, specID), classID, specID)
                end
            end
        end
    end
end

function Processor:Import(payload)
    local api = GetApi()
    if not api then
        return false, 0
    end

    payload = type(payload) == "table" and payload or {}
    local db = EnsureRootDB()
    local importedRoot = BuildImportedSpecRoot(payload)
    local importedCount = 0
    local newSpecConfigs = {}

    for classIDKey, classMap in pairs(importedRoot) do
        local classID = tonumber(classIDKey)
        if classID and classID >= 0 and type(classMap) == "table" then
            if type(newSpecConfigs[classID]) ~= "table" then
                newSpecConfigs[classID] = {}
            end
            for specIDKey, importedMap in pairs(classMap) do
                local specID = tonumber(specIDKey)
                if specID and specID >= 0 and type(importedMap) == "table" then
                    if classID == ALL_CLASSES_ID then
                        specID = ALL_SPECS_ID
                    end
                    local newMap = newSpecConfigs[classID][specID]
                    if type(newMap) ~= "table" then
                        newMap = {}
                        newSpecConfigs[classID][specID] = newMap
                    end

                    local importedIndices = {}
                    for index, entry in pairs(importedMap) do
                        index = tonumber(index) or 0
                        if index > 0 and type(entry) == "table" then
                            local spellId = tonumber(entry.spellId) or 0
                            if spellId > 0 then
                                importedIndices[#importedIndices + 1] = index
                            end
                        end
                    end
                    table.sort(importedIndices)

                    for _, index in ipairs(importedIndices) do
                        local sanitized = SanitizeEntryForImport(importedMap[index])
                        if sanitized then
                            local targetIndex = FindFreeIndex(newMap, index)
                            if targetIndex and targetIndex > 0 then
                                ClearDeletedEntryMarker(classID, specID, sanitized, targetIndex)
                                newMap[targetIndex] = sanitized
                                importedCount = importedCount + 1
                            end
                        end
                    end
                end
            end
        end
    end

    db.specConfigs = newSpecConfigs
    db.castSuccessConfigs = {}
    db.deletedEntries = {}

    db.collectionData = {}
    if type(payload.collectionData) == "table" then
        for classIDKey, classMap in pairs(payload.collectionData) do
            local classID = tonumber(classIDKey)
            if classID and classID >= 0 and type(classMap) == "table" then
                if type(db.collectionData[classID]) ~= "table" then
                    db.collectionData[classID] = {}
                end
                for specIDKey, scope in pairs(classMap) do
                    local specID = tonumber(specIDKey)
                    if specID and specID >= 0 and type(scope) == "table" then
                        if classID == ALL_CLASSES_ID then
                            specID = ALL_SPECS_ID
                        end
                        db.collectionData[classID][specID] = DeepCopyTable(scope)
                    end
                end
            end
        end
    end
    NormalizeImportedCollections(db, api)

    if type(payload.savedListOrder) == "table" then
        db.savedListOrder = DeepCopyTable(payload.savedListOrder)
    else
        db.savedListOrder = { loaded = {}, unloaded = {} }
    end
    EnsureSavedListOrderDB()

    if type(payload.bloodlustConfig) == "table" then
        db.bloodlustConfig = DeepCopyTable(payload.bloodlustConfig)
    end
    if type(payload.minimap) == "table" then
        db.minimap = DeepCopyTable(payload.minimap)
    end
    if type(payload.languageMode) == "string" then
        db.languageMode = payload.languageMode
        if type(NS.SetLanguageMode) == "function" then
            NS.SetLanguageMode(db.languageMode)
        end
    end
    if type(payload.uiSkinMode) == "string" then
        db.uiSkinMode = payload.uiSkinMode
    end

    db.collectionSerial = math.max(tonumber(payload.collectionSerial) or 0, 0)
    return true, importedCount
end
