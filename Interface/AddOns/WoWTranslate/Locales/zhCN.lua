-- WoW Translate: Simplified Chinese
local _, WT = ...
if WT.Locale() ~= "zhCN" then return end
local L = WT.L

-- The small tag in front of translated lines, e.g. [T]
L.MARKER_LETTER = "译"

-- Modes
L.MODE_QUICK = "快速"
L.MODE_QUICK_BADGE = "|cff20ff20免费|r"
L.MODE_QUICK_BODY = "在游戏内马上就能用。逐句给出大致意思，不一定准确。"
L.MODE_ACCURATE = "精准"
L.MODE_ACCURATE_BADGE = "|cffffcc00付费服务|r"
L.MODE_ACCURATE_BODY = "真正自然的翻译。需要在电脑上安装免费的 Companion 程序，以及一个翻译账号（每月有免费额度，超出后付费）。"

-- Options window
L.SECTION_MODE = "要怎么翻译？"
L.SECTION_READING = "阅读聊天"
L.SECTION_WRITING = "发送消息"
L.SECTION_OTHER = "其他"

L.OPT_TRANSLATE_INCOMING = "翻译其他玩家的消息"
L.OPT_TRANSLATE_INCOMING_TIP = "其他语言的消息会在你的聊天窗口中翻译。"
L.OPT_TRANSLATE_INTO = "翻译成："
L.OPT_TRANSLATE_INTO_TIP = "你想阅读的语言。自动会使用游戏的语言。"
L.AUTO_LANG = "自动（%s）"
L.OPT_SHOW_ORIGINAL = "同时显示原文"
L.OPT_SHOW_ORIGINAL_TIP = "在译文后面用灰色附上原始消息。"
L.OPT_LOCALIZE_LINKS = "物品和任务名称用我的语言"
L.OPT_LOCALIZE_LINKS_TIP = "物品、任务和法术链接会用你的语言显示名称。这直接来自游戏，所以一定准确。"
L.OPT_PAUSE_AFK = "暂离时暂停翻译（AFK）"
L.OPT_PAUSE_AFK_TIP = "你被标记为暂离时不会翻译。"
L.OPT_MARKER = "显示 [译] 标签"
L.OPT_MARKER_TIP = "翻译过的消息前会有一个小小的 [译]。把鼠标移到上面就能看到原始消息。"

L.OPT_TRANSLATE_OUTGOING = "翻译我写的消息（快速）"
L.OPT_TRANSLATE_OUTGOING_TIP = "你的消息会在发送前翻译。这使用快速模式，所以句子请写得简短简单。想要精准翻译自己的消息，请使用 Companion 程序：它会翻译并复制文字，你直接粘贴就行。"
L.OPT_WRITE_IN = "书写语言："
L.OPT_WRITE_IN_TIP = "对方的语言（自动）会用每位玩家最后一次写给你时所用的语言回复。如果还没有人用其他语言写给你，消息会按你输入的原样发送。"
L.THEIR_LANGUAGE = "对方的语言（自动）"
L.OPT_OUTGOING_TAG = "加上 \"(已翻译)\" 让对方知道"
L.OPT_OUTGOING_TAG_TIP = "在你翻译后的消息前，加上一个对方语言的短标签，让他们知道这是机器翻译。"

L.OPT_ROMANIZE = "外文名字显示拉丁拼写"
L.OPT_ROMANIZE_TIP = "其他文字的名字（例如 小明 或 Иван）会在鼠标提示中显示拉丁字母读音。真正的名字永远不会改变。"
L.OPT_MINIMAP = "小地图按钮"
L.OPT_MINIMAP_TIP = "在小地图上显示 WoW Translate 按钮。你也可以在小地图旁边的插件菜单中找到 WoW Translate。"
L.OPT_REMEMBER = "重启后记住我的设置"
L.OPT_REMEMBER_TIP = "WoW: Forever 测试版目前在游戏重启时会忘记插件设置。这会在一个名为 \"WoWTranslate\" 的宏中保存一份副本。你随时可以关闭，宏也会一并删除。"
L.REMEMBER_NOTE = "测试版修复。占用一个宏位置。"
L.REMEMBER_AT_RISK = "游戏重启时你的更改会丢失（测试版错误）。勾选此框即可保留。"
L.REMEMBER_ON = "你的设置会被记住（保存在 \"WoWTranslate\" 宏中）。"
L.REMEMBER_OFF = "设置将不再保存在宏中。"

L.CHANNEL_WHISPER = "密语"
L.CHANNEL_PARTY = "小队"
L.CHANNEL_RAID = "团队"
L.CHANNEL_INSTANCE = "副本与战场"
L.CHANNEL_GUILD = "公会"
L.CHANNEL_SAY = "说"
L.CHANNEL_YELL = "大喊"
L.CHANNEL_CHANNEL = "交易与世界"
L.CHANNEL_EMOTE = "表情"

L.BUTTON_TRY = "试一试"
L.BUTTON_TRY_TIP = "在聊天窗口中显示几个翻译示例。"
L.BUTTON_RESET = "重置"
L.BUTTON_HOW_TO_SETUP = "如何设置"
L.BUTTON_SEND_TEST = "发送测试"
L.BUTTON_USE_ACCURATE = "开启精准模式"
L.BUTTON_OPEN_OPTIONS = "打开 WoW Translate"
L.SETTINGS_PANEL_TEXT = "把聊天翻译成其他语言，或从其他语言翻译过来。随时输入 /wt 即可打开选项。"

-- Accurate mode / companion link
L.LINK_STATUS_OFF = "精准模式需要 WoW Translate Companion 程序。"
L.LINK_STATUS_ON = "Companion 连接已开启（%s）。请保持程序运行。"
L.LINK_QUEUE = "%d 条等待中"
L.LINK_TEST_MESSAGE = "WoW Translate 向你问好！如果你能在 Companion 程序中看到这段文字，精准模式就正常工作了。"
L.LINK_TEST_SENT = "测试已发送。应该会在一秒内出现在 Companion 程序中。"
L.LINK_CORNER_SET = "Companion 连接已移到%s角。"
L.LINK_SIZE_SET = "Companion 连接方块现在是 %d 像素。"
L.CORNER_TOPLEFT = "左上"
L.CORNER_TOPRIGHT = "右上"
L.CORNER_BOTTOMLEFT = "左下"
L.CORNER_BOTTOMRIGHT = "右下"

L.GUIDE_TITLE = "设置精准模式"
L.GUIDE_BODY = "插件无法连接互联网，所以精准翻译来自一个在游戏旁边运行的免费小程序。\n\n"
    .. "1. 下载 |cffffd100WoW Translate Companion|r（链接在下方）并启动它。\n"
    .. "2. 在程序中选择一个翻译服务，并粘贴你的密钥。DeepL 和 Google 每月提供免费额度，超出后会收费。\n"
    .. "3. 以 |cffffd100窗口|r 或 |cffffd100窗口（全屏）|r 模式游戏。\n"
    .. "4. 在这里开启精准模式。屏幕的一角会出现一条细细的彩色线条：这是插件和程序沟通的方式，请让它保持可见。\n\n"
    .. "之后译文会显示在程序窗口中，就在你的聊天旁边。"
L.GUIDE_LINK_LABEL = "下载页面（点击后按 Ctrl+C 复制）："

-- Chat line tooltip
L.TOOLTIP_TITLE = "WoW Translate"
L.TOOLTIP_ORIGINAL = "原文（%s）："
L.TOOLTIP_QUICK_HINT = "快速翻译：给出大致意思，可能不完全准确。"
L.TOOLTIP_ACCURATE_HINT = "精准翻译在 Companion 程序中。"
L.TOOLTIP_CLICK_HINT = "点击在聊天中显示原文。"
L.ORIGINAL_LINE = "原文（%s）："

-- Minimap
L.MINIMAP_STATUS = "%s - %s模式 - 翻译成%s"
L.MINIMAP_LEFT_CLICK = "左键：选项"
L.MINIMAP_RIGHT_CLICK = "右键：开启或关闭翻译"
L.STATE_ON = "开启"
L.STATE_OFF = "关闭"

-- Chat messages
L.GREETING = "%s模式已开启。其他语言的消息会翻译成%s。输入 /wt 打开选项。"
L.GREETING_OFF = "翻译已关闭。输入 /wt on 即可重新开启。"
L.TRANSLATION_ON = "翻译已开启。"
L.TRANSLATION_OFF = "翻译已关闭。"
L.NOW_QUICK = "快速模式：在游戏内免费翻译。"
L.NOW_ACCURATE = "精准模式：启动 Companion 程序即可看到精准翻译。输入 /wt link 获取帮助。"
L.NOW_TRANSLATING_INTO = "现在翻译成%s。"
L.NOW_WRITING_IN = "你的消息将用这种语言书写：%s。"
L.WRITING_ON = "你的消息会在发送前翻译。"
L.WRITING_OFF = "你的消息会按输入的原样发送。"
L.LANG_CODES = "语言：auto, en, de, fr, es, pt, ru, ko, zh, ja"
L.CANT_DETECT = "无法判断这是哪种语言。"
L.NOT_TRANSLATED = "（认识的词太少）"
L.KNOWN_PERCENT = "认识 %d%% 的词"
L.DEMO_HEADER = "翻译成%s的示例："
L.DEMO_FOOTER = "快速模式给出大致意思。想要自然的句子，请使用精准模式。"
L.SETTINGS_RESET = "设置已恢复为默认值。"
L.ERR_NO_CHAT_FILTERS = "此游戏版本没有聊天过滤功能，因此无法翻译聊天。"

L.STATUS_HEADER = "状态 - 版本"
L.STATUS_MODE = "模式"
L.STATUS_READING = "阅读"
L.STATUS_WRITING = "书写"
L.STATUS_LINK = "Companion 连接"
L.STATUS_SAVED_OK = "设置会正常保存。"
L.STATUS_SAVED_MACRO = "设置保存在 \"WoWTranslate\" 宏中（测试版修复）。"
L.STATUS_SAVED_RISK = "游戏重启时设置会被重置（测试版错误）。输入 /wt remember 即可保留。"
L.STATUS_LOCKDOWN = "游戏目前锁定了聊天（首领战或评级比赛），结束前无法翻译其他玩家的消息。"

L.PERSIST_NO_MACRO_API = "无法使用宏，因此无法保存设置。"
L.PERSIST_MACRO_FULL = "无法创建 \"WoWTranslate\" 宏。通用宏位置是不是都满了？"
L.PERSIST_SAVED = "已保存。"
L.PERSIST_FIXED = "好消息：游戏现在会自己保存插件设置，所以 \"WoWTranslate\" 宏已删除。"
L.PERSIST_HINT = "提示：WoW: Forever 测试版会在游戏重启时忘记插件设置。输入 /wt remember（或在 /wt 中勾选此框）即可保留你的更改。"
L.PERSIST_RESTORED = "设置已恢复。"

L.HELP_HEADER = "命令："
L.HELP_LINES = {
    "/wt - 打开选项",
    "/wt on | off - 开启或关闭翻译",
    "/wt quick | accurate - 选择模式",
    "/wt to <language> - 翻译成这种语言（auto, en, de, fr, es, pt, ru, ko, zh, ja）",
    "/wt write on | off | <language> - 翻译你写的消息",
    "/wt test <text> - 看看消息会怎么翻译",
    "/wt link - 精准模式帮助（/wt link test 发送测试）",
    "/wt remember - 重启后保留设置（测试版修复）",
    "/wt status - 显示当前开启的功能",
}
