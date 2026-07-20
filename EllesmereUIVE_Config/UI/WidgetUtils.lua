local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.WidgetUtils = NS.UI.WidgetUtils or {}

local Utils = NS.UI.WidgetUtils

function Utils.MakeSingleLine(fontString, width)
    if type(fontString) ~= "table" then
        return
    end
    if fontString.SetWordWrap then
        fontString:SetWordWrap(false)
    end
    if fontString.SetNonSpaceWrap then
        fontString:SetNonSpaceWrap(false)
    end
    if fontString.SetMaxLines then
        fontString:SetMaxLines(1)
    end
    if width and fontString.SetWidth then
        fontString:SetWidth(math.max(1, tonumber(width) or 1))
    end
end

function Utils.SafeCreateFrame(frameType, name, parent, templates)
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

function Utils.Clamp(value, minValue, maxValue)
    value = tonumber(value) or 0
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end
