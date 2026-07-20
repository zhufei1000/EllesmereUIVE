local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.SavedListRowRenderer = NS.UI.SavedListRowRenderer or {}

local RowRenderer = NS.UI.SavedListRowRenderer
local SavedListRows = NS.UI.SavedListRows or {}
local SavedListDragDrop = NS.UI.SavedListDragDrop or {}
local L = NS.L or function(key, ...) if select("#", ...) > 0 then return string.format(tostring(key), ...) end return tostring(key) end

local ROW_HEIGHT = 28
local GROUP_ROW_HEIGHT = 30
local EMPTY_ROW_HEIGHT = 24

local function BuildEntryRowText(entry, includeScopeText)
    if SavedListRows and type(SavedListRows.BuildEntryRowText) == "function" then
        return SavedListRows.BuildEntryRowText(entry, includeScopeText)
    end
    return tostring((entry and entry.spellName) or "")
end

local function BuildGroupRowText(entry)
    if SavedListRows and type(SavedListRows.BuildGroupRowText) == "function" then
        return SavedListRows.BuildGroupRowText(entry)
    end
    return tostring((entry and entry.name) or "")
end

local function HideRowDropPreview(row)
    if SavedListDragDrop and type(SavedListDragDrop.HideRowDropPreview) == "function" then
        return SavedListDragDrop:HideRowDropPreview(row)
    end
end

local function GetRowHeight(itemType)
    if itemType == "group" then
        return GROUP_ROW_HEIGHT
    elseif itemType == "group-empty" then
        return EMPTY_ROW_HEIGHT
    end
    return ROW_HEIGHT
end

function RowRenderer:UpdateRow(row, entry, opts)
    opts = opts or {}
    entry = entry or {}
    local includeScopeText = opts.includeScopeText == true
    local isPlaceholder = opts.isPlaceholder == true
    local canDrag = opts.canDrag == true
    local canDrop = opts.canDrop == true
    local selectedKey = tostring(opts.selectedKey or "")

    local itemType = tostring(entry.itemType or "entry")
    row.key = entry.key
    row.entryType = entry.entryType or "cooldown"
    row.itemType = itemType
    row.classID = tonumber(entry.classID) or nil
    row.specID = tonumber(entry.specID) or nil
    row.index = tonumber(entry.index) or nil
    row.groupID = entry.groupID
    row.parentGroupID = entry.parentGroupID
    row.parentGroupKey = entry.parentGroupKey or entry.groupKey
    row.groupKey = entry.groupKey
    row.displaySection = entry.displaySection
    row.depth = tonumber(entry.depth) or 0
    row.isLoadedEntry = entry.isLoaded ~= false
    row.isPlaceholder = isPlaceholder
    row.canDrop = ((canDrop == true) or itemType == "group" or itemType == "group-empty") and (not row.isPlaceholder)
    if row.canDrop then
        if itemType == "group-empty" then
            row.dropKey = entry.groupKey or entry.key
        else
            row.dropKey = entry.key
        end
    else
        row.dropKey = nil
    end
    row.canDrag = (canDrag == true) and (not row.isPlaceholder) and (itemType == "entry" or itemType == "group")
    row:EnableMouse(not row.isPlaceholder)
    row.plainText = tostring(entry.spellName or entry.name or "")
    HideRowDropPreview(row)
    if row.SetAlpha then
        row:SetAlpha(1)
    end

    local selected = (not row.isPlaceholder) and (itemType == "entry" or itemType == "group") and selectedKey ~= "" and selectedKey == entry.key

    row.icon:ClearAllPoints()
    row.statusDot:ClearAllPoints()
    row.statusDot:Hide()
    if itemType == "entry" and not row.isPlaceholder then
        local indent = 12 + ((tonumber(entry.depth) or 0) * 24)
        row.statusDot:SetPoint("LEFT", row, "LEFT", indent, 0)
        row.statusDot:Show()
        local euiStatus = tostring(entry.euiStatus or "")
        if euiStatus == "conflict" or euiStatus == "invalid_path" or euiStatus == "sharedmedia_missing" or euiStatus == "unsupported_tts" then
            row.statusDot:SetTextColor(1.00, 0.18, 0.18, 1)
        elseif euiStatus == "saved_waiting_sync" or euiStatus == "waiting_for_skill" or euiStatus == "waiting_for_eui"
            or euiStatus == "waiting_for_eui_custom_state" or euiStatus == "waiting_for_spec" or euiStatus == "requires_reload" then
            row.statusDot:SetTextColor(1.00, 0.82, 0.00, 1)
        elseif entry.isLoaded == false then
            row.statusDot:SetTextColor(1.00, 0.18, 0.18, 1)
        else
            row.statusDot:SetTextColor(0.18, 1.00, 0.25, 1)
        end
        row.icon:SetPoint("LEFT", row.statusDot, "RIGHT", 8, 0)
    elseif itemType == "group" and not row.isPlaceholder then
        local indent = 12 + ((tonumber(entry.depth) or 0) * 24)
        row.statusDot:SetPoint("LEFT", row, "LEFT", indent, 0)
        row.statusDot:Show()
        local loadState = tostring(entry.loadState or "")
        if loadState == "red" or entry.isLoaded == false then
            row.statusDot:SetTextColor(1.00, 0.18, 0.18, 1)
        elseif loadState == "yellow" then
            row.statusDot:SetTextColor(1.00, 0.82, 0.00, 1)
        else
            row.statusDot:SetTextColor(0.18, 1.00, 0.25, 1)
        end
        row.icon:SetPoint("LEFT", row.statusDot, "RIGHT", 8, 0)
    elseif itemType == "group-empty" then
        row.icon:SetPoint("LEFT", row, "LEFT", 36 + ((tonumber(entry.depth) or 0) * 24), 0)
    else
        row.icon:SetPoint("LEFT", row, "LEFT", 12, 0)
    end

    if row.isPlaceholder then
        row.bg:SetColorTexture(0, 0, 0, 0)
        row.accent:SetColorTexture(0.24, 0.48, 1.00, 0)
        row.icon:SetTexture(nil)
        row.main:SetText(L("EMPTY_CONFIG"))
        row.main:SetTextColor(0.62, 0.62, 0.62, 1)
    elseif itemType == "group" then
        row.bg:SetColorTexture(0.24, 0.48, 1.00, 0.06)
        row.accent:SetColorTexture(0.24, 0.48, 1.00, 0.55)
        row.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_Note_01")
        local isEmptyCollection = entry.isEmptyCollection == true or (tonumber(entry.count) or 0) <= 0
        local arrow = (isEmptyCollection or entry.collapsed) and "|cffffd24a[+]|r " or "|cffffd24a[-]|r "
        row.main:SetText(arrow .. BuildGroupRowText(entry))
        row.plainText = tostring(entry.name or L("COLLECTION_LABEL"))
        row.main:SetTextColor(1, 0.82, 0.00, 1)
    elseif itemType == "group-empty" then
        row.bg:SetColorTexture(0, 0, 0, 0)
        row.accent:SetColorTexture(0.24, 0.48, 1.00, 0.12)
        row.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.main:SetText("|cff808080" .. L("DRAG_INTO_COLLECTION") .. "|r")
        row.main:SetTextColor(0.62, 0.62, 0.62, 1)
    else
        row.bg:SetColorTexture(0.24, 0.48, 1.00, selected and 0.18 or 0)
        row.accent:SetColorTexture(0.24, 0.48, 1.00, selected and 0.95 or (entry.groupID and 0.10 or 0.18))
        row.icon:SetTexture(entry.icon or 134400)
        row.main:SetText(BuildEntryRowText(entry, includeScopeText))
        if selected then
            row.main:SetTextColor(1, 1, 1, 1)
        else
            row.main:SetTextColor(0.92, 0.92, 0.92, 1)
        end
    end

    local height = GetRowHeight(itemType)
    row.dragText = row.main and row.main:GetText() or row.plainText or ""
    row:SetHeight(height)
    return selected, height
end
