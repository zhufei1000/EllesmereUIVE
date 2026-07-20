local now = 100
function GetTimePreciseSec() return now end
function hooksecurefunc() end
EllesmereUIVEDB = { settings = { debugSoundTiming = true } }
EllesmereUIVENS = { Core = {}, DEBUG_SOUND_TIMING = true }
local NS = EllesmereUIVENS
assert(loadfile("EllesmereUIVE/Core/EUISoundRegistry.lua"))()
local registry = NS.Core.EUISoundRegistry
assert(registry:CacheResolvedPath("EUIVE_test", "Interface\\test.ogg"))
assert(registry:RecordEUIReady(207167, "sm:EUIVE_test", now))
now = 100.010
assert(registry:GetCachedSoundPath("sm:EUIVE_test", 207167) == "Interface\\test.ogg")
now = 100.020
local recorded, timing = registry:RecordPlayCalled(207167, "sm:EUIVE_test", now)
assert(recorded and timing.playCalled - timing.euiReady < 0.05)
assert(timing.soundResolved - timing.euiReady < 0.05)

local source = assert(io.open("EllesmereUIVE/Core/EUISoundRegistry.lua", "r")):read("*a")
for _, forbidden in ipairs({ "C_Timer.NewTicker", "SPELL_UPDATE_COOLDOWN", "C_Spell.GetSpellCooldown", 'SetScript("OnUpdate"' }) do
    assert(not source:find(forbidden, 1, true), forbidden)
end
print("COOLDOWN_PLAY_CHAIN_UNDER_50MS")
