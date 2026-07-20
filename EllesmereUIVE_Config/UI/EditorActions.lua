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

local function FinishSave(owner, inject)
    local state = Pull(owner) or NS.AceOptions:GetState()
    state.injectOnSave = inject == true
    local ok
    if state.entryType == "bloodlust" then
        ok = NS.AceOptions:SaveBloodlustConfig()
    else
        ok = NS.AceOptions:SaveEntry()
    end
    state.injectOnSave = false
    if ok then
        if NS.UI.MainFrame and type(NS.UI.MainFrame.RequestRefresh) == "function" then
            NS.UI.MainFrame:RequestRefresh("list")
        end
        owner:Close()
    else
        Refresh(owner)
    end
end

function Actions:Install(owner, frame)
    local w = frame.widgets
    w.close:SetScript("OnClick", function() owner:Close() end)
    w.actionClose:SetScript("OnClick", function() owner:Close() end)
    w.tabEUI:SetScript("OnClick", function() owner:SwitchEntryType("euiVoice") end)
    w.tabCast:SetScript("OnClick", function() owner:SwitchEntryType("cast") end)
    w.tabBloodlust:SetScript("OnClick", function() owner:SwitchEntryType("bloodlust") end)

    w.classDrop.qfxsaOnValueChanged = function(value)
        local state = Pull(owner) or NS.AceOptions:GetState()
        state.classID = tonumber(value) or 0
        state.specID = 0
        state.alertClassIDs = { [state.classID] = true }
        state.alertSpecIDs = { [0] = true }
        Refresh(owner)
    end
    w.specDrop.qfxsaOnValueChanged = function(value)
        local state = Pull(owner) or NS.AceOptions:GetState()
        state.specID = tonumber(value) or 0
        state.alertSpecIDs = { [state.specID] = true }
        Refresh(owner)
    end
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
