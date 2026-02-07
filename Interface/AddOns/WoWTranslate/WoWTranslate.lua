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
local originalAddMessage = nil

local pendingMessages = {}
local messageCounter = 0

-- Outgoing translation state
local outgoingQueue = {}
local outgoingCounter = 0
local originalSendChatMessage = SendChatMessage

local defaults = {
    enabled = true,
    apiKey = "",
    debugMode = false,
    -- Outgoing translation settings
    outgoingEnabled = false,  -- Off by default
    outgoingChannels = {
        WHISPER = true,
        PARTY = true,
        GUILD = true,
        RAID = true,
        SAY = true,
        YELL = true,
    },
    outgoingPrefix = "[Translated by WoWTranslate]",
    -- Language settings (any-to-any translation)
    incomingFromLang = "zh",
    incomingToLang = "en",
    outgoingFromLang = "en",
    outgoingToLang = "zh",
}

-- ============================================================================
-- LUA 5.0 COMPATIBILITY
-- ============================================================================
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

    if originalAddMessage then
        originalAddMessage(DEFAULT_CHAT_FRAME, "|cFFFFFF00[WT-DEBUG] " .. msg .. "|r")
    end

    table.insert(WoWTranslateDebugLog, logEntry)

    while table.getn(WoWTranslateDebugLog) > 500 do
        table.remove(WoWTranslateDebugLog, 1)
    end
end

-- ============================================================================
-- SOURCE LANGUAGE CHARACTER DETECTION
-- ============================================================================
-- Detects if text contains characters from the configured source language
-- Supports: zh (Chinese), ja (Japanese), ko (Korean), ru (Russian)
-- For Latin-based languages (en, de, fr, es, pt): detects non-ASCII characters

local function ContainsLanguageChars(text, lang)
    if not text then return false end

    for i = 1, string.len(text) do
        local byte = string.byte(text, i)

        if lang == "zh" then
            -- Chinese: CJK Unified Ideographs (U+4E00-U+9FFF)
            -- UTF-8: bytes 228-233 as first byte
            if byte >= 228 and byte <= 233 then
                return true
            end
        elseif lang == "ja" then
            -- Japanese: Hiragana, Katakana, and CJK
            -- Hiragana/Katakana: U+3040-U+30FF (UTF-8: 227 as first byte)
            -- CJK: same as Chinese
            if byte == 227 or (byte >= 228 and byte <= 233) then
                return true
            end
        elseif lang == "ko" then
            -- Korean: Hangul syllables U+AC00-U+D7AF
            -- UTF-8: bytes 234-237 as first byte (covers Hangul range)
            if byte >= 234 and byte <= 237 then
                return true
            end
        elseif lang == "ru" then
            -- Russian: Cyrillic U+0400-U+04FF
            -- UTF-8: bytes 208-209 as first byte
            if byte == 208 or byte == 209 then
                return true
            end
        else
            -- Latin-based languages (en, de, fr, es, pt)
            -- Detect extended ASCII / accented characters (UTF-8 multi-byte)
            -- Any byte >= 128 indicates non-ASCII (potential accented chars)
            if byte >= 192 and byte <= 223 then
                -- 2-byte UTF-8 sequence start (covers Latin Extended, etc.)
                return true
            end
        end
    end
    return false
end

-- Check if text contains characters that need translation based on incoming settings
local function ContainsSourceLanguage(text)
    if not text then return false end
    local sourceLang = WoWTranslateDB and WoWTranslateDB.incomingFromLang or "zh"
    return ContainsLanguageChars(text, sourceLang)
end

-- Check if text contains outgoing target language (to prevent double-translation)
local function ContainsOutgoingTargetLanguage(text)
    if not text then return false end
    local targetLang = WoWTranslateDB and WoWTranslateDB.outgoingToLang or "zh"
    return ContainsLanguageChars(text, targetLang)
end

-- Legacy function name for compatibility
local function ContainsChinese(text)
    return ContainsLanguageChars(text, "zh")
end

-- ============================================================================
-- HYPERLINK LOCALIZATION
-- ============================================================================
-- Parse hyperlinks and replace Chinese display names with English equivalents
-- using the client's GetItemInfo() API

-- Queue for messages waiting on item cache
local itemCacheQueue = {}
local itemCacheCounter = 0

-- Hidden tooltip for forcing item cache population
local itemCacheTooltip = CreateFrame("GameTooltip", "WoWTranslateItemCacheTooltip", nil, "GameTooltipTemplate")
itemCacheTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

-- Force item data to be requested from server using SetHyperlink
-- This is more reliable than just calling GetItemInfo()
local function TriggerItemCache(itemId)
    local itemString = "item:" .. itemId .. ":0:0:0"
    itemCacheTooltip:SetHyperlink(itemString)
    DebugLog("Triggered cache for item:", itemId)
end

-- Extract all item IDs from a text string
local function ExtractItemIds(text)
    local itemIds = {}
    local pos = 1

    while pos <= string.len(text) do
        -- Look for item links: |Hitem:ITEMID:
        local linkStart = string.find(text, "|Hitem:", pos, true)
        if not linkStart then
            break
        end

        -- Find the item ID (numbers after "item:")
        local idStart = linkStart + 7  -- length of "|Hitem:"
        local idEnd = string.find(text, ":", idStart, true)
        if idEnd then
            local itemIdStr = string.sub(text, idStart, idEnd - 1)
            local itemId = tonumber(itemIdStr)
            DebugLog("Extracted item ID:", itemIdStr, "->", itemId or "INVALID")
            if itemId then
                table.insert(itemIds, itemId)
            end
        end

        pos = linkStart + 1
    end

    DebugLog("Total item IDs extracted:", table.getn(itemIds))
    return itemIds
end

-- Check if all item IDs are cached, trigger cache for uncached ones
-- Returns: allCached (boolean), uncachedIds (table)
local function CheckItemCache(itemIds, triggerCache)
    local uncachedIds = {}

    for _, itemId in ipairs(itemIds) do
        local name, link = GetItemInfo(itemId)
        if not name then
            table.insert(uncachedIds, itemId)
            -- Use SetHyperlink to force server to send item data
            if triggerCache then
                TriggerItemCache(itemId)
            end
        end
    end

    return table.getn(uncachedIds) == 0, uncachedIds
end

-- Parse a hyperlink to extract its components
-- Returns: linkType, linkData, displayText, colorCode (or nils if parse fails)
local function ParseHyperlink(link)
    local colorCode = nil
    local linkType = nil
    local linkData = nil
    local displayText = nil

    -- Check for colored link: |cFFRRGGBB|H...
    local colorStart = string.find(link, "^|c%x%x%x%x%x%x%x%x")
    if colorStart then
        colorCode = string.sub(link, 3, 10)  -- Extract FFRRGGBB
    end

    -- Find |H to start of link data
    local hStart, hEnd = string.find(link, "|H")
    if not hStart then return nil end

    -- Find |h[ to find end of link data and start of display text
    local displayStart, displayStartEnd = string.find(link, "|h%[", hEnd)
    if not displayStart then return nil end

    -- Extract type:data between |H and |h[
    local typeData = string.sub(link, hEnd + 1, displayStart - 1)

    -- Split type:data by first colon
    local colonPos = string.find(typeData, ":")
    if colonPos then
        linkType = string.sub(typeData, 1, colonPos - 1)
        linkData = string.sub(typeData, colonPos + 1)
    else
        linkType = typeData
        linkData = ""
    end

    -- Find ]|h to get display text
    local displayEnd = string.find(link, "%]|h", displayStartEnd)
    if not displayEnd then return nil end

    displayText = string.sub(link, displayStartEnd + 1, displayEnd - 1)

    return linkType, linkData, displayText, colorCode
end

-- Extract item ID from link data (format: itemId:enchantId:suffixId:uniqueId)
local function GetItemIdFromLinkData(linkData)
    local colonPos = string.find(linkData, ":")
    if colonPos then
        return tonumber(string.sub(linkData, 1, colonPos - 1))
    else
        return tonumber(linkData)
    end
end

-- Extract quest ID from link data (format: questId:questLevel)
local function GetQuestIdFromLinkData(linkData)
    local colonPos = string.find(linkData, ":")
    if colonPos then
        return tonumber(string.sub(linkData, 1, colonPos - 1))
    else
        return tonumber(linkData)
    end
end

-- Get English quest name from pfQuest database
-- Returns nil if pfQuest not loaded or quest not found
local function GetEnglishQuestName(questId)
    if not pfDB or not pfDB["quests"] then
        return nil  -- pfQuest not loaded
    end

    -- Try Turtle WoW custom quests first (more specific)
    local turtleQuests = pfDB["quests"]["enUS-turtle"]
    if turtleQuests and turtleQuests[questId] then
        local entry = turtleQuests[questId]
        if type(entry) == "table" and entry["T"] then
            return entry["T"]
        end
        -- "_" means deleted, fall through to vanilla
    end

    -- Try vanilla quests
    local vanillaQuests = pfDB["quests"]["enUS"]
    if vanillaQuests and vanillaQuests[questId] then
        local entry = vanillaQuests[questId]
        if type(entry) == "table" and entry["T"] then
            return entry["T"]
        end
    end

    return nil  -- Quest not in database
end

-- Localize a hyperlink by replacing the display text with the English name
-- Currently supports: items (via GetItemInfo)
-- Falls back to original if localization not available
local function LocalizeHyperlink(link)
    DebugLog("LocalizeHyperlink called:", string.sub(link, 1, 40))

    local linkType, linkData, displayText, colorCode = ParseHyperlink(link)

    if not linkType then
        DebugLog("  Parse failed, returning original")
        return link  -- Couldn't parse, return original
    end

    DebugLog("  Parsed:", linkType, linkData and string.sub(linkData, 1, 20) or "nil")

    if linkType == "item" then
        local itemId = GetItemIdFromLinkData(linkData)
        DebugLog("  Item ID:", itemId)
        if itemId then
            -- GetItemInfo returns: name, link, quality, iLevel, ...
            local itemName, itemLink = GetItemInfo(itemId)
            DebugLog("  GetItemInfo returned:", itemName or "nil")

            if itemName then
                -- Always rebuild the link manually to ensure correct structure
                -- Use original color code from the Chinese link, just replace the name
                local result
                if colorCode then
                    result = "|c" .. colorCode .. "|H" .. linkType .. ":" .. linkData .. "|h[" .. itemName .. "]|h|r"
                else
                    result = "|H" .. linkType .. ":" .. linkData .. "|h[" .. itemName .. "]|h"
                end
                DebugLog("  Rebuilt link with English name")
                return result
            end
        end
    elseif linkType == "quest" then
        local questId = GetQuestIdFromLinkData(linkData)
        DebugLog("  Quest ID:", questId)
        if questId then
            local questName = GetEnglishQuestName(questId)
            DebugLog("  GetEnglishQuestName returned:", questName or "nil")

            if questName then
                local result
                if colorCode then
                    result = "|c" .. colorCode .. "|H" .. linkType .. ":" .. linkData .. "|h[" .. questName .. "]|h|r"
                else
                    result = "|H" .. linkType .. ":" .. linkData .. "|h[" .. questName .. "]|h"
                end
                DebugLog("  Rebuilt quest link with English name")
                return result
            end
        end
    else
        DebugLog("  Not an item or quest link, skipping localization")
    end
    -- Quest localization uses pfQuest database (if available)
    -- Spell localization not supported in vanilla WoW 1.12 (no GetSpellInfo API)

    DebugLog("  No localized name, returning original")
    return link  -- No localized name found, return original
end

-- ============================================================================
-- ROBUST HYPERLINK EXTRACTION
-- ============================================================================
-- WoW 1.12 hyperlink format: |cFFRRGGBB|Htype:data|h[DisplayText]|h|r
-- Key: Extract FULL hyperlinks including color codes as single units

-- Find all hyperlinks in text, returning their positions and content
local function FindAllHyperlinks(text)
    local hyperlinks = {}
    local pos = 1

    while pos <= string.len(text) do
        -- Look for hyperlink start - either |c (colored) or |H (plain)
        local colorStart = string.find(text, "|c%x%x%x%x%x%x%x%x|H", pos)
        local plainStart = string.find(text, "|H", pos)

        local linkStart = nil
        local hasColor = false

        -- Determine which comes first
        if colorStart and (not plainStart or colorStart <= plainStart) then
            linkStart = colorStart
            hasColor = true
        elseif plainStart then
            -- Make sure this |H isn't part of a colored link we already found
            if not colorStart or plainStart < colorStart then
                linkStart = plainStart
                hasColor = false
            end
        end

        if not linkStart then
            break
        end

        -- Find the end of the hyperlink: |h[...]|h followed by optional |r
        -- Pattern: find |h[ then find ]|h
        local displayStart = string.find(text, "|h%[", linkStart)
        if not displayStart then
            pos = linkStart + 1
        else
            -- Find closing ]|h
            local displayEnd = string.find(text, "%]|h", displayStart)
            if not displayEnd then
                pos = linkStart + 1
            else
                local linkEnd = displayEnd + 2  -- Position after ]|h

                -- Check for |r after the link
                if string.sub(text, linkEnd + 1, linkEnd + 2) == "|r" then
                    linkEnd = linkEnd + 2
                end

                -- If we have color, make sure we started from |c
                local actualStart = linkStart
                if hasColor then
                    actualStart = colorStart
                end

                local fullLink = string.sub(text, actualStart, linkEnd)

                DebugLog("Found hyperlink:", string.sub(fullLink, 1, 80))

                table.insert(hyperlinks, {
                    startPos = actualStart,
                    endPos = linkEnd,
                    content = fullLink
                })

                pos = linkEnd + 1
            end
        end
    end

    return hyperlinks
end

-- Split message into segments: text and hyperlinks
-- Returns array of {type="text"|"link", content=string}
local function SplitIntoSegments(text)
    local segments = {}
    local hyperlinks = FindAllHyperlinks(text)

    if table.getn(hyperlinks) == 0 then
        -- No hyperlinks, entire text is translatable
        if text ~= "" then
            table.insert(segments, {type = "text", content = text})
        end
        return segments
    end

    local lastEnd = 0
    for _, link in ipairs(hyperlinks) do
        -- Add text before this hyperlink
        if link.startPos > lastEnd + 1 then
            local textBefore = string.sub(text, lastEnd + 1, link.startPos - 1)
            if textBefore ~= "" then
                table.insert(segments, {type = "text", content = textBefore})
            end
        end

        -- Add the hyperlink (with localized display name if available)
        table.insert(segments, {type = "link", content = LocalizeHyperlink(link.content)})
        lastEnd = link.endPos
    end

    -- Add text after last hyperlink
    if lastEnd < string.len(text) then
        local textAfter = string.sub(text, lastEnd + 1)
        if textAfter ~= "" then
            table.insert(segments, {type = "text", content = textAfter})
        end
    end

    return segments
end

-- Check if any text segments contain source language characters
local function HasTranslatableContent(segments)
    for _, seg in ipairs(segments) do
        if seg.type == "text" and ContainsSourceLanguage(seg.content) then
            return true
        end
    end
    return false
end

-- Build text to translate: only text segments, hyperlinks become URL placeholders
-- URLs are preserved by Google Translate because they're recognized as web addresses
local function BuildTranslatableText(segments)
    local parts = {}
    local linkIndex = 0

    for _, seg in ipairs(segments) do
        if seg.type == "text" then
            table.insert(parts, seg.content)
        else
            linkIndex = linkIndex + 1
            -- Use URL format - translation APIs preserve URLs
            table.insert(parts, "http://ph.wt/" .. linkIndex)
        end
    end

    return table.concat(parts, "")
end

-- Reconstruct message from translated text and original segments
local function ReconstructMessage(segments, translatedText)
    local result = {}
    local workText = translatedText

    -- Count links
    local linkCount = 0
    local linkContents = {}
    for _, seg in ipairs(segments) do
        if seg.type == "link" then
            linkCount = linkCount + 1
            linkContents[linkCount] = seg.content
        end
    end

    if linkCount == 0 then
        return translatedText
    end

    -- Replace each URL placeholder with the original hyperlink
    for i = 1, linkCount do
        local placeholder = "http://ph.wt/" .. i
        -- Also try with https (in case API changes it)
        local placeholder2 = "https://ph.wt/" .. i
        -- Also try URL-encoded or modified versions
        local placeholder3 = "http://ph .wt/" .. i
        local placeholder4 = "http: //ph.wt/" .. i

        local found = false

        DebugLog("Link", i, "content:", string.sub(linkContents[i] or "nil", 1, 80))

        -- Try exact match first
        local startPos, endPos = string.find(workText, placeholder, 1, true)
        if startPos then
            workText = string.sub(workText, 1, startPos - 1) .. linkContents[i] .. string.sub(workText, endPos + 1)
            found = true
            DebugLog("Replaced placeholder", i)
        end

        -- Try https version
        if not found then
            startPos, endPos = string.find(workText, placeholder2, 1, true)
            if startPos then
                workText = string.sub(workText, 1, startPos - 1) .. linkContents[i] .. string.sub(workText, endPos + 1)
                found = true
                DebugLog("Replaced https placeholder", i)
            end
        end

        -- Try with space after http:
        if not found then
            startPos, endPos = string.find(workText, placeholder3, 1, true)
            if startPos then
                workText = string.sub(workText, 1, startPos - 1) .. linkContents[i] .. string.sub(workText, endPos + 1)
                found = true
            end
        end

        if not found then
            startPos, endPos = string.find(workText, placeholder4, 1, true)
            if startPos then
                workText = string.sub(workText, 1, startPos - 1) .. linkContents[i] .. string.sub(workText, endPos + 1)
                found = true
            end
        end

        if not found then
            DebugLog("Placeholder not found:", placeholder)
            -- Append the link at the end as fallback
            workText = workText .. " " .. linkContents[i]
        end
    end

    return workText
end

-- ============================================================================
-- CHAT FRAME HOOKING
-- ============================================================================

local function HookChatFrames()
    if not originalAddMessage and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        originalAddMessage = DEFAULT_CHAT_FRAME.AddMessage
    end

    for i = 1, NUM_CHAT_WINDOWS do
        local frameName = "ChatFrame" .. i
        local frame = getglobal(frameName)

        if frame and frame.AddMessage and not frame.WoWTranslateHooked then
            frame.WoWTranslateHooked = true
            local frameOriginalAddMessage = frame.AddMessage

            frame.AddMessage = function(self, text, r, g, b, id, holdTime)
                if not WoWTranslateDB or not WoWTranslateDB.enabled then
                    frameOriginalAddMessage(self, text, r, g, b, id, holdTime)
                    return
                end

                if not text or not ContainsSourceLanguage(text) then
                    frameOriginalAddMessage(self, text, r, g, b, id, holdTime)
                    return
                end

                -- Log original message for debugging
                DebugLog("ORIGINAL MSG:", string.sub(text, 1, 150))

                -- Check for item links and ensure items are cached before processing
                local itemIds = ExtractItemIds(text)
                if table.getn(itemIds) > 0 then
                    -- Pass true to trigger cache via SetHyperlink for uncached items
                    local allCached, uncachedIds = CheckItemCache(itemIds, true)

                    if not allCached then
                        -- Queue message and wait for item cache
                        itemCacheCounter = itemCacheCounter + 1
                        local cacheId = tostring(itemCacheCounter)

                        DebugLog("Waiting for item cache:", table.getn(uncachedIds), "items")

                        itemCacheQueue[cacheId] = {
                            frame = self,
                            originalAddMessage = frameOriginalAddMessage,
                            text = text,
                            itemIds = itemIds,
                            r = r,
                            g = g,
                            b = b,
                            id = id,
                            holdTime = holdTime,
                            timestamp = GetTime(),
                            retries = 0
                        }
                        return  -- Don't display yet, will be handled by cache poller
                    end
                end

                -- Split into segments (text and hyperlinks)
                local segments = SplitIntoSegments(text)

                DebugLog("Segments found:", table.getn(segments))
                for idx, seg in ipairs(segments) do
                    DebugLog("  Seg", idx, seg.type, ":", string.sub(seg.content, 1, 60))
                end

                -- Check if there's Chinese text to translate (outside hyperlinks)
                if not HasTranslatableContent(segments) then
                    -- All Chinese is inside hyperlinks - show original
                    frameOriginalAddMessage(self, text, r, g, b, id, holdTime)
                    return
                end

                -- Check if credits are exhausted FIRST - if so, pass through original text
                -- This skips both cache and API to show untranslated text
                if WoWTranslate_API and WoWTranslate_API.IsCreditsExhausted() then
                    DebugLog("Credits exhausted, passing through original (no cache, no API)")
                    WoWTranslate_API.ShowCreditWarningIfNeeded()
                    frameOriginalAddMessage(self, text, r, g, b, id, holdTime)
                    return
                end

                -- Build text to send to translation API
                local textToTranslate = BuildTranslatableText(segments)

                DebugLog("To translate:", string.sub(textToTranslate, 1, 50))

                -- Check cache first
                local cached, found = WoWTranslate_CacheGet(text)
                if found then
                    DebugLog("Cache hit")
                    WoWTranslate_API.TrackCacheHit(string.len(text))
                    frameOriginalAddMessage(self, cached, r, g, b, id, holdTime)
                    return
                end

                -- Need API translation
                if WoWTranslate_API and WoWTranslate_API.IsAvailable() then
                    messageCounter = messageCounter + 1
                    local msgId = tostring(messageCounter)

                    pendingMessages[msgId] = {
                        frame = self,
                        originalAddMessage = frameOriginalAddMessage,
                        originalText = text,
                        segments = segments,
                        r = r,
                        g = g,
                        b = b,
                        id = id,
                        holdTime = holdTime,
                        timestamp = GetTime()
                    }

                    DebugLog("Queued for API:", msgId)

                    WoWTranslate_API.Translate(textToTranslate, function(translation, err)
                        local pending = pendingMessages[msgId]
                        if pending then
                            pendingMessages[msgId] = nil

                            if translation then
                                DebugLog("API returned:", string.sub(translation, 1, 50))

                                -- Reconstruct with original hyperlinks
                                local finalText = ReconstructMessage(pending.segments, translation)

                                DebugLog("Final:", string.sub(finalText, 1, 100))

                                -- Debug: Check if links still have proper structure
                                if string.find(finalText, "|H") and string.find(finalText, "|h") then
                                    DebugLog("Final has |H and |h markers - link structure OK")
                                else
                                    DebugLog("WARNING: Final missing link markers!")
                                end

                                WoWTranslate_CacheSave(pending.originalText, finalText)
                                pending.originalAddMessage(pending.frame, finalText, pending.r, pending.g, pending.b, pending.id, pending.holdTime)
                            else
                                DebugLog("API error:", err)
                                -- Check for credit-related errors and show warning
                                if err and (string.find(err, "INSUFFICIENT_CREDITS") or string.find(err, "Insufficient credits")) then
                                    if originalAddMessage then
                                        originalAddMessage(DEFAULT_CHAT_FRAME, "|cFFFF0000[WoWTranslate] Out of credits! Add more at wowtranslate.duckdns.org|r")
                                    end
                                elseif err and (string.find(err, "INVALID_API_KEY") or string.find(err, "Invalid API key")) then
                                    if originalAddMessage then
                                        originalAddMessage(DEFAULT_CHAT_FRAME, "|cFFFF0000[WoWTranslate] Invalid API key! Check your key in /wt show|r")
                                    end
                                end
                                pending.originalAddMessage(pending.frame, pending.originalText, pending.r, pending.g, pending.b, pending.id, pending.holdTime)
                            end
                        end
                    end)

                    return
                else
                    DebugLog("DLL not available")
                end

                frameOriginalAddMessage(self, text, r, g, b, id, holdTime)
            end

            DebugLog("Hooked", frameName)
        end
    end
end

local function CleanupPendingMessages()
    local now = GetTime()
    for msgId, pending in pairs(pendingMessages) do
        if now - pending.timestamp > 30 then
            DebugLog("Message timed out:", msgId)
            pending.originalAddMessage(pending.frame, pending.originalText, pending.r, pending.g, pending.b, pending.id, pending.holdTime)
            pendingMessages[msgId] = nil
        end
    end
end

-- ============================================================================
-- OUTGOING TRANSLATION (English -> Chinese)
-- ============================================================================

-- Clean up queued outgoing messages after timeout
local function CleanupOutgoingQueue()
    local now = GetTime()
    for queueId, item in pairs(outgoingQueue) do
        if now - item.timestamp > 30 then
            DebugLog("Outgoing message timed out:", queueId)
            if originalAddMessage then
                originalAddMessage(DEFAULT_CHAT_FRAME, "|cFFFF0000[WoWTranslate] Translation timed out, sending original|r")
            end
            originalSendChatMessage(item.originalMsg, item.chatType, item.language, item.channel)
            outgoingQueue[queueId] = nil
        end
    end
end

-- Hooked SendChatMessage for outgoing translation
local function HookedSendChatMessage(msg, chatType, language, channel)
    -- Handle nil chatType (WoW 1.12 compatibility)
    if not chatType then
        DebugLog("chatType is nil, sending original")
        return originalSendChatMessage(msg, chatType, language, channel)
    end

    -- Skip if outgoing disabled
    if not WoWTranslateDB or not WoWTranslateDB.outgoingEnabled then
        return originalSendChatMessage(msg, chatType, language, channel)
    end

    -- Skip if channel not enabled
    if not WoWTranslateDB.outgoingChannels or not WoWTranslateDB.outgoingChannels[chatType] then
        DebugLog("Channel not enabled for outgoing:", chatType)
        return originalSendChatMessage(msg, chatType, language, channel)
    end

    -- Skip empty messages
    if not msg or msg == "" then
        return originalSendChatMessage(msg, chatType, language, channel)
    end

    -- Skip if already contains target language (don't double-translate)
    if ContainsOutgoingTargetLanguage(msg) then
        DebugLog("Message already contains target language, skipping outgoing translation")
        return originalSendChatMessage(msg, chatType, language, channel)
    end

    -- Skip if DLL not available
    if not WoWTranslate_API or not WoWTranslate_API.IsAvailable() then
        DebugLog("DLL not available for outgoing translation")
        return originalSendChatMessage(msg, chatType, language, channel)
    end

    -- Skip if credits are exhausted
    if WoWTranslate_API.IsCreditsExhausted() then
        DebugLog("Credits exhausted, sending original")
        WoWTranslate_API.ShowCreditWarningIfNeeded()
        return originalSendChatMessage(msg, chatType, language, channel)
    end

    -- Split message into segments (text and hyperlinks) to preserve links
    local segments = SplitIntoSegments(msg)
    DebugLog("Outgoing segments:", table.getn(segments))

    -- Build text to translate (hyperlinks replaced with URL placeholders)
    local textToTranslate = BuildTranslatableText(segments)
    DebugLog("Outgoing to translate:", textToTranslate)

    -- Queue for translation
    outgoingCounter = outgoingCounter + 1
    local queueId = tostring(outgoingCounter)

    outgoingQueue[queueId] = {
        originalMsg = msg,
        segments = segments,  -- Store segments for reconstruction
        chatType = chatType,
        language = language,
        channel = channel,
        timestamp = GetTime()
    }

    -- Show local feedback
    if originalAddMessage then
        originalAddMessage(DEFAULT_CHAT_FRAME, "|cFFFFFF00[WoWTranslate] Translating...|r")
    end

    DebugLog("Outgoing queued:", queueId, msg)

    -- Request translation (send only the text portions, not hyperlinks)
    WoWTranslate_API.TranslateOutgoing(textToTranslate, function(translation, err)
        local queued = outgoingQueue[queueId]
        if not queued then
            DebugLog("Outgoing callback but queue item gone:", queueId)
            return
        end
        outgoingQueue[queueId] = nil

        if translation then
            DebugLog("Outgoing translation received:", translation)

            -- Reconstruct message with original hyperlinks
            local reconstructed = ReconstructMessage(queued.segments, translation)
            DebugLog("Outgoing reconstructed:", reconstructed)

            -- Build message with prefix
            local prefix = WoWTranslateDB.outgoingPrefix or "[Translated by WoWTranslate]"
            local finalMsg = prefix .. " " .. reconstructed

            -- Truncate if over 255 bytes (WoW chat limit)
            if string.len(finalMsg) > 255 then
                finalMsg = string.sub(finalMsg, 1, 252) .. "..."
            end

            originalSendChatMessage(finalMsg, queued.chatType, queued.language, queued.channel)

            if originalAddMessage then
                originalAddMessage(DEFAULT_CHAT_FRAME, "|cFF00FF00[WoWTranslate] Sent:|r " .. finalMsg)
            end
        else
            -- Translation failed - send original
            DebugLog("Outgoing translation failed:", err)
            if originalAddMessage then
                originalAddMessage(DEFAULT_CHAT_FRAME, "|cFFFF0000[WoWTranslate] Translation failed, sending original|r")
            end
            originalSendChatMessage(queued.originalMsg, queued.chatType, queued.language, queued.channel)
        end
    end)
end

-- Track if hook is installed (for diagnostics)
local outgoingHookInstalled = false

-- Install the outgoing message hook
local function InstallOutgoingHook()
    if SendChatMessage ~= HookedSendChatMessage then
        DebugLog("Installing outgoing SendChatMessage hook")
        SendChatMessage = HookedSendChatMessage
        outgoingHookInstalled = true
    end
end

-- Remove the outgoing message hook
local function RemoveOutgoingHook()
    if SendChatMessage == HookedSendChatMessage then
        DebugLog("Removing outgoing SendChatMessage hook")
        SendChatMessage = originalSendChatMessage
        outgoingHookInstalled = false
    end
end

-- Check if hook is active (for diagnostics)
local function IsOutgoingHookActive()
    return outgoingHookInstalled and SendChatMessage == HookedSendChatMessage
end

-- ============================================================================
-- GLOBAL FUNCTIONS FOR CONFIG UI
-- ============================================================================

-- Toggle outgoing translation (called from config UI)
function WoWTranslate_SetOutgoingEnabled(enabled)
    if enabled then
        WoWTranslateDB.outgoingEnabled = true
        InstallOutgoingHook()
    else
        WoWTranslateDB.outgoingEnabled = false
        RemoveOutgoingHook()
    end
end

-- Toggle incoming translation (called from config UI)
function WoWTranslate_SetIncomingEnabled(enabled)
    WoWTranslateDB.enabled = enabled
end

-- Set channel enabled state (called from config UI)
function WoWTranslate_SetChannelEnabled(channel, enabled)
    if not WoWTranslateDB.outgoingChannels then
        WoWTranslateDB.outgoingChannels = {}
    end
    WoWTranslateDB.outgoingChannels[channel] = enabled
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================
SLASH_WOWTRANSLATE1 = "/wt"
SLASH_WOWTRANSLATE2 = "/wowtranslate"

SlashCmdList["WOWTRANSLATE"] = function(msg)
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

        local queuedCount = 0
        for _ in pairs(pendingMessages) do
            queuedCount = queuedCount + 1
        end

        local outgoingQueuedCount = 0
        for _ in pairs(outgoingQueue) do
            outgoingQueuedCount = outgoingQueuedCount + 1
        end

        local outgoingStatus = WoWTranslateDB.outgoingEnabled
            and "|cFF00FF00ON|r"
            or "|cFFFF0000OFF|r"

        local hookStatus = IsOutgoingHookActive()
            and "|cFF00FF00ACTIVE|r"
            or "|cFFFF0000INACTIVE|r"

        -- Get credits info
        local creditsStr = WoWTranslate_API.GetCreditsFormatted and WoWTranslate_API.GetCreditsFormatted() or "Unknown"
        local creditsLow = WoWTranslate_API.IsCreditsLow and WoWTranslate_API.IsCreditsLow()
        local creditsExhausted = WoWTranslate_API.IsCreditsExhausted and WoWTranslate_API.IsCreditsExhausted()

        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Status:")
        DEFAULT_CHAT_FRAME:AddMessage("  DLL: " .. dllStatus)
        if creditsExhausted then
            DEFAULT_CHAT_FRAME:AddMessage("  Credits: |cFFFF0000" .. creditsStr .. " (EXHAUSTED - translation disabled)|r")
        elseif creditsLow then
            DEFAULT_CHAT_FRAME:AddMessage("  Credits: |cFFFF0000" .. creditsStr .. " (LOW!)|r")
        else
            DEFAULT_CHAT_FRAME:AddMessage("  Credits: |cFF00FF00" .. creditsStr .. "|r")
        end
        DEFAULT_CHAT_FRAME:AddMessage("  Incoming (CN->EN): " .. (WoWTranslateDB.enabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"))
        DEFAULT_CHAT_FRAME:AddMessage("  Outgoing (EN->CN): " .. outgoingStatus)
        DEFAULT_CHAT_FRAME:AddMessage("  Outgoing Hook: " .. hookStatus)
        DEFAULT_CHAT_FRAME:AddMessage("  Glossary entries: " .. glossaryCount)
        DEFAULT_CHAT_FRAME:AddMessage("  Cached translations: " .. cacheStats.entries)
        DEFAULT_CHAT_FRAME:AddMessage("  Cache hit rate: " .. string.format("%.1f%%", cacheStats.hitRate))
        DEFAULT_CHAT_FRAME:AddMessage("  Pending API requests: " .. pendingCount)
        DEFAULT_CHAT_FRAME:AddMessage("  Queued incoming: " .. queuedCount)
        DEFAULT_CHAT_FRAME:AddMessage("  Queued outgoing: " .. outgoingQueuedCount)

    elseif cmd == "test" then
        local testText = arg or "\228\189\160\229\165\189"
        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Testing: " .. testText)

        local cached, found = WoWTranslate_CacheGet(testText)
        if found then
            DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Cache hit: " .. cached)
            return
        end

        if not WoWTranslate_API.IsAvailable() then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WoWTranslate] DLL not available|r")
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

    elseif cmd == "testlink" then
        -- Test hyperlink parsing and localization
        local testMsg = "|cffffffff|Hplayer:TestName|h[TestName]|h|r says hello"
        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Testing hyperlink parse:")
        DEFAULT_CHAT_FRAME:AddMessage("  Input: " .. testMsg)
        local segs = SplitIntoSegments(testMsg)
        for idx, seg in ipairs(segs) do
            DEFAULT_CHAT_FRAME:AddMessage("  Seg " .. idx .. " [" .. seg.type .. "]: " .. seg.content)
        end

    elseif cmd == "testitem" then
        -- Test item localization with a known item
        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Testing item localization...")
        local itemId = 2589  -- Default: Linen Cloth (common item)
        if arg and arg ~= "" then
            itemId = tonumber(arg) or 19716
        end
        DEFAULT_CHAT_FRAME:AddMessage("  Item ID: " .. tostring(itemId))
        local itemName = GetItemInfo(itemId)
        if itemName then
            DEFAULT_CHAT_FRAME:AddMessage("  GetItemInfo returned: " .. itemName)
            -- Create a fake Chinese link to test localization
            local testLink = "|cffa335ee|Hitem:" .. itemId .. ":0:0:0|h[测试物品]|h|r"
            DEFAULT_CHAT_FRAME:AddMessage("  Test link: " .. testLink)
            local localized = LocalizeHyperlink(testLink)
            DEFAULT_CHAT_FRAME:AddMessage("  Localized: " .. localized)
        else
            DEFAULT_CHAT_FRAME:AddMessage("  GetItemInfo returned nil - item not in client cache")
            DEFAULT_CHAT_FRAME:AddMessage("  Try: /wt testitem with an item ID you've seen (hover over an item link first)")
        end

    elseif cmd == "testquest" then
        -- Test quest localization using pfQuest database
        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Testing quest localization...")
        local questId = 913  -- Default: Stranglethorn Fever (common quest)
        if arg and arg ~= "" then
            questId = tonumber(arg) or 913
        end
        DEFAULT_CHAT_FRAME:AddMessage("  Quest ID: " .. tostring(questId))

        -- Check if pfQuest database is available
        if not pfDB or not pfDB["quests"] then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000  pfQuest database not found!|r")
            DEFAULT_CHAT_FRAME:AddMessage("  Quest localization requires pfQuest addon to be installed")
            return
        end

        local questName = GetEnglishQuestName(questId)
        if questName then
            DEFAULT_CHAT_FRAME:AddMessage("  GetEnglishQuestName returned: " .. questName)
            -- Create a fake Chinese link to test localization
            local testLink = "|cffffff00|Hquest:" .. questId .. ":60|h[测试任务]|h|r"
            DEFAULT_CHAT_FRAME:AddMessage("  Test link: " .. testLink)
            local localized = LocalizeHyperlink(testLink)
            DEFAULT_CHAT_FRAME:AddMessage("  Localized: " .. localized)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000  Quest not found in pfQuest database|r")
            DEFAULT_CHAT_FRAME:AddMessage("  Try: /wt testquest <questId> with a known quest ID")
        end

    -- =====================================================================
    -- OUTGOING TRANSLATION COMMANDS
    -- =====================================================================
    elseif cmd == "outgoing" then
        if arg == "on" or arg == "enable" then
            WoWTranslateDB.outgoingEnabled = true
            InstallOutgoingHook()
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WoWTranslate] Outgoing translation enabled|r")
            DEFAULT_CHAT_FRAME:AddMessage("  Your English messages will be translated to Chinese")
        elseif arg == "off" or arg == "disable" then
            WoWTranslateDB.outgoingEnabled = false
            RemoveOutgoingHook()
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WoWTranslate] Outgoing translation disabled|r")
        else
            local status = WoWTranslateDB.outgoingEnabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"
            DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Outgoing translation: " .. status)
            DEFAULT_CHAT_FRAME:AddMessage("  Usage: /wt outgoing on|off")
        end

    elseif cmd == "outchannel" then
        if not WoWTranslateDB.outgoingChannels then
            WoWTranslateDB.outgoingChannels = defaults.outgoingChannels
        end

        if arg and arg ~= "" then
            local channelType = string.upper(arg)
            if WoWTranslateDB.outgoingChannels[channelType] ~= nil then
                WoWTranslateDB.outgoingChannels[channelType] = not WoWTranslateDB.outgoingChannels[channelType]
                local newStatus = WoWTranslateDB.outgoingChannels[channelType] and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"
                DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Outgoing " .. channelType .. ": " .. newStatus)
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WoWTranslate] Unknown channel: " .. channelType .. "|r")
                DEFAULT_CHAT_FRAME:AddMessage("  Valid channels: WHISPER, PARTY, GUILD, RAID, SAY, YELL")
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Outgoing channel settings:")
            for channelType, enabled in pairs(WoWTranslateDB.outgoingChannels) do
                local status = enabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"
                DEFAULT_CHAT_FRAME:AddMessage("  " .. channelType .. ": " .. status)
            end
            DEFAULT_CHAT_FRAME:AddMessage("  Usage: /wt outchannel <WHISPER|PARTY|GUILD|RAID|SAY|YELL>")
        end

    elseif cmd == "prefix" then
        if arg and arg ~= "" then
            WoWTranslateDB.outgoingPrefix = arg
            DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Outgoing prefix set to: " .. arg)
        else
            DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Current prefix: " .. (WoWTranslateDB.outgoingPrefix or "[Translated]"))
            DEFAULT_CHAT_FRAME:AddMessage("  Usage: /wt prefix <text>")
        end

    elseif cmd == "testout" then
        local testText = arg or "Hello, how are you?"
        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Testing outgoing translation (EN->CN):")
        DEFAULT_CHAT_FRAME:AddMessage("  Input: " .. testText)

        if not WoWTranslate_API.IsAvailable() then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WoWTranslate] DLL not available|r")
            return
        end

        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Requesting from API...")
        WoWTranslate_API.TranslateOutgoing(testText, function(result, err)
            if result then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WoWTranslate] Translation:|r " .. result)
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WoWTranslate] Error: " .. (err or "unknown") .. "|r")
            end
        end)

    -- =====================================================================
    -- CONFIGURATION UI COMMANDS
    -- =====================================================================
    elseif cmd == "show" or cmd == "config" or cmd == "options" then
        WoWTranslate_ShowConfig()

    elseif cmd == "hide" then
        WoWTranslate_HideConfig()

    else
        DEFAULT_CHAT_FRAME:AddMessage("[WoWTranslate] Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt show - Open configuration panel")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt hide - Close configuration panel")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt on|off - Enable/disable incoming translation")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt key <apikey> - Set API key")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt status - Show status")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt clearcache - Clear cache")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt debug - Toggle debug mode")
        DEFAULT_CHAT_FRAME:AddMessage("  -- Outgoing --")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt outgoing on|off - Toggle outgoing translation")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt outchannel [type] - Show/toggle channel settings")
        DEFAULT_CHAT_FRAME:AddMessage("  /wt prefix <text> - Set message prefix")
    end
end

-- ============================================================================
-- ADDON INITIALIZATION
-- ============================================================================
local function InitializeSettings()
    if not WoWTranslateDB then WoWTranslateDB = {} end
    if not WoWTranslateDebugLog then WoWTranslateDebugLog = {} end

    for key, value in pairs(defaults) do
        if WoWTranslateDB[key] == nil then
            WoWTranslateDB[key] = value
        end
    end

    -- Migration: fix old short prefix to new full prefix
    if WoWTranslateDB.outgoingPrefix == "[Translated]" then
        WoWTranslateDB.outgoingPrefix = "[Translated by WoWTranslate]"
    end

    DEBUG_MODE = WoWTranslateDB.debugMode or false
end

local function OnAddonLoaded()
    if addonLoaded then return end
    addonLoaded = true

    InitializeSettings()

    local dllOk = WoWTranslate_API.CheckDLL()

    if dllOk and WoWTranslateDB.apiKey and WoWTranslateDB.apiKey ~= "" then
        WoWTranslate_API.SetKey(WoWTranslateDB.apiKey)
    end

    if dllOk then
        WoWTranslate_API.StartPolling()
    end

    local glossaryCount = WoWTranslate_GetGlossaryCount()
    local cacheCount = WoWTranslate_CacheStats().entries
    local dllStatus = dllOk and "|cFF00FF00DLL OK|r" or "|cFFFFFF00DLL not loaded|r"

    DEFAULT_CHAT_FRAME:AddMessage("|cFF00CCFFWoWTranslate|r v0.10 - " .. dllStatus .. " | /wt show")
end

local function OnPlayerLogin()
    HookChatFrames()

    if not WoWTranslate_API.IsAvailable() then
        WoWTranslate_API.CheckDLL()
        if WoWTranslate_API.IsAvailable() then
            WoWTranslate_API.StartPolling()
            if WoWTranslateDB and WoWTranslateDB.apiKey and WoWTranslateDB.apiKey ~= "" then
                WoWTranslate_API.SetKey(WoWTranslateDB.apiKey)
            end
        end
    end

    -- Install outgoing hook if enabled
    if WoWTranslateDB and WoWTranslateDB.outgoingEnabled then
        InstallOutgoingHook()
    end
end

-- ============================================================================
-- EVENT FRAME
-- ============================================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WoWTranslate" then
        OnAddonLoaded()
    elseif event == "PLAYER_LOGIN" then
        OnPlayerLogin()
    end
end)

local cleanupFrame = CreateFrame("Frame")
local cleanupElapsed = 0
cleanupFrame:SetScript("OnUpdate", function()
    cleanupElapsed = cleanupElapsed + arg1
    if cleanupElapsed >= 5 then
        cleanupElapsed = 0
        CleanupPendingMessages()
        CleanupOutgoingQueue()
    end
end)

-- ============================================================================
-- ITEM CACHE POLLING
-- ============================================================================
-- Process messages waiting for item cache data

local function ProcessItemCacheMessage(queued)
    local text = queued.text

    -- Split into segments (text and hyperlinks) - items should be cached now
    local segments = SplitIntoSegments(text)

    DebugLog("Processing cached item message, segments:", table.getn(segments))

    -- Check if there's Chinese text to translate (outside hyperlinks)
    if not HasTranslatableContent(segments) then
        -- All Chinese is inside hyperlinks - show with localized links
        local result = ""
        for _, seg in ipairs(segments) do
            result = result .. seg.content
        end
        queued.originalAddMessage(queued.frame, result, queued.r, queued.g, queued.b, queued.id, queued.holdTime)
        return
    end

    -- Check if credits are exhausted FIRST - if so, pass through original (no cache, no API)
    if WoWTranslate_API and WoWTranslate_API.IsCreditsExhausted() then
        DebugLog("Credits exhausted, passing through item message (no cache, no API)")
        WoWTranslate_API.ShowCreditWarningIfNeeded()
        queued.originalAddMessage(queued.frame, text, queued.r, queued.g, queued.b, queued.id, queued.holdTime)
        return
    end

    -- Build text to send to translation API
    local textToTranslate = BuildTranslatableText(segments)

    -- Check cache first
    local cached, found = WoWTranslate_CacheGet(text)
    if found then
        DebugLog("Cache hit for item message")
        WoWTranslate_API.TrackCacheHit(string.len(text))
        queued.originalAddMessage(queued.frame, cached, queued.r, queued.g, queued.b, queued.id, queued.holdTime)
        return
    end

    -- Need API translation
    if WoWTranslate_API and WoWTranslate_API.IsAvailable() then
        messageCounter = messageCounter + 1
        local msgId = tostring(messageCounter)

        pendingMessages[msgId] = {
            frame = queued.frame,
            originalAddMessage = queued.originalAddMessage,
            originalText = text,
            segments = segments,
            r = queued.r,
            g = queued.g,
            b = queued.b,
            id = queued.id,
            holdTime = queued.holdTime,
            timestamp = GetTime()
        }

        DebugLog("Queued item message for API:", msgId)

        WoWTranslate_API.Translate(textToTranslate, function(translation, err)
            local pending = pendingMessages[msgId]
            if pending then
                pendingMessages[msgId] = nil

                if translation then
                    DebugLog("API returned for item msg:", string.sub(translation, 1, 50))
                    local finalText = ReconstructMessage(pending.segments, translation)
                    WoWTranslate_CacheSave(pending.originalText, finalText)
                    pending.originalAddMessage(pending.frame, finalText, pending.r, pending.g, pending.b, pending.id, pending.holdTime)
                else
                    DebugLog("API error for item msg:", err)
                    pending.originalAddMessage(pending.frame, pending.originalText, pending.r, pending.g, pending.b, pending.id, pending.holdTime)
                end
            end
        end)
    else
        -- No API, just show with localized links
        local result = ""
        for _, seg in ipairs(segments) do
            result = result .. seg.content
        end
        queued.originalAddMessage(queued.frame, result, queued.r, queued.g, queued.b, queued.id, queued.holdTime)
    end
end

local itemCacheFrame = CreateFrame("Frame")
local itemCacheElapsed = 0
local ITEM_CACHE_POLL_INTERVAL = 0.05  -- Poll every 50ms
local ITEM_CACHE_MAX_WAIT = 3.0        -- Max wait 3 seconds
local ITEM_CACHE_RETRY_INTERVAL = 0.5  -- Retry triggering cache every 500ms

itemCacheFrame:SetScript("OnUpdate", function()
    itemCacheElapsed = itemCacheElapsed + arg1
    if itemCacheElapsed < ITEM_CACHE_POLL_INTERVAL then
        return
    end
    itemCacheElapsed = 0

    for cacheId, queued in pairs(itemCacheQueue) do
        local allCached = CheckItemCache(queued.itemIds, false)  -- Just check, don't trigger
        local elapsed = GetTime() - queued.timestamp

        if allCached then
            DebugLog("Items cached, processing message:", cacheId)
            itemCacheQueue[cacheId] = nil
            ProcessItemCacheMessage(queued)
        elseif elapsed > ITEM_CACHE_MAX_WAIT then
            -- Timeout - process anyway with whatever we have
            local _, stillUncached = CheckItemCache(queued.itemIds, false)
            DebugLog("Item cache timeout after", elapsed, "sec, uncached:", table.getn(stillUncached))
            for _, uid in ipairs(stillUncached) do
                DebugLog("  Still uncached item ID:", uid)
            end
            itemCacheQueue[cacheId] = nil
            ProcessItemCacheMessage(queued)
        else
            -- Retry triggering cache periodically for stubborn items
            if not queued.lastRetry or (GetTime() - queued.lastRetry) > ITEM_CACHE_RETRY_INTERVAL then
                queued.lastRetry = GetTime()
                queued.retries = (queued.retries or 0) + 1
                if queued.retries <= 5 then  -- Max 5 retries
                    local _, stillUncached = CheckItemCache(queued.itemIds, true)  -- Trigger cache again
                    if table.getn(stillUncached) > 0 then
                        DebugLog("Retry", queued.retries, "- triggering cache for", table.getn(stillUncached), "items")
                    end
                end
            end
        end
    end
end)
