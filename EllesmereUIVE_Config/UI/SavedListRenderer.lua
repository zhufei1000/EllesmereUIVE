local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.SavedListRenderer = NS.UI.SavedListRenderer or {}

local Renderer = NS.UI.SavedListRenderer
local SavedListRowFactory = NS.UI.SavedListRowFactory or {}
local SavedListRowRenderer = NS.UI.SavedListRowRenderer or {}
local SavedListHeaders = NS.UI.SavedListHeaders or {}
local L = NS.L or function(key, ...) if select("#", ...) > 0 then return string.format(tostring(key), ...) end return tostring(key) end

local ROW_HEIGHT = 28
local GROUP_ROW_HEIGHT = 30
local EMPTY_ROW_HEIGHT = 24
local HEADER_HEIGHT = 32
local VIRTUALIZE_MIN_ITEMS = 90
local VIRTUAL_OVERSCAN = 96

local function GetRowHeightForEntry(entry)
    local itemType = tostring(entry and entry.itemType or "entry")
    if itemType == "group" then
        return GROUP_ROW_HEIGHT
    elseif itemType == "group-empty" then
        return EMPTY_ROW_HEIGHT
    end
    return ROW_HEIGHT
end

local function EnsureRow(list, index)
    if SavedListRowFactory and type(SavedListRowFactory.EnsureRow) == "function" then
        return SavedListRowFactory:EnsureRow(list, index)
    end
    list.rows = list.rows or {}
    if list.rows[index] then
        return list.rows[index]
    end
    local row = CreateFrame("Button", nil, list.content)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("LEFT", list.content, "LEFT", 0, 0)
    row:SetPoint("RIGHT", list.content, "RIGHT", -4, 0)
    row.main = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.main:SetPoint("LEFT", row, "LEFT", 12, 0)
    row.main:SetPoint("RIGHT", row, "RIGHT", -12, 0)
    row.text = row.main
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.accent = row:CreateTexture(nil, "ARTWORK")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.statusDot = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    list.rows[index] = row
    return row
end

local function EnsureHeader(list, index)
    if SavedListHeaders and type(SavedListHeaders.EnsureHeader) == "function" then
        return SavedListHeaders:EnsureHeader(list, index)
    end

    -- Minimal fallback for defensive loading; the normal path is UI/SavedListHeaders.lua.
    list.headers = list.headers or {}
    if list.headers[index] then
        return list.headers[index]
    end
    local header = CreateFrame("Button", nil, list.content)
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("LEFT", list.content, "LEFT", 0, 0)
    header:SetPoint("RIGHT", list.content, "RIGHT", -4, 0)
    header.label = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.label:SetPoint("LEFT", header, "LEFT", 8, 0)
    header.arrow = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.arrow:SetPoint("RIGHT", header, "RIGHT", -8, 0)
    list.headers[index] = header
    return header
end

local function HideUnusedFrames(list, rowIndex, headerIndex)
    for index = rowIndex, #((list and list.rows) or {}) do
        local row = list.rows[index]
        if row then
            row:Hide()
        end
    end
    for index = headerIndex, #((list and list.headers) or {}) do
        local header = list.headers[index]
        if header then
            header:Hide()
        end
    end
end

local function PlaceFrame(list, frame, yOffset, height)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", list.content, "TOPLEFT", 0, -yOffset)
    frame:SetPoint("RIGHT", list.content, "RIGHT", -4, 0)
    frame:SetHeight(height)
    frame:Show()
end

local function SetHeaderText(header, sectionKey, title, count, state)
    header.sectionKey = sectionKey
    local collapsed = sectionKey == "loaded" and state.loadedCollapsed or state.unloadedCollapsed
    if header.label then
        header.label:SetText(string.format("%s（%d）", title, count))
    end
    if header.arrow then
        header.arrow:SetText(collapsed and "+" or "-")
    end
end

local function UpdateScrollState(list, contentHeight, viewportHeight)
    viewportHeight = math.max(tonumber(viewportHeight) or 0, 1)
    contentHeight = math.max(tonumber(contentHeight) or 0, viewportHeight)
    list.content:SetHeight(contentHeight)

    local maxScroll = math.max(contentHeight - viewportHeight, 0)
    local currentValue = tonumber(list.slider:GetValue()) or 0

    if maxScroll > 0 then
        list.slider:Show()
        list.slider:SetMinMaxValues(0, maxScroll)
        if currentValue > maxScroll then
            list.slider:SetValue(maxScroll)
        end
    else
        list.slider:SetMinMaxValues(0, 0)
        list.slider:SetValue(0)
        list.slider:Hide()
        list.scrollFrame:SetVerticalScroll(0)
    end
end

local function BuildVirtualItems(state, loadedEntries, unloadedEntries, loadedDisplayCount, unloadedDisplayCount)
    local items = {}
    local yOffset = 0

    local function addHeader(sectionKey, title, count)
        items[#items + 1] = {
            kind = "header",
            sectionKey = sectionKey,
            title = title,
            count = tonumber(count) or 0,
            top = yOffset,
            height = HEADER_HEIGHT,
        }
        yOffset = yOffset + HEADER_HEIGHT
    end

    local function addRow(entry, includeScopeText, isPlaceholder, canDrag, canDrop)
        local height = GetRowHeightForEntry(entry)
        items[#items + 1] = {
            kind = "row",
            entry = entry,
            includeScopeText = includeScopeText == true,
            isPlaceholder = isPlaceholder == true,
            canDrag = canDrag == true,
            canDrop = canDrop == true,
            top = yOffset,
            height = height,
        }
        yOffset = yOffset + height
    end

    addHeader("loaded", L("HEADER_LOADED"), loadedDisplayCount)
    if not state.loadedCollapsed then
        if #loadedEntries == 0 then
            addRow({
                key = "__empty_loaded",
                itemType = "entry",
                spellName = L("EMPTY_CONFIG"),
                index = 0,
                spellId = 0,
                modeText = "",
                icon = 134400,
            }, false, true, false, false)
        else
            for _, entry in ipairs(loadedEntries) do
                addRow(entry, false, false, true, true)
            end
        end
    end

    addHeader("unloaded", L("HEADER_UNLOADED"), unloadedDisplayCount)
    if not state.unloadedCollapsed then
        if #unloadedEntries == 0 then
            addRow({
                key = "__empty_unloaded",
                itemType = "entry",
                spellName = L("EMPTY_CONFIG"),
                index = 0,
                spellId = 0,
                modeText = "",
                icon = 134400,
            }, false, true, false, false)
        else
            for _, entry in ipairs(unloadedEntries) do
                addRow(entry, true, false, true, true)
            end
        end
    end

    return items, yOffset
end

local function RenderFullRows(list, state, selectedKey, loadedEntries, unloadedEntries, loadedDisplayCount, unloadedDisplayCount)
    local yOffset = 0
    local rowIndex = 1
    local headerIndex = 1
    local selectedExists = false

    local function placeFrame(frame, height)
        PlaceFrame(list, frame, yOffset, height)
        yOffset = yOffset + height
    end

    local function updateHeader(sectionKey, title, count)
        local header = EnsureHeader(list, headerIndex)
        SetHeaderText(header, sectionKey, title, count, state)
        placeFrame(header, HEADER_HEIGHT)
        headerIndex = headerIndex + 1
    end

    local function updateRow(entry, includeScopeText, isPlaceholder, canDrag, canDrop)
        local row = EnsureRow(list, rowIndex)
        local selected, height = false, ROW_HEIGHT
        if SavedListRowRenderer and type(SavedListRowRenderer.UpdateRow) == "function" then
            selected, height = SavedListRowRenderer:UpdateRow(row, entry, {
                includeScopeText = includeScopeText,
                isPlaceholder = isPlaceholder,
                canDrag = canDrag,
                canDrop = canDrop,
                selectedKey = selectedKey,
            })
        end
        if selected then
            selectedExists = true
        end
        placeFrame(row, height or ROW_HEIGHT)
        rowIndex = rowIndex + 1
    end

    updateHeader("loaded", L("HEADER_LOADED"), loadedDisplayCount)
    if not state.loadedCollapsed then
        if #loadedEntries == 0 then
            updateRow({
                key = "__empty_loaded",
                itemType = "entry",
                spellName = L("EMPTY_CONFIG"),
                index = 0,
                spellId = 0,
                modeText = "",
                icon = 134400,
            }, false, true, false, false)
        else
            for _, entry in ipairs(loadedEntries) do
                updateRow(entry, false, false, true, true)
            end
        end
    end

    updateHeader("unloaded", L("HEADER_UNLOADED"), unloadedDisplayCount)
    if not state.unloadedCollapsed then
        if #unloadedEntries == 0 then
            updateRow({
                key = "__empty_unloaded",
                itemType = "entry",
                spellName = L("EMPTY_CONFIG"),
                index = 0,
                spellId = 0,
                modeText = "",
                icon = 134400,
            }, false, true, false, false)
        else
            for _, entry in ipairs(unloadedEntries) do
                updateRow(entry, true, false, true, true)
            end
        end
    end

    HideUnusedFrames(list, rowIndex, headerIndex)

    if selectedKey ~= "" and not selectedExists then
        list.selectedKey = nil
    end

    list._savedListVirtualized = false
    list._savedListVirtualItems = nil
    list._savedListVirtualSelectedExists = nil
    local viewportHeight = list.frame:GetHeight()
    UpdateScrollState(list, yOffset, viewportHeight)
    return true
end

local function RenderVirtualVisibleRows(list, selectedKey)
    if not list or not list._savedListVirtualized then
        return false
    end

    local items = list._savedListVirtualItems
    if type(items) ~= "table" then
        return false
    end

    local state = list.state or {}
    local viewportHeight = math.max(tonumber(list.frame and list.frame:GetHeight()) or 0, 1)
    local scrollValue = tonumber(list.slider and list.slider:GetValue()) or 0
    local firstY = math.max(scrollValue - VIRTUAL_OVERSCAN, 0)
    local lastY = scrollValue + viewportHeight + VIRTUAL_OVERSCAN
    local rowIndex = 1
    local headerIndex = 1
    local selectedExists = false

    selectedKey = tostring(selectedKey or list.selectedKey or "")

    for _, item in ipairs(items) do
        local top = tonumber(item.top) or 0
        local height = tonumber(item.height) or ROW_HEIGHT
        if (top + height) >= firstY and top <= lastY then
            if item.kind == "header" then
                local header = EnsureHeader(list, headerIndex)
                SetHeaderText(header, item.sectionKey, item.title, item.count, state)
                PlaceFrame(list, header, top, height)
                headerIndex = headerIndex + 1
            else
                local row = EnsureRow(list, rowIndex)
                local selected, actualHeight = false, height
                if SavedListRowRenderer and type(SavedListRowRenderer.UpdateRow) == "function" then
                    selected, actualHeight = SavedListRowRenderer:UpdateRow(row, item.entry, {
                        includeScopeText = item.includeScopeText,
                        isPlaceholder = item.isPlaceholder,
                        canDrag = item.canDrag,
                        canDrop = item.canDrop,
                        selectedKey = selectedKey,
                    })
                end
                if selected then
                    selectedExists = true
                end
                PlaceFrame(list, row, top, actualHeight or height)
                rowIndex = rowIndex + 1
            end
        end
    end

    HideUnusedFrames(list, rowIndex, headerIndex)

    -- 在虚拟列表中，选中的行可能在当前视口外。这里用布局阶段记录的结果，
    -- 不因为“当前没渲染到屏幕上”就清空选择。
    if selectedKey ~= "" and list._savedListVirtualSelectedExists == false then
        list.selectedKey = nil
    end

    return true
end

local function RenderVirtualRows(list, state, selectedKey, loadedEntries, unloadedEntries, loadedDisplayCount, unloadedDisplayCount)
    local items, contentHeight = BuildVirtualItems(state, loadedEntries, unloadedEntries, loadedDisplayCount, unloadedDisplayCount)
    local selectedExists = false
    if selectedKey ~= "" then
        for _, item in ipairs(items) do
            if item.kind == "row" and item.entry and tostring(item.entry.key or "") == selectedKey then
                selectedExists = true
                break
            end
        end
    end

    list._savedListVirtualized = true
    list._savedListVirtualItems = items
    list._savedListVirtualSelectedExists = selectedKey == "" or selectedExists
    list._savedListVirtualContentHeight = contentHeight

    local viewportHeight = list.frame:GetHeight()
    UpdateScrollState(list, contentHeight, viewportHeight)
    RenderVirtualVisibleRows(list, selectedKey)
    return true
end

function Renderer:SelectKey(list, key, entryType)
    if SavedListRowFactory and type(SavedListRowFactory.SelectKey) == "function" then
        return SavedListRowFactory:SelectKey(list, key, entryType)
    end
end

function Renderer:RenderVisibleRows(list)
    if not list or not list._savedListVirtualized then
        return false
    end
    return RenderVirtualVisibleRows(list, tostring(list.selectedKey or ""))
end

function Renderer:RenderEntryRows(list, state, selectedKey, loadedEntries, unloadedEntries, loadedDisplayCount, unloadedDisplayCount)
    state = state or {}
    loadedEntries = type(loadedEntries) == "table" and loadedEntries or {}
    unloadedEntries = type(unloadedEntries) == "table" and unloadedEntries or {}

    local totalRows = #loadedEntries + #unloadedEntries
    if state.loadedCollapsed then
        totalRows = totalRows - #loadedEntries
    end
    if state.unloadedCollapsed then
        totalRows = totalRows - #unloadedEntries
    end

    -- 拖拽中不复用可见行，避免滚动时源行被虚拟列表重绘。
    if totalRows >= VIRTUALIZE_MIN_ITEMS and not list.dragKey then
        return RenderVirtualRows(list, state, selectedKey, loadedEntries, unloadedEntries, loadedDisplayCount, unloadedDisplayCount)
    end

    return RenderFullRows(list, state, selectedKey, loadedEntries, unloadedEntries, loadedDisplayCount, unloadedDisplayCount)
end
