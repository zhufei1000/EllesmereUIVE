local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.Config = NS.Config or {}
NS.Config.Controller = NS.Config.Controller or {}

function NS.Config.Controller:Refresh()
    if NS.UI and NS.UI.MainFrame then NS.UI.MainFrame:Refresh() end
end
