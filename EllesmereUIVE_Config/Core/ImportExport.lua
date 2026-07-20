local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.ImportExport = NS.ImportExport or {}
NS.AceOptions = NS.AceOptions or {}
local ImportExport = NS.ImportExport
local L = NS.L or function(key, ...) return select("#", ...) > 0 and string.format(tostring(key), ...) or tostring(key) end

local function Codec()
    return NS.Core and NS.Core.ImportExport
end

local function ParseEntryKey(key)
    local classID, specID, index = tostring(key or ""):match("^(%-?%d+):(%-?%d+):(%d+)$")
    return tonumber(classID), tonumber(specID), tonumber(index)
end

local function ParseGroupKey(key)
    local classID, specID, groupID = tostring(key or ""):match("^group:(%-?%d+):(%-?%d+):(.+)$")
    return tonumber(classID), tonumber(specID), groupID
end

function ImportExport:ExportFullString()
    local codec = Codec()
    if not codec then return "" end
    local text, err = codec:Encode(codec:BuildPayload())
    if not text then NS:Print(L("EXPORT_FAILED", err or "unknown")); return "" end
    return text
end

function ImportExport:ExportEntryString(entryKey)
    local classID, specID, index = ParseEntryKey(entryKey)
    local entry = classID and NS:GetScopeList(classID, specID, false)[index] or nil
    local codec = Codec()
    if not entry or not codec then return "" end
    local payload, err = codec:BuildEntryPayload(entry)
    local text
    if payload then text, err = codec:Encode(payload) end
    if not text then NS:Print(L("EXPORT_FAILED", err or "unknown")); return "" end
    return text
end

function ImportExport:ExportCollectionString(groupKey)
    local classID, specID, groupID = ParseGroupKey(groupKey)
    local codec = Codec()
    if classID == nil or not groupID or not codec then return "" end
    local payload, err = codec:BuildCollectionPayload(classID, specID, groupID)
    local text
    if payload then text, err = codec:Encode(payload) end
    if not text then NS:Print(L("EXPORT_FAILED", err or "unknown")); return "" end
    return text
end

function ImportExport:ImportString(text)
    local codec = Codec()
    if not codec then return false end
    local ok, count, status = codec:ImportText(text)
    if not ok then NS:Print(L("MSG_IMPORT_FAILED", count or status or "unknown")); return false end
    if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.RequestRefresh) == "function" then
        NS.UI.MainFrame:RequestRefresh("list")
    end
    NS:Print(L("MSG_IMPORT_DONE", status or "saved_waiting_sync", tonumber(count) or 0))
    return true
end

function NS.AceOptions:ExportEntryString(entryKey) return ImportExport:ExportEntryString(entryKey) end
function NS.AceOptions:ExportCollectionString(groupKey) return ImportExport:ExportCollectionString(groupKey) end
function NS.AceOptions:ExportFullString() return ImportExport:ExportFullString() end
function NS.AceOptions:ImportString(text) return ImportExport:ImportString(text) end
