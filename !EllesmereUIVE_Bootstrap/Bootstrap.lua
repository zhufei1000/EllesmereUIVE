local NS = _G.EllesmereUIVEBootstrapNS or {}
_G.EllesmereUIVEBootstrapNS = NS

local API = _G.EllesmereUIVEBootstrapAPI or {}
_G.EllesmereUIVEBootstrapAPI = API

NS.Runtime = NS.Runtime or {
    soundsRegisteredBeforeEUI = false,
    databasePreseededBeforeCDM = false,
    cdmLoaded = false,
    armedFamilies = { cd = false, buff = false },
}
NS.RegisteredBeforeEUI = NS.RegisteredBeforeEUI or {}
NS.ManifestByPath = NS.ManifestByPath or {}
NS.ManifestByKey = NS.ManifestByKey or {}

local function AddOnLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) == true end
    local legacy = rawget(_G, "IsAddOnLoaded")
    return type(legacy) == "function" and legacy(name) == true
end

local function NormalizePath(path)
    path = tostring(path or ""):match("^%s*(.-)%s*$") or ""
    path = path:gsub("/", "\\"):gsub("\\+", "\\")
    return path
end

local function HashPath(path)
    local normalized = NormalizePath(path):lower()
    local hash = 5381
    for index = 1, #normalized do
        hash = (hash * 33 + normalized:byte(index)) % 4294967296
    end
    return string.format("%08X", hash)
end

local function GetLSM()
    local libStub = rawget(_G, "LibStub")
    return type(libStub) == "table" and libStub:GetLibrary("LibSharedMedia-3.0", true) or nil
end

for _, item in ipairs(NS.SoundManifest or {}) do
    if type(item) == "table" and type(item.key) == "string" and type(item.path) == "string" then
        NS.ManifestByPath[NormalizePath(item.path):lower()] = item
        NS.ManifestByKey[item.key] = item
    end
end

local function ResolveBundledSound(path)
    return NS.ManifestByPath[NormalizePath(path):lower()]
end

local function RegisterMedia(key, path, beforeEUI)
    local lsm = GetLSM()
    if not lsm or type(key) ~= "string" or key == "" or type(path) ~= "string" or path == "" then return false end
    local current = lsm.Fetch and lsm:Fetch("sound", key, true) or nil
    local ok = current == path or pcall(lsm.Register, lsm, "sound", key, path)
    if ok and beforeEUI then NS.RegisteredBeforeEUI[key] = true end
    return ok
end

local function ResolveEntryPath(entry)
    local source = tostring(entry and entry.soundSource or "custom")
    if source == "builtin" then
        return NormalizePath(entry.builtinSoundPath or entry.soundPath or entry.customSoundPath)
    end
    return NormalizePath(entry and (entry.customSoundPath or entry.soundPath or entry.builtinSoundPath) or "")
end

local function RegisterBundledSounds()
    local beforeEUI = not AddOnLoaded("EllesmereUICooldownManager")
    local count = 0
    for _, item in ipairs(NS.SoundManifest or {}) do
        if RegisterMedia(item.key, item.path, beforeEUI) then count = count + 1 end
    end
    if beforeEUI and count > 0 then NS.Runtime.soundsRegisteredBeforeEUI = true end
    return count
end

local function RegisterSavedEntry(entry)
    if type(entry) ~= "table" or entry.entryType ~= "euiVoice" or entry.enabled == false or entry.voiceEnabled == false then
        return nil, "disabled"
    end
    local source = tostring(entry.soundSource or "custom")
    if source == "sharedmedia" then
        local key = tostring(entry.sharedMediaSound or "")
        if key == "" then return nil, "sharedmedia_missing" end
        local lsm = GetLSM()
        local path = lsm and lsm.Fetch and lsm:Fetch("sound", key, true) or nil
        entry.bootstrapMediaMissing = path == nil
        entry.soundKey = key
        entry.registeredBeforeEUI = not AddOnLoaded("EllesmereUICooldownManager")
        if entry.registeredBeforeEUI then NS.RegisteredBeforeEUI[key] = true end
        return key, path and "sharedmedia_ready" or "sharedmedia_key_preseeded"
    end

    local path = ResolveEntryPath(entry)
    if path == "" then return nil, "invalid_path" end
    local manifest = source == "builtin" and ResolveBundledSound(path) or nil
    local key = manifest and manifest.key or ("EUIVE_CUSTOM_" .. HashPath(path))
    local beforeEUI = not AddOnLoaded("EllesmereUICooldownManager")
    if not RegisterMedia(key, manifest and manifest.path or path, beforeEUI) then return nil, "invalid_path" end
    entry.soundKey = key
    entry.registeredBeforeEUI = beforeEUI
    entry.bootstrapMediaMissing = nil
    return key, beforeEUI and "registered_before_eui" or "registered_late"
end

local function RegisterSavedCustomSounds()
    local db = rawget(_G, "EllesmereUIVEDB")
    local count = 0
    for _, classMap in pairs(type(db) == "table" and type(db.specConfigs) == "table" and db.specConfigs or {}) do
        for _, entries in pairs(type(classMap) == "table" and classMap or {}) do
            for _, entry in pairs(type(entries) == "table" and entries or {}) do
                if RegisterSavedEntry(entry) then count = count + 1 end
            end
        end
    end
    return count
end

local FIELD_BY_TRIGGER = {
    cdReady = "cdReadySoundKey",
    buffGain = "buffActiveSoundKey",
    buffLoss = "buffLostSoundKey",
}
local HOSTED_BUFF_MARKER_BASE = 2000000000
-- Keep synchronized with EllesmereUICooldownManager.CDM_ITEM_PRESETS and the
-- runtime integration. EUI stores only each group's primary item ID.
local EUI_ITEM_PRESET_GROUPS = {
    [241308] = { 245898, 245897, 241309 },
    [241288] = { 241289, 245902, 245903 },
    [241304] = { 241305 },
    [241300] = { 245917, 245916, 241301 },
    [241302] = { 241303 },
}
local EUI_ITEM_PRESET_PRIMARY = {}
for primaryID, alternateIDs in pairs(EUI_ITEM_PRESET_GROUPS) do
    EUI_ITEM_PRESET_PRIMARY[primaryID] = primaryID
    for _, alternateID in ipairs(alternateIDs) do EUI_ITEM_PRESET_PRIMARY[alternateID] = primaryID end
end

local function GetCurrentClassSpec()
    local classID = 0
    if type(UnitClass) == "function" then classID = tonumber(select(3, UnitClass("player"))) or 0 end
    local index = GetSpecialization and GetSpecialization()
    local specID = index and C_SpecializationInfo and select(1, C_SpecializationInfo.GetSpecializationInfo(index)) or 0
    return classID, tonumber(specID) or 0
end

local function GetSpecKey()
    local getter = rawget(_G, "_ECME_GetCurrentSpecKey")
    if type(getter) == "function" then
        local ok, value = pcall(getter)
        if ok and value then return tostring(value) end
    end
    local _, specID = GetCurrentClassSpec()
    return specID > 0 and tostring(specID) or nil
end

local function ScopeIsCurrent(classID, specID)
    local currentClassID, currentSpecID = GetCurrentClassSpec()
    classID, specID = tonumber(classID) or 0, tonumber(specID) or 0
    return (classID == 0 or classID == currentClassID) and (specID == 0 or specID == currentSpecID)
end

local function ScopeMapMatches(map, id)
    if type(map) ~= "table" or next(map) == nil then return true end
    return map[0] == true or map["0"] == true or map[id] == true or map[tostring(id)] == true
end

local function EntryMatchesCurrent(entry, storageClassID, storageSpecID)
    local currentClassID, currentSpecID = GetCurrentClassSpec()
    local currentRaceID = type(UnitRace) == "function" and tonumber(select(3, UnitRace("player"))) or 0
    local classMap = type(entry.alertClassIDs) == "table" and next(entry.alertClassIDs) and entry.alertClassIDs or entry.customClassIDs
    local specMap = type(entry.alertSpecIDs) == "table" and next(entry.alertSpecIDs) and entry.alertSpecIDs or entry.customSpecIDs
    local raceMap = type(entry.alertRaceIDs) == "table" and next(entry.alertRaceIDs) and entry.alertRaceIDs or entry.customRaceIDs
    classMap = classMap or { [tonumber(storageClassID) or 0] = true }
    specMap = specMap or { [tonumber(storageSpecID) or 0] = true }
    return ScopeMapMatches(classMap, currentClassID) and ScopeMapMatches(specMap, currentSpecID)
        and ScopeMapMatches(raceMap, currentRaceID)
end

local function NormalizeTargetMode(entry)
    if type(entry) ~= "table" or entry.entryType ~= "euiVoice" then return end
    local family = tostring(entry.euiTargetFamily or "")
    if tostring(entry.euiTargetMode or "") == "forced"
        and (family == "cd" or family == "buff" or family == "custom") then return end
    if family == "custom" then
        entry.euiTargetMode, entry.euiTargetFamily = "forced", "custom"
    else
        entry.euiTargetMode, entry.euiTargetFamily = "auto", "auto"
    end
end

local function EnsureEUIContext(targetSpecID)
    local root = rawget(_G, "EllesmereUIDB")
    if type(root) ~= "table" then return nil, "waiting_for_eui" end
    local specKey = tonumber(targetSpecID) and tostring(math.floor(tonumber(targetSpecID))) or GetSpecKey()
    if not specKey then return nil, "waiting_for_spec" end
    local profileKey = tostring(root.activeProfile or "Default")
    root.spellAssignments = type(root.spellAssignments) == "table" and root.spellAssignments or {}
    local assignments = root.spellAssignments
    assignments.profiles = type(assignments.profiles) == "table" and assignments.profiles or {}
    assignments.profiles[profileKey] = type(assignments.profiles[profileKey]) == "table" and assignments.profiles[profileKey] or {}
    local profile = assignments.profiles[profileKey]
    profile.specProfiles = type(profile.specProfiles) == "table" and profile.specProfiles or {}
    profile.specProfiles[specKey] = type(profile.specProfiles[specKey]) == "table" and profile.specProfiles[specKey] or { barSpells = {} }
    local specProfile = profile.specProfiles[specKey]
    specProfile.barSpells = type(specProfile.barSpells) == "table" and specProfile.barSpells or {}
    local savedProfile = type(root.profiles) == "table" and root.profiles[profileKey] or nil
    if type(savedProfile) == "table" then
        savedProfile.addons = type(savedProfile.addons) == "table" and savedProfile.addons or {}
        savedProfile.addons.EllesmereUICooldownManager = type(savedProfile.addons.EllesmereUICooldownManager) == "table"
            and savedProfile.addons.EllesmereUICooldownManager or {}
    end
    local cdmProfile = type(savedProfile) == "table" and type(savedProfile.addons) == "table"
        and savedProfile.addons.EllesmereUICooldownManager or nil
    return {
        root = root,
        profileKey = profileKey,
        specKey = specKey,
        specProfile = specProfile,
        cdmProfile = cdmProfile,
    }
end

local function DecodeManagedID(value)
    value = tonumber(value)
    if not value then return nil end
    if value <= -HOSTED_BUFF_MARKER_BASE then return -value - HOSTED_BUFF_MARKER_BASE end
    return value > 0 and value or nil
end

local function GetCachedItemName(itemID)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    if not name then
        local getItemInfo = rawget(_G, "GetItemInfo")
        if type(getItemInfo) == "function" then name = getItemInfo(itemID) end
    end
    return type(name) == "string" and name:match("^%s*(.-)%s*$") or nil
end

local function FindManagedItem(context, itemID, entry)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return nil end
    itemID = math.floor(itemID)
    local marker = -math.floor(itemID)
    local managedItems = {}
    for _, barData in pairs(type(context and context.specProfile) == "table"
        and type(context.specProfile.barSpells) == "table" and context.specProfile.barSpells or {}) do
        for _, rawID in ipairs(type(barData) == "table" and type(barData.assignedSpells) == "table"
            and barData.assignedSpells or {}) do
            rawID = tonumber(rawID)
            if rawID == marker then return itemID, "exact" end
            if rawID == -13 or rawID == -14 then
                local equipped = GetInventoryItemID and GetInventoryItemID("player", -rawID)
                if tonumber(equipped) == itemID then return itemID, "trinket" end
            elseif rawID and rawID <= -100 and rawID > -HOSTED_BUFF_MARKER_BASE then
                managedItems[-rawID] = true
            end
        end
    end

    local primaryID = EUI_ITEM_PRESET_PRIMARY[itemID]
    if primaryID and managedItems[primaryID] then return primaryID, "preset_group" end
    if entry and entry.itemLoadSameName == true then
        local inputName = GetCachedItemName(itemID) or tostring(entry.spellName or ""):match("^%s*(.-)%s*$")
        if inputName and inputName ~= "" then
            for managedID in pairs(managedItems) do
                if GetCachedItemName(managedID) == inputName then return managedID, "same_name" end
            end
        end
        if C_Item and C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(itemID)
            for managedID in pairs(managedItems) do C_Item.RequestLoadItemDataByID(managedID) end
        end
    end
    return nil
end

local function IsBuffBar(barData)
    if type(barData) ~= "table" then return false end
    return barData.barType == "buffs" or barData.barType == "buff" or barData.type == "buffs"
end

local function DiscoverFamilies(specProfile, spellID)
    local foundCD, foundBuff = false, false
    for _, barData in pairs(type(specProfile) == "table" and type(specProfile.barSpells) == "table" and specProfile.barSpells or {}) do
        for _, rawID in ipairs(type(barData) == "table" and type(barData.assignedSpells) == "table" and barData.assignedSpells or {}) do
            if DecodeManagedID(rawID) == spellID then
                if tonumber(rawID) and tonumber(rawID) <= -HOSTED_BUFF_MARKER_BASE then
                    foundBuff = true
                elseif IsBuffBar(barData) then
                    foundBuff = true
                else
                    foundCD = true
                end
            end
        end
    end
    return foundCD, foundBuff
end

local function FindCustomState(context, spellID)
    local states = type(context.cdmProfile) == "table" and context.cdmProfile.customActiveStates or nil
    if type(states) ~= "table" then return nil, nil end
    if type(states[spellID]) == "table" then return states[spellID], spellID end
    local stringKey = tostring(spellID)
    if type(states[stringKey]) == "table" then return states[stringKey], stringKey end
    return nil, nil
end

local function IsForcedTarget(entry)
    if tostring(entry and entry.euiTargetMode or "") ~= "forced" then return false end
    local family = tostring(entry and entry.euiTargetFamily or "")
    return family == "cd" or family == "buff" or family == "custom"
end

-- Keep this target-family resolution algorithm synchronized with:
-- EllesmereUIVE/Integrations/EllesmereUI.lua
local function ResolveTargetFamily(context, entry, spellID)
    local trigger = tostring(entry.euiTriggerType or "cdReady")
    local family = tostring(entry.euiTargetFamily or "auto")
    local forced = IsForcedTarget(entry)
    if trigger == "buffGain" or trigger == "buffLoss" then
        if forced then
            if family == "custom" then return nil, "unsupported_entry_type" end
            if family == "cd" then return "spellSettingsCD" end
            if family == "buff" then return "spellSettingsBuff" end
        end
        return "spellSettingsBuff"
    end
    if forced then
        if family == "custom" then return "customActiveStates" end
        if family == "buff" then return "spellSettingsBuff" end
        if family == "cd" then return "spellSettingsCD" end
    end
    if FindCustomState(context, spellID) then return "customActiveStates" end
    local foundCD, foundBuff = DiscoverFamilies(context.specProfile, spellID)
    if foundCD then return "spellSettingsCD" end
    if foundBuff then return "spellSettingsBuff" end
    return "spellSettingsCD"
end

local function GetRecordTable(profileKey, specKey, spellID, create)
    EllesmereUIVEDB = type(EllesmereUIVEDB) == "table" and EllesmereUIVEDB or {}
    local db = EllesmereUIVEDB
    if type(db.euiInjectionRecords) ~= "table" then
        if not create then return nil end
        db.euiInjectionRecords = {}
    end
    local root = db.euiInjectionRecords
    if create then
        root[profileKey] = type(root[profileKey]) == "table" and root[profileKey] or {}
        root[profileKey][specKey] = type(root[profileKey][specKey]) == "table" and root[profileKey][specKey] or {}
        root[profileKey][specKey][spellID] = type(root[profileKey][specKey][spellID]) == "table"
            and root[profileKey][specKey][spellID] or {}
    end
    return root[profileKey] and root[profileKey][specKey] and root[profileKey][specKey][spellID] or nil
end

local function IsEmpty(value)
    return value == nil or value == false or value == "" or value == "none"
end

local function IsOwned(value)
    return type(value) == "string" and value:find("^sm:EUIVE_") ~= nil
end

local function ResolveTarget(context, family, spellID, create, createCustom)
    if family == "customActiveStates" then
        local target, key = FindCustomState(context, spellID)
        if not target and create and createCustom and type(context.cdmProfile) == "table" then
            context.cdmProfile.customActiveStates = type(context.cdmProfile.customActiveStates) == "table"
                and context.cdmProfile.customActiveStates or {}
            context.cdmProfile.customActiveStates[spellID] = {}
            target, key = context.cdmProfile.customActiveStates[spellID], spellID
        end
        if not target then return nil, nil, nil, "waiting_for_eui_custom_state" end
        return target, "customActiveStates", key
    end
    local store = context.specProfile[family]
    if type(store) ~= "table" and create then store = {}; context.specProfile[family] = store end
    if type(store) ~= "table" then return nil, family end
    local key = store[spellID] and spellID or (store[tostring(spellID)] and tostring(spellID) or spellID)
    if type(store[key]) ~= "table" and create then store[key] = {} end
    return store[key], family, key
end

local function ResolveCurrentRecordTarget(context, record, spellID)
    if type(record) ~= "table" then return nil end
    if record.family == "customActiveStates" then
        local states = type(context.cdmProfile) == "table" and context.cdmProfile.customActiveStates or nil
        if type(states) ~= "table" then return nil end
        local key = record.customStateKey or record.lookupID
        return type(states[key]) == "table" and states[key]
            or (type(states[spellID]) == "table" and states[spellID])
            or (type(states[tostring(spellID)]) == "table" and states[tostring(spellID)]) or nil
    end
    local store = type(context.specProfile) == "table" and context.specProfile[record.family] or nil
    return type(store) == "table" and (store[spellID] or store[tostring(spellID)]) or nil
end

local function PreseedEntry(entry, classID, specID, targetSpecID)
    if InCombatLockdown and InCombatLockdown() then return false, "waiting_combat" end
    if type(entry) ~= "table" or entry.entryType ~= "euiVoice" then return false, "unsupported_entry_type" end
    if entry.enabled == false or entry.voiceEnabled == false then return false, "disabled" end
    if not targetSpecID and not ScopeIsCurrent(classID, specID) then return false, "waiting_for_spec" end
    local trigger = tostring(entry.euiTriggerType or "cdReady")
    local field = FIELD_BY_TRIGGER[trigger]
    if not field then return false, "unsupported_entry_type" end
    NormalizeTargetMode(entry)
    local soundKey, registerStatus = RegisterSavedEntry(entry)
    if not soundKey then return false, registerStatus end
    local injectedValue = "sm:" .. soundKey
    local callOK, succeeded, changed, status = pcall(function()
        local context, contextStatus = EnsureEUIContext(targetSpecID)
        if not context then return false, false, contextStatus end
        local objectType = tostring(entry.objectType or "spell"):lower()
        local inputID, itemID, lookupID, lookupType, recordID, resolvedFamily, itemMatchType
        if objectType == "item" then
            itemID = tonumber(entry.itemID or entry.inputID or entry.spellId)
            itemID = itemID and math.floor(itemID) or nil
            if not itemID or itemID <= 0 then return false, false, "invalid_item_id" end
            if trigger ~= "cdReady" then return false, false, "unsupported_entry_type" end
            local euiItemID
            euiItemID, itemMatchType = FindManagedItem(context, itemID, entry)
            if not euiItemID then return false, false, "waiting_for_item_target" end
            inputID, recordID = itemID, itemID
            lookupID, lookupType = -euiItemID, "itemID"
            resolvedFamily = "customActiveStates"
        else
            local spellID = tonumber(entry.spellId)
            spellID = spellID and math.floor(spellID) or nil
            if not spellID or spellID <= 0 then return false, false, "unsupported_entry_type" end
            inputID, recordID, lookupID, lookupType = spellID, spellID, spellID, "spellID"
            local familyStatus
            resolvedFamily, familyStatus = ResolveTargetFamily(context, entry, spellID)
            if not resolvedFamily then return false, false, familyStatus end
        end
        local target, family, actualKey, targetStatus = ResolveTarget(
            context, resolvedFamily, lookupID, true, objectType == "item"
        )
        if type(target) ~= "table" then return false, false, targetStatus or family or "unsupported_structure" end
        local records = GetRecordTable(context.profileKey, context.specKey, recordID, true)
        local record = records[trigger]
        local current = rawget(target, field)
        local owned = IsOwned(current) or (type(record) == "table" and current == record.injectedValue)
        if not IsEmpty(current) and not owned and not (EllesmereUIVEDB.settings and EllesmereUIVEDB.settings.overwriteEUI == true) then
            return false, false, "conflict"
        end
        local sameRecordedTarget = type(record) == "table" and record.family == family and record.field == field
            and (family ~= "customActiveStates" or record.customStateKey == nil or record.customStateKey == actualKey)
        local staleChanged = false
        if type(record) == "table" and not sameRecordedTarget then
            local oldTarget = ResolveCurrentRecordTarget(context, record, recordID)
            if type(oldTarget) == "table" and oldTarget[record.field] == record.injectedValue then
                oldTarget[record.field] = record.previousValue
                staleChanged = true
            end
        end
        local previousValue = sameRecordedTarget and record.previousValue or current
        if sameRecordedTarget and current ~= record.injectedValue and not IsOwned(current) then previousValue = current end
        local fieldChanged = current ~= injectedValue
        if fieldChanged then target[field] = injectedValue end
        local registeredBeforeEUI = API.IsSoundRegisteredBeforeEUI(soundKey)
        local beforeCDM = not AddOnLoaded("EllesmereUICooldownManager")
        local triggerFamily = family == "spellSettingsBuff" and "buff" or "cd"
        local nativeReady = beforeCDM or entry.preseededBeforeCDM == true
            or (registeredBeforeEUI and NS.Runtime.armedFamilies[triggerFamily] == true)
        records[trigger] = {
            entryUID = tostring(entry.entryUID or ""),
            profileKey = context.profileKey,
            specKey = context.specKey,
            spellID = objectType == "spell" and lookupID or nil,
            objectType = objectType,
            inputID = inputID,
            itemID = itemID,
            euiItemID = objectType == "item" and -lookupID or nil,
            itemMatchType = objectType == "item" and itemMatchType or nil,
            lookupID = lookupID,
            lookupType = lookupType,
            triggerType = trigger,
            soundPath = ResolveEntryPath(entry),
            soundKey = injectedValue,
            previousValue = previousValue,
            injectedValue = injectedValue,
            injectedAtVersion = "1.0.4",
            family = family,
            field = field,
            customStateKey = family == "customActiveStates" and actualKey or nil,
            registeredBeforeEUI = registeredBeforeEUI,
            requiresReload = not nativeReady,
        }
        entry.registeredBeforeEUI = registeredBeforeEUI
        entry.preseededBeforeCDM = beforeCDM or entry.preseededBeforeCDM == true
        entry.requiresReload = not nativeReady
        local finalStatus = not nativeReady and "requires_reload"
            or (objectType == "item" and "item_id_injected")
            or (family == "customActiveStates" and "custom_state_injected" or (beforeCDM and "preseeded" or "native_ready"))
        return true, staleChanged or fieldChanged, finalStatus
    end)
    if not callOK then return false, "unsupported_structure" end
    return succeeded == true, status, changed == true
end

local function PreseedCurrentScope()
    local db = rawget(_G, "EllesmereUIVEDB")
    local count, changed, seenUID = 0, false, {}
    for classID, classMap in pairs(type(db) == "table" and type(db.specConfigs) == "table" and db.specConfigs or {}) do
        for specID, entries in pairs(type(classMap) == "table" and classMap or {}) do
            for _, entry in pairs(type(entries) == "table" and entries or {}) do
                local uid = type(entry) == "table" and tostring(entry.entryUID or "") or ""
                if (uid == "" or not seenUID[uid]) and EntryMatchesCurrent(entry, classID, specID) then
                    local ok, _, entryChanged = PreseedEntry(entry, classID, specID)
                    if ok then count = count + 1; changed = entryChanged == true or changed end
                    if uid ~= "" then seenUID[uid] = true end
                end
            end
        end
    end
    return count, changed
end

local function ScanArmedFamilies()
    local context = EnsureEUIContext()
    if not context then return end
    local cd, buff = false, false
    for _, settings in pairs(type(context.specProfile.spellSettingsCD) == "table" and context.specProfile.spellSettingsCD or {}) do
        if type(settings) == "table" and settings.cdReadySoundKey and settings.cdReadySoundKey ~= "none" then cd = true; break end
    end
    for _, settings in pairs(type(context.specProfile.spellSettingsBuff) == "table" and context.specProfile.spellSettingsBuff or {}) do
        if type(settings) == "table" and ((settings.buffActiveSoundKey and settings.buffActiveSoundKey ~= "none")
            or (settings.buffLostSoundKey and settings.buffLostSoundKey ~= "none")) then buff = true; break end
    end
    local cdm = context.cdmProfile
    for _, settings in pairs(type(cdm) == "table" and type(cdm.customActiveStates) == "table" and cdm.customActiveStates or {}) do
        if type(settings) == "table" and settings.cdReadySoundKey and settings.cdReadySoundKey ~= "none" then cd = true; break end
    end
    NS.Runtime.armedFamilies.cd = cd
    NS.Runtime.armedFamilies.buff = buff
end

local function PreseedEUIDatabase()
    local beforeCDM = not AddOnLoaded("EllesmereUICooldownManager")
    local ok, count, changed = pcall(PreseedCurrentScope)
    if not ok then return 0, false, "unsupported_structure" end
    if beforeCDM then NS.Runtime.databasePreseededBeforeCDM = true end
    ScanArmedFamilies()
    return count, changed, "preseeded"
end

function API.IsSoundRegisteredBeforeEUI(soundKey)
    soundKey = tostring(soundKey or ""):gsub("^sm:", "")
    return NS.RegisteredBeforeEUI[soundKey] == true
end

function API.ResolveBundledSoundKey(path)
    local item = ResolveBundledSound(path)
    return item and item.key or nil
end

function API.ResolveCustomSoundKey(path)
    path = NormalizePath(path)
    return path ~= "" and ("EUIVE_CUSTOM_" .. HashPath(path)) or nil
end

function API.RegisterSavedEntry(entry)
    return RegisterSavedEntry(entry)
end

function API.RegisterAllSavedEntries()
    return RegisterSavedCustomSounds()
end

function API.PreseedEntry(entry, classID, specID) return PreseedEntry(entry, classID, specID) end
function API.PreseedEntryForSpec(entry, classID, specID) return PreseedEntry(entry, classID, specID, specID) end
function API.PreseedCurrentScope() return PreseedCurrentScope() end
function API.EnsureEUIContext() return EnsureEUIContext() end

function API.IsCDMLoaded() return NS.Runtime.cdmLoaded == true end
function API.WasDatabasePreseededBeforeCDM() return NS.Runtime.databasePreseededBeforeCDM == true end
function API.IsFamilyArmed(family) return NS.Runtime.armedFamilies[tostring(family or "")] == true end
function API.NormalizePath(path) return NormalizePath(path) end
function API.HashPath(path) return HashPath(path) end
function API.GetRuntimeStatus() return NS.Runtime end

NS.Runtime.cdmLoaded = AddOnLoaded("EllesmereUICooldownManager")
RegisterBundledSounds()
RegisterSavedCustomSounds()

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, _, addonName)
    if addonName == "EllesmereUI" then
        PreseedEUIDatabase()
    elseif addonName == "EllesmereUICooldownManager" then
        NS.Runtime.cdmLoaded = true
        ScanArmedFamilies()
    end
end)

if AddOnLoaded("EllesmereUI") then PreseedEUIDatabase() end
