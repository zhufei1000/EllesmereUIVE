EllesmereUIVENS = { UI = {}, SavedListLayout = {}, AceOptions = {} }
local NS = EllesmereUIVENS
local queued, invalidated, rendered = {}, 0, 0
C_Timer = { After = function(_, callback) queued[#queued + 1] = callback end }
function NS.SavedListLayout:InvalidateCache() invalidated = invalidated + 1 end
function NS.AceOptions:GetState() return { selectedKey = "8:62:1" } end
NS.UI.SavedListBuilder = {
    BuildLayout = function() return { { key = "8:62:1" } }, {}, 1, 0 end,
    CountVisibleHeaderItems = function(rows) return #rows end,
}
NS.UI.SavedListRenderer = { RenderEntryRows = function() rendered = rendered + 1; return true end }
assert(loadfile("EllesmereUIVE_Config/UI/SavedListRefresh.lua"))()
local list = {
    frame = { IsShown = function() return true end },
    _cachedLoadedEntries = { { key = "stale" } }, _cachedUnloadedEntries = {},
    _cachedLoadedDisplayCount = 1, _cachedUnloadedDisplayCount = 0,
    _refreshPending = true, _refreshSerial = 3,
}
assert(NS.UI.SavedListRefresh:InvalidateAndRefresh(list))
assert(invalidated == 1 and list._cachedLoadedEntries == nil and list._cachedUnloadedEntries == nil)
assert(list._cachedLoadedDisplayCount == nil and list._cachedUnloadedDisplayCount == nil and list._refreshPending == false)
assert(#queued == 1 and rendered == 0)
queued[1]()
assert(rendered == 1 and list._cachedLoadedEntries[1].key == "8:62:1")
print("SAVED_LIST_IMMEDIATE_REFRESH")
