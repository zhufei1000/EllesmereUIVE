local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.MainFrame = NS.UI.MainFrame or {}

local MainFrame = NS.UI.MainFrame
local MainFrameRefresh = NS.UI.MainFrameRefresh or {}
local MainFrameLocale = NS.UI.MainFrameLocale or {}


-- Refresh coalescing and list-only refresh logic lives in UI/MainFrameRefresh.lua.



function MainFrame:EnsureFrame()
    if NS.UI and NS.UI.MainFrameBuilder and type(NS.UI.MainFrameBuilder.EnsureFrame) == "function" then
        return NS.UI.MainFrameBuilder:EnsureFrame(self)
    end
    return self.frame
end


-- Collection and import/export dialogs live in UI/MainFrameDialogs.lua.

function MainFrame:SetSelectedKey(key)
    self:EnsureFrame()
    self.savedList:SetSelectedKey(key)
    NS.AceOptions:GetState().selectedKey = key
end

function MainFrame:GetSelectedKey()
    if not self.savedList then
        return nil
    end
    return self.savedList:GetSelectedKey()
end

function MainFrame:RefreshLocale()
    if MainFrameLocale and type(MainFrameLocale.RefreshLocale) == "function" then
        return MainFrameLocale:RefreshLocale(self)
    end
end


function MainFrame:RefreshActionButtons()
    if MainFrameRefresh and type(MainFrameRefresh.RefreshActionButtons) == "function" then
        return MainFrameRefresh:RefreshActionButtons(self)
    end
end

function MainFrame:RequestRefresh(reason, delay)
    if tostring(reason or "") == "list" and delay ~= nil and self.savedList then
        local savedListRefresh = NS.UI and NS.UI.SavedListRefresh
        local ace = NS.AceOptions
        local state = ace and type(ace.GetState) == "function" and ace:GetState() or nil
        if state and type(self.savedList.SetSelectedKey) == "function" then
            self.savedList:SetSelectedKey(state.selectedKey)
        end
        if savedListRefresh and type(savedListRefresh.InvalidateAndRefresh) == "function" then
            local refreshed = savedListRefresh:InvalidateAndRefresh(self.savedList)
            self:RefreshActionButtons()
            return refreshed
        end
    end
    if MainFrameRefresh and type(MainFrameRefresh.RequestRefresh) == "function" then
        return MainFrameRefresh:RequestRefresh(self, reason)
    end
    return self:Refresh()
end

function MainFrame:Refresh()
    if MainFrameRefresh and type(MainFrameRefresh.Refresh) == "function" then
        return MainFrameRefresh:Refresh(self)
    end
end

function MainFrame:Open()
    local frame = self:EnsureFrame()
    NS.AceOptions:SyncScopeToCurrentSpec()
    NS.AceOptions:EnsureValidScope()
    self:Refresh()
    frame:Show()
    frame:Raise()
    if collectgarbage then
        collectgarbage("step", 96)
    end
    return true
end

function MainFrame:Close()
    if self.frame then
        self.frame:Hide()
    end
    if NS.UI and NS.UI.EditorFrame then
        NS.UI.EditorFrame:Close()
    end
end

function MainFrame:Toggle()
    local frame = self:EnsureFrame()
    if frame and frame:IsShown() then
        self:Close()
    else
        self:Open()
    end
end
