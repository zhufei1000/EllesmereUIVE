local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.Core = NS.Core or {}
NS.Core.Bloodlust = NS.Core.Bloodlust or {}
local Bloodlust = NS.Core.Bloodlust

-- The established exhaustion/debuff list covers Bloodlust, Heroism,
-- Time Warp, Ancient Hysteria, Primal Rage, Fury of the Aspects and drums.
local EXHAUSTION_IDS = { 57723, 57724, 80354, 95809, 160455, 207400, 264689, 390435 }
local EXHAUSTION_DURATION = 600
local FRESH_WINDOW = 5
local lastExpiration = 0

local function FindExhaustion(requireFresh)
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return false, nil end
    local now = GetTime and GetTime() or 0
    for _, spellID in ipairs(EXHAUSTION_IDS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        if aura and tonumber(aura.expirationTime) then
            local expiration = tonumber(aura.expirationTime)
            local remaining = expiration - now
            if not requireFresh or remaining >= (EXHAUSTION_DURATION - FRESH_WINDOW) then
                return true, expiration
            end
        end
    end
    return false, nil
end

function Bloodlust:HandleUnitAura(unit)
    if unit ~= "player" then return false end
    local fresh, expiration = FindExhaustion(true)
    if not fresh or not expiration or expiration <= 0 or expiration == lastExpiration then return false end
    lastExpiration = expiration

    local db = rawget(_G, "EllesmereUIVEDB")
    local config = type(db) == "table" and db.bloodlust or nil
    if type(config) ~= "table" or config.enabled == false or config.voiceEnabled == false then return false end
    local player = NS.Core and NS.Core.VoicePlayer
    return player and player:NotifyBloodlust(config) or false
end

function Bloodlust:Reset()
    lastExpiration = 0
end
