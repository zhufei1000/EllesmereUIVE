local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.Core = NS.Core or {}
NS.Core.CastSuccessSchedulerBridge = NS.Core.CastSuccessSchedulerBridge or {}
local Bridge = NS.Core.CastSuccessSchedulerBridge

function Bridge:Queue(triggerSpellID, cfg, playCallback)
    return NS.Core.CastSuccessScheduler:Queue(triggerSpellID, cfg, playCallback)
end

function Bridge:Cancel(triggerSpellID)
    return NS.Core.CastSuccessScheduler:Cancel(triggerSpellID)
end

function Bridge:ClearAll()
    return NS.Core.CastSuccessScheduler:ClearAll()
end
