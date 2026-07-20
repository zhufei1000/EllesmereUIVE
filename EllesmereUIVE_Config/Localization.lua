local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS
local RuntimeL = NS.L

local function NormalizeLanguageMode(value)
    value = tostring(value or "auto")
    if value == "zhCN" or value == "zhTW" or value == "enUS" then
        return value
    end
    return "auto"
end

local function DetectClientLocale()
    local rawLocale = (type(GetLocale) == "function" and GetLocale()) or "enUS"
    return (rawLocale == "zhCN" and "zhCN") or (rawLocale == "zhTW" and "zhTW") or "enUS"
end

local function GetSavedLanguageMode()
    local db = rawget(_G, "EllesmereUIVEDB")
    if type(db) == "table" then
        return NormalizeLanguageMode(db.languageMode)
    end
    return "auto"
end

local function ResolveActiveLocale(mode)
    mode = NormalizeLanguageMode(mode)
    if mode == "auto" then
        return DetectClientLocale()
    end
    return mode
end

local activeLanguageMode = GetSavedLanguageMode()
local activeLocale = ResolveActiveLocale(activeLanguageMode)
NS.LOCALE = activeLocale

local enUS = {
    ADDON_DISPLAY_NAME = "QFX Skill Alerts",
    ADDON_SHORT_NAME = "QFX Alerts",
    OPTION_NAME = "QFX Skill Alerts",
    AUTHOR_LINE = "Author: zhufei1000",
    OPTIONS_DESC = "Fixed-cooldown spell voice alerts: records successful casts via UNIT_SPELLCAST_SUCCEEDED, times cooldowns by the fixed CD you enter, and plays TTS or voice files when cooldowns finish, casts succeed, or Bloodlust is triggered.\n\nClick the button below to open the main settings window. You can also use /qfxsa or the minimap icon.",
    OPEN_MAIN_SETTINGS = "Open main settings",
    COMMANDS = "Commands: /qfxsa or /qfxskillalerts",

    BTN_ADD_VOICE = "Add Alert", BTN_ADD_COLLECTION = "Add Group", BTN_EDIT = "Edit", BTN_DELETE = "Delete", BTN_REFRESH = "Refresh", BTN_IMPORT = "Import", BTN_EXPORT_FULL = "Export All", BTN_SAVE = "Save", BTN_TEST = "Test", BTN_CLOSE = "Close", BTN_SELECT_ALL = "Select All",
    TITLE_NEW_CONFIG = "New Alert", TITLE_EDIT_CONFIG = "Edit Alert", TITLE_BLOODLUST_SETTINGS = "Bloodlust Alert Settings", TITLE_ADD_COLLECTION = "New Group", TITLE_RENAME_COLLECTION = "Rename Group", TITLE_IMPORT_EXPORT = "Import / Export", TITLE_EXPORT = "Export", TITLE_IMPORT_SETTINGS = "Import Settings", EXPORT_ENTRY = "Export Alert", EXPORT_COLLECTION = "Export Group", DELETE_ENTRY = "Delete Alert", EDIT_ENTRY = "Edit Alert", DELETE_COLLECTION_WITH_ITEMS = "Delete group and alerts", EXPAND_COLLECTION = "Expand Group", COLLAPSE_COLLECTION = "Collapse Group", RENAME_COLLECTION = "Rename Group", EXPORT_FULL_TITLE = "Export All",

    TAB_COOLDOWN = "CD Alert", TAB_CAST = "Cast Success", TAB_BLOODLUST = "Bloodlust", SECTION_CLASS_SPEC = "Class / Spec", LABEL_CLASS = "Class", LABEL_SPEC = "Spec", SECTION_SPELL_PARAMS = "Spell Settings", LABEL_SPELL_ID = "Spell ID", LABEL_SPELL_NAME = "Spell Name", LABEL_FIXED_CD_SEC = "Fixed CD (sec)", LABEL_CHECK_TALENT = "Check Talent", LABEL_TALENT_ID = "Talent ID", LABEL_TALENT_NAME = "Talent Name", LABEL_TALENT_CD_SEC = "CD Changes To (sec)", SECTION_NOTIFY = "Notification", LABEL_BUILTIN_SOUND = "Built-in Sound", LABEL_USE_CUSTOM_SOUND = "Use custom sound path", LABEL_USE_TTS = "Use TTS text", LABEL_TTS_RATE = "TTS Rate", EDITOR_HINT = "When TTS and custom path are disabled, the built-in sound will be used. Click \"Test\" before saving to confirm.", SECTION_BLOODLUST_SOUND = "Bloodlust Sound Settings", LABEL_SOUND_PATH_N = "Sound Path %d", BLOODLUST_HINT = "Recommended path format: Interface\\AddOns\\EllesmereUIVE\\Media\\Sounds\\xxx.ogg. Empty paths will not be added to the random pool.",

    PLACEHOLDER_SELECT_CLASS = "Select Class", PLACEHOLDER_SELECT_SPEC = "Select Spec", PLACEHOLDER_SELECT_CLASSES = "Select Classes", PLACEHOLDER_SELECT_SPECS = "Select Specs", PLACEHOLDER_SELECT_BUILTIN_SOUND = "Select built-in sound",
    COLLECTION_NAME = "Group Name", COLLECTION_ICON_ID = "Group Icon ID (optional)", COLLECTION_ICON_HINT = "Enter an in-game icon FileID, for example 134400. Leave it empty to use the default group icon.", COLLECTION_HINT = "After creation it appears in the Loaded area. Loaded and unloaded alerts can be dragged into groups; green/yellow/red dots show their status.", COLLECTION_DEFAULT_NAME = "New Group", COLLECTION_UNNAMED = "Unnamed Group", COLLECTION_LABEL = "Group", COLLECTION_COUNT = "%d items", COLLECTION_EMPTY_COUNT = "(empty)", DRAG_INTO_COLLECTION = "Drag alerts into this group",
    HEADER_LOADED = "Loaded", HEADER_UNLOADED = "Unloaded", EMPTY_CONFIG = "No alerts", ENTRY_TYPE_COOLDOWN = "CD Alert", ENTRY_TYPE_CAST = "Cast Success", ENTRY_TYPE_BLOODLUST = "Bloodlust", ENTRY_UNNAMED = "Unnamed", TALENT_ROW = "Talent:%s CD:%.2fs", TALENT_ROW_NO_CD = "Talent:%s", MODE_SOUND = "Sound", LOADED_TAG = " |cff00ff00Loaded|r", UNLOADED_TAG = " |cffff4040Unloaded|r",
    EXPORT_DESC = "Below is the compressed export string. Click \"Select All\" and press Ctrl+C to copy it. To import, paste this string into the same window.", IMPORT_DESC = "Paste a QFX Skill Alerts export string and click \"Import\". Supports single alerts, groups, and full imports. Full imports replace the current saved alerts, groups, sorting, Bloodlust, minimap, language, and UI skin settings.",
    MINIMAP_LEFT = "Left-click: open main settings", MINIMAP_RIGHT = "Right-click: open addon options", MINIMAP_DRAG = "Drag: move minimap icon", MINIMAP_ICON_FILE = "Icon file: AppIcon.png",
    MSG_PREFIX = "[EUIVE] ", MSG_MAIN_NOT_READY = "Main settings window is not ready yet.", MSG_MAIN_NOT_READY_LATER = "Main settings window is not ready yet. Please try again shortly.", MSG_NO_TTS = "No TTS voice is currently available.", MSG_TTS_FAILED = "TTS playback failed: %s", MSG_NO_CUSTOM_AUDIO = "This client cannot play custom audio.", MSG_SOUND_FAILED = "Voice file playback failed. Check path: %s", MSG_NO_SOUND_PATH = "This spell has no voice file path.", MSG_NO_CAST_SOUND_PATH = "Cast-success alert has no voice file path.", MSG_NO_BLOODLUST_SOUND_PATH = "Bloodlust alert has no voice path.", MSG_LOADED = "Loaded. Type /qfxsa or /qfxskillalerts to open settings.", MSG_SCOPE_COUNT = "%d spell alerts saved in the current scope.", MSG_CURRENT_EDIT_SCOPE = "Current class/spec: %s / %s", MSG_SELECTED_NOT_EXIST = "The selected alert no longer exists.", MSG_INVALID_CLASS_SPEC = "Class or spec is invalid.", MSG_INVALID_SPELL_ID = "Spell ID is invalid.", MSG_INVALID_FIXED_CD = "Fixed CD is invalid.", MSG_NEED_TALENT_ID = "Talent check is enabled. Please enter a valid Talent ID.", MSG_NEED_TALENT_CD = "Talent check is enabled. Please enter a valid CD Changes To value.", MSG_NEED_TTS_TEXT = "TTS is enabled. Please enter announcement text.", MSG_NEED_SOUND_PATH = "Voice file is enabled. Please enter a sound path.", MSG_NEED_ALERT_ACTIONS = "Please select at least one alert action: Sound, Image, or Text.", MSG_DUP_SPELL = "The current spec already has the same Spell ID.", MSG_SAVE_LIMIT = "Save limit reached.", MSG_CONFIG_SAVED = "Alert saved.", MSG_CHOOSE_CONFIG = "Please select an alert first.", MSG_CONFIG_DELETED = "Alert deleted.", MSG_IMPORT_FAILED = "Import failed: %s", MSG_IMPORT_UNKNOWN_TYPE = "Import failed: unknown import type.", MSG_IMPORT_DONE = "Import complete: %s, processed %d alerts.", MSG_IMPORT_EMPTY = "Import failed: no importable data.", MSG_MENU_MISSING = "Right-click menu component is not loaded by the client. Use the Edit/Delete buttons above.", MSG_DRAG_UNLOADED_TO_ROOT = "Unloaded alerts cannot be dragged to the loaded root area. Drag them into a loaded group instead.", MSG_DRAG_UNLOADED_TO_GROUP = "Unloaded alert added to this group. It will be shown with a red dot.",
    TTS_READY_DEFAULT = "Ready", TTS_CAST_SUCCESS_DEFAULT = "Cast success", FALLBACK_CLASS = "Class%s", FALLBACK_SPEC = "Spec%s",
}

local zhCN = setmetatable({
    ADDON_DISPLAY_NAME = "QFX 技能提醒", ADDON_SHORT_NAME = "QFX 技能提醒", OPTION_NAME = "QFX 技能提醒", AUTHOR_LINE = "作者：zhufei1000",
    OPTIONS_DESC = "固定CD技能语音提醒插件：通过 UNIT_SPELLCAST_SUCCEEDED 记录施法成功事件，按你填写的固定CD计时，并在冷却结束、施法成功或嗜血触发时播放TTS或语音文件。\n\n点击下方按钮可打开主设置界面；也可以使用 /qfxsa 或点击小地图图标打开。", OPEN_MAIN_SETTINGS = "打开主设置界面", COMMANDS = "命令：/qfxsa 或 /qfxskillalerts",
    BTN_ADD_VOICE = "新增", BTN_ADD_COLLECTION = "新增合集", BTN_EDIT = "编辑", BTN_DELETE = "删除", BTN_REFRESH = "刷新", BTN_IMPORT = "导入", BTN_EXPORT_FULL = "全量导出", BTN_SAVE = "保存", BTN_TEST = "试听", BTN_CLOSE = "关闭", BTN_SELECT_ALL = "全选",
    TITLE_NEW_CONFIG = "新增配置", TITLE_EDIT_CONFIG = "编辑配置", TITLE_BLOODLUST_SETTINGS = "嗜血提示设置", TITLE_ADD_COLLECTION = "新增合集", TITLE_RENAME_COLLECTION = "重命名合集", TITLE_IMPORT_EXPORT = "导入 / 导出", TITLE_EXPORT = "导出", TITLE_IMPORT_SETTINGS = "导入设置", EXPORT_ENTRY = "导出单条信息", EXPORT_COLLECTION = "导出合集", DELETE_ENTRY = "删除配置", EDIT_ENTRY = "编辑配置", DELETE_COLLECTION_WITH_ITEMS = "删除合集和其中语音", EXPAND_COLLECTION = "展开合集", COLLAPSE_COLLECTION = "收拢合集", RENAME_COLLECTION = "重命名合集", EXPORT_FULL_TITLE = "全量导出",
    TAB_COOLDOWN = "CD提示", TAB_CAST = "施法成功", TAB_BLOODLUST = "嗜血提示", SECTION_CLASS_SPEC = "职业 / 专精", LABEL_CLASS = "职业", LABEL_SPEC = "专精", SECTION_SPELL_PARAMS = "技能参数", LABEL_SPELL_ID = "技能ID", LABEL_SPELL_NAME = "技能名称", LABEL_FIXED_CD_SEC = "固定CD（秒）", LABEL_CHECK_TALENT = "检查天赋", LABEL_TALENT_ID = "天赋ID", LABEL_TALENT_NAME = "天赋名称", LABEL_TALENT_CD_SEC = "CD变为（秒）", SECTION_NOTIFY = "通知方式", LABEL_BUILTIN_SOUND = "内置语音", LABEL_USE_CUSTOM_SOUND = "启用自定义语音路径", LABEL_USE_TTS = "启用 TTS 文本", LABEL_TTS_RATE = "TTS 语速", EDITOR_HINT = "四种来源互斥：内置语音、共享媒体、自定义路径、TTS。保存前可点击底部“试听”确认。", SECTION_BLOODLUST_SOUND = "嗜血音效设置", LABEL_SOUND_PATH_N = "语音路径 %d", BLOODLUST_HINT = "建议填写 Interface\\AddOns\\EllesmereUIVE\\Media\\Sounds\\xxx.ogg 这样的游戏内路径。未填写的路径不会加入随机池。",
    PLACEHOLDER_SELECT_CLASS = "请选择职业", PLACEHOLDER_SELECT_SPEC = "请选择专精", PLACEHOLDER_SELECT_CLASSES = "请选择职业", PLACEHOLDER_SELECT_SPECS = "请选择专精", PLACEHOLDER_SELECT_BUILTIN_SOUND = "请选择内置语音",
    COLLECTION_NAME = "合集名称", COLLECTION_ICON_ID = "合集图标ID（可选）", COLLECTION_ICON_HINT = "输入游戏内图标 FileID，例如 134400。留空时使用默认合集图标。", COLLECTION_HINT = "创建后显示在已载入区域；已载入/未载入语音都可以拖入合集，合集内用绿/黄/红圆点区分状态。", COLLECTION_DEFAULT_NAME = "新建合集", COLLECTION_UNNAMED = "未命名合集", COLLECTION_LABEL = "合集", COLLECTION_COUNT = "%d 条", COLLECTION_EMPTY_COUNT = "（空）", DRAG_INTO_COLLECTION = "拖拽语音到这个合集里",
    HEADER_LOADED = "已载入", HEADER_UNLOADED = "未载入", EMPTY_CONFIG = "暂无配置", ENTRY_TYPE_COOLDOWN = "CD提示", ENTRY_TYPE_CAST = "施法成功", ENTRY_TYPE_BLOODLUST = "嗜血提示", ENTRY_UNNAMED = "未命名", TALENT_ROW = "天赋:%s CD:%.2fs", TALENT_ROW_NO_CD = "天赋:%s", MODE_SOUND = "语音", LOADED_TAG = " |cff00ff00已载入|r", UNLOADED_TAG = " |cffff4040未载入|r",
    EXPORT_DESC = "下面是压缩后的导出字符串。点击“全选”后用 Ctrl+C 复制；导入时把这段字符串粘贴到同一个窗口。", IMPORT_DESC = "粘贴 QFX 技能提醒导出字符串后点击“导入”。支持单条信息、合集和全量导入；全量导入会替换当前已保存提示、合集、排序、嗜血、小地图、语言和界面皮肤设置。",
    MINIMAP_LEFT = "左键：打开主设置界面", MINIMAP_RIGHT = "右键：打开系统选项页", MINIMAP_DRAG = "拖动：移动小地图图标", MINIMAP_ICON_FILE = "图标文件：AppIcon.png",
    MSG_MAIN_NOT_READY = "主设置界面尚未准备好。", MSG_MAIN_NOT_READY_LATER = "主界面尚未准备好，请稍后再试。", MSG_NO_TTS = "当前没有可用的TTS语音。", MSG_TTS_FAILED = "TTS播放失败: %s", MSG_NO_CUSTOM_AUDIO = "当前客户端无法播放自定义音频。", MSG_SOUND_FAILED = "语音文件播放失败，请检查路径: %s", MSG_NO_SOUND_PATH = "这条技能未填写语音文件路径。", MSG_NO_CAST_SOUND_PATH = "施法成功提示未填写语音文件路径。", MSG_NO_BLOODLUST_SOUND_PATH = "嗜血提示未填写语音路径。", MSG_LOADED = "已载入，输入 /qfxsa 或 /qfxskillalerts 打开配置。", MSG_SCOPE_COUNT = "当前保存作用域已保存 %d 条技能配置。", MSG_CURRENT_EDIT_SCOPE = "当前职业专精：%s / %s", MSG_SELECTED_NOT_EXIST = "选中的配置不存在。", MSG_INVALID_CLASS_SPEC = "职业或专精无效。", MSG_INVALID_SPELL_ID = "技能ID无效。", MSG_INVALID_FIXED_CD = "固定CD无效。", MSG_NEED_TALENT_ID = "已启用检查天赋，请填写有效的天赋ID。", MSG_NEED_TALENT_CD = "已启用检查天赋，请填写有效的 CD变为（秒）。", MSG_NEED_TTS_TEXT = "已启用TTS，请填写播报文本。", MSG_NEED_SOUND_PATH = "已启用语音文件，请填写语音路径。", MSG_NEED_ALERT_ACTIONS = "请至少选择一种提示方式：声音、图片或文本。", MSG_DUP_SPELL = "当前专精下已经存在相同的技能ID。", MSG_SAVE_LIMIT = "已达到保存上限。", MSG_CONFIG_SAVED = "配置已保存。", MSG_CHOOSE_CONFIG = "请先选择一条配置。", MSG_CONFIG_DELETED = "配置已删除。", MSG_IMPORT_FAILED = "导入失败：%s", MSG_IMPORT_UNKNOWN_TYPE = "导入失败：未知导入类型。", MSG_IMPORT_DONE = "导入完成：%s，处理 %d 条语音配置。", MSG_IMPORT_EMPTY = "导入失败：没有可导入的数据。", MSG_MENU_MISSING = "当前客户端未加载右键菜单组件，请使用上方编辑/删除按钮。", MSG_DRAG_UNLOADED_TO_ROOT = "未载入条目不能单独拖到已载入区域，只能拖入已载入合集。", MSG_DRAG_UNLOADED_TO_GROUP = "已把未载入语音加入当前合集，状态会以红色圆点显示。",
    TTS_READY_DEFAULT = "好了", TTS_CAST_SUCCESS_DEFAULT = "施法成功", FALLBACK_CLASS = "职业%s", FALLBACK_SPEC = "专精%s",
}, { __index = enUS })

local zhTW = setmetatable({
    ADDON_DISPLAY_NAME = "QFX 技能提醒", ADDON_SHORT_NAME = "QFX 技能提醒", OPTION_NAME = "QFX 技能提醒", AUTHOR_LINE = "作者：zhufei1000",
    OPTIONS_DESC = "固定冷卻技能語音提醒插件：透過 UNIT_SPELLCAST_SUCCEEDED 記錄施法成功事件，依照你填寫的固定冷卻計時，並在冷卻結束、施法成功或嗜血觸發時播放 TTS 或語音檔。\n\n點擊下方按鈕可開啟主設定介面；也可以使用 /qfxsa 或點擊小地圖圖示開啟。", OPEN_MAIN_SETTINGS = "開啟主設定介面", COMMANDS = "指令：/qfxsa 或 /qfxskillalerts",
    BTN_ADD_VOICE = "新增", BTN_ADD_COLLECTION = "新增合集", BTN_EDIT = "編輯", BTN_DELETE = "刪除", BTN_REFRESH = "重新整理", BTN_IMPORT = "匯入", BTN_EXPORT_FULL = "全量匯出", BTN_SAVE = "儲存", BTN_TEST = "試聽", BTN_CLOSE = "關閉", BTN_SELECT_ALL = "全選",
    TITLE_NEW_CONFIG = "新增設定", TITLE_EDIT_CONFIG = "編輯設定", TITLE_BLOODLUST_SETTINGS = "嗜血提示設定", TITLE_ADD_COLLECTION = "新增合集", TITLE_RENAME_COLLECTION = "重命名合集", TITLE_IMPORT_EXPORT = "匯入 / 匯出", TITLE_EXPORT = "匯出", TITLE_IMPORT_SETTINGS = "匯入設定", EXPORT_ENTRY = "匯出單條資訊", EXPORT_COLLECTION = "匯出合集", DELETE_ENTRY = "刪除設定", EDIT_ENTRY = "編輯設定", DELETE_COLLECTION_WITH_ITEMS = "刪除合集和其中語音", EXPAND_COLLECTION = "展開合集", COLLAPSE_COLLECTION = "收合合集", EXPORT_FULL_TITLE = "全量匯出",
    TAB_COOLDOWN = "CD提示", TAB_CAST = "施法成功", TAB_BLOODLUST = "嗜血提示", SECTION_CLASS_SPEC = "職業 / 專精", LABEL_CLASS = "職業", LABEL_SPEC = "專精", SECTION_SPELL_PARAMS = "技能參數", LABEL_SPELL_ID = "技能ID", LABEL_SPELL_NAME = "技能名稱", LABEL_FIXED_CD_SEC = "固定CD（秒）", LABEL_CHECK_TALENT = "檢查天賦", LABEL_TALENT_ID = "天賦ID", LABEL_TALENT_NAME = "天賦名稱", LABEL_TALENT_CD_SEC = "CD變為（秒）", SECTION_NOTIFY = "通知方式", LABEL_BUILTIN_SOUND = "內建語音", LABEL_USE_CUSTOM_SOUND = "啟用自訂語音路徑", LABEL_USE_TTS = "啟用 TTS 文字", LABEL_TTS_RATE = "TTS 語速", EDITOR_HINT = "四種來源互斥：內建語音、共享媒體、自訂路徑、TTS。儲存前可點擊底部「試聽」確認。", SECTION_BLOODLUST_SOUND = "嗜血音效設定", LABEL_SOUND_PATH_N = "語音路徑 %d", BLOODLUST_HINT = "建議填寫 Interface\\AddOns\\EllesmereUIVE\\Media\\Sounds\\xxx.ogg 這樣的遊戲內路徑。未填寫的路徑不會加入隨機池。",
    PLACEHOLDER_SELECT_CLASS = "請選擇職業", PLACEHOLDER_SELECT_SPEC = "請選擇專精", PLACEHOLDER_SELECT_CLASSES = "請選擇職業", PLACEHOLDER_SELECT_SPECS = "請選擇專精", PLACEHOLDER_SELECT_BUILTIN_SOUND = "請選擇內建語音",
    COLLECTION_NAME = "合集名稱", COLLECTION_ICON_ID = "合集圖示ID（可選）", COLLECTION_ICON_HINT = "輸入遊戲內圖示 FileID，例如 134400。留空時使用預設合集圖示。", COLLECTION_HINT = "建立後顯示在已載入區域；已載入/未載入語音都可以拖入合集，合集內用綠/黃/紅圓點區分狀態。", COLLECTION_DEFAULT_NAME = "新建合集", COLLECTION_UNNAMED = "未命名合集", COLLECTION_LABEL = "合集", COLLECTION_COUNT = "%d 條", COLLECTION_EMPTY_COUNT = "（空）", DRAG_INTO_COLLECTION = "拖曳語音到這個合集裡",
    HEADER_LOADED = "已載入", HEADER_UNLOADED = "未載入", EMPTY_CONFIG = "暫無設定", ENTRY_TYPE_COOLDOWN = "CD提示", ENTRY_TYPE_CAST = "施法成功", ENTRY_TYPE_BLOODLUST = "嗜血提示", ENTRY_UNNAMED = "未命名", TALENT_ROW = "天賦:%s CD:%.2fs", TALENT_ROW_NO_CD = "天賦:%s", MODE_SOUND = "語音", LOADED_TAG = " |cff00ff00已載入|r", UNLOADED_TAG = " |cffff4040未載入|r",
    MINIMAP_LEFT = "左鍵：開啟主設定介面", MINIMAP_RIGHT = "右鍵：開啟系統選項頁", MINIMAP_DRAG = "拖曳：移動小地圖圖示", MINIMAP_ICON_FILE = "圖示檔案：AppIcon.png",
    TTS_READY_DEFAULT = "好了", TTS_CAST_SUCCESS_DEFAULT = "施法成功", FALLBACK_CLASS = "職業%s", FALLBACK_SPEC = "專精%s",
}, { __index = zhCN })


-- Additional legacy/utility UI strings.
enUS.BTN_CREATE = "Create"; enUS.BTN_CANCEL = "Cancel"
enUS.CREATE_CHILD_COLLECTION = "Create Child Group"; enUS.CREATE_VOICE_IN_COLLECTION = "Create Alert in Group"
enUS.MSG_BLOODLUST_SUMMARY = "After Bloodlust/Heroism is triggered, one of %d valid voice paths will be played randomly."
enUS.MSG_BLOODLUST_SAVED = "Bloodlust voice settings saved."
enUS.MSG_INVALID_SCOPE = "Please select a valid class/spec first."
enUS.MSG_COLLECTION_NAME_EMPTY = "Group name cannot be empty."
enUS.MSG_COLLECTION_ADDED = "Group added: %s"
enUS.MSG_COLLECTION_RENAMED = "Group renamed: %s"
enUS.MSG_COLLECTION_DELETED = "Group deleted, and %d alerts inside it were also deleted."
enUS.MSG_GROUP_SORT_ONLY_CURRENT = "Groups can only be sorted within the currently loaded spec."
enUS.MSG_UNLOADED_ONLY_TO_LOADED_GROUP = "Unloaded alerts can only be dragged into groups in the currently loaded area."
enUS.MSG_EXPORT_MISSING_LIBS = "Export failed: AceSerializer or LibDeflate is missing."
enUS.MSG_EXPORT_DEFLATE_FAILED = "Export failed: data compression failed."
enUS.ERR_IMPORT_EMPTY = "Import string is empty."
enUS.ERR_IMPORT_MISSING_LIBS = "AceSerializer or LibDeflate is missing."
enUS.ERR_IMPORT_BAD_PREFIX = "This is not a QFX Skill Alerts import string."
enUS.ERR_IMPORT_DECODE_FAILED = "Import string decode failed."
enUS.ERR_IMPORT_DEFLATE_FAILED = "Import string decompression failed."
enUS.ERR_IMPORT_DESERIALIZE_FAILED = "Import string deserialization failed."
enUS.ERR_IMPORT_VERSION_MISMATCH = "Import string version mismatch."
enUS.MSG_EXPORT_ENTRY_NOT_FOUND = "Export failed: saved alert not found."
enUS.MSG_EXPORT_COLLECTION_INVALID = "Export failed: invalid group."
enUS.MSG_EXPORT_COLLECTION_NOT_FOUND = "Export failed: group not found."
enUS.IMPORT_COLLECTION_NAME = "Imported Group"
enUS.MODE_SOUND_FILE = "Voice file"; enUS.MODE_TTS_TEXT = "Text to speech"
enUS.STATUS_EXPAND = "Expand"; enUS.STATUS_COLLAPSE = "Collapse"
enUS.MSG_CHOOSE_SAVED_ENTRY = "Please select an alert in the saved area first."
enUS.MSG_ITEM_TRIGGER_PENDING_SAVED = "Item ID %s has been saved, but its use-trigger spell ID has not been resolved yet. It will be completed after combat ends or item data loads."
enUS.MSG_ITEM_TRIGGER_AUTO_FILLED = "Item use-trigger spell ID was completed automatically."
enUS.MSG_ITEM_TRIGGER_PENDING_RESOLVE = "Item ID %s has not resolved to a use-trigger spell ID yet. It is queued until item data loads or combat ends."

zhCN.BTN_CREATE = "创建"; zhCN.BTN_CANCEL = "取消"
zhCN.CREATE_CHILD_COLLECTION = "创建子合集"; zhCN.CREATE_VOICE_IN_COLLECTION = "创建语音"
zhCN.MSG_BLOODLUST_SUMMARY = "嗜血/英勇触发后将从 %d 条有效语音路径中随机播放。"
zhCN.MSG_BLOODLUST_SAVED = "嗜血语音配置已保存。"
zhCN.MSG_INVALID_SCOPE = "请先选择有效的职业/专精。"
zhCN.MSG_COLLECTION_NAME_EMPTY = "合集名称不能为空。"
zhCN.MSG_COLLECTION_ADDED = "已新增合集：%s"
zhCN.MSG_COLLECTION_RENAMED = "合集已重命名：%s"
zhCN.MSG_COLLECTION_DELETED = "合集已删除，并删除其中 %d 条语音配置。"
zhCN.MSG_GROUP_SORT_ONLY_CURRENT = "合集只能在当前已载入专精内排序。"
zhCN.MSG_UNLOADED_ONLY_TO_LOADED_GROUP = "未载入条目只能拖入当前已载入区域的合集。"
zhCN.MSG_EXPORT_MISSING_LIBS = "导出失败：缺少 AceSerializer 或 LibDeflate。"
zhCN.MSG_EXPORT_DEFLATE_FAILED = "导出失败：压缩数据失败。"
zhCN.ERR_IMPORT_EMPTY = "导入字符串为空。"
zhCN.ERR_IMPORT_MISSING_LIBS = "缺少 AceSerializer 或 LibDeflate。"
zhCN.ERR_IMPORT_BAD_PREFIX = "不是 QFX 技能提醒的导入字符串。"
zhCN.ERR_IMPORT_DECODE_FAILED = "导入字符串解码失败。"
zhCN.ERR_IMPORT_DEFLATE_FAILED = "导入字符串解压失败。"
zhCN.ERR_IMPORT_DESERIALIZE_FAILED = "导入字符串反序列化失败。"
zhCN.ERR_IMPORT_VERSION_MISMATCH = "导入字符串版本不匹配。"
zhCN.MSG_EXPORT_ENTRY_NOT_FOUND = "导出失败：找不到这条保存信息。"
zhCN.MSG_EXPORT_COLLECTION_INVALID = "导出失败：合集无效。"
zhCN.MSG_EXPORT_COLLECTION_NOT_FOUND = "导出失败：找不到合集。"
zhCN.IMPORT_COLLECTION_NAME = "导入合集"
zhCN.MODE_SOUND_FILE = "语音文件"; zhCN.MODE_TTS_TEXT = "文本转语音"
zhCN.STATUS_EXPAND = "展开"; zhCN.STATUS_COLLAPSE = "收拢"
zhCN.MSG_CHOOSE_SAVED_ENTRY = "请先在已保存区域选择一条配置。"
zhCN.MSG_ITEM_TRIGGER_PENDING_SAVED = "物品ID %s 已保存，但暂未解析到触发法术ID；脱战或物品资料加载后会自动补全。"
zhCN.MSG_ITEM_TRIGGER_AUTO_FILLED = "已自动补全物品触发法术ID。"
zhCN.MSG_ITEM_TRIGGER_PENDING_RESOLVE = "物品ID %s 暂时没有解析到触发法术ID，已等待物品资料加载或脱战后自动补全。"

zhTW.BTN_CREATE = "建立"; zhTW.BTN_CANCEL = "取消"
zhTW.CREATE_CHILD_COLLECTION = "建立子合集"; zhTW.CREATE_VOICE_IN_COLLECTION = "建立語音"
zhTW.MSG_BLOODLUST_SUMMARY = "嗜血/英勇觸發後將從 %d 條有效語音路徑中隨機播放。"
zhTW.MSG_BLOODLUST_SAVED = "嗜血語音設定已儲存。"
zhTW.MSG_INVALID_SCOPE = "請先選擇有效的職業/專精。"
zhTW.MSG_COLLECTION_NAME_EMPTY = "合集名稱不能為空。"
zhTW.MSG_COLLECTION_ADDED = "已新增合集：%s"
zhTW.MSG_COLLECTION_RENAMED = "合集已重新命名：%s"
zhTW.MSG_COLLECTION_DELETED = "合集已刪除，並刪除其中 %d 條語音設定。"
zhTW.MSG_GROUP_SORT_ONLY_CURRENT = "合集只能在目前已載入專精內排序。"
zhTW.MSG_UNLOADED_ONLY_TO_LOADED_GROUP = "未載入條目只能拖入目前已載入區域的合集。"
zhTW.MSG_EXPORT_MISSING_LIBS = "匯出失敗：缺少 AceSerializer 或 LibDeflate。"
zhTW.MSG_EXPORT_DEFLATE_FAILED = "匯出失敗：壓縮資料失敗。"
zhTW.ERR_IMPORT_EMPTY = "匯入字串為空。"
zhTW.ERR_IMPORT_MISSING_LIBS = "缺少 AceSerializer 或 LibDeflate。"
zhTW.ERR_IMPORT_BAD_PREFIX = "不是 QFX 技能提醒的匯入字串。"
zhTW.ERR_IMPORT_DECODE_FAILED = "匯入字串解碼失敗。"
zhTW.ERR_IMPORT_DEFLATE_FAILED = "匯入字串解壓失敗。"
zhTW.ERR_IMPORT_DESERIALIZE_FAILED = "匯入字串反序列化失敗。"
zhTW.ERR_IMPORT_VERSION_MISMATCH = "匯入字串版本不相符。"
zhTW.MSG_EXPORT_ENTRY_NOT_FOUND = "匯出失敗：找不到這條儲存資訊。"
zhTW.MSG_EXPORT_COLLECTION_INVALID = "匯出失敗：合集無效。"
zhTW.MSG_EXPORT_COLLECTION_NOT_FOUND = "匯出失敗：找不到合集。"
zhTW.IMPORT_COLLECTION_NAME = "匯入合集"
zhTW.MODE_SOUND_FILE = "語音檔"; zhTW.MODE_TTS_TEXT = "文字轉語音"
zhTW.STATUS_EXPAND = "展開"; zhTW.STATUS_COLLAPSE = "收合"
zhTW.MSG_CHOOSE_SAVED_ENTRY = "請先在已儲存區域選擇一條設定。"
zhTW.MSG_ITEM_TRIGGER_PENDING_SAVED = "物品ID %s 已儲存，但暫未解析到觸發法術ID；脫戰或物品資料載入後會自動補全。"
zhTW.MSG_ITEM_TRIGGER_AUTO_FILLED = "已自動補全物品觸發法術ID。"
zhTW.MSG_ITEM_TRIGGER_PENDING_RESOLVE = "物品ID %s 暫時沒有解析到觸發法術ID，已等待物品資料載入或脫戰後自動補全。"



zhTW.EXPORT_DESC = "下面是壓縮後的匯出字串。點擊「全選」後用 Ctrl+C 複製；匯入時把這段字串貼到同一個視窗。"
zhTW.IMPORT_DESC = "貼上 QFX 技能提醒匯出字串後點擊「匯入」。支援單條資訊、合集和全量匯入；全量匯入會取代目前已儲存提示、合集、排序、嗜血、小地圖、語言和介面外觀設定。"
zhTW.MSG_MAIN_NOT_READY = "主設定介面尚未準備好。"
zhTW.MSG_MAIN_NOT_READY_LATER = "主介面尚未準備好，請稍後再試。"
zhTW.MSG_NO_TTS = "目前沒有可用的 TTS 語音。"
zhTW.MSG_TTS_FAILED = "TTS播放失敗: %s"
zhTW.MSG_NO_CUSTOM_AUDIO = "目前客戶端無法播放自訂音訊。"
zhTW.MSG_SOUND_FAILED = "語音檔播放失敗，請檢查路徑: %s"
zhTW.MSG_NO_SOUND_PATH = "這條技能未填寫語音檔路徑。"
zhTW.MSG_NO_CAST_SOUND_PATH = "施法成功提示未填寫語音檔路徑。"
zhTW.MSG_NO_BLOODLUST_SOUND_PATH = "嗜血提示未填寫語音路徑。"
zhTW.MSG_LOADED = "已載入，輸入 /qfxsa 或 /qfxskillalerts 開啟設定。"
zhTW.MSG_SCOPE_COUNT = "目前儲存作用域已儲存 %d 條技能設定。"
zhTW.MSG_CURRENT_EDIT_SCOPE = "目前職業專精：%s / %s"
zhTW.MSG_SELECTED_NOT_EXIST = "選中的設定不存在。"
zhTW.MSG_INVALID_CLASS_SPEC = "職業或專精無效。"
zhTW.MSG_INVALID_SPELL_ID = "技能ID無效。"
zhTW.MSG_INVALID_FIXED_CD = "固定CD無效。"
zhTW.MSG_NEED_TALENT_ID = "已啟用檢查天賦，請填寫有效的天賦ID。"
zhTW.MSG_NEED_TALENT_CD = "已啟用檢查天賦，請填寫有效的 CD變為（秒）。"
zhTW.MSG_NEED_TTS_TEXT = "已啟用TTS，請填寫播報文字。"
zhTW.MSG_NEED_SOUND_PATH = "已啟用語音檔，請填寫語音路徑。"
zhTW.MSG_NEED_ALERT_ACTIONS = "請至少選擇一種提示方式：聲音、圖片或文字。"
zhTW.MSG_DUP_SPELL = "目前專精下已經存在相同的技能ID。"
zhTW.MSG_SAVE_LIMIT = "已達到儲存上限。"
zhTW.MSG_CONFIG_SAVED = "設定已儲存。"
zhTW.MSG_CHOOSE_CONFIG = "請先選擇一條設定。"
zhTW.MSG_CONFIG_DELETED = "設定已刪除。"
zhTW.MSG_IMPORT_FAILED = "匯入失敗：%s"
zhTW.MSG_IMPORT_UNKNOWN_TYPE = "匯入失敗：未知匯入類型。"
zhTW.MSG_IMPORT_DONE = "匯入完成：%s，處理 %d 條語音設定。"
zhTW.MSG_IMPORT_EMPTY = "匯入失敗：沒有可匯入的資料。"
zhTW.MSG_MENU_MISSING = "目前客戶端未載入右鍵選單元件，請使用上方編輯/刪除按鈕。"
zhTW.MSG_DRAG_UNLOADED_TO_ROOT = "未載入條目不能單獨拖到已載入區域，只能拖入已載入合集。"
zhTW.MSG_DRAG_UNLOADED_TO_GROUP = "已把未載入語音加入目前合集，狀態會以紅色圓點顯示。"

enUS.LABEL_SCOPE = "Scope"
enUS.BTN_SCOPE_SELECT = "Select Scope"
enUS.SCOPE_SELECT_TITLE = "Select Race / Class / Spec"
enUS.SCOPE_RACE_SECTION = "Race"
enUS.SCOPE_CLASS_SPEC_SECTION = "Class / Spec"
enUS.SCOPE_ALL_RACES = "All Races"
enUS.SCOPE_ALL_CLASSES = "All Classes"
enUS.SCOPE_ALL_SPECS = "All Specs"
enUS.SCOPE_RACE_COUNT = "%d Races"
enUS.SCOPE_CLASS_COUNT = "%d Classes"
enUS.SCOPE_SPEC_COUNT = "%d Specs"
enUS.SCOPE_APPLY = "Apply"
enUS.SCOPE_CANCEL = "Cancel"
enUS.PLACEHOLDER_SELECT_RACES = "Select Races"
enUS.SAVED_SCOPE_RACES = "Race:%s"
enUS.COLLECTION_COUNT_MIXED = "%d items (%d loaded / %d unloaded)"

zhCN.LABEL_SCOPE = "适用范围"
zhCN.BTN_SCOPE_SELECT = "选择范围"
zhCN.SCOPE_SELECT_TITLE = "选择种族 / 职业 / 专精"
zhCN.SCOPE_RACE_SECTION = "种族选择"
zhCN.SCOPE_CLASS_SPEC_SECTION = "职业专精"
zhCN.SCOPE_ALL_RACES = "全种族"
zhCN.SCOPE_ALL_CLASSES = "全职业"
zhCN.SCOPE_ALL_SPECS = "全专精"
zhCN.SCOPE_RACE_COUNT = "%d 个种族"
zhCN.SCOPE_CLASS_COUNT = "%d 个职业"
zhCN.SCOPE_SPEC_COUNT = "%d 个专精"
zhCN.SCOPE_APPLY = "应用"
zhCN.SCOPE_CANCEL = "取消"
zhCN.PLACEHOLDER_SELECT_RACES = "选择种族"
zhCN.SAVED_SCOPE_RACES = "种族:%s"
zhCN.COLLECTION_COUNT_MIXED = "%d 条（已载入 %d / 未载入 %d）"

zhTW.LABEL_SCOPE = "適用範圍"
zhTW.BTN_SCOPE_SELECT = "選擇範圍"
zhTW.SCOPE_SELECT_TITLE = "選擇種族 / 職業 / 專精"
zhTW.SCOPE_RACE_SECTION = "種族選擇"
zhTW.SCOPE_CLASS_SPEC_SECTION = "職業專精"
zhTW.SCOPE_ALL_RACES = "全種族"
zhTW.SCOPE_ALL_CLASSES = "全職業"
zhTW.SCOPE_ALL_SPECS = "全專精"
zhTW.SCOPE_RACE_COUNT = "%d 個種族"
zhTW.SCOPE_CLASS_COUNT = "%d 個職業"
zhTW.SCOPE_SPEC_COUNT = "%d 個專精"
zhTW.SCOPE_APPLY = "套用"
zhTW.SCOPE_CANCEL = "取消"
zhTW.PLACEHOLDER_SELECT_RACES = "選擇種族"
zhTW.SAVED_SCOPE_RACES = "種族:%s"
zhTW.COLLECTION_COUNT_MIXED = "%d 條（已載入 %d / 未載入 %d）"

enUS.BTN_IMPORT_RURUTIA_PRESET = "Import Rurutia"
zhCN.BTN_IMPORT_RURUTIA_PRESET = "导入露露预设"
zhTW.BTN_IMPORT_RURUTIA_PRESET = "匯入露露預設"

enUS.ALL_SPECS = "All Specs"
zhCN.ALL_SPECS = "全专精"
zhTW.ALL_SPECS = "全專精"


-- All class / all spec and spell-or-item unified labels.
enUS.ALL_CLASSES = "All Classes"
zhCN.ALL_CLASSES = "全职业"
zhTW.ALL_CLASSES = "全職業"

enUS.ALL_SPECS = enUS.ALL_SPECS or "All Specs"
zhCN.ALL_SPECS = zhCN.ALL_SPECS or "全专精"
zhTW.ALL_SPECS = zhTW.ALL_SPECS or "全專精"

enUS.LABEL_SPELL_ID = "Spell / Item ID"
zhCN.LABEL_SPELL_ID = "技能/物品ID"
zhTW.LABEL_SPELL_ID = "技能/物品ID"

enUS.LABEL_SPELL_NAME = "Spell / Item Name"
zhCN.LABEL_SPELL_NAME = "技能/物品名称"
zhTW.LABEL_SPELL_NAME = "技能/物品名稱"

enUS.MSG_INVALID_SPELL_ID = "Spell / item ID is invalid."
zhCN.MSG_INVALID_SPELL_ID = "技能/物品ID无效。"
zhTW.MSG_INVALID_SPELL_ID = "技能/物品ID無效。"

enUS.MSG_DUP_SPELL = "The current scope already has the same spell/item ID and alert type."
zhCN.MSG_DUP_SPELL = "当前范围下已经存在相同的技能/物品ID和提醒类型。"
zhTW.MSG_DUP_SPELL = "目前範圍下已經存在相同的技能/物品ID和提醒類型。"

enUS.MSG_NO_SOUND_PATH = "This spell/item has no voice file path."
zhCN.MSG_NO_SOUND_PATH = "这条技能/物品未填写语音文件路径。"
zhTW.MSG_NO_SOUND_PATH = "這條技能/物品未填寫語音檔路徑。"

enUS.ENTRY_OBJECT_SPELL_ID = "Spell / Item ID"
zhCN.ENTRY_OBJECT_SPELL_ID = "技能/物品ID"
zhTW.ENTRY_OBJECT_SPELL_ID = "技能/物品ID"

enUS.ENTRY_OBJECT_ITEM_ID = "Spell / Item ID"
zhCN.ENTRY_OBJECT_ITEM_ID = "技能/物品ID"
zhTW.ENTRY_OBJECT_ITEM_ID = "技能/物品ID"



enUS.SECTION_SPELL_PARAMS = "Spell / Item Settings"
zhCN.SECTION_SPELL_PARAMS = "技能/物品参数"
zhTW.SECTION_SPELL_PARAMS = "技能/物品參數"

enUS.LABEL_IS_ITEM = "Item"
zhCN.LABEL_IS_ITEM = "物品"
zhTW.LABEL_IS_ITEM = "物品"

enUS.LABEL_ITEM_LOAD_EQUIPPED = "Check Equipped"
zhCN.LABEL_ITEM_LOAD_EQUIPPED = "检测装备"
zhTW.LABEL_ITEM_LOAD_EQUIPPED = "檢測裝備"

enUS.LABEL_ITEM_LOAD_BAGS = "Check Bags"
zhCN.LABEL_ITEM_LOAD_BAGS = "检测背包"
zhTW.LABEL_ITEM_LOAD_BAGS = "檢測背包"

enUS.LABEL_ITEM_LOAD_SAME_NAME = "Same Name"
zhCN.LABEL_ITEM_LOAD_SAME_NAME = "同名物品"
zhTW.LABEL_ITEM_LOAD_SAME_NAME = "同名物品"

enUS.SAVED_ITEM_LOAD_EQUIPPED = "Load: Equipped"
zhCN.SAVED_ITEM_LOAD_EQUIPPED = "载入：已装备"
zhTW.SAVED_ITEM_LOAD_EQUIPPED = "載入：已裝備"

enUS.SAVED_ITEM_LOAD_BAGS = "Load: In bags"
zhCN.SAVED_ITEM_LOAD_BAGS = "载入：背包内"
zhTW.SAVED_ITEM_LOAD_BAGS = "載入：背包內"

enUS.SAVED_ITEM_LOAD_SAME_NAME = "Same name"
zhCN.SAVED_ITEM_LOAD_SAME_NAME = "同名"
zhTW.SAVED_ITEM_LOAD_SAME_NAME = "同名"
enUS.LABEL_ITEM_ID = "Item ID"
zhCN.LABEL_ITEM_ID = "物品ID"
zhTW.LABEL_ITEM_ID = "物品ID"
enUS.LABEL_OBJECT_SPELL_ID = "Spell ID"
zhCN.LABEL_OBJECT_SPELL_ID = "技能ID"
zhTW.LABEL_OBJECT_SPELL_ID = "技能ID"


-- Collection rename labels.
enUS.TITLE_RENAME_COLLECTION = enUS.TITLE_RENAME_COLLECTION or "Rename Group"
zhCN.TITLE_RENAME_COLLECTION = zhCN.TITLE_RENAME_COLLECTION or "重命名合集"
zhTW.TITLE_RENAME_COLLECTION = zhTW.TITLE_RENAME_COLLECTION or "重新命名合集"
enUS.RENAME_COLLECTION = enUS.RENAME_COLLECTION or "Rename Group"
zhCN.RENAME_COLLECTION = zhCN.RENAME_COLLECTION or "重命名合集"
zhTW.RENAME_COLLECTION = zhTW.RENAME_COLLECTION or "重新命名合集"
enUS.MSG_COLLECTION_RENAMED = enUS.MSG_COLLECTION_RENAMED or "Group renamed: %s"
zhCN.MSG_COLLECTION_RENAMED = zhCN.MSG_COLLECTION_RENAMED or "合集已重命名：%s"
zhTW.MSG_COLLECTION_RENAMED = zhTW.MSG_COLLECTION_RENAMED or "合集已重新命名：%s"

-- Saved list voice detail labels.
enUS.SAVED_VOICE_BUILTIN = "Voice  Built-in: %s"
zhCN.SAVED_VOICE_BUILTIN = "语音  内置语音：%s"
zhTW.SAVED_VOICE_BUILTIN = "語音  內建語音：%s"

enUS.SAVED_VOICE_CUSTOM = "Voice  Custom: %s"
zhCN.SAVED_VOICE_CUSTOM = "语音  自定义语音：%s"
zhTW.SAVED_VOICE_CUSTOM = "語音  自訂語音：%s"

enUS.SAVED_VOICE_TTS = "Voice  TTS text: %s"
zhCN.SAVED_VOICE_TTS = "语音  TTS文本：%s"
zhTW.SAVED_VOICE_TTS = "語音  TTS文字：%s"

enUS.SAVED_VOICE_SHAREDMEDIA = "Voice  SharedMedia: %s"
zhCN.SAVED_VOICE_SHAREDMEDIA = "语音  共享媒体：%s"
zhTW.SAVED_VOICE_SHAREDMEDIA = "語音  共享媒體：%s"

enUS.LABEL_SHAREDMEDIA_SOUND = "SharedMedia Sound"
zhCN.LABEL_SHAREDMEDIA_SOUND = "共享媒体语音"
zhTW.LABEL_SHAREDMEDIA_SOUND = "共享媒體語音"
enUS.LABEL_SOUND_SOURCE = "Voice Source"
zhCN.LABEL_SOUND_SOURCE = "语音来源"
zhTW.LABEL_SOUND_SOURCE = "語音來源"
enUS.SOURCE_BUILTIN = "Built-in Sound"
zhCN.SOURCE_BUILTIN = "内置语音"
zhTW.SOURCE_BUILTIN = "內建語音"
enUS.SOURCE_SHAREDMEDIA = "LibSharedMedia"
zhCN.SOURCE_SHAREDMEDIA = "共享媒体"
zhTW.SOURCE_SHAREDMEDIA = "共享媒體"
enUS.SOURCE_CUSTOM = "Custom Path"
zhCN.SOURCE_CUSTOM = "自定义路径"
zhTW.SOURCE_CUSTOM = "自訂路徑"
enUS.SOURCE_TTS = "TTS Text"
zhCN.SOURCE_TTS = "TTS 文本"
zhTW.SOURCE_TTS = "TTS 文字"

enUS.PLACEHOLDER_SELECT_SHAREDMEDIA_SOUND = "Select SharedMedia sound"
zhCN.PLACEHOLDER_SELECT_SHAREDMEDIA_SOUND = "选择共享媒体语音"
zhTW.PLACEHOLDER_SELECT_SHAREDMEDIA_SOUND = "選擇共享媒體語音"

-- Manual language switching and cast-success delay labels.
enUS.LABEL_LANGUAGE = "Language"
zhCN.LABEL_LANGUAGE = "语言"
zhTW.LABEL_LANGUAGE = "語言"

enUS.LANGUAGE_AUTO = "Follow Client"
zhCN.LANGUAGE_AUTO = "跟随客户端"
zhTW.LANGUAGE_AUTO = "跟隨客戶端"

enUS.LANGUAGE_ENUS = "English"
zhCN.LANGUAGE_ENUS = "English"
zhTW.LANGUAGE_ENUS = "English"

enUS.LANGUAGE_ZHCN = "简体中文"
zhCN.LANGUAGE_ZHCN = "简体中文"
zhTW.LANGUAGE_ZHCN = "簡體中文"

enUS.LANGUAGE_ZHTW = "繁體中文"
zhCN.LANGUAGE_ZHTW = "繁体中文"
zhTW.LANGUAGE_ZHTW = "繁體中文"

-- External skin mode labels.
enUS.LABEL_UI_SKIN_MODE = "UI Skin"
zhCN.LABEL_UI_SKIN_MODE = "界面皮肤"
zhTW.LABEL_UI_SKIN_MODE = "介面皮膚"

enUS.SKIN_MODE_AUTO = "Auto"
zhCN.SKIN_MODE_AUTO = "自动"
zhTW.SKIN_MODE_AUTO = "自動"

enUS.SKIN_MODE_EXTERNAL = "External Skin"
zhCN.SKIN_MODE_EXTERNAL = "外部皮肤"
zhTW.SKIN_MODE_EXTERNAL = "外部皮膚"

enUS.SKIN_MODE_QFX = "QFX Default"
zhCN.SKIN_MODE_QFX = "QFX 默认"
zhTW.SKIN_MODE_QFX = "QFX 預設"

enUS.MSG_SKIN_CHANGED = "UI skin mode changed: %s. Reopen the window if some controls were already created."
zhCN.MSG_SKIN_CHANGED = "界面皮肤模式已切换：%s。部分已创建控件需要重新打开窗口后完全生效。"
zhTW.MSG_SKIN_CHANGED = "介面皮膚模式已切換：%s。部分已建立控制項需要重新開啟視窗後完全生效。"

enUS.MSG_LANGUAGE_CHANGED = "Language switched to: %s"
zhCN.MSG_LANGUAGE_CHANGED = "语言已切换为：%s"
zhTW.MSG_LANGUAGE_CHANGED = "語言已切換為：%s"

enUS.LABEL_DELAY_CAST_SUCCESS = "Delay playback"
zhCN.LABEL_DELAY_CAST_SUCCESS = "延时播放"
zhTW.LABEL_DELAY_CAST_SUCCESS = "延時播放"

enUS.LABEL_DELAY_SECONDS = "Delay (sec)"
zhCN.LABEL_DELAY_SECONDS = "延时（秒）"
zhTW.LABEL_DELAY_SECONDS = "延時（秒）"

enUS.MSG_INVALID_DELAY_SECONDS = "Delay playback is enabled. Please enter a delay greater than 0 seconds."
zhCN.MSG_INVALID_DELAY_SECONDS = "已启用延时播放，请填写大于 0 的延时秒数。"
zhTW.MSG_INVALID_DELAY_SECONDS = "已啟用延時播放，請填寫大於 0 的延時秒數。"

enUS.SAVED_CAST_DELAY = "Delay: %.2fs"
zhCN.SAVED_CAST_DELAY = "延时：%.2f秒"
zhTW.SAVED_CAST_DELAY = "延時：%.2f秒"

enUS.EDITOR_HINT = "Choose a built-in sound, a LibSharedMedia sound, or enable a custom path / TTS. Click \"Test\" before saving to confirm."
zhCN.EDITOR_HINT = "四种来源互斥：内置语音、LibSharedMedia 共享媒体、自定义路径、TTS。保存前可点击底部“试听”确认。"
zhTW.EDITOR_HINT = "四種來源互斥：內建語音、LibSharedMedia 共享媒體、自訂路徑、TTS。儲存前可點擊底部「試聽」確認。"


-- Popup editor architecture labels.
enUS.EDITOR_DESC = "Configure trigger scope, spell parameters, and the single voice source used by this alert."
zhCN.EDITOR_DESC = "按统一弹窗结构配置作用域、技能参数和本条语音唯一使用的来源。"
zhTW.EDITOR_DESC = "依統一彈窗結構設定作用域、技能參數與本條語音唯一使用的來源。"

enUS.LABEL_CUSTOM_SOUND_PATH = "Custom Sound Path"
zhCN.LABEL_CUSTOM_SOUND_PATH = "自定义语音路径"
zhTW.LABEL_CUSTOM_SOUND_PATH = "自訂語音路徑"

enUS.LABEL_TTS_TEXT = "TTS Text"
zhCN.LABEL_TTS_TEXT = "TTS 文本"
zhTW.LABEL_TTS_TEXT = "TTS 文字"

enUS.EDITOR_HINT = "Voice Source is the only mode selector. Built-in, LibSharedMedia, Custom Path, and TTS are mutually exclusive. Click Test before saving."
zhCN.EDITOR_HINT = "“语音来源”下拉菜单是唯一模式选择入口：内置语音、LibSharedMedia、自定义路径、TTS 四选一。保存前可点击“试听”确认。"
zhTW.EDITOR_HINT = "「語音來源」下拉選單是唯一模式選擇入口：內建語音、LibSharedMedia、自訂路徑、TTS 四選一。儲存前可點擊「試聽」確認。"

enUS.ADDON_DISPLAY_NAME = "EllesmereUIVE"
enUS.ADDON_SHORT_NAME = "EUIVE"
enUS.OPTION_NAME = "EllesmereUIVE"
enUS.TAB_COOLDOWN = "EUI Voice Editor"
enUS.ENTRY_TYPE_COOLDOWN = "EUI Voice"
enUS.BTN_ADD_VOICE = "Add Voice"
enUS.BTN_SYNC_CURRENT_SPEC = "Sync Current Spec"
enUS.LABEL_EUI_TRIGGER = "Trigger Type"
enUS.TRIGGER_CD = "Cooldown ready"
enUS.TRIGGER_GAIN = "Buff gained"
enUS.TRIGGER_LOSS = "Buff lost"
enUS.BTN_SAVE_ONLY = "Save Only"
enUS.BTN_SAVE_AND_INJECT = "Save and Inject"
enUS.EUI_STATUS = "EUI: %s"

zhCN.ADDON_DISPLAY_NAME = "EllesmereUIVE"
zhCN.ADDON_SHORT_NAME = "EUIVE"
zhCN.OPTION_NAME = "EllesmereUIVE"
zhCN.TAB_COOLDOWN = "EUI语音编辑"
zhCN.ENTRY_TYPE_COOLDOWN = "EUI语音"
zhCN.BTN_ADD_VOICE = "添加语音"
zhCN.BTN_SYNC_CURRENT_SPEC = "同步当前专精"
zhCN.LABEL_EUI_TRIGGER = "触发类型"
zhCN.TRIGGER_CD = "冷却完成"
zhCN.TRIGGER_GAIN = "Buff获得"
zhCN.TRIGGER_LOSS = "Buff消失"
zhCN.BTN_SAVE_ONLY = "仅保存"
zhCN.BTN_SAVE_AND_INJECT = "保存并注入"
zhCN.EUI_STATUS = "EUI状态：%s"

zhTW.ADDON_DISPLAY_NAME = "EllesmereUIVE"
zhTW.ADDON_SHORT_NAME = "EUIVE"
zhTW.OPTION_NAME = "EllesmereUIVE"
zhTW.TAB_COOLDOWN = "EUI語音編輯"
zhTW.ENTRY_TYPE_COOLDOWN = "EUI語音"
zhTW.BTN_ADD_VOICE = "新增語音"
zhTW.BTN_SYNC_CURRENT_SPEC = "同步目前專精"
zhTW.LABEL_EUI_TRIGGER = "觸發類型"
zhTW.TRIGGER_CD = "冷卻完成"
zhTW.TRIGGER_GAIN = "Buff獲得"
zhTW.TRIGGER_LOSS = "Buff消失"
zhTW.BTN_SAVE_ONLY = "僅儲存"
zhTW.BTN_SAVE_AND_INJECT = "儲存並注入"
zhTW.EUI_STATUS = "EUI狀態：%s"

local selected = (activeLocale == "zhCN" and zhCN) or (activeLocale == "zhTW" and zhTW) or enUS
NS.L_TABLE = selected
NS.L_ENUS = enUS

function NS.L(key, ...)
    local value = selected[key] or enUS[key]
    if value == nil and type(RuntimeL) == "function" then
        return RuntimeL(key, ...)
    end
    value = value or tostring(key or "")
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, value, ...)
        if ok then return formatted end
    end
    return value
end

function NS.GetLanguageMode()
    return activeLanguageMode
end

function NS.GetActiveLocale()
    return activeLocale
end

function NS.GetLanguageDisplayName(mode)
    mode = NormalizeLanguageMode(mode)
    if mode == "zhCN" then
        return NS.L("LANGUAGE_ZHCN")
    elseif mode == "zhTW" then
        return NS.L("LANGUAGE_ZHTW")
    elseif mode == "enUS" then
        return NS.L("LANGUAGE_ENUS")
    end
    return NS.L("LANGUAGE_AUTO")
end

function NS.SetLanguageMode(mode)
    activeLanguageMode = NormalizeLanguageMode(mode)
    activeLocale = ResolveActiveLocale(activeLanguageMode)
    selected = (activeLocale == "zhCN" and zhCN) or (activeLocale == "zhTW" and zhTW) or enUS
    NS.LOCALE = activeLocale
    NS.L_TABLE = selected

    local db = rawget(_G, "EllesmereUIVEDB")
    if type(db) ~= "table" then
        db = {}
        _G.EllesmereUIVEDB = db
    end
    db.languageMode = activeLanguageMode

    NS.ADDON_DISPLAY_NAME = NS.L("ADDON_DISPLAY_NAME")
    NS.ADDON_SHORT_NAME = NS.L("ADDON_SHORT_NAME")
    return activeLocale, activeLanguageMode
end

NS.ADDON_DISPLAY_NAME = NS.L("ADDON_DISPLAY_NAME")
NS.ADDON_SHORT_NAME = NS.L("ADDON_SHORT_NAME")


-- Add-alert selector and multi-channel alert editor labels.
enUS.TITLE_SELECT_ALERT_TYPE = "Select Alert Type"
zhCN.TITLE_SELECT_ALERT_TYPE = "选择新增类型"
zhTW.TITLE_SELECT_ALERT_TYPE = "選擇新增類型"
enUS.SELECT_ALERT_TYPE_DESC = "Choose the alert type to create. The editor will open after selection."
zhCN.SELECT_ALERT_TYPE_DESC = "请选择要新增的提醒类型，选择后会自动打开对应编辑界面。"
zhTW.SELECT_ALERT_TYPE_DESC = "請選擇要新增的提醒類型，選擇後會自動開啟對應編輯介面。"

enUS.SELECT_ALERT_TYPE_COOLDOWN_DESC = "Fixed cooldown / ready reminders."
zhCN.SELECT_ALERT_TYPE_COOLDOWN_DESC = "技能固定冷却、冷却完成或提前提醒。"
zhTW.SELECT_ALERT_TYPE_COOLDOWN_DESC = "技能固定冷卻、冷卻完成或提前提醒。"
enUS.SELECT_ALERT_TYPE_CAST_DESC = "Alert immediately after a successful cast."
zhCN.SELECT_ALERT_TYPE_CAST_DESC = "技能施放成功后立即提示。"
zhTW.SELECT_ALERT_TYPE_CAST_DESC = "技能施放成功後立即提示。"
enUS.SELECT_ALERT_TYPE_BLOODLUST_DESC = "Built-in Bloodlust / Heroism / Time Warp detection."
zhCN.SELECT_ALERT_TYPE_BLOODLUST_DESC = "内置检测嗜血、英勇、时间扭曲等团队爆发。"
zhTW.SELECT_ALERT_TYPE_BLOODLUST_DESC = "內建偵測嗜血、英勇、時間扭曲等團隊爆發。"

enUS.SECTION_BLOODLUST_BUILTIN = "Built-in Detection"
zhCN.SECTION_BLOODLUST_BUILTIN = "内置检测"
zhTW.SECTION_BLOODLUST_BUILTIN = "內建偵測"
enUS.BLOODLUST_BUILTIN_HINT = "Bloodlust, Heroism, Time Warp and similar raid burst spells are detected by the addon automatically. No spell list setup is needed here. Configure Sound, Image, and Text tabs as needed."
zhCN.BLOODLUST_BUILTIN_HINT = "嗜血、英勇、时间扭曲等团队爆发技能由插件自动内置检测，这里不需要再设置技能列表。需要提示效果时，只设置“声音 / 图片 / 文本”即可。"
zhTW.BLOODLUST_BUILTIN_HINT = "嗜血、英勇、時間扭曲等團隊爆發技能由插件自動內建偵測，這裡不需要再設定技能列表。需要提示效果時，只設定「聲音 / 圖片 / 文字」即可。"



enUS.TAB_GROUP_TYPE = "Type"
zhCN.TAB_GROUP_TYPE = "类型"
zhTW.TAB_GROUP_TYPE = "類型"
enUS.TAB_GROUP_PAGE = "Page"
zhCN.TAB_GROUP_PAGE = "页面"
zhTW.TAB_GROUP_PAGE = "頁面"
enUS.TAB_SETTINGS = "Settings"
zhCN.TAB_SETTINGS = "设置"
zhTW.TAB_SETTINGS = "設定"
enUS.SECTION_NOTIFY_CONDITIONS = "Notification Conditions"
zhCN.SECTION_NOTIFY_CONDITIONS = "通知条件"
zhTW.SECTION_NOTIFY_CONDITIONS = "通知條件"
enUS.LABEL_CONDITION_WHEN = "When"
zhCN.LABEL_CONDITION_WHEN = "当"
zhTW.LABEL_CONDITION_WHEN = "當"
enUS.LABEL_COOLDOWN_REMAINING = "cooldown remaining"
zhCN.LABEL_COOLDOWN_REMAINING = "冷却剩余时间"
zhTW.LABEL_COOLDOWN_REMAINING = "冷卻剩餘時間"
enUS.LABEL_CONDITION_EXECUTE = "Execute"
zhCN.LABEL_CONDITION_EXECUTE = "执行"
zhTW.LABEL_CONDITION_EXECUTE = "執行"
enUS.PLACEHOLDER_SELECT_ALERT_ACTIONS = "Alert actions"
zhCN.PLACEHOLDER_SELECT_ALERT_ACTIONS = "提示方式"
zhTW.PLACEHOLDER_SELECT_ALERT_ACTIONS = "提示方式"
enUS.HINT_MULTI_SELECT_ACTIONS = "Multiple actions can be selected."
zhCN.HINT_MULTI_SELECT_ACTIONS = "可多选：声音、图片、文本。"
zhTW.HINT_MULTI_SELECT_ACTIONS = "可多選：聲音、圖片、文字。"
enUS.LABEL_VOICE_CONDITION = "Voice"
zhCN.LABEL_VOICE_CONDITION = "语音"
zhTW.LABEL_VOICE_CONDITION = "語音"
enUS.LABEL_IMAGE_CONDITION = "Image"
zhCN.LABEL_IMAGE_CONDITION = "图片"
zhTW.LABEL_IMAGE_CONDITION = "圖片"
enUS.LABEL_TEXT_CONDITION = "Text"
zhCN.LABEL_TEXT_CONDITION = "文本"
zhTW.LABEL_TEXT_CONDITION = "文字"
enUS.LABEL_SKILL_CD = "Skill CD"
zhCN.LABEL_SKILL_CD = "技能CD"
zhTW.LABEL_SKILL_CD = "技能CD"
enUS.LABEL_SECONDS_SHORT = "sec"
zhCN.LABEL_SECONDS_SHORT = "秒"
zhTW.LABEL_SECONDS_SHORT = "秒"

enUS.TAB_VOICE = "Sound"
zhCN.TAB_VOICE = "声音"
zhTW.TAB_VOICE = "聲音"
enUS.TAB_IMAGE = "Image"
zhCN.TAB_IMAGE = "图片"
zhTW.TAB_IMAGE = "圖片"
enUS.TAB_TEXT = "Text"
zhCN.TAB_TEXT = "文本"
zhTW.TAB_TEXT = "文字"
enUS.LABEL_ENABLE_VOICE_ALERT = "Enable voice alert"
zhCN.LABEL_ENABLE_VOICE_ALERT = "启用语音提示"
zhTW.LABEL_ENABLE_VOICE_ALERT = "啟用語音提示"
enUS.LABEL_ENABLE_IMAGE_ALERT = "Enable image alert"
zhCN.LABEL_ENABLE_IMAGE_ALERT = "启用图片提示"
zhTW.LABEL_ENABLE_IMAGE_ALERT = "啟用圖片提示"
enUS.LABEL_ENABLE_TEXT_ALERT = "Enable text alert"
zhCN.LABEL_ENABLE_TEXT_ALERT = "启用文本提示"
zhTW.LABEL_ENABLE_TEXT_ALERT = "啟用文字提示"
enUS.LABEL_IMAGE_PATH = "Image / Icon Path"
zhCN.LABEL_IMAGE_PATH = "图片 / 图标路径"
zhTW.LABEL_IMAGE_PATH = "圖片 / 圖示路徑"
enUS.LABEL_IMAGE_SIZE = "Image Size"
zhCN.LABEL_IMAGE_SIZE = "图片大小"
zhTW.LABEL_IMAGE_SIZE = "圖片大小"
enUS.LABEL_IMAGE_DURATION = "Duration (sec)"
zhCN.LABEL_IMAGE_DURATION = "持续时间（秒）"
zhTW.LABEL_IMAGE_DURATION = "持續時間（秒）"
enUS.LABEL_TEXT_CONTENT = "Alert Text"
zhCN.LABEL_TEXT_CONTENT = "提示文本"
zhTW.LABEL_TEXT_CONTENT = "提示文字"
enUS.LABEL_TEXT_SIZE = "Text Size"
zhCN.LABEL_TEXT_SIZE = "文字大小"
zhTW.LABEL_TEXT_SIZE = "文字大小"
enUS.LABEL_TEXT_DURATION = "Duration (sec)"
zhCN.LABEL_TEXT_DURATION = "持续时间（秒）"
zhTW.LABEL_TEXT_DURATION = "持續時間（秒）"
enUS.LABEL_POSITION_X = "X Offset"
zhCN.LABEL_POSITION_X = "X位置"
zhTW.LABEL_POSITION_X = "X位置"
enUS.LABEL_POSITION_Y = "Y Offset"
zhCN.LABEL_POSITION_Y = "Y位置"
zhTW.LABEL_POSITION_Y = "Y位置"
enUS.LABEL_COOLDOWN_ALERT_TIME = "CD condition"
zhCN.LABEL_COOLDOWN_ALERT_TIME = "CD条件"
zhTW.LABEL_COOLDOWN_ALERT_TIME = "CD條件"
enUS.LABEL_ALERT_CONDITION = "CD condition"
zhCN.LABEL_ALERT_CONDITION = "条件：技能CD"
zhTW.LABEL_ALERT_CONDITION = "條件：技能CD"
enUS.EDITOR_VOICE_HINT = "Voice source and TTS settings. CD trigger conditions are now centralized on the Settings tab."
zhCN.EDITOR_VOICE_HINT = "这里设置语音来源和 TTS 内容。CD触发条件已集中到“设置”标签页。"
zhTW.EDITOR_VOICE_HINT = "這裡設定語音來源和 TTS 內容。CD觸發條件已集中到「設定」標籤頁。"
enUS.EDITOR_IMAGE_HINT = "Enter a texture path or FileID. X/Y are offsets from screen center; duration controls how long it stays visible."
zhCN.EDITOR_IMAGE_HINT = "填写贴图路径或 FileID。X/Y 是相对屏幕中心的位置偏移；持续时间控制显示多久。"
zhTW.EDITOR_IMAGE_HINT = "填寫貼圖路徑或 FileID。X/Y 是相對螢幕中心的位置偏移；持續時間控制顯示多久。"
enUS.EDITOR_TEXT_HINT = "Leave text empty to use the spell name or default Bloodlust text. X/Y are offsets from screen center."
zhCN.EDITOR_TEXT_HINT = "文本留空时使用技能名或默认嗜血文本。X/Y 是相对屏幕中心的位置偏移。"
zhTW.EDITOR_TEXT_HINT = "文字留空時使用技能名或預設嗜血文字。X/Y 是相對螢幕中心的位置偏移。"
enUS.MSG_BLOODLUST_SUMMARY = "Bloodlust alert can now use voice source, image, and text settings."
zhCN.MSG_BLOODLUST_SUMMARY = "嗜血提示现在可使用语音来源、图片和文本设置。"
zhTW.MSG_BLOODLUST_SUMMARY = "嗜血提示現在可使用語音來源、圖片與文字設定。"

-- QFX visual alert layout additions.
enUS.LABEL_IMAGE_SOURCE = "Image Source"
zhCN.LABEL_IMAGE_SOURCE = "图片来源"
zhTW.LABEL_IMAGE_SOURCE = "圖片來源"
enUS.IMAGE_SOURCE_AUTO = "Auto: spell/item icon"
zhCN.IMAGE_SOURCE_AUTO = "自动使用技能/物品图标"
zhTW.IMAGE_SOURCE_AUTO = "自動使用技能/物品圖示"
enUS.IMAGE_SOURCE_SPELL = "Spell ID icon"
zhCN.IMAGE_SOURCE_SPELL = "技能ID获取图标"
zhTW.IMAGE_SOURCE_SPELL = "技能ID取得圖示"
enUS.IMAGE_SOURCE_ITEM = "Item ID icon"
zhCN.IMAGE_SOURCE_ITEM = "物品ID获取图标"
zhTW.IMAGE_SOURCE_ITEM = "物品ID取得圖示"
enUS.IMAGE_SOURCE_ICON = "Icon FileID"
zhCN.IMAGE_SOURCE_ICON = "手动填写图标ID"
zhTW.IMAGE_SOURCE_ICON = "手動填寫圖示ID"
enUS.IMAGE_SOURCE_PATH = "Custom path"
zhCN.IMAGE_SOURCE_PATH = "自定义图片路径"
zhTW.IMAGE_SOURCE_PATH = "自訂圖片路徑"
enUS.LABEL_IMAGE_ICON_ID = "Icon FileID"
zhCN.LABEL_IMAGE_ICON_ID = "图标ID"
zhTW.LABEL_IMAGE_ICON_ID = "圖示ID"
enUS.LABEL_IMAGE_SPELL_ID = "Spell ID"
zhCN.LABEL_IMAGE_SPELL_ID = "技能ID"
zhTW.LABEL_IMAGE_SPELL_ID = "技能ID"
enUS.LABEL_IMAGE_ITEM_ID = "Item ID"
zhCN.LABEL_IMAGE_ITEM_ID = "物品ID"
zhTW.LABEL_IMAGE_ITEM_ID = "物品ID"
enUS.LABEL_LIMIT_IMAGE_DURATION = "Limit image duration"
zhCN.LABEL_LIMIT_IMAGE_DURATION = "限制图片显示时间"
zhTW.LABEL_LIMIT_IMAGE_DURATION = "限制圖片顯示時間"
enUS.LABEL_LIMIT_TEXT_DURATION = "Limit text duration"
zhCN.LABEL_LIMIT_TEXT_DURATION = "限制文本显示时间"
zhTW.LABEL_LIMIT_TEXT_DURATION = "限制文字顯示時間"
enUS.LABEL_IMAGE_POSITION = "Image position"
zhCN.LABEL_IMAGE_POSITION = "图片位置"
zhTW.LABEL_IMAGE_POSITION = "圖片位置"
enUS.LABEL_TEXT_POSITION = "Text position"
zhCN.LABEL_TEXT_POSITION = "文本位置"
zhTW.LABEL_TEXT_POSITION = "文字位置"
enUS.LABEL_TEXT_POSITION_NUDGE = "Text position fine tune"
zhCN.LABEL_TEXT_POSITION_NUDGE = "文本位置微调"
zhTW.LABEL_TEXT_POSITION_NUDGE = "文字位置微調"
enUS.LABEL_DRAG_POSITION = "Position preview"
zhCN.LABEL_DRAG_POSITION = "位置预览"
zhTW.LABEL_DRAG_POSITION = "位置預覽"
enUS.BTN_SHOW_PREVIEW = "Show all previews"
zhCN.BTN_SHOW_PREVIEW = "显示全部预览"
zhTW.BTN_SHOW_PREVIEW = "顯示全部預覽"
enUS.BTN_HIDE_PREVIEW = "Hide all previews"
zhCN.BTN_HIDE_PREVIEW = "隐藏全部预览"
zhTW.BTN_HIDE_PREVIEW = "隱藏全部預覽"
enUS.BTN_RESET = "Reset"
zhCN.BTN_RESET = "重置"
zhTW.BTN_RESET = "重置"
enUS.LABEL_IMAGE_NUDGE = "Image position fine tune"
zhCN.LABEL_IMAGE_NUDGE = "图片位置微调"
zhTW.LABEL_IMAGE_NUDGE = "圖片位置微調"
enUS.LABEL_TEXT_LAYOUT = "Text + image layout"
zhCN.LABEL_TEXT_LAYOUT = "图文组合布局"
zhTW.LABEL_TEXT_LAYOUT = "圖文組合佈局"
enUS.LABEL_TEXT_ATTACH_MODE = "Text position"
zhCN.LABEL_TEXT_ATTACH_MODE = "文本位置"
zhTW.LABEL_TEXT_ATTACH_MODE = "文字位置"
enUS.TEXT_ATTACH_OUTSIDE = "Outside image"
zhCN.TEXT_ATTACH_OUTSIDE = "图外"
zhTW.TEXT_ATTACH_OUTSIDE = "圖外"
enUS.TEXT_ATTACH_INSIDE = "Inside image"
zhCN.TEXT_ATTACH_INSIDE = "图内"
zhTW.TEXT_ATTACH_INSIDE = "圖內"
enUS.LABEL_TEXT_VALIGN = "Vertical align"
zhCN.LABEL_TEXT_VALIGN = "上下对齐"
zhTW.LABEL_TEXT_VALIGN = "上下對齊"
enUS.TEXT_VALIGN_TOP = "Top"
zhCN.TEXT_VALIGN_TOP = "上对齐"
zhTW.TEXT_VALIGN_TOP = "上對齊"
enUS.TEXT_VALIGN_MIDDLE = "Middle"
zhCN.TEXT_VALIGN_MIDDLE = "居中"
zhTW.TEXT_VALIGN_MIDDLE = "置中"
enUS.TEXT_VALIGN_BOTTOM = "Bottom"
zhCN.TEXT_VALIGN_BOTTOM = "下对齐"
zhTW.TEXT_VALIGN_BOTTOM = "下對齊"
enUS.LABEL_TEXT_HALIGN = "Horizontal align"
zhCN.LABEL_TEXT_HALIGN = "左右对齐"
zhTW.LABEL_TEXT_HALIGN = "左右對齊"
enUS.TEXT_HALIGN_LEFT = "Left"
zhCN.TEXT_HALIGN_LEFT = "左对齐"
zhTW.TEXT_HALIGN_LEFT = "左對齊"
enUS.TEXT_HALIGN_CENTER = "Center"
zhCN.TEXT_HALIGN_CENTER = "居中"
zhTW.TEXT_HALIGN_CENTER = "置中"
enUS.TEXT_HALIGN_RIGHT = "Right"
zhCN.TEXT_HALIGN_RIGHT = "右对齐"
zhTW.TEXT_HALIGN_RIGHT = "右對齊"
enUS.LABEL_TEXT_NUDGE = "Text fine tune"
zhCN.LABEL_TEXT_NUDGE = "文本微调"
zhTW.LABEL_TEXT_NUDGE = "文字微調"
enUS.LABEL_SECONDS_INPUT = "Seconds"
zhCN.LABEL_SECONDS_INPUT = "秒"
zhTW.LABEL_SECONDS_INPUT = "秒"
enUS.EDITOR_IMAGE_HINT = "Default uses the spell icon. Use Icon FileID or custom path only when needed. The preview can be dragged; coordinates are saved as integer pixels."
zhCN.EDITOR_IMAGE_HINT = "默认使用技能图标。只有需要时才填写图标ID或自定义路径。预览可直接拖动，坐标保存为整数像素。"
zhTW.EDITOR_IMAGE_HINT = "預設使用技能圖示。只有需要時才填寫圖示ID或自訂路徑。預覽可直接拖曳，座標儲存為整數像素。"
enUS.EDITOR_TEXT_HINT = "When image and text are both enabled, they are dragged as one group. Only the text fine tune arrows move text relative to the image."
zhCN.EDITOR_TEXT_HINT = "图片和文本同时开启时会作为一个整体拖动。只有文本微调箭头会让文本相对图片单独移动。"
zhTW.EDITOR_TEXT_HINT = "圖片和文字同時啟用時會作為一個整體拖曳。只有文字微調箭頭會讓文字相對圖片單獨移動。"

-- 1.0.156 cast-success notification condition UI.
enUS.LABEL_CAST_DELAY_FIXED = "Delay"
zhCN.LABEL_CAST_DELAY_FIXED = "延时"
zhTW.LABEL_CAST_DELAY_FIXED = "延時"
enUS.LABEL_CAST_DELAY_AFTER_EXECUTE = "sec later"
zhCN.LABEL_CAST_DELAY_AFTER_EXECUTE = "秒后"
zhTW.LABEL_CAST_DELAY_AFTER_EXECUTE = "秒後"
enUS.CAST_DELAY_MODE_SHOW = "Show"
zhCN.CAST_DELAY_MODE_SHOW = "显示"
zhTW.CAST_DELAY_MODE_SHOW = "顯示"
enUS.CAST_DELAY_MODE_HIDE = "Hide"
zhCN.CAST_DELAY_MODE_HIDE = "消失"
zhTW.CAST_DELAY_MODE_HIDE = "消失"

-- 1.0.158 cast-success execution mode UI.
enUS.LABEL_CAST_IMMEDIATE_EXECUTE = "Execute immediately"
zhCN.LABEL_CAST_IMMEDIATE_EXECUTE = "立即执行"
zhTW.LABEL_CAST_IMMEDIATE_EXECUTE = "立即執行"
enUS.LABEL_CAST_DELAY_EXECUTE = "Delay execute"
zhCN.LABEL_CAST_DELAY_EXECUTE = "延时执行"
zhTW.LABEL_CAST_DELAY_EXECUTE = "延時執行"

-- Custom alert type.
enUS.TAB_CUSTOM = "Custom"
zhCN.TAB_CUSTOM = "自定义"
zhTW.TAB_CUSTOM = "自訂"
enUS.ENTRY_TYPE_CUSTOM = "Custom"
zhCN.ENTRY_TYPE_CUSTOM = "自定义"
zhTW.ENTRY_TYPE_CUSTOM = "自訂"
enUS.SELECT_ALERT_TYPE_CUSTOM_DESC = "Run custom Lua code and trigger Sound / Image / Text from returned variables."
zhCN.SELECT_ALERT_TYPE_CUSTOM_DESC = "运行自定义 Lua 代码，并根据返回变量触发声音 / 图片 / 文本。"
zhTW.SELECT_ALERT_TYPE_CUSTOM_DESC = "執行自訂 Lua 程式碼，並依返回變數觸發聲音 / 圖片 / 文字。"
enUS.SECTION_CUSTOM_CODE = "Custom Trigger"
zhCN.SECTION_CUSTOM_CODE = "自定义触发"
zhTW.SECTION_CUSTOM_CODE = "自訂觸發"
enUS.SECTION_CUSTOM_LUA_CODE = "Custom Lua Code"
zhCN.SECTION_CUSTOM_LUA_CODE = "自定义 Lua 代码"
zhTW.SECTION_CUSTOM_LUA_CODE = "自訂 Lua 程式碼"
enUS.SECTION_CUSTOM_EXECUTE_NOTIFY = "Execution & Notification"
zhCN.SECTION_CUSTOM_EXECUTE_NOTIFY = "执行通知"
zhTW.SECTION_CUSTOM_EXECUTE_NOTIFY = "執行通知"
enUS.LABEL_CUSTOM_NAME = "Custom Name"
zhCN.LABEL_CUSTOM_NAME = "自定义名称"
zhTW.LABEL_CUSTOM_NAME = "自訂名稱"
enUS.LABEL_CUSTOM_EVENT_TRIGGER = "Event trigger"
zhCN.LABEL_CUSTOM_EVENT_TRIGGER = "事件触发"
zhTW.LABEL_CUSTOM_EVENT_TRIGGER = "事件觸發"
enUS.LABEL_CUSTOM_EVENTS = "Events"
zhCN.LABEL_CUSTOM_EVENTS = "事件"
zhTW.LABEL_CUSTOM_EVENTS = "事件"
enUS.PLACEHOLDER_SELECT_EVENTS = "Select events"
zhCN.PLACEHOLDER_SELECT_EVENTS = "选择事件"
zhTW.PLACEHOLDER_SELECT_EVENTS = "選擇事件"
enUS.LABEL_CUSTOM_EVENT_TEXT = "Custom events (comma or space separated)"
zhCN.LABEL_CUSTOM_EVENT_TEXT = "自定义事件（逗号或空格分隔）"
zhTW.LABEL_CUSTOM_EVENT_TEXT = "自訂事件（逗號或空格分隔）"
enUS.LABEL_CUSTOM_TICKER_TRIGGER = "Periodic execution"
zhCN.LABEL_CUSTOM_TICKER_TRIGGER = "周期执行"
zhTW.LABEL_CUSTOM_TICKER_TRIGGER = "週期執行"
enUS.LABEL_CUSTOM_INTERVAL = "Interval"
zhCN.LABEL_CUSTOM_INTERVAL = "间隔"
zhTW.LABEL_CUSTOM_INTERVAL = "間隔"
enUS.LABEL_CUSTOM_CODE = "Custom Lua Code"
zhCN.LABEL_CUSTOM_CODE = "自定义 Lua 代码"
zhTW.LABEL_CUSTOM_CODE = "自訂 Lua 程式碼"
enUS.BTN_CUSTOM_TEST = "Run and Extract Variables"
zhCN.BTN_CUSTOM_TEST = "执行并提取变量"
zhTW.BTN_CUSTOM_TEST = "執行並提取變數"
enUS.LABEL_CUSTOM_RESULT_VAR = "Variable"
zhCN.LABEL_CUSTOM_RESULT_VAR = "变量"
zhTW.LABEL_CUSTOM_RESULT_VAR = "變數"
enUS.LABEL_CUSTOM_COMPARE_VALUE = "Value / Expr"
zhCN.LABEL_CUSTOM_COMPARE_VALUE = "值/表达式"
zhTW.LABEL_CUSTOM_COMPARE_VALUE = "值/表達式"
enUS.BTN_ADD_CUSTOM_NOTIFY = "Add"
zhCN.BTN_ADD_CUSTOM_NOTIFY = "增加"
zhTW.BTN_ADD_CUSTOM_NOTIFY = "增加"
enUS.LABEL_CUSTOM_NOTIFY_N = "Condition %d"
zhCN.LABEL_CUSTOM_NOTIFY_N = "条件%d"
zhTW.LABEL_CUSTOM_NOTIFY_N = "條件%d"
enUS.LABEL_CUSTOM_CONDITION_LOGIC = "Condition Logic"
zhCN.LABEL_CUSTOM_CONDITION_LOGIC = "条件关系"
zhTW.LABEL_CUSTOM_CONDITION_LOGIC = "條件關係"
enUS.CUSTOM_CONDITION_OR = "Any condition"
zhCN.CUSTOM_CONDITION_OR = "或者：任意满足"
zhTW.CUSTOM_CONDITION_OR = "或者：任一滿足"
enUS.CUSTOM_CONDITION_AND = "All conditions"
zhCN.CUSTOM_CONDITION_AND = "并且：全部满足"
zhTW.CUSTOM_CONDITION_AND = "並且：全部滿足"
enUS.PLACEHOLDER_SELECT_VARIABLE = "Select variable"
zhCN.PLACEHOLDER_SELECT_VARIABLE = "选择变量"
zhTW.PLACEHOLDER_SELECT_VARIABLE = "選擇變數"
enUS.MSG_CUSTOM_CODE_EMPTY = "Please enter custom Lua code."
zhCN.MSG_CUSTOM_CODE_EMPTY = "请填写自定义 Lua 代码。"
zhTW.MSG_CUSTOM_CODE_EMPTY = "請填寫自訂 Lua 程式碼。"
enUS.MSG_CUSTOM_NEED_TRIGGER = "Please enable Event trigger or Periodic execution."
zhCN.MSG_CUSTOM_NEED_TRIGGER = "请至少启用事件触发或周期执行。"
zhTW.MSG_CUSTOM_NEED_TRIGGER = "請至少啟用事件觸發或週期執行。"
enUS.MSG_CUSTOM_NEED_RESULT_VAR = "Please run the code and select a returned variable."
zhCN.MSG_CUSTOM_NEED_RESULT_VAR = "请先执行代码并选择返回变量。"
zhTW.MSG_CUSTOM_NEED_RESULT_VAR = "請先執行程式碼並選擇返回變數。"
enUS.MSG_CUSTOM_TEST_OK = "Custom code returned %d variables."
zhCN.MSG_CUSTOM_TEST_OK = "自定义代码返回了 %d 个变量。"
zhTW.MSG_CUSTOM_TEST_OK = "自訂程式碼返回了 %d 個變數。"
enUS.MSG_CUSTOM_TEST_FAILED = "Custom code failed: %s"
zhCN.MSG_CUSTOM_TEST_FAILED = "自定义代码执行失败：%s"
zhTW.MSG_CUSTOM_TEST_FAILED = "自訂程式碼執行失敗：%s"
