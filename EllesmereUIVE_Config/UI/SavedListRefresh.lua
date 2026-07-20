local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.SavedListRefresh = NS.UI.SavedListRefresh or {}

local Refresh = NS.UI.SavedListRefresh
local Utils = NS.Utils or {}
local SavedListBuilder = NS.UI.SavedListBuilder or {}
local SavedListRenderer = NS.UI.SavedListRenderer or {}

local function TrimText(value)
    if Utils.TrimText then
        return Utils.TrimText(value)
    end
    value = tostring(value or "")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return value
end

local function CallSoon(callback, delay)
    if type(callback) ~= "function" then
        return
    end
    delay = tonumber(delay) or 0
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(delay, callback)
    else
        callback()
    end
end

local function CountVisibleHeaderItems(rows)
    if SavedListBuilder and type(SavedListBuilder.CountVisibleHeaderItems) == "function" then
        return SavedListBuilder.CountVisibleHeaderItems(rows)
    end
    local count = 0
    for _, entry in ipairs(rows or {}) do
        if tostring(entry and entry.itemType or "entry") ~= "group-empty" then
            count = count + 1
        end
    end
    return count
end

local function RenderEntryRows(list, state, selectedKey, loadedEntries, unloadedEntries, loadedDisplayCount, unloadedDisplayCount)
    if SavedListRenderer and type(SavedListRenderer.RenderEntryRows) == "function" then
        return SavedListRenderer:RenderEntryRows(list, state, selectedKey, loadedEntries, unloadedEntries, loadedDisplayCount, unloadedDisplayCount)
    end
    return false
end

function Refresh:RequestRefresh(list, delay)
    if not list then
        return false
    end
    if list._refreshPending then
        return true
    end
    list._refreshPending = true
    CallSoon(function()
        list._refreshPending = false
        if list.frame and list.frame.IsShown and list.frame:IsShown() then
            self:Refresh(list)
        end
    end, delay or 0)
    return true
end

function Refresh:RenderCached(list)
    if not list then
        return false
    end
    local loadedEntries = list._cachedLoadedEntries
    local unloadedEntries = list._cachedUnloadedEntries
    if type(loadedEntries) ~= "table" or type(unloadedEntries) ~= "table" then
        return false
    end

    local state = list.state or (NS.AceOptions and NS.AceOptions.GetState and NS.AceOptions:GetState()) or {}
    list.state = state
    local selectedKey = tostring(list.selectedKey or state.selectedKey or "")
    local loadedDisplayCount = tonumber(list._cachedLoadedDisplayCount) or 0
    local unloadedDisplayCount = tonumber(list._cachedUnloadedDisplayCount) or 0

    return RenderEntryRows(list, state, selectedKey, loadedEntries, unloadedEntries, loadedDisplayCount, unloadedDisplayCount)
end

function Refresh:ToggleGroupCollapsed(list, groupKey)
    if not list then
        return false
    end
    groupKey = TrimText(groupKey)
    if groupKey == "" then
        return false
    end

    local getGroup = SavedListBuilder and SavedListBuilder.GetGroupDataByKey
    local toggleGroup = SavedListBuilder and SavedListBuilder.ToggleGroupCollapsed
    local collapseRows = SavedListBuilder and SavedListBuilder.CollapseCachedGroupRows
    local expandRows = SavedListBuilder and SavedListBuilder.ExpandCachedGroupRows

    local group = type(getGroup) == "function" and getGroup(groupKey) or nil
    local wasCollapsed = type(group) == "table" and group.collapsed == true
    if not (type(toggleGroup) == "function" and toggleGroup(groupKey)) then
        return false
    end

    -- 收拢只删除缓存里的可见子行，不重算所有职业/专精/合集布局。
    if not wasCollapsed and type(collapseRows) == "function" then
        local changedLoaded, nextLoaded = collapseRows(list._cachedLoadedEntries, groupKey)
        local changedUnloaded, nextUnloaded = collapseRows(list._cachedUnloadedEntries, groupKey)
        if changedLoaded or changedUnloaded then
            if changedLoaded then
                list._cachedLoadedEntries = nextLoaded
                list._cachedLoadedDisplayCount = CountVisibleHeaderItems(nextLoaded)
            end
            if changedUnloaded then
                list._cachedUnloadedEntries = nextUnloaded
                list._cachedUnloadedDisplayCount = CountVisibleHeaderItems(nextUnloaded)
            end
            self:RenderCached(list)
            return true
        end
    end

    -- 展开只重建当前合集所在 scope，并把子行插入缓存，避免全列表重建。
    if wasCollapsed and type(expandRows) == "function" then
        local changedLoaded, nextLoaded = expandRows(list._cachedLoadedEntries, groupKey)
        local changedUnloaded, nextUnloaded = expandRows(list._cachedUnloadedEntries, groupKey)
        if changedLoaded or changedUnloaded then
            if changedLoaded then
                list._cachedLoadedEntries = nextLoaded
                list._cachedLoadedDisplayCount = CountVisibleHeaderItems(nextLoaded)
            end
            if changedUnloaded then
                list._cachedUnloadedEntries = nextUnloaded
                list._cachedUnloadedDisplayCount = CountVisibleHeaderItems(nextUnloaded)
            end
            self:RenderCached(list)
            return true
        end
    end

    -- 缓存缺失时才退回全量刷新。
    self:RequestRefresh(list, 0)
    return true
end

function Refresh:Refresh(list)
    if not list then
        return false
    end
    if list._refreshBuilding then
        list._refreshQueuedAfterBuild = true
        return false
    end
    list._refreshBuilding = true

    local state = list.state or (NS.AceOptions and NS.AceOptions.GetState and NS.AceOptions:GetState()) or {}
    list.state = state
    local selectedKey = tostring(list.selectedKey or state.selectedKey or "")

    local loadedEntries, unloadedEntries, loadedDisplayCount, unloadedDisplayCount
    if SavedListBuilder and type(SavedListBuilder.BuildLayout) == "function" then
        loadedEntries, unloadedEntries, loadedDisplayCount, unloadedDisplayCount = SavedListBuilder.BuildLayout(list, state)
    end

    loadedEntries = type(loadedEntries) == "table" and loadedEntries or {}
    unloadedEntries = type(unloadedEntries) == "table" and unloadedEntries or {}
    loadedDisplayCount = tonumber(loadedDisplayCount) or CountVisibleHeaderItems(loadedEntries)
    unloadedDisplayCount = tonumber(unloadedDisplayCount) or CountVisibleHeaderItems(unloadedEntries)

    list._cachedLoadedEntries = loadedEntries
    list._cachedUnloadedEntries = unloadedEntries
    list._cachedLoadedDisplayCount = loadedDisplayCount
    list._cachedUnloadedDisplayCount = unloadedDisplayCount

    RenderEntryRows(list, state, selectedKey, loadedEntries, unloadedEntries, loadedDisplayCount, unloadedDisplayCount)

    list._refreshBuilding = false
    if list._refreshQueuedAfterBuild then
        list._refreshQueuedAfterBuild = false
        self:RequestRefresh(list, 0)
    end

    if collectgarbage and not list._gcStepPending then
        list._gcStepPending = true
        CallSoon(function()
            list._gcStepPending = false
            collectgarbage("step", 64)
        end, 0.5)
    end
    return true
end
