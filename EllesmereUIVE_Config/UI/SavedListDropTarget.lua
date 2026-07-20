local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.SavedListDropTarget = NS.UI.SavedListDropTarget or {}

local DropTarget = NS.UI.SavedListDropTarget
local DropKey = NS.SavedListDropKey or {}
local Geometry = NS.UI.SavedListDragGeometry or {}

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

local function GetScaledCursorY()
    if Geometry and type(Geometry.GetCursorY) == "function" then
        return Geometry:GetCursorY()
    end
    local _, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1
    return (y or 0) / scale
end

local function GetScaledCursorX()
    if Geometry and type(Geometry.GetCursorPosition) == "function" then
        local x = Geometry:GetCursorPosition()
        return x or 0
    end
    local x = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1
    return (x or 0) / scale
end

local function BuildDropKey(baseKey, mode)
    baseKey = tostring(baseKey or "")
    if baseKey == "" then
        return nil
    end
    if DropKey and type(DropKey.Build) == "function" then
        return DropKey:Build(baseKey, mode or "after")
    end
    if mode == "inside" then
        return baseKey .. ":inside"
    elseif mode == "after" then
        return baseKey .. ":after"
    end
    return baseKey
end

local function BuildRootDropKeyForSourceRow(sourceRow)
    if not sourceRow or tostring(sourceRow.itemType or "") ~= "entry" or not sourceRow.groupID then
        return nil
    end
    local classID = tonumber(sourceRow.classID) or 0
    local specID = tonumber(sourceRow.specID) or 0
    if classID < 0 or specID < 0 then
        return nil
    end
    return BuildDropKey(string.format("root:%d:%d", classID, specID), "after")
end

local function BuildParentGroupDropKeyForSourceRow(sourceRow)
    if not sourceRow or tostring(sourceRow.itemType or "") ~= "entry" or not sourceRow.groupID then
        return nil
    end
    local parentKey = tostring(sourceRow.parentGroupKey or sourceRow.groupKey or "")
    if parentKey == "" then
        return nil
    end
    return BuildDropKey(parentKey, "after")
end

local function IsCursorInsideList(list)
    if not list then
        return false
    end
    if Geometry and type(Geometry.IsCursorInsideAny) == "function" then
        return Geometry:IsCursorInsideAny(list.content, list.scrollChild, list.scrollFrame, list.frame)
    end
    return IsMouseOverFrame(list.scrollFrame) or IsMouseOverFrame(list.frame) or IsMouseOverFrame(list.content)
end

local function IsCursorNearList(list, extra)
    if not list then
        return false
    end
    extra = tonumber(extra) or 64
    if Geometry and type(Geometry.IsCursorInsideFrame) == "function" then
        return Geometry:IsCursorInsideFrame(list.frame, extra)
            or Geometry:IsCursorInsideFrame(list.scrollFrame, extra)
            or Geometry:IsCursorInsideFrame(list.content, extra)
    end
    return IsCursorInsideList(list)
end

local function IsOutdentedFromGroupedEntry(sourceRow, hoverRow)
    if not sourceRow or tostring(sourceRow.itemType or "") ~= "entry" or not sourceRow.groupID then
        return false
    end
    if not hoverRow or not hoverRow.IsShown or not hoverRow:IsShown() then
        return false
    end
    if tostring(hoverRow.itemType or "") == "group" then
        return false
    end

    local sourceParent = tostring(sourceRow.parentGroupKey or sourceRow.groupKey or "")
    local hoverParent = tostring(hoverRow.parentGroupKey or hoverRow.groupKey or "")
    if sourceParent == "" or hoverParent ~= sourceParent then
        return false
    end

    local depth = math.max(tonumber(sourceRow.depth) or 0, tonumber(hoverRow.depth) or 0)
    if depth <= 0 then
        return false
    end

    local left = hoverRow.GetLeft and hoverRow:GetLeft() or nil
    if not left and sourceRow.GetLeft then
        left = sourceRow:GetLeft()
    end
    if not left then
        return false
    end

    -- Rows are full-width buttons, so dragging a child row "outside" the collection
    -- still often hovers another child row. Treat a release to the left of the
    -- child's indent as an explicit outdent to the parent collection level.
    local parentIndentX = left + 12 + (math.max(depth - 1, 0) * 24)
    return GetScaledCursorX() <= (parentIndentX + 18)
end

local function BuildOutdentTarget(sourceRow, hoverRow)
    if not IsOutdentedFromGroupedEntry(sourceRow, hoverRow) then
        return nil
    end
    local key = BuildParentGroupDropKeyForSourceRow(sourceRow)
    if not key then
        key = BuildRootDropKeyForSourceRow(sourceRow)
    end
    if not key then
        return nil
    end
    return { row = hoverRow, dropKey = key, mode = "out" }
end

function DropTarget:DetermineDropMode(sourceRow, targetRow)
    if not sourceRow or not targetRow then
        return nil
    end

    -- 未载入条目可以在“未载入”区域内排序，也可以拖入任意合集；
    -- 但不要单独拖到“已载入”根区域，避免改变实际职业/专精归属。
    if sourceRow.itemType == "entry" and sourceRow.isLoadedEntry == false then
        if targetRow.itemType ~= "group" and targetRow.itemType ~= "group-empty" and not targetRow.groupID then
            if tostring(sourceRow.displaySection or "") ~= tostring(targetRow.displaySection or "") then
                return nil
            end
        end
    end

    local top = targetRow:GetTop() or 0
    local bottom = targetRow:GetBottom() or 0
    local y = GetScaledCursorY()

    if targetRow.itemType == "group-empty" then
        return "inside"
    end

    if targetRow.itemType == "group" then
        local height = math.max((top - bottom), 1)

        if sourceRow.itemType == "group" then
            if y >= top - height * 0.25 then
                return "before"
            elseif y <= bottom + height * 0.25 then
                return "after"
            end
            return "inside"
        end

        -- If an entry is already inside this group, dropping it on the parent
        -- group title should mean "move it out beside this group", not a no-op
        -- "put it back into the same group". This makes dragging entries out of
        -- collections reliable even when the user releases near the group title.
        if sourceRow.itemType == "entry" and sourceRow.groupID and tostring(sourceRow.parentGroupKey or "") == tostring(targetRow.key or "") then
            local mid = (top + bottom) / 2
            return y >= mid and "before" or "after"
        end

        -- 普通语音拖到合集标题时：中间区域是“放入合集”，
        -- 上/下边缘是“拖出到合集外，与该合集同级排序”。
        -- 对已经在合集内的语音，边缘区域加宽，降低拖出合集的操作难度。
        local edge = sourceRow.groupID and 0.42 or 0.25
        if y >= top - height * edge then
            return "before"
        elseif y <= bottom + height * edge then
            return "after"
        end
        return "inside"
    end

    -- 非空合集内的子条目也可以作为“拖入合集”的目标：
    -- 上/下边缘用于排序，中间区域用于直接放入该合集。
    if targetRow.groupID and targetRow.parentGroupKey and sourceRow.itemType ~= "group" then
        local height = math.max((top - bottom), 1)
        if y >= top - height * 0.25 then
            return "before"
        elseif y <= bottom + height * 0.25 then
            return "after"
        end
        return "inside"
    end

    local mid = (top + bottom) / 2
    return y >= mid and "before" or "after"
end

local function BuildTarget(self, list, sourceRow, row)
    if not row or row == sourceRow or not row:IsShown() or not row.dropKey then
        return nil
    end

    local outdentTarget = BuildOutdentTarget(sourceRow, row)
    if outdentTarget then
        return outdentTarget
    end

    local mode = row.dropMode or list.dragHoverMode or self:DetermineDropMode(sourceRow, row)
    if not mode then
        return nil
    end

    local key
    if mode == "inside" and row.parentGroupKey and row.itemType ~= "group" then
        key = tostring(row.parentGroupKey or "")
    else
        key = tostring(row.dropKey or "")
    end
    if key == "" then
        return nil
    end

    if DropKey and type(DropKey.Build) == "function" then
        key = DropKey:Build(key, mode)
    elseif mode == "inside" then
        key = key .. ":inside"
    elseif mode == "after" then
        key = key .. ":after"
    end
    return { row = row, dropKey = key, mode = mode }
end

function DropTarget:FindDropTarget(list, sourceRow)
    if list and list.dragHoverRow then
        local target = BuildTarget(self, list, sourceRow, list.dragHoverRow)
        if target then
            return target
        end
    end

    for _, row in ipairs((list and list.rows) or {}) do
        if row ~= sourceRow and row:IsShown() and row.dropKey and IsMouseOverFrame(row) then
            return BuildTarget(self, list, sourceRow, row)
        end
    end

    -- Dropping an entry from inside a collection onto empty space in/near the
    -- list should move it out. Prefer placing it beside its parent collection;
    -- fall back to the scope root if no parent group key is available. The
    -- "near list" margin covers the natural outdent gesture where the cursor is
    -- released just outside the list's left edge.
    if IsCursorInsideList(list) or IsCursorNearList(list, 80) then
        local parentDropKey = BuildParentGroupDropKeyForSourceRow(sourceRow)
        if parentDropKey then
            return { row = nil, dropKey = parentDropKey, mode = "out" }
        end

        local rootDropKey = BuildRootDropKeyForSourceRow(sourceRow)
        if rootDropKey then
            return { row = nil, dropKey = rootDropKey, mode = "root" }
        end
    end

    return nil
end
