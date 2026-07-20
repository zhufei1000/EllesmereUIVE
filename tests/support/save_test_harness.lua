return function(options)
    options = options or {}
    EllesmereUIVENS = {
        Constants = {
            ALL_CLASSES_ID = 0, ALL_SPECS_ID = 0, ALL_RACES_ID = 0,
            OBJECT_TYPE_SPELL = "spell", OBJECT_TYPE_ITEM = "item",
            ITEM_LOAD_NONE = "none", ITEM_LOAD_EQUIPPED = "equipped", ITEM_LOAD_BAGS = "bags",
        },
        Utils = {}, Core = {}, Integrations = {}, UI = {},
        L = function(key) return key end,
    }
    _G.EllesmereUIVENS = EllesmereUIVENS
    local NS = EllesmereUIVENS
    local serial = 0
    local function deepCopy(value, seen)
        if type(value) ~= "table" then return value end
        seen = seen or {}; if seen[value] then return seen[value] end
        local result = {}; seen[value] = result
        for key, child in pairs(value) do result[deepCopy(key, seen)] = deepCopy(child, seen) end
        return result
    end

    EllesmereUIVEDB = { specConfigs = {}, collectionData = {}, savedListOrder = { loaded = {}, unloaded = {} }, settings = {} }
    local function scopeMap(classID, specID, create)
        if create then
            EllesmereUIVEDB.specConfigs[classID] = EllesmereUIVEDB.specConfigs[classID] or {}
            EllesmereUIVEDB.specConfigs[classID][specID] = EllesmereUIVEDB.specConfigs[classID][specID] or {}
        end
        return EllesmereUIVEDB.specConfigs[classID] and EllesmereUIVEDB.specConfigs[classID][specID] or {}
    end

    local calls = { register = 0, inject = 0, list = 0, legacy = 0, cast = 0, invalidate = 0 }
    NS.Core.Database = {
        DeepCopy = deepCopy,
        NextEntryUID = function() serial = serial + 1; EllesmereUIVEDB.entrySerial = serial; return string.format("%08d", serial) end,
        NormalizeEUITarget = function(_, entry) entry.euiTargetMode, entry.euiTargetFamily = "auto", "auto" end,
    }
    NS.Core.EUISoundRegistry = {
        ValidateEntry = function() return true, "valid" end,
        RegisterEntry = function()
            calls.register = calls.register + 1
            if options.registerError then error("register exploded") end
            return "sm:Test Sound", "sharedmedia_ready", false, true
        end,
    }
    NS.Integrations.EllesmereUI = {
        RemoveEntryFromAllRecordedScopes = function() return true, "removed", false end,
        Refresh = function() if options.integrationRefreshError then error("integration refresh exploded") end return true end,
        GetInjectionStatus = function() return options.injectStatus or "native_ready" end,
    }
    NS.InjectSavedEntry = function(_, entry)
        calls.inject = calls.inject + 1
        if options.onInject then options.onInject(entry) end
        if options.injectError then error("inject exploded") end
        return true, options.injectStatus or "batch_complete", options.injectStats or {
            injected = 1, upToDate = 0, waiting = 0, conflict = 0,
            invalidSound = 0, reloadRequired = 0, refreshRequired = true,
        }
    end
    NS.SavedListLayout = {
        InvalidateCache = function()
            calls.invalidate = calls.invalidate + 1
            if options.invalidateError then error("invalidate exploded") end
        end,
    }
    NS.UI.MainFrame = {
        RequestRefresh = function(_, reason, delay)
            calls.list = calls.list + 1
            calls.lastRefreshReason, calls.lastRefreshDelay = reason, delay
            if options.refreshError then error("refresh exploded") end
            return true
        end,
    }

    NS.API = {
        GetModes = function() return "tts", "sound" end,
        ResolveObjectType = function(_, value) return value or "spell" end,
        GetStoredEntryMap = function(classID, specID) return scopeMap(classID, specID, false) end,
        EnsureEntryMap = function(classID, specID) return scopeMap(classID, specID, true) end,
        FindFirstFreeIndex = function(map) for i = 1, 100 do if map[i] == nil then return i end end end,
        GetOrderedEntryIndices = function(map)
            local out = {}; for index in pairs(map) do if tonumber(index) then out[#out + 1] = tonumber(index) end end
            table.sort(out); return out
        end,
        GetEntry = function(map, index) return map and map[index] end,
        ClearEntryDeletedMarker = function() end,
        ResolveObjectName = function(id) return "Spell" .. tostring(id) end,
        ResolveObjectIcon = function() return nil end,
        ResolveClassName = function(id) return tostring(id) end,
        ResolveSpecName = function(_, id) return tostring(id) end,
        GetCurrentClassSpec = function() return 8, 62 end,
        RebuildRuntimeConfig = function() calls.legacy = calls.legacy + 1 end,
        RebuildCustomConfig = function() calls.legacy = calls.legacy + 1 end,
        RefreshRuntimeCooldowns = function() calls.legacy = calls.legacy + 1 end,
        RebuildCastSuccessConfig = function() calls.cast = calls.cast + 1 end,
        RefreshPanel = function() calls.list = calls.list + 1 end,
    }

    local state = {
        selectedKey = "", editingEntryUID = "", classID = 8, specID = 62,
        alertClassIDs = { [8] = true }, alertSpecIDs = { [62] = true }, alertRaceIDs = { [0] = true },
        entryType = "euiVoice", objectType = "spell", spellId = 207167, spellName = "Test Spell",
        euiTriggerType = "cdReady", notifyMode = "sound", soundSource = "builtin",
        soundPath = "Interface\\test.ogg", builtinSoundPath = "Interface\\test.ogg",
        voiceEnabled = true, imageEnabled = false, textEnabled = false, injectOnSave = true,
    }
    NS.AceOptions = {
        GetState = function() return state end,
        ResolveSoundSourceFields = function(_, source) return source end,
        NormalizeSoundPath = function(_, path) return path end,
        SaveEntry = function(self) return NS.EntryStore:SaveEntry(self) end,
    }

    assert(loadfile("EllesmereUIVE_Config/Core/CollectionStore.lua"))()
    assert(loadfile("EllesmereUIVE_Config/Core/EntryStore.lua"))()
    return { NS = NS, state = state, calls = calls, db = EllesmereUIVEDB, scopeMap = scopeMap }
end
