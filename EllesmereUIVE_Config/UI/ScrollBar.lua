local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.ScrollBar = NS.UI.ScrollBar or {}

local ScrollBar = NS.UI.ScrollBar
local Skin = NS.UI.Skin

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

function ScrollBar:ClearInheritedScripts(slider)
    if not slider or not slider.SetScript then
        return slider
    end

    -- UIPanelScrollBarTemplate / SecureScrollTemplates install an inherited
    -- OnValueChanged handler that expects a very specific parent scroll frame.
    -- Our dropdown and custom panels wire scrolling manually, so clearing this
    -- before the first SetValue prevents SecureScrollTemplates.lua errors.
    slider:SetScript("OnValueChanged", nil)
    return slider
end

function ScrollBar:Create(parent, name, opts)
    opts = opts or {}
    local slider = SafeCreateFrame("Slider", name, parent, {
        "UIPanelScrollBarTemplate",
        "OptionsSliderTemplate",
        "BackdropTemplate",
    })

    self:ClearInheritedScripts(slider)

    if slider.SetOrientation then
        slider:SetOrientation(opts.orientation or "VERTICAL")
    end
    if slider.SetWidth then
        slider:SetWidth(opts.width or 16)
    end
    if slider.SetMinMaxValues then
        slider:SetMinMaxValues(opts.minValue or 0, opts.maxValue or 0)
    end
    if slider.SetValueStep then
        slider:SetValueStep(opts.valueStep or 1)
    end
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(opts.obeyStepOnDrag and true or false)
    end
    if slider.SetValue then
        slider:SetValue(opts.value or 0)
    end

    if Skin and Skin.SkinScrollBar then
        Skin:SkinScrollBar(slider)
    end

    return slider
end
