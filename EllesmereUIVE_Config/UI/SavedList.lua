local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.SavedList = NS.UI.SavedList or {}

local SavedList = NS.UI.SavedList
local Skin = NS.UI.Skin
local ScrollBar = NS.UI.ScrollBar
local Utils = NS.Utils or {}
local L = NS.L or function(key, ...) if select("#", ...) > 0 then return string.format(tostring(key), ...) end return tostring(key) end
local SavedListRows = NS.UI.SavedListRows or {}
local SavedListBuilder = NS.UI.SavedListBuilder or {}
local SavedListDragDrop = NS.UI.SavedListDragDrop or {}
local SavedListContextMenu = NS.UI.SavedListContextMenu or {}
local SavedListRenderer = NS.UI.SavedListRenderer or {}
local SavedListRefresh = NS.UI.SavedListRefresh or {}

local ROW_HEIGHT = 28
local GROUP_ROW_HEIGHT = 30
local EMPTY_ROW_HEIGHT = 24
local HEADER_HEIGHT = 32

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


local function SafeCreateFrame(frameType, name, parent, templates)
    if type(templates) == "string" then
        templates = { templates }
    end
    if type(templates) == "table" then
        for _, template in ipairs(templates) do
            if template and template ~= "" then
                local ok, frame = pcall(CreateFrame, frameType, name, parent, template)
                if ok and frame then
                    return frame
                end
            end
        end
    end
    return CreateFrame(frameType, name, parent)
end

local function TrimText(value)
    if Utils.TrimText then
        return Utils.TrimText(value)
    end
    value = tostring(value or "")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return value
end

local function GetGroupDataByKey(groupKey)
    if SavedListBuilder and type(SavedListBuilder.GetGroupDataByKey) == "function" then
        return SavedListBuilder.GetGroupDataByKey(groupKey)
    end
    return nil
end

local function ToggleGroupCollapsed(groupKey)
    if SavedListBuilder and type(SavedListBuilder.ToggleGroupCollapsed) == "function" then
        return SavedListBuilder.ToggleGroupCollapsed(groupKey)
    end
    return false
end

function SavedList:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -12)
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -12, 12)

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 0)
    scrollFrame:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetPoint("TOPLEFT", 0, 0)
    content:SetPoint("TOPRIGHT", 0, 0)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)

    local slider = ScrollBar and ScrollBar.Create and ScrollBar:Create(scrollFrame, "EllesmereUIVESavedListScrollBar", {
        orientation = "VERTICAL",
        width = 16,
        minValue = 0,
        maxValue = 0,
        valueStep = 1,
        value = 0,
        obeyStepOnDrag = false,
    }) or SafeCreateFrame("Slider", "EllesmereUIVESavedListScrollBar", scrollFrame, {
        "UIPanelScrollBarTemplate",
        "OptionsSliderTemplate",
        "BackdropTemplate",
    })
    if ScrollBar and ScrollBar.ClearInheritedScripts then
        ScrollBar:ClearInheritedScripts(slider)
    end
    slider:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 6, -16)
    slider:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 6, 16)
    slider:Hide()

    local list = {
        frame = frame,
        scrollFrame = scrollFrame,
        content = content,
        slider = slider,
        rows = {},
        headers = {},
        selectedKey = nil,
        state = NS.AceOptions:GetState(),
        onSelectionChanged = nil,
        menuFrame = nil,
        contextMenu = nil,
        contextBlocker = nil,
        dragKey = nil,
        dragRow = nil,
    }

    slider:SetScript("OnValueChanged", function(_, value)
        scrollFrame:SetVerticalScroll(value or 0)
        if list and list._savedListVirtualized and SavedListRenderer and type(SavedListRenderer.RenderVisibleRows) == "function" then
            SavedListRenderer:RenderVisibleRows(list)
        end
    end)

    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        local minValue, maxValue = slider:GetMinMaxValues()
        local nextValue = (slider:GetValue() or 0) - ((delta or 0) * ROW_HEIGHT)
        if nextValue < minValue then
            nextValue = minValue
        end
        if nextValue > maxValue then
            nextValue = maxValue
        end
        slider:SetValue(nextValue)
    end)

    scrollFrame:SetScript("OnSizeChanged", function(_, width)
        if width and width > 0 then
            content:SetWidth(width)
        end
        if list and list._savedListVirtualized and SavedListRenderer and type(SavedListRenderer.RenderVisibleRows) == "function" then
            SavedListRenderer:RenderVisibleRows(list)
        end
    end)

    setmetatable(list, { __index = self })
    return list
end

function SavedList:RequestRefresh(delay)
    if SavedListRefresh and type(SavedListRefresh.RequestRefresh) == "function" then
        return SavedListRefresh:RequestRefresh(self, delay)
    end
    if self._refreshPending then
        return
    end
    self._refreshPending = true
    CallSoon(function()
        self._refreshPending = false
        if self.frame and self.frame.IsShown and self.frame:IsShown() then
            self:Refresh()
        end
    end, delay or 0)
end

function SavedList:SetOnSelectionChanged(callback)
    self.onSelectionChanged = callback
end

function SavedList:SetSelectedKey(key)
    self.selectedKey = tostring(key or "")
end

function SavedList:GetSelectedKey()
    return self.selectedKey
end

function SavedList:SelectKey(key, entryType)
    if SavedListRenderer and type(SavedListRenderer.SelectKey) == "function" then
        return SavedListRenderer:SelectKey(self, key, entryType)
    end
    return false
end

function SavedList:UpdateSelectionOnly(oldKey, newKey)
    local selection = NS.UI and NS.UI.SavedListSelection
    if selection and type(selection.UpdateSelectionOnly) == "function" then
        return selection:UpdateSelectionOnly(self, oldKey, newKey)
    end

    newKey = tostring(newKey or self.selectedKey or "")
    self.selectedKey = newKey
end

function SavedList:FindDropTarget(sourceRow)
    if SavedListDragDrop and type(SavedListDragDrop.FindDropTarget) == "function" then
        return SavedListDragDrop:FindDropTarget(self, sourceRow)
    end
    return nil
end



local function RenderEntryRows(list, state, selectedKey, loadedEntries, unloadedEntries, loadedDisplayCount, unloadedDisplayCount)
    if SavedListRenderer and type(SavedListRenderer.RenderEntryRows) == "function" then
        return SavedListRenderer:RenderEntryRows(list, state, selectedKey, loadedEntries, unloadedEntries, loadedDisplayCount, unloadedDisplayCount)
    end
    return false
end

function SavedList:RenderCached()
    if SavedListRefresh and type(SavedListRefresh.RenderCached) == "function" then
        return SavedListRefresh:RenderCached(self)
    end
    local loadedEntries = self._cachedLoadedEntries
    local unloadedEntries = self._cachedUnloadedEntries
    if type(loadedEntries) ~= "table" or type(unloadedEntries) ~= "table" then
        return false
    end

    local state = self.state or (NS.AceOptions and NS.AceOptions.GetState and NS.AceOptions:GetState()) or {}
    self.state = state
    local selectedKey = tostring(self.selectedKey or state.selectedKey or "")
    local loadedDisplayCount = tonumber(self._cachedLoadedDisplayCount) or 0
    local unloadedDisplayCount = tonumber(self._cachedUnloadedDisplayCount) or 0

    return RenderEntryRows(self, state, selectedKey, loadedEntries, unloadedEntries, loadedDisplayCount, unloadedDisplayCount)
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

local function CollapseCachedGroupRows(rows, groupKey)
    if SavedListBuilder and type(SavedListBuilder.CollapseCachedGroupRows) == "function" then
        return SavedListBuilder.CollapseCachedGroupRows(rows, groupKey)
    end
    return false, rows
end

function SavedList:ToggleGroupCollapsed(groupKey)
    if SavedListRefresh and type(SavedListRefresh.ToggleGroupCollapsed) == "function" then
        return SavedListRefresh:ToggleGroupCollapsed(self, groupKey)
    end
    groupKey = TrimText(groupKey)
    if groupKey == "" then
        return false
    end

    local group = GetGroupDataByKey(groupKey)
    local wasCollapsed = type(group) == "table" and group.collapsed == true
    if not ToggleGroupCollapsed(groupKey) then
        return false
    end

    if not wasCollapsed then
        local changedLoaded, nextLoaded = CollapseCachedGroupRows(self._cachedLoadedEntries, groupKey)
        local changedUnloaded, nextUnloaded = CollapseCachedGroupRows(self._cachedUnloadedEntries, groupKey)
        if changedLoaded or changedUnloaded then
            if changedLoaded then
                self._cachedLoadedEntries = nextLoaded
                self._cachedLoadedDisplayCount = CountVisibleHeaderItems(nextLoaded)
            end
            if changedUnloaded then
                self._cachedUnloadedEntries = nextUnloaded
                self._cachedUnloadedDisplayCount = CountVisibleHeaderItems(nextUnloaded)
            end
            self:RenderCached()
            return true
        end
    end

    self:RequestRefresh(0)
    return true
end

function SavedList:Refresh()
    if SavedListRefresh and type(SavedListRefresh.Refresh) == "function" then
        return SavedListRefresh:Refresh(self)
    end
    local state = self.state or NS.AceOptions:GetState()
    self.state = state
    local selectedKey = tostring(self.selectedKey or state.selectedKey or "")

    local loadedEntries, unloadedEntries, loadedDisplayCount, unloadedDisplayCount
    if SavedListBuilder and type(SavedListBuilder.BuildLayout) == "function" then
        loadedEntries, unloadedEntries, loadedDisplayCount, unloadedDisplayCount = SavedListBuilder.BuildLayout(self, state)
    end

    loadedEntries = type(loadedEntries) == "table" and loadedEntries or {}
    unloadedEntries = type(unloadedEntries) == "table" and unloadedEntries or {}
    loadedDisplayCount = tonumber(loadedDisplayCount) or CountVisibleHeaderItems(loadedEntries)
    unloadedDisplayCount = tonumber(unloadedDisplayCount) or CountVisibleHeaderItems(unloadedEntries)

    self._cachedLoadedEntries = loadedEntries
    self._cachedUnloadedEntries = unloadedEntries
    self._cachedLoadedDisplayCount = loadedDisplayCount
    self._cachedUnloadedDisplayCount = unloadedDisplayCount

    RenderEntryRows(self, state, selectedKey, loadedEntries, unloadedEntries, loadedDisplayCount, unloadedDisplayCount)
end
