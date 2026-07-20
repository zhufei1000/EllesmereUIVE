local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.OptionsState = NS.OptionsState or {}

local GetNumClasses = rawget(_G, "GetNumClasses")
local GetClassInfo = rawget(_G, "GetClassInfo")
local GetNumSpecializationsForClassID = rawget(_G, "GetNumSpecializationsForClassID")
local GetSpecializationInfoForClassID = rawget(_G, "GetSpecializationInfoForClassID")

local L = NS.L or function(key, ...)
    if select("#", ...) > 0 then
        return string.format(tostring(key), ...)
    end
    return tostring(key)
end

local CONST = NS.Constants or {}
local Utils = NS.Utils or {}

local ALL_CLASSES_ID = CONST.ALL_CLASSES_ID or 0
local ALL_SPECS_ID = CONST.ALL_SPECS_ID or 0
local ALL_RACES_ID = CONST.ALL_RACES_ID or 0
local OBJECT_TYPE_SPELL = CONST.OBJECT_TYPE_SPELL or "spell"
local OBJECT_TYPE_ITEM = CONST.OBJECT_TYPE_ITEM or "item"
local ITEM_LOAD_NONE = CONST.ITEM_LOAD_NONE or "none"
local ITEM_LOAD_EQUIPPED = CONST.ITEM_LOAD_EQUIPPED or "equipped"
local ITEM_LOAD_BAGS = CONST.ITEM_LOAD_BAGS or "bags"


local function NormalizeConditionOp(value)
    value = tostring(value or "<=")
    if value == "<" or value == "<=" or value == ">" or value == ">=" or value == "==" then
        return value
    end
    if value == "=" then
        return "=="
    end
    return "<="
end

local function TrimText(value)
    if Utils.TrimText then
        return Utils.TrimText(value)
    end
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function GetApi()
    return NS.API
end

local function BuildInlineTexture(texture, size, left, right, top, bottom)
    if type(texture) ~= "string" and type(texture) ~= "number" then
        return ""
    end

    size = tonumber(size) or 14
    if left and right and top and bottom then
        return string.format("|T%s:%d:%d:0:0:256:256:%d:%d:%d:%d|t ", tostring(texture), size, size, left, right, top, bottom)
    end
    return string.format("|T%s:%d:%d|t ", tostring(texture), size, size)
end

local function GetClassColorCode(classFile)
    local color = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
    if not color then
        return nil
    end

    local r = math.floor(((tonumber(color.r) or 1) * 255) + 0.5)
    local g = math.floor(((tonumber(color.g) or 1) * 255) + 0.5)
    local b = math.floor(((tonumber(color.b) or 1) * 255) + 0.5)
    return string.format("|cff%02x%02x%02x", r, g, b)
end

local function BuildClassDisplayText(className, classFile)
    local icon = ""
    local coords = CLASS_ICON_TCOORDS and classFile and CLASS_ICON_TCOORDS[classFile]
    if coords then
        icon = BuildInlineTexture(
            "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",
            14,
            math.floor((coords[1] or 0) * 256),
            math.floor((coords[2] or 1) * 256),
            math.floor((coords[3] or 0) * 256),
            math.floor((coords[4] or 1) * 256)
        )
    end

    local text = tostring(className or "-")
    local colorCode = GetClassColorCode(classFile)
    if colorCode then
        return icon .. colorCode .. text .. "|r"
    end
    return icon .. text
end

local function BuildSpecDisplayText(specName, specIcon)
    return BuildInlineTexture(specIcon, 14) .. tostring(specName or "-")
end

local function IsSoundSourceValue(value)
    value = tostring(value or "")
    return value == "builtin" or value == "sharedmedia" or value == "custom" or value == "tts"
end

local function NormalizeItemLoadMode(value)
    value = tostring(value or ITEM_LOAD_NONE):lower()
    if value == ITEM_LOAD_EQUIPPED or value == ITEM_LOAD_BAGS then
        return value
    end
    return ITEM_LOAD_NONE
end

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

local function NormalizeRaceMap(source)
    local copy = CopyNumberBoolMap(source)
    if next(copy) == nil or copy[ALL_RACES_ID] == true then
        return { [ALL_RACES_ID] = true }
    end
    return copy
end

function NS.OptionsState:GetState(owner)
    owner = owner or NS.AceOptions or self
    owner.state = owner.state or {}
    local api = GetApi()
    if not api then
        return owner.state
    end

    if owner.state.classID == nil or owner.state.specID == nil then
        self:SyncScopeToCurrentSpec(owner)
    end
    local classID = tonumber(owner.state.classID) or 0
    if classID == ALL_CLASSES_ID then
        owner.state.specID = ALL_SPECS_ID
    end
    local modeTts, modeSound = api.GetModes()
    owner.state.notifyMode = owner.state.notifyMode or modeSound
    owner.state.fixedCD = true
    owner.state.checkTalent = owner.state.checkTalent == true
    owner.state.itemLoadMode = NormalizeItemLoadMode(owner.state.itemLoadMode)
    if tostring(owner.state.objectType or ""):lower() ~= OBJECT_TYPE_ITEM then
        owner.state.itemLoadMode = ITEM_LOAD_NONE
    end
    owner.state.itemLoadSameName = owner.state.itemLoadMode == ITEM_LOAD_BAGS and owner.state.itemLoadSameName == true
    owner.state.alertRaceIDs = NormalizeRaceMap(owner.state.alertRaceIDs)
    owner.state.customRaceIDs = owner.state.alertRaceIDs
    owner.state.talentId = tonumber(owner.state.talentId) or 0
    owner.state.talentName = tostring(owner.state.talentName or "")
    owner.state.talentCD = tonumber(owner.state.talentCD) or 0
    owner.state.delayEnabled = owner.state.delayEnabled == true
    owner.state.delaySeconds = math.max(0, tonumber(owner.state.delaySeconds) or 0)
    owner.state.castDelayMode = "show"
    owner.state.cooldownAlertTime = math.max(0, tonumber(owner.state.cooldownAlertTime) or 0)
    owner.state.voiceEnabled = owner.state.voiceEnabled ~= false
    owner.state.euiTriggerType = tostring(owner.state.euiTriggerType or "cdReady")
    if owner.state.euiTriggerType ~= "buffGain" and owner.state.euiTriggerType ~= "buffLoss" then
        owner.state.euiTriggerType = "cdReady"
    end
    owner.state.injectOnSave = owner.state.injectOnSave == true
    local legacyAlertTime = math.max(0, tonumber(owner.state.cooldownAlertTime or owner.state.alertLeadTime) or 0)
    owner.state.voiceConditionOp = NormalizeConditionOp(owner.state.voiceConditionOp)
    owner.state.voiceConditionTime = math.max(0, tonumber(owner.state.voiceConditionTime) or legacyAlertTime)
    owner.state.activeAlertTab = tostring(owner.state.activeAlertTab or "settings")
    if owner.state.activeAlertTab ~= "settings" and owner.state.activeAlertTab ~= "voice" and owner.state.activeAlertTab ~= "image" and owner.state.activeAlertTab ~= "text" then
        owner.state.activeAlertTab = "settings"
    end
    owner.state.imageEnabled = owner.state.imageEnabled == true
    owner.state.imageConditionOp = NormalizeConditionOp(owner.state.imageConditionOp)
    owner.state.imageConditionTime = math.max(0, tonumber(owner.state.imageConditionTime) or legacyAlertTime)
    owner.state.imageSource = tostring(owner.state.imageSource or "auto")
    if owner.state.imageSource ~= "spell" and owner.state.imageSource ~= "item" and owner.state.imageSource ~= "icon" and owner.state.imageSource ~= "path" then
        owner.state.imageSource = "auto"
    end
    owner.state.imageIconID = math.max(0, tonumber(owner.state.imageIconID) or 0)
    owner.state.imagePath = TrimText(owner.state.imagePath or "")
    owner.state.imageSize = math.max(16, tonumber(owner.state.imageSize) or 96)
    owner.state.imageDurationEnabled = owner.state.imageDurationEnabled == true
    owner.state.imageDuration = math.max(0.1, tonumber(owner.state.imageDuration) or 2)
    owner.state.imageX = tonumber(owner.state.imageX) or 0
    owner.state.imageY = tonumber(owner.state.imageY) or 120
    owner.state.textEnabled = owner.state.textEnabled == true
    owner.state.textConditionOp = NormalizeConditionOp(owner.state.textConditionOp)
    owner.state.textConditionTime = math.max(0, tonumber(owner.state.textConditionTime) or legacyAlertTime)
    owner.state.textAlert = tostring(owner.state.textAlert or "")
    owner.state.textSize = math.max(8, tonumber(owner.state.textSize) or 24)
    owner.state.textDurationEnabled = owner.state.textDurationEnabled == true
    owner.state.textDuration = math.max(0.1, tonumber(owner.state.textDuration) or 2)
    if Utils.SyncLinkedVisualDurations then
        Utils.SyncLinkedVisualDurations(owner.state)
    end
    owner.state.textX = tonumber(owner.state.textX) or 0
    owner.state.textY = tonumber(owner.state.textY) or 120
    owner.state.textAttachMode = tostring(owner.state.textAttachMode or "outside")
    if owner.state.textAttachMode ~= "inside" then owner.state.textAttachMode = "outside" end
    owner.state.textVAlign = tostring(owner.state.textVAlign or "bottom")
    if owner.state.textVAlign ~= "top" and owner.state.textVAlign ~= "middle" then owner.state.textVAlign = "bottom" end
    owner.state.textHAlign = tostring(owner.state.textHAlign or "center")
    if owner.state.textHAlign ~= "left" and owner.state.textHAlign ~= "right" then owner.state.textHAlign = "center" end
    owner.state.textOffsetX = tonumber(owner.state.textOffsetX) or 0
    owner.state.textOffsetY = tonumber(owner.state.textOffsetY) or 0

    local defaultBuiltin = owner:GetDefaultBuiltinSoundPath()
    owner.state.builtinSoundPath = owner:NormalizeSoundPath(owner.state.builtinSoundPath or defaultBuiltin)
    if owner.state.builtinSoundPath == "" or not owner:IsBuiltinSoundPath(owner.state.builtinSoundPath) then
        owner.state.builtinSoundPath = defaultBuiltin
    end
    owner.state.sharedMediaSound = TrimText(owner.state.sharedMediaSound or "")
    owner.state.useSharedMediaSound = owner.state.useSharedMediaSound == true
    owner.state.customSoundPath = owner:NormalizeSoundPath(owner.state.customSoundPath or "")
    owner.state.customSoundPaths = type(owner.state.customSoundPaths) == "table" and owner.state.customSoundPaths or { owner.state.customSoundPath or "", "", "", "", "" }
    for i = 1, 5 do
        owner.state.customSoundPaths[i] = owner:NormalizeSoundPath(owner.state.customSoundPaths[i] or "")
    end
    if TrimText(owner.state.customSoundPath or "") ~= "" and TrimText(owner.state.customSoundPaths[1] or "") == "" then
        owner.state.customSoundPaths[1] = owner.state.customSoundPath
    end
    owner.state.useCustomSound = owner.state.useCustomSound == true
    owner.state.soundSource = tostring(owner.state.soundSource or "")

    if TrimText(owner.state.soundPath or "") == "" and tostring(owner.state.notifyMode or "") ~= tostring(modeTts) then
        owner.state.soundPath = owner.state.builtinSoundPath
    else
        owner.state.soundPath = owner:NormalizeSoundPath(owner.state.soundPath or "")
    end

    if owner.state.soundSource == "" then
        local resolved = owner:ResolveSoundSourceFields(owner.state, modeTts, modeSound)
        owner.state.notifyMode = resolved.notifyMode
        owner.state.soundSource = resolved.soundSource
        owner.state.soundPath = resolved.soundPath
        owner.state.builtinSoundPath = resolved.builtinSoundPath
        owner.state.customSoundPath = resolved.customSoundPath
        owner.state.sharedMediaSound = resolved.sharedMediaSound
        owner.state.useCustomSound = resolved.useCustomSound == true
        owner.state.useSharedMediaSound = resolved.useSharedMediaSound == true
    end

    return owner.state
end

function NS.OptionsState:SyncScopeToCurrentSpec(owner)
    owner = owner or NS.AceOptions or self
    local api = GetApi()
    owner.state = owner.state or {}
    if not api or type(api.GetCurrentClassSpec) ~= "function" then
        return
    end

    local classID, specID = api.GetCurrentClassSpec()
    owner.state.classID = tonumber(classID) or 0
    owner.state.specID = tonumber(specID) or 0
    owner.state.selectedKey = nil
    owner.state.selectedCollectionKey = nil
end

function NS.OptionsState:GetClassOptionList(owner)
    local options = {
        { classID = ALL_CLASSES_ID, className = L("ALL_CLASSES"), classFile = nil },
    }
    if type(GetNumClasses) ~= "function" or type(GetClassInfo) ~= "function" then
        return options
    end

    local classCount = tonumber(GetNumClasses()) or 0
    for classIndex = 1, classCount do
        local ok, className, classFile, classID = pcall(GetClassInfo, classIndex)
        classID = tonumber(classID) or 0
        if ok and classID > 0 and type(className) == "string" and className ~= "" then
            options[#options + 1] = {
                classID = classID,
                className = className,
                classFile = classFile,
            }
        end
    end

    return options
end

function NS.OptionsState:GetClassValues(owner)
    local values = {}
    local classList = self:GetClassOptionList(owner)
    for _, option in ipairs(classList) do
        values[option.classID] = BuildClassDisplayText(option.className, option.classFile)
    end
    return values
end

function NS.OptionsState:GetSpecOptionList(owner, classID)
    classID = tonumber(classID) or 0
    local options = {
        {
            specID = ALL_SPECS_ID,
            specName = L("ALL_SPECS"),
            specIcon = nil,
        }
    }
    if classID == ALL_CLASSES_ID then
        return options
    end
    if classID < 0 then
        return options
    end

    if type(GetNumSpecializationsForClassID) ~= "function" or type(GetSpecializationInfoForClassID) ~= "function" then
        return options
    end

    local specCount = tonumber(GetNumSpecializationsForClassID(classID)) or 0
    for specIndex = 1, specCount do
        local ok, specID, specName, _, specIcon = pcall(GetSpecializationInfoForClassID, classID, specIndex)
        specID = tonumber(specID) or 0
        if ok and specID > 0 then
            options[#options + 1] = {
                specID = specID,
                specName = (type(specName) == "string" and specName ~= "") and specName or L("FALLBACK_SPEC", " " .. tostring(specID)),
                specIcon = specIcon,
            }
        end
    end

    return options
end

function NS.OptionsState:GetSpecValues(owner, classID)
    local values = {}
    for _, option in ipairs(self:GetSpecOptionList(owner, classID)) do
        values[option.specID] = BuildSpecDisplayText(option.specName, option.specIcon)
    end
    return values
end

function NS.OptionsState:EnsureValidScope(owner)
    owner = owner or NS.AceOptions or self
    local state = self:GetState(owner)
    if state.classID == nil then
        self:SyncScopeToCurrentSpec(owner)
    end
    state.classID = tonumber(state.classID) or 0
    state.specID = tonumber(state.specID) or 0

    if state.classID == ALL_CLASSES_ID then
        state.specID = ALL_SPECS_ID
        return
    end

    if state.classID < 0 then
        self:SyncScopeToCurrentSpec(owner)
    end

    local specValues = self:GetSpecValues(owner, state.classID)
    if not specValues[state.specID] then
        state.specID = ALL_SPECS_ID
    end
end

function NS.OptionsState:ClearEditorFields(owner)
    owner = owner or NS.AceOptions or self
    local api = GetApi()
    local state = self:GetState(owner)
    if not api or type(api.GetModes) ~= "function" then
        return
    end
    local _, modeSound = api.GetModes()

    state.selectedKey = nil
    state.spellId = 0
    state.objectType = OBJECT_TYPE_SPELL
    state.itemLoadMode = ITEM_LOAD_NONE
    state.itemLoadSameName = false
    state.alertRaceIDs = { [ALL_RACES_ID] = true }
    state.customRaceIDs = state.alertRaceIDs
    local classID, specID = 0, 0
    if api and type(api.GetCurrentClassSpec) == "function" then
        classID, specID = api.GetCurrentClassSpec()
    end
    classID = tonumber(classID) or 0
    specID = tonumber(specID) or 0
    state.alertClassIDs = { [classID > 0 and classID or ALL_CLASSES_ID] = true }
    state.customClassIDs = state.alertClassIDs
    state.alertSpecIDs = { [specID > 0 and specID or ALL_SPECS_ID] = true }
    state.customSpecIDs = state.alertSpecIDs
    state.spellName = ""
    state.baseCD = 0
    state.fixedCD = true
    state.checkTalent = false
    state.talentId = 0
    state.talentName = ""
    state.talentCD = 0
    state.delayEnabled = false
    state.delaySeconds = 0
    state.castDelayMode = "show"
    state.cooldownAlertTime = 0
    state.euiTriggerType = "cdReady"
    state.injectOnSave = false
    state.notifyMode = modeSound
    state.ttsText = ""
    state.ttsRate = 0
    state.builtinSoundPath = owner:GetDefaultBuiltinSoundPath()
    state.sharedMediaSound = ""
    state.useSharedMediaSound = false
    state.customSoundPath = ""
    state.customSoundPaths = { "", "", "", "", "" }
    state.useCustomSound = false
    state.soundSource = "builtin"
    state.soundPath = state.builtinSoundPath
    state.voiceEnabled = false
    state.voiceConditionOp = "<="
    state.voiceConditionTime = 0
    state.activeAlertTab = "settings"
    state.imageEnabled = false
    state.imageConditionOp = "<="
    state.imageConditionTime = 0
    state.imageSource = "auto"
    state.imageIconID = 0
    state.imagePath = ""
    state.imageSize = 96
    state.imageDurationEnabled = false
    state.imageDuration = 2
    state.imageX = 0
    state.imageY = 120
    state.textEnabled = false
    state.textConditionOp = "<="
    state.textConditionTime = 0
    state.textAlert = ""
    state.textSize = 24
    state.textDurationEnabled = false
    state.textDuration = 2
    state.textX = 0
    state.textY = 120
    state.textAttachMode = "outside"
    state.textVAlign = "bottom"
    state.textHAlign = "center"
    state.textOffsetX = 0
    state.textOffsetY = 0
end

function NS.OptionsState:SyncStateFromWidgets(owner)
    owner = owner or NS.AceOptions or self
    local widgets = owner.editorWidgets or owner.widgets
    local state = self:GetState(owner)
    local api = GetApi()
    if not widgets or not api then
        return
    end

    if widgets.classDrop then
        state.classID = tonumber(widgets.classDrop:GetValue()) or state.classID or 0
    end
    if widgets.specDrop then
        if (tonumber(state.classID) or 0) == ALL_CLASSES_ID then
            state.specID = ALL_SPECS_ID
        else
            state.specID = tonumber(widgets.specDrop:GetValue()) or state.specID or 0
        end
    end
    if widgets.objectTypeItem then
        local isItem = type(widgets.objectTypeItem.GetValue) == "function" and widgets.objectTypeItem:GetValue() == true or (type(widgets.objectTypeItem.GetChecked) == "function" and widgets.objectTypeItem:GetChecked() == true)
        state.objectType = isItem and OBJECT_TYPE_ITEM or OBJECT_TYPE_SPELL
    end
    if state.objectType == OBJECT_TYPE_ITEM then
        local equippedChecked = widgets.itemLoadEquipped and type(widgets.itemLoadEquipped.GetChecked) == "function" and widgets.itemLoadEquipped:GetChecked() == true
        local bagsChecked = widgets.itemLoadBags and type(widgets.itemLoadBags.GetChecked) == "function" and widgets.itemLoadBags:GetChecked() == true
        if equippedChecked then
            state.itemLoadMode = ITEM_LOAD_EQUIPPED
            state.itemLoadSameName = false
        elseif bagsChecked then
            state.itemLoadMode = ITEM_LOAD_BAGS
            state.itemLoadSameName = widgets.itemLoadSameName and type(widgets.itemLoadSameName.GetChecked) == "function" and widgets.itemLoadSameName:GetChecked() == true or false
        else
            state.itemLoadMode = ITEM_LOAD_NONE
            state.itemLoadSameName = false
        end
    else
        state.itemLoadMode = ITEM_LOAD_NONE
        state.itemLoadSameName = false
    end
    if widgets.spellId then
        state.spellId = tonumber(widgets.spellId:GetText() or "") or 0
    end
    if widgets.spellName then
        state.spellName = tostring(widgets.spellName:GetText() or "")
    end
    if widgets.baseCD then
        state.baseCD = tonumber(widgets.baseCD:GetText() or "") or 0
    end
    if widgets.checkTalent then
        if type(widgets.checkTalent.GetValue) == "function" then
            state.checkTalent = widgets.checkTalent:GetValue() == true
        elseif type(widgets.checkTalent.GetChecked) == "function" then
            state.checkTalent = widgets.checkTalent:GetChecked() == true
        end
        if state.objectType == OBJECT_TYPE_ITEM then
            state.checkTalent = false
        end
    end
    if widgets.talentId then
        state.talentId = tonumber(widgets.talentId:GetText() or "") or 0
    end
    if widgets.talentName then
        state.talentName = tostring(widgets.talentName:GetText() or "")
    end
    if widgets.talentCD then
        state.talentCD = tonumber(widgets.talentCD:GetText() or "") or 0
    end
    if widgets.delayEnabled then
        if type(widgets.delayEnabled.GetValue) == "function" then
            state.delayEnabled = widgets.delayEnabled:GetValue() == true
        elseif type(widgets.delayEnabled.GetChecked) == "function" then
            state.delayEnabled = widgets.delayEnabled:GetChecked() == true
        end
    end
    if widgets.castDelayEnabled then
        if type(widgets.castDelayEnabled.GetValue) == "function" then
            state.delayEnabled = widgets.castDelayEnabled:GetValue() == true
        elseif type(widgets.castDelayEnabled.GetChecked) == "function" then
            state.delayEnabled = widgets.castDelayEnabled:GetChecked() == true
        end
    end
    if widgets.castDelaySeconds then
        state.delaySeconds = math.max(0, tonumber(widgets.castDelaySeconds:GetText() or "") or 0)
    elseif widgets.delaySeconds then
        state.delaySeconds = math.max(0, tonumber(widgets.delaySeconds:GetText() or "") or 0)
    end
    if widgets.castDelayModeDrop and widgets.castDelayModeDrop.qfxsaValue ~= nil then
        state.castDelayMode = "show"
    end
    state.fixedCD = true
    local modeTts, modeSound = api.GetModes()
    if widgets.notifyMode then
        local value = tostring(widgets.notifyMode:GetValue() or state.soundSource or "")
        if IsSoundSourceValue(value) then
            state.soundSource = value
            state.notifyMode = (value == "tts") and modeTts or modeSound
        else
            state.notifyMode = (value == tostring(modeTts)) and modeTts or modeSound
            if state.notifyMode == modeTts then
                state.soundSource = "tts"
            elseif tostring(state.soundSource or "") == "" then
                state.soundSource = "builtin"
            end
        end
    end
    if widgets.ttsText then
        state.ttsText = tostring(widgets.ttsText:GetText() or "")
    end
    if widgets.builtinSound and type(widgets.builtinSound.GetValue) == "function" then
        local builtinPath = owner:NormalizeSoundPath(widgets.builtinSound:GetValue() or state.builtinSoundPath or "")
        if builtinPath == "" or not owner:IsBuiltinSoundPath(builtinPath) then
            builtinPath = owner:GetDefaultBuiltinSoundPath()
        end
        state.builtinSoundPath = builtinPath
    end
    if widgets.sharedMediaSound and type(widgets.sharedMediaSound.GetValue) == "function" then
        state.sharedMediaSound = TrimText(widgets.sharedMediaSound:GetValue() or state.sharedMediaSound or "")
    end
    if widgets.soundPath then
        state.customSoundPath = owner:NormalizeSoundPath(widgets.soundPath:GetText() or state.customSoundPath or "")
    end
    state.customSoundPaths = type(state.customSoundPaths) == "table" and state.customSoundPaths or { state.customSoundPath or "", "", "", "", "" }
    state.customSoundPaths[1] = state.customSoundPath
    local bloodlustPathInputs = widgets.bloodlustCustomPaths
    if type(bloodlustPathInputs) == "table" then
        for i = 2, 5 do
            local input = bloodlustPathInputs[i]
            state.customSoundPaths[i] = owner:NormalizeSoundPath((input and input.GetText and input:GetText()) or state.customSoundPaths[i] or "")
        end
    end

    local source = tostring(state.soundSource or "")
    local sourceEntry = {
        notifyMode = (source == "tts") and modeTts or modeSound,
        soundSource = source,
        soundPath = state.soundPath,
        customSoundPath = state.customSoundPath,
        customSoundPaths = state.customSoundPaths,
        builtinSoundPath = state.builtinSoundPath,
        sharedMediaSound = state.sharedMediaSound,
    }

    if source == "tts" then
        sourceEntry.soundPath = ""
        sourceEntry.sharedMediaSound = ""
    elseif source == "sharedmedia" then
        sourceEntry.soundPath = owner:ResolveSharedMediaSoundPath(state.sharedMediaSound, "")
        sourceEntry.customSoundPath = ""
    elseif source == "custom" then
        local customPath = state.customSoundPath
        for i = 1, 5 do
            local path = TrimText((state.customSoundPaths or {})[i] or "")
            if path ~= "" then
                customPath = path
                break
            end
        end
        sourceEntry.customSoundPath = customPath
        sourceEntry.soundPath = customPath
        sourceEntry.sharedMediaSound = ""
    elseif source == "builtin" then
        sourceEntry.soundPath = state.builtinSoundPath or owner:GetDefaultBuiltinSoundPath()
        sourceEntry.sharedMediaSound = ""
        sourceEntry.customSoundPath = ""
    else
        if tostring(state.notifyMode or modeSound) == tostring(modeTts) then
            sourceEntry.soundSource = "tts"
        elseif TrimText(state.sharedMediaSound or "") ~= "" then
            sourceEntry.soundSource = "sharedmedia"
            sourceEntry.soundPath = owner:ResolveSharedMediaSoundPath(state.sharedMediaSound, "")
        elseif TrimText(state.customSoundPath or "") ~= "" then
            sourceEntry.soundSource = "custom"
            sourceEntry.soundPath = state.customSoundPath
        else
            sourceEntry.soundSource = "builtin"
            sourceEntry.soundPath = state.builtinSoundPath or owner:GetDefaultBuiltinSoundPath()
        end
    end

    owner:ApplySoundSourceToState(owner:ResolveSoundSourceFields(sourceEntry, modeTts, modeSound))
end
