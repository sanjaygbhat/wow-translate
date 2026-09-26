-- WoW Translate: outgoing chat (Quick mode)
--
-- Blizzard's chat edit box fires "ChatFrame.OnEditBoxPreSendText" right
-- before it sends, explicitly so addons can make final edits. We replace the
-- edit box text there. Blizzard's own code still does the sending, so chat
-- keeps working normally, including during chat lockdown (where we simply
-- leave the text alone).

local _, WT = ...
local L = WT.L
local T = WT.Text

local sub, find = string.sub, string.find

-- Short tag in the reader's language so they know a machine translated it.
local TAGS = {
    en = "(translated)", de = "(übersetzt)", fr = "(traduit)", es = "(traducido)",
    pt = "(traduzido)", ru = "(перевод)", ko = "(번역)", zh = "(翻译)", ja = "(翻訳)",
}
WT.OUTGOING_TAGS = TAGS

local MIN_SCORE = 0.5    -- do not send word salad: at least half must be known
local MAX_BYTES = 255

-- Which language to write in for this chat line, or nil to leave it alone.
function WT.OutgoingTarget(chatType, tellTarget)
    local db = WT.db
    local mine = WT.ClientLang()
    local to = db.outgoingTo
    if to ~= "auto" then
        return (to ~= mine) and to or nil
    end
    local channel = WT.CHATTYPE_CHANNEL[chatType]
    local lang
    if channel == "WHISPER" and tellTarget then
        lang = WT.lastLangBySender[WT.ShortName(tellTarget)]
    elseif channel then
        lang = WT.lastLangByChannel[channel]
    end
    if lang and lang ~= mine then return lang end
    return nil
end

-- Translate text the player typed. Returns the text to send, or nil.
function WT.TranslateOutgoing(text, to)
    local from = WT.ClientLang()
    if not to or to == from then return nil end
    if WT.DetectLanguage(text) == to then return nil end   -- already in their language
    local out, score = WT.TranslateMessage(text, from, to)
    if not out or score < MIN_SCORE then
        WT.Debug("outgoing skipped, score", score)
        return nil, score
    end
    if WT.db.outgoingTag then
        out = (TAGS[to] or TAGS.en) .. " " .. out
    end
    return T.truncate(out, MAX_BYTES), score
end

local function OnPreSend(_, editBox)
    local db = WT.db
    if not db or not db.outgoingEnabled or not editBox then return end
    local ok, text = pcall(editBox.GetText, editBox)
    if not ok or type(text) ~= "string" or text == "" or not WT.CanRead(text) then return end
    if sub(text, 1, 1) == "/" then return end
    if WT.InChatLockdown() then return end

    local chatType = editBox.GetChatType and editBox:GetChatType()
    local channel = WT.CHATTYPE_CHANNEL[chatType or ""]
    if not channel or not db.outgoingChannels[channel] then return end

    local tellTarget = editBox.GetTellTarget and editBox:GetTellTarget()
    local to = WT.OutgoingTarget(chatType, tellTarget)
    if not to then return end

    local out = WT.TranslateOutgoing(text, to)
    if out and out ~= text then
        editBox:SetText(out)
        WT.Debug("outgoing", chatType, to, out)
    end
end

WT.On("LOGIN", function()
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("ChatFrame.OnEditBoxPreSendText", OnPreSend, WT)
    else
        WT.Debug("no pre-send hook on this client; outgoing translation unavailable")
    end
end)

WT._OnPreSend = OnPreSend
