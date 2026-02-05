-- WoWTranslate.lua
-- Main addon file: chat hooks, display, and coordination
-- Chinese to English translation for WoW 1.12

-- ============================================================================
-- SAVED VARIABLES (initialized on load)
-- ============================================================================
WoWTranslateDB = WoWTranslateDB or {}
WoWTranslateDebugLog = WoWTranslateDebugLog or {}

-- ============================================================================
-- LOCAL STATE
-- ============================================================================
local DEBUG_MODE = false
local addonLoaded = false

-- Default settings
local defaults = {
    enabled = true,
    apiKey = "",
    showInChat = true,       -- Show translations in chat frame
    debugMode = false,
}

-- ============================================================================
-- LUA 5.0 COMPATIBILITY
-- ============================================================================
-- strsplit is not available in WoW 1.12, implement it
local function strsplit(delimiter, text, limit)
    if not text then return nil end
    if not delimiter or delimiter == "" then return text end

    local result = {}
    local count = 0
    local start = 1
    local delimStart, delimEnd = string.find(text, delimiter, start, true)

    while delimStart do
        count = count + 1
        if limit and count >= limit then
            break
        end
        table.insert(result, string.sub(text, start, delimStart - 1))
        start = delimEnd + 1
        delimStart, delimEnd = string.find(text, delimiter, start, true)
    end

    table.insert(result, string.sub(text, start))
    return unpack(result)
end

-- ============================================================================
-- DEBUG LOGGING
-- ============================================================================
local function DebugLog(a1, a2, a3, a4, a5)
    if not DEBUG_MODE then return end

    local msg = ""
    if a1 then msg = msg .. tostring(a1) .. " " end
    if a2 then msg = msg .. tostring(a2) .. " " end
    if a3 then msg = msg .. tostring(a3) .. " " end
    if a4 then msg = msg .. tostring(a4) .. " " end
    if a5 then msg = msg .. tostring(a5) .. " " end

    local timestamp = string.format("%.1f", GetTime())
    local logEntry = "[" .. timestamp .. "] " .. msg

    -- Print to chat (yellow color)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[WT-DEBUG] " .. msg .. "|r")

    -- Save to log table (persists via SavedVariables)
    table.insert(WoWTranslateDebugLog, logEntry)

    -- Keep only last 500 entries
    while table.getn(WoWTranslateDebugLog) > 500 do
        table.remove(WoWTranslateDebugLog, 1)
    end
end

-- ============================================================================
-- CHINESE CHARACTER DETECTION
-- ============================================================================
-- Detect if text contains Chinese characters (CJK Unicode range)
local function ContainsChinese(text)
    if not text then return false end
    for i = 1, string.len(text) do
        local byte = string.byte(text, i)
        -- UTF-8 Chinese characters start with bytes 0xE4-0xE9 (228-233)
        if byte >= 228 and byte <= 233 then
            return true
        end
    end
    return false
end

-- ============================================================================
-- DISPLAY FUNCTIONS
-- ============================================================================
-- Get chat color for different event types
local function GetChatColor(event)
    local colors = {
        ["CHAT_MSG_SAY"] = "|cFFFFFFFF",           -- White
        ["CHAT_MSG_YELL"] = "|cFFFF4040",          -- Red
        ["CHAT_MSG_WHISPER"] = "|cFFFF80FF",       -- Pink
        ["CHAT_MSG_PARTY"] = "|cFFAAAAFF",         -- Light blue
        ["CHAT_MSG_RAID"] = "|cFFFF7F00",          -- Orange
        ["CHAT_MSG_RAID_LEADER"] = "|cFFFF4800",   -- Dark orange
        ["CHAT_MSG_GUILD"] = "|cFF40FF40",         -- Green
        ["CHAT_MSG_OFFICER"] = "|cFF40C040",       -- Dark green
        ["CHAT_MSG_CHANNEL"] = "|cFFFFB0B0",       -- Light pink
    }
    return colors[event] or "|cFFCCCCCC"
end

-- Display translated message
local function DisplayTranslation(sender, translation, event)
    if not WoWTranslateDB then return end
    if not WoWTranslateDB.enabled then return end
    if not WoWTranslateDB.showInChat then return end

    local color = GetChatColor(event)
    -- Format: [TT] PlayerName: translation
    local message = color .. "[TT] " .. sender .. ": " .. translation .. "|r"
    DEFAULT_CHAT_FRAME:AddMessage(message)
end

-- ============================================================================
-- TRANSLATION LOGIC
-- ============================================================================
-- Main translation function
local function TranslateMessage(message, sender, event)
    if not WoWTranslateDB then return end
    if not WoWTranslateDB.enabled then return end

    DebugLog("Processing message from", sender, ":", message)

    -- Step 1: Check WoW-specific glossary FIRST (100% accurate)
    local glossaryResult, matchType = WoWTranslate_CheckGlossary(message)
    if glossaryResult then
        DebugLog("Glossary", matchType, ":", message, "->", glossaryResult)
        DisplayTranslation(sender, glossaryResult, event)
        return
    end

    -- Step 2: Check permanent cache
    local cached, found = WoWTranslate_CacheGet(message)
    if found then
        DebugLog("Cache hit:", message, "->", cached)
        DisplayTranslation(sender, cached, event)
        return
    end

    -- Step 3: Call Google API via DLL (only for non-gaming conversational text)
    if not WoWTranslate_API.IsAvailable() then
        DebugLog("DLL not available, skipping API call")
        return
    end

    DebugLog("API request for:", message)
    WoWTranslate_API.Translate(message, function(translation, err)
        if translation then
            DebugLog("API returned:", translation)
            -- Save to permanent cache
            WoWTranslate_CacheSave(message, translation)
            DisplayTranslation(sender, translation, event)
        else
            DebugLog("API error:", err or "unknown")
        end
    end)
end

-- ============================================================================
-- CHAT EVENT HANDLERS
-- ============================================================================
-- CRITICAL: Never modify arg2 (sender name) - it must remain untouched
-- for /whisper, /invite, and other player interactions to work

local function OnChatMessage()
    local message = arg1      -- Text to translate
    local sender = arg2       -- PRESERVE EXACTLY - never translate/modify
    local language = arg3
    local channelName = arg4
    local event = event       -- Chat event type

    -- Only process if message contains Chinese characters
    if not ContainsChinese(message) then
        return
    end

    DebugLog("Chinese detected in", event, "from", sender)

    -- Translate the message (sender is preserved, never translated)
    TranslateMessage(message, sender, event)
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================
SLASH_WOWTRANSLATE1 = "/wt"
SLASH_WOWTRANSLATE2 = "/wowtranslate"

SlashCmdList["WOWTRANSLATE"] = function(msg)
    -- Ensure DB exists (safety check)
    if not WoWTranslateDB then
        WoWTranslateDB = {}
        InitializeSettings()
    end

    local cmd, arg = strsplit(" ", msg, 2)
    cmd = string.lower(cmd or "")

    if cmd == "on" or cmd == "enable" then
        WoWTranslateDB.enabled = true
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WoWTranslate] Enabled|r")

    elseif cmd == "off" or cmd == "disable" then
        WoWTranslateDB.enabled = false
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WoWTranslate] Disabled|r")

    elseif cmd == "key" and arg then
        WoWTranslateDB.apiKey = arg
        local success, err = WoWTranslate_API.SetKey(arg)
        if success then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WoWTranslate] API key set|r")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WoWTranslate] Failed to set API key: " .. (err or "unknown") .. "|r")
        end

    elseif cmd == "status" then
        local dllStatus = WoWTranslate_API.IsAvailable()
            and "|cFF00FF00Connected|r"
            or "|cFFFF0000Not loaded|r"

        local cacheStats = WoWTranslate_CacheStats()
        local glossaryCount = WoWTranslate_GetGlossaryCount()
        local pendingCount = WoWTranslate_API.GetPendingCount()

        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Status:")
        DEFAULT_CHAT_FRAME:AddMessage("  DLL: " .. dllStatus)
        DEFAULT_CHAT_FRAME:AddMessage("  Enabled: " .. tostring(WoWTranslateDB.enabled))
        DEFAULT_CHAT_FRAME:AddMessage("  Glossary entries: " .. glossaryCount)
        DEFAULT_CHAT_FRAME:AddMessage("  Cached translations: " .. cacheStats.entries)
        DEFAULT_CHAT_FRAME:AddMessage("  Cache hit rate: " .. string.format("%.1f%%", cacheStats.hitRate))
        DEFAULT_CHAT_FRAME:AddMessage("  Pending requests: " .. pendingCount)

    elseif cmd == "test" then
        local testText = arg or "你好"
        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Testing: " .. testText)

        -- First check glossary
        local glossaryResult, matchType = WoWTranslate_CheckGlossary(testText)
        if glossaryResult then
            DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Glossary (" .. matchType .. "): " .. glossaryResult)
            return
        end

        -- Then check cache
        local cached, found = WoWTranslate_CacheGet(testText)
        if found then
            DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Cache hit: " .. cached)
            return
        end

        -- Finally try API
        if not WoWTranslate_API.IsAvailable() then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WoWTranslate] DLL not available for API test|r")
            return
        end

        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Requesting from API...")
        WoWTranslate_API.Translate(testText, function(result, err)
            if result then
                DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] API result: " .. result)
                WoWTranslate_CacheSave(testText, result)
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WoWTranslate] API error: " .. (err or "unknown") .. "|r")
            end
        end)

    elseif cmd == "clearcache" then
        WoWTranslate_CacheClear()
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[WoWTranslate] Cache cleared|r")

    elseif cmd == "test1" then
        -- Glossary test: "Hello" in Chinese
        local testText = "\228\189\160\229\165\189"  -- 你好
        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Test 1 - Glossary test")
        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Input: ni hao (Hello)")
        local result, matchType = WoWTranslate_CheckGlossary(testText)
        if result then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WoWTranslate] Result: " .. result .. " (" .. matchType .. ")|r")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WoWTranslate] No glossary match|r")
        end

    elseif cmd == "test2" then
        -- Glossary test: "LFG Molten Core" in Chinese
        local testText = "\230\177\130\231\187\132MC"  -- 求组MC
        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Test 2 - Glossary test (WoW terms)")
        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Input: qiu zu MC (LFG MC)")
        local result, matchType = WoWTranslate_CheckGlossary(testText)
        if result then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WoWTranslate] Result: " .. result .. " (" .. matchType .. ")|r")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WoWTranslate] No glossary match|r")
        end

    elseif cmd == "test3" then
        -- API test: "The weather is nice today"
        local testText = "\228\187\138\229\164\169\229\164\169\230\176\148\229\190\136\229\165\189"  -- 今天天气很好
        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Test 3 - API test")
        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Input: jin tian tian qi hen hao (The weather is nice today)")

        -- Check cache first
        local cached, found = WoWTranslate_CacheGet(testText)
        if found then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WoWTranslate] Cache hit: " .. cached .. "|r")
            return
        end

        if not WoWTranslate_API.IsAvailable() then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WoWTranslate] DLL not available|r")
            return
        end

        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Calling API...")
        WoWTranslate_API.Translate(testText, function(result, err)
            if result then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WoWTranslate] API Result: " .. result .. "|r")
                WoWTranslate_CacheSave(testText, result)
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WoWTranslate] API Error: " .. (err or "unknown") .. "|r")
            end
        end)

    elseif cmd == "test4" then
        -- API test: "I need help"
        local testText = "\230\136\145\233\156\128\232\166\129\229\184\174\229\138\169"  -- 我需要帮助
        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Test 4 - API test")
        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Input: wo xu yao bang zhu (I need help)")

        -- Check cache first
        local cached, found = WoWTranslate_CacheGet(testText)
        if found then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WoWTranslate] Cache hit: " .. cached .. "|r")
            return
        end

        if not WoWTranslate_API.IsAvailable() then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WoWTranslate] DLL not available|r")
            return
        end

        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Calling API...")
        WoWTranslate_API.Translate(testText, function(result, err)
            if result then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WoWTranslate] API Result: " .. result .. "|r")
                WoWTranslate_CacheSave(testText, result)
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WoWTranslate] API Error: " .. (err or "unknown") .. "|r")
            end
        end)

    elseif cmd == "debug" then
        DEBUG_MODE = not DEBUG_MODE
        WoWTranslateDB.debugMode = DEBUG_MODE
        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Debug mode: " .. (DEBUG_MODE and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"))

    elseif cmd == "log" then
        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Recent log entries:")
        local logs = WoWTranslateDebugLog or {}
        local start = math.max(1, table.getn(logs) - 19)
        for i = start, table.getn(logs) do
            DEFAULT_CHAT_FRAME:AddMessage("  " .. logs[i])
        end

    elseif cmd == "clearlog" then
        WoWTranslateDebugLog = {}
        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Debug log cleared")

    else
        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt on|off - Enable/disable translation")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt key <apikey> - Set Google API key")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt status - Show status and statistics")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt test [text] - Test translation")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt test1 - Test glossary (Hello)")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt test2 - Test glossary (LFG MC)")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt test3 - Test API (weather)")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt test4 - Test API (need help)")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt clearcache - Clear translation cache")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt debug - Toggle debug mode")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt log - Show recent debug log")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt clearlog - Clear debug log")
    end
end

-- ============================================================================
-- ADDON INITIALIZATION
-- ============================================================================
local function InitializeSettings()
    -- Ensure SavedVariables exist (WoW 1.12 may not have initialized them yet)
    if not WoWTranslateDB then
        WoWTranslateDB = {}
    end
    if not WoWTranslateDebugLog then
        WoWTranslateDebugLog = {}
    end

    -- Apply defaults for any missing settings
    for key, value in pairs(defaults) do
        if WoWTranslateDB[key] == nil then
            WoWTranslateDB[key] = value
        end
    end

    -- Restore debug mode from saved settings
    DEBUG_MODE = WoWTranslateDB.debugMode or false
end

local function OnAddonLoaded()
    if addonLoaded then return end
    addonLoaded = true

    -- Initialize settings
    InitializeSettings()

    -- Check DLL availability
    local dllOk = WoWTranslate_API.CheckDLL()

    -- Set API key if we have one saved
    if dllOk and WoWTranslateDB.apiKey and WoWTranslateDB.apiKey ~= "" then
        WoWTranslate_API.SetKey(WoWTranslateDB.apiKey)
    end

    -- Start polling for translation responses
    if dllOk then
        WoWTranslate_API.StartPolling()
    end

    -- Print startup message
    local glossaryCount = WoWTranslate_GetGlossaryCount()
    local cacheCount = WoWTranslate_CacheStats().entries
    local dllStatus = dllOk and "|cFF00FF00DLL OK|r" or "|cFFFFFF00DLL not loaded|r"

    DEFAULT_CHAT_FRAME:AddMessage("|cFF00CCFFWoWTranslate|r v0.1 loaded - " .. dllStatus .. " | " .. glossaryCount .. " glossary terms | " .. cacheCount .. " cached translations | Type /wt for help")
end

-- ============================================================================
-- EVENT FRAME
-- ============================================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

-- Register all chat events
eventFrame:RegisterEvent("CHAT_MSG_SAY")
eventFrame:RegisterEvent("CHAT_MSG_YELL")
eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
eventFrame:RegisterEvent("CHAT_MSG_PARTY")
eventFrame:RegisterEvent("CHAT_MSG_RAID")
eventFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
eventFrame:RegisterEvent("CHAT_MSG_GUILD")
eventFrame:RegisterEvent("CHAT_MSG_OFFICER")
eventFrame:RegisterEvent("CHAT_MSG_CHANNEL")

eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WoWTranslate" then
        OnAddonLoaded()
    elseif event == "PLAYER_LOGIN" then
        -- Re-check DLL after login (in case it loaded late)
        if not WoWTranslate_API.IsAvailable() then
            WoWTranslate_API.CheckDLL()
            if WoWTranslate_API.IsAvailable() then
                WoWTranslate_API.StartPolling()
                if WoWTranslateDB and WoWTranslateDB.apiKey and WoWTranslateDB.apiKey ~= "" then
                    WoWTranslate_API.SetKey(WoWTranslateDB.apiKey)
                end
            end
        end
    elseif string.find(event, "CHAT_MSG_") then
        OnChatMessage()
    end
end)
