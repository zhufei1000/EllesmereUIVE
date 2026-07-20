local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.AceOptions = NS.AceOptions or {}

local L = NS.L or function(key, ...)
    if select("#", ...) > 0 then
        return string.format(tostring(key), ...)
    end
    return tostring(key)
end
local CONST = NS.Constants or {}
local OPTION_NAME = L("OPTION_NAME")
local ALL_CLASSES_ID = CONST.ALL_CLASSES_ID or 0
local ALL_SPECS_ID = CONST.ALL_SPECS_ID or 0

-- This file keeps legacy NS.AceOptions method names available while the real
-- implementation lives in smaller modules. UI code can continue using the old
-- calls, but AceOptions.lua no longer has to carry every bridge wrapper.

function NS.AceOptions:GetOptionName()
    return NS.ADDON_DISPLAY_NAME or OPTION_NAME
end

function NS.AceOptions:GetState()
    if NS.OptionsState and type(NS.OptionsState.GetState) == "function" then
        return NS.OptionsState:GetState(self)
    end
    self.state = self.state or {}
    return self.state
end

function NS.AceOptions:SyncScopeToCurrentSpec()
    if NS.OptionsState and type(NS.OptionsState.SyncScopeToCurrentSpec) == "function" then
        return NS.OptionsState:SyncScopeToCurrentSpec(self)
    end
end

function NS.AceOptions:GetClassOptionList()
    if NS.OptionsState and type(NS.OptionsState.GetClassOptionList) == "function" then
        return NS.OptionsState:GetClassOptionList(self)
    end
    return { { classID = ALL_CLASSES_ID, className = L("ALL_CLASSES"), classFile = nil } }
end

function NS.AceOptions:GetClassValues()
    if NS.OptionsState and type(NS.OptionsState.GetClassValues) == "function" then
        return NS.OptionsState:GetClassValues(self)
    end
    return {}
end

function NS.AceOptions:GetSpecOptionList(classID)
    if NS.OptionsState and type(NS.OptionsState.GetSpecOptionList) == "function" then
        return NS.OptionsState:GetSpecOptionList(self, classID)
    end
    return { { specID = ALL_SPECS_ID, specName = L("ALL_SPECS"), specIcon = nil } }
end

function NS.AceOptions:GetSpecValues(classID)
    if NS.OptionsState and type(NS.OptionsState.GetSpecValues) == "function" then
        return NS.OptionsState:GetSpecValues(self, classID)
    end
    return {}
end

function NS.AceOptions:EnsureValidScope()
    if NS.OptionsState and type(NS.OptionsState.EnsureValidScope) == "function" then
        return NS.OptionsState:EnsureValidScope(self)
    end
end

function NS.AceOptions:ClearEditorFields()
    if NS.OptionsState and type(NS.OptionsState.ClearEditorFields) == "function" then
        return NS.OptionsState:ClearEditorFields(self)
    end
end

function NS.AceOptions:GetEntryMap()
    if NS.EntryStore and type(NS.EntryStore.GetEntryMap) == "function" then
        return NS.EntryStore:GetEntryMap(self)
    end
    return {}
end

function NS.AceOptions:GetCurrentScopeEntryList()
    if NS.EntryStore and type(NS.EntryStore.GetCurrentScopeEntryList) == "function" then
        return NS.EntryStore:GetCurrentScopeEntryList(self)
    end
    return {}
end

function NS.AceOptions:GetAllSavedEntryList()
    if NS.EntryStore and type(NS.EntryStore.GetAllSavedEntryList) == "function" then
        return NS.EntryStore:GetAllSavedEntryList(self)
    end
    return {}
end

function NS.AceOptions:GetSavedListLayoutForScope(classID, specID, includeScopeText)
    if NS.SavedListLayout and type(NS.SavedListLayout.GetSavedListLayoutForScope) == "function" then
        return NS.SavedListLayout:GetSavedListLayoutForScope(self, classID, specID, includeScopeText)
    end
    return {}
end

function NS.AceOptions:MoveSavedListItem(sourceKey, targetKey, targetSection, suppressRefresh)
    if NS.SavedListMoveController and type(NS.SavedListMoveController.MoveSavedListItem) == "function" then
        return NS.SavedListMoveController:MoveSavedListItem(self, sourceKey, targetKey, targetSection, suppressRefresh)
    end
    return false
end

function NS.AceOptions:IsGroupKey(key)
    return tostring(key or ""):match("^group:") ~= nil
end
