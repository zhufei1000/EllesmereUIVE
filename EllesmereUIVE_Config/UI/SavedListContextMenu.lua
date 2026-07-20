local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.SavedListContextMenu = NS.UI.SavedListContextMenu or {}

local ContextMenu = NS.UI.SavedListContextMenu
local Skin = NS.UI.Skin
local SavedListBuilder = NS.UI.SavedListBuilder or {}
local L = NS.L or function(key, ...) if select("#", ...) > 0 then return string.format(tostring(key), ...) end return tostring(key) end

local CONTEXT_MENU_WIDTH = 220
local CONTEXT_MENU_ROW_HEIGHT = 24

local function CloseNativeDropdowns()
    local closeDropDownMenus = rawget(_G, "CloseDropDownMenus")
    if type(closeDropDownMenus) == "function" then
        pcall(closeDropDownMenus)
    end

    local popup = rawget(_G, "EllesmereUIVENativeDropDownPopup")
    if popup and popup.Hide then
        popup:Hide()
    end
    local blocker = rawget(_G, "EllesmereUIVENativeDropDownBlocker")
    if blocker and blocker.Hide then
        blocker:Hide()
    end
end

function ContextMenu:Hide(list)
    if not list then
        return
    end
    if list.contextMenu then
        list.contextMenu:Hide()
    end
    if list.contextBlocker then
        list.contextBlocker:Hide()
    end
end

function ContextMenu:Open(list, items)
    if not list or type(items) ~= "table" or #items <= 0 then
        return
    end

    CloseNativeDropdowns()

    if not list.contextBlocker then
        local blocker = CreateFrame("Frame", "EllesmereUIVESavedListContextBlocker", UIParent)
        blocker:SetAllPoints(UIParent)
        blocker:SetFrameStrata("FULLSCREEN_DIALOG")
        blocker:SetFrameLevel(900)
        blocker:EnableMouse(true)
        blocker:Hide()
        blocker:SetScript("OnMouseDown", function()
            ContextMenu:Hide(list)
        end)
        list.contextBlocker = blocker
    end

    if not list.contextMenu then
        local menu = CreateFrame("Frame", "EllesmereUIVESavedListContextMenu", UIParent, "BackdropTemplate")
        menu:SetFrameStrata("TOOLTIP")
        menu:SetFrameLevel(1000)
        menu:EnableMouse(true)
        menu.rows = {}
        if menu.SetBackdrop then
            menu:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 14,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            menu:SetBackdropColor(0, 0, 0, 0.92)
            menu:SetBackdropBorderColor(0.75, 0.75, 0.75, 0.90)
        end
        menu:SetScript("OnHide", function()
            if list.contextBlocker then
                list.contextBlocker:Hide()
            end
        end)
        list.contextMenu = menu
    end

    local menu = list.contextMenu
    for _, row in ipairs(menu.rows or {}) do
        row:Hide()
    end

    local width = CONTEXT_MENU_WIDTH
    local rowHeight = CONTEXT_MENU_ROW_HEIGHT
    local height = (#items * rowHeight) + 8
    menu:SetSize(width, height)

    for i, item in ipairs(items) do
        local row = menu.rows[i]
        if not row then
            row = CreateFrame("Button", nil, menu)
            row:SetHeight(rowHeight)
            row:SetPoint("LEFT", menu, "LEFT", 4, 0)
            row:SetPoint("RIGHT", menu, "RIGHT", -4, 0)
            local hover = row:CreateTexture(nil, "HIGHLIGHT")
            hover:SetAllPoints(row)
            hover:SetColorTexture(0.24, 0.48, 1.00, 0.18)
            row.hover = hover
            local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            text:SetPoint("LEFT", row, "LEFT", 8, 0)
            text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            text:SetJustifyH("LEFT")
            text:SetJustifyV("MIDDLE")
            if text.SetWordWrap then
                text:SetWordWrap(false)
            end
            if text.SetMaxLines then
                text:SetMaxLines(1)
            end
            if Skin and Skin.StyleFont then
                Skin:StyleFont(text, "body")
            end
            row.text = text
            menu.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - ((i - 1) * rowHeight))
        row:SetPoint("RIGHT", menu, "RIGHT", -4, 0)
        row.text:SetText(tostring(item.text or ""))
        row:SetScript("OnClick", function()
            ContextMenu:Hide(list)
            if type(item.func) == "function" then
                item.func()
            end
        end)
        row:Show()
    end

    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1
    local uiWidth = UIParent:GetWidth() or 0
    local uiHeight = UIParent:GetHeight() or 0
    local left = ((x or 0) / scale) + 2
    local top = ((y or 0) / scale) - 2
    if uiWidth > 0 and left + width > uiWidth then
        left = math.max(4, uiWidth - width - 4)
    end
    if uiHeight > 0 and top > uiHeight - 4 then
        top = uiHeight - 4
    end
    if top - height < 4 then
        top = math.min(uiHeight - 4, height + 4)
    end

    list.contextBlocker:Show()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    menu:Show()
end

function ContextMenu:OpenEntryMenu(list, key, entryType)
    if list and type(list.SelectKey) == "function" then
        list:SelectKey(key, entryType)
    end

    self:Open(list, {
        {
            text = L("EDIT_ENTRY"),
            func = function()
                if list and type(list.SelectKey) == "function" then
                    list:SelectKey(key, entryType)
                end
                if NS.UI and NS.UI.EditorFrame then
                    NS.UI.EditorFrame:OpenForEdit()
                end
            end,
        },
        {
            text = L("EXPORT_ENTRY"),
            func = function()
                if NS.UI and NS.UI.MainFrame and NS.AceOptions and type(NS.AceOptions.ExportEntryString) == "function" then
                    NS.UI.MainFrame:OpenExportDialog(L("EXPORT_ENTRY"), NS.AceOptions:ExportEntryString(key))
                end
            end,
        },
        {
            text = L("DELETE_ENTRY"),
            func = function()
                if list and type(list.SelectKey) == "function" then
                    list:SelectKey(key, entryType)
                end
                NS.AceOptions:DeleteSelectedEntry(true)
                if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.RequestRefresh) == "function" then
                    NS.UI.MainFrame:RequestRefresh("list")
                elseif list then
                    list:RequestRefresh(0)
                end
            end,
        },
    })
end

function ContextMenu:OpenGroupMenu(list, key)
    local collapsed = false
    if SavedListBuilder and type(SavedListBuilder.IsGroupCollapsed) == "function" then
        collapsed = SavedListBuilder.IsGroupCollapsed(key) == true
    end

    self:Open(list, {
        {
            text = collapsed and L("EXPAND_COLLECTION") or L("COLLAPSE_COLLECTION"),
            func = function()
                if list and type(list.ToggleGroupCollapsed) == "function" then
                    list:ToggleGroupCollapsed(key)
                end
            end,
        },
        {
            text = L("CREATE_VOICE_IN_COLLECTION"),
            func = function()
                if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.OpenNewVoiceInCollection) == "function" then
                    NS.UI.MainFrame:OpenNewVoiceInCollection(key)
                end
            end,
        },
        {
            text = L("CREATE_CHILD_COLLECTION"),
            func = function()
                if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.OpenCollectionNameDialogForGroup) == "function" then
                    NS.UI.MainFrame:OpenCollectionNameDialogForGroup(key)
                end
            end,
        },
        {
            text = L("RENAME_COLLECTION"),
            func = function()
                if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.OpenRenameCollectionDialog) == "function" then
                    NS.UI.MainFrame:OpenRenameCollectionDialog(key)
                end
            end,
        },
        {
            text = L("EXPORT_COLLECTION"),
            func = function()
                if NS.UI and NS.UI.MainFrame and NS.AceOptions and type(NS.AceOptions.ExportCollectionString) == "function" then
                    NS.UI.MainFrame:OpenExportDialog(L("EXPORT_COLLECTION"), NS.AceOptions:ExportCollectionString(key))
                end
            end,
        },
        {
            text = L("DELETE_COLLECTION_WITH_ITEMS"),
            func = function()
                if NS.AceOptions:DeleteCollection(key, true) then
                    if NS.UI and NS.UI.MainFrame and type(NS.UI.MainFrame.RequestRefresh) == "function" then
                        NS.UI.MainFrame:RequestRefresh("list")
                    elseif list then
                        list:RequestRefresh(0)
                    end
                end
            end,
        },
    })
end
