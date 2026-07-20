local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.Integrations = NS.Integrations or {}
NS.Integrations.EllesmereUI = NS.Integrations.EllesmereUI or {}
local Integration = NS.Integrations.EllesmereUI

local FIELD_BY_TRIGGER = {
    cdReady = "cdReadySoundKey",
    buffGain = "buffActiveSoundKey",
    buffLoss = "buffLostSoundKey",
}
local HOSTED_BUFF_MARKER_BASE = 2000000000
-- Mirrors EllesmereUICooldownManager.CDM_ITEM_PRESETS. EUI persists only the
-- primary itemID; every altItemID shares that primary frame/settings entry.
local EUI_ITEM_PRESET_GROUPS = {
    [241308] = { 245898, 245897, 241309 }, -- Light's Potential
    [241288] = { 241289, 245902, 245903 }, -- Potion of Recklessness
    [241304] = { 241305 },                 -- Silvermoon Health Potion
    [241300] = { 245917, 245916, 241301 }, -- Lightfused Mana Potion
    [241302] = { 241303 },                 -- Invisibility Potion
}
local EUI_ITEM_PRESET_PRIMARY = {}
for primaryID, alternateIDs in pairs(EUI_ITEM_PRESET_GROUPS) do
    EUI_ITEM_PRESET_PRIMARY[primaryID] = primaryID
    for _, alternateID in ipairs(alternateIDs) do EUI_ITEM_PRESET_PRIMARY[alternateID] = primaryID end
end

local function EntryEnabled(entry)
    return type(entry) == "table" and entry.enabled ~= false and entry.voiceEnabled ~= false
end

local function AddOnLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) == true end
    local legacy = rawget(_G, "IsAddOnLoaded")
    return type(legacy) == "function" and legacy(name) == true
end

local function TryLoadCooldownManager()
    if AddOnLoaded("EllesmereUICooldownManager") then return true end
    if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "EllesmereUICooldownManager") end
    return AddOnLoaded("EllesmereUICooldownManager")
end

local function GetSpecKey()
    local getter = rawget(_G, "_ECME_GetCurrentSpecKey")
    if type(getter) == "function" then
        local ok, key = pcall(getter)
        if ok and key then return tostring(key) end
    end
    local index = GetSpecialization and GetSpecialization()
    local id = index and C_SpecializationInfo and select(1, C_SpecializationInfo.GetSpecializationInfo(index))
    return id and tostring(id) or nil
end

local function ResolveRootProfile(create)
    if not AddOnLoaded("EllesmereUI") then return nil, "waiting_for_eui" end
    if not AddOnLoaded("EllesmereUICooldownManager") and not TryLoadCooldownManager() then return nil, "module_not_loaded" end
    local root = rawget(_G, "EllesmereUIDB")
    if type(root) ~= "table" then return nil, "waiting_for_eui" end
    local profileKey = tostring(root.activeProfile or "Default")
    if create then
        root.spellAssignments = type(root.spellAssignments) == "table" and root.spellAssignments or {}
        root.spellAssignments.profiles = type(root.spellAssignments.profiles) == "table" and root.spellAssignments.profiles or {}
        root.spellAssignments.profiles[profileKey] = type(root.spellAssignments.profiles[profileKey]) == "table"
            and root.spellAssignments.profiles[profileKey] or {}
        local bucket = root.spellAssignments.profiles[profileKey]
        bucket.specProfiles = type(bucket.specProfiles) == "table" and bucket.specProfiles or {}
    end
    local assignments = root.spellAssignments
    local profiles = type(assignments) == "table" and assignments.profiles or nil
    local bucket = type(profiles) == "table" and profiles[profileKey] or nil
    local specProfiles = type(bucket) == "table" and bucket.specProfiles or nil
    local profile = type(root.profiles) == "table" and root.profiles[profileKey] or nil
    if create and type(profile) == "table" then
        profile.addons = type(profile.addons) == "table" and profile.addons or {}
        profile.addons.EllesmereUICooldownManager = type(profile.addons.EllesmereUICooldownManager) == "table"
            and profile.addons.EllesmereUICooldownManager or {}
    end
    local cdmProfile = type(profile) == "table" and type(profile.addons) == "table"
        and profile.addons.EllesmereUICooldownManager or nil
    return root, profileKey, specProfiles, cdmProfile
end

local function ResolveContextForSpec(specID, create)
    local root, profileKey, specProfiles, cdmProfileOrStatus = ResolveRootProfile(create)
    if not root then return nil, profileKey end
    local specKey = tonumber(specID) and tostring(math.floor(tonumber(specID))) or tostring(specID or "")
    if specKey == "" then return nil, "waiting_for_spec" end
    if create then
        specProfiles[specKey] = type(specProfiles[specKey]) == "table" and specProfiles[specKey] or { barSpells = {} }
        specProfiles[specKey].barSpells = type(specProfiles[specKey].barSpells) == "table" and specProfiles[specKey].barSpells or {}
    end
    local specProfile = type(specProfiles) == "table" and (specProfiles[specKey] or specProfiles[tonumber(specKey)]) or nil
    if create and type(specProfile) ~= "table" then return nil, "unsupported_structure" end
    return {
        root = root,
        profileKey = profileKey,
        specKey = specKey,
        specProfiles = specProfiles,
        specProfile = specProfile,
        cdmProfile = cdmProfileOrStatus,
    }
end

local function ResolveContext(create)
    local specKey = GetSpecKey()
    if not specKey then return nil, "waiting_for_spec" end
    return ResolveContextForSpec(specKey, create)
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

    -- Optional forward-compatible fallback for future EUI preset ranks. This is
    -- deliberately opt-in because arbitrary custom items may legitimately share
    -- a localized name without belonging to one EUI preset.
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
    if type(states) ~= "table" then return nil, nil, states end
    if type(states[spellID]) == "table" then return states[spellID], spellID, states end
    local stringKey = tostring(spellID)
    if type(states[stringKey]) == "table" then return states[stringKey], stringKey, states end
    return nil, nil, states
end

local function IsSkillPresent(context, spellID)
    if FindCustomState(context, spellID) then return true end
    local foundCD, foundBuff = DiscoverFamilies(context and context.specProfile, spellID)
    return foundCD or foundBuff
end

local function IsForcedTarget(entry)
    if tostring(entry and entry.euiTargetMode or "") ~= "forced" then return false end
    local family = tostring(entry and entry.euiTargetFamily or "")
    return family == "cd" or family == "buff" or family == "custom"
end

-- Keep this target-family resolution algorithm synchronized with:
-- !EllesmereUIVE_Bootstrap/Bootstrap.lua
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

-- EUI stores cooldown/utility items as negative item IDs. The on-use spell ID
-- is resolved by EUI only for cast edges; it is not the cooldown identity.
local function ResolveManagedIdentifier(context, entry)
    local objectType = tostring(entry and entry.objectType or "spell"):lower()
    if objectType == "item" then
        local itemID = tonumber(entry.itemID or entry.inputID or entry.spellId)
        itemID = itemID and math.floor(itemID) or nil
        if not itemID or itemID <= 0 then return nil, "invalid_item_id" end
        if tostring(entry.euiTriggerType or "cdReady") ~= "cdReady" then
            return nil, "unsupported_entry_type"
        end
        local euiItemID, itemMatchType = FindManagedItem(context, itemID, entry)
        if not euiItemID then return nil, "waiting_for_item_target" end
        return {
            objectType = "item",
            inputID = itemID,
            itemID = itemID,
            euiItemID = euiItemID,
            itemMatchType = itemMatchType,
            recordID = itemID,
            lookupID = -euiItemID,
            lookupType = "itemID",
            family = "customActiveStates",
        }
    end

    local spellID = tonumber(entry and entry.spellId)
    spellID = spellID and math.floor(spellID) or nil
    if not spellID or spellID <= 0 then return nil, "unsupported_entry_type" end
    local family, familyStatus = ResolveTargetFamily(context, entry, spellID)
    if not family then return nil, familyStatus end
    return {
        objectType = "spell",
        inputID = spellID,
        recordID = spellID,
        lookupID = spellID,
        lookupType = "spellID",
        family = family,
    }
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
        if not target then return nil, nil, "waiting_for_eui_custom_state" end
        return target, key
    end
    local specProfile = context.specProfile
    if type(specProfile) ~= "table" then return nil end
    local store = specProfile[family]
    if type(store) ~= "table" and create then store = {}; specProfile[family] = store end
    if type(store) ~= "table" then return nil end
    local key = type(store[spellID]) == "table" and spellID
        or (type(store[tostring(spellID)]) == "table" and tostring(spellID) or spellID)
    if type(store[key]) ~= "table" and create then store[key] = {} end
    return store[key], key
end

local function GetRecordTable(profileKey, specKey, spellID, create)
    local db = rawget(_G, "EllesmereUIVEDB")
    if type(db) ~= "table" then return nil end
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

local function IsOwnedValue(value)
    return type(value) == "string" and value:find("^sm:EUIVE_") ~= nil
end

function Integration:IsAvailable()
    local context, status = ResolveContext(false)
    return context ~= nil, status or "available"
end

function Integration:GetVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then return C_AddOns.GetAddOnMetadata("EllesmereUI", "Version") or "unknown" end
    return "unknown"
end

function Integration:GetCurrentProfileKey()
    local root = rawget(_G, "EllesmereUIDB")
    return type(root) == "table" and tostring(root.activeProfile or "Default") or nil
end

function Integration:GetCurrentSpecKey() return GetSpecKey() end

function Integration:GetManagedSpells()
    local context, status = ResolveContext(false)
    if not context then return {}, status end
    local result = {}
    for _, barData in pairs(type(context.specProfile) == "table" and type(context.specProfile.barSpells) == "table" and context.specProfile.barSpells or {}) do
        for _, rawID in ipairs(type(barData) == "table" and type(barData.assignedSpells) == "table" and barData.assignedSpells or {}) do
            local id = DecodeManagedID(rawID)
            if id then result[id] = true end
        end
    end
    local getter = rawget(_G, "_ECME_GetCDMSpellSet")
    if type(getter) == "function" then
        local ok, managed = pcall(getter)
        if ok and type(managed) == "table" then
            for rawID, present in pairs(managed) do
                local id = present == true and tonumber(rawID) or tonumber(present)
                if id and id > 0 then result[id] = true end
            end
        end
    end
    return result, "available"
end

function Integration:IsSpellManaged(spellID)
    local managed, status = self:GetManagedSpells()
    return managed[tonumber(spellID)] == true, status
end

function Integration:BuildSoundKey(entry) return NS.Core.EUISoundRegistry:BuildStableSoundKey(entry) end
function Integration:RegisterEntrySound(entry) return NS.Core.EUISoundRegistry:RegisterEntry(entry) end

local function BuildPlan(self, context, entry, overwrite)
    if not EntryEnabled(entry) then return nil, "disabled" end
    local trigger = tostring(entry.euiTriggerType or "cdReady")
    local field = FIELD_BY_TRIGGER[trigger]
    if not field then return nil, "unsupported_entry_type" end
    local identifier, identifierStatus = ResolveManagedIdentifier(context, entry)
    if not identifier then return nil, identifierStatus end
    local family, lookupID = identifier.family, identifier.lookupID
    if family == "customActiveStates" and trigger ~= "cdReady" then return nil, "unsupported_entry_type" end
    local injectedValue, registerStatus, mediaChanged = self:RegisterEntrySound(entry)
    if not injectedValue then return nil, registerStatus end
    local readiness = NS.Core.EUISoundRegistry:GetNativeReadiness(entry)
    if readiness == "invalid_path" or readiness == "sharedmedia_missing" then return nil, readiness end
    local target, actualKey, targetStatus = ResolveTarget(context, family, lookupID, false)
    if targetStatus and identifier.objectType ~= "item" then return nil, targetStatus end
    local current = type(target) == "table" and rawget(target, field) or nil
    local records = GetRecordTable(context.profileKey, context.specKey, identifier.recordID, false)
    local record = records and records[trigger] or nil
    local owned = IsOwnedValue(current) or (type(record) == "table" and current == record.injectedValue)
    if not IsEmpty(current) and current ~= injectedValue and not owned and overwrite ~= true then return nil, "conflict" end
    local status = (identifier.objectType == "spell" and not IsSkillPresent(context, lookupID)) and "waiting_for_skill"
        or readiness == "requires_reload" and "requires_reload"
        or (identifier.objectType == "item" and "item_id_injected")
        or (family == "customActiveStates" and "custom_state_injected" or "native_ready")
    return {
        entry = entry,
        spellID = lookupID,
        recordID = identifier.recordID,
        objectType = identifier.objectType,
        inputID = identifier.inputID,
        itemID = identifier.itemID,
        euiItemID = identifier.euiItemID,
        itemMatchType = identifier.itemMatchType,
        lookupID = lookupID,
        lookupType = identifier.lookupType,
        trigger = trigger,
        field = field,
        family = family,
        actualKey = actualKey,
        injectedValue = injectedValue,
        current = current,
        record = record,
        fieldChanged = current ~= injectedValue,
        mediaChanged = mediaChanged == true,
        resolvedPath = NS.Core.EUISoundRegistry:ResolveSoundPath(entry),
        requiresReload = readiness == "requires_reload",
        registeredBeforeEUI = entry.registeredBeforeEUI == true,
    }, status
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

local function ApplyPlan(context, plan)
    local target, actualKey, targetStatus = ResolveTarget(
        context, plan.family, plan.lookupID, true, plan.objectType == "item"
    )
    if type(target) ~= "table" then return false, targetStatus or "unsupported_structure" end
    local sameRecordedTarget = type(plan.record) == "table" and plan.record.family == plan.family
        and plan.record.field == plan.field
        and (plan.family ~= "customActiveStates" or plan.record.customStateKey == nil
            or plan.record.customStateKey == actualKey)
    local staleChanged = false
    if type(plan.record) == "table" and not sameRecordedTarget then
        local oldTarget = ResolveCurrentRecordTarget(context, plan.record, plan.recordID)
        if type(oldTarget) == "table" and oldTarget[plan.record.field] == plan.record.injectedValue then
            oldTarget[plan.record.field] = plan.record.previousValue
            staleChanged = true
        end
    end
    local previousValue = sameRecordedTarget and plan.record.previousValue or plan.current
    if sameRecordedTarget and plan.current ~= plan.record.injectedValue and not IsOwnedValue(plan.current) then
        previousValue = plan.current
    end
    if plan.fieldChanged then target[plan.field] = plan.injectedValue end
    local records = GetRecordTable(context.profileKey, context.specKey, plan.recordID, true)
    records[plan.trigger] = {
        entryUID = tostring(plan.entry.entryUID or ""),
        profileKey = context.profileKey,
        specKey = context.specKey,
        spellID = plan.objectType == "spell" and plan.lookupID or nil,
        objectType = plan.objectType,
        inputID = plan.inputID,
        itemID = plan.itemID,
        euiItemID = plan.euiItemID,
        itemMatchType = plan.itemMatchType,
        lookupID = plan.lookupID,
        lookupType = plan.lookupType,
        triggerType = plan.trigger,
        soundPath = plan.resolvedPath,
        soundKey = plan.injectedValue,
        previousValue = previousValue,
        injectedValue = plan.injectedValue,
        injectedAtVersion = NS.VERSION or "1.0.3",
        family = plan.family,
        field = plan.field,
        customStateKey = plan.family == "customActiveStates" and (actualKey or plan.actualKey) or nil,
        registeredBeforeEUI = plan.registeredBeforeEUI,
        requiresReload = plan.requiresReload,
    }
    plan.entry.requiresReload = plan.requiresReload
    return staleChanged or plan.fieldChanged == true or plan.mediaChanged == true, nil
end

local function NewStats()
    return { targetCount = 0, injected = 0, upToDate = 0, waiting = 0, conflict = 0, invalidSound = 0, unsupported = 0, disabled = 0, reloadRequired = 0, changed = false }
end

local function CountStatus(stats, status)
    if status == "native_ready" or status == "preseeded" or status == "custom_state_injected" or status == "item_id_injected" then stats.injected = stats.injected + 1
    elseif status == "up_to_date" then stats.upToDate = stats.upToDate + 1
    elseif status == "waiting_for_eui" or status == "eui_missing" or status == "module_not_loaded" or status == "waiting_for_spec" or status == "waiting_for_eui_custom_state" or status == "waiting_for_skill" or status == "waiting_for_item_target"
        or status == "waiting_combat" or status == "saved_waiting_sync" then stats.waiting = stats.waiting + 1
    elseif status == "requires_reload" then stats.reloadRequired = stats.reloadRequired + 1
    elseif status == "conflict" then stats.conflict = stats.conflict + 1
    elseif status == "invalid_path" or status == "sharedmedia_missing" then stats.invalidSound = stats.invalidSound + 1
    elseif status == "unsupported_entry_type" or status == "unsupported_structure" or status == "invalid_item_id" then stats.unsupported = stats.unsupported + 1
    elseif status == "disabled" then stats.disabled = stats.disabled + 1 end
end

function Integration:PreseedDatabaseEntry(entry, classID, specID)
    local bridge = NS.Core and NS.Core.BootstrapBridge
    if not bridge then return false, "waiting_for_eui" end
    return bridge:PreseedEntry(entry, classID, specID)
end

function Integration:InjectEntry(entry, overwrite, noRefresh)
    local classID, specID = 0, tonumber(GetSpecKey())
    if type(NS.GetCurrentClassSpec) == "function" then classID, specID = NS:GetCurrentClassSpec() end
    return self:InjectEntryToSpec(entry, classID, specID, overwrite, noRefresh)
end

function Integration:InjectEntryToSpec(entry, classID, specID, overwrite, noRefresh)
    if InCombatLockdown and InCombatLockdown() then
        if NS.RequestEUISync then NS:RequestEUISync("COMBAT_SAVE") end
        return false, "waiting_combat", false
    end
    local ok, result, status, changed = pcall(function()
        local context, contextStatus = ResolveContextForSpec(specID, true)
        if not context then return false, contextStatus, false end
        local plan, planStatus = BuildPlan(self, context, entry, overwrite)
        if not plan then return false, planStatus, false end
        local applied, applyStatus = ApplyPlan(context, plan)
        if applyStatus then return false, applyStatus, false end
        local currentSpecKey = GetSpecKey()
        if applied and not plan.requiresReload and not noRefresh and tostring(context.specKey) == tostring(currentSpecKey) then self:Refresh() end
        return true, planStatus, applied
    end)
    if not ok then return false, "unsupported_structure", false end
    return result, status or (result and "native_ready" or "pending"), changed == true
end

function Integration:InjectEntryToTargets(entry, targets, overwrite, noRefresh)
    targets = type(targets) == "table" and targets or {}
    local stats, results = NewStats(), {}
    stats.targetCount = #targets
    if InCombatLockdown and InCombatLockdown() then
        stats.waiting = #targets
        return results, "waiting_combat", stats
    end
    local currentSpecKey = GetSpecKey()
    local refreshRequired, seenCustom = false, {}
    for _, target in ipairs(targets) do
        local specID = tonumber(target and target.specID)
        local context, contextStatus = ResolveContextForSpec(specID, true)
        local status, applied = contextStatus or "pending", false
        if context then
            local plan, planStatus = BuildPlan(self, context, entry, overwrite)
            status = planStatus or "pending"
            if plan then
                if not plan.fieldChanged and not plan.mediaChanged then status = "up_to_date" end
                local customKey = plan.family == "customActiveStates" and table.concat({ context.profileKey, plan.lookupID, plan.trigger }, ":") or nil
                if customKey and seenCustom[customKey] then
                    status = "up_to_date"
                else
                    if customKey then seenCustom[customKey] = true end
                    local applyStatus
                    applied, applyStatus = ApplyPlan(context, plan)
                    if applyStatus then status = applyStatus end
                    if applied and not plan.requiresReload and (plan.family == "customActiveStates" or tostring(context.specKey) == tostring(currentSpecKey)) then
                        refreshRequired = true
                    end
                end
            end
        end
        results[specID or tostring(#results + 1)] = status
        CountStatus(stats, status)
        stats.changed = applied or stats.changed
    end
    if refreshRequired and not noRefresh then self:Refresh() end
    stats.refreshRequired = refreshRequired
    return results, "batch_complete", stats
end

function Integration:InjectAllTargets(entries, overwrite)
    entries = type(entries) == "table" and entries or {}
    local total, output, refreshRequired = NewStats(), {}
    local resolver = NS.Core and NS.Core.ScopeResolver
    for _, entry in ipairs(entries) do
        local targets = resolver and resolver:ResolveEntryTargets(entry) or {}
        local _, status, stats = self:InjectEntryToTargets(entry, targets, overwrite, true)
        output[entry] = status
        entry.injectionStatus = status
        entry.injectionStats = {
            targetCount = tonumber(stats.targetCount) or 0,
            injected = tonumber(stats.injected) or 0,
            upToDate = tonumber(stats.upToDate) or 0,
            waiting = tonumber(stats.waiting) or 0,
            conflict = tonumber(stats.conflict) or 0,
            invalidSound = tonumber(stats.invalidSound) or 0,
            unsupported = tonumber(stats.unsupported) or 0,
            reloadRequired = tonumber(stats.reloadRequired) or 0,
        }
        for _, key in ipairs({ "targetCount", "injected", "upToDate", "waiting", "conflict", "invalidSound", "unsupported", "disabled", "reloadRequired" }) do
            total[key] = (tonumber(total[key]) or 0) + (tonumber(stats[key]) or 0)
        end
        total.changed = stats.changed == true or total.changed
        refreshRequired = stats.refreshRequired == true or refreshRequired
    end
    if refreshRequired then self:Refresh() end
    return output, "complete", total
end

function Integration:InjectAll(entries, overwrite)
    entries = type(entries) == "table" and entries or {}
    local stats = NewStats()
    if InCombatLockdown and InCombatLockdown() then
        if NS.RequestEUISync then NS:RequestEUISync("COMBAT_BATCH") end
        local waiting = {}
        for _, entry in ipairs(entries) do waiting[entry] = "waiting_combat"; CountStatus(stats, "waiting_combat") end
        return waiting, "waiting_combat", stats
    end
    local ok, results, status = pcall(function()
        local context, contextStatus = ResolveContext(true)
        if not context then return nil, contextStatus end
        local plans, output = {}, {}
        for _, entry in ipairs(entries) do
            local plan, planStatus = BuildPlan(self, context, entry, overwrite)
            output[entry] = planStatus or "pending"
            if plan then plans[#plans + 1] = plan end
            CountStatus(stats, output[entry])
        end
        local changed, liveChanged = false, false
        for _, plan in ipairs(plans) do
            local applied, applyStatus = ApplyPlan(context, plan)
            if applyStatus then
                output[plan.entry] = applyStatus
                CountStatus(stats, applyStatus)
            end
            changed = applied or changed
            if applied and not plan.requiresReload then liveChanged = true end
        end
        stats.changed = changed
        if liveChanged then self:Refresh() end
        return output, "complete"
    end)
    if not ok then return {}, "unsupported_structure", stats end
    if not results then return {}, status, stats end
    return results, status, stats
end

local function ResolveRecordedTarget(root, profileKey, specKey, spellID, record)
    if record.family == "customActiveStates" then
        local profile = type(root.profiles) == "table" and root.profiles[profileKey] or nil
        local cdm = type(profile) == "table" and type(profile.addons) == "table" and profile.addons.EllesmereUICooldownManager or nil
        local states = type(cdm) == "table" and cdm.customActiveStates or nil
        local key = record.customStateKey or record.lookupID
        return type(states) == "table" and (states[key] or states[spellID] or states[tostring(spellID)]) or nil
    end
    local assignments = root.spellAssignments
    local profiles = type(assignments) == "table" and assignments.profiles or nil
    local bucket = type(profiles) == "table" and profiles[profileKey] or nil
    local specProfiles = type(bucket) == "table" and bucket.specProfiles or nil
    local specProfile = type(specProfiles) == "table" and (specProfiles[specKey] or specProfiles[tostring(specKey)]) or nil
    local store = type(specProfile) == "table" and specProfile[record.family] or nil
    return type(store) == "table" and (store[spellID] or store[tostring(spellID)]) or nil
end

function Integration:RemoveEntryFromAllRecordedScopes(entryOrUID, noRefresh)
    if InCombatLockdown and InCombatLockdown() then
        if type(entryOrUID) == "table" and NS.QueueEUIRemoval then NS:QueueEUIRemoval(entryOrUID) end
        return false, "waiting_combat", false
    end
    local ok, removed, status, changed = pcall(function()
        local root = rawget(_G, "EllesmereUIDB")
        if type(root) ~= "table" then return false, "waiting_for_eui", false end
        local db = rawget(_G, "EllesmereUIVEDB")
        local rootRecords = type(db) == "table" and db.euiInjectionRecords or nil
        local entryUID = tostring(type(entryOrUID) == "table" and entryOrUID.entryUID or entryOrUID or "")
        if entryUID == "" then return false, "removed", false end
        local currentProfile, currentSpec = self:GetCurrentProfileKey(), self:GetCurrentSpecKey()
        local found, currentChanged = false, false
        for profileKey, specs in pairs(type(rootRecords) == "table" and rootRecords or {}) do
            for specKey, spells in pairs(type(specs) == "table" and specs or {}) do
                for recordedSpellID, triggers in pairs(type(spells) == "table" and spells or {}) do
                    for recordedTrigger, record in pairs(type(triggers) == "table" and triggers or {}) do
                        local uidMatches = tostring(type(record) == "table" and record.entryUID or "") == entryUID
                        if type(record) == "table" and uidMatches then
                            found = true
                            local target = ResolveRecordedTarget(root, profileKey, specKey, tonumber(recordedSpellID), record)
                            if type(target) == "table" and target[record.field] == record.injectedValue then
                                target[record.field] = record.previousValue
                                if tostring(profileKey) == tostring(currentProfile)
                                    and (record.family == "customActiveStates" or tostring(specKey) == tostring(currentSpec)) then currentChanged = true end
                            end
                            triggers[recordedTrigger] = nil
                        end
                    end
                end
            end
        end
        if currentChanged and not noRefresh then self:Refresh() end
        return found, "removed", currentChanged
    end)
    if not ok then return false, "unsupported_structure", false end
    return removed, status, changed == true
end

function Integration:RemoveEntry(entry, noRefresh)
    local uid = type(entry) == "table" and entry.entryUID or entry
    if uid ~= nil and tostring(uid) ~= "" then
        return self:RemoveEntryFromAllRecordedScopes(entry, noRefresh)
    end
    return false, "removed", false
end

function Integration:GetInjectionStatus(entry)
    if not EntryEnabled(entry) then return "disabled" end
    if tostring(entry.injectionStatus or "") == "batch_complete" and type(entry.injectionStats) == "table" then return "batch_complete" end
    if NS.pendingEUISync and InCombatLockdown and InCombatLockdown() then return "waiting_combat" end
    if tostring(entry.soundSource or "") == "tts" or tostring(entry.notifyMode or "") == "tts" then return "unsupported_tts" end
    if type(NS.GetCurrentClassSpec) == "function" then
        local currentClassID, currentSpecID = NS:GetCurrentClassSpec()
        local raceID = type(NS.GetCurrentRaceID) == "function" and NS:GetCurrentRaceID() or 0
        local resolver = NS.Core and NS.Core.ScopeResolver
        if resolver and not resolver:EntryMatchesScope(entry, currentClassID, currentSpecID, raceID) then return "waiting_for_spec" end
    end
    local readiness = NS.Core.EUISoundRegistry:GetNativeReadiness(entry)
    if readiness == "invalid_path" or readiness == "sharedmedia_missing" then return readiness end
    local context, status = ResolveContext(false)
    if not context then return status end
    local trigger = tostring(entry.euiTriggerType or "cdReady")
    local field = FIELD_BY_TRIGGER[trigger]
    if not field then return "unsupported_entry_type" end
    local identifier, identifierStatus = ResolveManagedIdentifier(context, entry)
    if not identifier then return identifierStatus end
    local family, lookupID = identifier.family, identifier.lookupID
    local target, _, targetStatus = ResolveTarget(context, family, lookupID, false)
    if targetStatus then return targetStatus end
    local value = type(target) == "table" and target[field] or nil
    local records = GetRecordTable(context.profileKey, context.specKey, identifier.recordID, false)
    local record = records and records[trigger] or nil
    if type(record) == "table" and value == record.injectedValue then
        if identifier.objectType == "spell" and not IsSkillPresent(context, lookupID) then return "waiting_for_skill" end
        if readiness == "requires_reload" or record.requiresReload == true then return "requires_reload" end
        if identifier.objectType == "item" then return "item_id_injected" end
        return family == "customActiveStates" and "custom_state_injected" or "native_ready"
    end
    if not IsEmpty(value) and not IsOwnedValue(value) then return "conflict" end
    return "saved_waiting_sync"
end

function Integration:Refresh()
    if InCombatLockdown and InCombatLockdown() then
        if NS.RequestEUISync then NS:RequestEUISync("COMBAT_REFRESH") end
        return false
    end
    local apply = rawget(_G, "_ECME_Apply")
    if type(apply) ~= "function" then return false end
    NS.internalApplyInProgress = true
    local ok = pcall(apply)
    NS.internalApplyInProgress = false
    return ok
end

Integration.GetManagedEntries = Integration.GetManagedSpells
Integration.SyncCurrentSpec = Integration.InjectAll
Integration.GetEntryStatus = Integration.GetInjectionStatus

function Integration:FindManagedTarget(spellID, trigger, entry)
    local context, status = ResolveContext(false)
    if not context then return nil, status end
    entry = entry or { spellId = spellID, euiTriggerType = trigger or "cdReady" }
    local identifier, identifierStatus = ResolveManagedIdentifier(context, entry)
    if not identifier then return nil, identifierStatus end
    local target, _, targetStatus = ResolveTarget(context, identifier.family, identifier.lookupID, false)
    if targetStatus then return nil, targetStatus end
    return target, identifier.family
end

Integration.ResolveFamily = ResolveTargetFamily
function Integration:ResolveManagedIdentifier(entry, specID)
    local context, status = specID and ResolveContextForSpec(specID, false) or ResolveContext(false)
    if not context then return nil, status end
    return ResolveManagedIdentifier(context, entry)
end
function Integration:ResolveRootProfile(create) return ResolveRootProfile(create) end
function Integration:ResolveContextForSpec(specID, create) return ResolveContextForSpec(specID, create) end
