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

local function ResolveContext()
    if not AddOnLoaded("EllesmereUI") then return nil, "eui_missing" end
    if not TryLoadCooldownManager() then return nil, "module_not_loaded" end
    local root = rawget(_G, "EllesmereUIDB")
    local profileKey = type(root) == "table" and tostring(root.activeProfile or "Default") or nil
    local assignments = type(root) == "table" and root.spellAssignments or nil
    local profiles = type(assignments) == "table" and assignments.profiles or nil
    local bucket = type(profiles) == "table" and profiles[profileKey] or nil
    local specProfiles = type(bucket) == "table" and bucket.specProfiles or nil
    local specKey = GetSpecKey()
    if not profileKey or not specKey or type(specProfiles) ~= "table" then
        return nil, "unsupported_structure"
    end
    return {
        root = root,
        profileKey = profileKey,
        specKey = specKey,
        specProfiles = specProfiles,
        specProfile = specProfiles[specKey],
        cdmProfile = root.profiles and root.profiles[profileKey] and root.profiles[profileKey].addons
            and root.profiles[profileKey].addons.EllesmereUICooldownManager or nil,
    }
end

local function DecodeManagedID(value)
    value = tonumber(value)
    if not value then return nil end
    if value <= -HOSTED_BUFF_MARKER_BASE then return -value - HOSTED_BUFF_MARKER_BASE end
    return value > 0 and value or nil
end

local function ManagedSetContains(managed, spellID)
    if type(managed) ~= "table" then return false end
    if managed[spellID] or managed[tostring(spellID)] then return true end
    for _, value in ipairs(managed) do if tonumber(value) == spellID then return true end end
    return false
end

local function DiscoverFamilies(specProfile, spellID)
    local foundCD, foundBuff = false, false
    if type(specProfile) ~= "table" then return false, false end
    for barKey, barData in pairs(type(specProfile.barSpells) == "table" and specProfile.barSpells or {}) do
        if type(barData) == "table" and type(barData.assignedSpells) == "table" then
            for _, rawID in ipairs(barData.assignedSpells) do
                if DecodeManagedID(rawID) == spellID then
                    if tonumber(rawID) and tonumber(rawID) <= -HOSTED_BUFF_MARKER_BASE then
                        foundCD = true
                    elseif tostring(barKey):lower():find("buff", 1, true) then
                        foundBuff = true
                    else
                        foundCD = true
                    end
                end
            end
        end
    end
    return foundCD, foundBuff
end

local function ResolveFamily(specProfile, spellID, trigger)
    local foundCD, foundBuff = DiscoverFamilies(specProfile, spellID)
    if not foundCD and not foundBuff then
        local getter = rawget(_G, "_ECME_GetCDMSpellSet")
        local ok, managed = false, nil
        if type(getter) == "function" then ok, managed = pcall(getter) end
        if not ManagedSetContains(managed, spellID) then return nil end
        return (trigger == "buffGain" or trigger == "buffLoss") and "spellSettingsBuff" or "spellSettingsCD"
    end
    if trigger == "buffGain" or trigger == "buffLoss" then
        return foundBuff and "spellSettingsBuff" or "spellSettingsCD"
    end
    return foundCD and "spellSettingsCD" or "spellSettingsBuff"
end

local function GetRecordTable(profileKey, specKey, spellID, trigger, create)
    local db = rawget(_G, "EllesmereUIVEDB")
    if type(db) ~= "table" then return nil end
    if type(db.euiInjectionRecords) ~= "table" then
        if not create then return nil end
        db.euiInjectionRecords = {}
    end
    local root = db.euiInjectionRecords
    if create then
        root[profileKey] = root[profileKey] or {}
        root[profileKey][specKey] = root[profileKey][specKey] or {}
        root[profileKey][specKey][spellID] = root[profileKey][specKey][spellID] or {}
    end
    return root[profileKey] and root[profileKey][specKey] and root[profileKey][specKey][spellID]
end

local function BuildStaleRemoval(context, spellID, trigger)
    local records = GetRecordTable(context.profileKey, context.specKey, spellID, trigger, false)
    local record = records and records[trigger] or nil
    if not record then return nil end
    return { spellID = spellID, trigger = trigger, record = record, records = records }
end

local function ApplyStaleRemoval(context, removal)
    local record = removal.record
    local store = type(context.specProfile) == "table" and context.specProfile[record.family] or nil
    local target = type(store) == "table" and store[removal.spellID] or nil
    local changed = false
    if type(target) == "table" and target[record.field] == record.injectedValue then
        target[record.field] = record.previousValue
        changed = true
    end
    removal.records[removal.trigger] = nil
    return changed
end

local function IsEmpty(value)
    return value == nil or value == false or value == "" or value == "none"
end

local function IsOwnedValue(value)
    return type(value) == "string" and value:find("^sm:EUIVE_") ~= nil
end

function Integration:IsAvailable()
    local context, status = ResolveContext()
    return context ~= nil, status or "available"
end

function Integration:GetVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata("EllesmereUI", "Version") or "unknown"
    end
    return "unknown"
end

function Integration:GetCurrentProfileKey()
    local context = ResolveContext()
    return context and context.profileKey or nil
end

function Integration:GetCurrentSpecKey()
    local context = ResolveContext()
    return context and context.specKey or nil
end

function Integration:GetManagedSpells()
    local context, status = ResolveContext()
    if not context then return {}, status end
    local result = {}
    local profile = context.specProfile
    for _, barData in pairs(type(profile) == "table" and type(profile.barSpells) == "table" and profile.barSpells or {}) do
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

function Integration:BuildSoundKey(entry, specKey)
    return NS.Core.EUISoundRegistry:BuildStableSoundKey(entry)
end

function Integration:RegisterEntrySound(entry, specKey)
    return NS.Core.EUISoundRegistry:RegisterEntry(entry)
end

local function BuildPlan(self, context, entry, overwrite)
    if not EntryEnabled(entry) then return nil, "disabled" end
    if tostring(entry.objectType or "spell") ~= "spell" then return nil, "unsupported_entry_type" end
    local spellID = tonumber(entry.spellId)
    local trigger = tostring(entry.euiTriggerType or "cdReady")
    local field = FIELD_BY_TRIGGER[trigger]
    if not spellID or spellID <= 0 or not field then return nil, "unsupported_entry_type" end
    local family = ResolveFamily(context.specProfile, spellID, trigger)
    if not family then
        return nil, "waiting_for_eui_spell", BuildStaleRemoval(context, spellID, trigger)
    end
    local activeStates = type(context.cdmProfile) == "table" and context.cdmProfile.customActiveStates or nil
    if type(activeStates) == "table" and (activeStates[spellID] or activeStates[tostring(spellID)]) then
        return nil, "unsupported_entry_type"
    end
    local injectedValue, registerStatus = self:RegisterEntrySound(entry, context.specKey)
    if not injectedValue then return nil, registerStatus end
    local resolvedPath = NS.Core.EUISoundRegistry:ResolveSoundPath(entry)
    local specProfile = context.specProfile
    local store = type(specProfile) == "table" and specProfile[family] or nil
    local target = type(store) == "table" and store[spellID] or nil
    local current = type(target) == "table" and target[field] or nil
    local previousOwn = type(target) == "table" and rawget(target, field) or nil
    local records = GetRecordTable(context.profileKey, context.specKey, spellID, trigger, false)
    local record = records and records[trigger] or nil
    local mediaChanged = record and tostring(record.soundPath or "") ~= tostring(resolvedPath or "") or false
    if current == injectedValue then
        return {
            entry = entry, spellID = spellID, trigger = trigger, field = field, family = family,
            injectedValue = injectedValue, current = current, previousOwn = previousOwn, record = record,
            fieldChanged = false, mediaChanged = mediaChanged, resolvedPath = resolvedPath,
        }, mediaChanged and "injected" or "up_to_date"
    end
    local owned = IsOwnedValue(current) or (record and current == record.injectedValue)
    if not IsEmpty(current) and not owned and overwrite ~= true then return nil, "conflict" end
    return {
        entry = entry, spellID = spellID, trigger = trigger, field = field, family = family,
        injectedValue = injectedValue, current = current, previousOwn = previousOwn, record = record,
        fieldChanged = current ~= injectedValue, mediaChanged = mediaChanged, resolvedPath = resolvedPath,
    }, "injected"
end

local function ApplyPlan(context, plan)
    local specProfile = context.specProfile
    specProfile[plan.family] = specProfile[plan.family] or {}
    local store = specProfile[plan.family]
    store[plan.spellID] = store[plan.spellID] or {}
    local target = store[plan.spellID]
    local previous = plan.record and plan.record.previousValue or plan.previousOwn
    if not plan.record and not plan.fieldChanged then previous = nil end
    if plan.record and plan.current ~= plan.record.injectedValue and not IsOwnedValue(plan.current) then previous = plan.previousOwn end
    if plan.fieldChanged then target[plan.field] = plan.injectedValue end
    local records = GetRecordTable(context.profileKey, context.specKey, plan.spellID, plan.trigger, true)
    records[plan.trigger] = {
        entryUID = tostring(plan.entry.entryUID or ""),
        profileKey = context.profileKey,
        specKey = context.specKey,
        spellID = plan.spellID,
        triggerType = plan.trigger,
        soundPath = plan.resolvedPath,
        soundKey = plan.injectedValue,
        previousValue = previous,
        injectedValue = plan.injectedValue,
        injectedAtVersion = NS.VERSION or "1.0.0",
        family = plan.family,
        field = plan.field,
    }
    return plan.fieldChanged == true or plan.mediaChanged == true
end

local function NewStats()
    return { injected = 0, upToDate = 0, waiting = 0, conflict = 0, invalidSound = 0, unsupported = 0, disabled = 0, changed = false }
end

local function CountStatus(stats, status)
    if status == "injected" then stats.injected = stats.injected + 1
    elseif status == "up_to_date" then stats.upToDate = stats.upToDate + 1
    elseif status == "waiting_for_eui_spell" or status == "waiting_for_spec" or status == "saved_waiting_sync" then stats.waiting = stats.waiting + 1
    elseif status == "conflict" then stats.conflict = stats.conflict + 1
    elseif status == "invalid_path" then stats.invalidSound = stats.invalidSound + 1
    elseif status == "unsupported_entry_type" then stats.unsupported = stats.unsupported + 1
    elseif status == "disabled" then stats.disabled = stats.disabled + 1 end
end

function Integration:InjectEntry(entry, overwrite, noRefresh)
    self:RegisterEntrySound(entry)
    if InCombatLockdown and InCombatLockdown() then
        if NS.RequestEUISync then NS:RequestEUISync("COMBAT_SAVE") end
        return false, "waiting_combat"
    end
    local ok, result, status, fieldChanged = pcall(function()
        local context, contextStatus = ResolveContext()
        if not context then return false, contextStatus end
        if type(context.specProfile) ~= "table" then return false, "waiting_for_eui_spell" end
        local plan, planStatus, staleRemoval = BuildPlan(self, context, entry, overwrite)
        if not plan then
            local changed = staleRemoval and ApplyStaleRemoval(context, staleRemoval) or false
            if changed and not noRefresh then self:Refresh() end
            return false, planStatus, changed
        end
        local changed = ApplyPlan(context, plan)
        if changed and not noRefresh then self:Refresh() end
        return true, planStatus, changed
    end)
    if not ok then result, status, fieldChanged = false, "unsupported_structure", false end
    return result, status or (result and "injected" or "pending"), fieldChanged == true
end

function Integration:InjectAll(entries, overwrite)
    entries = type(entries) == "table" and entries or {}
    local stats = NewStats()
    for _, entry in ipairs(entries) do self:RegisterEntrySound(entry) end
    if InCombatLockdown and InCombatLockdown() then
        if NS.RequestEUISync then NS:RequestEUISync("COMBAT_BATCH") end
        local waiting = {}
        for _, entry in ipairs(entries) do waiting[entry] = "waiting_combat" end
        return waiting, "waiting_combat", stats
    end
    local ok, results, status = pcall(function()
        local context, contextStatus = ResolveContext()
        if not context then return nil, contextStatus, stats end
        if type(context.specProfile) ~= "table" then
            local output = {}
            for _, entry in ipairs(entries) do output[entry] = "waiting_for_eui_spell"; CountStatus(stats, "waiting_for_eui_spell") end
            return output, "complete", stats
        end
        local plans, staleRemovals, output = {}, {}, {}
        for _, entry in ipairs(entries) do
            local plan, planStatus, staleRemoval = BuildPlan(self, context, entry, overwrite)
            output[entry] = planStatus or "pending"
            if plan then plans[#plans + 1] = plan end
            if staleRemoval then staleRemovals[#staleRemovals + 1] = staleRemoval end
            CountStatus(stats, output[entry])
        end
        -- Validation is complete before this write phase, preventing partial
        -- mutations caused by an unsupported structure discovered mid-batch.
        local changed = false
        for _, removal in ipairs(staleRemovals) do changed = ApplyStaleRemoval(context, removal) or changed end
        for _, plan in ipairs(plans) do changed = ApplyPlan(context, plan) or changed end
        stats.changed = changed
        if changed then self:Refresh() end
        return output, "complete", stats
    end)
    if not ok then return {}, "unsupported_structure", stats end
    if not results then
        return {}, status, stats
    end
    return results, status, stats
end

function Integration:RemoveEntry(entry, noRefresh)
    if InCombatLockdown and InCombatLockdown() then
        if NS.QueueEUIRemoval then NS:QueueEUIRemoval(entry) end
        return false, "waiting_combat"
    end
    local ok, removed, status, fieldChanged = pcall(function()
        local context, contextStatus = ResolveContext()
        if not context then return false, contextStatus, false end
        local spellID = tonumber(entry and entry.spellId)
        local trigger = tostring(entry and entry.euiTriggerType or "cdReady")
        local entryUID = tostring(entry and entry.entryUID or "")
        local db = rawget(_G, "EllesmereUIVEDB")
        local rootRecords = type(db) == "table" and db.euiInjectionRecords or nil
        local assignments = type(context.root) == "table" and context.root.spellAssignments or nil
        local profiles = type(assignments) == "table" and assignments.profiles or nil
        local found, currentChanged = false, false
        for profileKey, specs in pairs(type(rootRecords) == "table" and rootRecords or {}) do
            for specKey, spells in pairs(type(specs) == "table" and specs or {}) do
                for recordedSpellID, triggers in pairs(type(spells) == "table" and spells or {}) do
                    for recordedTrigger, record in pairs(type(triggers) == "table" and triggers or {}) do
                        local uidMatches = entryUID ~= "" and tostring(type(record) == "table" and record.entryUID or "") == entryUID
                        local legacyMatches = tostring(profileKey) == tostring(context.profileKey)
                            and tostring(specKey) == tostring(context.specKey)
                            and tonumber(recordedSpellID) == spellID and tostring(recordedTrigger) == trigger
                        if type(record) == "table" and (uidMatches or legacyMatches) then
                            found = true
                            local bucket = type(profiles) == "table" and profiles[profileKey] or nil
                            local specProfiles = type(bucket) == "table" and bucket.specProfiles or nil
                            local profile = type(specProfiles) == "table" and (specProfiles[specKey] or specProfiles[tostring(specKey)]) or nil
                            local store = type(profile) == "table" and profile[record.family] or nil
                            local target = type(store) == "table" and (store[tonumber(recordedSpellID)] or store[recordedSpellID]) or nil
                            if type(target) == "table" and target[record.field] == record.injectedValue then
                                target[record.field] = record.previousValue
                                if tostring(profileKey) == tostring(context.profileKey) and tostring(specKey) == tostring(context.specKey) then
                                    currentChanged = true
                                end
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
    if not ok then removed, status, fieldChanged = false, "unsupported_structure", false end
    return removed, status, fieldChanged
end

function Integration:GetInjectionStatus(entry)
    if not EntryEnabled(entry) then return "disabled" end
    if NS.pendingEUISync and InCombatLockdown and InCombatLockdown() then return "waiting_combat" end
    if not (NS.Core and NS.Core.EUISoundRegistry) or NS.Core.EUISoundRegistry:ResolveSoundPath(entry) == "" then return "invalid_path" end
    if type(NS.FindEntryScope) == "function" and type(NS.GetCurrentClassSpec) == "function" then
        local classID, specID = NS:FindEntryScope(entry)
        local currentClassID, currentSpecID = NS:GetCurrentClassSpec()
        if classID ~= nil and ((classID ~= 0 and classID ~= currentClassID) or (specID ~= 0 and specID ~= currentSpecID)) then
            return "waiting_for_spec"
        end
    end
    local context, status = ResolveContext()
    if not context then return status end
    if tostring(entry.soundSource or "") == "tts" or tostring(entry.notifyMode or "") == "tts" then return "unsupported_tts" end
    if type(context.specProfile) ~= "table" then return "waiting_for_eui_spell" end
    local spellID = tonumber(entry.spellId)
    local trigger = tostring(entry.euiTriggerType or "cdReady")
    local activeStates = type(context.cdmProfile) == "table" and context.cdmProfile.customActiveStates or nil
    if type(activeStates) == "table" and (activeStates[spellID] or activeStates[tostring(spellID)]) then
        return "unsupported_entry_type"
    end
    local family = spellID and ResolveFamily(context.specProfile, spellID, trigger)
    if not family then return "waiting_for_eui_spell" end
    local field = FIELD_BY_TRIGGER[trigger]
    local target = context.specProfile[family] and context.specProfile[family][spellID]
    local value = target and target[field]
    local records = GetRecordTable(context.profileKey, context.specKey, spellID, trigger, false)
    local record = records and records[trigger]
    if record and value == record.injectedValue then return "injected" end
    if not IsEmpty(value) and not IsOwnedValue(value) then return "conflict" end
    return "saved_waiting_sync"
end

function Integration:Refresh()
    if InCombatLockdown and InCombatLockdown() then
        if NS.RequestEUISync then NS:RequestEUISync("COMBAT_REFRESH") end
        return false
    end
    local apply = rawget(_G, "_ECME_Apply")
    if type(apply) == "function" then
        local ok = pcall(apply)
        return ok
    end
    return false
end

Integration.GetManagedEntries = Integration.GetManagedSpells
Integration.SyncCurrentSpec = Integration.InjectAll
Integration.GetEntryStatus = Integration.GetInjectionStatus

function Integration:FindManagedTarget(spellID, trigger)
    local context, status = ResolveContext()
    if not context or type(context.specProfile) ~= "table" then return nil, status or "waiting_for_eui_spell" end
    local family = ResolveFamily(context.specProfile, tonumber(spellID), trigger or "cdReady")
    if not family then return nil, "waiting_for_eui_spell" end
    local store = context.specProfile[family]
    return type(store) == "table" and store[tonumber(spellID)] or nil, family
end
