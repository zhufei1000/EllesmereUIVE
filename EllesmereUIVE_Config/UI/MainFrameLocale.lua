local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.MainFrame = NS.UI.MainFrame or {}
NS.UI.MainFrameLocale = NS.UI.MainFrameLocale or {}

local MainFrameLocale = NS.UI.MainFrameLocale
local Widgets = NS.UI.Widgets
local L = NS.L or function(key, ...) if select("#", ...) > 0 then return string.format(tostring(key), ...) end return tostring(key) end

function MainFrameLocale:BuildLanguageItems()
    return {
        { value = "auto", text = L("LANGUAGE_AUTO") },
        { value = "zhCN", text = L("LANGUAGE_ZHCN") },
        { value = "zhTW", text = L("LANGUAGE_ZHTW") },
        { value = "enUS", text = L("LANGUAGE_ENUS") },
    }
end

function MainFrameLocale:RefreshLocale(mainFrame)
    if not mainFrame or not mainFrame.frame then
        return false
    end

    if mainFrame.headerTitle then
        mainFrame.headerTitle:SetText(NS.ADDON_DISPLAY_NAME or L("ADDON_DISPLAY_NAME"))
    end
    if type(mainFrame.layoutHeader) == "function" then
        mainFrame.layoutHeader()
    end

    if mainFrame.languageLabel then
        mainFrame.languageLabel:SetText(L("LABEL_LANGUAGE"))
    end
    if mainFrame.languageDrop and Widgets then
        Widgets:SetDropdownItems(mainFrame.languageDrop, self:BuildLanguageItems())
        Widgets:SetDropdownValue(mainFrame.languageDrop, NS.GetLanguageMode and NS.GetLanguageMode() or "auto", L("LANGUAGE_AUTO"))
    end

    if mainFrame.addBtn then mainFrame.addBtn:SetText(L("BTN_ADD_VOICE")) end
    if mainFrame.addGroupBtn then mainFrame.addGroupBtn:SetText(L("BTN_ADD_COLLECTION")) end
    if mainFrame.editBtn then mainFrame.editBtn:SetText(L("BTN_EDIT")) end
    if mainFrame.deleteBtn then mainFrame.deleteBtn:SetText(L("BTN_DELETE")) end
    if mainFrame.refreshBtn then mainFrame.refreshBtn:SetText(L("BTN_REFRESH")) end
    if mainFrame.syncBtn then mainFrame.syncBtn:SetText(L("BTN_SYNC_CURRENT_SPEC")) end
    if mainFrame.importBtn then mainFrame.importBtn:SetText(L("BTN_IMPORT")) end
    if mainFrame.exportAllBtn then mainFrame.exportAllBtn:SetText(L("BTN_EXPORT_FULL")) end
    if type(mainFrame.layoutToolbar) == "function" then
        mainFrame.layoutToolbar()
    end

    if NS.Core and NS.Core.ConfigPanel and type(NS.Core.ConfigPanel.Refresh) == "function" then
        NS.Core.ConfigPanel:Refresh()
    end
    -- 编辑弹窗同步刷新文案，但不重置输入框，避免切换语言时丢失尚未保存的内容。
    if NS.UI and NS.UI.EditorFrame and type(NS.UI.EditorFrame.RefreshLocale) == "function" then
        NS.UI.EditorFrame:RefreshLocale()
    end
    if type(mainFrame.Refresh) == "function" then
        mainFrame:Refresh()
    end
    return true
end
