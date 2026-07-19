local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.Config = NS.Config or {}
NS.Config.SOUND_PATH_HINT = (NS.Constants and NS.Constants.SOUND_ROOT or "Interface\\AddOns\\EllesmereUIVE\\Media\\Sounds\\") .. "AirHorn.ogg"
