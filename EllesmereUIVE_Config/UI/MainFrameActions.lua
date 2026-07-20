local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.MainFrame = NS.UI.MainFrame or {}
NS.UI.MainFrameActions = NS.UI.MainFrameActions or {}

local MainFrame = NS.UI.MainFrame
local Widgets = NS.UI and NS.UI.Widgets or nil
local Skin = NS.UI and NS.UI.Skin or nil
local L = NS.L or function(key, ...) if select("#", ...) > 0 then return string.format(tostring(key), ...) end return tostring(key) end

local function CreateButton(parent, text, width, height)
    if Widgets and type(Widgets.CreateButton) == "function" then
        return Widgets:CreateButton(parent, text, width, height)
    end
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 160, height or 32)
    btn:SetText(text or "")
    return btn
end

local function CreateLabel(parent, text, template)
    if Widgets and type(Widgets.CreateLabel) == "function" then
        return Widgets:CreateLabel(parent, text, template or "GameFontHighlight")
    end
    local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlight")
    fs:SetText(text or "")
    return fs
end

local function EnsureAddTypeSelector(owner)
    if owner.addTypeSelector then
        return owner.addTypeSelector
    end

    local frame = CreateFrame("Frame", "EllesmereUIVEAddTypeSelectorFrame", UIParent, "BackdropTemplate")
    frame:SetSize(460, 330)
    frame:SetPoint("CENTER", UIParent, "CENTER", 100, 0)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(120)
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()
    if Widgets and type(Widgets.ApplyPanelChrome) == "function" then
        Widgets:ApplyPanelChrome(frame, { footerHeight = 0 })
    end
    if frame.GetName and frame:GetName() then
        tinsert(UISpecialFrames, frame:GetName())
    end

    local title = CreateLabel(frame, L("TITLE_SELECT_ALERT_TYPE"), "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -18)
    title:SetWidth(380)
    title:SetJustifyH("CENTER")
    if Skin and Skin.StyleFont then Skin:StyleFont(title, "title") end

    local desc = CreateLabel(frame, L("SELECT_ALERT_TYPE_DESC"), "GameFontHighlightSmall")
    desc:SetPoint("TOP", title, "BOTTOM", 0, -8)
    desc:SetWidth(390)
    desc:SetJustifyH("CENTER")
    if desc.SetWordWrap then desc:SetWordWrap(true) end
    if Skin and Skin.StyleFont then Skin:StyleFont(desc, "muted") end

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(28, 28)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    if Skin and Skin.SkinCloseButton then Skin:SkinCloseButton(close) end
    close:SetScript("OnClick", function() frame:Hide() end)

    local function AddChoice(entryType, label, hint, y)
        local btn = CreateButton(frame, label, 360, 44)
        btn:SetPoint("TOP", frame, "TOP", 0, y)
        btn:SetScript("OnClick", function()
            frame:Hide()
            if NS.UI and NS.UI.EditorFrame and type(NS.UI.EditorFrame.OpenForNew) == "function" then
                NS.UI.EditorFrame:OpenForNew(entryType)
            end
        end)
        local hintText = CreateLabel(frame, hint, "GameFontDisableSmall")
        hintText:SetPoint("TOP", btn, "BOTTOM", 0, -3)
        hintText:SetWidth(360)
        hintText:SetJustifyH("CENTER")
        if Skin and Skin.StyleFont then Skin:StyleFont(hintText, "muted") end
        return btn, hintText
    end

    frame.cooldownBtn, frame.cooldownHint = AddChoice("euiVoice", L("TAB_COOLDOWN"), L("SELECT_ALERT_TYPE_COOLDOWN_DESC"), -82)
    frame.castBtn, frame.castHint = AddChoice("cast", L("TAB_CAST"), L("SELECT_ALERT_TYPE_CAST_DESC"), -156)
    frame.bloodlustBtn, frame.bloodlustHint = AddChoice("bloodlust", L("TAB_BLOODLUST"), L("SELECT_ALERT_TYPE_BLOODLUST_DESC"), -230)
    frame.RefreshLocale = function(selfFrame)
        title:SetText(L("TITLE_SELECT_ALERT_TYPE"))
        desc:SetText(L("SELECT_ALERT_TYPE_DESC"))
        selfFrame.cooldownBtn:SetText(L("TAB_COOLDOWN"))
        selfFrame.castBtn:SetText(L("TAB_CAST"))
        selfFrame.bloodlustBtn:SetText(L("TAB_BLOODLUST"))
        selfFrame.cooldownHint:SetText(L("SELECT_ALERT_TYPE_COOLDOWN_DESC"))
        selfFrame.castHint:SetText(L("SELECT_ALERT_TYPE_CAST_DESC"))
        selfFrame.bloodlustHint:SetText(L("SELECT_ALERT_TYPE_BLOODLUST_DESC"))
    end

    owner.addTypeSelector = frame
    return frame
end

function MainFrame:OpenAddTypeSelector()
    local frame = EnsureAddTypeSelector(self)
    if frame.RefreshLocale then
        frame:RefreshLocale()
    end
    frame:Show()
    frame:Raise()
end


function MainFrame:BindActions(controls)
    controls = controls or {}
    local addBtn = controls.addBtn
    local addGroupBtn = controls.addGroupBtn
    local editBtn = controls.editBtn
    local deleteBtn = controls.deleteBtn
    local refreshBtn = controls.refreshBtn
    local syncBtn = controls.syncBtn
    local importBtn = controls.importBtn
    local exportAllBtn = controls.exportAllBtn
    local savedList = controls.savedList

addBtn:SetScript("OnClick", function()
    if NS.UI and NS.UI.EditorFrame and type(NS.UI.EditorFrame.OpenForNew) == "function" then
        NS.UI.EditorFrame:OpenForNew("euiVoice")
    end
end)
addGroupBtn:SetScript("OnClick", function()
    self:OpenCollectionNameDialog()
end)
editBtn:SetScript("OnClick", function()
    local selectedKey = tostring(NS.AceOptions:GetState().selectedKey or "")
    if NS.AceOptions and type(NS.AceOptions.IsGroupKey) == "function" and NS.AceOptions:IsGroupKey(selectedKey) then
        self:OpenRenameCollectionDialog(selectedKey)
    else
        NS.UI.EditorFrame:OpenForEdit()
    end
end)
deleteBtn:SetScript("OnClick", function()
    local selectedKey = tostring(NS.AceOptions:GetState().selectedKey or "")
    if NS.AceOptions and type(NS.AceOptions.IsGroupKey) == "function" and NS.AceOptions:IsGroupKey(selectedKey) then
        if NS.AceOptions:DeleteCollection(selectedKey, true) then
            self:RequestRefresh("list")
        end
    else
        NS.AceOptions:DeleteSelectedEntry(true)
        self:RequestRefresh("list")
    end
end)
refreshBtn:SetScript("OnClick", function()
    self:Refresh()
end)
if syncBtn then
    syncBtn:SetScript("OnClick", function()
        syncBtn:SetEnabled(false)
        local _, status, stats = NS:SyncSelectedEUIEntries()
        syncBtn:SetEnabled(true)
        if NS.SavedListLayout and type(NS.SavedListLayout.InvalidateCache) == "function" then
            NS.SavedListLayout:InvalidateCache()
        end
        self:Refresh()
        if status == "complete" and type(stats) == "table" then
            NS:Print(NS.L("SYNC_SUMMARY", stats.injected or 0, stats.upToDate or 0, stats.waiting or 0,
                stats.reloadRequired or 0, stats.conflict or 0, stats.invalidSound or 0, stats.unsupported or 0))
        else
            NS:Print(NS.L("STATUS_" .. tostring(status or "saved_waiting_sync")))
        end
    end)
end
importBtn:SetScript("OnClick", function()
    self:OpenImportDialog()
end)
exportAllBtn:SetScript("OnClick", function()
    if NS.AceOptions and type(NS.AceOptions.ExportFullString) == "function" then
        self:OpenExportDialog(L("EXPORT_FULL_TITLE"), NS.AceOptions:ExportFullString())
    end
end)

savedList:SetOnSelectionChanged(function(key, entryType, oldKey)
    local state = NS.AceOptions:GetState()
    key = tostring(key or "")
    local isGroup = NS.AceOptions and type(NS.AceOptions.IsGroupKey) == "function" and NS.AceOptions:IsGroupKey(key)
    state.selectedKey = key
    if isGroup then
        state.selectedCollectionKey = key
    else
        state.selectedCollectionKey = nil
        state.entryType = entryType or state.entryType or "euiVoice"
        NS.AceOptions:LoadSelectedEntry()
    end
    if savedList and type(savedList.UpdateSelectionOnly) == "function" then
        savedList:UpdateSelectionOnly(oldKey, key)
    end
    if type(self.RefreshActionButtons) == "function" then
        self:RefreshActionButtons()
    end
end)

end
