-- WoW Translate: UTF-8 text helpers
-- Pure Lua 5.1 (no bit library needed). Invalid UTF-8 never errors: a bad
-- byte is treated as a single one-byte character.

local _, WT = ...
local T = {}
WT.Text = T

local byte, sub, char, gsub, find, lower = string.byte, string.sub, string.char, string.gsub, string.find, string.lower
local floor = math.floor

-- Decode one code point at byte index i. Returns codepoint, index after it.
local function decode(s, i)
    local c = byte(s, i)
    if not c then return nil, i end
    if c < 0x80 then return c, i + 1 end
    local n, cp
    if c >= 0xF0 and c < 0xF8 then n, cp = 3, c - 0xF0
    elseif c >= 0xE0 then n, cp = 2, c - 0xE0
    elseif c >= 0xC0 then n, cp = 1, c - 0xC0
    else return c, i + 1 end           -- stray continuation byte
    for k = 1, n do
        local cc = byte(s, i + k)
        if not cc or cc < 0x80 or cc > 0xBF then return c, i + 1 end
        cp = cp * 64 + (cc - 0x80)
    end
    return cp, i + n + 1
end
T.decode = decode

-- Encode a code point to UTF-8.
local function encode(cp)
    if cp < 0x80 then return char(cp) end
    if cp < 0x800 then
        return char(0xC0 + floor(cp / 64), 0x80 + cp % 64)
    end
    if cp < 0x10000 then
        return char(0xE0 + floor(cp / 4096), 0x80 + floor(cp / 64) % 64, 0x80 + cp % 64)
    end
    return char(0xF0 + floor(cp / 262144), 0x80 + floor(cp / 4096) % 64, 0x80 + floor(cp / 64) % 64, 0x80 + cp % 64)
end
T.encode = encode

-- Number of characters (code points).
function T.len(s)
    local n, i, L = 0, 1, #s
    while i <= L do
        local _
        _, i = decode(s, i)
        n = n + 1
    end
    return n
end

-- ---------------------------------------------------------------------------
-- Script classification
-- ---------------------------------------------------------------------------
local function script(cp)
    if cp < 0x80 then
        if (cp >= 65 and cp <= 90) or (cp >= 97 and cp <= 122) then return "latin" end
        if cp >= 48 and cp <= 57 then return "digit" end
        if cp == 32 or cp == 9 or cp == 10 or cp == 13 then return "space" end
        return "punct"
    end
    if cp >= 0xC0 and cp <= 0x24F and cp ~= 0xD7 and cp ~= 0xF7 then return "latin" end
    if cp >= 0x400 and cp <= 0x4FF then return "cyrillic" end
    if (cp >= 0x4E00 and cp <= 0x9FFF) or (cp >= 0x3400 and cp <= 0x4DBF) or (cp >= 0xF900 and cp <= 0xFAFF) then return "han" end
    if (cp >= 0x3040 and cp <= 0x30FF) or (cp >= 0x31F0 and cp <= 0x31FF) or (cp >= 0xFF66 and cp <= 0xFF9F) then return "kana" end
    if (cp >= 0xAC00 and cp <= 0xD7AF) or (cp >= 0x1100 and cp <= 0x11FF) or (cp >= 0x3130 and cp <= 0x318F) then return "hangul" end
    if cp == 0x3000 or cp == 0xA0 then return "space" end
    if (cp >= 0x3000 and cp <= 0x303F) or (cp >= 0xFF00 and cp <= 0xFF65) or (cp >= 0x2000 and cp <= 0x206F) or cp < 0xC0 then return "punct" end
    return "other"
end
T.script = script

-- Count letters per script. Returns table {latin=n, cyrillic=n, ...}.
function T.scriptCounts(s)
    local counts = {}
    local i, L = 1, #s
    while i <= L do
        local cp
        cp, i = decode(s, i)
        local sc = script(cp)
        counts[sc] = (counts[sc] or 0) + 1
    end
    return counts
end

-- ---------------------------------------------------------------------------
-- Case folding
-- ---------------------------------------------------------------------------
-- Fallback lowercase map for the scripts our dictionaries use (Latin-1,
-- Latin Extended-A pairs, Cyrillic). Used when C_Intl.FoldCase is missing
-- (e.g. in the offline test harness).
local LOWER = {}
for cp = 0xC0, 0xDE do
    if cp ~= 0xD7 then LOWER[encode(cp)] = encode(cp + 32) end
end
for cp = 0x100, 0x17E, 2 do                 -- Ā..ž even/odd pairs (good enough)
    LOWER[encode(cp)] = encode(cp + 1)
end
for cp = 0x410, 0x42F do LOWER[encode(cp)] = encode(cp + 32) end   -- А..Я
for cp = 0x400, 0x40F do LOWER[encode(cp)] = encode(cp + 80) end   -- Ѐ..Џ (Ё)

local foldCase = C_Intl and C_Intl.FoldCase

function T.lower(s)
    if foldCase then
        local ok, r = pcall(foldCase, s)
        if ok and type(r) == "string" then return r end
    end
    s = lower(s)
    return (gsub(s, "[\195-\197\208][\128-\191]", LOWER))
end

-- ---------------------------------------------------------------------------
-- Accent folding (matching only; never shown to the player)
-- ---------------------------------------------------------------------------
local FOLD = {}
local function addFold(chars, to)
    for _, c in ipairs(chars) do FOLD[c] = to end
end
addFold({ "à", "á", "â", "ã", "ä", "å", "ā", "ă", "ą" }, "a")
addFold({ "ç", "ć", "č" }, "c")
addFold({ "è", "é", "ê", "ë", "ē", "ę", "ě" }, "e")
addFold({ "ì", "í", "î", "ï", "ī" }, "i")
addFold({ "ò", "ó", "ô", "õ", "ö", "ø", "ō", "ő" }, "o")
addFold({ "ù", "ú", "û", "ü", "ū", "ů", "ű" }, "u")
addFold({ "ý", "ÿ" }, "y")
addFold({ "ß" }, "ss")
addFold({ "æ" }, "ae")
addFold({ "œ" }, "oe")
addFold({ "ё" }, "е")                       -- Russian ё reads as е in chat

function T.foldAccents(s)
    return (gsub(s, "[\195-\197\209][\128-\191]", FOLD))
end

-- ---------------------------------------------------------------------------
-- Width / punctuation normalization for CJK text
-- ---------------------------------------------------------------------------
local CJK_PUNCT = {
    ["\227\128\130"] = ".",  -- 。
    ["\227\128\129"] = ",",  -- 、
    ["\227\128\128"] = " ",  -- ideographic space
    ["\227\128\140"] = "\"", ["\227\128\141"] = "\"",   -- 「 」
    ["\227\128\142"] = "\"", ["\227\128\143"] = "\"",   -- 『 』
    ["\227\128\144"] = "[",  ["\227\128\145"] = "]",    -- 【 】
    ["\226\128\156"] = "\"", ["\226\128\157"] = "\"",   -- “ ”
    ["\226\128\152"] = "'",  ["\226\128\153"] = "'",    -- ‘ ’
    ["\226\128\166"] = "...",                           -- …
    ["\239\189\158"] = "~",                             -- ～
}

-- Fullwidth ASCII (U+FF01..U+FF5E) -> ASCII, plus CJK punctuation.
function T.halfwidth(s)
    s = gsub(s, "\239([\188\189])([\128-\191])", function(b2, b3)
        local cp = 0xF000 + (byte(b2) - 0x80) * 64 + (byte(b3) - 0x80)
        if cp >= 0xFF01 and cp <= 0xFF5E then return char(cp - 0xFEE0) end
        return nil
    end)
    return (gsub(s, "[\226\227\239][\128-\191][\128-\191]", CJK_PUNCT))
end

local ACCENT_FOLD_LANGS = { en = true, de = true, fr = true, es = true, pt = true, ru = true }
T.ACCENT_FOLD_LANGS = ACCENT_FOLD_LANGS

-- The key used for dictionary lookups.
function T.normalize(lang, s)
    s = T.halfwidth(s)
    s = T.lower(s)
    if ACCENT_FOLD_LANGS[lang] then s = T.foldAccents(s) end
    s = gsub(s, "\226\128\153", "'")         -- ’ -> '
    s = gsub(s, "%s+", " ")
    s = gsub(s, "^ ", "")
    s = gsub(s, " $", "")
    return s
end

function T.trim(s)
    return (gsub(gsub(s, "^%s+", ""), "%s+$", ""))
end

-- Truncate to at most maxBytes without cutting a UTF-8 character in half.
function T.truncate(s, maxBytes)
    if #s <= maxBytes then return s end
    local cut = maxBytes
    while cut > 0 do
        local b = byte(s, cut + 1)
        if not b or b < 0x80 or b >= 0xC0 then break end
        cut = cut - 1
    end
    return sub(s, 1, cut)
end

-- True if s contains any byte >= 0x80 (i.e. not plain ASCII)
function T.hasNonAscii(s)
    return find(s, "[\128-\255]") ~= nil
end
