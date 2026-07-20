local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.Core = NS.Core or {}
NS.Core.ScopeResolver = NS.Core.ScopeResolver or {}
local Resolver = NS.Core.ScopeResolver

local function CurrentClassSpec()
    if type(NS.GetCurrentClassSpec) == "function" then
        local classID, specID = NS:GetCurrentClassSpec()
        return tonumber(classID) or 0, tonumber(specID) or 0
    end
    local classID = type(UnitClass) == "function" and tonumber(select(3, UnitClass("player"))) or 0
    local index = type(GetSpecialization) == "function" and GetSpecialization() or nil
    local specID = index and C_SpecializationInfo and type(C_SpecializationInfo.GetSpecializationInfo) == "function"
        and tonumber(select(1, C_SpecializationInfo.GetSpecializationInfo(index))) or 0
    return classID or 0, specID or 0
end

local function ClassIDAt(index)
    if type(GetClassInfo) == "function" then
        local _, _, classID = GetClassInfo(index)
        if tonumber(classID) then return tonumber(classID) end
    end
    if C_CreatureInfo and type(C_CreatureInfo.GetClassInfo) == "function" then
        local info = C_CreatureInfo.GetClassInfo(index)
        if type(info) == "table" then return tonumber(info.classID) end
    end
end

local function SpecIDAt(classID, index)
    if type(GetSpecializationInfoForClassID) == "function" then
        return tonumber(select(1, GetSpecializationInfoForClassID(classID, index)))
    end
    if C_SpecializationInfo and type(C_SpecializationInfo.GetSpecializationInfoForClassID) == "function" then
        return tonumber(select(1, C_SpecializationInfo.GetSpecializationInfoForClassID(classID, index)))
    end
end

local function CopySelection(source)
    local result = {}
    for key, enabled in pairs(type(source) == "table" and source or {}) do
        local id = tonumber(key)
        if enabled == true and id and id >= 0 then result[id] = true end
    end
    return result
end

local function PreferredMap(primary, legacy)
    if type(primary) == "table" and next(primary) ~= nil then return primary end
    return legacy
end

function Resolver:GetAllConcreteTargets()
    local targets, seen = {}, {}
    local classCount = type(GetNumClasses) == "function" and tonumber(GetNumClasses()) or 0
    for classIndex = 1, classCount do
        local classID = ClassIDAt(classIndex)
        if classID and classID > 0 then
            local specCount = type(GetNumSpecializationsForClassID) == "function"
                and tonumber(GetNumSpecializationsForClassID(classID)) or 0
            for specIndex = 1, specCount do
                local specID = SpecIDAt(classID, specIndex)
                local key = specID and (tostring(classID) .. ":" .. tostring(specID)) or nil
                if specID and specID > 0 and not seen[key] then
                    targets[#targets + 1] = { classID = classID, specID = specID }
                    seen[key] = true
                end
            end
        end
    end
    table.sort(targets, function(a, b)
        return a.classID == b.classID and a.specID < b.specID or a.classID < b.classID
    end)
    return targets
end

function Resolver:ResolveTargets(classMap, specMap)
    classMap, specMap = CopySelection(classMap), CopySelection(specMap)
    local allClasses, allSpecs = classMap[0] == true, specMap[0] == true
    local result = {}
    for _, target in ipairs(self:GetAllConcreteTargets()) do
        local classSelected = allClasses or classMap[target.classID] == true
        local specSelected = allSpecs or specMap[target.specID] == true
        if classSelected and specSelected then
            result[#result + 1] = { classID = target.classID, specID = target.specID }
        end
    end
    if #result == 0 then
        local classID, specID = CurrentClassSpec()
        if classID > 0 and specID > 0 then result[1] = { classID = classID, specID = specID } end
    end
    return result
end

local function MatchesMap(map, id)
    if type(map) ~= "table" or next(map) == nil then return true end
    return map[0] == true or map["0"] == true or map[id] == true or map[tostring(id)] == true
end

function Resolver:EntryMatchesScope(entry, classID, specID, raceID)
    if type(entry) ~= "table" then return false end
    classID, specID, raceID = tonumber(classID) or 0, tonumber(specID) or 0, tonumber(raceID) or 0
    local classMap = PreferredMap(entry.alertClassIDs, entry.customClassIDs)
    local specMap = PreferredMap(entry.alertSpecIDs, entry.customSpecIDs)
    local raceMap = PreferredMap(entry.alertRaceIDs, entry.customRaceIDs)
    if classMap == nil then classMap = { [tonumber(entry.classID) or 0] = true } end
    if specMap == nil then specMap = { [tonumber(entry.specID) or 0] = true } end
    return MatchesMap(classMap, classID) and MatchesMap(specMap, specID) and MatchesMap(raceMap, raceID)
end

function Resolver:ResolveEntryTargets(entry)
    entry = type(entry) == "table" and entry or {}
    return self:ResolveTargets(PreferredMap(entry.alertClassIDs, entry.customClassIDs), PreferredMap(entry.alertSpecIDs, entry.customSpecIDs))
end

function Resolver:ResolveStorageScope(classMap, specMap)
    classMap, specMap = CopySelection(classMap), CopySelection(specMap)
    if classMap[0] == true and specMap[0] == true then return 0, 0 end
    local selectedClass, classCount = nil, 0
    for classID, enabled in pairs(classMap) do
        if enabled and classID > 0 then selectedClass, classCount = classID, classCount + 1 end
    end
    if classCount ~= 1 or classMap[0] == true then return 0, 0 end
    if specMap[0] == true then return selectedClass, 0 end
    local targets = self:ResolveTargets(classMap, specMap)
    if #targets == 1 and targets[1].classID == selectedClass then
        return selectedClass, targets[1].specID
    end
    return 0, 0
end

Resolver.CopySelection = CopySelection
Resolver.PreferredMap = PreferredMap
