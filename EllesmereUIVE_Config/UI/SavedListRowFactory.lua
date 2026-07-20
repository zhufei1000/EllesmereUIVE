local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.SavedListRowFactory = NS.UI.SavedListRowFactory or {}

local RowFactory = NS.UI.SavedListRowFactory
local Skin = NS.UI.Skin
local SavedListDragDrop = NS.UI.SavedListDragDrop or {}
local SavedListContextMenu = NS.UI.SavedListContextMenu or {}
local Geometry = NS.UI.SavedListDragGeometry or {}

local ROW_HEIGHT = 28

local function HideRowDropPreview(row)
    if SavedListDragDrop and type(SavedListDragDrop.HideRowDropPreview) == "function" then
        return SavedListDragDrop:HideRowDropPreview(row)
    end
end

local function UpdateDropPreview(list, force)
    if SavedListDragDrop and type(SavedListDragDrop.UpdateDropPreview) == "function" then
        return SavedListDragDrop:UpdateDropPreview(list, force)
    end
end

local function StopDragVisual(list)
    if SavedListDragDrop and type(SavedListDragDrop.StopDragVisual) == "function" then
        return SavedListDragDrop:StopDragVisual(list)
    end
end

local function StartDragVisual(list, row)
    if SavedListDragDrop and type(SavedListDragDrop.StartDragVisual) == "function" then
        return SavedListDragDrop:StartDragVisual(list, row)
    end
end

local function OpenEntryMenu(list, key, entryType)
    if SavedListContextMenu and type(SavedListContextMenu.OpenEntryMenu) == "function" then
        return SavedListContextMenu:OpenEntryMenu(list, key, entryType)
    end
end

local function OpenGroupMenu(list, key)
    if SavedListContextMenu and type(SavedListContextMenu.OpenGroupMenu) == "function" then
        return SavedListContextMenu:OpenGroupMenu(list, key)
    end
end


local function IsGroupKey(key)
    return NS.AceOptions and type(NS.AceOptions.IsGroupKey) == "function" and NS.AceOptions:IsGroupKey(key)
end

local function SelectGroup(list, key)
    key = tostring(key or "")
    if key == "" or not list then
        return
    end
    local oldKey = tostring(list.GetSelectedKey and list:GetSelectedKey() or "")
    local oldEntryType = tostring(list.selectedEntryType or "")
    if list.SetSelectedKey then
        list:SetSelectedKey(key)
    else
        list.selectedKey = key
    end
    list.selectedEntryType = "group"

    if NS.AceOptions and type(NS.AceOptions.GetState) == "function" then
        local state = NS.AceOptions:GetState()
        state.selectedKey = key
        state.selectedCollectionKey = key
        state.entryType = state.entryType or "cooldown"
    end

    if type(list.onSelectionChanged) == "function" then
        list.onSelectionChanged(key, "group", oldKey, oldEntryType)
    elseif type(list.UpdateSelectionOnly) == "function" then
        list:UpdateSelectionOnly(oldKey, key)
    end
end

local function IsMouseOverFrame(frame)
    if Geometry and type(Geometry.IsCursorInsideFrame) == "function" then
        return Geometry:IsCursorInsideFrame(frame, 2)
    end
    if not frame or not frame.IsShown or not frame:IsShown() then
        return false
    end
    if frame.IsMouseOver then
        return frame:IsMouseOver()
    end
    local mouseIsOver = rawget(_G, "MouseIsOver")
    if type(mouseIsOver) == "function" then
        return mouseIsOver(frame)
    end
    return false
end

local function IsMouseOverList(list)
    if Geometry and type(Geometry.IsCursorInsideAny) == "function" then
        return Geometry:IsCursorInsideAny(list and list.content, list and list.scrollChild, list and list.scrollFrame, list and list.frame)
    end
    return IsMouseOverFrame(list and list.scrollFrame) or IsMouseOverFrame(list and list.frame) or IsMouseOverFrame(list and list.content)
end

local function BuildRootDropKeyForSourceRow(row)
    if not row or tostring(row.itemType or "") ~= "entry" or not row.groupID then
        return nil
    end
    local classID = tonumber(row.classID) or 0
    local specID = tonumber(row.specID) or 0
    if classID < 0 or specID < 0 then
        return nil
    end
    return string.format("root:%d:%d:after", classID, specID)
end

function RowFactory:SelectKey(list, key, entryType)
    key = tostring(key or "")
    if key == "" or not list then
        return
    end

    local oldKey = tostring(list.GetSelectedKey and list:GetSelectedKey() or "")
    local oldEntryType = tostring(list.selectedEntryType or "")
    local newEntryType = tostring(entryType or "")

    if list.SetSelectedKey then
        list:SetSelectedKey(key)
    else
        list.selectedKey = key
    end
    list.selectedEntryType = entryType

    -- Re-clicking the current row should only keep the visual selection in sync.
    -- Do not reload the entry or rebuild the whole saved list.
    if oldKey == key and oldEntryType == newEntryType then
        if type(list.UpdateSelectionOnly) == "function" then
            list:UpdateSelectionOnly(oldKey, key)
        end
        return
    end

    if type(list.onSelectionChanged) == "function" then
        list.onSelectionChanged(key, entryType, oldKey, oldEntryType)
        return
    end

    if NS.AceOptions and type(NS.AceOptions.GetState) == "function" then
        local state = NS.AceOptions:GetState()
        state.selectedKey = key
        state.selectedCollectionKey = nil
        state.entryType = entryType or state.entryType or "cooldown"
    end
    if NS.AceOptions and type(NS.AceOptions.LoadSelectedEntry) == "function" then
        NS.AceOptions:LoadSelectedEntry()
    end
    if type(list.UpdateSelectionOnly) == "function" then
        list:UpdateSelectionOnly(oldKey, key)
    end
end

function RowFactory:EnsureRow(list, index)
    list.rows = list.rows or {}
    if list.rows[index] then
        return list.rows[index]
    end

    local row = CreateFrame("Button", nil, list.content)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("LEFT", list.content, "LEFT", 0, 0)
    row:SetPoint("RIGHT", list.content, "RIGHT", -4, 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:RegisterForDrag("LeftButton")

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)
    bg:SetColorTexture(0, 0, 0, 0)
    row.bg = bg

    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
    hover:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)
    hover:SetColorTexture(0.24, 0.48, 1.00, 0.10)
    row.hover = hover

    local dropBG = row:CreateTexture(nil, "OVERLAY")
    dropBG:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
    dropBG:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)
    dropBG:SetColorTexture(0.24, 0.48, 1.00, 0.18)
    dropBG:Hide()
    row.dropBG = dropBG

    local dropLine = row:CreateTexture(nil, "OVERLAY")
    dropLine:SetHeight(4)
    dropLine:SetColorTexture(0.24, 0.55, 1.00, 0.95)
    dropLine:Hide()
    row.dropLine = dropLine

    local accent = row:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -3)
    accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 3)
    accent:SetWidth(3)
    accent:SetColorTexture(0.24, 0.48, 1.00, 0)
    row.accent = accent

    local divider = row:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 0)
    divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 0)
    divider:SetColorTexture(1, 1, 1, 0.035)
    row.divider = divider

    local statusDot = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusDot:SetText("●")
    statusDot:SetJustifyH("CENTER")
    statusDot:SetJustifyV("MIDDLE")
    if Skin then
        Skin:StyleFont(statusDot, "body")
    end
    row.statusDot = statusDot

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", row, "LEFT", 12, 0)
    row.icon = icon

    local main = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    main:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    main:SetPoint("RIGHT", row, "RIGHT", -12, 0)
    main:SetJustifyH("LEFT")
    main:SetJustifyV("MIDDLE")
    if main.SetWordWrap then
        main:SetWordWrap(false)
    end
    if main.SetMaxLines then
        main:SetMaxLines(1)
    end
    if Skin then
        Skin:StyleFont(main, "body")
    end
    row.main = main
    row.text = main

    row:SetScript("OnClick", function(_, button)
        if row.isPlaceholder then
            return
        end

        local key = row.key
        if row.itemType == "group-empty" then
            key = row.parentGroupKey or row.groupKey or row.dropKey or row.key
        end
        if not key or tostring(key or "") == "" then
            return
        end

        if row.itemType == "group" or row.itemType == "group-empty" or IsGroupKey(key) then
            SelectGroup(list, key)
            if button == "RightButton" then
                OpenGroupMenu(list, key)
            elseif row.itemType == "group" and type(list.ToggleGroupCollapsed) == "function" then
                list:ToggleGroupCollapsed(key)
            end
            return
        end

        if button == "RightButton" then
            OpenEntryMenu(list, key, row.entryType)
        else
            RowFactory:SelectKey(list, key, row.entryType)
        end
    end)

    row:SetScript("OnEnter", function()
        if list.dragKey then
            UpdateDropPreview(list, true)
        end
    end)

    row:SetScript("OnLeave", function()
        if list.dragHoverRow == row then
            list.dragHoverRow = nil
            list.dragHoverMode = nil
        end
        HideRowDropPreview(row)
    end)

    row:SetScript("OnDragStart", function()
        if not row.canDrag or not row.key or row.isPlaceholder then
            return
        end
        list.dragKey = row.key
        list.dragRow = row
        row.bg:SetColorTexture(0.24, 0.48, 1.00, 0.24)
        StartDragVisual(list, row)
    end)

    row:SetScript("OnDragStop", function()
        local sourceKey = list.dragKey
        if not sourceKey then
            StopDragVisual(list)
            return
        end

        UpdateDropPreview(list, true)
        local target = type(list.FindDropTarget) == "function" and list:FindDropTarget(row) or nil
        if not target and IsMouseOverList(list) then
            local rootDropKey = BuildRootDropKeyForSourceRow(row)
            if rootDropKey then
                target = { row = row, dropKey = rootDropKey, mode = "root" }
            end
        end

        if row.bg then
            row.bg:SetColorTexture(0, 0, 0, 0)
        end
        StopDragVisual(list)
        list.dragKey = nil
        list.dragRow = nil

        local moved = false
        if target and target.dropKey and NS.AceOptions and type(NS.AceOptions.MoveSavedListItem) == "function" then
            moved = NS.AceOptions:MoveSavedListItem(sourceKey, target.dropKey, target.row and target.row.displaySection, true) == true
        end

        if moved then
            if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.RequestRefresh) == "function" then
                NS.UI.MainFrame:RequestRefresh("list")
            elseif type(list.RequestRefresh) == "function" then
                list:RequestRefresh(0)
            end
        else
            -- No data changed. Only repaint the cached rows to clear transient
            -- drag visuals; avoid rebuilding all saved/group layout data.
            if not (type(list.RenderCached) == "function" and list:RenderCached()) and type(list.RequestRefresh) == "function" then
                list:RequestRefresh(0)
            end
        end
    end)

    list.rows[index] = row
    return row
end
