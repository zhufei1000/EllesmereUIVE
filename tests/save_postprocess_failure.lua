local newHarness = assert(loadfile("tests/support/save_test_harness.lua"))()
local context = newHarness({ injectError = true, refreshError = true })
local NS, state = context.NS, context.state
local ok, status, details = NS.EntryStore:SaveEntry(NS.AceOptions)
assert(ok == true and details and details.committed == true)
assert(status == "saved_inject_failed" and details.injected == false)
local entry = context.scopeMap(8, 62, false)[1]
assert(entry and entry.entryUID == details.entryUID)
assert(state.selectedKey == "8:62:1" and state.editingEntryUID == entry.entryUID)
print("SAVE_POSTPROCESS_FAILURE_OK")

-- A post-commit editor refresh error must not keep the editor open.
context = newHarness({ refreshError = true })
NS, state = context.NS, context.state
assert(loadfile("EllesmereUIVE_Config/UI/EditorActions.lua"))()
local function Widget()
    return { SetScript = function(self, event, callback) self[event] = callback end, SetEnabled = function(self, value) self.enabled = value end, ClearFocus = function() end }
end
local widgets = {}
for _, key in ipairs({ "close", "actionClose", "tabEUI", "tabCast", "tabBloodlust", "euiTriggerDrop", "soundSourceDrop", "builtinDrop", "sharedMediaDrop", "spellId", "scopeButton", "actionTest", "saveOnly", "saveInject", "actionSave" }) do widgets[key] = Widget() end
local owner = { widgets = widgets }
function owner:PullFromWidgets() return state end
function owner:Refresh() end
function owner:Close() self.closed = true end
function owner:SwitchEntryType() end
NS.UI.EditorActions:Install(owner, { widgets = widgets })
widgets.saveInject.OnClick()
assert(owner.closed == true and context.scopeMap(8, 62, false)[1])
print("EDITOR_CLOSES_AFTER_POSTPROCESS_FAILURE")
