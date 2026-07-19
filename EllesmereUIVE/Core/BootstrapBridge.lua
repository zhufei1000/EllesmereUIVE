local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.Core = NS.Core or {}
NS.Core.BootstrapBridge = NS.Core.BootstrapBridge or {}
local Bridge = NS.Core.BootstrapBridge

local function API()
    local api = rawget(_G, "EllesmereUIVEBootstrapAPI")
    return type(api) == "table" and api or nil
end

local function Call(name, ...)
    local api = API()
    local method = api and api[name]
    if type(method) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(method, ...)
    if not ok then return nil end
    return a, b, c, d
end

function Bridge:IsSoundRegisteredBeforeEUI(soundKey) return Call("IsSoundRegisteredBeforeEUI", soundKey) == true end
function Bridge:WasDatabasePreseededBeforeCDM() return Call("WasDatabasePreseededBeforeCDM") == true end
function Bridge:IsCDMLoaded() return Call("IsCDMLoaded") == true end
function Bridge:IsFamilyArmed(family) return Call("IsFamilyArmed", family) == true end
function Bridge:ResolveBundledSoundKey(path) return Call("ResolveBundledSoundKey", path) end
function Bridge:ResolveCustomSoundKey(path) return Call("ResolveCustomSoundKey", path) end
function Bridge:RegisterSavedEntry(entry) return Call("RegisterSavedEntry", entry) end
function Bridge:RegisterAllSavedEntries() return Call("RegisterAllSavedEntries") end
function Bridge:PreseedEntry(entry, classID, specID) return Call("PreseedEntry", entry, classID, specID) end
function Bridge:PreseedCurrentScope() return Call("PreseedCurrentScope") end
function Bridge:GetRuntimeStatus() return Call("GetRuntimeStatus") or {} end
function Bridge:NormalizePath(path) return Call("NormalizePath", path) or tostring(path or "") end
