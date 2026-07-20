local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.ScopeSelector = NS.UI.ScopeSelector or {}

local ScopeSelector = NS.UI.ScopeSelector
local Widgets = NS.UI.Widgets
local Skin = NS.UI.Skin
local L = NS.L or function(key, ...) if select("#", ...) > 0 then return string.format(tostring(key), ...) end return tostring(key) end
local CONST = NS.Constants or {}

local ALL_RACES_ID = CONST.ALL_RACES_ID or 0
local ALL_CLASSES_ID = CONST.ALL_CLASSES_ID or 0
local ALL_SPECS_ID = CONST.ALL_SPECS_ID or 0

local RACE_IDS = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 22, 24, 25, 26, 27, 28, 29, 30, 31, 32, 34, 35, 36, 37, 52, 70, 84, 85,
}

local RACE_FALLBACK_NAMES = {
    [1] = "Human", [2] = "Orc", [3] = "Dwarf", [4] = "Night Elf", [5] = "Undead",
    [6] = "Tauren", [7] = "Gnome", [8] = "Troll", [9] = "Goblin", [10] = "Blood Elf",
    [11] = "Draenei", [22] = "Worgen", [24] = "Pandaren", [25] = "Pandaren (Alliance)",
    [26] = "Pandaren (Horde)", [27] = "Nightborne", [28] = "Highmountain Tauren",
    [29] = "Void Elf", [30] = "Lightforged Draenei", [31] = "Zandalari Troll",
    [32] = "Kul Tiran", [34] = "Dark Iron Dwarf", [35] = "Vulpera", [36] = "Mag'har Orc",
    [37] = "Mechagnome", [52] = "Dracthyr", [70] = "Dracthyr", [84] = "Earthen", [85] = "Earthen",
}

local function CopyNumberBoolMap(source)
    local copy = {}
    if type(source) == "table" then
        for key, value in pairs(source) do
            local numberKey = tonumber(key)
            if value == true and numberKey and numberKey >= 0 then
                copy[numberKey] = true
            end
        end
    end
    return copy
end

local function NormalizeAllMap(source, allID)
    local copy = CopyNumberBoolMap(source)
    allID = tonumber(allID) or 0
    if next(copy) == nil or copy[allID] == true then
        return { [allID] = true }
    end
    return copy
end

local function GetCurrentClassSpec()
    if NS.API and type(NS.API.GetCurrentClassSpec) == "function" then
        local classID, specID = NS.API.GetCurrentClassSpec()
        return tonumber(classID) or 0, tonumber(specID) or 0
    end
    return 0, 0
end

local function NormalizeDefaultCurrentMap(source, allID, fallbackID)
    local copy = CopyNumberBoolMap(source)
    allID = tonumber(allID) or 0
    fallbackID = tonumber(fallbackID) or 0
    if copy[allID] == true then
        return { [allID] = true }
    end
    if next(copy) == nil then
        return { [fallbackID > 0 and fallbackID or allID] = true }
    end
    return copy
end

local function CountConcrete(map)
    local count = 0
    for key, value in pairs(map or {}) do
        if value == true and (tonumber(key) or 0) > 0 then
            count = count + 1
        end
    end
    return count
end

local function SingleConcreteID(map)
    local found
    for key, value in pairs(map or {}) do
        local id = tonumber(key) or 0
        if value == true and id > 0 then
            if found then return nil end
            found = id
        end
    end
    return found
end

local function GetClassName(classID)
    for _, option in ipairs(NS.AceOptions and NS.AceOptions:GetClassOptionList() or {}) do
        if tonumber(option.classID) == tonumber(classID) then return tostring(option.className or classID) end
    end
    return tostring(classID)
end

local function GetSpecName(classID, specID)
    for _, option in ipairs(NS.AceOptions and NS.AceOptions:GetSpecOptionList(classID) or {}) do
        if tonumber(option.specID) == tonumber(specID) then return tostring(option.specName or specID) end
    end
    return tostring(specID)
end

local function HasConcreteSelection(map)
    for key, value in pairs(map or {}) do
        if value == true and (tonumber(key) or 0) > 0 then
            return true
        end
    end
    return false
end

local function GetRaceName(raceID)
    raceID = tonumber(raceID) or 0
    if C_CreatureInfo and type(C_CreatureInfo.GetRaceInfo) == "function" then
        local ok, info = pcall(C_CreatureInfo.GetRaceInfo, raceID)
        if ok and type(info) == "table" and type(info.raceName) == "string" and info.raceName ~= "" then
            return info.raceName
        end
    end
    return RACE_FALLBACK_NAMES[raceID] or tostring(raceID)
end

local function BuildRaceItems()
    local items = {}
    for _, raceID in ipairs(RACE_IDS) do
        items[#items + 1] = { value = raceID, text = GetRaceName(raceID) }
    end
    table.sort(items, function(a, b) return tostring(a.text or "") < tostring(b.text or "") end)
    return items
end

local function BuildSpecItems(classID)
    local items = {}
    local list = NS.AceOptions and NS.AceOptions.GetSpecOptionList and NS.AceOptions:GetSpecOptionList(classID) or {}
    for _, specInfo in ipairs(list or {}) do
        local specID = tonumber(specInfo and specInfo.specID) or 0
        if specID > 0 then
            items[#items + 1] = { value = specID, text = tostring(specInfo.specName or specID) }
        end
    end
    table.sort(items, function(a, b) return tostring(a.text or "") < tostring(b.text or "") end)
    return items
end

local function AddAllSpecsForClass(target, classID)
    for _, item in ipairs(BuildSpecItems(classID)) do
        local specID = tonumber(item.value) or 0
        if specID > 0 then
            target[specID] = true
        end
    end
end

local function SetCheckEnabled(button, enabled)
    if not button then return end
    if enabled then
        if button.Enable then button:Enable() end
        button:SetAlpha(1)
    else
        if button.Disable then button:Disable() end
        button:SetAlpha(0.55)
    end
end

local function CreateTitle(parent, text, x, y)
    local label = Widgets:CreateLabel(parent, text, "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetSize(620, 22)
    if Skin and Skin.StyleFont then Skin:StyleFont(label, "section") end
    return label
end

function ScopeSelector:BuildSummary(state)
    state = state or {}
    local currentClassID, currentSpecID = GetCurrentClassSpec()
    local raceMap = NormalizeAllMap(state.alertRaceIDs or state.customRaceIDs, ALL_RACES_ID)
    local classMap = NormalizeDefaultCurrentMap(state.alertClassIDs or state.customClassIDs, ALL_CLASSES_ID, currentClassID)
    local specMap = NormalizeDefaultCurrentMap(state.alertSpecIDs or state.customSpecIDs, ALL_SPECS_ID, currentSpecID)

    local singleRace, singleClass, singleSpec = SingleConcreteID(raceMap), SingleConcreteID(classMap), SingleConcreteID(specMap)
    local raceText = raceMap[ALL_RACES_ID] and L("SCOPE_ALL_RACES") or (singleRace and GetRaceName(singleRace) or L("SCOPE_RACE_COUNT", CountConcrete(raceMap)))
    local classText = classMap[ALL_CLASSES_ID] and L("SCOPE_ALL_CLASSES") or (singleClass and GetClassName(singleClass) or L("SCOPE_CLASS_COUNT", CountConcrete(classMap)))
    local specText = specMap[ALL_SPECS_ID] and L("SCOPE_ALL_SPECS") or (singleClass and singleSpec and GetSpecName(singleClass, singleSpec) or L("SCOPE_SPEC_COUNT", CountConcrete(specMap)))
    return string.format("%s / %s / %s", raceText, classText, specText)
end

function ScopeSelector:EnsureFrame()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "EllesmereUIVEScopeSelectorFrame", UIParent, "BackdropTemplate")
    frame:SetSize(720, 660)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    Widgets:ApplyPanelChrome(frame, { footerHeight = 58 })
    -- This selector sits above the editor and contains many empty areas.  Keep
    -- a fully opaque base even when an external skin elects not to paint one,
    -- otherwise the editor underneath shows through the class/spec list.
    local opaqueBackground = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    opaqueBackground:SetAllPoints(frame)
    opaqueBackground:SetColorTexture(0.015, 0.015, 0.015, 1)
    frame.qfxsaOpaqueBackground = opaqueBackground
    frame:SetAlpha(1)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(28, 28)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    if Skin and Skin.SkinCloseButton then Skin:SkinCloseButton(close) end
    close:SetScript("OnClick", function() frame:Hide() end)

    local title = Widgets:CreateLabel(frame, L("SCOPE_SELECT_TITLE"), "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -18)
    title:SetWidth(560)
    title:SetJustifyH("CENTER")
    if Skin and Skin.StyleFont then Skin:StyleFont(title, "title") end

    local raceTitle = CreateTitle(frame, L("SCOPE_RACE_SECTION"), 28, -58)
    local raceAll = Widgets:CreateCheckButton(frame, L("SCOPE_ALL_RACES"), 180)
    raceAll:SetPoint("TOPLEFT", raceTitle, "BOTTOMLEFT", 0, -8)
    local raceDrop = Widgets:CreateMultiSelectDropdown(frame, "EllesmereUIVEScopeRaceDropDown", 420)
    raceDrop:SetPoint("LEFT", raceAll, "RIGHT", 185, 0)

    local classTitle = CreateTitle(frame, L("SCOPE_CLASS_SPEC_SECTION"), 28, -132)
    local allClasses = Widgets:CreateCheckButton(frame, L("SCOPE_ALL_CLASSES"), 160)
    allClasses:SetPoint("TOPLEFT", classTitle, "BOTTOMLEFT", 0, -8)
    local allSpecs = Widgets:CreateCheckButton(frame, L("SCOPE_ALL_SPECS"), 160)
    allSpecs:SetPoint("LEFT", allClasses, "RIGHT", 200, 0)

    local listHost = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate,BackdropTemplate")
    listHost:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -198)
    listHost:SetSize(648, 374)
    local listContent = CreateFrame("Frame", nil, listHost)
    listContent:SetSize(610, 374)
    listHost:SetScrollChild(listContent)

    local apply = Widgets:CreateButton(frame, L("SCOPE_APPLY"), 118, 32)
    apply:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 28, 18)
    local cancel = Widgets:CreateButton(frame, L("SCOPE_CANCEL"), 118, 32)
    cancel:SetPoint("LEFT", apply, "RIGHT", 10, 0)
    cancel:SetScript("OnClick", function() frame:Hide() end)

    frame.controls = {
        raceAll = raceAll,
        raceDrop = raceDrop,
        allClasses = allClasses,
        allSpecs = allSpecs,
        listHost = listHost,
        listContent = listContent,
        apply = apply,
        classRows = {},
    }

    self.frame = frame
    return frame
end

function ScopeSelector:BuildClassRows(frame)
    local controls = frame.controls
    local content = controls.listContent
    if type(controls.classRows) == "table" and #controls.classRows > 0 then
        return
    end
    controls.classRows = {}

    local classOptions = NS.AceOptions and NS.AceOptions.GetClassOptionList and NS.AceOptions:GetClassOptionList() or {}
    local y = -4
    for _, classInfo in ipairs(classOptions or {}) do
        local classID = tonumber(classInfo and classInfo.classID) or 0
        if classID > 0 then
            local rowFrame = CreateFrame("Frame", nil, content)
            rowFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            rowFrame:SetSize(600, 32)
            local classCheck = Widgets:CreateCheckButton(rowFrame, tostring(classInfo.className or classID), 178)
            classCheck:SetPoint("LEFT", rowFrame, "LEFT", 0, 0)
            local specDrop = Widgets:CreateMultiSelectDropdown(rowFrame, nil, 360)
            specDrop:SetPoint("LEFT", rowFrame, "LEFT", 214, 0)
            Widgets:SetDropdownItems(specDrop, BuildSpecItems(classID))
            local row = { frame = rowFrame, classID = classID, classCheck = classCheck, specDrop = specDrop }
            controls.classRows[#controls.classRows + 1] = row
            classCheck:SetScript("OnClick", function()
                self:RefreshEnabled()
            end)
            y = y - 34
        end
    end
    content:SetHeight(math.max(374, math.abs(y) + 12))
end

function ScopeSelector:RefreshEnabled()
    local frame = self.frame
    if not frame or not frame.controls then return end
    local c = frame.controls
    Widgets:SetDropdownEnabled(c.raceDrop, true)

    local allClasses = c.allClasses and c.allClasses:GetChecked() == true
    if allClasses and c.allSpecs then
        c.allSpecs:SetChecked(true)
    end
    SetCheckEnabled(c.allSpecs, not allClasses)
    local allSpecs = c.allSpecs and c.allSpecs:GetChecked() == true

    for _, row in ipairs(c.classRows or {}) do
        SetCheckEnabled(row.classCheck, not allClasses)
        local rowChecked = row.classCheck and row.classCheck:GetChecked() == true
        Widgets:SetDropdownEnabled(row.specDrop, (not allClasses) and (not allSpecs) and rowChecked)
    end
end

function ScopeSelector:Open(state, onApply)
    state = state or {}
    local frame = self:EnsureFrame()
    self:BuildClassRows(frame)

    local c = frame.controls
    local currentClassID, currentSpecID = GetCurrentClassSpec()
    local raceMap = NormalizeAllMap(state.alertRaceIDs or state.customRaceIDs, ALL_RACES_ID)
    local classMap = NormalizeDefaultCurrentMap(state.alertClassIDs or state.customClassIDs, ALL_CLASSES_ID, currentClassID)
    local specMap = NormalizeDefaultCurrentMap(state.alertSpecIDs or state.customSpecIDs, ALL_SPECS_ID, currentSpecID)

    Widgets:SetDropdownItems(c.raceDrop, BuildRaceItems())
    c.raceAll:SetChecked(raceMap[ALL_RACES_ID] == true)
    Widgets:SetMultiDropdownValues(c.raceDrop, raceMap, L("PLACEHOLDER_SELECT_RACES"))

    local allClasses = classMap[ALL_CLASSES_ID] == true
    local allSpecs = specMap[ALL_SPECS_ID] == true or allClasses
    c.allClasses:SetChecked(allClasses)
    c.allSpecs:SetChecked(allSpecs)

    for _, row in ipairs(c.classRows or {}) do
        local classID = row.classID
        local checked = allClasses or classMap[classID] == true
        row.classCheck:SetChecked(checked)
        local selectedSpecs = {}
        if not allSpecs then
            for _, item in ipairs(BuildSpecItems(classID)) do
                local specID = tonumber(item.value) or 0
                if specID > 0 and specMap[specID] == true then
                    selectedSpecs[specID] = true
                end
            end
        end
        Widgets:SetMultiDropdownValues(row.specDrop, selectedSpecs, L("PLACEHOLDER_SELECT_SPECS"))
    end

    c.raceAll:SetScript("OnClick", function() self:RefreshEnabled() end)
    c.raceDrop.qfxsaOnValueChanged = function(values)
        if HasConcreteSelection(values) then
            if c.raceAll then
                c.raceAll:SetChecked(false)
            end
            -- 清除 ALL_RACES_ID，防止 NormalizeAllMap 将其误判为全种族
            if c.raceDrop and c.raceDrop.qfxsaSelectedValues then
                c.raceDrop.qfxsaSelectedValues[ALL_RACES_ID] = nil
            end
        end
        self:RefreshEnabled()
    end
    c.allClasses:SetScript("OnClick", function() self:RefreshEnabled() end)
    c.allSpecs:SetScript("OnClick", function() self:RefreshEnabled() end)
    c.apply:SetScript("OnClick", function()
        local nextRaceMap
        if c.raceAll:GetChecked() == true then
            nextRaceMap = { [ALL_RACES_ID] = true }
        else
            local selectedRaces = Widgets:GetMultiDropdownValues(c.raceDrop)
            if HasConcreteSelection(selectedRaces) then
                nextRaceMap = NormalizeAllMap(selectedRaces, ALL_RACES_ID)
            else
                nextRaceMap = { [ALL_RACES_ID] = true }
            end
        end

        local nextClassMap = {}
        local nextSpecMap = {}
        if c.allClasses:GetChecked() == true then
            nextClassMap[ALL_CLASSES_ID] = true
            nextSpecMap[ALL_SPECS_ID] = true
        else
            for _, row in ipairs(c.classRows or {}) do
                if row.classCheck:GetChecked() == true then
                    nextClassMap[row.classID] = true
                    if c.allSpecs:GetChecked() == true then
                        nextSpecMap[ALL_SPECS_ID] = true
                    else
                        local selectedSpecs = Widgets:GetMultiDropdownValues(row.specDrop)
                        if next(selectedSpecs) == nil then
                            AddAllSpecsForClass(nextSpecMap, row.classID)
                        else
                            for specID, enabled in pairs(selectedSpecs) do
                                if enabled == true and (tonumber(specID) or 0) > 0 then
                                    nextSpecMap[tonumber(specID)] = true
                                end
                            end
                        end
                    end
                end
            end
            if next(nextClassMap) == nil then
                nextClassMap[ALL_CLASSES_ID] = true
                nextSpecMap[ALL_SPECS_ID] = true
            elseif next(nextSpecMap) == nil then
                nextSpecMap[ALL_SPECS_ID] = true
            end
        end

        state.alertRaceIDs = nextRaceMap
        state.customRaceIDs = nextRaceMap
        state.alertClassIDs = nextClassMap
        state.customClassIDs = nextClassMap
        state.alertSpecIDs = nextSpecMap
        state.customSpecIDs = nextSpecMap
        local resolver = NS.Core and NS.Core.ScopeResolver
        if resolver and type(resolver.ResolveStorageScope) == "function" then
            state.classID, state.specID = resolver:ResolveStorageScope(nextClassMap, nextSpecMap)
        else
            state.classID, state.specID = ALL_CLASSES_ID, ALL_SPECS_ID
        end
        frame:Hide()
        if type(onApply) == "function" then
            onApply(state)
        end
    end)

    self:RefreshEnabled()
    frame:Show()
    frame:Raise()
end
