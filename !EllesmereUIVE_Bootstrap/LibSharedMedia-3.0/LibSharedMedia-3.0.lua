-- Minimal early-loading LibSharedMedia surface. The full embedded library in
-- EllesmereUIVE upgrades this shared table later without losing registrations.
local MAJOR, MINOR = "LibSharedMedia-3.0", 1
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.MediaTable = lib.MediaTable or {}
lib.MediaList = lib.MediaList or {}

local function Ensure(mediatype)
    lib.MediaTable[mediatype] = lib.MediaTable[mediatype] or {}
    lib.MediaList[mediatype] = lib.MediaList[mediatype] or {}
    return lib.MediaTable[mediatype], lib.MediaList[mediatype]
end

function lib:Register(mediatype, key, data)
    if type(mediatype) ~= "string" or type(key) ~= "string" or type(data) ~= "string" then return false end
    local media, list = Ensure(mediatype)
    if media[key] == nil then list[#list + 1] = key end
    media[key] = data
    return true
end

function lib:Fetch(mediatype, key, noDefault)
    local media = self.MediaTable and self.MediaTable[mediatype]
    local value = type(media) == "table" and media[key] or nil
    if value ~= nil or noDefault then return value end
    local defaults = self.DefaultMedia and self.DefaultMedia[mediatype]
    return type(media) == "table" and defaults and media[defaults] or nil
end

function lib:HashTable(mediatype)
    return Ensure(mediatype)
end

function lib:List(mediatype)
    local _, list = Ensure(mediatype)
    return list
end
