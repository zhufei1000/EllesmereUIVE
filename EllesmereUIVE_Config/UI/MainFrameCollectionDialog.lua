local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.MainFrame = NS.UI.MainFrame or {}
NS.UI.MainFrameCollectionDialog = NS.UI.MainFrameCollectionDialog or {}

local MainFrame = NS.UI.MainFrame
local Dialogs = NS.UI.MainFrameDialogs or {}
local Widgets = NS.UI.Widgets
local Skin = NS.UI.Skin
local L = NS.L or function(key, ...) if select("#", ...) > 0 then return string.format(tostring(key), ...) end return tostring(key) end

function MainFrame:EnsureCollectionDialog()
    if self.collectionDialog then
        return self.collectionDialog
    end

    local parent = self:EnsureFrame()
    local dialog = CreateFrame("Frame", "EllesmereUIVECollectionNameDialog", parent, "BackdropTemplate")
    dialog:SetSize(660, 420)
    dialog:SetPoint("CENTER", parent, "CENTER", 0, 18)
    dialog:Hide()
    if Dialogs and type(Dialogs.PrepareNativeDialog) == "function" then
        Dialogs:PrepareNativeDialog(dialog, parent, { footerHeight = 58 })
    end

    local title = Widgets:CreateLabel(dialog, L("TITLE_ADD_COLLECTION"), "GameFontNormalLarge")
    title:SetPoint("TOP", dialog, "TOP", 0, -18)
    title:SetWidth(460)
    title:SetJustifyH("CENTER")
    if Skin then
        Skin:StyleFont(title, "title")
    end

    local nameLabel = Widgets:CreateLabel(dialog, L("COLLECTION_NAME"), "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", 34, -70)
    if Skin then
        Skin:StyleFont(nameLabel, "accent")
    end

    local editBox = Widgets:CreateEditBox(dialog, 592, 32, false)
    editBox:SetPoint("TOPLEFT", dialog, "TOPLEFT", 34, -98)

    local iconLabel = Widgets:CreateLabel(dialog, L("COLLECTION_ICON_ID"), "GameFontNormal")
    iconLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", 34, -150)
    if Skin then
        Skin:StyleFont(iconLabel, "accent")
    end

    local iconEditBox = Widgets:CreateEditBox(dialog, 210, 32, true)
    iconEditBox:SetPoint("TOPLEFT", dialog, "TOPLEFT", 34, -176)

    local iconPreviewBorder = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
    iconPreviewBorder:SetSize(42, 42)
    iconPreviewBorder:SetPoint("LEFT", iconEditBox, "RIGHT", 14, 0)
    if Skin and Skin.ApplyWindowChrome then
        Skin:ApplyWindowChrome(iconPreviewBorder, { inset = true, noFooter = true, noTopLine = true, topHeight = 0 })
    end

    local iconPreview = iconPreviewBorder:CreateTexture(nil, "ARTWORK")
    iconPreview:SetSize(32, 32)
    iconPreview:SetPoint("CENTER", iconPreviewBorder, "CENTER", 0, 0)
    iconPreview:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local iconHint = Widgets:CreateLabel(dialog, L("COLLECTION_ICON_HINT"), "GameFontHighlightSmall")
    iconHint:SetPoint("LEFT", iconPreviewBorder, "RIGHT", 12, 0)
    iconHint:SetPoint("RIGHT", dialog, "RIGHT", -34, 0)
    iconHint:SetHeight(42)
    iconHint:SetJustifyH("LEFT")
    iconHint:SetJustifyV("MIDDLE")
    if iconHint.SetWordWrap then
        iconHint:SetWordWrap(true)
    end
    if Skin then
        Skin:StyleFont(iconHint, "muted")
    end

    local hint = Widgets:CreateLabel(dialog, L("COLLECTION_HINT"), "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", dialog, "TOPLEFT", 34, -258)
    hint:SetPoint("RIGHT", dialog, "RIGHT", -34, 0)
    hint:SetHeight(56)
    hint:SetJustifyH("LEFT")
    hint:SetJustifyV("TOP")
    if hint.SetWordWrap then
        hint:SetWordWrap(true)
    end
    if Skin then
        Skin:StyleFont(hint, "muted")
    end

    local save = Widgets:CreateButton(dialog, L("BTN_CREATE"), 118, 32)
    save:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 34, 20)

    local cancel = Widgets:CreateButton(dialog, L("BTN_CANCEL"), 118, 32)
    cancel:SetPoint("LEFT", save, "RIGHT", 10, 0)

    local function UpdateIconPreview()
        local texture = NS.AceOptions:ResolveCollectionIcon(iconEditBox:GetText())
        iconPreview:SetTexture(texture)
    end

    local function SubmitCollectionDialog()
        local name = tostring(editBox:GetText() or "")
        local iconID = tostring(iconEditBox:GetText() or "")
        local ok = false
        if dialog.mode == "rename" then
            ok = NS.AceOptions:RenameCollection(dialog.groupKey, name, iconID, true)
        else
            if dialog.parentGroupKey and NS.AceOptions and type(NS.AceOptions.GetState) == "function" then
                local state = NS.AceOptions:GetState()
                state.selectedCollectionKey = tostring(dialog.parentGroupKey or "")
                if tostring(dialog.parentGroupKey or "") ~= "" then
                    state.selectedKey = tostring(dialog.parentGroupKey or "")
                end
            end
            ok = NS.AceOptions:CreateCollection(name, iconID, dialog.parentGroupKey, true)
        end
        if ok then
            dialog:Hide()
            dialog.mode = "create"
            dialog.groupKey = nil
            dialog.parentGroupKey = nil
            self:RequestRefresh("list")
        end
    end

    save:SetScript("OnClick", SubmitCollectionDialog)
    cancel:SetScript("OnClick", function()
        dialog:Hide()
    end)
    editBox:SetScript("OnEnterPressed", function(box)
        box:ClearFocus()
        SubmitCollectionDialog()
    end)
    iconEditBox:SetScript("OnTextChanged", UpdateIconPreview)
    iconEditBox:SetScript("OnEnterPressed", function(box)
        box:ClearFocus()
        SubmitCollectionDialog()
    end)
    editBox:SetScript("OnEscapePressed", function(box)
        box:ClearFocus()
        dialog:Hide()
    end)
    iconEditBox:SetScript("OnEscapePressed", function(box)
        box:ClearFocus()
        dialog:Hide()
    end)

    dialog.title = title
    dialog.saveButton = save
    dialog.editBox = editBox
    dialog.iconEditBox = iconEditBox
    dialog.UpdateIconPreview = UpdateIconPreview
    dialog.mode = "create"
    dialog.groupKey = nil
    self.collectionDialog = dialog
    return dialog
end


function MainFrame:OpenCollectionNameDialog()
    local dialog = self:EnsureCollectionDialog()
    dialog.mode = "create"
    dialog.groupKey = nil
    dialog.parentGroupKey = nil
    if NS.AceOptions and type(NS.AceOptions.GetState) == "function" then
        local state = NS.AceOptions:GetState()
        local selectedKey = tostring(state.selectedCollectionKey or "")
        if selectedKey == "" and NS.AceOptions.IsGroupKey and NS.AceOptions:IsGroupKey(state.selectedKey) then
            selectedKey = tostring(state.selectedKey or "")
        end
        if selectedKey ~= "" and NS.AceOptions.IsGroupKey and NS.AceOptions:IsGroupKey(selectedKey) then
            dialog.parentGroupKey = selectedKey
        end
    end
    if dialog.title then
        dialog.title:SetText(L("TITLE_ADD_COLLECTION"))
    end
    if dialog.saveButton then
        dialog.saveButton:SetText(L("BTN_CREATE"))
    end
    dialog.editBox:SetText("")
    if dialog.iconEditBox then
        dialog.iconEditBox:SetText("")
    end
    if type(dialog.UpdateIconPreview) == "function" then
        dialog.UpdateIconPreview()
    end
    dialog:Show()
    dialog:Raise()
    dialog.editBox:SetFocus()
end

function MainFrame:OpenCollectionNameDialogForGroup(groupKey)
    groupKey = tostring(groupKey or "")
    if groupKey == "" then
        return self:OpenCollectionNameDialog()
    end
    if NS.AceOptions and type(NS.AceOptions.IsGroupKey) == "function" and NS.AceOptions:IsGroupKey(groupKey) then
        local state = NS.AceOptions:GetState()
        state.selectedKey = groupKey
        state.selectedCollectionKey = groupKey
        if self.savedList and type(self.savedList.SetSelectedKey) == "function" then
            self.savedList:SetSelectedKey(groupKey)
        end
    end
    return self:OpenCollectionNameDialog()
end

function MainFrame:OpenNewVoiceInCollection(groupKey)
    groupKey = tostring(groupKey or "")
    if groupKey ~= "" and NS.AceOptions and type(NS.AceOptions.IsGroupKey) == "function" and NS.AceOptions:IsGroupKey(groupKey) then
        local state = NS.AceOptions:GetState()
        state.selectedKey = groupKey
        state.selectedCollectionKey = groupKey
        if self.savedList and type(self.savedList.SetSelectedKey) == "function" then
            self.savedList:SetSelectedKey(groupKey)
        end
    end
    if NS.UI and NS.UI.EditorFrame and type(NS.UI.EditorFrame.OpenForNew) == "function" then
        NS.UI.EditorFrame:OpenForNew()
    end
end

function MainFrame:OpenRenameCollectionDialog(groupKey)
    local dialog = self:EnsureCollectionDialog()
    local info = NS.AceOptions and type(NS.AceOptions.GetCollectionInfo) == "function" and NS.AceOptions:GetCollectionInfo(groupKey) or nil
    if type(info) ~= "table" then
        return false
    end

    dialog.mode = "rename"
    dialog.groupKey = tostring(groupKey or "")
    if dialog.title then
        dialog.title:SetText(L("TITLE_RENAME_COLLECTION"))
    end
    if dialog.saveButton then
        dialog.saveButton:SetText(L("BTN_SAVE"))
    end
    dialog.editBox:SetText(tostring(info.name or ""))
    if dialog.iconEditBox then
        dialog.iconEditBox:SetText(info.iconID and tostring(info.iconID) or "")
    end
    if type(dialog.UpdateIconPreview) == "function" then
        dialog.UpdateIconPreview()
    end
    dialog:Show()
    dialog:Raise()
    dialog.editBox:SetFocus()
    dialog.editBox:HighlightText()
    return true
end
