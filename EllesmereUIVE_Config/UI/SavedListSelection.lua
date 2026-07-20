local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.SavedListSelection = NS.UI.SavedListSelection or {}

local Selection = NS.UI.SavedListSelection

local function ApplyRowVisual(row, selected)
    if not row or row.isPlaceholder then
        return
    end

    local itemType = tostring(row.itemType or "entry")
    if itemType ~= "entry" and itemType ~= "group" then
        return
    end

    if itemType == "group" then
        if row.bg then
            row.bg:SetColorTexture(0.24, 0.48, 1.00, selected and 0.16 or 0.06)
        end
        if row.accent then
            row.accent:SetColorTexture(0.24, 0.48, 1.00, selected and 0.95 or 0.55)
        end
        if row.main then
            row.main:SetTextColor(selected and 1 or 1, selected and 1 or 0.82, selected and 1 or 0.00, 1)
        end
        return
    end

    if row.bg then
        row.bg:SetColorTexture(0.24, 0.48, 1.00, selected and 0.18 or 0)
    end
    if row.accent then
        row.accent:SetColorTexture(0.24, 0.48, 1.00, selected and 0.95 or (row.groupID and 0.10 or 0.18))
    end
    if row.main then
        if selected then
            row.main:SetTextColor(1, 1, 1, 1)
        else
            row.main:SetTextColor(0.92, 0.92, 0.92, 1)
        end
    end
end

function Selection:UpdateSelectionOnly(list, oldKey, newKey)
    if type(list) ~= "table" then
        return
    end

    newKey = tostring(newKey or list.selectedKey or "")
    oldKey = tostring(oldKey or "")
    list.selectedKey = newKey

    -- Only repaint rows whose selected state could have changed. This avoids
    -- SavedList:Refresh(), which rebuilds all saved/group layout data and causes
    -- a hitch on large saved lists.
    for _, row in ipairs(list.rows or {}) do
        if row and row.IsShown and row:IsShown() then
            local rowKey = tostring(row.key or "")
            if rowKey ~= "" and (rowKey == oldKey or rowKey == newKey) then
                ApplyRowVisual(row, rowKey == newKey)
            end
        end
    end
end
