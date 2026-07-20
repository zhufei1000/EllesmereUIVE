local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.ImportCodec = NS.ImportCodec or {}
local ImportCodec = NS.ImportCodec

local LibStubGlobal = rawget(_G, "LibStub")
local L = NS.L or function(key, ...)
    if select("#", ...) > 0 then
        return string.format(tostring(key), ...)
    end
    return tostring(key)
end

local EXPORT_PREFIX = "!QFXSA:1!"
local LEGACY_EXPORT_PREFIX = "!MCDVCA:1!"
local ADDON_ID = "EllesmereUIVE"
local LEGACY_ADDON_ID = "MCDVoiceCooldown"

local function GetAceSerializer()
    if type(LibStubGlobal) == "table" and LibStubGlobal.GetLibrary then
        return LibStubGlobal:GetLibrary("AceSerializer-3.0", true)
    end
    return nil
end

local function GetLibDeflate()
    if type(LibStubGlobal) == "table" and LibStubGlobal.GetLibrary then
        return LibStubGlobal:GetLibrary("LibDeflate", true)
    end
    return nil
end

function ImportCodec:GetPrefix()
    return EXPORT_PREFIX
end

function ImportCodec:Encode(payload)
    local serializer = GetAceSerializer()
    local deflate = GetLibDeflate()
    if not serializer or not deflate then
        print("[EUIVE] " .. L("MSG_EXPORT_MISSING_LIBS"))
        return ""
    end

    payload = payload or {}
    payload.addon = ADDON_ID
    payload.format = 1

    local serialized = serializer:Serialize(payload)
    local compressed = deflate:CompressDeflate(serialized, { level = 9 })
    if type(compressed) ~= "string" then
        print("[EUIVE] " .. L("MSG_EXPORT_DEFLATE_FAILED"))
        return ""
    end

    return EXPORT_PREFIX .. deflate:EncodeForPrint(compressed)
end

function ImportCodec:Decode(text)
    text = tostring(text or ""):gsub("%s+", "")
    if text == "" then
        return nil, L("ERR_IMPORT_EMPTY")
    end

    local serializer = GetAceSerializer()
    local deflate = GetLibDeflate()
    if not serializer or not deflate then
        return nil, L("ERR_IMPORT_MISSING_LIBS")
    end

    local matchedPrefix
    if text:sub(1, #EXPORT_PREFIX) == EXPORT_PREFIX then
        matchedPrefix = EXPORT_PREFIX
    elseif text:sub(1, #LEGACY_EXPORT_PREFIX) == LEGACY_EXPORT_PREFIX then
        matchedPrefix = LEGACY_EXPORT_PREFIX
    else
        return nil, L("ERR_IMPORT_BAD_PREFIX")
    end

    local encoded = text:sub(#matchedPrefix + 1)
    local compressed = deflate:DecodeForPrint(encoded)
    if type(compressed) ~= "string" then
        return nil, L("ERR_IMPORT_DECODE_FAILED")
    end

    local serialized = deflate:DecompressDeflate(compressed)
    if type(serialized) ~= "string" then
        return nil, L("ERR_IMPORT_DEFLATE_FAILED")
    end

    local ok, payload = serializer:Deserialize(serialized)
    if not ok or type(payload) ~= "table" then
        return nil, L("ERR_IMPORT_DESERIALIZE_FAILED")
    end
    if (payload.addon ~= ADDON_ID and payload.addon ~= LEGACY_ADDON_ID) or tonumber(payload.format) ~= 1 then
        return nil, L("ERR_IMPORT_VERSION_MISMATCH")
    end

    return payload
end
