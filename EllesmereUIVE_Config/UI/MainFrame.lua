local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.MainFrame = NS.UI.MainFrame or {}
local MainFrame = NS.UI.MainFrame

local WHITE = { 0.92, 0.92, 0.92 }
local MUTED = { 0.62, 0.68, 0.72 }
local GREEN = { 0.20, 0.85, 0.55 }

local function Label(parent, text, x, y, size, color)
    local fs = parent:CreateFontString(nil, "ARTWORK", size and "GameFontNormalLarge" or "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text or "")
    color = color or WHITE
    fs:SetTextColor(color[1], color[2], color[3])
    return fs
end

local function Button(parent, text, x, y, width, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 120, 24)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

local function Edit(parent, label, x, y, width)
    Label(parent, label, x, y, nil, MUTED)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width or 240, 24)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 20)
    box:SetAutoFocus(false)
    box:SetTextInsets(6, 6, 0, 0)
    return box
end

local function Check(parent, text, x, y, checked, callback)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    check:SetChecked(checked == true)
    check.text = check:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    check.text:SetPoint("LEFT", check, "RIGHT", 2, 0)
    check.text:SetText(text)
    check:SetScript("OnClick", function(self) if callback then callback(self:GetChecked() == true) end end)
    return check
end

local function Cycle(parent, label, x, y, width, options)
    Label(parent, label, x, y, nil, MUTED)
    local button = Button(parent, "", x, y - 20, width or 170)
    button.options = options
    function button:SetValue(value)
        self.value = value
        for _, option in ipairs(self.options) do
            if option[1] == value then self:SetText(option[2]); return end
        end
        self.value = self.options[1][1]; self:SetText(self.options[1][2])
    end
    button:SetScript("OnClick", function(self)
        local index = 1
        for i, option in ipairs(self.options) do if option[1] == self.value then index = i; break end end
        index = index % #self.options + 1
        self:SetValue(self.options[index][1])
        if self.OnValueChanged then self:OnValueChanged(self.value) end
    end)
    button:SetValue(options[1][1])
    return button
end

local function SpellName(spellID)
    spellID = tonumber(spellID)
    if not spellID then return "" end
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) or "" end
    local getInfo = rawget(_G, "GetSpellInfo")
    return type(getInfo) == "function" and (getInfo(spellID) or "") or ""
end

local function StatusText(entry)
    local integration = NS.Integrations and NS.Integrations.EllesmereUI
    local status = integration and integration:GetInjectionStatus(entry) or "pending"
    return NS.L("STATUS_" .. tostring(status)), status
end

local function SetStatus(panel, text, good)
    if not panel.status then return end
    panel.status:SetText(text or "")
    panel.status:SetTextColor(good and GREEN[1] or 1, good and GREEN[2] or 0.65, good and GREEN[3] or 0.25)
end

local function CreateList(panel, y, entryType, onEdit, allScopes, rowCount, onContext)
    panel.rows = {}
    panel.listPage = 1
    rowCount = tonumber(rowCount) or 7
    Label(panel, entryType == "euiVoice" and "Saved EUI voices" or "Saved cast-success voices", 18, y, nil, MUTED)
    for i = 1, rowCount do
        local row = CreateFrame("Button", nil, panel)
        row:SetSize(760, 27)
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, y - 20 - (i - 1) * 29)
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetColorTexture(0.10, 0.12, 0.14, i % 2 == 0 and 0.65 or 0.42)
        row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row, "LEFT", 8, 0); row.text:SetWidth(670); row.text:SetJustifyH("LEFT")
        row.delete = Button(row, "Delete", 0, 0, 70, function()
            if row.entry then NS:DeleteEntry(row.entry); onEdit(nil); MainFrame:Refresh() end
        end)
        row.delete:ClearAllPoints(); row.delete:SetPoint("RIGHT", row, "RIGHT", -2, 0); row.delete:SetHeight(21)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(self, button)
            if not self.entry then return end
            if button == "RightButton" and onContext then onContext(self.entry, self) else onEdit(self.entry) end
        end)
        panel.rows[i] = row
    end
    local footerY = y - 24 - rowCount * 29
    panel.pageText = Label(panel, "", 350, footerY - 4, nil, MUTED)
    panel.prevPage = Button(panel, "Previous", 18, footerY, 90, function()
        panel.listPage = math.max(1, panel.listPage - 1); panel:RefreshList()
    end)
    panel.nextPage = Button(panel, "Next", 112, footerY, 90, function()
        panel.listPage = panel.listPage + 1; panel:RefreshList()
    end)
    function panel:RefreshList()
        local records = allScopes and NS:GetAllEntries(entryType) or nil
        local entries = records or NS:GetCurrentEntries(entryType)
        local pages = math.max(1, math.ceil(#entries / #self.rows))
        self.listPage = math.min(math.max(1, self.listPage), pages)
        local offset = (self.listPage - 1) * #self.rows
        self.pageText:SetText(string.format("Page %d / %d", self.listPage, pages))
        self.prevPage:SetEnabled(self.listPage > 1)
        self.nextPage:SetEnabled(self.listPage < pages)
        for i, row in ipairs(self.rows) do
            local record = entries[offset + i]
            local entry = allScopes and record and record.entry or record
            row.entry = entry
            row:SetShown(entry ~= nil)
            if entry then
                local name = entry.spellName ~= "" and entry.spellName or SpellName(entry.spellId)
                if entryType == "euiVoice" then
                    local status = StatusText(entry)
                    local scope = allScopes and string.format("C%d/S%d", record.classID, record.specID) or ""
                    local soundName = entry.sharedMediaSound ~= "" and entry.sharedMediaSound
                        or tostring(entry.soundPath or entry.customSoundPath or entry.builtinSoundPath or ""):match("([^\\/]+)$") or "-"
                    local enabled = entry.enabled ~= false and entry.voiceEnabled ~= false and NS.L("ENABLED") or NS.L("DISABLED")
                    row.text:SetText(string.format("%s [%d] %s %s %s %s |cff9ad9ff%s|r", name, entry.spellId or 0, scope, entry.euiTriggerType or "cdReady", soundName, enabled, status))
                else
                    row.text:SetText(string.format("%s  [%d]   %s", name, entry.spellId or 0, entry.soundSource or "custom"))
                end
            end
        end
    end
end

local function FillCommon(panel, entry)
    entry = entry or {}
    panel.editingEntry = entry.entryUID and entry or nil
    panel.spellID:SetText(entry.spellId or "")
    panel.spellName:SetText(entry.spellName or "")
    panel.source:SetValue(entry.soundSource or "custom")
    panel.soundPath:SetText(entry.soundPath or entry.customSoundPath or entry.builtinSoundPath or "")
    panel.sharedMedia:SetText(entry.sharedMediaSound or entry.sharedMediaName or "")
    panel.enabled:SetChecked(entry.enabled ~= false and entry.voiceEnabled ~= false)
    if panel.ttsText then panel.ttsText:SetText(entry.ttsText or "") end
    if panel.ttsRate then panel.ttsRate:SetText(entry.ttsRate or 0) end
    if panel.delayEnabled then panel.delayEnabled:SetChecked(entry.delayEnabled == true) end
    if panel.delaySeconds then panel.delaySeconds:SetText(entry.delaySeconds or 0) end
    if panel.classID and panel.specID then
        local classID, specID = entry.entryUID and NS:FindEntryScope(entry) or NS:GetCurrentClassSpec()
        panel.classID:SetText(classID or 0)
        panel.specID:SetText(specID or 0)
    end
end

local function ReadCommon(panel, entry)
    entry.spellId = tonumber(panel.spellID:GetText())
    entry.spellName = panel.spellName:GetText():match("^%s*(.-)%s*$")
    if entry.spellName == "" then entry.spellName = SpellName(entry.spellId) end
    entry.objectType = "spell"
    entry.soundSource = panel.source.value
    entry.soundPath = panel.soundPath:GetText():match("^%s*(.-)%s*$")
    entry.customSoundPath = entry.soundPath
    entry.sharedMediaSound = panel.sharedMedia:GetText():match("^%s*(.-)%s*$")
    entry.notifyMode = entry.soundSource == "tts" and "tts" or "sound"
    entry.enabled = panel.enabled:GetChecked() == true
    entry.voiceEnabled = entry.enabled
    if panel.ttsText then entry.ttsText = panel.ttsText:GetText() end
    if panel.ttsRate then entry.ttsRate = tonumber(panel.ttsRate:GetText()) or 0 end
    if panel.delayEnabled then entry.delayEnabled = panel.delayEnabled:GetChecked() == true end
    if panel.delaySeconds then entry.delaySeconds = math.max(0, tonumber(panel.delaySeconds:GetText()) or 0) end
    return entry
end

local function ReadBloodlust(panel)
    local cfg = {
        enabled = panel.enabled:GetChecked() == true,
        voiceEnabled = panel.enabled:GetChecked() == true,
        soundSource = panel.source.value,
        sharedMediaSound = panel.sharedMedia:GetText():match("^%s*(.-)%s*$"),
        ttsText = panel.ttsText:GetText(),
        ttsRate = tonumber(panel.ttsRate:GetText()) or 0,
        customSoundPaths = {},
    }
    cfg.notifyMode = cfg.soundSource == "tts" and "tts" or "sound"
    for i, box in ipairs(panel.pathEdits) do cfg.customSoundPaths[i] = box:GetText():match("^%s*(.-)%s*$") end
    cfg.soundPath = cfg.customSoundPaths[1] or ""
    cfg.customSoundPath = cfg.soundPath
    return cfg
end

local function CurrentClassSpecNames()
    local className = "-"
    if type(UnitClass) == "function" then className = UnitClass("player") or "-" end
    local specName = "-"
    local index = GetSpecialization and GetSpecialization()
    if index and C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
        specName = select(2, C_SpecializationInfo.GetSpecializationInfo(index)) or "-"
    end
    return className, specName
end

local function SyncSummary(stats)
    stats = type(stats) == "table" and stats or {}
    return NS.L("SYNC_SUMMARY", stats.injected or 0, stats.upToDate or 0, stats.waiting or 0,
        stats.reloadRequired or 0, stats.conflict or 0, stats.invalidSound or 0, stats.unsupported or 0)
end

function MainFrame:BuildEUIPanel(parent)
    local panel = CreateFrame("Frame", nil, parent); panel:SetAllPoints()
    panel.connection = Label(panel, "", 18, -10, nil, MUTED)
    panel.character = Label(panel, "", 18, -31, nil, MUTED)
    panel.profile = Label(panel, "", 430, -31, nil, MUTED)
    panel.status = Label(panel, "", 18, -336, nil, MUTED)

    Button(panel, NS.L("SYNC_CURRENT_SPEC"), 18, -58, 145, function()
        SetStatus(panel, NS.L("SYNC_QUEUED"), true)
        NS:RequestEUISync("CONFIG_BUTTON", function(_, status, stats)
            if status == "complete" then SetStatus(panel, SyncSummary(stats), true)
            else SetStatus(panel, NS.L("STATUS_" .. tostring(status)), false) end
            MainFrame:Refresh()
        end)
    end)
    Button(panel, NS.L("NEW_VOICE"), 172, -58, 110, function()
        FillCommon(panel, nil); panel.trigger:SetValue("cdReady"); MainFrame.exportEntry = nil; SetStatus(panel, "")
    end)
    Button(panel, NS.L("REDETECT_STATUS"), 291, -58, 135, function()
        local available, status = NS.Integrations.EllesmereUI:IsAvailable()
        SetStatus(panel, available and NS.L("EUI_CONNECTED") or NS.L("STATUS_" .. tostring(status)), available)
        panel:RefreshHeader()
    end)

    panel.spellID = Edit(panel, NS.L("SPELL_ID"), 18, -104, 150)
    panel.spellName = Edit(panel, NS.L("SPELL_NAME"), 190, -104, 250)
    panel.trigger = Cycle(panel, NS.L("TRIGGER"), 462, -104, 170, {
        { "cdReady", NS.L("TRIGGER_CD") }, { "buffGain", NS.L("TRIGGER_GAIN") }, { "buffLoss", NS.L("TRIGGER_LOSS") },
    })
    panel.source = Cycle(panel, NS.L("SOUND_SOURCE"), 650, -104, 140, {
        { "custom", NS.L("CUSTOM_SOUND") }, { "builtin", NS.L("BUILTIN_SOUND") }, { "sharedmedia", "LibSharedMedia" },
    })
    panel.classID = Edit(panel, NS.L("CLASS_ID"), 18, -160, 150)
    panel.specID = Edit(panel, NS.L("SPEC_ID"), 190, -160, 250)
    panel.soundPath = Edit(panel, NS.L("SOUND_PATH"), 462, -160, 328)
    panel.soundPath:SetText("Interface\\AddOns\\EllesmereUIVE\\Media\\Sounds\\AirHorn.ogg")
    panel.sharedMedia = Edit(panel, "LibSharedMedia", 18, -216, 422)
    panel.enabled = Check(panel, NS.L("ENABLED"), 462, -237, true)

    local function ReadEUIEntry()
        local entry = ReadCommon(panel, {})
        entry.entryType = "euiVoice"
        entry.euiTriggerType = panel.trigger.value
        local existing = panel.editingEntry
        if existing and existing.euiTargetMode == "forced" then
            entry.euiTargetMode = "forced"
            entry.euiTargetFamily = existing.euiTargetFamily
        else
            entry.euiTargetMode = "auto"
            entry.euiTargetFamily = "auto"
        end
        return entry, math.max(0, tonumber(panel.classID:GetText()) or 0), math.max(0, tonumber(panel.specID:GetText()) or 0)
    end

    local function SaveEUIEntry(injectNow)
        local entry, classID, specID = ReadEUIEntry()
        if not entry.spellId or entry.spellId <= 0 then SetStatus(panel, NS.L("SPELL_ID_REQUIRED")); return end
        if NS.Core.EUISoundRegistry:ResolveSoundPath(entry) == "" then SetStatus(panel, NS.L("STATUS_invalid_path")); return end
        local saved, status, ok = NS:SaveEntry(entry, panel.editingEntry, classID, specID, injectNow)
        if not saved then SetStatus(panel, status == "duplicate" and NS.L("DUPLICATE_ENTRY") or NS.L("SAVE_FAILED")); return end
        panel.editingEntry = saved
        SetStatus(panel, NS.L("STATUS_" .. tostring(status)), ok and status ~= "requires_reload")
        MainFrame:Refresh()
    end

    Button(panel, NS.L("PREVIEW"), 18, -278, 80, function() NS.Core.VoicePlayer:PreviewSound((ReadEUIEntry())) end)
    Button(panel, NS.L("SAVE_ONLY"), 106, -278, 110, function() SaveEUIEntry(false) end)
    Button(panel, NS.L("SAVE_AND_INJECT"), 224, -278, 130, function() SaveEUIEntry(true) end)
    Button(panel, NS.L("REMOVE_INJECTION"), 362, -278, 130, function()
        if panel.editingEntry then
            local ok, status = NS.Integrations.EllesmereUI:RemoveEntry(panel.editingEntry)
            SetStatus(panel, NS.L("STATUS_" .. status), ok); MainFrame:Refresh()
        end
    end)

    local edit
    edit = function(entry)
        FillCommon(panel, entry)
        MainFrame.exportEntry = entry
        panel.trigger:SetValue(entry and entry.euiTriggerType or "cdReady")
        if entry then
            local text, status = StatusText(entry)
            SetStatus(panel, text, status == "native_ready" or status == "preseeded" or status == "custom_state_injected" or status == "up_to_date")
        else SetStatus(panel, "") end
    end

    local function context(entry, owner)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then edit(entry); return end
        MenuUtil.CreateContextMenu(owner, function(_, root)
            root:CreateButton(NS.L("EDIT"), function() edit(entry) end)
            root:CreateButton(NS.L("INJECT_NOW"), function()
                local ok, status = NS:InjectSavedEntry(entry)
                SetStatus(panel, NS.L("STATUS_" .. tostring(status)), ok and status ~= "requires_reload"); MainFrame:Refresh()
            end)
            root:CreateButton(NS.L("REMOVE_INJECTION"), function()
                local ok, status = NS.Integrations.EllesmereUI:RemoveEntry(entry)
                SetStatus(panel, NS.L("STATUS_" .. tostring(status)), ok); MainFrame:Refresh()
            end)
            root:CreateButton(NS.L("DISABLE"), function()
                local classID, specID = NS:FindEntryScope(entry)
                local draft = NS.Core.Database.DeepCopy(entry); draft.enabled = false; draft.voiceEnabled = false
                NS:SaveEntry(draft, entry, classID, specID, false); MainFrame:Refresh()
            end)
            root:CreateButton(NS.L("DELETE"), function() NS:DeleteEntry(entry); edit(nil); MainFrame:Refresh() end)
        end)
    end

    CreateList(panel, -363, "euiVoice", edit, true, 4, context)
    function panel:RefreshHeader()
        local integration = NS.Integrations.EllesmereUI
        local available, status = integration:IsAvailable()
        local className, specName = CurrentClassSpecNames()
        local pending = 0
        for _, entry in ipairs(NS:GetCurrentEntries("euiVoice")) do
            local entryStatus = integration:GetEntryStatus(entry)
            if entryStatus ~= "native_ready" and entryStatus ~= "preseeded" and entryStatus ~= "custom_state_injected"
                and entryStatus ~= "up_to_date" and entryStatus ~= "disabled" then pending = pending + 1 end
        end
        self.connection:SetText(NS.L("EUI_STATUS_LINE", available and NS.L("CONNECTED") or NS.L("STATUS_" .. tostring(status))))
        self.character:SetText(NS.L("CHARACTER_LINE", className, specName))
        self.profile:SetText(NS.L("PROFILE_PENDING_LINE", integration:GetCurrentProfileKey() or "-", pending))
    end
    panel.Edit = edit
    return panel
end

function MainFrame:BuildCastPanel(parent)
    local panel = CreateFrame("Frame", nil, parent); panel:SetAllPoints()
    Label(panel, "EllesmereUIVE listens for UNIT_SPELLCAST_SUCCEEDED and plays voice only.", 18, -12, nil, MUTED)
    panel.spellID = Edit(panel, "Spell ID", 18, -44, 150)
    panel.spellName = Edit(panel, "Spell name", 190, -44, 250)
    panel.source = Cycle(panel, "Sound source", 462, -44, 170, {
        { "custom", "Voice path" }, { "builtin", "Built-in" }, { "sharedmedia", "SharedMedia" }, { "tts", "TTS" },
    })
    panel.soundPath = Edit(panel, "Voice path", 18, -100, 490)
    panel.soundPath:SetText("Interface\\AddOns\\EllesmereUIVE\\Media\\Sounds\\AirHorn.ogg")
    panel.sharedMedia = Edit(panel, "SharedMedia sound", 530, -100, 260)
    panel.ttsText = Edit(panel, "TTS text", 18, -156, 490)
    panel.ttsRate = Edit(panel, "TTS rate (-10 to 10)", 530, -156, 150)
    panel.enabled = Check(panel, "Enabled", 700, -177, true)
    panel.delayEnabled = Check(panel, "Delay playback", 18, -207, false)
    panel.delaySeconds = Edit(panel, "Delay seconds", 160, -190, 120)
    panel.status = Label(panel, "", 360, -256, nil, MUTED)
    Button(panel, "New", 18, -250, 80, function() FillCommon(panel, nil); SetStatus(panel, "") end)
    Button(panel, "Test", 106, -250, 80, function() NS.Core.VoicePlayer:PreviewSound(ReadCommon(panel, {})) end)
    Button(panel, "Save", 194, -250, 120, function()
        local entry = ReadCommon(panel, {})
        entry.entryType = "cast"; entry.triggerSpellID = entry.spellId
        if not entry.spellId then SetStatus(panel, "Spell ID is required."); return end
        local saved, status = NS:SaveEntry(entry, panel.editingEntry)
        if not saved then SetStatus(panel, status == "duplicate" and "A matching cast-success entry already exists." or "Save failed."); return end
        panel.editingEntry = saved
        NS.Core.CastSuccess:Rebuild(); SetStatus(panel, NS.L("SAVED"), true); MainFrame:Refresh()
    end)
    local function edit(entry) FillCommon(panel, entry); MainFrame.exportEntry = entry; SetStatus(panel, entry and NS.L("SAVED") or "", entry ~= nil) end
    CreateList(panel, -300, "cast", edit)
    panel.Edit = edit
    return panel
end

function MainFrame:BuildBloodlustPanel(parent)
    local panel = CreateFrame("Frame", nil, parent); panel:SetAllPoints()
    Label(panel, "Bloodlust/Heroism detection is local to EllesmereUIVE and is never injected into EUI.", 18, -12, nil, MUTED)
    panel.source = Cycle(panel, "Sound source", 18, -54, 170, {
        { "custom", "Voice path" }, { "builtin", "Built-in" }, { "sharedmedia", "SharedMedia" }, { "tts", "TTS" },
    })
    panel.pathEdits = {}
    for i = 1, 5 do panel.pathEdits[i] = Edit(panel, "Custom voice path " .. i, 210, -54 - (i - 1) * 54, 580) end
    panel.soundPath = panel.pathEdits[1]
    panel.sharedMedia = Edit(panel, "SharedMedia sound", 18, -330, 360)
    panel.ttsText = Edit(panel, "TTS text", 400, -330, 390)
    panel.ttsRate = Edit(panel, "TTS rate (-10 to 10)", 18, -386, 170)
    panel.enabled = Check(panel, "Enable Bloodlust voice alert", 220, -406, true)
    panel.status = Label(panel, "", 18, -454, nil, MUTED)
    Button(panel, "Test", 18, -486, 100, function()
        NS.Core.VoicePlayer:PlayBloodlust(ReadBloodlust(panel))
    end)
    Button(panel, "Save", 128, -486, 120, function()
        EllesmereUIVEDB.bloodlust = ReadBloodlust(panel)
        SetStatus(panel, NS.L("SAVED"), true)
    end)
    function panel:RefreshPanel()
        local cfg = EllesmereUIVEDB.bloodlust or {}
        panel.source:SetValue(cfg.soundSource or "custom")
        for i, box in ipairs(panel.pathEdits) do box:SetText(type(cfg.customSoundPaths) == "table" and cfg.customSoundPaths[i] or (i == 1 and (cfg.soundPath or cfg.customSoundPath) or "")) end
        panel.sharedMedia:SetText(cfg.sharedMediaSound or "")
        panel.ttsText:SetText(cfg.ttsText or "Bloodlust")
        panel.ttsRate:SetText(cfg.ttsRate or 0)
        panel.enabled:SetChecked(cfg.enabled ~= false and cfg.voiceEnabled ~= false)
    end
    return panel
end

function MainFrame:BuildImportPanel(parent)
    local panel = CreateFrame("Frame", nil, parent); panel:SetAllPoints()
    Label(panel, "Full EllesmereUIVE configuration export (schema 2).", 18, -12, nil, MUTED)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -42); scroll:SetSize(750, 390)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject("ChatFontNormal")
    edit:SetWidth(720); edit:SetHeight(700); edit:SetTextInsets(8, 8, 8, 8)
    scroll:SetScrollChild(edit); panel.text = edit
    panel.status = Label(panel, "", 18, -475, nil, MUTED)
    local function ShowExport(payload, err)
        if not payload then SetStatus(panel, NS.L("EXPORT_FAILED", err or "unknown")); return end
        local text, encodeError = NS.Core.ImportExport:Encode(payload)
        if text then edit:SetText(text); edit:HighlightText(); SetStatus(panel, "Export ready.", true)
        else SetStatus(panel, NS.L("EXPORT_FAILED", encodeError)) end
    end
    Button(panel, "Export all", 18, -505, 110, function()
        local text, err = NS.Core.ImportExport:Encode()
        if text then edit:SetText(text); edit:HighlightText(); SetStatus(panel, "Export ready.", true)
        else SetStatus(panel, NS.L("EXPORT_FAILED", err)) end
    end)
    Button(panel, "Export entry", 136, -505, 110, function()
        local payload, err = NS.Core.ImportExport:BuildEntryPayload(MainFrame.exportEntry)
        ShowExport(payload, err)
    end)
    Button(panel, "Export collection", 254, -505, 135, function()
        local classID, specID = NS:GetCurrentClassSpec()
        ShowExport(NS.Core.ImportExport:BuildCollectionPayload(classID, specID))
    end)
    Button(panel, "Import", 397, -505, 100, function()
        local ok, added, status = NS.Core.ImportExport:ImportText(edit:GetText())
        local message
        if not ok then message = NS.L("IMPORT_FAILED", added or "unknown")
        elseif status == "requires_reload" then message = NS.L("IMPORT_DONE_RELOAD", added or 0)
        else message = NS.L("IMPORT_DONE_COUNT", added or 0) end
        SetStatus(panel, message, ok and status ~= "requires_reload")
        MainFrame:Refresh()
    end)
    return panel
end

function MainFrame:BuildSettingsPanel(parent)
    local panel = CreateFrame("Frame", nil, parent); panel:SetAllPoints()
    Label(panel, "EllesmereUIVE settings", 18, -18, true, WHITE)
    local s = EllesmereUIVEDB.settings
    panel.loginSync = Check(panel, "Synchronize current specialization at login", 18, -60, s.syncOnLogin, function(v) s.syncOnLogin = v end)
    panel.autoSync = Check(panel, "Automatically sync after specialization changes", 18, -96, s.autoSyncSpec, function(v) s.autoSyncSpec = v end)
    panel.autoInject = Check(panel, "Inject automatically when saving", 18, -132, s.autoInjectOnSave, function(v) s.autoInjectOnSave = v end)
    panel.overwrite = Check(panel, "Overwrite voices already configured in EUI", 18, -168, s.overwriteEUI, function(v) s.overwriteEUI = v end)
    panel.loadMessage = Check(panel, "Show loaded message", 18, -204, s.showLoadMessage, function(v) s.showLoadMessage = v end)
    panel.minimap = Check(panel, "Show minimap button", 18, -240, EllesmereUIVEDB.minimap.hide ~= true, function(v)
        NS.Core.MinimapButton:SetShown(v)
    end)
    panel.channel = Cycle(panel, "Sound channel", 18, -294, 180, {
        { "Master", "Master" }, { "SFX", "SFX" }, { "Dialog", "Dialog" }, { "Music", "Music" }, { "Ambience", "Ambience" },
    })
    panel.channel:SetValue(s.soundChannel or "Master")
    panel.channel.OnValueChanged = function(_, value) s.soundChannel = value end
    Label(panel, "Default behavior never overwrites an existing EUI voice. Enable the overwrite option only when intended.", 18, -366, nil, MUTED)
    return panel
end

function MainFrame:Build()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "EllesmereUIVEMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(850, 650); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true); frame:EnableMouse(true); frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton"); frame:SetScript("OnDragStart", frame.StartMoving); frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
    Label(frame, "EllesmereUIVE", 22, -18, true, GREEN)
    local close = Button(frame, "X", 0, 0, 28, function() frame:Hide() end)
    close:ClearAllPoints(); close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -72); content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    self.panels = {
        self:BuildEUIPanel(content), self:BuildCastPanel(content), self:BuildBloodlustPanel(content),
        self:BuildImportPanel(content), self:BuildSettingsPanel(content),
    }
    local tabLabels = { NS.L("TAB_EUI"), NS.L("TAB_CAST"), NS.L("TAB_BLOODLUST"), NS.L("TAB_IMPORT"), NS.L("TAB_SETTINGS") }
    self.tabs = {}
    local x = 18
    for i, text in ipairs(tabLabels) do
        local width = i == 4 and 130 or 115
        self.tabs[i] = Button(frame, text, x, -45, width, function() self:SelectTab(i) end)
        x = x + width + 5
    end
    self.frame = frame
    frame:SetScript("OnShow", function() self:Refresh() end)
    self:SelectTab(1); frame:Hide()
    return frame
end

function MainFrame:SelectTab(index)
    self.selectedTab = index
    for i, panel in ipairs(self.panels or {}) do panel:SetShown(i == index) end
end

function MainFrame:Refresh()
    if not self.frame then return end
    local eui, cast, bloodlust = self.panels[1], self.panels[2], self.panels[3]
    if eui.RefreshList then eui:RefreshList() end
    if eui.RefreshHeader then eui:RefreshHeader() end
    if cast.RefreshList then cast:RefreshList() end
    if bloodlust.RefreshPanel then bloodlust:RefreshPanel() end
end

function MainFrame:Open()
    local frame = self:Build(); frame:Show(); self:Refresh()
end

function MainFrame:Toggle()
    local frame = self:Build()
    if frame:IsShown() then frame:Hide() else frame:Show(); self:Refresh() end
end
