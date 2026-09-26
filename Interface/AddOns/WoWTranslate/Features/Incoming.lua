-- WoW Translate: incoming chat
--
-- Uses Blizzard's chat message filters (ChatFrameUtil.AddMessageEventFilter).
-- On the Forever / Midnight client those filters are only called for
-- messages addons are allowed to read: during boss encounters, rated PvP and
-- similar "chat lockdown" moments other players' lines arrive as secret
-- values and are shown untouched. Nothing here ever reads a secret value.

local _, WT = ...
local L = WT.L
local T = WT.Text

local format, match, find, gsub = string.format, string.match, string.find, string.gsub

-- A message is shown once per chat window; filters run once per window, so
-- each chat line is worked out once and remembered by its line ID.
local memo, memoKeys, memoPos = {}, {}, 0
local memoGen = {}           -- generation for lines that were left untouched
local generation = 1         -- bumped when settings change
local MEMO_MAX = 500

local function Remember(lineID, entry)
    memoPos = memoPos % MEMO_MAX + 1
    local old = memoKeys[memoPos]
    if old then memo[old] = nil; memoGen[old] = nil end
    memoKeys[memoPos] = lineID
    memo[lineID] = entry
end

function WT.GetTranslatedLine(lineID)
    local e = memo[lineID]
    return e or nil
end

-- Which language each player / channel last wrote in: lets outgoing
-- translation answer people in their own language.
WT.lastLangBySender = {}
WT.lastLangByChannel = {}

local function ShortName(name)
    if not name then return nil end
    if Ambiguate then
        local ok, n = pcall(Ambiguate, name, "none")
        if ok and n then name = n end
    end
    return string.lower(name)
end
WT.ShortName = ShortName

local MIN_SCORE = 0.25   -- below this, a Quick translation would be mostly guesswork

local function Marker(lineID)
    return "|Haddon:WoWTranslate:o:" .. lineID .. "|h|cff66bbff[" .. L.MARKER_LETTER .. "]|r|h "
end

local function IsAFK()
    if not UnitIsAFK then return false end
    local afk = UnitIsAFK("player")      -- can be secret during chat lockdown
    if not WT.CanRead(afk) then return false end
    return afk and true or false
end

-- Work out what to show for one chat line. Returns an entry table or false.
local function Process(event, msg, author, channelName, lineID, guid)
    local db = WT.db
    local channel = WT.EVENT_CHANNEL[event]
    if not channel or not db.channels[channel] then return false end
    if guid and WT.playerGUID and guid == WT.playerGUID then return false end
    if db.disableWhileAfk and IsAFK() then return false end

    local from = WT.DetectLanguage(msg)
    local to = WT.IncomingTarget()

    if from then
        local who = ShortName(author)
        if who then WT.lastLangBySender[who] = from end
        WT.lastLangByChannel[channel] = from
    end

    -- Accurate mode: hand foreign lines to the companion app.
    if db.mode == "accurate" and WT.CompanionLink then
        local plain = WT.PlainText(msg)
        local foreign = (from and from ~= to) or (not from and T.hasNonAscii(plain))
        if foreign then
            WT.CompanionLink.SendChat(channel, channelName, author, from, plain)
        end
    end

    local translatable = from and from ~= to and WT.HasDictionary(from)
        and (from == "en" or to == "en" or WT.HasDictionary(to))
    if not translatable then
        -- Same language, but item/quest links may still carry names from the
        -- sender's client language: show those in the reader's language.
        local relinked = db.localizeLinks and WT.LocalizeLinksOnly(msg)
        if relinked then
            return { display = relinked, original = msg, from = from, to = to, score = 1, author = author, linksOnly = true }
        end
        return false
    end

    local out, score = WT.TranslateMessage(msg, from, to)
    if not out or score < MIN_SCORE then
        local relinked = db.localizeLinks and WT.LocalizeLinksOnly(msg)
        if relinked then
            return { display = relinked, original = msg, from = from, to = to, score = 1, author = author, linksOnly = true }
        end
        return false
    end

    local display = out
    if db.display == "both" then
        display = out .. " |cff9d9d9d(" .. msg .. "|cff9d9d9d)|r"
    end
    if db.showMarker and lineID then
        display = Marker(lineID) .. display
    end
    return { display = display, original = msg, from = from, to = to, score = score, author = author }
end

local function Filter(chatFrame, event, msg, author, ...)
    local db = WT.db
    if not db or not db.enabled then return false end
    if type(msg) ~= "string" or msg == "" or not WT.CanRead(msg) then return false end

    local channelName = select(2, ...)      -- arg4
    local lineID = select(9, ...)           -- arg11
    local guid = select(10, ...)            -- arg12

    local entry
    if type(lineID) == "number" and lineID > 0 then
        entry = memo[lineID]
        if entry ~= nil and (entry and entry.gen or memoGen[lineID]) ~= generation then entry = nil end
        if entry == nil then
            local ok, res = pcall(Process, event, msg, author, channelName, lineID, guid)
            if not ok then
                WT.Debug("incoming error:", res)
                res = false
            end
            entry = res
            if entry then entry.gen = generation else memoGen[lineID] = generation end
            Remember(lineID, entry)
        end
    else
        local ok, res = pcall(Process, event, msg, author, channelName, nil, guid)
        entry = ok and res or false
    end

    if entry then
        return false, entry.display, author, ...
    end
    return false
end

-- ---------------------------------------------------------------------------
-- The [T] marker: hover shows the original, click prints it in chat.
-- ---------------------------------------------------------------------------
local tooltipShown = false

local function LangName(code)
    return (code and WT.LANG_NATIVE[code]) or "?"
end

local function OnLinkEnter(_, chatFrame, link)
    if not WT.CanRead(link) or type(link) ~= "string" then return end
    local id = match(link, "^addon:WoWTranslate:o:(%d+)")
    if not id then return end
    local e = memo[tonumber(id)]
    if not e then return end
    GameTooltip:SetOwner(chatFrame or UIParent, "ANCHOR_CURSOR")
    GameTooltip:SetText(L.TOOLTIP_TITLE, 0.2, 0.8, 1)
    GameTooltip:AddLine(format(L.TOOLTIP_ORIGINAL, LangName(e.from)), 1, 0.82, 0)
    GameTooltip:AddLine(WT.PlainText(e.original), 1, 1, 1, true)
    GameTooltip:AddLine(" ")
    if WT.db.mode == "accurate" then
        GameTooltip:AddLine(L.TOOLTIP_ACCURATE_HINT, 0.6, 0.6, 0.6, true)
    else
        GameTooltip:AddLine(L.TOOLTIP_QUICK_HINT, 0.6, 0.6, 0.6, true)
    end
    GameTooltip:AddLine(L.TOOLTIP_CLICK_HINT, 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
    tooltipShown = true
end

local function OnLinkLeave()
    if tooltipShown then
        tooltipShown = false
        GameTooltip:Hide()
    end
end

local function OnLinkClick(_, link, text, button, chatFrame)
    if not WT.CanRead(link) or type(link) ~= "string" then return end
    local id = match(link, "^addon:WoWTranslate:o:(%d+)")
    if not id then return end
    local e = memo[tonumber(id)]
    local frame = chatFrame or DEFAULT_CHAT_FRAME
    if e and frame and frame.AddMessage then
        frame:AddMessage("|cff9d9d9d" .. format(L.ORIGINAL_LINE, LangName(e.from)) .. "|r " .. e.original)
    end
end

WT.On("LOGIN", function()
    local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    if not add then
        WT.Print(L.ERR_NO_CHAT_FILTERS)
        return
    end
    for event in pairs(WT.EVENT_CHANNEL) do
        add(event, Filter)
    end
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkEnter", OnLinkEnter, WT)
        EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkLeave", OnLinkLeave, WT)
        EventRegistry:RegisterCallback("SetItemRef", OnLinkClick, WT)
    end
end)

-- Settings that change what a line looks like must not reuse old results,
-- but already-shown lines keep their hover text.
WT.On("SETTINGS_CHANGED", function()
    generation = generation + 1
end)

-- Exposed for /wt test and the test harness.
WT._IncomingFilter = Filter
