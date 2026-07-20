# EllesmereUIVE 1.0.3 Test Plan

Use a clean copy of `!EllesmereUIVE_Bootstrap`, `EllesmereUIVE`, and `EllesmereUIVE_Config`. Keep the installed `EllesmereUI` and `EllesmereUICooldownManager` folders unchanged. Enable Lua error display before testing.

## 1. Fresh installation

1. Start with no `EllesmereUIVEDB` saved variables.
2. Log in with EUI installed and open `/euive`.
3. Verify there are no Lua errors and the configuration UI opens.
4. Create and test one cast-success voice and the Bloodlust voice alert.

Expected: cast-success and Bloodlust remain independently playable; no EUI database errors occur.

## 2. Existing preset after reload

1. Save a cooldown-ready EUI voice preset.
2. Run `/reload`.
3. Confirm the sound is available to EUI and trigger the cooldown-ready edge.

Expected: status is `native_ready` and EUI performs playback.

## 3. New custom path after EUI initialization

1. Wait until `EllesmereUICooldownManager` is loaded.
2. Enter a custom sound path that was not registered at startup.
3. Save and inject.

Expected: saving succeeds, status is `requires_reload`, the UI does not claim “Injected,” and `/reload` changes the status to `native_ready`.

## 4. Bundled sound hot switch

1. Change an existing EUI voice from AirHorn to Applause.
2. Save and inject.

Expected: an already-armed CD/Buff family applies immediately; a family with no startup sound reports `requires_reload`.

## 5. Spell not yet present in EUI

1. Save a `cdReady` voice for a valid spell ID absent from all EUI bars.
2. Inspect the active EUI spec profile.
3. Add the spell to an EUI cooldown bar and trigger `_ECME_Apply` through the normal EUI UI.

Expected: the preset remains visible with status `waiting_for_skill` / “等待技能加入EUI”; after adding the spell, synchronization applies it without requiring a preset re-edit.

## 6. Hosted Buff

1. Place a Buff on a CD/utility bar so EUI stores the hosted marker `-(2000000000 + spellID)`.
2. Save `buffGain` and `buffLoss` voices.

Expected: both fields are written only to `spellSettingsBuff[spellID]`, never `spellSettingsCD`.

## 7. Custom Buff-family bar

1. Use a bar whose internal key does not contain `buff` but whose `barType` is `buffs` (also check legacy `buff`/`type = buffs`).
2. Save a Buff voice for a member spell.

Expected: the target remains `spellSettingsBuff`.

## 8. customActiveStates

1. Use an EUI custom cooldown spell with `customActiveStates[spellID]` (repeat with a string key if available).
2. Save a `cdReady` voice, then remove the EllesmereUIVE injection.

Expected: `cdReadySoundKey` is written to the existing key type and removal restores only the recorded previous value. Buff triggers remain unsupported for this family.

## 9. EUI profile switch

1. Switch from `Default` to another EUI profile without changing specialization.
2. Let the EUI UI invoke `_ECME_Apply`.

Expected: the secure hook detects the profile key change and synchronizes only the current class/spec/profile after the 0.1-second debounce.

## 10. Save during combat

1. Enter combat and save an EUI voice.
2. Leave combat.

Expected: the preset is saved immediately, EUI writes/refresh are queued until `PLAYER_REGEN_ENABLED`, and `requires_reload` remains accurate.

## 11. Conflict protection

1. Select a non-EllesmereUIVE sound manually in EUI.
2. Synchronize with `overwriteEUI` disabled, then enabled.
3. Delete the EllesmereUIVE entry.

Expected: disabled overwrite returns `conflict`; enabled overwrite records `previousValue`; deletion restores that value only if the current field still equals the injected value.

## 12. Cast-success and Bloodlust regression

Verify `UNIT_SPELLCAST_SUCCEEDED`, delayed playback, TTS, Bloodlust fatigue detection, and randomized selection from five Bloodlust paths.

Expected: trigger logic and saved data formats are unchanged, and no `euiVoice` entry enters the cast-success runtime list.

## Static/package checks

- Every Lua file passes `luac -p`.
- Every TOC/XML reference exists.
- Bootstrap has no EUI dependency; the main addon depends on Bootstrap; Config remains load-on-demand.
- No persistent synchronization `OnUpdate`, repeating ticker below one second, `debug.getupvalue`, or EUI source-file modification exists.
- Every `SoundManifest.lua` path resolves to a real `.ogg` or `.mp3` file.
- `EllesmereUIVE-1.0.3.zip` contains exactly the three addon folders at archive root.

## 1.0.3 automatic target-selection matrix

### A. Normal EUI custom cooldown skill

With `customActiveStates[12345] = { duration = 30 }`, create a normal UI `cdReady` entry for spell 12345. Confirm `euiTargetMode/euiTargetFamily` are `auto/auto`, `customActiveStates[12345].cdReadySoundKey` is written, and `spellSettingsCD[12345]` is not created.

### B. String custom-state key

Repeat with `customActiveStates["12345"] = {}`. Confirm the string key is retained, no numeric key is created, and removal restores the previous sound.

### C. Unmanaged spell without custom state

Use a spell absent from `barSpells` and `customActiveStates`. Confirm `spellSettingsCD[spellID].cdReadySoundKey` is pre-created and no custom state is created.

### D. Custom state and CD bar both present

Put the same spell in a CD bar and `customActiveStates`. An automatic `cdReady` entry must choose the existing custom state.

### E. Forced CD

Import `euiTargetMode = forced`, `euiTargetFamily = cd` for a spell with an existing custom state. Confirm the voice is written to `spellSettingsCD`.

### F. Forced custom before EUI creates it

Import `forced/custom` for a missing state. Confirm status is `waiting_for_eui_custom_state`, the preset remains saved, no custom state or CD fallback is created, and a later EUI `_ECME_Apply` injects automatically after EUI creates the state.

### G. Buff triggers with an existing custom state

Create automatic `buffGain` and `buffLoss` entries for a spell that has a custom state. Confirm both use `spellSettingsBuff`, never `customActiveStates`.

### H. 1.0.1 normal-data migration

Load an old entry with `euiTargetFamily = cd` (or `buff`) and no target mode. Confirm it becomes `auto/auto` and resolves against the current EUI structure. If a previous injection record points to another family, confirm the old field is restored safely before the record moves to the newly resolved target.

### I. Legacy custom-data migration

Load an old entry with `euiTargetFamily = custom` and no target mode. Confirm it becomes `forced/custom`.

### J. Editing preserves intent

Edit automatic and forced-custom entries, change sound paths, then change spell IDs. Confirm automatic entries remain automatic, forced custom remains forced, and the new spell ID is resolved against its own EUI state.

### K. Custom-state rollback

After injecting into a custom state, delete the entry. Restore `previousValue` only while the field still equals the injected value; preserve a later user edit and never delete the custom-state table.

### L. Regression pass

Repeat Hosted Buff, arbitrary Buff-bar, reload-required media, early Bootstrap, profile/spec synchronization, cast-success, delay, TTS, Bloodlust, and schema-2 import/export tests.

## 1.0.3 scope and sound-search regression

1. Confirm the editor no longer creates class/spec single-select dropdowns and the scope selector restores all prior race/class/spec selections.
2. Verify all/all, one class/all specs, one class/one spec, one class/multiple specs, and multiple-class mixed-spec selections.
3. Confirm cast-success playback and current-spec login sync ignore entries whose class/spec/race maps do not match the player.
4. Use Save and Inject on a multi-spec EUI voice and confirm every target `specProfile` receives the correct field while the current EUI UI refreshes once.
5. Narrow the entry scope or delete it; confirm all matching injection records are removed while a field manually changed in EUI remains untouched.
6. Search built-in sounds by display name, filename, and full path, and search LibSharedMedia sounds case-insensitively. Clearing search must restore the complete list without changing ordinary dropdowns.
