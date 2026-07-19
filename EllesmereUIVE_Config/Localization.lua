local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.Config = NS.Config or {}
NS.Config.SOUND_PATH_HINT = (NS.Constants and NS.Constants.SOUND_ROOT or "Interface\\AddOns\\EllesmereUIVE\\Media\\Sounds\\") .. "AirHorn.ogg"
NS.Config.WAITING_CUSTOM_STATE_TEXT = NS.L and NS.L("STATUS_waiting_for_eui_custom_state")
