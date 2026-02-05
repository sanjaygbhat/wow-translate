-- WoWTranslate_API.lua
-- DLL communication via UnitXP interface
-- Handles async translation requests and polling

WoWTranslate_API = {}

-- Internal state
local pendingRequests = {}
local dllAvailable = false
local requestCounter = 0
local pollFrame = nil

-- Constants
local POLL_INTERVAL = 0.1  -- Poll every 100ms
local REQUEST_TIMEOUT = 30 -- Timeout requests after 30 seconds

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
-- API KEY MANAGEMENT
-- ============================================================================

-- Set the Google API key in the DLL
function WoWTranslate_API.SetKey(apiKey)
    if not dllAvailable then
        return false, "DLL not available"
    end

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

    -- Send request to DLL
    local success, err = pcall(function()
        UnitXP("WoWTranslate", "translate_async", requestId, text)
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
        -- Parse result: "requestId|translation|error"
        local parts = { strsplit("|", result) }
        local requestId = parts[1]
        local translation = parts[2]
        local err = parts[3]

        if requestId and pendingRequests[requestId] then
            local req = pendingRequests[requestId]
            pendingRequests[requestId] = nil

            if req.callback then
                if err and err ~= "" then
                    req.callback(nil, err)
                else
                    req.callback(translation, nil)
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
