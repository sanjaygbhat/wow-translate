-- WoW Translate: hyperlinks and escape codes
--
-- Chat text mixes plain words with WoW escape sequences: hyperlinks
-- (|H...|h[text]|h), colours (|cffRRGGBB, |cnNAME:, |r), textures (|T..|t),
-- atlases (|A..|a), protected strings (|K..|k) and raid icons ({rt1}).
-- Only the plain words are ever translated; every code is passed through
-- byte-for-byte so links stay clickable and protected strings stay intact.
--
-- Link names are shown in the reader's language using the client's own
-- item / quest / spell data. That part is exact, not a guess.

local _, WT = ...

local sub, find, match = string.sub, string.find, string.match
local concat = table.concat

-- ---------------------------------------------------------------------------
-- Splitting
-- ---------------------------------------------------------------------------
-- Returns an array of segments: { k = "t", s = text } or { k = "c", s = code,
-- link = { data =, text = } (for hyperlinks) }.
function WT.SplitMessage(msg)
    local segs = {}
    local pos, L = 1, #msg
    local textStart = 1

    local function flushText(upto)
        if upto >= textStart then
            segs[#segs + 1] = { k = "t", s = sub(msg, textStart, upto) }
        end
    end

    while pos <= L do
        local a = find(msg, "[|{]", pos)
        if not a then break end
        local c = sub(msg, a, a)
        local codeEnd, link

        if c == "{" then
            local close = find(msg, "}", a + 1, true)
            if close and close - a <= 24 and not find(sub(msg, a + 1, close - 1), "%s") then
                codeEnd = close
            end
        else
            local c2 = sub(msg, a + 1, a + 1)
            if c2 == "H" then
                local mid = find(msg, "|h", a + 2, true)
                local close = mid and find(msg, "|h", mid + 2, true)
                if close then
                    codeEnd = close + 1
                    link = { data = sub(msg, a + 2, mid - 1), text = sub(msg, mid + 2, close - 1) }
                end
            elseif c2 == "c" then
                if sub(msg, a + 2, a + 2) == "n" then
                    local colon = find(msg, ":", a + 3, true)
                    if colon and colon - a <= 40 then codeEnd = colon end
                elseif match(sub(msg, a + 2, a + 9), "^%x%x%x%x%x%x%x%x$") then
                    codeEnd = a + 9
                end
            elseif c2 == "T" or c2 == "A" or c2 == "K" then
                local close = find(msg, "|" .. string.lower(c2), a + 2, true)
                if close then codeEnd = close + 1 end
            elseif c2 ~= "" then
                codeEnd = a + 1               -- |r, |n, ||, and anything unknown
            end
        end

        if codeEnd then
            flushText(a - 1)
            segs[#segs + 1] = { k = "c", s = sub(msg, a, codeEnd), link = link }
            pos = codeEnd + 1
            textStart = pos
        else
            pos = a + 1
        end
    end
    flushText(L)
    return segs
end

function WT.JoinSegments(segs)
    local out = {}
    for i = 1, #segs do out[i] = segs[i].s end
    return concat(out)
end

-- ---------------------------------------------------------------------------
-- Native link names
-- ---------------------------------------------------------------------------
local function ItemName(id)
    if C_Item and C_Item.GetItemNameByID then
        local ok, name = pcall(C_Item.GetItemNameByID, id)
        if ok and type(name) == "string" and name ~= "" then return name end
        -- Not cached yet: ask the client to load it so the next link is ready.
        if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    end
    return nil
end

local function QuestName(id)
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, name = pcall(C_QuestLog.GetTitleForQuestID, id)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return nil
end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, id)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return nil
end

local function AchievementName(id)
    if GetAchievementInfo then
        local ok, _, name = pcall(GetAchievementInfo, id)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return nil
end

local RESOLVERS = {
    item = ItemName,
    quest = QuestName,
    spell = SpellName,
    enchant = SpellName,
    achievement = AchievementName,
}

-- Returns a rebuilt link segment string, or nil when nothing changes.
function WT.LocalizeLink(seg)
    local link = seg.link
    if not link then return nil end
    local ltype, id = match(link.data, "^(%a+):(%d+)")
    local resolve = ltype and RESOLVERS[ltype]
    if not resolve then return nil end
    if ltype == "item" then
        -- item:id:enchant:gem1:gem2:gem3:gem4:suffix:unique:level:spec:mods:context:numBonus:...
        -- Random-suffix or bonus items ("... of the Monkey") would lose part of
        -- their name, so they keep the name the sender's client gave them.
        local f = {}
        for v in string.gmatch(link.data .. ":", "([^:]*):") do f[#f + 1] = v end
        if (tonumber(f[8]) or 0) ~= 0 or (tonumber(f[14]) or 0) > 0 then return nil end
    end
    local name = resolve(tonumber(id))
    if not name then return nil end
    local text = link.text
    local bracketed = sub(text, 1, 1) == "[" and sub(text, -1) == "]"
    local newText = bracketed and ("[" .. name .. "]") or name
    if newText == text then return nil end
    return "|H" .. link.data .. "|h" .. newText .. "|h"
end

-- Only swap link names (for messages already in the reader's language).
-- Returns the new message or nil when nothing changed.
function WT.LocalizeLinksOnly(msg)
    if not find(msg, "|H", 1, true) then return nil end
    local segs = WT.SplitMessage(msg)
    local changed = false
    for i = 1, #segs do
        local seg = segs[i]
        if seg.link then
            local rebuilt = WT.LocalizeLink(seg)
            if rebuilt then seg.s = rebuilt changed = true end
        end
    end
    return changed and WT.JoinSegments(segs) or nil
end

-- ---------------------------------------------------------------------------
-- Whole-message Quick translation
-- ---------------------------------------------------------------------------
-- Returns: newMessage (or nil if nothing useful changed), score 0..1
-- keepLinks: never rewrite link names (used for text you send).
function WT.TranslateMessage(msg, from, to, keepLinks)
    local segs = WT.SplitMessage(msg)
    local changed = false
    local weighted, weight = 0, 0
    local localize = WT.db and WT.db.localizeLinks and not keepLinks

    for i = 1, #segs do
        local seg = segs[i]
        if seg.k == "t" then
            if find(seg.s, "[%w\128-\255]") then
                local lead, core, trail = match(seg.s, "^(%s*)(.-)(%s*)$")
                local out, score = WT.QuickTranslate(core, from, to)
                local w = #core
                weighted, weight = weighted + score * w, weight + w
                if out and out ~= core and score > 0 then
                    seg.s = lead .. out .. trail
                    changed = true
                end
            end
        elseif localize and seg.link then
            local rebuilt = WT.LocalizeLink(seg)
            if rebuilt then
                seg.s = rebuilt
                changed = true
            end
        end
    end

    if not changed then return nil, 0 end
    return WT.JoinSegments(segs), (weight > 0) and (weighted / weight) or 1
end
