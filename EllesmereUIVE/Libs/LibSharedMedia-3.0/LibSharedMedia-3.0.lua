--[[
Name: LibSharedMedia-3.0
Revision: embedded v12.0.0-r167
Author: Elkano (elkano@gmx.de)
Inspired By: SurfaceLib by Haste/Otravi (troeks@gmail.com)
Website: https://www.wowace.com/projects/libsharedmedia-3-0
Description: Shared handling of media data (fonts, sounds, textures, ...) between addons.
Dependencies: LibStub, CallbackHandler-1.0
License: LGPL v2.1
]]

local MAJOR, MINOR = "LibSharedMedia-3.0", 90000 + 167
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

local _G = getfenv(0)
local pairs = _G.pairs
local type = _G.type
local error = _G.error
local tostring = _G.tostring
local table_sort = _G.table.sort
local locale = GetLocale()
local bitlib = _G.bit or _G.bit32
local band = bitlib and bitlib.band or function() return 0 end

local locale_is_western
local LOCALE_MASK = 0

lib.LOCALE_BIT_koKR = 1
lib.LOCALE_BIT_ruRU = 2
lib.LOCALE_BIT_zhCN = 4
lib.LOCALE_BIT_zhTW = 8
lib.LOCALE_BIT_western = 128

local CallbackHandler = LibStub:GetLibrary("CallbackHandler-1.0")
lib.callbacks = lib.callbacks or CallbackHandler:New(lib)
lib.DefaultMedia = lib.DefaultMedia or {}
lib.MediaList = lib.MediaList or {}
lib.MediaTable = lib.MediaTable or {}
lib.MediaType = lib.MediaType or {}
lib.OverrideMedia = lib.OverrideMedia or {}

local defaultMedia = lib.DefaultMedia
local mediaList = lib.MediaList
local mediaTable = lib.MediaTable
local overrideMedia = lib.OverrideMedia

lib.MediaType.BACKGROUND = "background"
lib.MediaType.BORDER = "border"
lib.MediaType.FONT = "font"
lib.MediaType.STATUSBAR = "statusbar"
lib.MediaType.SOUND = "sound"

local function ensureTable(mediatype)
    if not mediaTable[mediatype] then
        mediaTable[mediatype] = {}
    end
    return mediaTable[mediatype]
end

local bg = ensureTable("background")
bg["Blizzard Dialog Background"] = [[Interface\DialogFrame\UI-DialogBox-Background]]
bg["Blizzard Low Health"] = [[Interface\FullScreenTextures\LowHealth]]
bg["Blizzard Out of Control"] = [[Interface\FullScreenTextures\OutOfControl]]
bg["Blizzard Parchment"] = [[Interface\AchievementFrame\UI-Achievement-Parchment-Horizontal]]
bg["Blizzard Parchment 2"] = [[Interface\AchievementFrame\UI-Achievement-Parchment]]
bg["Blizzard Tabard Background"] = [[Interface\TabardFrame\TabardFrameBackground]]
bg["Blizzard Tooltip"] = [[Interface\Tooltips\UI-Tooltip-Background]]
bg["Solid"] = [[Interface\Buttons\WHITE8X8]]

local border = ensureTable("border")
border["None"] = [[Interface\None]]
border["Blizzard Achievement Wood"] = [[Interface\AchievementFrame\UI-Achievement-WoodBorder]]
border["Blizzard Chat Bubble"] = [[Interface\Tooltips\ChatBubble-Backdrop]]
border["Blizzard Dialog"] = [[Interface\DialogFrame\UI-DialogBox-Border]]
border["Blizzard Dialog Gold"] = [[Interface\DialogFrame\UI-DialogBox-Gold-Border]]
border["Blizzard Party"] = [[Interface\CHARACTERFRAME\UI-Party-Border]]
border["Blizzard Tooltip"] = [[Interface\Tooltips\UI-Tooltip-Border]]

local font = ensureTable("font")
if locale == "koKR" then
    LOCALE_MASK = lib.LOCALE_BIT_koKR
    font["굵은 글꼴"] = [[Fonts\2002B.TTF]]
    font["기본 글꼴"] = [[Fonts\2002.TTF]]
    font["데미지 글꼴"] = [[Fonts\K_Damage.TTF]]
    font["퀘스트 글꼴"] = [[Fonts\K_Pagetext.TTF]]
    defaultMedia.font = "기본 글꼴"
elseif locale == "zhCN" then
    LOCALE_MASK = lib.LOCALE_BIT_zhCN
    font["伤害数字"] = [[Fonts\ZYKai_C.ttf]]
    font["默认"] = [[Fonts\ZYKai_T.ttf]]
    font["聊天"] = [[Fonts\ZYHei.ttf]]
    defaultMedia.font = "默认"
elseif locale == "zhTW" then
    LOCALE_MASK = lib.LOCALE_BIT_zhTW
    font["提示訊息"] = [[Fonts\bHEI00M.ttf]]
    font["聊天"] = [[Fonts\bHEI01B.ttf]]
    font["傷害數字"] = [[Fonts\bKAI00M.ttf]]
    font["預設"] = [[Fonts\bLEI00D.ttf]]
    defaultMedia.font = "預設"
elseif locale == "ruRU" then
    LOCALE_MASK = lib.LOCALE_BIT_ruRU
    font["Arial Narrow"] = [[Fonts\ARIALN.TTF]]
    font["Friz Quadrata TT"] = [[Fonts\FRIZQT__.TTF]]
    font["Morpheus"] = [[Fonts\MORPHEUS.TTF]]
    font["Nimrod MT"] = [[Fonts\NIM_____.ttf]]
    font["Skurri"] = [[Fonts\SKURRI.TTF]]
    defaultMedia.font = "Friz Quadrata TT"
else
    LOCALE_MASK = lib.LOCALE_BIT_western
    locale_is_western = true
    font["Arial Narrow"] = [[Fonts\ARIALN.TTF]]
    font["Friz Quadrata TT"] = [[Fonts\FRIZQT__.TTF]]
    font["Morpheus"] = [[Fonts\MORPHEUS.TTF]]
    font["Skurri"] = [[Fonts\SKURRI.TTF]]
    defaultMedia.font = "Friz Quadrata TT"
end

local statusbar = ensureTable("statusbar")
statusbar["Blizzard"] = [[Interface\TargetingFrame\UI-StatusBar]]
defaultMedia.statusbar = "Blizzard"

local sound = ensureTable("sound")
sound["None"] = [[Interface\Quiet.mp3]]
defaultMedia.sound = "None"

local function rebuildMediaList(mediatype)
    local mtable = mediaTable[mediatype]
    if not mtable then return end
    if not mediaList[mediatype] then
        mediaList[mediatype] = {}
    end
    local mlist = mediaList[mediatype]
    local i = 0
    for key in pairs(mtable) do
        i = i + 1
        mlist[i] = key
    end
    for index = i + 1, #mlist do
        mlist[index] = nil
    end
    table_sort(mlist)
end

function lib:Register(mediatype, key, data, langmask)
    if type(mediatype) ~= "string" then
        error(MAJOR .. ":Register(mediatype, key, data, langmask) - mediatype must be string, got " .. type(mediatype), 2)
    end
    if type(key) ~= "string" then
        error(MAJOR .. ":Register(mediatype, key, data, langmask) - key must be string, got " .. type(key), 2)
    end
    mediatype = mediatype:lower()
    if mediatype == lib.MediaType.FONT and ((langmask and band(langmask, LOCALE_MASK) == 0) or not (langmask or locale_is_western)) then
        return false
    end
    local mtable = ensureTable(mediatype)
    if mtable[key] then
        return false
    end
    mtable[key] = data
    rebuildMediaList(mediatype)
    self.callbacks:Fire("LibSharedMedia_Registered", mediatype, key)
    return true
end

function lib:Fetch(mediatype, key, noDefault)
    if type(mediatype) == "string" then
        mediatype = mediatype:lower()
    end
    local mtable = mediaTable[mediatype]
    local overridekey = overrideMedia[mediatype]
    return mtable and ((overridekey and mtable[overridekey]) or mtable[key] or (not noDefault and defaultMedia[mediatype] and mtable[defaultMedia[mediatype]])) or nil
end

function lib:IsValid(mediatype, key)
    if type(mediatype) == "string" then
        mediatype = mediatype:lower()
    end
    return mediaTable[mediatype] and (not key or mediaTable[mediatype][key]) and true or false
end

function lib:HashTable(mediatype)
    if type(mediatype) == "string" then
        mediatype = mediatype:lower()
    end
    return mediaTable[mediatype]
end

function lib:List(mediatype)
    if type(mediatype) == "string" then
        mediatype = mediatype:lower()
    end
    if not mediaTable[mediatype] then
        return nil
    end
    if not mediaList[mediatype] then
        rebuildMediaList(mediatype)
    end
    return mediaList[mediatype]
end

function lib:GetGlobal(mediatype)
    if type(mediatype) == "string" then
        mediatype = mediatype:lower()
    end
    return overrideMedia[mediatype]
end

function lib:SetGlobal(mediatype, key)
    if type(mediatype) == "string" then
        mediatype = mediatype:lower()
    end
    if not mediaTable[mediatype] then
        return false
    end
    overrideMedia[mediatype] = (key and mediaTable[mediatype][key]) and key or nil
    self.callbacks:Fire("LibSharedMedia_SetGlobal", mediatype, overrideMedia[mediatype])
    return true
end

function lib:GetDefault(mediatype)
    if type(mediatype) == "string" then
        mediatype = mediatype:lower()
    end
    return defaultMedia[mediatype]
end

function lib:SetDefault(mediatype, key)
    if type(mediatype) == "string" then
        mediatype = mediatype:lower()
    end
    if mediaTable[mediatype] and mediaTable[mediatype][key] and not defaultMedia[mediatype] then
        defaultMedia[mediatype] = key
        return true
    end
    return false
end
