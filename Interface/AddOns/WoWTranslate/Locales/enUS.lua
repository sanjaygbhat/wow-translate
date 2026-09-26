-- WoW Translate: English (base language for every other locale)
local _, WT = ...
local L = WT.L

-- The small tag in front of translated lines, e.g. [T]
L.MARKER_LETTER = "T"

-- Modes
L.MODE_QUICK = "Quick"
L.MODE_QUICK_BADGE = "|cff20ff20FREE|r"
L.MODE_QUICK_BODY = "Works right away, inside the game. Gives you the general meaning, phrase by phrase. Not always accurate."
L.MODE_ACCURATE = "Accurate"
L.MODE_ACCURATE_BADGE = "|cffffcc00PAID SERVICE|r"
L.MODE_ACCURATE_BODY = "Real, natural translations. Needs the free Companion app on your PC and a translation account (free monthly amount, then paid)."

-- Options window
L.SECTION_MODE = "How should I translate?"
L.SECTION_READING = "Reading chat"
L.SECTION_WRITING = "Writing chat"
L.SECTION_OTHER = "Other"

L.OPT_TRANSLATE_INCOMING = "Translate messages from other players"
L.OPT_TRANSLATE_INCOMING_TIP = "Messages in other languages are translated in your chat window."
L.OPT_TRANSLATE_INTO = "Translate into:"
L.OPT_TRANSLATE_INTO_TIP = "The language you want to read. Auto uses your game's language."
L.AUTO_LANG = "Auto (%s)"
L.OPT_SHOW_ORIGINAL = "Show the original text too"
L.OPT_SHOW_ORIGINAL_TIP = "Adds the original message in grey after the translation."
L.OPT_LOCALIZE_LINKS = "Item and quest names in my language"
L.OPT_LOCALIZE_LINKS_TIP = "Item, quest and spell links are shown with their name in your language. This comes straight from the game, so it is always exact."
L.OPT_PAUSE_AFK = "Pause while I'm away (AFK)"
L.OPT_PAUSE_AFK_TIP = "No translating while you are marked AFK."
L.OPT_MARKER = "Show the [T] tag"
L.OPT_MARKER_TIP = "A small [T] in front of translated lines. Point at it to see the original message."

L.OPT_TRANSLATE_OUTGOING = "Translate what I write (Quick)"
L.OPT_TRANSLATE_OUTGOING_TIP = "Your message is translated right before it is sent. Uses Quick mode, so keep sentences short and simple. For accurate translations of your own messages, use the Companion app: it translates and copies the text for you to paste."
L.OPT_WRITE_IN = "Write in:"
L.OPT_WRITE_IN_TIP = "Their language (auto) answers each player in the language they last wrote to you in. If nobody has written in another language yet, your message is sent as you typed it."
L.THEIR_LANGUAGE = "Their language (auto)"
L.OPT_OUTGOING_TAG = "Add \"(translated)\" so others know"
L.OPT_OUTGOING_TAG_TIP = "Adds a short tag, in their language, in front of your translated message so they know a machine translated it."

L.OPT_ROMANIZE = "Latin spelling of foreign names"
L.OPT_ROMANIZE_TIP = "Names in other alphabets (like 小明 or Иван) get a Latin reading in their tooltip. The real name is never changed."
L.OPT_MINIMAP = "Minimap button"
L.OPT_MINIMAP_TIP = "Show the WoW Translate button on the minimap. You can also find WoW Translate in the addons menu next to the minimap."
L.OPT_REMEMBER = "Remember my settings after restart"
L.OPT_REMEMBER_TIP = "The WoW: Forever beta currently forgets addon settings when the game restarts. This keeps a copy in one macro called \"WoWTranslate\". You can turn it off at any time and the macro is removed."
L.REMEMBER_NOTE = "Beta fix. Uses one macro slot."
L.REMEMBER_AT_RISK = "Your changes will be lost when the game restarts (beta bug). Tick this box to keep them."
L.REMEMBER_ON = "Your settings will be remembered (kept in the \"WoWTranslate\" macro)."
L.REMEMBER_OFF = "Settings will no longer be kept in a macro."

L.CHANNEL_WHISPER = "Whispers"
L.CHANNEL_PARTY = "Party"
L.CHANNEL_RAID = "Raid"
L.CHANNEL_INSTANCE = "Dungeon & BG"
L.CHANNEL_GUILD = "Guild"
L.CHANNEL_SAY = "Say"
L.CHANNEL_YELL = "Yell"
L.CHANNEL_CHANNEL = "Trade & World"
L.CHANNEL_EMOTE = "Emotes"

L.BUTTON_TRY = "Try it"
L.BUTTON_TRY_TIP = "Shows a few example translations in your chat window."
L.BUTTON_RESET = "Reset"
L.BUTTON_HOW_TO_SETUP = "How to set it up"
L.BUTTON_SEND_TEST = "Send a test"
L.BUTTON_USE_ACCURATE = "Turn on Accurate mode"
L.BUTTON_OPEN_OPTIONS = "Open WoW Translate"
L.SETTINGS_PANEL_TEXT = "Translate chat to and from other languages. Type /wt at any time to open the options."

-- Accurate mode / companion link
L.LINK_STATUS_OFF = "Accurate mode needs the WoW Translate Companion app."
L.LINK_STATUS_ON = "Companion link is on (%s). Keep the app running."
L.LINK_QUEUE = "%d waiting"
L.LINK_TEST_MESSAGE = "Hello from WoW Translate! If you can read this in the Companion app, Accurate mode is working."
L.LINK_TEST_SENT = "Test sent. It should appear in the Companion app within a second."
L.LINK_CORNER_SET = "Companion link moved to the %s corner."
L.LINK_SIZE_SET = "Companion link squares are now %d pixels."
L.CORNER_TOPLEFT = "top left"
L.CORNER_TOPRIGHT = "top right"
L.CORNER_BOTTOMLEFT = "bottom left"
L.CORNER_BOTTOMRIGHT = "bottom right"

L.GUIDE_TITLE = "Set up Accurate mode"
L.GUIDE_BODY = "Addons can't use the internet, so accurate translations come from a small free app that runs next to the game.\n\n"
    .. "1. Download |cffffd100WoW Translate Companion|r (link below) and start it.\n"
    .. "2. In the app, pick a translation service and paste your key. DeepL and Google give you a free amount every month, then they charge you.\n"
    .. "3. Play in |cffffd100Windowed|r or |cffffd100Windowed (Fullscreen)|r mode.\n"
    .. "4. Turn on Accurate mode here. A thin coloured line appears in a corner of your screen: that is how the addon talks to the app, so leave it visible.\n\n"
    .. "Translations then show up in the app's window, right next to your chat."
L.GUIDE_LINK_LABEL = "Download page (click, then press Ctrl+C to copy):"

-- Chat line tooltip
L.TOOLTIP_TITLE = "WoW Translate"
L.TOOLTIP_ORIGINAL = "Original (%s):"
L.TOOLTIP_QUICK_HINT = "Quick translation: gives the general meaning and may not be exact."
L.TOOLTIP_ACCURATE_HINT = "The accurate translation is in the Companion app."
L.TOOLTIP_CLICK_HINT = "Click to show the original in chat."
L.ORIGINAL_LINE = "Original (%s):"

-- Minimap
L.MINIMAP_STATUS = "%s - %s mode - into %s"
L.MINIMAP_LEFT_CLICK = "Left-click: options"
L.MINIMAP_RIGHT_CLICK = "Right-click: turn translation on or off"
L.STATE_ON = "On"
L.STATE_OFF = "Off"

-- Chat messages
L.GREETING = "%s mode is on. Messages in other languages are translated into %s. Type /wt for options."
L.GREETING_OFF = "Translation is off. Type /wt on to turn it back on."
L.TRANSLATION_ON = "Translation is on."
L.TRANSLATION_OFF = "Translation is off."
L.NOW_QUICK = "Quick mode: free translations inside the game."
L.NOW_ACCURATE = "Accurate mode: start the Companion app to see accurate translations. Type /wt link for help."
L.NOW_TRANSLATING_INTO = "Now translating into %s."
L.NOW_WRITING_IN = "Your messages will be written in: %s."
L.WRITING_ON = "Your messages will be translated before they are sent."
L.WRITING_OFF = "Your messages will be sent as you type them."
L.LANG_CODES = "Languages: auto, en, de, fr, es, pt, ru, ko, zh, ja"
L.CANT_DETECT = "I couldn't tell which language that is."
L.NOT_TRANSLATED = "(too few known words)"
L.KNOWN_PERCENT = "%d%% of words known"
L.DEMO_HEADER = "Examples translated into %s:"
L.DEMO_FOOTER = "Quick mode gives the general meaning. For natural sentences, use Accurate mode."
L.SETTINGS_RESET = "Settings are back to their defaults."
L.ERR_NO_CHAT_FILTERS = "This game version has no chat filters, so chat can't be translated."

L.STATUS_HEADER = "Status - version"
L.STATUS_MODE = "Mode"
L.STATUS_READING = "Reading"
L.STATUS_WRITING = "Writing"
L.STATUS_LINK = "Companion link"
L.STATUS_SAVED_OK = "Settings are saved normally."
L.STATUS_SAVED_MACRO = "Settings are kept in the \"WoWTranslate\" macro (beta fix)."
L.STATUS_SAVED_RISK = "Settings will reset when the game restarts (beta bug). Type /wt remember to keep them."
L.STATUS_LOCKDOWN = "Chat is locked by the game right now (boss fight or rated match), so other players' messages can't be translated until it ends."

L.PERSIST_NO_MACRO_API = "Macros are not available, so settings can't be kept."
L.PERSIST_MACRO_FULL = "Couldn't create the \"WoWTranslate\" macro. Are all general macro slots full?"
L.PERSIST_SAVED = "Saved."
L.PERSIST_FIXED = "Good news: the game now saves addon settings itself, so the \"WoWTranslate\" macro was removed."
L.PERSIST_HINT = "Tip: the WoW: Forever beta forgets addon settings when the game restarts. Type /wt remember (or tick the box in /wt) to keep your changes."
L.PERSIST_RESTORED = "Settings restored."

L.HELP_HEADER = "Commands:"
L.HELP_LINES = {
    "/wt - open the options",
    "/wt on | off - turn translation on or off",
    "/wt quick | accurate - pick a mode",
    "/wt to <language> - translate into this language (auto, en, de, fr, es, pt, ru, ko, zh, ja)",
    "/wt write on | off | <language> - translate what you write",
    "/wt test <text> - see how a message would be translated",
    "/wt link - Accurate mode help (/wt link test sends a test)",
    "/wt remember - keep settings after a restart (beta fix)",
    "/wt status - show what is on",
}
