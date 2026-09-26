-- WoW Translate: language detection
-- Script-based for Chinese / Japanese / Korean / Russian, and a small
-- stop-word vote for the Latin-script languages. Returns nil when unsure, so
-- short neutral lines ("gg", "ok", "lol", "+1") are never "translated".

local _, WT = ...
local T = WT.Text

local gmatch, gsub, find = string.gmatch, string.gsub, string.find

-- Distinctive, frequent words per language (already lowercased and
-- accent-folded, because detection runs on normalized text). Words that are
-- common to several of these languages are deliberately left out.
local STOP = {
    en = "the and you your you're youre i'm im is are was were it's its this that what where when who why how "
      .. "need needs have has had can can't cant will would just my me we they them their not don't dont "
      .. "please pls plz anyone looking group want wants got get getting going come here there now "
      .. "with for from of to in on at be been if but or so too any some thanks thank thx ty sorry "
      .. "yes yeah yep nope selling buying run runs quest help guys guild does did who's what's",
    de = "der die das und ist nicht ich du wir ihr sie ein eine einen einem mit fur auf noch auch wie was "
      .. "wo wer bin bist sind hat habe haben kann kannst mal schon jetzt gibt heute suche suchen brauche "
      .. "brauchen gruppe bitte danke hallo ja nein kein keine oder aber dann hier gut sehr zum zur im dem "
      .. "den des mir mich dich uns euch vom geht gerne leute moin servus tschuss nochmal wieso warum",
    fr = "le la les un une des du et est pas je tu il elle nous vous ils avec pour dans sur qui quoi mais "
      .. "c'est cest ce cette mon ma mes ton ta suis sont fait faire bonjour salut merci oui non cherche "
      .. "besoin tres plus bien aussi ici quand comment pourquoi j'ai jai au aux d'un d'une qu'il "
      .. "mdr ptdr stp svp dsl jsp moi toi",
    es = "el los las y es esta estoy ella nosotros con para por una uno unos pero muy hola gracias "
      .. "si busco necesito hay tengo tiene vamos ahora aqui tambien del al lo me te se mi su mas ya eso "
      .. "esto quien cual donde cuando jaja jajaja porfa vale bueno",
    pt = "o os e nao eu voce vc ele ela nos com pra por um uma mas muito ola oi obrigado obrigada sim "
      .. "procuro preciso tem tenho agora aqui bem tambem tbm do da dos das na nas meu minha seu sua mais "
      .. "ja isso isto kkk kkkk kkkkk vlw valeu blz beleza cade entao voces",
}

-- Characters that strongly suggest one Latin-script language.
local MARKS = {
    de = { "ä", "ö", "ü", "ß" },
    fr = { "è", "ê", "à", "ù", "œ", "ç", "â", "î", "û" },
    es = { "ñ", "¿", "¡" },
    pt = { "ã", "õ", "ç" },
}

local STOPSET = {}
for lang, words in pairs(STOP) do
    local set = {}
    for w in gmatch(words, "%S+") do set[w] = true end
    STOPSET[lang] = set
end

local LATIN_LANGS = { "en", "de", "fr", "es", "pt" }
local DICT_LANGS = { "de", "fr", "es", "pt" }

-- Remove WoW escape codes and hyperlinks before looking at the words.
local function Plain(s)
    s = gsub(s, "|H.-|h(.-)|h", "%1")
    s = gsub(s, "|c%x%x%x%x%x%x%x%x", "")
    s = gsub(s, "|cn[^:]*:", "")
    s = gsub(s, "|r", "")
    s = gsub(s, "|[TAK].-|[tak]", "")
    s = gsub(s, "{[^}]*}", "")
    return s
end
WT.PlainText = Plain

-- Returns lang code (or nil) and a confidence number.
function WT.DetectLanguage(text)
    if not text or text == "" then return nil, 0 end
    -- Link names come from the sender's game client, not from what they
    -- typed, so they are no evidence of the chat language: drop them.
    local plain = Plain((gsub(text, "|H.-|h.-|h", " ")))
    local counts = T.scriptCounts(plain)

    local hangul, kana, han, cyr = counts.hangul or 0, counts.kana or 0, counts.han or 0, counts.cyrillic or 0
    local latin = counts.latin or 0

    -- Non-Latin scripts are decisive.
    if hangul > 0 and hangul >= kana and hangul >= cyr then return "ko", hangul end
    if kana > 0 then return "ja", kana + han end
    if han > 0 then return "zh", han end
    if cyr > 0 and cyr >= latin / 2 then return "ru", cyr end
    if latin == 0 then return nil, 0 end

    -- Latin script: vote with stop words and accent marks.
    local lowered = T.lower(plain)
    local score = { en = 0, de = 0, fr = 0, es = 0, pt = 0 }
    for lang, marks in pairs(MARKS) do
        for _, m in ipairs(marks) do
            if find(lowered, m, 1, true) then score[lang] = score[lang] + 2 end
        end
    end
    local folded = T.foldAccents(lowered)
    local words = 0
    for w in gmatch(folded, "[%a']+") do
        words = words + 1
        for _, lang in ipairs(LATIN_LANGS) do
            if STOPSET[lang][w] then score[lang] = score[lang] + 1 end
        end
    end

    local function pick()
        local best, bestScore, second = nil, 0, 0
        for _, lang in ipairs(LATIN_LANGS) do
            local s = score[lang]
            if s > bestScore then
                second, best, bestScore = bestScore, lang, s
            elseif s > second then
                second = s
            end
        end
        return best, bestScore, second
    end

    local best, bestScore, second = pick()
    local clear = best and bestScore - second >= 2 and not (bestScore == 2 and words > 8)
    if not clear and WT.GetDictionary then
        -- Not sure yet: words that only one language's dictionary knows are
        -- good evidence ("susurrame", "gleich"). Loanwords shared by several
        -- dictionaries ("tank", "afk") count for nobody.
        local dicts = {}
        for _, lang in ipairs(DICT_LANGS) do dicts[lang] = WT.GetDictionary(lang) end
        for w in gmatch(folded, "[%a']+") do
            if #w >= 3 and not STOPSET.en[w] then
                local only, n = nil, 0
                for _, lang in ipairs(DICT_LANGS) do
                    local d = dicts[lang]
                    if d and (d.fwd[w] ~= nil or d.stems[w] ~= nil) then only, n = lang, n + 1 end
                end
                if n == 1 then score[only] = score[only] + 1 end
            end
        end
        best, bestScore, second = pick()
    end

    if not best or bestScore == second then return nil, 0 end
    -- A single weak hit in a long line is not enough evidence.
    if bestScore == 1 and words > 4 then return nil, 0 end
    -- One-word lines ("yo", "same", "xD") are everywhere in English chat:
    -- only trust them with strong evidence such as accent marks.
    if words <= 1 and bestScore < 2 then return nil, 0 end
    return best, bestScore - second
end
