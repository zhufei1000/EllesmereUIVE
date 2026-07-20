local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.ExportBuilder = NS.ExportBuilder or {}

local Builder = NS.ExportBuilder
local L = NS.L or function(key, ...)
    if select("#", ...) > 0 then
        return string.format(tostring(key), ...)
    end
    return tostring(key)
end
local Utils = NS.Utils or {}
local CollectionStore = NS.CollectionStore or {}
local ImportCodec = NS.ImportCodec or {}
local ImportExportUtil = NS.ImportExportUtil or {}
local ImportEntryProcessor = NS.ImportEntryProcessor or {}

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

local function GetApi()
    return NS.API
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

local function IsSameScopeGroupRef(scopeClassID, scopeSpecID, ref)
    if CollectionStore.IsSameScopeGroupRef then
        return CollectionStore.IsSameScopeGroupRef(scopeClassID, scopeSpecID, ref)
    end
    return nil
end

local function EntryRefToKey(scopeClassID, scopeSpecID, ref)
    if CollectionStore.EntryRefToKey then
        return CollectionStore.EntryRefToKey(scopeClassID, scopeSpecID, ref)
    end
    return nil
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

local function MigrateLegacyCastSuccessConfigs(db)
    if ImportExportUtil and type(ImportExportUtil.MergeLegacyCastSuccessConfigsIntoSpecConfigs) == "function" then
        return ImportExportUtil:MergeLegacyCastSuccessConfigsIntoSpecConfigs(db, false)
    end
    return 0
end

local function EncodeExportPayload(payload)
    if ImportCodec and type(ImportCodec.Encode) == "function" then
        return ImportCodec:Encode(payload)
    end
    print("[EUIVE] " .. L("MSG_EXPORT_MISSING_LIBS"))
    return ""
end

local function BuildEntryExportRecord(classID, specID, index)
    if ImportEntryProcessor and type(ImportEntryProcessor.BuildEntryExportRecord) == "function" then
        return ImportEntryProcessor:BuildEntryExportRecord(classID, specID, index)
    end
    return nil
end

function Builder:ExportEntryString(entryKey)
    local classID, specID, index = ParseEntryKey(entryKey)
    local record = BuildEntryExportRecord(classID, specID, index)
    if not record then
        print("[EUIVE] " .. L("MSG_EXPORT_ENTRY_NOT_FOUND"))
        return ""
    end
    return EncodeExportPayload({ type = "entry", entries = { record } })
end

function Builder:ExportCollectionString(groupKey)
    local classID, specID, groupID = ParseGroupKey(groupKey)
    if classID < 0 or specID < 0 or tostring(groupID or "") == "" then
        print("[EUIVE] " .. L("MSG_EXPORT_COLLECTION_INVALID"))
        return ""
    end
    local scope = EnsureCollectionScope(classID, specID)
    local api = GetApi()
    if not scope or not api or type(scope.groups[groupID]) ~= "table" then
        print("[EUIVE] " .. L("MSG_EXPORT_COLLECTION_NOT_FOUND"))
        return ""
    end
    NormalizeCollectionScope(scope, api.GetStoredEntryMap(classID, specID), classID, specID)

    local entries = {}
    local exportedEntryKeys = {}
    local groups = {}

    local function collectGroup(gid, seen)
        gid = tostring(gid or "")
        local group = scope.groups[gid]
        if gid == "" or type(group) ~= "table" then
            return
        end
        seen = seen or {}
        if seen[gid] then
            return
        end
        seen[gid] = true

        local groupCopy = {
            name = TrimText(group.name) ~= "" and TrimText(group.name) or L("COLLECTION_UNNAMED"),
            iconID = NormalizeIconID(group.iconID),
            collapsed = group.collapsed == true,
            entries = DeepCopyTable(group.entries or {}),
        }
        groups[gid] = groupCopy

        for _, ref in ipairs(group.entries or {}) do
            local _, childGroupID = IsSameScopeGroupRef(classID, specID, ref)
            if childGroupID and type(scope.groups[childGroupID]) == "table" then
                collectGroup(childGroupID, seen)
            else
                local key, rowClassID, rowSpecID, rowIndex = EntryRefToKey(classID, specID, ref)
                if key and not exportedEntryKeys[key] then
                    local record = BuildEntryExportRecord(rowClassID, rowSpecID, rowIndex)
                    if record then
                        record.originalKey = key
                        entries[#entries + 1] = record
                        exportedEntryKeys[key] = true
                    end
                end
            end
        end
    end

    collectGroup(groupID, {})

    local rootGroup = groups[groupID] or {
        name = L("COLLECTION_UNNAMED"),
        entries = {},
    }

    return EncodeExportPayload({
        type = "collection",
        classID = classID,
        specID = specID,
        rootGroupID = groupID,
        group = rootGroup,
        groups = groups,
        entries = entries,
    })
end

function Builder:ExportFullString()
    local db = EnsureRootDB()
    MigrateLegacyCastSuccessConfigs(db)

    local specConfigs = {}
    for classID, classMap in pairs(db.specConfigs or {}) do
        if type(classMap) == "table" then
            specConfigs[classID] = {}
            for specID, entryMap in pairs(classMap) do
                if type(entryMap) == "table" then
                    specConfigs[classID][specID] = {}
                    for index, entry in pairs(entryMap) do
                        if type(entry) == "table" then
                            specConfigs[classID][specID][index] = SanitizeEntryForImport(entry) or DeepCopyTable(entry)
                        else
                            specConfigs[classID][specID][index] = DeepCopyTable(entry)
                        end
                    end
                else
                    specConfigs[classID][specID] = DeepCopyTable(entryMap)
                end
            end
        else
            specConfigs[classID] = DeepCopyTable(classMap)
        end
    end

    return EncodeExportPayload({
        type = "full",
        specConfigs = specConfigs,
        collectionData = DeepCopyTable(db.collectionData or {}),
        collectionSerial = tonumber(db.collectionSerial) or 0,
        savedListOrder = DeepCopyTable(db.savedListOrder or {}),
        bloodlustConfig = DeepCopyTable(db.bloodlustConfig or {}),
        minimap = DeepCopyTable(db.minimap or {}),
        languageMode = tostring(db.languageMode or "auto"),
        uiSkinMode = tostring(db.uiSkinMode or "auto"),
    })
end
