-- WoWTranslate_API.lua
-- DLL communication via UnitXP interface
-- Handles async translation requests and polling
-- v0.10: Added credit tracking for WoWTranslate API keys

WoWTranslate_API = {}

-- Internal state
local pendingRequests = {}
local dllAvailable = false
local requestCounter = 0
local pollFrame = nil

-- Credit tracking (updated from DLL responses)
local creditsRemaining = -1  -- -1 = unknown
local creditsExhausted = false  -- True when we know credits are zero
local lastError = nil
local lastCreditWarningTime = 0  -- For throttling credit warnings

-- Cache savings tracking (session-based)
local sessionCacheHits = 0
local sessionCacheChars = 0
local COST_PER_CHAR = 0.003  -- $30 per million = 0.003 cents per char

-- Constants
local POLL_INTERVAL = 0.1  -- Poll every 100ms
local REQUEST_TIMEOUT = 30 -- Timeout requests after 30 seconds

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
-- DLL STATUS FUNCTIONS
-- ============================================================================

-- Check if DLL is loaded and responding
function WoWTranslate_API.CheckDLL()
    if UnitXP then
        local success, result = pcall(function()
            return UnitXP("WoWTranslate", "ping")
        end)
        if success and result == "pong" then
            dllAvailable = true
            return true
        end
    end
    dllAvailable = false
    return false
end

-- Get DLL status
function WoWTranslate_API.IsAvailable()
    return dllAvailable
end

-- ============================================================================
-- CREDIT TRACKING (v0.10+)
-- ============================================================================

-- Get remaining credits from last API response
-- Returns: credits (number, -1 if unknown), formatted string
function WoWTranslate_API.GetCredits()
    return creditsRemaining
end

-- Get credits as formatted string (e.g., "$4.95" or "Unknown")
function WoWTranslate_API.GetCreditsFormatted()
    if creditsRemaining < 0 then
        return "Unknown"
    end
    -- Convert cents to dollars
    local dollars = creditsRemaining / 100
    return string.format("$%.2f", dollars)
end

-- Get last error message
function WoWTranslate_API.GetLastError()
    return lastError
end

-- Check if credits are low (less than $1.00 = 100 cents)
function WoWTranslate_API.IsCreditsLow()
    return creditsRemaining >= 0 and creditsRemaining < 100
end

-- Check if credits are completely exhausted (translation should be skipped)
function WoWTranslate_API.IsCreditsExhausted()
    return creditsExhausted
end

-- Show credit exhausted warning (throttled to once per 60 seconds)
-- Returns true if warning was shown, false if throttled
function WoWTranslate_API.ShowCreditWarningIfNeeded()
    local now = GetTime()
    if now - lastCreditWarningTime >= 60 then
        lastCreditWarningTime = now
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WoWTranslate] Out of credits! Translation disabled. Contact the addon author to add more credits.|r")
        end
        return true
    end
    return false
end

-- Reset credit exhausted state (called when key changes or credits added)
function WoWTranslate_API.ResetCreditState()
    creditsExhausted = false
    creditsRemaining = -1
    lastError = nil
end

-- Track a cache hit (called when translation comes from local cache)
function WoWTranslate_API.TrackCacheHit(charCount)
    sessionCacheHits = sessionCacheHits + 1
    sessionCacheChars = sessionCacheChars + (charCount or 0)
end

-- Get cache savings for this session
function WoWTranslate_API.GetCacheSavings()
    local savingsCents = sessionCacheChars * COST_PER_CHAR
    return sessionCacheHits, sessionCacheChars, savingsCents
end

-- Get cache savings as formatted string
function WoWTranslate_API.GetCacheSavingsFormatted()
    local hits, chars, cents = WoWTranslate_API.GetCacheSavings()
    if hits == 0 then
        return "No cache hits yet"
    end
    local dollars = cents / 100
    return string.format("%d hits, %d chars, $%.2f saved", hits, chars, dollars)
end

-- ============================================================================
-- API KEY MANAGEMENT
-- ============================================================================

-- Set the WoWTranslate API key in the DLL
function WoWTranslate_API.SetKey(apiKey)
    if not dllAvailable then
        return false, "DLL not available"
    end

    -- Reset credit state when key changes
    creditsRemaining = -1
    creditsExhausted = false
    lastError = nil
    lastCreditWarningTime = 0

    local success, result = pcall(function()
        return UnitXP("WoWTranslate", "setkey", apiKey)
    end)

    if success then
        -- DLL returns "ok" on success or "error|message" on failure
        if result == "ok" then
            return true
        elseif result and string.find(result, "error|") then
            local errorMsg = string.sub(result, 7) -- Remove "error|" prefix
            return false, errorMsg
        else
            return true -- Assume success if no error prefix
        end
    else
        return false, result
    end
end

-- ============================================================================
-- TRANSLATION FUNCTIONS
-- ============================================================================

-- Request an async translation
-- callback(translation, error) will be called when complete
function WoWTranslate_API.Translate(text, callback)
    if not dllAvailable then
        if callback then
            callback(nil, "DLL not available")
        end
        return false
    end

    if not text or text == "" then
        if callback then
            callback(nil, "Empty text")
        end
        return false
    end

    -- Generate unique request ID
    requestCounter = requestCounter + 1
    local requestId = tostring(requestCounter)

    -- Store pending request
    pendingRequests[requestId] = {
        callback = callback,
        text = text,
        timestamp = GetTime()
    }

    -- Send request to DLL with configurable language direction
    local fromLang = WoWTranslateDB and WoWTranslateDB.incomingFromLang or "zh"
    local toLang = WoWTranslateDB and WoWTranslateDB.incomingToLang or "en"
    local success, err = pcall(function()
        UnitXP("WoWTranslate", "translate_async", requestId, text, fromLang, toLang)
    end)

    if not success then
        pendingRequests[requestId] = nil
        if callback then
            callback(nil, "DLL call failed: " .. tostring(err))
        end
        return false
    end

    return true, requestId
end

-- ============================================================================
-- POLLING SYSTEM
-- ============================================================================

-- Poll DLL for completed translations
local function PollTranslations()
    if not dllAvailable then return end

    local success, result = pcall(function()
        return UnitXP("WoWTranslate", "poll")
    end)

    if success and result and result ~= "" then
        -- Parse result format from proxy-enabled DLL:
        -- Success: "requestId|translation|credits|"
        -- Error: "requestId||error_message|credits"
        -- Where credits is optional (may be empty)

        local firstPipe = string.find(result, "|", 1, true)
        if firstPipe then
            local requestId = string.sub(result, 1, firstPipe - 1)
            local remainder = string.sub(result, firstPipe + 1)

            -- Find all pipes in remainder
            local pipes = {}
            local searchPos = 1
            while true do
                local pos = string.find(remainder, "|", searchPos, true)
                if pos then
                    table.insert(pipes, pos)
                    searchPos = pos + 1
                else
                    break
                end
            end

            local translation, err, credits

            if table.getn(pipes) >= 2 then
                -- Format: translation|error|credits
                translation = string.sub(remainder, 1, pipes[1] - 1)
                err = string.sub(remainder, pipes[1] + 1, pipes[2] - 1)
                local creditsStr = string.sub(remainder, pipes[2] + 1)
                credits = tonumber(creditsStr)
            elseif table.getn(pipes) == 1 then
                -- Old format: translation|error
                translation = string.sub(remainder, 1, pipes[1] - 1)
                err = string.sub(remainder, pipes[1] + 1)
            else
                translation = remainder
                err = ""
            end

            -- Update credits if we got a value
            if credits and credits >= 0 then
                creditsRemaining = credits
                creditsExhausted = (credits == 0)
            end

            if requestId and pendingRequests[requestId] then
                local req = pendingRequests[requestId]
                pendingRequests[requestId] = nil

                if req.callback then
                    if err and err ~= "" then
                        -- Store error for UI
                        lastError = err

                        -- Check for credit exhaustion
                        if string.find(err, "INSUFFICIENT_CREDITS") or string.find(err, "Insufficient credits") then
                            creditsExhausted = true
                            creditsRemaining = 0
                        end

                        req.callback(nil, err)
                    else
                        lastError = nil
                        req.callback(translation, nil)
                    end
                end
            end
        end
    end

    -- Cleanup timed-out requests
    local now = GetTime()
    for id, req in pairs(pendingRequests) do
        if now - req.timestamp > REQUEST_TIMEOUT then
            pendingRequests[id] = nil
            if req.callback then
                req.callback(nil, "Request timed out")
            end
        end
    end
end

-- Start the polling frame
function WoWTranslate_API.StartPolling()
    if pollFrame then return end

    pollFrame = CreateFrame("Frame")
    local elapsed = 0

    pollFrame:SetScript("OnUpdate", function()
        elapsed = elapsed + arg1
        if elapsed >= POLL_INTERVAL then
            elapsed = 0
            PollTranslations()
        end
    end)
end

-- Stop the polling frame
function WoWTranslate_API.StopPolling()
    if pollFrame then
        pollFrame:SetScript("OnUpdate", nil)
        pollFrame = nil
    end
end

-- ============================================================================
-- OUTGOING TRANSLATION (English -> Chinese)
-- ============================================================================

-- Request an async outgoing translation (en -> zh)
-- callback(translation, error) will be called when complete
function WoWTranslate_API.TranslateOutgoing(text, callback)
    if not dllAvailable then
        if callback then
            callback(nil, "DLL not available")
        end
        return false
    end

    if not text or text == "" then
        if callback then
            callback(nil, "Empty text")
        end
        return false
    end

    -- Generate unique request ID with "out_" prefix to distinguish from incoming
    requestCounter = requestCounter + 1
    local requestId = "out_" .. tostring(requestCounter)

    -- Store pending request
    pendingRequests[requestId] = {
        callback = callback,
        text = text,
        timestamp = GetTime()
    }

    -- Send request to DLL with configurable language direction
    local fromLang = WoWTranslateDB and WoWTranslateDB.outgoingFromLang or "en"
    local toLang = WoWTranslateDB and WoWTranslateDB.outgoingToLang or "zh"
    local success, err = pcall(function()
        UnitXP("WoWTranslate", "translate_async", requestId, text, fromLang, toLang)
    end)

    if not success then
        pendingRequests[requestId] = nil
        if callback then
            callback(nil, "DLL call failed: " .. tostring(err))
        end
        return false
    end

    return true, requestId
end

-- ============================================================================
-- DEBUG FUNCTIONS
-- ============================================================================

-- Get pending request count
function WoWTranslate_API.GetPendingCount()
    local count = 0
    for _ in pairs(pendingRequests) do
        count = count + 1
    end
    return count
end

-- Get all pending request info (for debugging)
function WoWTranslate_API.GetPendingRequests()
    local info = {}
    local now = GetTime()
    for id, req in pairs(pendingRequests) do
        table.insert(info, {
            id = id,
            text = req.text,
            age = now - req.timestamp
        })
    end
    return info
end

