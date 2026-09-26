-- WoW Translate: Core
-- Namespace, settings, events and small shared helpers.
--
-- Target: WoW: Forever (game type "camelot", interface 16001). The Forever
-- client runs the modern Midnight-era API, so everything here uses modern
-- calls (C_AddOns, C_ChatInfo, EventRegistry ...) and never assumes a Classic
-- global exists. Every optional API is feature-tested before use.

local ADDON_NAME, WT = ...
WT.name = ADDON_NAME
WT.version = "3.0.0"
if C_AddOns and C_AddOns.GetAddOnMetadata then
    local ok, v = pcall(C_AddOns.GetAddOnMetadata, ADDON_NAME, "Version")
    if ok and type(v) == "string" and v ~= "" then WT.version = v end
end

-- Public handle so players can inspect state with /dump WoWTranslate.db
_G.WoWTranslate = WT

-- ---------------------------------------------------------------------------
-- Localization: L.KEY falls back to the key itself so a missing string never
-- breaks the UI. Locales/enUS.lua fills the English base, the other locale
-- files override it only on their own client.
-- ---------------------------------------------------------------------------
WT.L = setmetatable({}, { __index = function(_, k) return k end })

function WT.Locale()
    return (GetLocale and GetLocale()) or "enUS"
end

-- ---------------------------------------------------------------------------
-- Languages and chat channels
-- ---------------------------------------------------------------------------
-- Languages the offline dictionaries cover. English is the pivot language.
WT.LANGS = { "en", "de", "fr", "es", "pt", "ru", "ko", "zh", "ja" }
WT.LANG_SET = {}
for _, code in ipairs(WT.LANGS) do WT.LANG_SET[code] = true end

-- Each language is shown in its own script so any player can find theirs.
WT.LANG_NATIVE = {
    en = "English", de = "Deutsch", fr = "Français", es = "Español",
    pt = "Português", ru = "Русский", ko = "한국어", zh = "中文", ja = "日本語",
}

local LOCALE_TO_LANG = {
    enUS = "en", enGB = "en", deDE = "de", frFR = "fr", esES = "es", esMX = "es",
    ptBR = "pt", ptPT = "pt", ruRU = "ru", koKR = "ko", zhTW = "zh", zhCN = "zh",
}

-- The player's own language, taken from the game client's language.
function WT.ClientLang()
    return LOCALE_TO_LANG[WT.Locale()] or "en"
end

-- Chat channel groups the player can switch on and off.
WT.CHANNELS = { "WHISPER", "PARTY", "RAID", "INSTANCE", "GUILD", "SAY", "YELL", "CHANNEL", "EMOTE" }

WT.EVENT_CHANNEL = {
    CHAT_MSG_SAY = "SAY",
    CHAT_MSG_YELL = "YELL",
    CHAT_MSG_WHISPER = "WHISPER",
    CHAT_MSG_BN_WHISPER = "WHISPER",
    CHAT_MSG_PARTY = "PARTY",
    CHAT_MSG_PARTY_LEADER = "PARTY",
    CHAT_MSG_RAID = "RAID",
    CHAT_MSG_RAID_LEADER = "RAID",
    CHAT_MSG_RAID_WARNING = "RAID",
    CHAT_MSG_INSTANCE_CHAT = "INSTANCE",
    CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE",
    CHAT_MSG_GUILD = "GUILD",
    CHAT_MSG_OFFICER = "GUILD",
    CHAT_MSG_CHANNEL = "CHANNEL",
    CHAT_MSG_COMMUNITIES_CHANNEL = "CHANNEL",
    CHAT_MSG_EMOTE = "EMOTE",
}

-- Outgoing chat types (edit box chat type -> channel group)
WT.CHATTYPE_CHANNEL = {
    SAY = "SAY", YELL = "YELL", WHISPER = "WHISPER", BN_WHISPER = "WHISPER",
    PARTY = "PARTY", RAID = "RAID", RAID_WARNING = "RAID",
    INSTANCE_CHAT = "INSTANCE", GUILD = "GUILD", OFFICER = "GUILD",
    CHANNEL = "CHANNEL", EMOTE = "EMOTE",
}

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------
WT.DB_VERSION = 3

WT.defaults = {
    enabled = true,              -- translate incoming chat
    mode = "quick",              -- "quick" (free, offline) or "accurate" (companion app)
    incomingTo = "auto",         -- "auto" = the game client's language
    display = "replace",         -- "replace" or "both" (translation + original)
    showMarker = true,           -- clickable [T] tag in front of translated lines
    localizeLinks = true,        -- show item/quest/spell links in your language
    disableWhileAfk = true,
    channels = {
        WHISPER = true, PARTY = true, RAID = true, INSTANCE = true, GUILD = true,
        SAY = true, YELL = true, CHANNEL = true, EMOTE = false,
    },
    outgoingEnabled = false,
    outgoingTo = "auto",         -- "auto" = the language the other player last wrote in
    outgoingTag = true,          -- add a short "(translated)" tag to what you send
    outgoingChannels = {
        WHISPER = true, PARTY = true, RAID = true, INSTANCE = true, GUILD = false,
        SAY = true, YELL = false, CHANNEL = false, EMOTE = false,
    },
    romanizeNames = true,        -- show a Latin reading of player names in tooltips
    minimap = { hide = false, angle = 200 },
    link = { corner = "TOPLEFT", block = 3, hold = 0.12 },
    rememberViaMacro = false,    -- beta workaround, see Features/Persist.lua
    welcomed = false,
    debug = false,
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end
WT.CopyDefaults = CopyDefaults

-- Replace the live settings with defaults (used by /wt reset).
-- The "remember my settings" choice survives a reset, so the fresh defaults
-- are what gets remembered (instead of the old macro coming back later).
function WT.ResetSettings()
    local remember = WT.db.rememberViaMacro
    for k in pairs(WT.db) do
        if k ~= "__wt" then WT.db[k] = nil end
    end
    CopyDefaults(WT.defaults, WT.db)
    WT.db.rememberViaMacro = remember
    WT.Fire("SETTINGS_CHANGED", "*")
end

-- Resolved target language for incoming chat.
function WT.IncomingTarget()
    local to = WT.db and WT.db.incomingTo or "auto"
    if to == "auto" or not WT.LANG_SET[to] then
        to = WT.ClientLang()
    end
    return to
end

-- ---------------------------------------------------------------------------
-- Tiny callback bus so modules can react to setting changes
-- ---------------------------------------------------------------------------
local listeners = {}

function WT.On(message, fn)
    listeners[message] = listeners[message] or {}
    table.insert(listeners[message], fn)
end

function WT.Fire(message, ...)
    local list = listeners[message]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then WT.Debug("listener error", message, err) end
    end
end

-- Change a setting from UI or slash commands. `key` may be "a.b" for nested.
function WT.Set(key, value)
    local db = WT.db
    local a, b = string.match(key, "^([^%.]+)%.(.+)$")
    if a then
        if type(db[a]) ~= "table" then db[a] = {} end
        db[a][b] = value
    else
        db[key] = value
    end
    WT.Fire("SETTINGS_CHANGED", key, value)
end

function WT.Get(key)
    local a, b = string.match(key, "^([^%.]+)%.(.+)$")
    if a then
        return WT.db[a] and WT.db[a][b]
    end
    return WT.db[key]
end

-- ---------------------------------------------------------------------------
-- Output helpers
-- ---------------------------------------------------------------------------
WT.COLOR = "|cff33ccff"
WT.PREFIX = WT.COLOR .. "WoW Translate|r"

function WT.Print(msg)
    local frame = DEFAULT_CHAT_FRAME or ChatFrame1
    if frame then frame:AddMessage(WT.PREFIX .. ": " .. tostring(msg)) end
end

local debugLog = {}
WT.debugLog = debugLog

function WT.Debug(...)
    local n = select("#", ...)
    local parts = {}
    for i = 1, n do parts[i] = tostring((select(i, ...))) end
    local line = table.concat(parts, " ")
    debugLog[#debugLog + 1] = string.format("%.1f %s", (GetTime and GetTime()) or 0, line)
    if #debugLog > 200 then table.remove(debugLog, 1) end
    if WT.db and WT.db.debug then
        local frame = DEFAULT_CHAT_FRAME or ChatFrame1
        if frame then frame:AddMessage("|cff888888[WT debug]|r " .. line) end
    end
end

-- Secret values (Midnight-era restriction): anything we cannot read is left
-- alone. canaccessvalue/issecretvalue only exist on modern clients.
function WT.CanRead(v)
    if issecretvalue and issecretvalue(v) then return false end
    if canaccessvalue and not canaccessvalue(v) then return false end
    return true
end

-- Chat messaging lockdown (boss encounters, Mythic/rated content, arenas).
function WT.InChatLockdown()
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
        return ok and locked == true
    end
    return false
end

function WT.IsForeverClient()
    local iface = GetBuildInfo and select(4, GetBuildInfo())
    return type(iface) == "number" and iface >= 16000 and iface < 20000
end

-- ---------------------------------------------------------------------------
-- Events. Registering an event the client does not know throws on Forever
-- and would abort this file, so every registration is protected.
-- ---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local handlers = {}

function WT.RegisterEvent(event, fn)
    if not handlers[event] then
        local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
        if not ok then
            WT.Debug("event not available on this client:", event)
            return false
        end
        handlers[event] = {}
    end
    table.insert(handlers[event], fn)
    return true
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok then WT.Debug("handler error", event, err) end
    end
end)

-- ---------------------------------------------------------------------------
-- Startup
-- ---------------------------------------------------------------------------
WT.hadSavedVariables = false

WT.RegisterEvent("ADDON_LOADED", function(_, name)
    if name ~= ADDON_NAME then return end

    -- The Forever beta client currently writes SavedVariables but never loads
    -- them back. If they do arrive (bug fixed), they win.
    if type(WoWTranslateDB) == "table" and WoWTranslateDB.__wt == WT.DB_VERSION then
        WT.hadSavedVariables = true
    else
        WoWTranslateDB = { __wt = WT.DB_VERSION }
    end
    WT.db = CopyDefaults(WT.defaults, WoWTranslateDB)
    WT.Fire("DB_READY")
end)

WT.RegisterEvent("PLAYER_LOGIN", function()
    WT.playerGUID = UnitGUID and UnitGUID("player")
    WT.Fire("LOGIN")
end)
