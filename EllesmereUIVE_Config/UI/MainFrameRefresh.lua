local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.MainFrameRefresh = NS.UI.MainFrameRefresh or {}

local Refresh = NS.UI.MainFrameRefresh

local function CallSoon(callback)
    if type(callback) ~= "function" then
        return
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, callback)
    else
        callback()
    end
end

function Refresh:RefreshSavedListOnly(main)
    if not main or not main.frame then
        return
    end

    local ace = NS.AceOptions
    if not ace or type(ace.GetState) ~= "function" then
        return
    end

    local state = ace:GetState()
    if main.summary and type(ace.GetCurrentScopeSummary) == "function" then
        main.summary:SetText(ace:GetCurrentScopeSummary())
    end
    if main.savedList then
        main.savedList:SetSelectedKey(state.selectedKey)
        main.savedList:Refresh()
    end
    self:RefreshActionButtons(main)
end

function Refresh:RefreshActionButtons(main)
    if not main or not main.frame then
        return
    end

    local ace = NS.AceOptions
    local state = ace and type(ace.GetState) == "function" and ace:GetState() or {}
    local hasSelected = tostring(state.selectedKey or "") ~= ""
    if main.editBtn then
        main.editBtn:SetEnabled(hasSelected)
    end
    if main.deleteBtn then
        main.deleteBtn:SetEnabled(hasSelected)
    end
end

function Refresh:RequestRefresh(main, reason)
    if not main then
        return
    end

    reason = tostring(reason or "full")
    if main._refreshPending then
        if reason == "full" then
            main._refreshReason = "full"
        elseif not main._refreshReason then
            main._refreshReason = reason
        end
        return
    end

    main._refreshPending = true
    main._refreshReason = reason
    CallSoon(function()
        main._refreshPending = false
        local pendingReason = tostring(main._refreshReason or "full")
        main._refreshReason = nil
        if pendingReason == "buttons" then
            self:RefreshActionButtons(main)
        else
            -- Both full and list refreshes share the same visible work here, but
            -- queuing them avoids repeated full rebuilds when data-layer and UI
            -- code request a refresh in the same click/drag/import operation.
            self:RefreshSavedListOnly(main)
        end
    end)
end

function Refresh:Refresh(main)
    if not main or not main.frame then
        return
    end
    self:RefreshSavedListOnly(main)
end
