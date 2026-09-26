-- WoWTranslate_API.lua
-- DLL communication via UnitXP interface
-- Handles provider configuration, async translation requests, and polling.
-- v2.0: Direct Google/OpenAI/custom provider support.

WoWTranslate_API = {}

-- Internal state
local pendingRequests = {}
local dllAvailable = false
local requestCounter = 0
local pollFrame = nil
local activePendingCount = 0
local lastError = nil

-- Session cache hit tracking for diagnostics only
local sessionCacheHits = 0
local sessionCacheChars = 0

-- Constants
local POLL_INTERVAL = 0.1
local REQUEST_TIMEOUT = 30

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

local function trim(text)
    if not text then return "" end
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

-- Minimal JSON string/value reader for the fixed DLL response shapes.
local function JsonUnescape(value)
    if not value then return "" end

    local result = ""
    local i = 1
    while i <= string.len(value) do
        local ch = string.sub(value, i, i)
        if ch == "\\" and i < string.len(value) then
            local nextCh = string.sub(value, i + 1, i + 1)
            if nextCh == "\"" then result = result .. "\""
            elseif nextCh == "\\" then result = result .. "\\"
            elseif nextCh == "/" then result = result .. "/"
            elseif nextCh == "n" then result = result .. "\n"
            elseif nextCh == "r" then result = result .. "\r"
            elseif nextCh == "t" then result = result .. "\t"
            elseif nextCh == "b" then result = result .. "\b"
            elseif nextCh == "f" then result = result .. "\f"
            elseif nextCh == "u" and i + 5 <= string.len(value) then
                -- DLL emits UTF-8 directly for normal text; keep uncommon escapes readable.
                result = result .. "?"
                i = i + 4
            else
                result = result .. nextCh
            end
            i = i + 2
        else
            result = result .. ch
            i = i + 1
        end
    end

    return result
end

local function JsonGetRaw(jsonText, key)
    if not jsonText or not key then return nil end

    local search = "\"" .. key .. "\""
    local keyStart, keyEnd = string.find(jsonText, search, 1, true)
    if not keyStart then return nil end

    local colon = string.find(jsonText, ":", keyEnd + 1, true)
    if not colon then return nil end

    local start = colon + 1
    while start <= string.len(jsonText) do
        local ch = string.sub(jsonText, start, start)
        if ch ~= " " and ch ~= "\t" and ch ~= "\n" and ch ~= "\r" then
            break
        end
        start = start + 1
    end

    if string.sub(jsonText, start, start) == "\"" then
        local pos = start + 1
        while pos <= string.len(jsonText) do
            local ch = string.sub(jsonText, pos, pos)
            if ch == "\\" then
                pos = pos + 2
            elseif ch == "\"" then
                return string.sub(jsonText, start + 1, pos - 1), true
            else
                pos = pos + 1
            end
        end
        return nil
    end

    local finish = start
    while finish <= string.len(jsonText) do
        local ch = string.sub(jsonText, finish, finish)
        if ch == "," or ch == "}" then
            break
        end
        finish = finish + 1
    end

    return trim(string.sub(jsonText, start, finish - 1)), false
end

local function JsonGetString(jsonText, key)
    local raw, quoted = JsonGetRaw(jsonText, key)
    if raw == nil then return nil end
    if quoted then
        return JsonUnescape(raw)
    end
    if raw == "null" then return nil end
    return raw
end

local function JsonGetBool(jsonText, key)
    local raw = JsonGetRaw(jsonText, key)
    return raw == "true"
end

local function JsonGetNumber(jsonText, key)
    local raw = JsonGetRaw(jsonText, key)
    if raw then return tonumber(raw) end
    return nil
end

local function ParseBridgeResult(result)
    if result == "ok" then
        return true, nil
    end
    if result and string.find(result, "error|", 1, true) == 1 then
        return false, string.sub(result, 7)
    end
    return true, nil
end

-- ============================================================================
-- DLL STATUS FUNCTIONS
-- ============================================================================
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

function WoWTranslate_API.IsAvailable()
    return dllAvailable
end

function WoWTranslate_API.GetLastError()
    if dllAvailable and UnitXP then
        local success, result = pcall(function()
            return UnitXP("WoWTranslate", "last_error")
        end)
        if success and result and result ~= "" then
            lastError = result
        end
    end
    return lastError
end

function WoWTranslate_API.GetProviderStatus()
    local status = {
        provider = WoWTranslateDB and WoWTranslateDB.provider or "google",
        configured = false,
        ready = false,
        endpoint = "",
        lastHttpStatus = 0,
    }

    if not dllAvailable or not UnitXP then
        return status
    end

    local success, result = pcall(function()
        return UnitXP("WoWTranslate", "provider_status")
    end)

    if success and result and result ~= "" then
        status.provider = JsonGetString(result, "provider") or status.provider
        status.configured = JsonGetBool(result, "configured")
        status.ready = JsonGetBool(result, "ready")
        status.endpoint = JsonGetString(result, "endpoint") or ""
        status.lastHttpStatus = JsonGetNumber(result, "lastHttpStatus") or 0
    end

    return status
end

-- ============================================================================
-- PROVIDER CONFIGURATION
-- ============================================================================
function WoWTranslate_API.ConfigureGoogle(apiKey)
    if not dllAvailable then
        return false, "DLL not available"
    end

    local success, result = pcall(function()
        return UnitXP("WoWTranslate", "configure_google", apiKey or "")
    end)

    if not success then
        lastError = tostring(result)
        return false, lastError
    end

    local ok, err = ParseBridgeResult(result)
    lastError = err
    return ok, err
end

function WoWTranslate_API.ConfigureGoogleFree()
    if not dllAvailable then
        return false, "DLL not available"
    end

    local success, result = pcall(function()
        return UnitXP("WoWTranslate", "configure_google_free")
    end)

    if not success then
        lastError = tostring(result)
        return false, lastError
    end

    local ok, err = ParseBridgeResult(result)
    lastError = err
    return ok, err
end

function WoWTranslate_API.ConfigureOpenAICompatible(endpoint, apiKey, model, temperature)
    if not dllAvailable then
        return false, "DLL not available"
    end

    local success, result = pcall(function()
        return UnitXP("WoWTranslate", "configure_openai",
            endpoint or "https://api.openai.com/v1/chat/completions",
            apiKey or "",
            model or "gpt-4.1-mini",
            tostring(temperature or 0))
    end)

    if not success then
        lastError = tostring(result)
        return false, lastError
    end

    local ok, err = ParseBridgeResult(result)
    lastError = err
    return ok, err
end

function WoWTranslate_API.ConfigureCustomHttp(endpoint, apiKey, authHeader, authScheme, requestTemplate, responsePath)
    if not dllAvailable then
        return false, "DLL not available"
    end

    local success, result = pcall(function()
        return UnitXP("WoWTranslate", "configure_custom",
            endpoint or "",
            apiKey or "",
            authHeader or "Authorization",
            authScheme or "Bearer",
            requestTemplate or "",
            responsePath or "translation")
    end)

    if not success then
        lastError = tostring(result)
        return false, lastError
    end

    local ok, err = ParseBridgeResult(result)
    lastError = err
    return ok, err
end

function WoWTranslate_API.HasSavedProviderConfig(provider)
    provider = provider or (WoWTranslateDB and WoWTranslateDB.provider) or "google"
    if not WoWTranslateDB then return false end

    if provider == "google" then
        return WoWTranslateDB.googleApiKey and WoWTranslateDB.googleApiKey ~= ""
    elseif provider == "google_free" then
        return true -- no configuration needed
    elseif provider == "openai" then
        return WoWTranslateDB.openaiApiKey and WoWTranslateDB.openaiApiKey ~= ""
    elseif provider == "custom" then
        return WoWTranslateDB.customEndpoint and WoWTranslateDB.customEndpoint ~= ""
    end

    return false
end

function WoWTranslate_API.ConfigureFromSaved(force)
    if not dllAvailable then
        return false, "DLL not available"
    end
    if not WoWTranslateDB then
        return false, "settings not loaded"
    end

    local provider = WoWTranslateDB.provider or "google"

    if not force and not WoWTranslate_API.HasSavedProviderConfig(provider) then
        return true, nil
    end

    if provider == "google" then
        return WoWTranslate_API.ConfigureGoogle(WoWTranslateDB.googleApiKey or "")
    elseif provider == "google_free" then
        return WoWTranslate_API.ConfigureGoogleFree()
    elseif provider == "openai" then
        return WoWTranslate_API.ConfigureOpenAICompatible(
            WoWTranslateDB.openaiEndpoint or "https://api.openai.com/v1/chat/completions",
            WoWTranslateDB.openaiApiKey or "",
            WoWTranslateDB.openaiModel or "gpt-4.1-mini",
            0)
    elseif provider == "custom" then
        return WoWTranslate_API.ConfigureCustomHttp(
            WoWTranslateDB.customEndpoint or "",
            WoWTranslateDB.customApiKey or "",
            WoWTranslateDB.customAuthHeader or "Authorization",
            WoWTranslateDB.customAuthScheme or "Bearer",
            WoWTranslateDB.customRequestTemplate or "",
            WoWTranslateDB.customResponsePath or "translation")
    end

    return false, "unknown provider: " .. tostring(provider)
end

-- ============================================================================
-- CACHE DIAGNOSTICS
-- ============================================================================
function WoWTranslate_API.TrackCacheHit(charCount)
    sessionCacheHits = sessionCacheHits + 1
    sessionCacheChars = sessionCacheChars + (charCount or 0)
end

function WoWTranslate_API.GetSessionCacheStats()
    return sessionCacheHits, sessionCacheChars
end

function WoWTranslate_API.GetSessionCacheStatsFormatted()
    if sessionCacheHits == 0 then
        return "No session cache hits"
    end
    return tostring(sessionCacheHits) .. " hits, " .. tostring(sessionCacheChars) .. " chars"
end

-- ============================================================================
-- DEMAND-BASED POLLING HELPERS
-- ============================================================================
local function OnRequestQueued()
    activePendingCount = activePendingCount + 1
    if not pollFrame then
        WoWTranslate_API.StartPolling()
    end
end

local function OnRequestCompleted()
    activePendingCount = activePendingCount - 1
    if activePendingCount <= 0 then
        activePendingCount = 0
        WoWTranslate_API.StopPolling()
    end
end

-- ============================================================================
-- TRANSLATION FUNCTIONS
-- ============================================================================
function WoWTranslate_API.Translate(text, callback)
    if not dllAvailable then
        if callback then callback(nil, "DLL not available") end
        return false
    end

    if not text or text == "" then
        if callback then callback(nil, "Empty text") end
        return false
    end

    requestCounter = requestCounter + 1
    local requestId = tostring(requestCounter)

    pendingRequests[requestId] = {
        callback = callback,
        text = text,
        timestamp = GetTime()
    }

    local fromLang = WoWTranslateDB and WoWTranslateDB.incomingFromLang or "zh"
    local toLang = WoWTranslateDB and WoWTranslateDB.incomingToLang or "en"
    local success, result = pcall(function()
        return UnitXP("WoWTranslate", "translate_async", requestId, text, fromLang, toLang)
    end)

    if not success then
        pendingRequests[requestId] = nil
        if callback then callback(nil, "DLL call failed: " .. tostring(result)) end
        return false
    end

    local ok, err = ParseBridgeResult(result)
    if not ok then
        pendingRequests[requestId] = nil
        lastError = err
        if callback then callback(nil, err) end
        return false
    end

    OnRequestQueued()
    return true, requestId
end

-- ============================================================================
-- POLLING SYSTEM
-- ============================================================================
local function PollTranslations()
    if not dllAvailable then return end

    local success, result = pcall(function()
        return UnitXP("WoWTranslate", "poll")
    end)

    if success and result and result ~= "" then
        local requestId = JsonGetString(result, "id")
        local translation = JsonGetString(result, "translation") or ""
        local err = JsonGetString(result, "error") or ""

        if requestId and pendingRequests[requestId] then
            local req = pendingRequests[requestId]
            pendingRequests[requestId] = nil
            OnRequestCompleted()

            if req.callback then
                if err ~= "" then
                    lastError = err
                    req.callback(nil, err)
                else
                    lastError = nil
                    req.callback(translation, nil)
                end
            end
        end
    end

    local now = GetTime()
    for id, req in pairs(pendingRequests) do
        if now - req.timestamp > REQUEST_TIMEOUT then
            pendingRequests[id] = nil
            OnRequestCompleted()
            lastError = "Request timed out"
            if req.callback then
                req.callback(nil, "Request timed out")
            end
        end
    end
end

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

function WoWTranslate_API.StopPolling()
    if pollFrame then
        pollFrame:SetScript("OnUpdate", nil)
        pollFrame = nil
    end
end

-- ============================================================================
-- OUTGOING TRANSLATION
-- ============================================================================
function WoWTranslate_API.TranslateOutgoing(text, callback)
    if not dllAvailable then
        if callback then callback(nil, "DLL not available") end
        return false
    end

    if not text or text == "" then
        if callback then callback(nil, "Empty text") end
        return false
    end

    requestCounter = requestCounter + 1
    local requestId = "out_" .. tostring(requestCounter)

    pendingRequests[requestId] = {
        callback = callback,
        text = text,
        timestamp = GetTime()
    }

    local fromLang = WoWTranslateDB and WoWTranslateDB.outgoingFromLang or "en"
    local toLang = WoWTranslateDB and WoWTranslateDB.outgoingToLang or "zh"
    local success, result = pcall(function()
        return UnitXP("WoWTranslate", "translate_async", requestId, text, fromLang, toLang)
    end)

    if not success then
        pendingRequests[requestId] = nil
        if callback then callback(nil, "DLL call failed: " .. tostring(result)) end
        return false
    end

    local ok, err = ParseBridgeResult(result)
    if not ok then
        pendingRequests[requestId] = nil
        lastError = err
        if callback then callback(nil, err) end
        return false
    end

    OnRequestQueued()
    return true, requestId
end

-- ============================================================================
-- DEBUG FUNCTIONS
-- ============================================================================
function WoWTranslate_API.GetPendingCount()
    local count = 0
    for _ in pairs(pendingRequests) do
        count = count + 1
    end
    return count
end

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
