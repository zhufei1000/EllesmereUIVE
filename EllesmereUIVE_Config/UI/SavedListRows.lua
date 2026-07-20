local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.SavedListRows = NS.UI.SavedListRows or {}

local Rows = NS.UI.SavedListRows
local Utils = NS.Utils or {}
local CONST = NS.Constants or {}
local ALL_RACES_ID = CONST.ALL_RACES_ID or 0
local ITEM_LOAD_NONE = CONST.ITEM_LOAD_NONE or "none"
local ITEM_LOAD_EQUIPPED = CONST.ITEM_LOAD_EQUIPPED or "equipped"
local ITEM_LOAD_BAGS = CONST.ITEM_LOAD_BAGS or "bags"
local L = NS.L or function(key, ...)
    if select("#", ...) > 0 then
        return string.format(tostring(key), ...)
    end
    return tostring(key)
end

local function TrimText(value)
    if Utils.TrimText then
        return Utils.TrimText(value)
    end
    value = tostring(value or "")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return value
end

local RACE_FALLBACK_NAMES = {
    [1] = "Human", [2] = "Orc", [3] = "Dwarf", [4] = "Night Elf", [5] = "Undead",
    [6] = "Tauren", [7] = "Gnome", [8] = "Troll", [9] = "Goblin", [10] = "Blood Elf",
    [11] = "Draenei", [22] = "Worgen", [24] = "Pandaren", [25] = "Pandaren (Alliance)",
    [26] = "Pandaren (Horde)", [27] = "Nightborne", [28] = "Highmountain Tauren",
    [29] = "Void Elf", [30] = "Lightforged Draenei", [31] = "Zandalari Troll",
    [32] = "Kul Tiran", [34] = "Dark Iron Dwarf", [35] = "Vulpera", [36] = "Mag'har Orc",
    [37] = "Mechagnome", [52] = "Dracthyr", [70] = "Dracthyr", [84] = "Earthen", [85] = "Earthen",
}

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

local function GetRaceName(raceID)
    raceID = tonumber(raceID) or 0
    if C_CreatureInfo and type(C_CreatureInfo.GetRaceInfo) == "function" then
        local ok, info = pcall(C_CreatureInfo.GetRaceInfo, raceID)
        if ok and type(info) == "table" and type(info.raceName) == "string" and info.raceName ~= "" then
            return info.raceName
        end
    end
    return RACE_FALLBACK_NAMES[raceID] or tostring(raceID)
end

local function BuildRaceScopeText(entry)
    local map = CopyNumberBoolMap(entry and entry.alertRaceIDs)
    if next(map) == nil or map[ALL_RACES_ID] == true then
        return ""
    end
    local ids = {}
    for raceID, enabled in pairs(map) do
        raceID = tonumber(raceID) or 0
        if enabled == true and raceID > 0 then
            ids[#ids + 1] = raceID
        end
    end
    table.sort(ids)
    if #ids == 0 then
        return ""
    end
    local names = {}
    for index, raceID in ipairs(ids) do
        if index > 3 then
            break
        end
        names[#names + 1] = GetRaceName(raceID)
    end
    local value = (#ids > 3) and L("SCOPE_RACE_COUNT", #ids) or table.concat(names, "/")
    return L("SAVED_SCOPE_RACES", value)
end

local function GetEntryTypeText(entry)
    local typeText = TrimText(entry and entry.typeText)
    if typeText ~= "" then
        return typeText
    end

    local entryType = tostring((entry and entry.entryType) or "euiVoice")
    if entryType == "cast" then
        return L("ENTRY_TYPE_CAST")
    elseif entryType == "custom" then
        return L("ENTRY_TYPE_CUSTOM")
    elseif entryType == "bloodlust" then
        return L("ENTRY_TYPE_BLOODLUST")
    end
    return L("ENTRY_TYPE_COOLDOWN")
end

function Rows.GetEntryTypeText(entry)
    return GetEntryTypeText(entry)
end

function Rows.BuildEntryRowText(entry, includeScopeText)
    if type(entry) == "table" then
        local cacheField = includeScopeText and "_mcdRowTextWithScope" or "_mcdRowText"
        if type(entry[cacheField]) == "string" then
            return entry[cacheField]
        end
    end
    local parts = {}
    local spellId = tonumber(entry and entry.spellId) or 0
    local index = tonumber(entry and entry.index) or 0
    local spellName = TrimText(entry and entry.spellName)

    parts[#parts + 1] = string.format("|cffffd24a%s|r", GetEntryTypeText(entry))
    if spellName ~= "" then
        parts[#parts + 1] = spellName
    elseif spellId > 0 then
        parts[#parts + 1] = tostring(spellId)
    else
        parts[#parts + 1] = L("ENTRY_UNNAMED")
    end

    if spellId > 0 then
        local objectType = tostring(entry and entry.objectType or "spell"):lower()
        local idLabel = (objectType == "item") and L("ENTRY_OBJECT_ITEM_ID") or L("ENTRY_OBJECT_SPELL_ID")
        parts[#parts + 1] = string.format("|cff808080%s:%d|r", idLabel, spellId)
        if objectType == "item" then
            local itemLoadMode = tostring(entry and entry.itemLoadMode or ITEM_LOAD_NONE)
            if itemLoadMode == ITEM_LOAD_EQUIPPED then
                parts[#parts + 1] = string.format("|cff808080%s|r", L("SAVED_ITEM_LOAD_EQUIPPED"))
            elseif itemLoadMode == ITEM_LOAD_BAGS then
                parts[#parts + 1] = string.format("|cff808080%s|r", L("SAVED_ITEM_LOAD_BAGS"))
                if entry.itemLoadSameName == true then
                    parts[#parts + 1] = string.format("|cff808080%s|r", L("SAVED_ITEM_LOAD_SAME_NAME"))
                end
            end
        end
    end
    if index > 0 then
        parts[#parts + 1] = string.format("|cff808080#%d|r", index)
    end
    local soundDetail = TrimText(entry and entry.soundDetail)
    if soundDetail ~= "" then
        parts[#parts + 1] = string.format("|cff808080%s|r", soundDetail)
    elseif TrimText(entry and entry.modeText) ~= "" then
        parts[#parts + 1] = string.format("|cff808080%s|r", TrimText(entry and entry.modeText))
    end
    if tostring(entry and entry.entryType or "") == "cast" and entry.delayEnabled == true and (tonumber(entry.delaySeconds) or 0) > 0 then
        parts[#parts + 1] = string.format("|cff808080%s|r", L("SAVED_CAST_DELAY", tonumber(entry.delaySeconds) or 0))
    end
    if tostring(entry and entry.entryType or "") == "euiVoice" then
        local triggerText = TrimText(entry and entry.modeText)
        if triggerText ~= "" then parts[#parts + 1] = string.format("|cff80c8ff%s|r", triggerText) end
        local enabledText = TrimText(entry and entry.enabledText)
        if enabledText ~= "" then parts[#parts + 1] = string.format("|cff808080%s|r", enabledText) end
        local statusText = TrimText(entry and entry.euiStatusText)
        if statusText ~= "" then parts[#parts + 1] = string.format("|cff80dfff%s|r", L("EUI_STATUS", statusText)) end
    end
    if entry and entry.checkTalent == true and (tonumber(entry.talentId) or 0) > 0 then
        local talentText = TrimText(entry.talentName)
        if talentText == "" then
            talentText = tostring(entry.talentId)
        end
        local talentCD = tonumber(entry.talentCD) or 0
        if talentCD > 0 then
            parts[#parts + 1] = string.format("|cff808080%s|r", L("TALENT_ROW", talentText, talentCD))
        else
            parts[#parts + 1] = string.format("|cff808080%s|r", L("TALENT_ROW_NO_CD", talentText))
        end
    end
    if includeScopeText and TrimText(entry and entry.scopeText) ~= "" then
        parts[#parts + 1] = string.format("|cff808080%s|r", TrimText(entry and entry.scopeText))
    elseif entry and entry.groupID and entry.isLoaded == false then
        parts[#parts + 1] = TrimText(L("UNLOADED_TAG"))
    end
    local raceScopeText = BuildRaceScopeText(entry)
    if raceScopeText ~= "" then
        parts[#parts + 1] = string.format("|cff808080%s|r", raceScopeText)
    end

    local result = table.concat(parts, "  ")
    if type(entry) == "table" then
        local cacheField = includeScopeText and "_mcdRowTextWithScope" or "_mcdRowText"
        entry[cacheField] = result
    end
    return result
end

function Rows.BuildGroupRowText(entry)
    if type(entry) == "table" and type(entry._mcdGroupRowText) == "string" then
        return entry._mcdGroupRowText
    end
    local name = TrimText(entry and entry.name)
    if name == "" then
        name = L("COLLECTION_UNNAMED")
    end
    local count = tonumber(entry and entry.count) or 0
    local countText
    local loadedCount = tonumber(entry and entry.loadedCount) or 0
    local unloadedCount = tonumber(entry and entry.unloadedCount) or 0
    if count <= 0 then
        countText = L("COLLECTION_EMPTY_COUNT")
    elseif loadedCount > 0 and unloadedCount > 0 then
        countText = L("COLLECTION_COUNT_MIXED", count, loadedCount, unloadedCount)
    else
        countText = L("COLLECTION_COUNT", count)
    end
    local result = string.format("|cffffd24a%s|r  %s  |cff808080%s|r", L("COLLECTION_LABEL"), name, countText)
    if type(entry) == "table" then
        entry._mcdGroupRowText = result
    end
    return result
end
