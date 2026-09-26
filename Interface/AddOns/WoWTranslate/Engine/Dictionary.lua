-- WoW Translate: offline dictionaries
--
-- Dictionary files call WT.AddDictionary(lang, { "english|form1|form2", ... }).
-- Nothing is indexed at load time: a language's lookup tables are built the
-- first time a message in that language is seen, and the raw lines are then
-- released. Players who never meet a language never pay for it.

local _, WT = ...
local T = WT.Text

local find, sub, gsub, gmatch = string.find, string.sub, string.gsub, string.gmatch

local raw = {}
local built = {}

function WT.AddDictionary(lang, lines)
    raw[lang] = raw[lang] or {}
    table.insert(raw[lang], lines)
end

function WT.HasDictionary(lang)
    return raw[lang] ~= nil or built[lang] ~= nil
end

-- Languages written without spaces: matched by longest character run.
local CJK = { zh = true, ja = true }
WT.CJK_LANGS = CJK

-- ---------------------------------------------------------------------------
-- Light stemming: strip one inflection ending so "танку" finds "танк" and
-- "heilern" finds "heiler". Only used when the exact word is unknown.
-- ---------------------------------------------------------------------------
local SUFFIXES = {
    ru = { "ами", "ями", "ого", "его", "ому", "ему", "ыми", "ими", "ах", "ях", "ов", "ев", "ей", "ой",
           "ый", "ий", "ая", "яя", "ое", "ее", "ую", "юю", "ом", "ем", "ам", "ям", "ы", "и", "а", "я",
           "о", "е", "у", "ю", "ь" },
    de = { "ern", "en", "er", "es", "em", "e", "n", "s" },
    fr = { "ent", "ez", "ons", "es", "s", "x", "e" },
    es = { "iendo", "ando", "os", "as", "es", "ar", "er", "ir", "s" },
    pt = { "endo", "ando", "ou", "os", "as", "es", "ar", "er", "ir", "s" },
    en = { "ing", "ies", "es", "ed", "s" },
}
for _, list in pairs(SUFFIXES) do
    table.sort(list, function(a, b) return #a > #b end)
end

local function stem(lang, word)
    local list = SUFFIXES[lang]
    if not list then return word end
    local wlen = T.len(word)
    for i = 1, #list do
        local suf = list[i]
        if #word > #suf and sub(word, -#suf) == suf and (wlen - T.len(suf)) >= 3 then
            return sub(word, 1, #word - #suf)
        end
    end
    return word
end
WT.Stem = stem

-- Korean: particles attached to the end of a word.
local KO_PARTICLES = { "에서", "에게", "한테", "으로", "까지", "부터", "이랑", "처럼", "은", "는", "이", "가",
    "을", "를", "에", "로", "와", "과", "도", "만", "의", "요", "랑" }
table.sort(KO_PARTICLES, function(a, b) return #a > #b end)
WT.KO_PARTICLES = KO_PARTICLES

local function wordCount(s)
    local n = 1
    for _ in gmatch(s, " ") do n = n + 1 end
    return n
end

local function normalizeEnglish(s)
    s = T.normalize("en", s)
    s = gsub(s, "[%?!%.]+$", "")
    return s
end
WT.NormalizeEnglish = normalizeEnglish

local function build(lang)
    local chunks = raw[lang]
    if not chunks then return nil end
    local d = {
        lang = lang, cjk = CJK[lang] or false,
        fwd = {}, stems = {}, rev = {},
        maxLen = 1, revMaxWords = 1, count = 0,
    }
    for c = 1, #chunks do
        local lines = chunks[c]
        for n = 1, #lines do
            local line = lines[n]
            -- split on "|" keeping empty fields
            local fields, pos = {}, 1
            while true do
                local bar = find(line, "|", pos, true)
                if not bar then fields[#fields + 1] = sub(line, pos) break end
                fields[#fields + 1] = sub(line, pos, bar - 1)
                pos = bar + 1
            end
            local en = T.trim(fields[1] or "")
            for i = 2, #fields do
                local form = fields[i]
                if form and form ~= "" then
                    local key = T.normalize(lang, form)
                    if key ~= "" and d.fwd[key] == nil then
                        d.fwd[key] = en
                        d.count = d.count + 1
                        local size = d.cjk and T.len(key) or wordCount(key)
                        if size > d.maxLen then d.maxLen = size end
                        if not d.cjk and size == 1 and SUFFIXES[lang] then
                            local st = stem(lang, key)
                            if st ~= key and d.stems[st] == nil then d.stems[st] = en end
                        end
                    end
                end
            end
            local canonical = fields[2]
            if en ~= "" and canonical and canonical ~= "" then
                local ekey = normalizeEnglish(en)
                if ekey ~= "" and d.rev[ekey] == nil then
                    d.rev[ekey] = T.trim(canonical)
                    local wc = wordCount(ekey)
                    if wc > d.revMaxWords then d.revMaxWords = wc end
                end
            end
        end
    end
    if d.maxLen > 12 then d.maxLen = 12 end
    if d.revMaxWords > 6 then d.revMaxWords = 6 end
    raw[lang] = nil
    built[lang] = d
    WT.Debug("dictionary ready:", lang, d.count, "forms")
    return d
end

function WT.GetDictionary(lang)
    return built[lang] or build(lang)
end

function WT.DictionaryLanguages()
    local out = {}
    for lang in pairs(raw) do out[#out + 1] = lang end
    for lang in pairs(built) do out[#out + 1] = lang end
    table.sort(out)
    return out
end
