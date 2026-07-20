local newHarness = assert(loadfile("tests/support/save_test_harness.lua"))()
local nestedAttempts = 0
local context
context = newHarness({ onInject = function()
    nestedAttempts = nestedAttempts + 2
    context.owner.widgets.saveInject.OnClick()
    context.owner.widgets.saveInject.OnClick()
end })
local NS, state = context.NS, context.state
assert(loadfile("EllesmereUIVE_Config/UI/EditorActions.lua"))()
local function Widget()
    return { SetScript = function(self, event, callback) self[event] = callback end, SetEnabled = function(self, value) self.enabled = value end, ClearFocus = function() end }
end
local widgets = {}
for _, key in ipairs({ "close", "actionClose", "tabEUI", "tabCast", "tabBloodlust", "euiTriggerDrop", "soundSourceDrop", "builtinDrop", "sharedMediaDrop", "spellId", "scopeButton", "actionTest", "saveOnly", "saveInject", "actionSave" }) do widgets[key] = Widget() end
local owner = { widgets = widgets }
context.owner = owner
function owner:PullFromWidgets() return state end
function owner:Refresh() end
function owner:Close() self.closed = true end
function owner:SwitchEntryType() end
NS.UI.EditorActions:Install(owner, { widgets = widgets })
widgets.saveInject.OnClick()
assert(nestedAttempts == 2 and context.calls.inject == 1 and context.calls.register == 1)
assert(context.scopeMap(8, 62, false)[1] and context.scopeMap(8, 62, false)[2] == nil)
assert(owner.closed == true and owner._saving == false)
print("SAVE_DOUBLE_CLICK_BLOCKED")
