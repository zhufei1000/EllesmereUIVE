-- LibDBIcon-1.0.lua
-- Lightweight embedded LibDBIcon-compatible minimap launcher implementation.
-- Creates standard LibDBIcon10_<name> buttons so skin/minimap addons can detect them.
local MAJOR, MINOR = "LibDBIcon-1.0", 1
local LibStub = _G.LibStub
if not LibStub then error(MAJOR .. " requires LibStub.") end
local ldb = LibStub("LibDataBroker-1.1", true)
if not ldb then error(MAJOR .. " requires LibDataBroker-1.1.") end
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.objects = lib.objects or {}
lib.notCreated = lib.notCreated or {}
lib.disabled = lib.disabled or false

local minimapShapes = {
    ["ROUND"] = {true, true, true, true},
    ["SQUARE"] = {false, false, false, false},
    ["CORNER-TOPLEFT"] = {false, false, false, true},
    ["CORNER-TOPRIGHT"] = {false, false, true, false},
    ["CORNER-BOTTOMLEFT"] = {false, true, false, false},
    ["CORNER-BOTTOMRIGHT"] = {true, false, false, false},
    ["SIDE-LEFT"] = {false, true, false, true},
    ["SIDE-RIGHT"] = {true, false, true, false},
    ["SIDE-TOP"] = {false, false, true, true},
    ["SIDE-BOTTOM"] = {true, true, false, false},
    ["TRICORNER-TOPLEFT"] = {false, true, true, true},
    ["TRICORNER-TOPRIGHT"] = {true, false, true, true},
    ["TRICORNER-BOTTOMLEFT"] = {true, true, false, true},
    ["TRICORNER-BOTTOMRIGHT"] = {true, true, true, false},
}

local function safe_atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    elseif x == 0 and y > 0 then
        return math.pi / 2
    elseif x == 0 and y < 0 then
        return -math.pi / 2
    end
    return 0
end

local function getPosition(button)
    local db = button and button.db
    if db and type(db.minimapPos) == "number" then return db.minimapPos end
    return 225
end

local function updatePosition(button)
    if not button or not Minimap then return end
    button:ClearAllPoints()
    local angle = math.rad(getPosition(button))
    local x, y, q = math.cos(angle), math.sin(angle), 1
    if x < 0 then q = q + 1 end
    if y > 0 then q = q + 2 end
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local quad = minimapShapes[shape] or minimapShapes.ROUND
    if quad[q] then
        x, y = x * 80, y * 80
    else
        local radius = 103.13708498985
        x = math.max(-80, math.min(x * radius, 80))
        y = math.max(-80, math.min(y * radius, 80))
    end
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function tooltipAnchor(frame)
    if not frame or not UIParent then return "CENTER" end
    local x, y = frame:GetCenter()
    if not x or not y then return "CENTER" end
    local h = (x > UIParent:GetWidth() * 2 / 3) and "RIGHT" or (x < UIParent:GetWidth() / 3) and "LEFT" or ""
    local v = (y > UIParent:GetHeight() / 2) and "TOP" or "BOTTOM"
    return v .. h, frame, (v == "TOP" and "BOTTOM" or "TOP") .. h
end

local function updateCoord(icon)
    local parent = icon and icon:GetParent()
    local obj = parent and parent.dataObject
    local coords = obj and obj.iconCoords
    if type(coords) == "table" then
        icon:SetTexCoord(coords[1] or 0, coords[2] or 1, coords[3] or 0, coords[4] or 1)
    else
        icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    end
end

local function applyObjectIcon(button)
    local obj = button and button.dataObject
    if not obj or not button.icon then return end
    button.icon:SetTexture(obj.icon)
    if obj.iconR or obj.iconG or obj.iconB then
        button.icon:SetVertexColor(obj.iconR or 1, obj.iconG or 1, obj.iconB or 1)
    else
        button.icon:SetVertexColor(1, 1, 1)
    end
    updateCoord(button.icon)
end

local function onEnter(self)
    if self.isMoving then return end
    local obj = self.dataObject
    if obj and obj.OnTooltipShow and GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint(tooltipAnchor(self))
        obj.OnTooltipShow(GameTooltip)
        GameTooltip:Show()
    elseif obj and obj.OnEnter then
        obj.OnEnter(self)
    end
end

local function onLeave(self)
    if GameTooltip then GameTooltip:Hide() end
    local obj = self.dataObject
    if obj and obj.OnLeave then obj.OnLeave(self) end
end

local function onClick(self, mouseButton)
    local obj = self.dataObject
    if obj and obj.OnClick then obj.OnClick(self, mouseButton) end
end

local function onDragUpdate(self)
    if not Minimap then return end
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale() or 1
    if not mx or not my or not px or not py then return end
    px, py = px / scale, py / scale
    local deg = math.deg(safe_atan2(py - my, px - mx)) % 360
    if self.db then self.db.minimapPos = deg end
    updatePosition(self)
end

local function onDragStart(self)
    if self.db and self.db.lock then return end
    self.isMoving = true
    self:SetScript("OnUpdate", onDragUpdate)
    self:LockHighlight()
    if GameTooltip then GameTooltip:Hide() end
end

local function onDragStop(self)
    self:SetScript("OnUpdate", nil)
    self.isMoving = false
    self:UnlockHighlight()
    updatePosition(self)
end

local function createButton(name, object, db)
    local btnName = "LibDBIcon10_" .. name
    local button = _G[btnName] or CreateFrame("Button", btnName, Minimap or UIParent)
    button.dataObject = object
    button.db = db
    button:SetParent(Minimap or UIParent)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap and Minimap:GetFrameLevel() or 0) + 8)
    button:SetSize(31, 31)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")
    button:SetClampedToScreen(true)
    button:EnableMouse(true)

    if not button.overlay then
        local overlay = button:CreateTexture(nil, "OVERLAY")
        overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        overlay:SetSize(53, 53)
        overlay:SetPoint("TOPLEFT", 0, 0)
        button.overlay = overlay
    end
    if not button.background then
        local background = button:CreateTexture(nil, "BACKGROUND")
        background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
        background:SetSize(20, 20)
        background:SetPoint("TOPLEFT", 7, -5)
        button.background = background
    end
    if not button.icon then
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetSize(17, 17)
        icon:SetPoint("TOPLEFT", 7, -6)
        button.icon = icon
    end
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    applyObjectIcon(button)
    button:SetScript("OnEnter", onEnter)
    button:SetScript("OnLeave", onLeave)
    button:SetScript("OnClick", onClick)
    if db and db.lock then
        button:SetScript("OnDragStart", nil)
        button:SetScript("OnDragStop", nil)
    else
        button:SetScript("OnDragStart", onDragStart)
        button:SetScript("OnDragStop", onDragStop)
    end

    -- Hints used by several skin/minimap addons.  The standard frame name is the
    -- important part; these flags are harmless if no external skin addon is loaded.
    button.d4border = true
    button.euiveSkinTarget = true
    button.euiveSkinGroup = "LibDBIconMinimapButton"

    lib.objects[name] = button
    updatePosition(button)
    if lib.disabled or (db and db.hide) then button:Hide() else button:Show() end
    return button
end

local function ensureCreated(name)
    local pending = lib.notCreated[name]
    if pending then
        lib.notCreated[name] = nil
        return createButton(name, pending.object, pending.db)
    end
    return lib.objects[name]
end

function lib:Register(name, object, db)
    assert(type(name) == "string", "Usage: Register(name, object, db)")
    assert(type(object) == "table" and object.icon, "Can't register LDB objects without icons set!")
    if lib.objects[name] or lib.notCreated[name] then return end
    createButton(name, object, db)
end

function lib:IsRegistered(name)
    return (lib.objects[name] or lib.notCreated[name]) and true or false
end

function lib:GetMinimapButton(name)
    return ensureCreated(name)
end

function lib:Refresh(name, db)
    local button = ensureCreated(name)
    if not button then return end
    if db then button.db = db end
    applyObjectIcon(button)
    updatePosition(button)
    if not lib.disabled and (not button.db or not button.db.hide) then button:Show() else button:Hide() end
end

function lib:Show(name)
    local button = ensureCreated(name)
    local db = button and button.db or (lib.notCreated[name] and lib.notCreated[name].db)
    if db then db.hide = false end
    if button and not lib.disabled then button:Show(); updatePosition(button) end
end

function lib:Hide(name)
    local button = lib.objects[name]
    local db = button and button.db or (lib.notCreated[name] and lib.notCreated[name].db)
    if db then db.hide = true end
    if button then button:Hide() end
end

function lib:Lock(name)
    local button = ensureCreated(name)
    local db = button and button.db or (lib.notCreated[name] and lib.notCreated[name].db)
    if db then db.lock = true end
    if button then button:SetScript("OnDragStart", nil); button:SetScript("OnDragStop", nil) end
end

function lib:Unlock(name)
    local button = ensureCreated(name)
    local db = button and button.db or (lib.notCreated[name] and lib.notCreated[name].db)
    if db then db.lock = false end
    if button then button:SetScript("OnDragStart", onDragStart); button:SetScript("OnDragStop", onDragStop) end
end

function lib:EnableLibrary()
    lib.disabled = false
    for name in pairs(lib.notCreated) do ensureCreated(name) end
    for _, button in pairs(lib.objects) do if not button.db or not button.db.hide then button:Show(); updatePosition(button) end end
end

function lib:DisableLibrary()
    lib.disabled = true
    for _, button in pairs(lib.objects) do button:Hide() end
end

local f = lib.eventFrame or CreateFrame("Frame")
lib.eventFrame = f
f:SetScript("OnEvent", function()
    for _, button in pairs(lib.objects) do updatePosition(button) end
end)
f:RegisterEvent("PLAYER_LOGIN")
