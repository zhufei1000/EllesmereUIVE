# EllesmereUIVE

EllesmereUIVE 1.0.1 is a standalone voice editor for the EllesmereUI Cooldown Manager. It preserves the addon's independent cast-success and Bloodlust voice alerts while delegating cooldown-ready and Buff gain/loss playback to EUI.

## Addon folders

- `!EllesmereUIVE_Bootstrap` loads first, registers bundled/saved sounds, and pre-seeds the active EUI profile before the Cooldown Manager performs its one-time scans.
- `EllesmereUIVE` contains the runtime, safe EUI database integration, cast-success alerts, and Bloodlust alerts.
- `EllesmereUIVE_Config` is the load-on-demand configuration UI.

Install all three folders directly under `Interface\AddOns`. Do not nest them inside an extra `EllesmereUIVE-1.0.1` folder.

## EUI voice behavior

- Bundled sounds and previously saved custom sounds are registered before EUI initializes.
- Voice presets can be saved for spells that are not yet present in an EUI bar; the target `spellSettingsCD` or `spellSettingsBuff` entry is pre-created without adding a ghost bar spell.
- Hosted Buffs and Buff-family bars use `spellSettingsBuff`.
- EUI custom cooldown states support `customActiveStates[spellID].cdReadySoundKey`.
- Profile/spec changes and `_ECME_Apply` requests are synchronized through events and a debounced secure hook, without a persistent `OnUpdate` or ticker.
- A brand-new custom sound added after the Cooldown Manager initialized is saved safely and reported as `requires_reload`; after `/reload`, EUI can play it natively.

EllesmereUI and EllesmereUICooldownManager files are not modified.

## Compatibility

- World of Warcraft 12.0.5
- World of Warcraft 12.0.7
- World of Warcraft 12.1.0

See [TEST_PLAN.md](TEST_PLAN.md) for the in-game verification matrix.
