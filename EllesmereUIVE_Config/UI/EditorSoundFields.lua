local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.EditorSoundFields = NS.UI.EditorSoundFields or {}
local SoundFields = NS.UI.EditorSoundFields

local L = NS.L or function(key) return tostring(key) end

local function SortedItems(map)
    local items = {}
    for value, text in pairs(type(map) == "table" and map or {}) do
        items[#items + 1] = { value = value, text = tostring(text or value) }
    end
    table.sort(items, function(a, b) return a.text:lower() < b.text:lower() end)
    return items
end

local function FileName(path)
    return tostring(path or ""):gsub("/", "\\"):match("([^\\]+)$") or tostring(path or "")
end

function SoundFields:GetSourceItems(allowTTS)
    local items = {
        { value = "builtin", text = L("LABEL_BUILTIN_SOUND") },
        { value = "sharedmedia", text = "LibSharedMedia" },
        { value = "custom", text = L("LABEL_CUSTOM_SOUND_PATH") },
    }
    if allowTTS then items[#items + 1] = { value = "tts", text = L("LABEL_TTS_TEXT") } end
    return items
end

function SoundFields:GetBuiltinItems()
    local items = SortedItems(NS.AceOptions and NS.AceOptions:GetBuiltinSoundList() or {})
    for _, item in ipairs(items) do
        item.searchText = table.concat({ tostring(item.text or ""), tostring(item.value or ""), FileName(item.value) }, " ")
    end
    return items
end

function SoundFields:GetSharedMediaItems()
    local source = NS.AceOptions and NS.AceOptions:GetSharedMediaSoundList() or {}
    local names = {}
    for name in pairs(source) do names[name] = name end
    local items = SortedItems(names)
    for _, item in ipairs(items) do item.searchText = tostring(item.text or "") .. " " .. tostring(item.value or "") end
    return items
end

function SoundFields:Resolve(state)
    return NS.AceOptions:ResolveSoundSourceFields(state, "tts", "sound")
end
