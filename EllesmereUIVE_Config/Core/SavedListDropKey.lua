local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.SavedListDropKey = NS.SavedListDropKey or {}
local DropKey = NS.SavedListDropKey

local Utils = NS.Utils or {}

local function TrimText(value)
    if Utils.TrimText then
        return Utils.TrimText(value)
    end
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

function DropKey:StripSuffix(value)
    local key = TrimText(value)
    local mode = "before"
    local hadEmptySuffix = false

    if key:match(":inside$") then
        key = key:gsub(":inside$", "")
        mode = "inside"
    elseif key:match(":after$") then
        key = key:gsub(":after$", "")
        mode = "after"
    elseif key:match(":before$") then
        key = key:gsub(":before$", "")
        mode = "before"
    end

    if key:match(":empty$") then
        key = key:gsub(":empty$", "")
        hadEmptySuffix = true
    end

    return key, mode, hadEmptySuffix
end

function DropKey:Build(baseKey, mode)
    baseKey = TrimText(baseKey)
    mode = tostring(mode or "before")
    if baseKey == "" then
        return ""
    end
    if mode == "inside" then
        return baseKey .. ":inside"
    elseif mode == "after" then
        return baseKey .. ":after"
    elseif mode == "before" then
        return baseKey
    end
    return baseKey
end

function DropKey:IsGroupKey(value)
    local key = self:StripSuffix(value)
    return tostring(key or ""):match("^group:") ~= nil
end

function DropKey:IsEntryKey(value)
    local key = self:StripSuffix(value)
    return tostring(key or ""):match("^%-?%d+:%-?%d+:%-?%d+$") ~= nil
end

function DropKey:GetKind(value)
    local key = self:StripSuffix(value)
    if tostring(key or ""):match("^group:") then
        return "group"
    end
    if tostring(key or ""):match("^root:%-?%d+:%-?%d+$") then
        return "root"
    end
    if tostring(key or ""):match("^%-?%d+:%-?%d+:%-?%d+$") then
        return "entry"
    end
    return nil
end

function DropKey:ParseRootKey(value)
    local key = self:StripSuffix(value)
    local classID, specID = tostring(key or ""):match("^root:(%-?%d+):(%-?%d+)$")
    return tonumber(classID) or -1, tonumber(specID) or -1
end

function DropKey:Split(value)
    local key, mode, hadEmptySuffix = self:StripSuffix(value)
    return {
        original = tostring(value or ""),
        key = key,
        mode = mode,
        isInside = mode == "inside",
        isAfter = mode == "after",
        isBefore = mode == "before",
        hadEmptySuffix = hadEmptySuffix == true,
        kind = self:GetKind(key),
    }
end

function DropKey:IsSameBaseKey(a, b)
    local ak = self:StripSuffix(a)
    local bk = self:StripSuffix(b)
    return ak ~= "" and ak == bk
end
