local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.Config = NS.Config or {}
NS.Config.Controller = NS.Config.Controller or {}
NS.Utils = NS.Utils or {}
NS.API = NS.API or {}
NS.Constants = NS.Constants or {}
NS.AceOptions = NS.AceOptions or {}

local Utils = NS.Utils
local API = NS.API
local Constants = NS.Constants
local AceOptions = NS.AceOptions

Constants.ALL_CLASSES_ID = Constants.ALL_CLASSES_ID or 0
Constants.ALL_SPECS_ID = Constants.ALL_SPECS_ID or 0
Constants.ALL_RACES_ID = Constants.ALL_RACES_ID or 0
Constants.OBJECT_TYPE_SPELL = Constants.OBJECT_TYPE_SPELL or "spell"
Constants.OBJECT_TYPE_ITEM = Constants.OBJECT_TYPE_ITEM or "item"
Constants.ITEM_LOAD_NONE = Constants.ITEM_LOAD_NONE or "none"
Constants.ITEM_LOAD_EQUIPPED = Constants.ITEM_LOAD_EQUIPPED or "equipped"
Constants.ITEM_LOAD_BAGS = Constants.ITEM_LOAD_BAGS or "bags"
Constants.DEFAULT_COLLECTION_ICON = Constants.DEFAULT_COLLECTION_ICON or 134400

function Utils.TrimText(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

function Utils.CanonicalPath(value)
    return tostring(value or ""):gsub("/", "\\")
end

function Utils.GetFileNameFromPath(value)
    return Utils.CanonicalPath(value):match("([^\\]+)$") or ""
end

function Utils.NormalizeIconID(value)
    value = tonumber(value)
    return value and value > 0 and math.floor(value) or nil
end

function Utils.Clamp(value, minimum, maximum)
    value = tonumber(value) or tonumber(minimum) or 0
    return math.max(tonumber(minimum) or value, math.min(tonumber(maximum) or value, value))
end

function Utils.SyncLinkedVisualDurations(state)
    return state
end

local function ResolveSpellName(spellID)
    spellID = tonumber(spellID) or 0
    if spellID <= 0 then return "" end
    if C_Spell and type(C_Spell.GetSpellName) == "function" then
        return C_Spell.GetSpellName(spellID) or ""
    end
    local getSpellInfo = rawget(_G, "GetSpellInfo")
    return type(getSpellInfo) == "function" and (getSpellInfo(spellID) or "") or ""
end

local function ResolveSpellIcon(spellID)
    spellID = tonumber(spellID) or 0
    if spellID <= 0 then return nil end
    if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
        return C_Spell.GetSpellTexture(spellID)
    end
    local getSpellTexture = rawget(_G, "GetSpellTexture")
    return type(getSpellTexture) == "function" and getSpellTexture(spellID) or nil
end

local function ResolveClassName(classID)
    classID = tonumber(classID) or 0
    if classID == 0 then return NS.L and NS.L("ALL_CLASSES") or "All classes" end
    local getClassInfo = rawget(_G, "GetClassInfo")
    if type(getClassInfo) == "function" then
        for index = 1, tonumber(GetNumClasses and GetNumClasses()) or 0 do
            local name, _, id = getClassInfo(index)
            if tonumber(id) == classID then return name or tostring(classID) end
        end
    end
    return tostring(classID)
end

local function ResolveSpecName(classID, specID)
    classID, specID = tonumber(classID) or 0, tonumber(specID) or 0
    if specID == 0 then return NS.L and NS.L("ALL_SPECS") or "All specializations" end
    if type(GetNumSpecializationsForClassID) == "function" and type(GetSpecializationInfoForClassID) == "function" then
        for index = 1, tonumber(GetNumSpecializationsForClassID(classID)) or 0 do
            local id, name = GetSpecializationInfoForClassID(classID, index)
            if tonumber(id) == specID then return name or tostring(specID) end
        end
    end
    return tostring(specID)
end

local function OrderedIndices(map)
    local indices = {}
    for index, entry in pairs(type(map) == "table" and map or {}) do
        index = tonumber(index)
        if index and index > 0 and type(entry) == "table" then indices[#indices + 1] = index end
    end
    table.sort(indices)
    return indices
end

local function CurrentScope()
    if type(NS.GetCurrentClassSpec) == "function" then return NS:GetCurrentClassSpec() end
    return 0, 0
end

local function IsActiveScopeLoaded(classID, specID, currentClassID, currentSpecID)
    classID, specID = tonumber(classID) or 0, tonumber(specID) or 0
    currentClassID, currentSpecID = tonumber(currentClassID) or 0, tonumber(currentSpecID) or 0
    return (classID == 0 or classID == currentClassID) and (specID == 0 or specID == currentSpecID)
end

API.GetCurrentClassSpec = CurrentScope
API.GetTargetClassSpec = CurrentScope
API.IsActiveScopeLoaded = IsActiveScopeLoaded
API.GetStoredEntryMap = function(classID, specID)
    return type(NS.GetScopeList) == "function" and NS:GetScopeList(classID, specID, false) or {}
end
API.EnsureEntryMap = function(classID, specID)
    return type(NS.GetScopeList) == "function" and NS:GetScopeList(classID, specID, true) or nil
end
API.GetCastSuccessMap = API.GetStoredEntryMap
API.EnsureCastSuccessMap = API.EnsureEntryMap
API.GetEntry = function(map, index) return type(map) == "table" and map[tonumber(index)] or nil end
API.GetOrderedEntryIndices = OrderedIndices
API.FindFirstFreeIndex = function(map)
    for index = 1, 10000 do if type(map) ~= "table" or map[index] == nil then return index end end
end
API.GetEntryRange = function() return 1, 10000 end
API.GetModes = function() return "tts", "sound" end
API.ResolveClassName = ResolveClassName
API.ResolveSpecName = ResolveSpecName
API.ResolveSpellName = ResolveSpellName
API.ResolveSpellIcon = ResolveSpellIcon
API.ResolveSpellBaseCooldownSeconds = function(spellID)
    if C_Spell and type(C_Spell.GetSpellBaseCooldown) == "function" then
        return (tonumber(C_Spell.GetSpellBaseCooldown(tonumber(spellID) or 0)) or 0) / 1000
    end
    return 0
end
API.ResolveObjectType = function(_, objectType)
    return tostring(objectType or "spell") == "item" and "item" or "spell"
end
API.ResolveObjectName = function(objectID, objectType)
    if tostring(objectType or "spell") == "item" and C_Item and type(C_Item.GetItemNameByID) == "function" then
        return C_Item.GetItemNameByID(tonumber(objectID) or 0) or ""
    end
    return ResolveSpellName(objectID)
end
API.ResolveObjectIcon = function(objectID, objectType)
    if tostring(objectType or "spell") == "item" and C_Item and type(C_Item.GetItemIconByID) == "function" then
        return C_Item.GetItemIconByID(tonumber(objectID) or 0)
    end
    return ResolveSpellIcon(objectID)
end
API.ResolveObjectBaseCooldownSeconds = API.ResolveSpellBaseCooldownSeconds
API.IsItemLoadRequirementMet = function() return true end
API.ResolveItemName = API.ResolveObjectName
API.ResolveItemIcon = API.ResolveObjectIcon
API.ResolveItemUseSpellID = function() return nil end
API.ResolveItemTriggerForEntry = function(entry) return type(entry) == "table" and entry.triggerSpellID or nil end
API.ResolveAllStoredItemTriggers = function() return true end
API.ResolvePendingItems = function() return true end
API.ResolveTalentName = ResolveSpellName
API.IsTalentSelected = function() return false end
API.MarkEntryDeleted = function() return true end
API.ClearEntryDeletedMarker = function() return true end
API.IsEntryMarkedDeleted = function() return false end
API.PurgeDeletedEntries = function() return true end

local function RefreshRuntime()
    if type(NS.RebuildVoiceRuntime) == "function" then NS:RebuildVoiceRuntime() end
    return true
end

API.RebuildRuntimeConfig = RefreshRuntime
API.RebuildCastSuccessConfig = RefreshRuntime
API.RebuildCustomConfig = RefreshRuntime
API.RefreshRuntimeCooldowns = function() return true end
API.RebuildBloodlustConfig = function() return true end
API.RefreshPanel = function()
    return NS.Config.Controller:Refresh()
end
API.GetSummaryText = function()
    local classID, specID = CurrentScope()
    local count = #API.GetStoredEntryMap(classID, specID)
    return NS.L and NS.L("MSG_SCOPE_COUNT", count) or tostring(count)
end

API.PlayReadyNotification = function(config)
    return NS.Core and NS.Core.VoicePlayer and NS.Core.VoicePlayer:PreviewSound(config)
end
API.PlayCastSuccessNotification = function(config)
    return NS.Core and NS.Core.VoicePlayer and NS.Core.VoicePlayer:NotifyCastSuccess(config)
end
API.QueueCastSuccessNotification = function(triggerSpellID, config)
    local scheduler = NS.Core and NS.Core.CastSuccessScheduler
    if scheduler and type(scheduler.Queue) == "function" then
        return scheduler:Queue(triggerSpellID, config, function(value)
            API.PlayCastSuccessNotification(value)
        end)
    end
    return API.PlayCastSuccessNotification(config)
end
API.ClearDelayedCastSuccessTimers = function()
    local scheduler = NS.Core and NS.Core.CastSuccessScheduler
    return scheduler and type(scheduler.ClearAll) == "function" and scheduler:ClearAll()
end
API.PlayBloodlustNotification = function(config)
    return NS.Core and NS.Core.VoicePlayer and NS.Core.VoicePlayer:NotifyBloodlust(config)
end

function AceOptions:NormalizeSoundPath(value)
    return Utils.CanonicalPath(value):gsub("\\+", "\\")
end

function AceOptions:GetDefaultBuiltinSoundPath()
    return Constants.DEFAULT_SOUND or "Interface\\AddOns\\EllesmereUIVE\\Media\\Sounds\\AirHorn.ogg"
end

function AceOptions:GetBuiltinSoundList()
    local sounds = {}
    local bootstrap = rawget(_G, "EllesmereUIVEBootstrapNS")
    for _, item in ipairs(type(bootstrap) == "table" and type(bootstrap.SoundManifest) == "table" and bootstrap.SoundManifest or {}) do
        if type(item) == "table" and type(item.path) == "string" then
            sounds[self:NormalizeSoundPath(item.path)] = tostring(item.name or Utils.GetFileNameFromPath(item.path))
        end
    end
    if next(sounds) == nil then sounds[self:GetDefaultBuiltinSoundPath()] = "AirHorn" end
    return sounds
end

function AceOptions:GetBuiltinSoundDisplayName(path)
    return self:GetBuiltinSoundList()[self:NormalizeSoundPath(path)] or Utils.GetFileNameFromPath(path)
end

function AceOptions:IsBuiltinSoundPath(path)
    return self:GetBuiltinSoundList()[self:NormalizeSoundPath(path)] ~= nil
end

function AceOptions:GetSharedMediaSoundList()
    local libStub = rawget(_G, "LibStub")
    local lsm = type(libStub) == "table" and libStub:GetLibrary("LibSharedMedia-3.0", true) or nil
    return lsm and type(lsm.HashTable) == "function" and (lsm:HashTable("sound") or {}) or {}
end

function AceOptions:FetchSharedMediaSoundPath(name)
    return self:GetSharedMediaSoundList()[tostring(name or "")]
end

function AceOptions:ResolveSharedMediaSoundPath(name, fallback)
    return self:NormalizeSoundPath(self:FetchSharedMediaSoundPath(name) or fallback or "")
end

function AceOptions:ResolveSoundSourceFields(entry, modeTts, modeSound)
    entry = type(entry) == "table" and entry or {}
    modeTts, modeSound = tostring(modeTts or "tts"), tostring(modeSound or "sound")
    local source = tostring(entry.soundSource or "")
    if source == "" then
        if tostring(entry.notifyMode or "") == modeTts then source = "tts"
        elseif Utils.TrimText(entry.sharedMediaSound or entry.sharedMediaName) ~= "" then source = "sharedmedia"
        elseif Utils.TrimText(entry.customSoundPath) ~= "" then source = "custom"
        else source = "builtin" end
    end
    local builtin = self:NormalizeSoundPath(entry.builtinSoundPath or self:GetDefaultBuiltinSoundPath())
    local custom = self:NormalizeSoundPath(entry.customSoundPath or "")
    if custom == "" and type(entry.customSoundPaths) == "table" then
        for index = 1, 5 do
            custom = self:NormalizeSoundPath(entry.customSoundPaths[index] or "")
            if custom ~= "" then break end
        end
    end
    local shared = Utils.TrimText(entry.sharedMediaSound or entry.sharedMediaName)
    local path
    if source == "custom" then path = custom ~= "" and custom or self:NormalizeSoundPath(entry.soundPath)
    elseif source == "sharedmedia" then path = self:ResolveSharedMediaSoundPath(shared, entry.soundPath)
    elseif source == "tts" then path = ""
    else source, path = "builtin", builtin end
    return {
        notifyMode = source == "tts" and modeTts or modeSound,
        soundSource = source,
        soundPath = path,
        builtinSoundPath = builtin,
        customSoundPath = custom,
        sharedMediaSound = shared,
        useCustomSound = source == "custom",
        useSharedMediaSound = source == "sharedmedia",
    }
end

local db = rawget(_G, "EllesmereUIVEDB")
if type(db) == "table" then
    db.collectionData = type(db.collectionData) == "table" and db.collectionData or {}
    db.savedListOrder = type(db.savedListOrder) == "table" and db.savedListOrder or {}
    db.bloodlust = type(db.bloodlust) == "table" and db.bloodlust or {}
    db.bloodlustConfig = db.bloodlust
end

function NS.Config.Controller:Refresh()
    if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.Refresh) == "function" then
        return NS.UI.MainFrame:Refresh()
    end
end
