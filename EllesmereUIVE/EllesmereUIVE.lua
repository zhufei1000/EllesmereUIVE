EllesmereUIVEDB = type(EllesmereUIVEDB) == "table" and EllesmereUIVEDB or {}

local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS
_G.EllesmereUIVE = NS
_G.EUIVE = NS

NS.VERSION = "1.0.1"
NS.ADDON_NAME = "EllesmereUIVE"
NS.ADDON_CHAT_PREFIX = "|cff25d5a4[EUIVE]|r"
NS.CONFIG_ADDON_NAME = "EllesmereUIVE_Config"
NS.pendingEUIRemovals = NS.pendingEUIRemovals or {}
NS.internalApplyInProgress = false
NS.lastProfileKey = NS.lastProfileKey or nil
NS.lastSpecKey = NS.lastSpecKey or nil

function NS:Print(message)
    local text = self.ADDON_CHAT_PREFIX .. " " .. tostring(message or "")
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage(text) else print(text) end
end

function NS:LoadConfigAddon(silent)
    if self.UI and self.UI.MainFrame then return true end
    local loaded, reason = false, nil
    if C_AddOns and C_AddOns.LoadAddOn then
        local ok, value, why = pcall(C_AddOns.LoadAddOn, self.CONFIG_ADDON_NAME)
        loaded, reason = ok and value == true, why
    end
    if not loaded and not silent then self:Print("Unable to load configuration: " .. tostring(reason or self.CONFIG_ADDON_NAME)) end
    return loaded and self.UI and self.UI.MainFrame ~= nil
end

function NS:OpenMainFrame()
    if self:LoadConfigAddon(false) and self.UI.MainFrame then self.UI.MainFrame:Open() end
end

function NS:ToggleMainFrame()
    if self:LoadConfigAddon(false) and self.UI.MainFrame then self.UI.MainFrame:Toggle() end
end

function NS:GetCurrentClassSpec()
    local classID = 0
    if type(UnitClass) == "function" then
        local _, _, value = UnitClass("player")
        classID = tonumber(value) or 0
    end
    local index = GetSpecialization and GetSpecialization()
    local specID = index and C_SpecializationInfo and select(1, C_SpecializationInfo.GetSpecializationInfo(index)) or 0
    return classID, tonumber(specID) or 0
end

function NS:GetScopeList(classID, specID, create)
    classID, specID = tonumber(classID) or 0, tonumber(specID) or 0
    if create then
        EllesmereUIVEDB.specConfigs[classID] = EllesmereUIVEDB.specConfigs[classID] or {}
        EllesmereUIVEDB.specConfigs[classID][specID] = EllesmereUIVEDB.specConfigs[classID][specID] or {}
    end
    return EllesmereUIVEDB.specConfigs[classID] and EllesmereUIVEDB.specConfigs[classID][specID] or {}
end

function NS:GetCurrentEntries(entryType)
    local classID, specID = self:GetCurrentClassSpec()
    local result = {}
    local function collect(c, s)
        for _, entry in pairs(self:GetScopeList(c, s, false)) do
            if type(entry) == "table" and (not entryType or entry.entryType == entryType) then result[#result + 1] = entry end
        end
    end
    collect(0, 0)
    if classID ~= 0 then collect(classID, 0) end
    if specID ~= 0 then collect(classID, specID) end
    table.sort(result, function(a, b) return tostring(a.entryUID or "") < tostring(b.entryUID or "") end)
    return result
end

function NS:GetAllEntries(entryType)
    local result = {}
    for classID, classMap in pairs(EllesmereUIVEDB.specConfigs or {}) do
        for specID, entries in pairs(type(classMap) == "table" and classMap or {}) do
            for _, entry in pairs(type(entries) == "table" and entries or {}) do
                if type(entry) == "table" and (not entryType or entry.entryType == entryType) then
                    result[#result + 1] = { entry = entry, classID = tonumber(classID) or 0, specID = tonumber(specID) or 0 }
                end
            end
        end
    end
    table.sort(result, function(a, b)
        if a.classID ~= b.classID then return a.classID < b.classID end
        if a.specID ~= b.specID then return a.specID < b.specID end
        return tostring(a.entry.entryUID or "") < tostring(b.entry.entryUID or "")
    end)
    return result
end

local function SameTarget(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    if tonumber(a.spellId) ~= tonumber(b.spellId) then return false end
    if tostring(a.entryType) ~= tostring(b.entryType) then return false end
    if tostring(a.objectType or "spell") ~= tostring(b.objectType or "spell") then return false end
    if a.entryType == "euiVoice" then return tostring(a.euiTriggerType) == tostring(b.euiTriggerType) end
    return true
end

local function ScopeOverlaps(classA, specA, classB, specB)
    classA, specA, classB, specB = tonumber(classA) or 0, tonumber(specA) or 0, tonumber(classB) or 0, tonumber(specB) or 0
    local classOverlap = classA == 0 or classB == 0 or classA == classB
    local specOverlap = specA == 0 or specB == 0 or specA == specB
    return classOverlap and specOverlap
end

local function ScopeIsCurrent(classID, specID)
    local currentClass, currentSpec = NS:GetCurrentClassSpec()
    return (tonumber(classID) == 0 or tonumber(classID) == currentClass)
        and (tonumber(specID) == 0 or tonumber(specID) == currentSpec)
end

function NS:FindDuplicate(classID, specID, entry, excluding)
    for storedClass, classMap in pairs(EllesmereUIVEDB.specConfigs or {}) do
        for storedSpec, entries in pairs(type(classMap) == "table" and classMap or {}) do
            if ScopeOverlaps(classID, specID, storedClass, storedSpec) then
                for _, current in pairs(type(entries) == "table" and entries or {}) do
                    if current ~= excluding and SameTarget(current, entry) then return current end
                end
            end
        end
    end
    return nil
end

function NS:FindEntryScope(entry)
    for classID, classMap in pairs(EllesmereUIVEDB.specConfigs or {}) do
        for specID, entries in pairs(type(classMap) == "table" and classMap or {}) do
            for _, current in pairs(type(entries) == "table" and entries or {}) do
                if current == entry then return tonumber(classID) or 0, tonumber(specID) or 0 end
            end
        end
    end
    return nil, nil
end

function NS:AddEntry(classID, specID, entry)
    if type(entry) ~= "table" or self:FindDuplicate(classID, specID, entry) then return nil, "duplicate" end
    self.Core.Database:NormalizeEUITarget(entry)
    entry.entryUID = entry.entryUID or self.Core.Database:NextEntryUID()
    entry.entryUID = tostring(entry.entryUID)
    entry.classID, entry.specID = tonumber(classID) or 0, tonumber(specID) or 0
    entry.injected, entry.injectionStatus = nil, nil
    local list = self:GetScopeList(classID, specID, true)
    list[#list + 1] = entry
    return entry
end

local function SnapshotEntry(entry)
    local snapshot = {
        entryUID = entry.entryUID,
        entryType = entry.entryType,
        spellId = entry.spellId,
        objectType = entry.objectType,
        euiTriggerType = entry.euiTriggerType,
        euiTargetMode = entry.euiTargetMode,
        euiTargetFamily = entry.euiTargetFamily,
        soundSource = entry.soundSource,
        soundPath = entry.soundPath,
        builtinSoundPath = entry.builtinSoundPath,
        customSoundPath = entry.customSoundPath,
        sharedMediaSound = entry.sharedMediaSound,
        enabled = entry.enabled,
        voiceEnabled = entry.voiceEnabled,
    }
    snapshot.soundKey = NS.Core.EUISoundRegistry:BuildStableSoundKey(entry)
    return snapshot
end
NS.SnapshotEntry = SnapshotEntry

function NS:QueueEUIRemoval(entry)
    self.pendingEUIRemovals[#self.pendingEUIRemovals + 1] = SnapshotEntry(entry)
    self.pendingEUISync = true
end

function NS:SaveEntry(draft, existing, classID, specID, injectNow)
    if type(draft) ~= "table" then return nil, "invalid" end
    self.Core.Database:NormalizeEUITarget(draft)
    local oldClassID, oldSpecID = nil, nil
    if existing then oldClassID, oldSpecID = self:FindEntryScope(existing) end
    if classID == nil then
        if existing and oldClassID ~= nil then classID, specID = oldClassID, oldSpecID else classID, specID = self:GetCurrentClassSpec() end
    end
    classID, specID = tonumber(classID) or 0, tonumber(specID) or 0
    if self:FindDuplicate(classID, specID, draft, existing) then return nil, "duplicate" end
    local integration = self.Integrations and self.Integrations.EllesmereUI
    local old = existing and SnapshotEntry(existing) or nil
    local changedScope = existing and (oldClassID ~= classID or oldSpecID ~= specID)
    local changedTarget = old and ((not SameTarget(old, draft)) or changedScope)
    local disabling = draft.enabled == false or draft.voiceEnabled == false
    local oldInjectionChanged = false
    if old and old.entryType == "euiVoice" and (changedTarget or disabling or draft.entryType ~= "euiVoice") then
        local removed, removeStatus, changed = integration:RemoveEntry(old, true)
        oldInjectionChanged = changed == true
        if not removed and removeStatus ~= "removed" and removeStatus ~= "waiting_combat" then self:QueueEUIRemoval(old) end
    end
    local saved = existing
    if saved then
        local uid = saved.entryUID
        wipe(saved)
        for key, value in pairs(draft) do saved[key] = value end
        saved.entryUID = uid
        saved.classID, saved.specID = classID, specID
        if changedScope then
            local oldList = self:GetScopeList(oldClassID, oldSpecID, false)
            for index = #oldList, 1, -1 do if oldList[index] == saved then table.remove(oldList, index); break end end
            local newList = self:GetScopeList(classID, specID, true)
            newList[#newList + 1] = saved
        end
    else
        saved = self:AddEntry(classID, specID, draft)
        if not saved then return nil, "duplicate" end
    end
    saved.injected, saved.injectionStatus = nil, nil
    if saved.entryType == "euiVoice" then
        saved.enabled = saved.enabled ~= false and saved.voiceEnabled ~= false
        saved.voiceEnabled = saved.enabled
        self.Core.Database:NormalizeEUITarget(saved)
        local readiness = self.Core.EUISoundRegistry:GetNativeReadiness(saved)
        if injectNow == nil then injectNow = EllesmereUIVEDB.settings.autoInjectOnSave ~= false end
        if saved.enabled ~= false and injectNow and ScopeIsCurrent(classID, specID) then
            local ok, status, injectionChanged = integration:InjectEntry(saved, EllesmereUIVEDB.settings.overwriteEUI == true)
            if oldInjectionChanged and injectionChanged ~= true and status ~= "waiting_combat" then integration:Refresh() end
            saved.injectionStatus = status
            if status == "requires_reload" then self:NotifyReloadRequiredOnce() end
            return saved, status, ok or status == "requires_reload" or status == "native_ready" or status == "preseeded"
        elseif saved.enabled ~= false and injectNow then
            if oldInjectionChanged then integration:Refresh() end
            return saved, "waiting_for_spec", true
        elseif readiness == "requires_reload" then
            saved.injectionStatus = "requires_reload"
        end
    else
        self:RebuildVoiceRuntime()
    end
    if oldInjectionChanged then integration:Refresh() end
    local finalStatus = (saved.enabled == false or saved.voiceEnabled == false) and "disabled"
        or (saved.entryType == "euiVoice" and "saved_waiting_sync" or "saved")
    return saved, finalStatus, true
end

function NS:DeleteEntry(entry)
    if type(entry) ~= "table" then return false end
    if entry.entryType == "euiVoice" then
        local snapshot = SnapshotEntry(entry)
        local removed, status = self.Integrations.EllesmereUI:RemoveEntry(snapshot)
        if not removed and status ~= "removed" and status ~= "waiting_combat" then self:QueueEUIRemoval(snapshot) end
    end
    for _, classMap in pairs(EllesmereUIVEDB.specConfigs or {}) do
        for _, list in pairs(type(classMap) == "table" and classMap or {}) do
            if type(list) == "table" then
                for index = #list, 1, -1 do
                    if list[index] == entry or tostring(list[index].entryUID) == tostring(entry.entryUID) then
                        table.remove(list, index); self:RebuildVoiceRuntime(); return true
                    end
                end
            end
        end
    end
    return false
end

function NS:RebuildVoiceRuntime()
    self.Core.CastSuccess:Rebuild()
end

function NS:InjectSavedEntry(entry)
    if type(entry) ~= "table" then return false, "unsupported_entry_type" end
    if entry.enabled == false or entry.voiceEnabled == false then return false, "disabled" end
    local classID, specID = self:FindEntryScope(entry)
    if classID == nil or not ScopeIsCurrent(classID, specID) then return false, "waiting_for_spec" end
    local ok, status = self.Integrations.EllesmereUI:InjectEntry(entry, EllesmereUIVEDB.settings.overwriteEUI == true)
    if status == "requires_reload" then self:NotifyReloadRequiredOnce() end
    return ok or status == "requires_reload" or status == "native_ready" or status == "preseeded", status
end

local reloadNoticeShown = false
function NS:NotifyReloadRequiredOnce()
    if reloadNoticeShown then return false end
    reloadNoticeShown = true
    self:Print(self.L("RELOAD_REQUIRED_NOTICE"))
    return true
end

function NS:SyncEUIEntries()
    local integration = self.Integrations.EllesmereUI
    local profileKey = integration:GetCurrentProfileKey()
    local specKey = integration:GetCurrentSpecKey()
    local scopeChanged = tostring(profileKey or "") ~= tostring(self.lastProfileKey or "")
        or tostring(specKey or "") ~= tostring(self.lastSpecKey or "")
    self.Core.EUISoundRegistry:RegisterAllSavedEntries()
    if scopeChanged then
        self.lastProfileKey, self.lastSpecKey = profileKey, specKey
        local bridge = self.Core and self.Core.BootstrapBridge
        if bridge and not bridge:IsCDMLoaded() then bridge:PreseedCurrentScope() end
        self:RebuildVoiceRuntime()
    end
    local entries = {}
    for _, entry in ipairs(self:GetCurrentEntries("euiVoice")) do
        if entry.enabled ~= false and entry.voiceEnabled ~= false then entries[#entries + 1] = entry end
    end
    local results, status, stats = integration:SyncCurrentSpec(entries, EllesmereUIVEDB.settings.overwriteEUI == true)
    self.lastEUISyncResults, self.lastEUISyncStatus, self.lastEUISyncStats = results, status, stats
    return results, status, stats
end

local euiApplyHookInstalled = false
function NS:InstallEUIApplyHook()
    if euiApplyHookInstalled or type(hooksecurefunc) ~= "function" or type(rawget(_G, "_ECME_Apply")) ~= "function" then return false end
    euiApplyHookInstalled = true
    hooksecurefunc("_ECME_Apply", function()
        if NS.internalApplyInProgress then return end
        NS:RequestEUISync("EUI_APPLY_HOOK")
    end)
    return true
end

local syncTimerPending = false
local pendingSyncCallbacks = {}
function NS:RequestEUISync(reason, callback)
    if type(callback) == "function" then pendingSyncCallbacks[#pendingSyncCallbacks + 1] = callback end
    self.pendingEUISync = true
    if InCombatLockdown and InCombatLockdown() then return false, "waiting_combat" end
    if syncTimerPending then return true end
    syncTimerPending = true
    local function apply()
        syncTimerPending = false
        self:ProcessPendingEUISync()
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.10, apply) else apply() end
    return true
end

function NS:ProcessPendingEUISync()
    if InCombatLockdown and InCombatLockdown() then return false end
    local integration = self.Integrations.EllesmereUI
    local removals = self.pendingEUIRemovals
    self.pendingEUIRemovals = {}
    local removalChanged = self.pendingEUIRefresh == true
    self.pendingEUIRefresh = false
    for _, oldEntry in ipairs(removals) do
        local _, _, changed = integration:RemoveEntry(oldEntry, true)
        removalChanged = changed == true or removalChanged
    end
    local results, status, stats
    if self.pendingEUISync then
        self.pendingEUISync = false
        results, status, stats = self:SyncEUIEntries()
        if removalChanged and not (stats and stats.changed) then integration:Refresh() end
    elseif removalChanged then
        integration:Refresh()
    end
    if self.UI and self.UI.MainFrame then self.UI.MainFrame:Refresh() end
    local callbacks = pendingSyncCallbacks
    pendingSyncCallbacks = {}
    for _, callback in ipairs(callbacks) do pcall(callback, results, status, stats) end
    return true, status, stats
end

local loginSyncPending, loginSyncCompleted = false, false
function NS:ScheduleLoginSync()
    if loginSyncPending or loginSyncCompleted or EllesmereUIVEDB.settings.syncOnLogin == false then return false end
    loginSyncPending = true
    local function run(attempt)
        self:RequestEUISync("LOGIN", function(_, status)
            if attempt == 1 and (status == "waiting_for_eui" or status == "eui_missing" or status == "module_not_loaded" or status == "unsupported_structure") then
                if C_Timer and C_Timer.After then C_Timer.After(0.5, function() run(2) end) else run(2) end
            else
                loginSyncPending, loginSyncCompleted = false, true
            end
        end)
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.5, function() run(1) end) else run(1) end
    return true
end

local specSyncPending = false
function NS:ScheduleSpecSync()
    if specSyncPending or EllesmereUIVEDB.settings.autoSyncSpec == false then return false end
    specSyncPending = true
    local function run()
        specSyncPending = false
        self:RebuildVoiceRuntime()
        self:RequestEUISync("SPEC_CHANGED")
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.2, run) else run() end
    return true
end

local function InitializeSlashCommands()
    SLASH_ELLESMEREUIVE1 = "/euive"
    SLASH_ELLESMEREUIVE2 = "/ellesmereuive"
    SlashCmdList.ELLESMEREUIVE = function(message)
        local command = tostring(message or ""):match("^%s*(%S*)")
        if command and command:lower() == "sync" then NS:RequestEUISync("SLASH") else NS:ToggleMainFrame() end
    end
end

local initialized = false
local function InitializeAddon()
    if initialized then return end
    initialized = true
    NS.Core.Database:Initialize()
    NS.Core.EUISoundRegistry:RegisterAllSavedEntries()
    NS:RebuildVoiceRuntime()
    NS:InstallEUIApplyHook()
    InitializeSlashCommands()
end

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_ENTERING_WORLD",
    "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_REGEN_ENABLED",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_AURA", "ITEM_DATA_LOAD_RESULT",
}) do eventFrame:RegisterEvent(event) end
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "EllesmereUIVE" then InitializeAddon()
        elseif addonName == "EllesmereUI" or addonName == "EllesmereUICooldownManager" then
            if initialized then
                NS.Core.EUISoundRegistry:RegisterAllSavedEntries()
                NS:InstallEUIApplyHook()
                NS:RequestEUISync("ADDON_LOADED_" .. addonName)
            end
        end
    elseif event == "PLAYER_LOGIN" then
        InitializeAddon()
        NS.Core.EUISoundRegistry:RegisterAllSavedEntries()
        NS:InstallEUIApplyHook()
        NS.Core.MinimapButton:Initialize()
        NS.Core.ConfigPanel:Initialize()
        if EllesmereUIVEDB.settings.showLoadMessage ~= false then NS:Print(NS.L("LOADED")) end
        NS:ScheduleLoginSync()
    elseif event == "PLAYER_LOGOUT" then
        NS.Core.CastSuccess:Reset()
    elseif event == "PLAYER_ENTERING_WORLD" then
        NS.Core.EUISoundRegistry:RegisterAllSavedEntries()
        NS:InstallEUIApplyHook()
        NS:ScheduleLoginSync()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = ...
        if unit == "player" then NS:ScheduleSpecSync() end
    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
        NS:ScheduleSpecSync()
    elseif event == "PLAYER_REGEN_ENABLED" then
        NS:ProcessPendingEUISync()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" or unit == "pet" then NS.Core.CastSuccess:HandleSpellcast(spellID) end
    elseif event == "UNIT_AURA" then
        NS.Core.Bloodlust:HandleUnitAura(...)
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        NS:RebuildVoiceRuntime()
    end
end)

_G.EllesmereUIVEAPI = {
    Open = function() NS:OpenMainFrame() end,
    Sync = function() return NS:RequestEUISync("API") end,
    GetCurrentEntries = function(entryType) return NS:GetCurrentEntries(entryType) end,
    GetAllEntries = function(entryType) return NS:GetAllEntries(entryType) end,
    GetIntegration = function() return NS.Integrations and NS.Integrations.EllesmereUI end,
}
