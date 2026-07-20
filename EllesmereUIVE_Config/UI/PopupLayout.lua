local NS = rawget(_G, "EllesmereUIVENS") or {}
_G.EllesmereUIVENS = NS

NS.UI = NS.UI or {}
NS.UI.PopupLayout = NS.UI.PopupLayout or {}

local Layout = NS.UI.PopupLayout
local Widgets = NS.UI.Widgets
local Skin = NS.UI.Skin

--[[
QFX Skill Alerts 弹出窗口统一架构说明

目标：所有弹窗都按同一套结构写，后续只改本文件的尺寸/间距常量，
不要在业务逻辑里随意写散乱坐标。

标准弹窗结构：
1. Header：标题 + 说明文字 + 关闭按钮。
2. Tabs：标签按钮区，用于切换 CD提示 / 施法成功 / 嗜血提示。
3. ScrollHost：可滚动内容区。内容高度超过可视区域时，只滚动内容区。
4. Module：模块区。每个模块用分割线标题承载一组字段，例如：职业/专精、技能参数、通知方式。
5. Controls：控件区。字段按统一列宽摆放；控件外观回归原生友好风格。
   按钮、输入框、勾选框、下拉菜单、滑条优先使用 Blizzard 原生模板，
   不再自绘复杂箭头、边框和复选框，便于 ElvUI / NDui 自动接管。
   外观层使用 Auto Skin Friendly：自动检测 ElvUI / NDui；不在主界面提供皮肤选择下拉。
6. Footer：固定底部按钮区，例如 保存 / 试听。

语音来源规则：
- “语音来源”下拉菜单是唯一的模式选择入口。
- 内置语音、LibSharedMedia、自定义路径、TTS 四选一。
- 不再使用“启用TTS / 启用自定义语音”勾选框，避免下拉和勾选框双重状态冲突。

后续维护建议：
- 想调整弹窗尺寸：改 Layout.Editor.Frame。
- 想调整列宽/左右边距：改 Layout.Editor.Grid。
- 想调整模块之间的距离/高度：改 Layout.Editor.Modules。
- 想新增字段：优先放到对应模块内，控件必须以模块卡片为 parent，禁止再直接挂到滚动 content 上；这样可以保证模块内容不会超出模块本身。
- 每个模块内部统一使用：模块左内边距、统一标签 Y、统一控件 Y、统一列宽。不要在 EditorFrame 里临时写一套新的外层坐标。
- 想调整皮肤接管策略：优先改 UI/Skin.lua 中的 GetSkinMode / UseExternalSkin / TryExternalSkin。
- 想调整控件外观：优先保持原生模板，不要在业务文件里重新自绘箭头、按钮或复选框。
- 下拉菜单统一从 UI/Widgets.lua 的 Widgets:CreateDropdown 创建。
  所有下拉菜单，无论短列表还是长列表，展开状态都使用同一个原生风格可滚动列表；
  不再混用 Blizzard 原生短列表和自定义长列表，避免悬浮效果、窗口层级和点击行为不一致。
  展开窗口使用 TOOLTIP 层级并挂到专用遮罩层，必须显示在弹窗上方，不能被模块/滚动区遮挡。
  展开窗口宽度必须与闭合控件外框宽度一致；内容超过 10 行时必须在下拉内部滚动，禁止铺满屏幕。
  展开时自动滚动到当前已选项目附近，方便长列表二次选择。
]]

Layout.Editor = Layout.Editor or {
    Frame = {
        width = 760,
        minHeight = 780,
        maxHeight = 920,
        screenPadding = 40,
        footerHeight = 54,
        headerTitleY = -14,
        headerDescY = -40,
        tabY = -70,
        subTabY = -108,
        contentTopY = -148,
        contentBottom = 66,
        sideInset = 24,
    },
    Grid = {
        left = 24,
        right = 680,
        moduleInnerLeft = 16,
        moduleInnerRight = 16,
        moduleTitleY = -10,
        moduleContentTop = -34,
        row = 30,
        gap = 14,
        idW = 112,
        nameW = 220,
        cdW = 112,
        checkW = 126,
        classDropW = 286,
        specDropW = 286,
        sourceW = 286,
        halfW = 286,
    },
    Modules = {
        left = 8,
        width = 680,
        classTop = -8,
        classHeight = 104,
        spellTop = -124,
        spellHeight = 240,
        conditionTop = -382,
        conditionHeight = 266,
        customCodeTop = -452,
        customConditionTop = -742,
        notifyTop = -8,
        notifyHeight = 420,
        bloodlustTop = -8,
        bloodlustHeight = 530,
    },
    Rows = {
        classSection = -14,
        classLabels = -50,
        classControls = -43,
        spellSection = -102,
        spellLabels = -136,
        spellControls = -160,
        talentLabels = -210,
        talentControls = -234,
        notifySection = -296,
        sourceLabel = -330,
        sourceControl = -354,
        soundLabels = -404,
        soundControls = -428,
        customLabel = -478,
        customControl = -502,
        ttsLabel = -556,
        ttsControl = -580,
        hint = -642,
        contentHeight = 980,
    },
}

local function StyleDescription(fs)
    if Skin and Skin.StyleFont then
        Skin:StyleFont(fs, "muted")
    end
    return fs
end

function Layout:CreateHeaderDescription(parent, text)
    local desc = Widgets:CreateLabel(parent, text or "", "GameFontHighlightSmall")
    desc:SetJustifyH("CENTER")
    desc:SetPoint("TOPLEFT", parent, "TOPLEFT", 62, self.Editor.Frame.headerDescY)
    desc:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -62, self.Editor.Frame.headerDescY)
    StyleDescription(desc)
    return desc
end

function Layout:CreateModule(parent, title, y)
    local section = Widgets:CreateSection(parent, title)
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    section:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    return section
end

local function SetNativeLabelColor(label, enabled)
    if not label or not label.SetTextColor then
        return
    end
    local color = enabled and rawget(_G, "NORMAL_FONT_COLOR") or rawget(_G, "GRAY_FONT_COLOR")
    if color and color.GetRGB then
        local r, g, b = color:GetRGB()
        label:SetTextColor(r, g, b, 1)
    elseif enabled then
        label:SetTextColor(1.00, 0.82, 0.00, 1)
    else
        label:SetTextColor(0.50, 0.50, 0.50, 1)
    end
end

function Layout:SetLabelEnabled(label, enabled)
    SetNativeLabelColor(label, enabled)
end

function Layout:UpdatePopupHeight(frame)
    if not frame then
        return
    end
    local cfg = self.Editor.Frame
    local parentHeight = UIParent and UIParent.GetHeight and (UIParent:GetHeight() or cfg.maxHeight) or cfg.maxHeight
    local targetHeight = math.min(cfg.maxHeight, math.max(cfg.minHeight, parentHeight - cfg.screenPadding))
    frame:SetHeight(targetHeight)
    if frame.contentHost and frame.contentHost.UpdateScrollRange then
        frame.contentHost:UpdateScrollRange()
    end
end
