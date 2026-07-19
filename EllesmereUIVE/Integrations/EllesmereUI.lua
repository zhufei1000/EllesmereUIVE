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

local function ResolveContext(create)
    if not AddOnLoaded("EllesmereUI") then return nil, "waiting_for_eui" end
    if not AddOnLoaded("EllesmereUICooldownManager") and not TryLoadCooldownManager() then return nil, "module_not_loaded" end
    local root = rawget(_G, "EllesmereUIDB")
    if type(root) ~= "table" then return nil, "waiting_for_eui" end
    local profileKey = tostring(root.activeProfile or "Default")
    local specKey = GetSpecKey()
    if not specKey then return nil, "waiting_for_spec" end
    if create then
        root.spellAssignments = type(root.spellAssignments) == "table" and root.spellAssignments or {}
        root.spellAssignments.profiles = type(root.spellAssignments.profiles) == "table" and root.spellAssignments.profiles or {}
        root.spellAssignments.profiles[profileKey] = type(root.spellAssignments.profiles[profileKey]) == "table"
            and root.spellAssignments.profiles[profileKey] or {}
        local bucket = root.spellAssignments.profiles[profileKey]
        bucket.specProfiles = type(bucket.specProfiles) == "table" and bucket.specProfiles or {}
        bucket.specProfiles[specKey] = type(bucket.specProfiles[specKey]) == "table" and bucket.specProfiles[specKey] or { barSpells = {} }
    end
    local assignments = root.spellAssignments
    local profiles = type(assignments) == "table" and assignments.profiles or nil
    local bucket = type(profiles) == "table" and profiles[profileKey] or nil
    local specProfiles = type(bucket) == "table" and bucket.specProfiles or nil
    local specProfile = type(specProfiles) == "table" and (specProfiles[specKey] or specProfiles[tonumber(specKey)]) or nil
    if create and type(specProfile) ~= "table" then return nil, "unsupported_structure" end
    local profile = type(root.profiles) == "table" and root.profiles[profileKey] or nil
    local cdmProfile = type(profile) == "table" and type(profile.addons) == "table"
        and profile.addons.EllesmereUICooldownManager or nil
    return {
        root = root,
        profileKey = profileKey,
        specKey = specKey,
        specProfiles = specProfiles,
        specProfile = specProfile,
        cdmProfile = cdmProfile,
    }
end

local function EnsureCDMProfile(context)
    local root = context.root
    root.profiles = type(root.profiles) == "table" and root.profiles or {}
    root.profiles[context.profileKey] = type(root.profiles[context.profileKey]) == "table" and root.profiles[context.profileKey] or {}
    local profile = root.profiles[context.profileKey]
    profile.addons = type(profile.addons) == "table" and profile.addons or {}
    profile.addons.EllesmereUICooldownManager = type(profile.addons.EllesmereUICooldownManager) == "table"
        and profile.addons.EllesmereUICooldownManager or {}
    context.cdmProfile = profile.addons.EllesmereUICooldownManager
    return context.cdmProfile
end

local function DecodeManagedID(value)
    value = tonumber(value)
    if not value then return nil end
    if value <= -HOSTED_BUFF_MARKER_BASE then return -value - HOSTED_BUFF_MARKER_BASE end
    return value > 0 and value or nil
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

local function ResolveFamily(context, entry, spellID)
    local trigger = tostring(entry.euiTriggerType or "cdReady")
    local explicit = tostring(entry.euiTargetFamily or "")
    if trigger == "buffGain" or trigger == "buffLoss" then
        if explicit == "custom" then return nil, "unsupported_entry_type" end
        return explicit == "cd" and "spellSettingsCD" or "spellSettingsBuff"
    end
    local custom = FindCustomState(context, spellID)
    if explicit == "custom" or (custom and explicit ~= "buff") then return "customActiveStates" end
    if explicit == "buff" then return "spellSettingsBuff" end
    if explicit == "cd" then return "spellSettingsCD" end
    local foundCD, foundBuff = DiscoverFamilies(context.specProfile, spellID)
    if foundCD then return "spellSettingsCD" end
    if foundBuff then return "spellSettingsBuff" end
    return "spellSettingsCD"
end

local function ResolveTarget(context, family, spellID, create)
    if family == "customActiveStates" then
        local target, key, states = FindCustomState(context, spellID)
        if not target and create then
            local cdm = EnsureCDMProfile(context)
            cdm.customActiveStates = type(cdm.customActiveStates) == "table" and cdm.customActiveStates or {}
            states, key = cdm.customActiveStates, spellID
            states[key] = {}
            target = states[key]
        end
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
    if tostring(entry.objectType or "spell") ~= "spell" then return nil, "unsupported_entry_type" end
    local spellID = tonumber(entry.spellId)
    local trigger = tostring(entry.euiTriggerType or "cdReady")
    local field = FIELD_BY_TRIGGER[trigger]
    if not spellID or spellID <= 0 or not field then return nil, "unsupported_entry_type" end
    local family, familyStatus = ResolveFamily(context, entry, spellID)
    if not family then return nil, familyStatus end
    if family == "customActiveStates" and trigger ~= "cdReady" then return nil, "unsupported_entry_type" end
    local injectedValue, registerStatus, mediaChanged = self:RegisterEntrySound(entry)
    if not injectedValue then return nil, registerStatus end
    local readiness = NS.Core.EUISoundRegistry:GetNativeReadiness(entry)
    if readiness == "invalid_path" or readiness == "sharedmedia_missing" then return nil, readiness end
    local target, actualKey = ResolveTarget(context, family, spellID, false)
    local current = type(target) == "table" and rawget(target, field) or nil
    local records = GetRecordTable(context.profileKey, context.specKey, spellID, false)
    local record = records and records[trigger] or nil
    local owned = IsOwnedValue(current) or (type(record) == "table" and current == record.injectedValue)
    if not IsEmpty(current) and current ~= injectedValue and not owned and overwrite ~= true then return nil, "conflict" end
    local status = readiness == "requires_reload" and "requires_reload"
        or (family == "customActiveStates" and "custom_state_injected" or "native_ready")
    return {
        entry = entry,
        spellID = spellID,
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

local function ApplyPlan(context, plan)
    local target, actualKey = ResolveTarget(context, plan.family, plan.spellID, true)
    if type(target) ~= "table" then return false end
    local previousValue = type(plan.record) == "table" and plan.record.previousValue or plan.current
    if type(plan.record) == "table" and plan.current ~= plan.record.injectedValue and not IsOwnedValue(plan.current) then
        previousValue = plan.current
    end
    if plan.fieldChanged then target[plan.field] = plan.injectedValue end
    local records = GetRecordTable(context.profileKey, context.specKey, plan.spellID, true)
    records[plan.trigger] = {
        entryUID = tostring(plan.entry.entryUID or ""),
        profileKey = context.profileKey,
        specKey = context.specKey,
        spellID = plan.spellID,
        triggerType = plan.trigger,
        soundPath = plan.resolvedPath,
        soundKey = plan.injectedValue,
        previousValue = previousValue,
        injectedValue = plan.injectedValue,
        injectedAtVersion = NS.VERSION or "1.0.1",
        family = plan.family,
        field = plan.field,
        customStateKey = plan.family == "customActiveStates" and (actualKey or plan.actualKey) or nil,
        registeredBeforeEUI = plan.registeredBeforeEUI,
        requiresReload = plan.requiresReload,
    }
    plan.entry.requiresReload = plan.requiresReload
    return plan.fieldChanged == true or plan.mediaChanged == true
end

local function NewStats()
    return { injected = 0, upToDate = 0, waiting = 0, conflict = 0, invalidSound = 0, unsupported = 0, disabled = 0, reloadRequired = 0, changed = false }
end

local function CountStatus(stats, status)
    if status == "native_ready" or status == "preseeded" or status == "custom_state_injected" then stats.injected = stats.injected + 1
    elseif status == "up_to_date" then stats.upToDate = stats.upToDate + 1
    elseif status == "waiting_for_eui" or status == "waiting_for_spec" or status == "waiting_combat" or status == "saved_waiting_sync" then stats.waiting = stats.waiting + 1
    elseif status == "requires_reload" then stats.reloadRequired = stats.reloadRequired + 1
    elseif status == "conflict" then stats.conflict = stats.conflict + 1
    elseif status == "invalid_path" or status == "sharedmedia_missing" then stats.invalidSound = stats.invalidSound + 1
    elseif status == "unsupported_entry_type" then stats.unsupported = stats.unsupported + 1
    elseif status == "disabled" then stats.disabled = stats.disabled + 1 end
end

function Integration:PreseedDatabaseEntry(entry, classID, specID)
    local bridge = NS.Core and NS.Core.BootstrapBridge
    if not bridge then return false, "waiting_for_eui" end
    return bridge:PreseedEntry(entry, classID, specID)
end

function Integration:InjectEntry(entry, overwrite, noRefresh)
    if InCombatLockdown and InCombatLockdown() then
        if NS.RequestEUISync then NS:RequestEUISync("COMBAT_SAVE") end
        return false, "waiting_combat", false
    end
    local ok, result, status, changed = pcall(function()
        local context, contextStatus = ResolveContext(true)
        if not context then return false, contextStatus, false end
        local plan, planStatus = BuildPlan(self, context, entry, overwrite)
        if not plan then return false, planStatus, false end
        local applied = ApplyPlan(context, plan)
        if applied and not plan.requiresReload and not noRefresh then self:Refresh() end
        return true, planStatus, applied
    end)
    if not ok then return false, "unsupported_structure", false end
    return result, status or (result and "native_ready" or "pending"), changed == true
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
            local applied = ApplyPlan(context, plan)
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
        local key = record.customStateKey
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

function Integration:RemoveEntry(entry, noRefresh)
    if InCombatLockdown and InCombatLockdown() then
        if NS.QueueEUIRemoval then NS:QueueEUIRemoval(entry) end
        return false, "waiting_combat", false
    end
    local ok, removed, status, changed = pcall(function()
        local root = rawget(_G, "EllesmereUIDB")
        if type(root) ~= "table" then return false, "waiting_for_eui", false end
        local db = rawget(_G, "EllesmereUIVEDB")
        local rootRecords = type(db) == "table" and db.euiInjectionRecords or nil
        local entryUID = tostring(entry and entry.entryUID or "")
        local spellID = tonumber(entry and entry.spellId)
        local trigger = tostring(entry and entry.euiTriggerType or "cdReady")
        local currentProfile, currentSpec = self:GetCurrentProfileKey(), self:GetCurrentSpecKey()
        local found, currentChanged = false, false
        for profileKey, specs in pairs(type(rootRecords) == "table" and rootRecords or {}) do
            for specKey, spells in pairs(type(specs) == "table" and specs or {}) do
                for recordedSpellID, triggers in pairs(type(spells) == "table" and spells or {}) do
                    for recordedTrigger, record in pairs(type(triggers) == "table" and triggers or {}) do
                        local uidMatches = entryUID ~= "" and tostring(type(record) == "table" and record.entryUID or "") == entryUID
                        local recordUID = tostring(type(record) == "table" and record.entryUID or "")
                        local legacyMatches = recordUID == "" and tonumber(recordedSpellID) == spellID and tostring(recordedTrigger) == trigger
                        if type(record) == "table" and (uidMatches or legacyMatches) then
                            found = true
                            local target = ResolveRecordedTarget(root, profileKey, specKey, tonumber(recordedSpellID), record)
                            if type(target) == "table" and target[record.field] == record.injectedValue then
                                target[record.field] = record.previousValue
                                if tostring(profileKey) == tostring(currentProfile) and tostring(specKey) == tostring(currentSpec) then currentChanged = true end
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

function Integration:GetInjectionStatus(entry)
    if not EntryEnabled(entry) then return "disabled" end
    if NS.pendingEUISync and InCombatLockdown and InCombatLockdown() then return "waiting_combat" end
    if tostring(entry.soundSource or "") == "tts" or tostring(entry.notifyMode or "") == "tts" then return "unsupported_tts" end
    if type(NS.FindEntryScope) == "function" and type(NS.GetCurrentClassSpec) == "function" then
        local classID, specID = NS:FindEntryScope(entry)
        local currentClassID, currentSpecID = NS:GetCurrentClassSpec()
        if classID ~= nil and ((classID ~= 0 and classID ~= currentClassID) or (specID ~= 0 and specID ~= currentSpecID)) then return "waiting_for_spec" end
    end
    local readiness = NS.Core.EUISoundRegistry:GetNativeReadiness(entry)
    if readiness == "invalid_path" or readiness == "sharedmedia_missing" then return readiness end
    local context, status = ResolveContext(false)
    if not context then return status end
    local spellID = tonumber(entry.spellId)
    local trigger = tostring(entry.euiTriggerType or "cdReady")
    local field = FIELD_BY_TRIGGER[trigger]
    local family, familyStatus = ResolveFamily(context, entry, spellID)
    if not family then return familyStatus end
    local target = ResolveTarget(context, family, spellID, false)
    local value = type(target) == "table" and target[field] or nil
    local records = GetRecordTable(context.profileKey, context.specKey, spellID, false)
    local record = records and records[trigger] or nil
    if type(record) == "table" and value == record.injectedValue then
        if readiness == "requires_reload" or record.requiresReload == true then return "requires_reload" end
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
    entry = entry or { euiTriggerType = trigger or "cdReady" }
    local family, familyStatus = ResolveFamily(context, entry, tonumber(spellID))
    if not family then return nil, familyStatus end
    return ResolveTarget(context, family, tonumber(spellID), false), family
end

Integration.ResolveFamily = ResolveFamily
