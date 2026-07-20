local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.ImportRefreshScheduler = NS.ImportRefreshScheduler or {}
local Scheduler = NS.ImportRefreshScheduler

local pendingToken = 0
local pendingReason

local function RunSoon(callback)
    if type(callback) ~= "function" then
        return
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, callback)
    else
        callback()
    end
end

local function SafeCall(api, method)
    if api and type(api[method]) == "function" then
        return api[method]()
    end
    return nil
end

function Scheduler:Schedule(reason)
    pendingToken = pendingToken + 1
    local token = pendingToken
    pendingReason = tostring(reason or "import")

    local function stillCurrent()
        return token == pendingToken
    end

    -- Split expensive post-import work across frames. Import itself writes data
    -- immediately; rebuilding runtime tables and refreshing the visible list is
    -- deferred so the import click does not freeze the UI for large payloads.
    local function rebuildRuntime()
        RunSoon(function()
            if not stillCurrent() then return end
            local api = NS.API
            SafeCall(api, "RebuildRuntimeConfig")
            if api and type(api.RebuildCastSuccessConfig) == "function" then
                api.RebuildCastSuccessConfig()
            end
            if api and type(api.RebuildCustomConfig) == "function" then
                api.RebuildCustomConfig()
            end

            RunSoon(function()
                if not stillCurrent() then return end
                api = NS.API
                SafeCall(api, "RefreshRuntimeCooldowns")
                if api and type(api.RebuildBloodlustConfig) == "function" then
                    api.RebuildBloodlustConfig()
                end

                RunSoon(function()
                    if not stillCurrent() then return end
                    local main = NS.UI and NS.UI.MainFrame
                    if main and type(main.RequestRefresh) == "function" then
                        main:RequestRefresh("list")
                    else
                        api = NS.API
                        if api and type(api.RefreshPanel) == "function" then
                            api.RefreshPanel()
                        end
                    end
                    pendingReason = nil
                end)
            end)
        end)
    end

    RunSoon(function()
        if not stillCurrent() then return end
        local queue = NS.ItemResolveQueue or (NS.Core and NS.Core.ItemResolveQueue)
        if queue and type(queue.ResolveAllStoredBatched) == "function" then
            queue:ResolveAllStoredBatched(true, function()
                if stillCurrent() then
                    rebuildRuntime()
                end
            end, 24)
            return
        end

        local api = NS.API
        if api and type(api.ResolveAllStoredItemTriggers) == "function" then
            api.ResolveAllStoredItemTriggers(true)
        end
        rebuildRuntime()
    end)
end

function Scheduler:Cancel()
    pendingToken = pendingToken + 1
    pendingReason = nil
end

function Scheduler:IsPending()
    return pendingReason ~= nil
end
