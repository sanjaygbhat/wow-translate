-- WoW Translate: Traditional Chinese
local _, WT = ...
if WT.Locale() ~= "zhTW" then return end
local L = WT.L

-- The small tag in front of translated lines, e.g. [T]
L.MARKER_LETTER = "譯"

-- Modes
L.MODE_QUICK = "快速"
L.MODE_QUICK_BADGE = "|cff20ff20免費|r"
L.MODE_QUICK_BODY = "在遊戲內立即可用。逐句提供大致意思，不一定準確。"
L.MODE_ACCURATE = "精準"
L.MODE_ACCURATE_BADGE = "|cffffcc00付費服務|r"
L.MODE_ACCURATE_BODY = "真正自然的翻譯。需要在電腦上安裝免費的 Companion 程式，以及一個翻譯帳號（每月有免費額度，超過後付費）。"

-- Options window
L.SECTION_MODE = "要怎麼翻譯？"
L.SECTION_READING = "閱讀聊天"
L.SECTION_WRITING = "發送訊息"
L.SECTION_OTHER = "其他"

L.OPT_TRANSLATE_INCOMING = "翻譯其他玩家的訊息"
L.OPT_TRANSLATE_INCOMING_TIP = "其他語言的訊息會在你的聊天視窗中翻譯。"
L.OPT_TRANSLATE_INTO = "翻譯成："
L.OPT_TRANSLATE_INTO_TIP = "你想閱讀的語言。自動會使用遊戲的語言。"
L.AUTO_LANG = "自動（%s）"
L.OPT_SHOW_ORIGINAL = "同時顯示原文"
L.OPT_SHOW_ORIGINAL_TIP = "在翻譯後方以灰色附上原始訊息。"
L.OPT_LOCALIZE_LINKS = "物品和任務名稱用我的語言"
L.OPT_LOCALIZE_LINKS_TIP = "物品、任務和法術連結會以你的語言顯示名稱。這直接來自遊戲，所以一定準確。"
L.OPT_PAUSE_AFK = "暫離時暫停翻譯（AFK）"
L.OPT_PAUSE_AFK_TIP = "你被標記為暫離時不會翻譯。"
L.OPT_MARKER = "顯示 [譯] 標籤"
L.OPT_MARKER_TIP = "翻譯過的訊息前會有個小小的 [譯]。將滑鼠移到上面即可看到原始訊息。"

L.OPT_TRANSLATE_OUTGOING = "翻譯我寫的訊息（快速）"
L.OPT_TRANSLATE_OUTGOING_TIP = "你的訊息會在送出前翻譯。這使用快速模式，所以句子請寫得簡短簡單。想要精準翻譯自己的訊息，請使用 Companion 程式：它會翻譯並複製文字，讓你直接貼上。"
L.OPT_WRITE_IN = "撰寫語言："
L.OPT_WRITE_IN_TIP = "對方的語言（自動）會用每位玩家最後一次寫給你時所用的語言回覆。如果還沒有人用其他語言寫給你，訊息會照你輸入的原樣送出。"
L.THEIR_LANGUAGE = "對方的語言（自動）"
L.OPT_OUTGOING_TAG = "加上 \"(已翻譯)\" 讓對方知道"
L.OPT_OUTGOING_TAG_TIP = "在你翻譯後的訊息前，加上一個對方語言的短標籤，讓他們知道這是機器翻譯。"

L.OPT_ROMANIZE = "外文名字顯示拉丁拼音"
L.OPT_ROMANIZE_TIP = "其他文字的名字（例如 小明 或 Иван）會在滑鼠提示中顯示拉丁字母讀音。真正的名字永遠不會改變。"
L.OPT_MINIMAP = "小地圖按鈕"
L.OPT_MINIMAP_TIP = "在小地圖上顯示 WoW Translate 按鈕。你也可以在小地圖旁的插件選單中找到 WoW Translate。"
L.OPT_REMEMBER = "重新啟動後記住我的設定"
L.OPT_REMEMBER_TIP = "WoW: Forever 測試版目前在遊戲重新啟動時會忘記插件設定。這會在一個名為 \"WoWTranslate\" 的巨集中保存一份副本。你隨時可以關閉，巨集也會一併移除。"
L.REMEMBER_NOTE = "測試版修正。佔用一個巨集欄位。"
L.REMEMBER_AT_RISK = "遊戲重新啟動時你的變更會遺失（測試版錯誤）。勾選此方塊即可保留。"
L.REMEMBER_ON = "你的設定會被記住（保存在 \"WoWTranslate\" 巨集中）。"
L.REMEMBER_OFF = "設定將不再保存在巨集中。"

L.CHANNEL_WHISPER = "密語"
L.CHANNEL_PARTY = "隊伍"
L.CHANNEL_RAID = "團隊"
L.CHANNEL_INSTANCE = "副本與戰場"
L.CHANNEL_GUILD = "公會"
L.CHANNEL_SAY = "說"
L.CHANNEL_YELL = "大喊"
L.CHANNEL_CHANNEL = "交易與世界"
L.CHANNEL_EMOTE = "表情"

L.BUTTON_TRY = "試試看"
L.BUTTON_TRY_TIP = "在聊天視窗中顯示幾個翻譯範例。"
L.BUTTON_RESET = "重設"
L.BUTTON_HOW_TO_SETUP = "如何設定"
L.BUTTON_SEND_TEST = "傳送測試"
L.BUTTON_USE_ACCURATE = "開啟精準模式"
L.BUTTON_OPEN_OPTIONS = "開啟 WoW Translate"
L.SETTINGS_PANEL_TEXT = "把聊天翻譯成其他語言，或從其他語言翻譯過來。隨時輸入 /wt 即可開啟選項。"

-- Accurate mode / companion link
L.LINK_STATUS_OFF = "精準模式需要 WoW Translate Companion 程式。"
L.LINK_STATUS_ON = "Companion 連線已開啟（%s）。請保持程式執行。"
L.LINK_QUEUE = "%d 則等待中"
L.LINK_TEST_MESSAGE = "WoW Translate 向你問好！如果你能在 Companion 程式中看到這段文字，精準模式就正常運作了。"
L.LINK_TEST_SENT = "測試已傳送。應該會在一秒內出現在 Companion 程式中。"
L.LINK_CORNER_SET = "Companion 連線已移到%s角。"
L.LINK_SIZE_SET = "Companion 連線方塊現在是 %d 像素。"
L.CORNER_TOPLEFT = "左上"
L.CORNER_TOPRIGHT = "右上"
L.CORNER_BOTTOMLEFT = "左下"
L.CORNER_BOTTOMRIGHT = "右下"

L.GUIDE_TITLE = "設定精準模式"
L.GUIDE_BODY = "插件無法連上網路，所以精準翻譯來自一個在遊戲旁執行的小型免費程式。\n\n"
    .. "1. 下載 |cffffd100WoW Translate Companion|r（連結在下方）並啟動它。\n"
    .. "2. 在程式中選擇一個翻譯服務，並貼上你的金鑰。DeepL 和 Google 每月提供免費額度，超過後會收費。\n"
    .. "3. 以 |cffffd100視窗|r 或 |cffffd100視窗（全螢幕）|r 模式遊玩。\n"
    .. "4. 在這裡開啟精準模式。螢幕的一角會出現一條細細的彩色線條：這是插件與程式溝通的方式，請讓它保持可見。\n\n"
    .. "之後翻譯會顯示在程式視窗中，就在你的聊天旁邊。"
L.GUIDE_LINK_LABEL = "下載頁面（點一下，再按 Ctrl+C 複製）："

-- Chat line tooltip
L.TOOLTIP_TITLE = "WoW Translate"
L.TOOLTIP_ORIGINAL = "原文（%s）："
L.TOOLTIP_QUICK_HINT = "快速翻譯：提供大致意思，可能不完全準確。"
L.TOOLTIP_ACCURATE_HINT = "精準翻譯在 Companion 程式中。"
L.TOOLTIP_CLICK_HINT = "點擊以在聊天中顯示原文。"
L.ORIGINAL_LINE = "原文（%s）："

-- Minimap
L.MINIMAP_STATUS = "%s - %s模式 - 翻譯成%s"
L.MINIMAP_LEFT_CLICK = "左鍵：選項"
L.MINIMAP_RIGHT_CLICK = "右鍵：開啟或關閉翻譯"
L.STATE_ON = "開啟"
L.STATE_OFF = "關閉"

-- Chat messages
L.GREETING = "%s模式已開啟。其他語言的訊息會翻譯成%s。輸入 /wt 開啟選項。"
L.GREETING_OFF = "翻譯已關閉。輸入 /wt on 即可重新開啟。"
L.TRANSLATION_ON = "翻譯已開啟。"
L.TRANSLATION_OFF = "翻譯已關閉。"
L.NOW_QUICK = "快速模式：在遊戲內免費翻譯。"
L.NOW_ACCURATE = "精準模式：啟動 Companion 程式即可看到精準翻譯。輸入 /wt link 取得說明。"
L.NOW_TRANSLATING_INTO = "現在翻譯成%s。"
L.NOW_WRITING_IN = "你的訊息將以此語言撰寫：%s。"
L.WRITING_ON = "你的訊息會在送出前翻譯。"
L.WRITING_OFF = "你的訊息會照輸入的原樣送出。"
L.LANG_CODES = "語言：auto, en, de, fr, es, pt, ru, ko, zh, ja"
L.CANT_DETECT = "無法判斷這是哪種語言。"
L.NOT_TRANSLATED = "（認得的字詞太少）"
L.KNOWN_PERCENT = "認得 %d%% 的字詞"
L.DEMO_HEADER = "翻譯成%s的範例："
L.DEMO_FOOTER = "快速模式提供大致意思。想要自然的句子，請使用精準模式。"
L.SETTINGS_RESET = "設定已恢復為預設值。"
L.ERR_NO_CHAT_FILTERS = "此遊戲版本沒有聊天過濾功能，因此無法翻譯聊天。"

L.STATUS_HEADER = "狀態 - 版本"
L.STATUS_MODE = "模式"
L.STATUS_READING = "閱讀"
L.STATUS_WRITING = "撰寫"
L.STATUS_LINK = "Companion 連線"
L.STATUS_SAVED_OK = "設定會正常儲存。"
L.STATUS_SAVED_MACRO = "設定保存在 \"WoWTranslate\" 巨集中（測試版修正）。"
L.STATUS_SAVED_RISK = "遊戲重新啟動時設定會被重設（測試版錯誤）。輸入 /wt remember 即可保留。"
L.STATUS_LOCKDOWN = "遊戲目前鎖定了聊天（首領戰或積分賽），結束前無法翻譯其他玩家的訊息。"

L.PERSIST_NO_MACRO_API = "無法使用巨集，因此無法保存設定。"
L.PERSIST_MACRO_FULL = "無法建立 \"WoWTranslate\" 巨集。一般巨集欄位是不是都滿了？"
L.PERSIST_SAVED = "已儲存。"
L.PERSIST_FIXED = "好消息：遊戲現在會自己儲存插件設定，所以 \"WoWTranslate\" 巨集已移除。"
L.PERSIST_HINT = "提示：WoW: Forever 測試版會在遊戲重新啟動時忘記插件設定。輸入 /wt remember（或在 /wt 中勾選方塊）即可保留你的變更。"
L.PERSIST_RESTORED = "設定已還原。"

L.HELP_HEADER = "指令："
L.HELP_LINES = {
    "/wt - 開啟選項",
    "/wt on | off - 開啟或關閉翻譯",
    "/wt quick | accurate - 選擇模式",
    "/wt to <language> - 翻譯成此語言（auto, en, de, fr, es, pt, ru, ko, zh, ja）",
    "/wt write on | off | <language> - 翻譯你寫的訊息",
    "/wt test <text> - 看看訊息會怎麼翻譯",
    "/wt link - 精準模式說明（/wt link test 傳送測試）",
    "/wt remember - 重新啟動後保留設定（測試版修正）",
    "/wt status - 顯示目前開啟的功能",
}
