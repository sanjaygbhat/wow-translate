-- WoW Translate: German
local _, WT = ...
if WT.Locale() ~= "deDE" then return end
local L = WT.L

-- The small tag in front of translated lines, e.g. [T]
L.MARKER_LETTER = "Ü"

-- Modes
L.MODE_QUICK = "Schnell"
L.MODE_QUICK_BADGE = "|cff20ff20KOSTENLOS|r"
L.MODE_QUICK_BODY = "Funktioniert sofort, direkt im Spiel. Gibt dir den groben Sinn, Satzteil für Satzteil. Nicht immer genau."
L.MODE_ACCURATE = "Genau"
L.MODE_ACCURATE_BADGE = "|cffffcc00KOSTENPFLICHTIG|r"
L.MODE_ACCURATE_BODY = "Echte, natürliche Übersetzungen. Braucht die kostenlose Companion-App auf deinem PC und ein Übersetzungskonto (jeden Monat gratis bis zu einer Menge, dann kostenpflichtig)."

-- Options window
L.SECTION_MODE = "Wie soll ich übersetzen?"
L.SECTION_READING = "Chat lesen"
L.SECTION_WRITING = "Chat schreiben"
L.SECTION_OTHER = "Sonstiges"

L.OPT_TRANSLATE_INCOMING = "Nachrichten anderer Spieler übersetzen"
L.OPT_TRANSLATE_INCOMING_TIP = "Nachrichten in anderen Sprachen werden in deinem Chatfenster übersetzt."
L.OPT_TRANSLATE_INTO = "Übersetzen in:"
L.OPT_TRANSLATE_INTO_TIP = "Die Sprache, die du lesen willst. Auto nutzt die Sprache deines Spiels."
L.AUTO_LANG = "Auto (%s)"
L.OPT_SHOW_ORIGINAL = "Auch den Originaltext zeigen"
L.OPT_SHOW_ORIGINAL_TIP = "Zeigt die Originalnachricht in Grau hinter der Übersetzung."
L.OPT_LOCALIZE_LINKS = "Gegenstände und Quests auf Deutsch"
L.OPT_LOCALIZE_LINKS_TIP = "Links zu Gegenständen, Quests und Zaubern zeigen den Namen in deiner Sprache. Das kommt direkt aus dem Spiel und ist daher immer exakt."
L.OPT_PAUSE_AFK = "Pausieren, wenn ich weg bin (AFK)"
L.OPT_PAUSE_AFK_TIP = "Keine Übersetzung, solange du als AFK markiert bist."
L.OPT_MARKER = "Das [Ü]-Zeichen anzeigen"
L.OPT_MARKER_TIP = "Ein kleines [Ü] vor übersetzten Zeilen. Zeig mit der Maus darauf, um die Originalnachricht zu sehen."

L.OPT_TRANSLATE_OUTGOING = "Übersetzen, was ich schreibe (Schnell)"
L.OPT_TRANSLATE_OUTGOING_TIP = "Deine Nachricht wird direkt vor dem Senden übersetzt. Das nutzt den Schnellmodus, also halte deine Sätze kurz und einfach. Für genaue Übersetzungen deiner eigenen Nachrichten nutze die Companion-App: Sie übersetzt den Text und kopiert ihn, damit du ihn einfügen kannst."
L.OPT_WRITE_IN = "Schreiben in:"
L.OPT_WRITE_IN_TIP = "Sprache der anderen (auto) antwortet jedem Spieler in der Sprache, in der er dir zuletzt geschrieben hat. Hat noch niemand in einer anderen Sprache geschrieben, wird deine Nachricht so gesendet, wie du sie getippt hast."
L.THEIR_LANGUAGE = "Sprache der anderen (auto)"
L.OPT_OUTGOING_TAG = "Hinweis \"(übersetzt)\" hinzufügen"
L.OPT_OUTGOING_TAG_TIP = "Setzt einen kurzen Hinweis in ihrer Sprache vor deine übersetzte Nachricht, damit sie wissen, dass eine Maschine übersetzt hat."

L.OPT_ROMANIZE = "Fremde Namen in lateinischer Schrift"
L.OPT_ROMANIZE_TIP = "Namen in anderen Schriften (wie 小明 oder Иван) bekommen im Tooltip eine lateinische Lesart. Der echte Name wird nie geändert."
L.OPT_MINIMAP = "Button an der Minikarte"
L.OPT_MINIMAP_TIP = "Zeigt den WoW Translate-Button an der Minikarte. Du findest WoW Translate auch im Addon-Menü neben der Minikarte."
L.OPT_REMEMBER = "Einstellungen nach Neustart behalten"
L.OPT_REMEMBER_TIP = "Die Beta von WoW: Forever vergisst derzeit Addon-Einstellungen, wenn das Spiel neu startet. Diese Option speichert eine Kopie in einem Makro namens \"WoWTranslate\". Du kannst sie jederzeit ausschalten, dann wird das Makro entfernt."
L.REMEMBER_NOTE = "Beta-Lösung. Belegt einen Makroplatz."
L.REMEMBER_AT_RISK = "Deine Änderungen gehen beim Neustart des Spiels verloren (Beta-Fehler). Setz hier ein Häkchen, um sie zu behalten."
L.REMEMBER_ON = "Deine Einstellungen werden gemerkt (im Makro \"WoWTranslate\")."
L.REMEMBER_OFF = "Einstellungen werden nicht mehr in einem Makro gespeichert."

L.CHANNEL_WHISPER = "Flüstern"
L.CHANNEL_PARTY = "Gruppe"
L.CHANNEL_RAID = "Schlachtzug"
L.CHANNEL_INSTANCE = "Instanz & Schlachtfeld"
L.CHANNEL_GUILD = "Gilde"
L.CHANNEL_SAY = "Sagen"
L.CHANNEL_YELL = "Schreien"
L.CHANNEL_CHANNEL = "Handel & Welt"
L.CHANNEL_EMOTE = "Emotes"

L.BUTTON_TRY = "Ausprobieren"
L.BUTTON_TRY_TIP = "Zeigt ein paar Beispielübersetzungen in deinem Chatfenster."
L.BUTTON_RESET = "Zurücksetzen"
L.BUTTON_HOW_TO_SETUP = "So richtest du es ein"
L.BUTTON_SEND_TEST = "Test senden"
L.BUTTON_USE_ACCURATE = "Genaumodus einschalten"
L.BUTTON_OPEN_OPTIONS = "WoW Translate öffnen"
L.SETTINGS_PANEL_TEXT = "Übersetzt den Chat in andere Sprachen und aus anderen Sprachen. Gib jederzeit /wt ein, um die Optionen zu öffnen."

-- Accurate mode / companion link
L.LINK_STATUS_OFF = "Der Genaumodus braucht die App WoW Translate Companion."
L.LINK_STATUS_ON = "Companion-Verbindung ist an (%s). Lass die App laufen."
L.LINK_QUEUE = "%d wartend"
L.LINK_TEST_MESSAGE = "Hallo von WoW Translate! Wenn du das in der Companion-App lesen kannst, funktioniert der Genaumodus."
L.LINK_TEST_SENT = "Test gesendet. Er sollte innerhalb einer Sekunde in der Companion-App erscheinen."
L.LINK_CORNER_SET = "Companion-Verbindung in die Ecke %s verschoben."
L.LINK_SIZE_SET = "Die Quadrate der Companion-Verbindung sind jetzt %d Pixel groß."
L.CORNER_TOPLEFT = "oben links"
L.CORNER_TOPRIGHT = "oben rechts"
L.CORNER_BOTTOMLEFT = "unten links"
L.CORNER_BOTTOMRIGHT = "unten rechts"

L.GUIDE_TITLE = "Genaumodus einrichten"
L.GUIDE_BODY = "Addons können nicht ins Internet. Genaue Übersetzungen kommen daher von einer kleinen kostenlosen App, die neben dem Spiel läuft.\n\n"
    .. "1. Lade |cffffd100WoW Translate Companion|r herunter (Link unten) und starte es.\n"
    .. "2. Wähle in der App einen Übersetzungsdienst und füge deinen Schlüssel ein. DeepL und Google geben dir jeden Monat eine Gratismenge, danach kostet es Geld.\n"
    .. "3. Spiele im |cffffd100Fenstermodus|r oder im |cffffd100Fenstermodus (Vollbild)|r.\n"
    .. "4. Schalte hier den Genaumodus ein. In einer Ecke deines Bildschirms erscheint eine dünne farbige Linie: So spricht das Addon mit der App, also lass sie sichtbar.\n\n"
    .. "Die Übersetzungen erscheinen dann im Fenster der App, direkt neben deinem Chat."
L.GUIDE_LINK_LABEL = "Downloadseite (klicken, dann Ctrl+C zum Kopieren):"

-- Chat line tooltip
L.TOOLTIP_TITLE = "WoW Translate"
L.TOOLTIP_ORIGINAL = "Original (%s):"
L.TOOLTIP_QUICK_HINT = "Schnelle Übersetzung: gibt den groben Sinn wieder und ist vielleicht nicht exakt."
L.TOOLTIP_ACCURATE_HINT = "Die genaue Übersetzung steht in der Companion-App."
L.TOOLTIP_CLICK_HINT = "Klicken, um das Original im Chat zu zeigen."
L.ORIGINAL_LINE = "Original (%s):"

-- Minimap
L.MINIMAP_STATUS = "%s - Modus: %s - Ziel: %s"
L.MINIMAP_LEFT_CLICK = "Linksklick: Optionen"
L.MINIMAP_RIGHT_CLICK = "Rechtsklick: Übersetzung an oder aus"
L.STATE_ON = "An"
L.STATE_OFF = "Aus"

-- Chat messages
L.GREETING = "Modus %s ist an. Nachrichten in anderen Sprachen werden übersetzt in: %s. Gib /wt für die Optionen ein."
L.GREETING_OFF = "Übersetzung ist aus. Gib /wt on ein, um sie wieder einzuschalten."
L.TRANSLATION_ON = "Übersetzung ist an."
L.TRANSLATION_OFF = "Übersetzung ist aus."
L.NOW_QUICK = "Schnellmodus: kostenlose Übersetzungen direkt im Spiel."
L.NOW_ACCURATE = "Genaumodus: Starte die Companion-App, um genaue Übersetzungen zu sehen. Gib /wt link ein, wenn du Hilfe brauchst."
L.NOW_TRANSLATING_INTO = "Jetzt wird übersetzt in: %s."
L.NOW_WRITING_IN = "Deine Nachrichten werden geschrieben in: %s."
L.WRITING_ON = "Deine Nachrichten werden vor dem Senden übersetzt."
L.WRITING_OFF = "Deine Nachrichten werden so gesendet, wie du sie tippst."
L.LANG_CODES = "Sprachen: auto, en, de, fr, es, pt, ru, ko, zh, ja"
L.CANT_DETECT = "Ich konnte nicht erkennen, welche Sprache das ist."
L.NOT_TRANSLATED = "(zu wenige bekannte Wörter)"
L.KNOWN_PERCENT = "%d%% der Wörter bekannt"
L.DEMO_HEADER = "Beispiele (übersetzt in %s):"
L.DEMO_FOOTER = "Der Schnellmodus gibt den groben Sinn wieder. Für natürliche Sätze nutze den Genaumodus."
L.SETTINGS_RESET = "Die Einstellungen sind wieder auf Standard."
L.ERR_NO_CHAT_FILTERS = "Diese Spielversion hat keine Chatfilter, daher kann der Chat nicht übersetzt werden."

L.STATUS_HEADER = "Status - Version"
L.STATUS_MODE = "Modus"
L.STATUS_READING = "Lesen"
L.STATUS_WRITING = "Schreiben"
L.STATUS_LINK = "Companion-Verbindung"
L.STATUS_SAVED_OK = "Einstellungen werden normal gespeichert."
L.STATUS_SAVED_MACRO = "Einstellungen werden im Makro \"WoWTranslate\" gespeichert (Beta-Lösung)."
L.STATUS_SAVED_RISK = "Einstellungen werden beim Neustart des Spiels zurückgesetzt (Beta-Fehler). Gib /wt remember ein, um sie zu behalten."
L.STATUS_LOCKDOWN = "Der Chat ist gerade vom Spiel gesperrt (Bosskampf oder gewertetes Match). Nachrichten anderer Spieler können erst danach übersetzt werden."

L.PERSIST_NO_MACRO_API = "Makros sind nicht verfügbar, daher können die Einstellungen nicht behalten werden."
L.PERSIST_MACRO_FULL = "Das Makro \"WoWTranslate\" konnte nicht erstellt werden. Sind alle allgemeinen Makroplätze belegt?"
L.PERSIST_SAVED = "Gespeichert."
L.PERSIST_FIXED = "Gute Nachricht: Das Spiel speichert Addon-Einstellungen jetzt selbst, daher wurde das Makro \"WoWTranslate\" entfernt."
L.PERSIST_HINT = "Tipp: Die Beta von WoW: Forever vergisst Addon-Einstellungen, wenn das Spiel neu startet. Gib /wt remember ein (oder setz das Häkchen in /wt), um deine Änderungen zu behalten."
L.PERSIST_RESTORED = "Einstellungen wiederhergestellt."

L.HELP_HEADER = "Befehle:"
L.HELP_LINES = {
    "/wt - Optionen öffnen",
    "/wt on | off - Übersetzung ein- oder ausschalten",
    "/wt quick | accurate - Modus wählen",
    "/wt to <language> - in diese Sprache übersetzen (auto, en, de, fr, es, pt, ru, ko, zh, ja)",
    "/wt write on | off | <language> - übersetzen, was du schreibst",
    "/wt test <text> - sehen, wie eine Nachricht übersetzt würde",
    "/wt link - Hilfe zum Genaumodus (/wt link test sendet einen Test)",
    "/wt remember - Einstellungen nach Neustart behalten (Beta-Lösung)",
    "/wt status - zeigen, was eingeschaltet ist",
}
