local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.MainFrameBuilder = NS.UI.MainFrameBuilder or {}

local Builder = NS.UI.MainFrameBuilder
local Widgets = NS.UI.Widgets
local Skin = NS.UI.Skin
local L = NS.L or function(key, ...)
    if select("#", ...) > 0 then
        return string.format(tostring(key), ...)
    end
    return tostring(key)
end
local MainFrameLocale = NS.UI.MainFrameLocale or {}

function Builder:EnsureFrame(owner)
    owner = owner or (NS.UI and NS.UI.MainFrame)
    if not owner then
        return nil
    end
    if owner.frame then
        return owner.frame
    end

    local frame = CreateFrame("Frame", "EllesmereUIVEMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(1040, 700)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()
    Widgets:ApplyPanelChrome(frame, { footerHeight = 50 })
    tinsert(UISpecialFrames, frame:GetName())

    local header = CreateFrame("Frame", nil, frame)
    header:SetSize(420, 40)
    header:SetPoint("TOP", frame, "TOP", 0, -10)

    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetSize(34, 34)
    logo:SetPoint("LEFT", header, "LEFT", 0, -1)
    logo:SetTexture(NS.ADDON_ICON or "Interface\\AddOns\\EllesmereUIVE\\AppIcon.png")
    logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local title = Widgets:CreateLabel(header, NS.ADDON_DISPLAY_NAME or L("ADDON_DISPLAY_NAME"), "GameFontNormalLarge")
    title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
    title:SetJustifyH("LEFT")
    if Skin then
        Skin:StyleFont(title, "title")
    end

    local function LayoutHeader()
        local titleWidth = 360
        if title.GetStringWidth then
            titleWidth = math.min(math.max((title:GetStringWidth() or 0) + 6, 180), 540)
        end
        title:SetWidth(titleWidth)
        header:SetWidth(34 + 10 + titleWidth)
    end
    LayoutHeader()
    frame:HookScript("OnShow", LayoutHeader)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(28, 28)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    if Skin and Skin.SkinCloseButton then
        Skin:SkinCloseButton(close)
    end
    close:SetScript("OnClick", function()
        owner:Close()
    end)

    local summary = Widgets:CreateLabel(frame, "", "GameFontHighlight")
    summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -62)
    summary:SetPoint("RIGHT", frame, "RIGHT", -245, 0)
    if Skin then
        Skin:StyleFont(summary, "muted")
    end

    local languageLabel = Widgets:CreateLabel(frame, L("LABEL_LANGUAGE"), "GameFontNormal")
    languageLabel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -220, -62)
    if Skin then
        Skin:StyleFont(languageLabel, "accent")
    end

    -- UI skin is fully automatic.  No user-facing skin selector is shown here:
    -- ElvUI / NDui can skin native-friendly controls when loaded; otherwise the built-in fallback is used.

    local languageDrop = Widgets:CreateDropdown(frame, "EllesmereUIVELanguageDropDown", 180)
    languageDrop:ClearAllPoints()
    languageDrop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -54)
    languageLabel:ClearAllPoints()
    languageLabel:SetPoint("RIGHT", languageDrop, "LEFT", -8, 0)
    languageLabel:SetJustifyH("RIGHT")
    Widgets:SetDropdownItems(languageDrop, MainFrameLocale:BuildLanguageItems())
    Widgets:SetDropdownValue(languageDrop, NS.GetLanguageMode and NS.GetLanguageMode() or "auto", L("LANGUAGE_AUTO"))
    languageDrop.qfxsaOnValueChanged = function(value)
        if NS.SetLanguageMode then
            NS.SetLanguageMode(value)
            local label = NS.GetLanguageDisplayName and NS.GetLanguageDisplayName(value) or tostring(value or "auto")
            print("[EUIVE] " .. L("MSG_LANGUAGE_CHANGED", label))
        end
        owner:RefreshLocale()
    end


    local addBtn = Widgets:CreateButton(frame, L("BTN_ADD_VOICE"), 112, 32)
    addBtn:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -16)

    local addGroupBtn = Widgets:CreateButton(frame, L("BTN_ADD_COLLECTION"), 112, 32)
    addGroupBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)

    local editBtn = Widgets:CreateButton(frame, L("BTN_EDIT"), 104, 32)
    editBtn:SetPoint("LEFT", addGroupBtn, "RIGHT", 8, 0)

    local deleteBtn = Widgets:CreateButton(frame, L("BTN_DELETE"), 104, 32)
    deleteBtn:SetPoint("LEFT", editBtn, "RIGHT", 8, 0)

    local refreshBtn = Widgets:CreateButton(frame, L("BTN_REFRESH"), 104, 32)
    refreshBtn:SetPoint("LEFT", deleteBtn, "RIGHT", 8, 0)

    local syncBtn = Widgets:CreateButton(frame, L("BTN_SYNC_CURRENT_SPEC"), 140, 32)
    syncBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 8, 0)

    local importBtn = Widgets:CreateButton(frame, L("BTN_IMPORT"), 104, 32)
    importBtn:SetPoint("LEFT", syncBtn, "RIGHT", 8, 0)

    local exportAllBtn = Widgets:CreateButton(frame, L("BTN_EXPORT_FULL"), 112, 32)
    exportAllBtn:SetPoint("LEFT", importBtn, "RIGHT", 8, 0)

    local toolbarButtons = { addBtn, addGroupBtn, editBtn, deleteBtn, refreshBtn, syncBtn, importBtn, exportAllBtn }
    local toolbarMinWidths = { 108, 112, 82, 82, 82, 132, 82, 108 }
    local function FitToolbarButton(button, minWidth)
        if not button then
            return
        end
        local width = tonumber(minWidth) or 96
        local text = button.GetFontString and button:GetFontString() or nil
        if text and text.GetStringWidth then
            width = math.max(width, math.ceil((text:GetStringWidth() or 0) + 34))
        end
        button:SetSize(width, 32)
    end

    local function LayoutToolbar()
        for index, button in ipairs(toolbarButtons) do
            FitToolbarButton(button, toolbarMinWidths[index])
            button:ClearAllPoints()
            if index == 1 then
                button:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -16)
            else
                button:SetPoint("LEFT", toolbarButtons[index - 1], "RIGHT", 8, 0)
            end
        end
    end
    LayoutToolbar()
    frame:HookScript("OnShow", LayoutToolbar)

    local listHost = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    listHost:SetPoint("TOPLEFT", addBtn, "BOTTOMLEFT", 0, -18)
    listHost:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 24)
    Widgets:ApplyPanelChrome(listHost, { inset = true, noFooter = true, topHeight = 20 })

    local savedList = NS.UI.SavedList:Create(listHost)

    if type(owner.BindActions) == "function" then
        owner:BindActions({
            addBtn = addBtn,
            addGroupBtn = addGroupBtn,
            editBtn = editBtn,
            deleteBtn = deleteBtn,
            refreshBtn = refreshBtn,
            syncBtn = syncBtn,
            importBtn = importBtn,
            exportAllBtn = exportAllBtn,
            savedList = savedList,
        })
    end

    owner.frame = frame
    owner.headerTitle = title
    owner.layoutHeader = LayoutHeader
    owner.summary = summary
    owner.languageLabel = languageLabel
    owner.languageDrop = languageDrop
    owner.addBtn = addBtn
    owner.addGroupBtn = addGroupBtn
    owner.editBtn = editBtn
    owner.deleteBtn = deleteBtn
    owner.refreshBtn = refreshBtn
    owner.syncBtn = syncBtn
    owner.importBtn = importBtn
    owner.exportAllBtn = exportAllBtn
    owner.layoutToolbar = LayoutToolbar
    owner.savedList = savedList
    return frame
end
