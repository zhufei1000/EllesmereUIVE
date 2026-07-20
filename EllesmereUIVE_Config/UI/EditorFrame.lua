local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.EditorFrame = NS.UI.EditorFrame or {}

local EditorFrame = NS.UI.EditorFrame
local EditorFields = NS.UI.EditorFields or {}
local EditorDrafts = NS.UI.EditorDrafts or {}
local L = NS.L or function(key, ...) if select("#", ...) > 0 then return string.format(tostring(key), ...) end return tostring(key) end

local function NormalizeEntryType(value)
    if EditorDrafts and type(EditorDrafts.NormalizeEntryType) == "function" then
        return EditorDrafts:NormalizeEntryType(value)
    end
    value = tostring(value or "euiVoice")
    if value == "cast" or value == "bloodlust" then
        return value
    end
    return "euiVoice"
end

local function SaveEditorDraft(state, entryType)
    if EditorDrafts and type(EditorDrafts.Save) == "function" then
        return EditorDrafts:Save(state, entryType)
    end
end


local function ResetEditorScroll(frame)
    if not frame or not frame.contentHost then
        return
    end
    if frame.contentHost.slider then
        frame.contentHost.slider:SetValue(0)
    end
    if frame.contentHost.scrollFrame then
        frame.contentHost.scrollFrame:SetVerticalScroll(0)
    end
    if frame.contentHost.UpdateScrollRange then
        frame.contentHost:UpdateScrollRange()
    end
end

local function RefreshEditorDragPreview(editor)
    if not editor or not editor.frame or not editor.frame:IsShown() then
        return
    end
    local state = NS.AceOptions and NS.AceOptions.GetState and NS.AceOptions:GetState() or {}
    local preview = NS.UI and NS.UI.VisualPositionPreview
    if not preview then
        return
    end
    if state.imageEnabled == true or state.textEnabled == true then
        if type(preview.Show) == "function" then preview:Show(editor) end
    elseif type(preview.Hide) == "function" then
        preview:Hide()
    end
end

local function DeferredRefresh(editor)
    if not editor or not editor.frame or not editor.frame:IsShown() then
        return
    end
    editor:PushToWidgets()
    ResetEditorScroll(editor.frame)
    RefreshEditorDragPreview(editor)
    if editor.frame.Raise then editor.frame:Raise() end
end

local function RestoreEditorDraft(state, entryType)
    if EditorDrafts and type(EditorDrafts.Restore) == "function" then
        return EditorDrafts:Restore(state, entryType)
    end
end

function EditorFrame:EnsureFrame()
    local builder = NS.UI and NS.UI.EditorFrameBuilder
    if builder and type(builder.EnsureFrame) == "function" then
        return builder:EnsureFrame(self)
    end
    return self.frame
end


function EditorFrame:SwitchEntryType(entryType)
    local state = NS.AceOptions:GetState()
    entryType = NormalizeEntryType(entryType)

    if self.mode == "new" then
        self:PullFromWidgets()
        local currentType = tostring(state.entryType or "")
        if currentType == "euiVoice" or currentType == "cast" then
            SaveEditorDraft(state, currentType)
        end
        RestoreEditorDraft(state, entryType)
    else
        self:PullFromWidgets()
        state.entryType = entryType
        if entryType == "euiVoice" then
            state.delayEnabled = false
            state.delaySeconds = 0
            state.castDelayMode = "show"
        elseif entryType == "cast" then
            state.baseCD = 0
            state.checkTalent = false
            state.talentId = 0
            state.talentName = ""
            state.talentCD = 0
        end
    end

    state.activeAlertTab = "settings"
    self:Refresh()
end


function EditorFrame:PullFromWidgets()
    return EditorFields:PullFromWidgets(self)
end

function EditorFrame:PushToWidgets()
    return EditorFields:PushToWidgets(self)
end

function EditorFrame:RefreshLocale()
    return EditorFields:RefreshLocale(self)
end

function EditorFrame:Refresh()
    if self.frame and self.frame:IsShown() then
        self:PushToWidgets()
        if self.frame.contentHost and self.frame.contentHost.UpdateScrollRange then
            self.frame.contentHost:UpdateScrollRange()
        end
        self.frame:Raise()
    end
end

function EditorFrame:OpenForNew(entryType)
    local state = NS.AceOptions:GetState()
    local selectedGroupKey = tostring(state.selectedCollectionKey or "")
    if selectedGroupKey == "" and NS.AceOptions and type(NS.AceOptions.IsGroupKey) == "function" and NS.AceOptions:IsGroupKey(state.selectedKey) then
        selectedGroupKey = tostring(state.selectedKey or "")
    end

    local info = nil
    if selectedGroupKey ~= "" and NS.AceOptions and type(NS.AceOptions.GetCollectionInfo) == "function" then
        info = NS.AceOptions:GetCollectionInfo(selectedGroupKey)
    end

    if type(info) == "table" then
        state.classID = tonumber(info.classID) or 0
        state.specID = tonumber(info.specID) or 0
        state.selectedCollectionKey = tostring(info.key or selectedGroupKey)
        state.selectedKey = tostring(info.key or selectedGroupKey)
    else
        NS.AceOptions:SyncScopeToCurrentSpec()
    end

    NS.AceOptions:EnsureValidScope()
    NS.AceOptions:ClearEditorFields()
    state.editingEntryUID = nil
    state.originalClassID = nil
    state.originalSpecID = nil
    state.originalIndex = nil
    state._editorDrafts = {}
    state._mcdCustomNotifyVisibleCount = nil
    state._mcdCustomNotifyManualCount = nil
    state.entryType = NormalizeEntryType(entryType or "euiVoice")
    state.activeAlertTab = "settings"
    if state.entryType == "bloodlust" and NS.AceOptions and type(NS.AceOptions.LoadBloodlustConfig) == "function" then
        NS.AceOptions:LoadBloodlustConfig()
        state.activeAlertTab = "settings"
    end
    if type(info) == "table" then
        state.selectedCollectionKey = tostring(info.key or selectedGroupKey)
    end
    local frame = self:EnsureFrame()
    self.mode = "new"
    frame.title:SetText(L("TITLE_NEW_CONFIG"))
    frame.qfxsaLastActiveAlertTab = nil
    frame:Show()
    frame:Raise()
    self:PushToWidgets()
    ResetEditorScroll(frame)
    RefreshEditorDragPreview(self)
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, function() DeferredRefresh(self) end)
        C_Timer.After(0.05, function() DeferredRefresh(self) end)
    end
end

function EditorFrame:OpenForEdit()
    local state = NS.AceOptions:GetState()
    if tostring(state.selectedKey or "") == "" then
        print("[EUIVE] " .. L("MSG_CHOOSE_CONFIG"))
        return
    end

    NS.AceOptions:LoadSelectedEntry()
    state._mcdCustomNotifyVisibleCount = nil
    state._mcdCustomNotifyManualCount = nil
    local frame = self:EnsureFrame()
    self.mode = "edit"
    frame.title:SetText(L("TITLE_EDIT_CONFIG"))
    frame.qfxsaLastActiveAlertTab = nil
    frame:Show()
    frame:Raise()
    self:PushToWidgets()
    ResetEditorScroll(frame)
    RefreshEditorDragPreview(self)
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, function() DeferredRefresh(self) end)
        C_Timer.After(0.05, function() DeferredRefresh(self) end)
    end
end

local function RestoreLockedVisualFromEditor(editor)
    local state = NS.AceOptions and NS.AceOptions.GetState and NS.AceOptions:GetState() or {}
    local selectedKey = tostring(state.selectedKey or "")
    if selectedKey == "" then
        return
    end
    local bridge = NS.Core and NS.Core.NotifierBridge
    if bridge and type(bridge.RefreshActiveVisualForKey) == "function" then
        bridge:RefreshActiveVisualForKey(selectedKey, state)
    end
end

function EditorFrame:Close()
    local preview = NS.UI and NS.UI.VisualPositionPreview
    if preview and type(preview.Hide) == "function" then
        preview:Hide()
    end
    RestoreLockedVisualFromEditor(self)
    if self.frame then
        self.frame:Hide()
    end
end
