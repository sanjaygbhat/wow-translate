-- WoWTranslate_Cache.lua
-- Permanent translation cache using SavedVariables
-- Translations persist across sessions and never expire

-- Initialize cache (will be populated from SavedVariables on load)
WoWTranslateCache = WoWTranslateCache or {}

-- Cache statistics
local cacheHits = 0
local cacheMisses = 0

-- Check if a translation exists in cache
function WoWTranslate_CacheGet(text)
    if WoWTranslateCache[text] then
        cacheHits = cacheHits + 1
        return WoWTranslateCache[text], true
    end
    cacheMisses = cacheMisses + 1
    return nil, false
end

-- Save a translation to cache
function WoWTranslate_CacheSave(text, translation)
    if text and translation and text ~= "" and translation ~= "" then
        WoWTranslateCache[text] = translation
        return true
    end
    return false
end

-- Get cache statistics
function WoWTranslate_CacheStats()
    local count = 0
    for _ in pairs(WoWTranslateCache) do
        count = count + 1
    end
    return {
        entries = count,
        hits = cacheHits,
        misses = cacheMisses,
        hitRate = (cacheHits + cacheMisses > 0) and
                  (cacheHits / (cacheHits + cacheMisses) * 100) or 0
    }
end

-- Clear the cache (use with caution)
function WoWTranslate_CacheClear()
    WoWTranslateCache = {}
    cacheHits = 0
    cacheMisses = 0
end

-- Reset session statistics only
function WoWTranslate_CacheResetStats()
    cacheHits = 0
    cacheMisses = 0
end
