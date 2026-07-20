local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.EditorActions = NS.UI.EditorActions or {}
local Actions = NS.UI.EditorActions

local function Refresh(owner)
    if owner and type(owner.Refresh) == "function" then owner:Refresh() end
end

local function Pull(owner)
    if owner and type(owner.PullFromWidgets) == "function" then return owner:PullFromWidgets() end
end

local function SetSaving(owner, saving)
    if not owner then return end
    owner._saving = saving == true
    local w = owner.widgets or (owner.frame and owner.frame.widgets)
    for _, key in ipairs({ "saveOnly", "saveInject", "actionSave" }) do
        local button = w and w[key]
        if button and type(button.SetEnabled) == "function" then
            button:SetEnabled(not owner._saving)
        end
    end
end

local function ErrorHandler(errorText)
    if type(geterrorhandler) == "function" then
        local handler = geterrorhandler()
        if type(handler) == "function" then
            pcall(handler, errorText)
        end
    end
    return tostring(errorText or "unknown error")
end

local function ReportPostSaveError(stage, errorText)
    print("[EUIVE] 保存后处理失败：" .. tostring(stage or "editor") .. "：" .. tostring(errorText or "unknown error"))
end

local function TryPostSave(stage, callback)
    if type(callback) ~= "function" then return false end
    local ok, errorText = xpcall(callback, ErrorHandler)
    if not ok then ReportPostSaveError(stage, errorText) end
    return ok
end

local function FinishSave(owner, inject)
    if not owner or owner._saving then return false end
    SetSaving(owner, true)

    local state
    local saveOK, result, details
    local callOK, errorText = xpcall(function()
        state = Pull(owner) or NS.AceOptions:GetState()
        state.injectOnSave = inject == true
        state.lastSaveDetails = nil
        if state.entryType == "bloodlust" then
            saveOK, result, details = NS.AceOptions:SaveBloodlustConfig()
        else
            saveOK, result, details = NS.AceOptions:SaveEntry()
        end
    end, ErrorHandler)
    if state then
        state.injectOnSave = false
        state.lastSaveResult = result
    end
    details = type(details) == "table" and details or (state and state.lastSaveDetails)
    local committed = saveOK == true or (type(details) == "table" and details.committed == true)

    if not callOK then
        ReportPostSaveError(committed and "editor_after_commit" or "editor_save", errorText)
    end

    if committed then
        TryPostSave("editor_close", function() owner:Close() end)
        TryPostSave("editor_list_cache", function()
            if NS.SavedListLayout and type(NS.SavedListLayout.InvalidateCache) == "function" then
                NS.SavedListLayout:InvalidateCache()
            end
        end)
        TryPostSave("editor_main_refresh", function()
            if NS.UI.MainFrame and type(NS.UI.MainFrame.RequestRefresh) == "function" then
                NS.UI.MainFrame:RequestRefresh("list", 0)
            end
        end)
    else
        TryPostSave("editor_refresh", function() Refresh(owner) end)
    end
    SetSaving(owner, false)
    return committed, result, details
end

function Actions:Install(owner, frame)
    local w = frame.widgets
    w.close:SetScript("OnClick", function() owner:Close() end)
    w.actionClose:SetScript("OnClick", function() owner:Close() end)
    w.tabEUI:SetScript("OnClick", function() owner:SwitchEntryType("euiVoice") end)
    w.tabCast:SetScript("OnClick", function() owner:SwitchEntryType("cast") end)
    w.tabBloodlust:SetScript("OnClick", function() owner:SwitchEntryType("bloodlust") end)

    w.euiTriggerDrop.qfxsaOnValueChanged = function(value)
        NS.AceOptions:GetState().euiTriggerType = tostring(value or "cdReady")
    end
    w.soundSourceDrop.qfxsaOnValueChanged = function(value)
        local state = Pull(owner) or NS.AceOptions:GetState()
        state.soundSource = tostring(value or "builtin")
        Refresh(owner)
    end
    w.builtinDrop.qfxsaOnValueChanged = function(value)
        local state = NS.AceOptions:GetState()
        state.builtinSoundPath = tostring(value or "")
        state.soundPath = state.builtinSoundPath
    end
    w.sharedMediaDrop.qfxsaOnValueChanged = function(value)
        local state = NS.AceOptions:GetState()
        state.sharedMediaSound = tostring(value or "")
        state.soundPath = NS.AceOptions:ResolveSharedMediaSoundPath(state.sharedMediaSound, "")
    end

    w.spellId:SetScript("OnEnterPressed", function(box)
        box:ClearFocus()
        Pull(owner)
        NS.AceOptions:AutofillFromSpellId()
        Refresh(owner)
    end)
    w.scopeButton:SetScript("OnClick", function()
        Pull(owner)
        local state = NS.AceOptions:GetState()
        if NS.UI.ScopeSelector and type(NS.UI.ScopeSelector.Open) == "function" then
            NS.UI.ScopeSelector:Open(state, function() Refresh(owner) end)
        end
    end)

    w.actionTest:SetScript("OnClick", function()
        Pull(owner)
        NS.AceOptions:TestCurrent()
    end)
    w.saveOnly:SetScript("OnClick", function() FinishSave(owner, false) end)
    w.saveInject:SetScript("OnClick", function() FinishSave(owner, true) end)
    w.actionSave:SetScript("OnClick", function() FinishSave(owner, false) end)
end
