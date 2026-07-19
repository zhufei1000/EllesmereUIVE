-- LibDataBroker-1.1.lua
-- Lightweight embedded LibDataBroker-compatible implementation for launcher objects.
-- It keeps the standard library name so LibDBIcon-1.0 can consume it, but uses
-- a low minor version so a full external LibDataBroker can replace it.
local MAJOR, MINOR = "LibDataBroker-1.1", 1
local LibStub = _G.LibStub
if not LibStub then error(MAJOR .. " requires LibStub.") end
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.objects = lib.objects or {}
lib.callbacks = lib.callbacks or {}

local function fire(event, ...)
    local list = lib.callbacks[event]
    if not list then return end
    for target, method in pairs(list) do
        if type(method) == "function" then
            pcall(method, target, event, ...)
        elseif type(target) == "table" and type(target[method]) == "function" then
            pcall(target[method], target, event, ...)
        end
    end
end

local object_mt = {
    __newindex = function(t, k, v)
        rawset(t, k, v)
        local name = rawget(t, "__ldb_name")
        if name then
            fire("LibDataBroker_AttributeChanged", name, k, v, t)
            fire("LibDataBroker_AttributeChanged_" .. name, name, k, v, t)
            fire("LibDataBroker_AttributeChanged__" .. k, name, k, v, t)
            fire("LibDataBroker_AttributeChanged_" .. name .. "_" .. k, name, k, v, t)
        end
    end,
}

function lib:NewDataObject(name, dataobj)
    assert(type(name) == "string", "Usage: NewDataObject(name, dataobj)")
    if self.objects[name] then return self.objects[name] end
    dataobj = dataobj or {}
    rawset(dataobj, "__ldb_name", name)
    setmetatable(dataobj, object_mt)
    self.objects[name] = dataobj
    fire("LibDataBroker_DataObjectCreated", name, dataobj)
    return dataobj
end

function lib:GetDataObjectByName(name)
    return self.objects[name]
end

function lib:DataObjectIterator()
    return pairs(self.objects)
end

-- Compatible with normal CallbackHandler-style dot usage:
--   ldb.RegisterCallback(target, "Event", method)
-- Also tolerates accidental colon-style usage:
--   ldb:RegisterCallback(target, "Event", method)
function lib.RegisterCallback(selfOrTarget, eventOrTarget, methodOrEvent, maybeMethod)
    local target, event, method
    if selfOrTarget == lib and type(eventOrTarget) == "table" and type(methodOrEvent) == "string" then
        target, event, method = eventOrTarget, methodOrEvent, maybeMethod
    else
        target, event, method = selfOrTarget, eventOrTarget, methodOrEvent
    end
    if type(event) ~= "string" then return end
    lib.callbacks[event] = lib.callbacks[event] or {}
    lib.callbacks[event][target] = method or event
end

function lib.UnregisterCallback(selfOrTarget, eventOrTarget)
    local target, event
    if selfOrTarget == lib and type(eventOrTarget) == "table" then
        target, event = eventOrTarget, nil
    elseif selfOrTarget == lib and type(eventOrTarget) == "string" then
        target, event = selfOrTarget, eventOrTarget
    else
        target, event = selfOrTarget, eventOrTarget
    end
    if event and lib.callbacks[event] then
        lib.callbacks[event][target] = nil
    end
end

function lib.UnregisterAllCallbacks(target)
    for _, list in pairs(lib.callbacks) do
        list[target] = nil
    end
end
