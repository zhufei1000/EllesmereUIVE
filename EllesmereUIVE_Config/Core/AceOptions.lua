local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.AceOptions = NS.AceOptions or {}

local Utils = NS.Utils or {}

local function TrimText(value)
    if Utils.TrimText then
        return Utils.TrimText(value)
    end
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

NS.AceOptions.TrimText = TrimText

function NS.AceOptions:ApplySoundSourceToState(fields)
    local state = self:GetState()
    fields = type(fields) == "table" and fields or self:ResolveSoundSourceFields(state)
    state.notifyMode = fields.notifyMode
    state.soundSource = fields.soundSource
    state.soundPath = fields.soundPath
    state.builtinSoundPath = fields.builtinSoundPath
    state.customSoundPath = fields.customSoundPath
    state.sharedMediaSound = fields.sharedMediaSound
    state.useCustomSound = fields.useCustomSound == true
    state.useSharedMediaSound = fields.useSharedMediaSound == true
end

local function GetCollectionController()
    return NS.CollectionController
end

function NS.AceOptions:ResolveCollectionIcon(value)
    local controller = GetCollectionController()
    if controller and type(controller.ResolveCollectionIcon) == "function" then
        return controller:ResolveCollectionIcon(value)
    end
    if NS.CollectionStore and type(NS.CollectionStore.ResolveCollectionIcon) == "function" then
        return NS.CollectionStore.ResolveCollectionIcon(value)
    end
    return nil
end

function NS.AceOptions:CreateCollection(name, iconID, explicitParentGroupKey, suppressRefresh)
    local controller = GetCollectionController()
    if controller and type(controller.CreateCollection) == "function" then
        return controller:CreateCollection(self, name, iconID, explicitParentGroupKey, suppressRefresh)
    end
    return false
end

function NS.AceOptions:GetCollectionInfo(groupKey)
    local controller = GetCollectionController()
    if controller and type(controller.GetCollectionInfo) == "function" then
        return controller:GetCollectionInfo(groupKey)
    end
    return nil
end

function NS.AceOptions:RenameCollection(groupKey, name, iconID, suppressRefresh)
    local controller = GetCollectionController()
    if controller and type(controller.RenameCollection) == "function" then
        return controller:RenameCollection(groupKey, name, iconID, suppressRefresh)
    end
    return false
end

function NS.AceOptions:DeleteCollection(groupKey, suppressRefresh)
    local controller = GetCollectionController()
    if controller and type(controller.DeleteCollection) == "function" then
        return controller:DeleteCollection(self, groupKey, suppressRefresh)
    end
    return false
end
