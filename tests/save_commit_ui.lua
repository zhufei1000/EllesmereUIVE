local newHarness = assert(loadfile("tests/support/save_test_harness.lua"))()
local context = newHarness()
local NS, state, calls = context.NS, context.state, context.calls

local ok, status, details = NS.EntryStore:SaveEntry(NS.AceOptions)
assert(ok and status == "saved_and_injected")
assert(details and details.committed == true and details.injected == true)
assert(context.scopeMap(8, 62, false)[1].entryUID == details.entryUID)
assert(state.selectedKey == "8:62:1" and state.editingEntryUID == details.entryUID)
assert(calls.legacy == 0 and calls.cast == 0)
print("SAVE_COMMIT_OK")
print("NO_LEGACY_CD_RUNTIME_ON_EUI_SAVE")

local noLegacyContext = newHarness()
noLegacyContext.NS.API.RebuildRuntimeConfig = nil
noLegacyContext.NS.API.RebuildCustomConfig = nil
noLegacyContext.NS.API.RefreshRuntimeCooldowns = nil
local noLegacyOK, _, noLegacyDetails = noLegacyContext.NS.EntryStore:SaveEntry(noLegacyContext.NS.AceOptions)
assert(noLegacyOK and noLegacyDetails.committed == true and noLegacyContext.scopeMap(8, 62, false)[1])

-- Exercise the editor success path independently with a fresh database.
context = newHarness()
NS, state, calls = context.NS, context.state, context.calls
assert(loadfile("EllesmereUIVE_Config/UI/EditorActions.lua"))()
local function Widget()
    return {
        SetScript = function(self, event, callback) self[event] = callback end,
        SetEnabled = function(self, enabled) self.enabled = enabled end,
        ClearFocus = function() end,
    }
end
local widgets = {}
for _, key in ipairs({ "close", "actionClose", "tabEUI", "tabCast", "tabBloodlust", "euiTriggerDrop", "soundSourceDrop", "builtinDrop", "sharedMediaDrop", "spellId", "scopeButton", "actionTest", "saveOnly", "saveInject", "actionSave" }) do
    widgets[key] = Widget()
end
local owner = { widgets = widgets, closed = false }
function owner:PullFromWidgets() return state end
function owner:Refresh() end
function owner:Close() self.closed = true end
function owner:SwitchEntryType() end
NS.UI.EditorActions:Install(owner, { widgets = widgets })
widgets.saveInject.OnClick()
assert(owner.closed == true and owner._saving == false)
assert(widgets.saveOnly.enabled == true and widgets.saveInject.enabled == true and widgets.actionSave.enabled == true)
assert(calls.list >= 1 and calls.lastRefreshReason == "list" and calls.lastRefreshDelay == 0)
print("EDITOR_CLOSES_AFTER_SAVE")
