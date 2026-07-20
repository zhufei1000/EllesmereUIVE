local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.MainFrame = NS.UI.MainFrame or {}
NS.UI.MainFrameDialogs = NS.UI.MainFrameDialogs or {}

local MainFrame = NS.UI.MainFrame
local Dialogs = NS.UI.MainFrameDialogs
local Widgets = NS.UI.Widgets
local Skin = NS.UI.Skin
local DialogTextArea = NS.UI.DialogTextArea or {}
local L = NS.L or function(key, ...) if select("#", ...) > 0 then return string.format(tostring(key), ...) end return tostring(key) end

local function PrepareNativeDialog(dialog, parent, opts)
    if not dialog then
        return dialog
    end
    opts = opts or {}
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    dialog:SetFrameLevel((parent and parent.GetFrameLevel and (parent:GetFrameLevel() or 1) or 1) + 100)
    dialog:SetToplevel(true)
    dialog:SetClampedToScreen(true)
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    Widgets:ApplyPanelChrome(dialog, { footerHeight = opts.footerHeight or 58 })

    local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    close:SetSize(28, 28)
    close:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -10, -10)
    if Skin and Skin.SkinCloseButton then
        Skin:SkinCloseButton(close)
    end
    close:SetScript("OnClick", function()
        dialog:Hide()
    end)
    dialog.closeButton = close
    return dialog
end

local function CreateMultilineBox(parent, width, height)
    if DialogTextArea and type(DialogTextArea.Create) == "function" then
        return DialogTextArea:Create(parent, width, height)
    end

    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate,BackdropTemplate")
    scrollFrame:SetSize(width, height)
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetSize(math.max(1, width - 34), height)
    scrollFrame:SetScrollChild(editBox)
    return scrollFrame, editBox
end

function Dialogs:PrepareNativeDialog(dialog, parent, opts)
    return PrepareNativeDialog(dialog, parent, opts)
end

function Dialogs:CreateMultilineBox(parent, width, height)
    return CreateMultilineBox(parent, width, height)
end

function MainFrame:EnsureImportExportDialog()
    if self.importExportDialog then
        return self.importExportDialog
    end

    local parent = self:EnsureFrame()
    local dialog = CreateFrame("Frame", "EllesmereUIVEImportExportDialog", parent, "BackdropTemplate")
    dialog:SetSize(720, 500)
    dialog:SetPoint("CENTER", parent, "CENTER", 0, 10)
    dialog:Hide()
    PrepareNativeDialog(dialog, parent, { footerHeight = 58 })

    local title = Widgets:CreateLabel(dialog, L("TITLE_IMPORT_EXPORT"), "GameFontNormalLarge")
    title:SetPoint("TOP", dialog, "TOP", 0, -18)
    title:SetWidth(520)
    title:SetJustifyH("CENTER")
    if Skin then
        Skin:StyleFont(title, "title")
    end

    local desc = Widgets:CreateLabel(dialog, "", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", dialog, "TOPLEFT", 34, -60)
    desc:SetPoint("RIGHT", dialog, "RIGHT", -34, 0)
    desc:SetHeight(44)
    desc:SetJustifyH("LEFT")
    desc:SetJustifyV("TOP")
    if desc.SetWordWrap then
        desc:SetWordWrap(true)
    end
    if Skin then
        Skin:StyleFont(desc, "muted")
    end

    local scrollFrame, editBox = CreateMultilineBox(dialog, 650, 300)
    scrollFrame:SetPoint("TOPLEFT", dialog, "TOPLEFT", 34, -112)

    local importBtn = Widgets:CreateButton(dialog, L("BTN_IMPORT"), 118, 32)
    importBtn:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 34, 20)

    local selectBtn = Widgets:CreateButton(dialog, L("BTN_SELECT_ALL"), 118, 32)
    selectBtn:SetPoint("LEFT", importBtn, "RIGHT", 10, 0)

    local closeBtn = Widgets:CreateButton(dialog, L("BTN_CLOSE"), 118, 32)
    closeBtn:SetPoint("LEFT", selectBtn, "RIGHT", 10, 0)

    importBtn:SetScript("OnClick", function()
        if NS.AceOptions and type(NS.AceOptions.ImportString) == "function" then
            if NS.AceOptions:ImportString(editBox:GetText() or "") then
                dialog:Hide()
                -- ImportExport schedules the expensive rebuild/list refresh work
                -- across frames. Avoid doing a second synchronous full refresh here.
                local scheduler = NS.ImportRefreshScheduler
                if not scheduler or type(scheduler.IsPending) ~= "function" or not scheduler:IsPending() then
                    if type(self.RequestRefresh) == "function" then
                        self:RequestRefresh("list")
                    else
                        self:Refresh()
                    end
                end
            end
        end
    end)
    selectBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)
    closeBtn:SetScript("OnClick", function()
        dialog:Hide()
    end)

    dialog.title = title
    dialog.desc = desc
    dialog.editBox = editBox
    dialog.importBtn = importBtn
    dialog.selectBtn = selectBtn
    self.importExportDialog = dialog
    return dialog
end

function MainFrame:OpenExportDialog(titleText, exportText)
    local dialog = self:EnsureImportExportDialog()
    dialog.title:SetText(tostring(titleText or L("TITLE_EXPORT")))
    dialog.desc:SetText(L("EXPORT_DESC"))
    dialog.editBox:SetText(tostring(exportText or ""))
    dialog.importBtn:Hide()
    dialog.selectBtn:ClearAllPoints()
    dialog.selectBtn:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 34, 20)
    dialog:Show()
    dialog:Raise()
    dialog.editBox:SetFocus()
    dialog.editBox:HighlightText()
end

function MainFrame:OpenImportDialog()
    local dialog = self:EnsureImportExportDialog()
    dialog.title:SetText(L("TITLE_IMPORT_SETTINGS"))
    dialog.desc:SetText(L("IMPORT_DESC"))
    dialog.editBox:SetText("")
    dialog.importBtn:Show()
    dialog.importBtn:ClearAllPoints()
    dialog.importBtn:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 34, 20)
    dialog.selectBtn:ClearAllPoints()
    dialog.selectBtn:SetPoint("LEFT", dialog.importBtn, "RIGHT", 10, 0)
    dialog:Show()
    dialog:Raise()
    dialog.editBox:SetFocus()
end
