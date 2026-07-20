local classes = {
    { id = 1, name = "Warrior", specs = { 71, 72 } },
    { id = 6, name = "Death Knight", specs = { 250, 251, 252 } },
    { id = 8, name = "Mage", specs = { 62, 63, 64 } },
}

function GetNumClasses() return #classes end
function GetClassInfo(index)
    local value = classes[index]
    return value and value.name, value and value.name:upper(), value and value.id
end
function GetNumSpecializationsForClassID(classID)
    for _, value in ipairs(classes) do if value.id == classID then return #value.specs end end
    return 0
end
function GetSpecializationInfoForClassID(classID, index)
    for _, value in ipairs(classes) do if value.id == classID then return value.specs[index] end end
end

EllesmereUIVENS = { Core = {}, UI = { Widgets = {}, WidgetUtils = {} } }
function EllesmereUIVENS:GetCurrentClassSpec() return 8, 62 end
assert(loadfile("EllesmereUIVE/Core/ScopeResolver.lua"))()
local resolver = EllesmereUIVENS.Core.ScopeResolver

local all = resolver:ResolveTargets({ [0] = true }, { [0] = true })
assert(#all == 8)

local dk = resolver:ResolveTargets({ [6] = true }, { [0] = true })
assert(#dk == 3)
for _, target in ipairs(dk) do assert(target.classID == 6) end

local frost = resolver:ResolveTargets({ [6] = true }, { [251] = true })
assert(#frost == 1 and frost[1].classID == 6 and frost[1].specID == 251)

local validMixed = resolver:ResolveTargets({ [6] = true, [8] = true }, { [251] = true, [62] = true })
assert(#validMixed == 2)
assert(validMixed[1].classID == 6 and validMixed[1].specID == 251)
assert(validMixed[2].classID == 8 and validMixed[2].specID == 62)

local classID, specID = resolver:ResolveStorageScope({ [6] = true }, { [0] = true })
assert(classID == 6 and specID == 0)
classID, specID = resolver:ResolveStorageScope({ [6] = true }, { [251] = true })
assert(classID == 6 and specID == 251)
classID, specID = resolver:ResolveStorageScope({ [6] = true, [8] = true }, { [251] = true, [62] = true })
assert(classID == 0 and specID == 0)

local dkOnly = { alertClassIDs = { [6] = true }, alertSpecIDs = { [0] = true }, alertRaceIDs = { [0] = true } }
assert(resolver:EntryMatchesScope(dkOnly, 6, 251, 1))
assert(not resolver:EntryMatchesScope(dkOnly, 8, 62, 1))
local legacy = { customClassIDs = { [8] = true }, customSpecIDs = { [62] = true } }
assert(resolver:EntryMatchesScope(legacy, 8, 62, 1))
local legacyWithEmptyNewMaps = { alertClassIDs = {}, alertSpecIDs = {}, customClassIDs = { [6] = true }, customSpecIDs = { [251] = true } }
assert(resolver:EntryMatchesScope(legacyWithEmptyNewMaps, 6, 251, 1))
assert(not resolver:EntryMatchesScope(legacyWithEmptyNewMaps, 8, 62, 1))

assert(loadfile("EllesmereUIVE_Config/UI/WidgetDropdownPopup.lua"))()
local popup = EllesmereUIVENS.UI.WidgetDropdownPopup
local items = {
    { value = "Interface\\AddOns\\EllesmereUIVE\\Media\\Sounds\\AirHorn.ogg", text = "|cff00ff00AirHorn|r", searchText = "AirHorn Interface\\AddOns\\EllesmereUIVE\\Media\\Sounds\\AirHorn.ogg AirHorn.ogg" },
    { value = "Bell", text = "|Ticon:12|t Bell" },
}
local matches = popup.FilterItems(items, "AIR")
assert(#matches == 1 and matches[1].originalIndex == 1 and matches[1].item.value:find("AirHorn.ogg", 1, true))
assert(#popup.FilterItems(items, "horn.ogg") == 1)
assert(#popup.FilterItems(items, "interface\\addons") == 1)
assert(#popup.FilterItems(items, "bell") == 1)
assert(#popup.FilterItems(items, "") == 2)
assert(#popup.FilterItems(items, "missing") == 0)

print("SCOPE_AND_SEARCH_OK")
