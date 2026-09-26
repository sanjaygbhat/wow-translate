-- WoW Translate: Quick (offline) translation engine
--
-- Phrase-by-phrase dictionary translation. It gives the gist of a message,
-- not a polished sentence. English is the pivot: Russian -> German goes
-- Russian -> English -> German.
--
-- Input is always plain text: hyperlinks and escape codes are cut out by
-- Engine/Links.lua before a segment reaches this file.

local _, WT = ...
local T = WT.Text

local sub, lower, upper, gsub, find, match, byte = string.sub, string.lower, string.upper, string.gsub, string.find, string.match, string.byte
local concat = table.concat

local decode, script = T.decode, T.script

-- ---------------------------------------------------------------------------
-- Tokenizing
-- ---------------------------------------------------------------------------
local WORD_SCRIPTS = { latin = true, cyrillic = true, hangul = true, han = true, kana = true, digit = true, other = true }

-- Split into characters with their script. Returns array of {s=char, sc=script}.
local function chars(text)
    local out, i, L = {}, 1, #text
    while i <= L do
        local cp, j = decode(text, i)
        out[#out + 1] = { s = sub(text, i, j - 1), sc = script(cp) }
        i = j
    end
    return out
end

-- Words and the gaps between them. gaps[k] is the text before words[k];
-- gaps[#words+1] is the trailing text.
local function splitWords(text)
    local cs = chars(text)
    local words, gaps = {}, {}
    local buf, gap = {}, {}
    local function flushWord()
        if #buf > 0 then
            gaps[#words + 1] = concat(gap)
            words[#words + 1] = concat(buf)
            buf, gap = {}, {}
        end
    end
    for k = 1, #cs do
        local c = cs[k]
        local isWord = WORD_SCRIPTS[c.sc] or c.s == "'" or c.s == "-" or c.s == "_" or c.s == "+"
        if isWord then
            buf[#buf + 1] = c.s
        else
            flushWord()
            gap[#gap + 1] = c.s
        end
    end
    flushWord()
    gaps[#words + 1] = concat(gap)
    return words, gaps
end

local FR_ELISION = { "jusqu'", "lorsqu'", "puisqu'", "qu'", "l'", "d'", "j'", "c'", "n'", "m'", "t'", "s'" }

-- ---------------------------------------------------------------------------
-- Output assembly
-- ---------------------------------------------------------------------------
local NO_SPACE_BEFORE = { [","] = true, ["."] = true, ["!"] = true, ["?"] = true, [":"] = true, [";"] = true,
    [")"] = true, ["]"] = true, ["%"] = true, ["..."] = true, ["~"] = true }

-- tokens: array of {k="w"|"p", s=string}
local function assemble(tokens, joinNoSpace)
    local out, prev = {}, nil
    for i = 1, #tokens do
        local tk = tokens[i]
        local s = tk.s
        if s ~= "" then
            if tk.k == "p" then
                -- punctuation: keep it tight against the previous word
                if s == " " then
                    if prev and prev.s ~= " " then out[#out + 1] = " " end
                    tk = { k = "p", s = " " }
                else
                    if out[#out] == " " and NO_SPACE_BEFORE[s] then out[#out] = nil end
                    out[#out + 1] = s
                end
            else
                if prev and prev.k == "w" then
                    if not (joinNoSpace and prev.cjk and tk.cjk) then out[#out + 1] = " " end
                elseif prev and prev.k == "p" and prev.s ~= " " and not joinNoSpace then
                    local last = sub(prev.s, -1)
                    if last ~= "(" and last ~= "[" and last ~= "\"" and last ~= "'" and last ~= "-" and last ~= "/" and last ~= "#" then
                        out[#out + 1] = " "
                    end
                end
                out[#out + 1] = s
            end
            prev = tk
        end
    end
    local r = concat(out)
    r = gsub(r, "([%?!])[%?!]+", "%1")
    -- "need need a healer" -> "need a healer" (two phrases that overlap)
    r = gsub(r, "%f[%w](%a+) %1%f[%W]", "%1")
    r = gsub(r, "  +", " ")
    r = gsub(r, "^%s+", "")
    r = gsub(r, "%s+$", "")
    return r
end

-- Append the separators between two words: a space token for any run of
-- whitespace, and one token per run of punctuation.
local function gapTokens(tokens, g)
    if g == "" then return end
    local pos, L = 1, #g
    while pos <= L do
        local a, b = find(g, "^%s+", pos)
        if a then
            tokens[#tokens + 1] = { k = "p", s = " " }
            pos = b + 1
        else
            a, b = find(g, "^[^%s]+", pos)
            tokens[#tokens + 1] = { k = "p", s = sub(g, a, b) }
            pos = b + 1
        end
    end
end

-- Gamer shorthand looks right in capitals ("lfg" -> "LFG").
local ACRONYMS = {}
for w in string.gmatch("lfg lfm wts wtb wtt dps hps afk brb gg gdkp aoe dot hot xp pvp pve bg mt ot npc ui "
    .. "idk ty np dm mc bwl zg aq ubrs lbrs brd ah gm", "%S+") do
    ACRONYMS[w] = upper(w)
end
ACRONYMS.pvp, ACRONYMS.pve = "PvP", "PvE"

local function isPunctOnly(s)
    return s ~= "" and not find(s, "[%w\128-\255]")
end

local function englishToken(en, known)
    if isPunctOnly(en) then return { k = "p", s = en } end
    return { k = "w", s = en, known = known }
end

-- ---------------------------------------------------------------------------
-- Foreign -> English
-- ---------------------------------------------------------------------------
local function lookupWord(d, lang, key)
    local fwd = d.fwd
    local en = fwd[key]
    if en ~= nil then return en end
    if lang == "ko" then
        local parts = WT.KO_PARTICLES
        for i = 1, #parts do
            local p = parts[i]
            if #key > #p and sub(key, -#p) == p then
                en = fwd[sub(key, 1, #key - #p)]
                if en ~= nil then return en end
            end
        end
        return nil
    end
    local st = WT.Stem(lang, key)
    if st ~= key then
        en = fwd[st]
        if en == nil then en = d.stems[st] end
        if en ~= nil then return en end
    end
    en = d.stems[key]
    return en
end

local function toEnglishSpaced(text, d, lang)
    local rawWords, gaps = splitWords(text)
    -- French elisions: split "l'aggro" into "l'" + "aggro" unless known whole.
    if lang == "fr" then
        local w2, g2 = {}, {}
        for k = 1, #rawWords do
            local w = rawWords[k]
            local key = T.normalize(lang, w)
            local split = false
            if d.fwd[key] == nil then
                for _, e in ipairs(FR_ELISION) do
                    if #key > #e and sub(key, 1, #e) == e then
                        g2[#w2 + 1] = gaps[k]; w2[#w2 + 1] = sub(w, 1, #e)
                        g2[#w2 + 1] = "";      w2[#w2 + 1] = sub(w, #e + 1)
                        split = true
                        break
                    end
                end
            end
            if not split then g2[#w2 + 1] = gaps[k]; w2[#w2 + 1] = w end
        end
        g2[#w2 + 1] = gaps[#rawWords + 1]
        rawWords, gaps = w2, g2
    end

    local keys = {}
    for k = 1, #rawWords do keys[k] = T.normalize(lang, rawWords[k]) end

    local tokens = {}
    local known, total = 0, 0
    local function pushGap(g) gapTokens(tokens, g) end

    local i, n = 1, #rawWords
    while i <= n do
        pushGap(gaps[i])
        local matched = false
        local maxN = d.maxLen
        if maxN > n - i + 1 then maxN = n - i + 1 end
        for len = maxN, 2, -1 do
            local ok = true
            for g = i + 1, i + len - 1 do
                if find(gaps[g], "[^%s]") then ok = false break end
            end
            if ok then
                local key = concat(keys, " ", i, i + len - 1)
                local en = d.fwd[key]
                if en ~= nil then
                    if en ~= "" then tokens[#tokens + 1] = englishToken(en, true) end
                    known, total = known + len, total + len
                    i = i + len
                    matched = true
                    break
                end
            end
        end
        if not matched then
            local key = keys[i]
            local en = lookupWord(d, lang, key)
            if en ~= nil then
                if en ~= "" then tokens[#tokens + 1] = englishToken(en, true) end
                known, total = known + 1, total + 1
            elseif find(key, "^[%d%+%-]+$") then
                tokens[#tokens + 1] = { k = "w", s = rawWords[i] }
            else
                tokens[#tokens + 1] = { k = "w", s = rawWords[i] }
                total = total + 1
            end
            i = i + 1
        end
    end
    pushGap(gaps[n + 1])
    return tokens, known, total
end

local function toEnglishCJK(text, d)
    local cs = chars(text)
    local n = #cs
    local low = {}
    for k = 1, n do
        local s = cs[k].s
        if #s == 1 then low[k] = lower(s)
        elseif cs[k].sc == "latin" then low[k] = T.lower(s)
        else low[k] = s end
    end
    local fwd, maxLen = d.fwd, d.maxLen
    local tokens, unknown = {}, {}
    local known, total = 0, 0

    local function flushUnknown()
        if #unknown > 0 then
            tokens[#tokens + 1] = { k = "w", s = concat(unknown), cjk = true }
            unknown = {}
        end
    end

    local i = 1
    local prefix = {}
    while i <= n do
        local c = cs[i]
        local sc = c.sc
        if sc == "space" then
            flushUnknown()
            tokens[#tokens + 1] = { k = "p", s = " " }
            i = i + 1
        elseif sc == "punct" and c.s ~= "+" then
            flushUnknown()
            tokens[#tokens + 1] = { k = "p", s = c.s }
            i = i + 1
        else
            -- try the longest dictionary entry starting here
            local limit = maxLen
            if limit > n - i + 1 then limit = n - i + 1 end
            local acc = ""
            for L = 1, limit do
                local ch = cs[i + L - 1]
                if ch.sc == "space" then limit = L - 1 break end
                acc = acc .. low[i + L - 1]
                prefix[L] = acc
            end
            local hit, hitLen = nil, 0
            for L = limit, 1, -1 do
                local en = fwd[prefix[L]]
                if en ~= nil then
                    -- an ASCII key must not cut through the middle of a Latin word
                    local nextc = cs[i + L]
                    local lastc = cs[i + L - 1]
                    local cutsWord = nextc and (lastc.sc == "latin" or lastc.sc == "digit")
                        and (nextc.sc == "latin" or nextc.sc == "digit")
                    local prevc = cs[i - 1]
                    local startsMid = prevc and (c.sc == "latin" or c.sc == "digit")
                        and (prevc.sc == "latin" or prevc.sc == "digit")
                    -- number slang ("88" = bye, "666") only when it stands alone,
                    -- never inside a price like "88金" or "88g"
                    if not cutsWord and not startsMid and find(prefix[L], "^%d+$") then
                        local function solid(ch) return ch and WORD_SCRIPTS[ch.sc] end
                        if solid(nextc) or solid(prevc) then cutsWord = true end
                    end
                    if not cutsWord and not startsMid then
                        hit, hitLen = en, L
                        break
                    end
                end
            end
            if hit then
                flushUnknown()
                if hit ~= "" then tokens[#tokens + 1] = englishToken(hit, true) end
                known, total = known + hitLen, total + hitLen
                i = i + hitLen
            elseif sc == "latin" or sc == "digit" or c.s == "+" then
                -- keep Latin words and numbers whole
                flushUnknown()
                local j = i
                while j <= n and (cs[j].sc == "latin" or cs[j].sc == "digit" or cs[j].s == "+" or cs[j].s == "'") do j = j + 1 end
                local w = {}
                for k = i, j - 1 do w[#w + 1] = cs[k].s end
                tokens[#tokens + 1] = { k = "w", s = concat(w) }
                i = j
            else
                unknown[#unknown + 1] = c.s
                total = total + 1
                i = i + 1
            end
        end
    end
    flushUnknown()
    return tokens, known, total
end

local function toEnglish(text, lang)
    local d = WT.GetDictionary(lang)
    if not d then return text, 0 end
    local tokens, known, total
    if d.cjk then
        tokens, known, total = toEnglishCJK(T.halfwidth(text), d)
    else
        tokens, known, total = toEnglishSpaced(T.halfwidth(text), d, lang)
    end
    local out = assemble(tokens, false)
    out = gsub(out, "%f[%a]i%f[%A]", "I")
    out = gsub(out, "%f[%a](%a+)%f[%A]", ACRONYMS)
    return out, (total > 0) and (known / total) or 0
end

-- ---------------------------------------------------------------------------
-- English -> foreign
-- ---------------------------------------------------------------------------
-- Languages without articles: an untranslated "a"/"the" is just noise there.
local NO_ARTICLES = { zh = true, ja = true, ko = true, ru = true }
local EN_ARTICLES = { a = true, an = true, the = true }

local function fromEnglish(text, lang)
    local d = WT.GetDictionary(lang)
    if not d then return text, 0 end
    local rev = d.rev
    local words, gaps = splitWords(text)
    local keys = {}
    for k = 1, #words do keys[k] = WT.NormalizeEnglish(words[k]) end

    local tokens = {}
    local known, total = 0, 0
    local function pushGap(g) gapTokens(tokens, g) end

    local i, n = 1, #words
    while i <= n do
        pushGap(gaps[i])
        local matched = false
        local maxN = d.revMaxWords
        if maxN > n - i + 1 then maxN = n - i + 1 end
        for len = maxN, 1, -1 do
            local ok = true
            for g = i + 1, i + len - 1 do
                if find(gaps[g], "[^%s]") then ok = false break end
            end
            if ok then
                local key = concat(keys, " ", i, i + len - 1)
                local out = rev[key]
                if out == nil and len == 1 then
                    local st = WT.Stem("en", key)
                    if st ~= key then out = rev[st] end
                end
                if out ~= nil then
                    tokens[#tokens + 1] = { k = "w", s = out, cjk = d.cjk and T.hasNonAscii(out) }
                    known, total = known + len, total + len
                    i = i + len
                    matched = true
                    break
                end
            end
        end
        if not matched then
            if not (NO_ARTICLES[lang] and EN_ARTICLES[keys[i]]) then
                tokens[#tokens + 1] = { k = "w", s = words[i] }
                if not find(keys[i], "^[%d%+%-]+$") then total = total + 1 end
            end
            i = i + 1
        end
    end
    pushGap(gaps[n + 1])
    return assemble(tokens, d.cjk), (total > 0) and (known / total) or 0
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------
local cache, cacheSize = {}, 0

-- Translate a plain-text segment. Returns translated text and a 0..1 score
-- saying how much of the source was recognised.
function WT.QuickTranslate(text, from, to)
    if not text or text == "" or from == to then return text, 1 end
    if not from or not to then return text, 0 end
    local ck = from .. ">" .. to .. ":" .. text
    local hit = cache[ck]
    if hit then return hit[1], hit[2] end

    local out, score
    if to == "en" then
        out, score = toEnglish(text, from)
    elseif from == "en" then
        out, score = fromEnglish(text, to)
    else
        local mid
        mid, score = toEnglish(text, from)
        out = fromEnglish(mid, to)
    end
    -- Readability: capitalise the first letter of Latin-script output.
    if to ~= "zh" and to ~= "ja" and to ~= "ko" then
        out = gsub(out, "^(%l)", upper)
    end

    if cacheSize > 1000 then cache, cacheSize = {}, 0 end
    cache[ck] = { out, score }
    cacheSize = cacheSize + 1
    return out, score
end

function WT.ClearTranslationCache()
    cache, cacheSize = {}, 0
end
