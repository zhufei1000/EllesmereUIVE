local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.SavedListDragDrop = NS.UI.SavedListDragDrop or {}

local DragDrop = NS.UI.SavedListDragDrop
local Skin = NS.UI.Skin
local DropTarget = NS.UI.SavedListDropTarget

local ROW_HEIGHT = 28
local DRAG_PREVIEW_INTERVAL = 0.045

local function IsMouseOverFrame(frame)
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
    local _, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1
    return (y or 0) / scale
end

function DragDrop:HideRowDropPreview(row)
    if not row then
        return
    end
    if row.dropBG then
        row.dropBG:Hide()
    end
    if row.dropLine then
        row.dropLine:Hide()
    end
    row.dropMode = nil
end

function DragDrop:HideDropHighlights(list)
    for _, candidate in ipairs((list and list.rows) or {}) do
        self:HideRowDropPreview(candidate)
    end
end

function DragDrop:DetermineDropMode(sourceRow, targetRow)
    if DropTarget and type(DropTarget.DetermineDropMode) == "function" then
        return DropTarget:DetermineDropMode(sourceRow, targetRow)
    end
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

    -- 拖到合集标题或空合集提示时，中间为放入，上下边缘为同级排序。
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

        -- 普通语音拖到合集标题时：中间区域仍然表示“放入合集”；
        -- 上/下边缘表示“拖出到合集外，与该合集同级排序”。
        -- 这修复了合集内语音只能拖进其他合集，无法拖回外层根列表的问题。
        if y >= top - height * 0.25 then
            return "before"
        elseif y <= bottom + height * 0.25 then
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

function DragDrop:ShowRowDropPreview(row, mode)
    self:HideRowDropPreview(row)
    if not row or not mode then
        return
    end

    row.dropMode = mode
    if mode == "inside" then
        if row.dropBG then
            row.dropBG:Show()
        end
        return
    end

    if row.dropLine then
        row.dropLine:ClearAllPoints()
        if mode == "before" then
            row.dropLine:SetPoint("TOPLEFT", row, "TOPLEFT", 8, 1)
            row.dropLine:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, 1)
        else
            row.dropLine:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, -1)
            row.dropLine:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, -1)
        end
        row.dropLine:Show()
    end
end

function DragDrop:UpdateDropPreview(list, force)
    if not list or not list.dragKey or not list.dragRow then
        return
    end

    -- 拖拽过程中限制命中检测频率，避免大列表每帧扫描导致卡顿。
    local now = type(GetTime) == "function" and GetTime() or 0
    if not force then
        local nextTime = tonumber(list.dragPreviewNextTime) or 0
        if now > 0 and now < nextTime then
            return
        end
    end
    if now > 0 then
        list.dragPreviewNextTime = now + DRAG_PREVIEW_INTERVAL
    end

    local sourceRow = list.dragRow
    local hoverRow = nil
    local hoverMode = nil

    for _, candidate in ipairs(list.rows or {}) do
        if candidate ~= sourceRow and candidate:IsShown() and candidate.dropKey and not candidate.isPlaceholder and IsMouseOverFrame(candidate) then
            hoverRow = candidate
            hoverMode = self:DetermineDropMode(sourceRow, candidate)
            break
        end
    end

    if hoverRow == list.dragHoverRow and hoverMode == list.dragHoverMode then
        return
    end

    if list.dragHoverRow and list.dragHoverRow ~= hoverRow then
        self:HideRowDropPreview(list.dragHoverRow)
    elseif list.dragHoverRow and list.dragHoverMode ~= hoverMode then
        self:HideRowDropPreview(list.dragHoverRow)
    end

    list.dragHoverRow = hoverRow
    list.dragHoverMode = hoverMode
    if hoverRow then
        self:ShowRowDropPreview(hoverRow, hoverMode)
    end
end

function DragDrop:StopDragVisual(list)
    if not list then
        return
    end

    if list.dragGhost then
        list.dragGhost:Hide()
        list.dragGhost:SetScript("OnUpdate", nil)
    end
    if list.dragRow and list.dragRow.SetAlpha then
        list.dragRow:SetAlpha(1)
    end
    self:HideDropHighlights(list)
    list.dragHoverRow = nil
    list.dragHoverMode = nil
    list.dragPreviewNextTime = nil
end

function DragDrop:StartDragVisual(list, row)
    if not list or not row then
        return
    end

    if not list.dragGhost then
        local ghost = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        ghost:SetFrameStrata("TOOLTIP")
        ghost:EnableMouse(false)
        if ghost.SetBackdrop then
            ghost:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 14,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            ghost:SetBackdropColor(0, 0, 0, 0.82)
            ghost:SetBackdropBorderColor(0.75, 0.75, 0.75, 0.90)
        end

        local accent = ghost:CreateTexture(nil, "ARTWORK")
        accent:SetPoint("TOPLEFT", ghost, "TOPLEFT", 3, -3)
        accent:SetPoint("BOTTOMLEFT", ghost, "BOTTOMLEFT", 3, 3)
        accent:SetWidth(3)
        accent:SetColorTexture(0.24, 0.48, 1.00, 0.80)
        ghost.accent = accent

        local statusDot = ghost:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        statusDot:SetText("●")
        statusDot:SetJustifyH("CENTER")
        statusDot:SetJustifyV("MIDDLE")
        if Skin then
            Skin:StyleFont(statusDot, "body")
        end
        ghost.statusDot = statusDot

        local icon = ghost:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        ghost.icon = icon

        local text = ghost:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetJustifyH("LEFT")
        text:SetJustifyV("MIDDLE")
        if text.SetWordWrap then
            text:SetWordWrap(false)
        end
        if text.SetMaxLines then
            text:SetMaxLines(1)
        end
        ghost.text = text
        list.dragGhost = ghost
    end

    local ghost = list.dragGhost
    local width = math.min(math.max((row:GetWidth() or 420), 420), 760)
    local height = math.max((row:GetHeight() or ROW_HEIGHT), ROW_HEIGHT)
    ghost:SetSize(width, height)

    ghost.statusDot:ClearAllPoints()
    ghost.icon:ClearAllPoints()
    ghost.text:ClearAllPoints()

    if row.statusDot and row.statusDot:IsShown() then
        local r, g, b, a = row.statusDot:GetTextColor()
        ghost.statusDot:SetTextColor(r or 1, g or 1, b or 1, a or 1)
        ghost.statusDot:SetPoint("LEFT", ghost, "LEFT", 14, 0)
        ghost.statusDot:Show()
        ghost.icon:SetPoint("LEFT", ghost.statusDot, "RIGHT", 8, 0)
    else
        ghost.statusDot:Hide()
        ghost.icon:SetPoint("LEFT", ghost, "LEFT", 14, 0)
    end

    local texture = row.icon and row.icon:GetTexture()
    ghost.icon:SetTexture(texture or 134400)
    ghost.text:SetPoint("LEFT", ghost.icon, "RIGHT", 10, 0)
    ghost.text:SetPoint("RIGHT", ghost, "RIGHT", -12, 0)
    ghost.text:SetText(tostring(row.dragText or (row.main and row.main:GetText()) or row.plainText or ""))

    ghost:ClearAllPoints()
    ghost:Show()
    ghost:SetScript("OnUpdate", function(self)
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale() or 1
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (x or 0) / scale + 22, (y or 0) / scale - 20)
        DragDrop:UpdateDropPreview(list)
    end)

    if row.SetAlpha then
        row:SetAlpha(0.46)
    end

    if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
end

function DragDrop:FindDropTarget(list, sourceRow)
    if DropTarget and type(DropTarget.FindDropTarget) == "function" then
        return DropTarget:FindDropTarget(list, sourceRow)
    end

    local function buildTarget(row)
        if not row or row == sourceRow or not row:IsShown() or not row.dropKey then
            return nil
        end
        local mode = row.dropMode or list.dragHoverMode or DragDrop:DetermineDropMode(sourceRow, row)
        local key
        if mode == "inside" and row.parentGroupKey and row.itemType ~= "group" then
            key = tostring(row.parentGroupKey or "")
        else
            key = tostring(row.dropKey or "")
        end
        if key == "" then
            return nil
        end
        if not mode then
            return nil
        end
        if mode == "inside" then
            key = key .. ":inside"
        elseif mode == "after" then
            key = key .. ":after"
        end
        return { row = row, dropKey = key, mode = mode }
    end

    if list.dragHoverRow then
        local target = buildTarget(list.dragHoverRow)
        if target then
            return target
        end
    end

    for _, row in ipairs(list.rows or {}) do
        if row ~= sourceRow and row:IsShown() and row.dropKey and IsMouseOverFrame(row) then
            return buildTarget(row)
        end
    end
    return nil
end
