-- Standalone Lua smoke test for the load-on-demand configuration modules.
-- It supplies only the small WoW API surface needed to build the frames and
-- exercise the shared saved-list/collection store.

function wipe(value) for key in pairs(value) do value[key] = nil end return value end
function CreateColor(r, g, b, a) return { GetRGBA = function() return r, g, b, a end } end
tinsert, UISpecialFrames = table.insert, {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

local function Object(name)
    local object = { _name = name, _shown = true, _enabled = true, _text = "", _children = {} }
    return setmetatable(object, { __index = function(self, key)
        if key == "CreateTexture" or key == "CreateFontString" then
            return function(parent, childName)
                local child = Object(childName)
                parent._children[#parent._children + 1] = child
                return child
            end
        end
        local methods = {
            GetName = function(frame) return frame._name end,
            SetText = function(frame, text) frame._text = tostring(text or "") end,
            GetText = function(frame) return frame._text end,
            GetStringWidth = function(frame) return #(frame._text or "") * 7 end,
            GetFontString = function(frame) frame._font = frame._font or Object(); return frame._font end,
            SetScript = function(frame, event, callback) frame["_script_" .. event] = callback end,
            HookScript = function(frame, event, callback) frame["_script_" .. event] = callback end,
            GetScript = function(frame, event) return frame["_script_" .. event] end,
            Show = function(frame) frame._shown = true end,
            Hide = function(frame) frame._shown = false end,
            SetShown = function(frame, shown) frame._shown = shown == true end,
            IsShown = function(frame) return frame._shown end,
            SetEnabled = function(frame, enabled) frame._enabled = enabled == true end,
            Enable = function(frame) frame._enabled = true end,
            Disable = function(frame) frame._enabled = false end,
            IsEnabled = function(frame) return frame._enabled end,
            SetChecked = function(frame, checked) frame._checked = checked == true end,
            GetChecked = function(frame) return frame._checked == true end,
            SetValue = function(frame, value) frame._value = value end,
            GetValue = function(frame) return frame._value end,
            GetChildren = function(frame) return table.unpack(frame._children) end,
            GetNumChildren = function(frame) return #frame._children end,
            GetRegions = function() return nil end,
            GetFrameLevel = function() return 1 end,
            GetWidth = function() return 800 end, GetRight = function() return 800 end,
            GetHeight = function() return 600 end, GetTop = function() return 600 end,
            GetLeft = function() return 0 end, GetBottom = function() return 0 end,
            GetVerticalScrollRange = function() return 0 end,
            GetVerticalScroll = function() return 0 end,
            GetEffectiveScale = function() return 1 end,
            IsMouseOver = function() return false end,
            GetObjectType = function() return "Frame" end,
        }
        if methods[key] then return methods[key] end
        if type(key) == "string" and key:match("^[A-Z]") then return function() end end
    end })
end

function CreateFrame(_, name, parent)
    local frame = Object(name)
    if parent and parent._children then parent._children[#parent._children + 1] = frame end
    return frame
end

UIParent = Object("UIParent")
function GetLocale() return "enUS" end
function UnitClass() return "Mage", "MAGE", 8 end
function GetSpecialization() return 1 end
function GetNumClasses() return 1 end
function GetClassInfo() return "Mage", "MAGE", 8 end
function GetNumSpecializationsForClassID() return 1 end
function GetSpecializationInfoForClassID() return 62, "Arcane", nil, 135932 end
function InCombatLockdown() return false end
function UnitAffectingCombat() return false end
function GetCursorPosition() return 0, 0 end
function MouseIsOver() return false end
function PlaySoundFile() return true end
function CloseDropDownMenus() end
function hooksecurefunc() end
C_Timer = { After = function(_, callback) callback() end }
C_SpecializationInfo = { GetSpecializationInfo = function() return 62, "Arcane" end }
C_Spell = {
    GetSpellName = function(id) return "Spell" .. tostring(id) end,
    GetSpellTexture = function() return 134400 end,
    GetSpellBaseCooldown = function() return 0 end,
}
C_Item = {
    GetItemNameByID = function(id) return "Item" .. tostring(id) end,
    GetItemIconByID = function() return 134400 end,
}
C_CreatureInfo = { GetRaceInfo = function() return { raceName = "Human" } end }

EllesmereUIVEDB = {
    specConfigs = {}, collectionData = {}, savedListOrder = {}, bloodlust = {},
    settings = { autoInjectOnSave = true, overwriteEUI = false },
    euiInjectionRecords = {}, entrySerial = 0,
}
EllesmereUIVENS = { Constants = {
    DEFAULT_SOUND = "Interface\\AddOns\\EllesmereUIVE\\Media\\Sounds\\AirHorn.ogg",
}, Core = {} }
local NS = EllesmereUIVENS
function NS:GetCurrentClassSpec() return 8, 62 end
function NS:GetScopeList(classID, specID, create)
    classID, specID = tonumber(classID) or 0, tonumber(specID) or 0
    if create then
        EllesmereUIVEDB.specConfigs[classID] = EllesmereUIVEDB.specConfigs[classID] or {}
        EllesmereUIVEDB.specConfigs[classID][specID] = EllesmereUIVEDB.specConfigs[classID][specID] or {}
    end
    return EllesmereUIVEDB.specConfigs[classID] and EllesmereUIVEDB.specConfigs[classID][specID] or {}
end
function NS:FindEntryScope(entry)
    for classID, classMap in pairs(EllesmereUIVEDB.specConfigs) do
        for specID, entries in pairs(classMap) do
            for _, current in pairs(entries) do if current == entry then return classID, specID end end
        end
    end
end
function NS:Print() end
function NS:RebuildVoiceRuntime() end
function NS:SnapshotEntry(entry) return entry end
function NS:QueueEUIRemoval() end
function NS:RequestEUISync(_, callback)
    if callback then callback({}, "complete", { injected = 0, upToDate = 0, waiting = 0, reloadRequired = 0, conflict = 0, invalidSound = 0, unsupported = 0 }) end
    return true
end
NS.Core.Database = {
    NextEntryUID = function() EllesmereUIVEDB.entrySerial = EllesmereUIVEDB.entrySerial + 1; return string.format("%08d", EllesmereUIVEDB.entrySerial) end,
    NormalizeEUITarget = function(_, entry) entry.euiTargetMode, entry.euiTargetFamily = "auto", "auto" end,
    DeepCopy = function(value, seen)
        if type(value) ~= "table" then return value end
        seen = seen or {}
        if seen[value] then return seen[value] end
        local copy = {}; seen[value] = copy
        for key, child in pairs(value) do copy[NS.Core.Database.DeepCopy(key, seen)] = NS.Core.Database.DeepCopy(child, seen) end
        return copy
    end,
}
NS.Core.VoicePlayer = { PreviewSound = function() return true end, NotifyCastSuccess = function() return true end, NotifyBloodlust = function() return true end }
NS.Core.CastSuccessScheduler = { Queue = function() return true end, ClearAll = function() end }
NS.Core.EUISoundRegistry = { RegisterEntry = function() return true end, RegisterAllSavedEntries = function() return 0, 0 end }
NS.Integrations = { EllesmereUI = {
    GetInjectionStatus = function() return "saved_waiting_sync" end,
    RemoveEntry = function() return true, "removed", false end,
    RemoveEntryFromAllRecordedScopes = function() return true, "removed", false end,
} }

local toc = assert(io.open("EllesmereUIVE_Config/EllesmereUIVE_Config.toc", "r"))
for line in toc:lines() do
    line = line:match("^%s*(.-)%s*$")
    if line:match("%.lua$") and not line:match("LibDeflate") and not line:match("AceSerializer") then
        assert(loadfile("EllesmereUIVE_Config/" .. line:gsub("\\", "/")))()
    end
end
toc:close()
assert(loadfile("EllesmereUIVE/Core/ImportExport.lua"))()

assert(NS.UI.MainFrame:Open())
NS.UI.EditorFrame:OpenForNew("euiVoice")
assert(NS.UI.EditorFrame.frame:GetName() == "EllesmereUIVEEditorFrame")
assert(NS.UI.EditorFrame.frame.widgets.classDrop == nil and NS.UI.EditorFrame.frame.widgets.specDrop == nil)
assert(NS.UI.EditorFrame.frame.widgets.builtinDrop.qfxsaSearchable == true)
assert(NS.UI.EditorFrame.frame.widgets.sharedMediaDrop.qfxsaSearchable == true)
assert(NS.UI.EditorFrame.frame.widgets.soundSourceDrop.qfxsaSearchable == false)
assert(NS.UI.EditorFrame.frame.widgets.euiTriggerDrop.qfxsaSearchable == false)

local state = NS.AceOptions:GetState()
state.classID, state.specID = 8, 62
state.alertClassIDs, state.alertSpecIDs, state.alertRaceIDs = { [8] = true }, { [62] = true }, { [0] = true }
NS.UI.EditorFrame:PullFromWidgets()
assert(state.alertClassIDs[8] == true and next(state.alertClassIDs, 8) == nil)
assert(state.alertSpecIDs[62] == true and next(state.alertSpecIDs, 62) == nil)
assert(state.alertRaceIDs[0] == true and next(state.alertRaceIDs, 0) == nil)
assert(NS.AceOptions:CreateCollection("Mixed", nil, nil, true))
local groupKey = state.selectedCollectionKey

state.entryType, state.spellId, state.spellName = "euiVoice", 12345, "EUI Voice"
state.euiTriggerType, state.voiceEnabled = "buffGain", true
state.soundSource, state.notifyMode = "builtin", "sound"
state.builtinSoundPath, state.soundPath = NS.AceOptions:GetDefaultBuiltinSoundPath(), NS.AceOptions:GetDefaultBuiltinSoundPath()
state.imageEnabled, state.textEnabled, state.injectOnSave = false, false, false
assert(NS.AceOptions:SaveEntry())

state.selectedKey, state.selectedCollectionKey = groupKey, groupKey
state.entryType, state.spellId, state.spellName = "cast", 67890, "Cast Voice"
state.euiTriggerType, state.voiceEnabled = nil, true
state.delayEnabled, state.delaySeconds = true, 0.5
assert(NS.AceOptions:SaveEntry())

local entries = NS:GetScopeList(8, 62, false)
assert(entries[1].entryType == "euiVoice" and entries[1].euiTriggerType == "buffGain")
assert(entries[2].entryType == "cast")
local scope = EllesmereUIVEDB.collectionData[8][62]
local groupID = groupKey:match("[^:]+$")
assert(#scope.groups[groupID].entries == 2)
assert(#NS.AceOptions:GetSavedListLayoutForScope(8, 62, true) >= 3)

-- A collection export must contain only that collection, then remap both
-- mixed entry types back into valid keys when imported into a fresh scope.
entries[3] = { entryType = "cast", spellId = 77777, triggerSpellID = 77777, soundSource = "builtin", notifyMode = "sound", enabled = true }
local payload = assert(NS.Core.ImportExport:BuildCollectionPayload(8, 62, groupID))
assert(#payload.euiVoiceEntries == 1 and #payload.castEntries == 1)
assert(payload.collectionGroups[groupID] and payload.collectionRootGroupID == groupID)
EllesmereUIVEDB.specConfigs[8][62] = {}
EllesmereUIVEDB.collectionData[8][62] = { root = {}, groups = {} }
local imported, count = NS.Core.ImportExport:ImportPayload(payload)
assert(imported and count == 2)
local importedScope = EllesmereUIVEDB.collectionData[8][62]
local importedGroupID = importedScope.root[1].id
assert(#importedScope.groups[importedGroupID].entries == 2)
assert(NS:GetScopeList(8, 62, false)[1].entryType == "euiVoice")
assert(NS:GetScopeList(8, 62, false)[2].entryType == "cast")

-- Full exports preserve sparse entry indices so collection/order references
-- remain stable after replacement import.
local importedEntries = NS:GetScopeList(8, 62, false)
importedEntries[4], importedEntries[2] = importedEntries[2], nil
importedScope.groups[importedGroupID].entries[2] = "8:62:4"
local fullPayload = NS.Core.ImportExport:BuildPayload()
local fullOK, fullCount = NS.Core.ImportExport:ImportPayload(fullPayload)
assert(fullOK and fullCount == 2)
assert(NS:GetScopeList(8, 62, false)[1].entryType == "euiVoice")
assert(NS:GetScopeList(8, 62, false)[4].entryType == "cast")
local fullScope = EllesmereUIVEDB.collectionData[8][62]
assert(fullScope.groups[importedGroupID].entries[2] == "8:62:4")
print("CONFIG_UI_SMOKE_OK")
