local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.Core = NS.Core or {}
NS.Core.CastSuccessScheduler = NS.Core.CastSuccessScheduler or {}
local Scheduler = NS.Core.CastSuccessScheduler
local timers = {}

local function RemoveTimer(triggerSpellID, timer)
    local list = timers[triggerSpellID]
    if not list then return end
    for index = #list, 1, -1 do if list[index] == timer then table.remove(list, index) end end
    if #list == 0 then timers[triggerSpellID] = nil end
end

function Scheduler:Queue(triggerSpellID, cfg, playCallback)
    triggerSpellID = tonumber(triggerSpellID)
    if not triggerSpellID or type(cfg) ~= "table" or type(playCallback) ~= "function" then return false end
    local delay = cfg.delayEnabled == true and math.max(0, tonumber(cfg.delaySeconds) or 0) or 0
    if delay <= 0 or not (C_Timer and C_Timer.NewTimer) then
        playCallback(cfg, triggerSpellID)
        return true
    end
    local timer
    timer = C_Timer.NewTimer(delay, function()
        RemoveTimer(triggerSpellID, timer)
        playCallback(cfg, triggerSpellID)
    end)
    timers[triggerSpellID] = timers[triggerSpellID] or {}
    timers[triggerSpellID][#timers[triggerSpellID] + 1] = timer
    return true
end

function Scheduler:Cancel(triggerSpellID)
    triggerSpellID = tonumber(triggerSpellID)
    local list = triggerSpellID and timers[triggerSpellID]
    if not list then return false end
    for _, timer in ipairs(list) do if timer and timer.Cancel then timer:Cancel() end end
    timers[triggerSpellID] = nil
    return true
end

function Scheduler:ClearAll()
    for triggerSpellID in pairs(timers) do self:Cancel(triggerSpellID) end
end
