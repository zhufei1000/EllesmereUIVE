local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.SavedListDragGeometry = NS.UI.SavedListDragGeometry or {}

local Geometry = NS.UI.SavedListDragGeometry

function Geometry:GetCursorPosition()
    local x, y = GetCursorPosition()
    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if not scale or scale <= 0 then
        scale = 1
    end
    return (x or 0) / scale, (y or 0) / scale
end

function Geometry:GetCursorY()
    local _, y = self:GetCursorPosition()
    return y or 0
end

function Geometry:IsCursorInsideFrame(frame, extra)
    if not frame or not frame.IsShown or not frame:IsShown() then
        return false
    end

    if frame.IsMouseOver and frame:IsMouseOver() then
        return true
    end

    local mouseIsOver = rawget(_G, "MouseIsOver")
    if type(mouseIsOver) == "function" and mouseIsOver(frame) then
        return true
    end

    local left = frame.GetLeft and frame:GetLeft() or nil
    local right = frame.GetRight and frame:GetRight() or nil
    local top = frame.GetTop and frame:GetTop() or nil
    local bottom = frame.GetBottom and frame:GetBottom() or nil
    if not left or not right or not top or not bottom then
        return false
    end

    extra = tonumber(extra) or 0
    local x, y = self:GetCursorPosition()
    return x >= (left - extra) and x <= (right + extra) and y <= (top + extra) and y >= (bottom - extra)
end

function Geometry:IsCursorInsideAny(...)
    for i = 1, select("#", ...) do
        local frame = select(i, ...)
        if self:IsCursorInsideFrame(frame, 2) then
            return true
        end
    end
    return false
end

function Geometry:GetVerticalModeForRow(row, beforeRatio, afterRatio)
    if not row then
        return nil
    end
    local top = row.GetTop and row:GetTop() or 0
    local bottom = row.GetBottom and row:GetBottom() or 0
    local height = math.max((top - bottom), 1)
    local y = self:GetCursorY()
    beforeRatio = tonumber(beforeRatio) or 0.25
    afterRatio = tonumber(afterRatio) or beforeRatio

    if y >= top - height * beforeRatio then
        return "before"
    elseif y <= bottom + height * afterRatio then
        return "after"
    end
    return "inside"
end
