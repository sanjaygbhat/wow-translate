-- WoW Translate: romanized player names
--
-- Names written in another alphabet (小明, Иван, 민수) get a Latin reading in
-- their tooltip, e.g. "» Xiao Ming". This uses the game's own built-in
-- transliterator (C_Intl.Transliterate), so it is exact and costs nothing.
-- Display only: the real name is never changed, so whispers and invites
-- always use the correct name.

local _, WT = ...
local T = WT.Text

local gsub, upper = string.gsub, string.upper

local cache = {}
local available = nil   -- nil = not tested yet
local ID_CHAIN = { "Any-Latin; Latin-ASCII", "Any-Latin", "Han-Latin", "Cyrillic-Latin", "Hangul-Latin" }
local workingID

local function tryTransliterate(text, id)
    local ok, out = pcall(C_Intl.Transliterate, text, id)
    if ok and type(out) == "string" and out ~= "" then return out end
    return nil
end

function WT.Romanize(name)
    if not name or name == "" or not T.hasNonAscii(name) then return nil end
    if not (C_Intl and C_Intl.Transliterate) then return nil end
    local hit = cache[name]
    if hit ~= nil then return hit or nil end

    local out
    if workingID then
        out = tryTransliterate(name, workingID)
    elseif available ~= false then
        for _, id in ipairs(ID_CHAIN) do
            out = tryTransliterate(name, id)
            if out and out ~= name then workingID = id break end
        end
        available = out ~= nil
    end
    if out then
        out = gsub(out, "(%a)(%w*)", function(a, b) return upper(a) .. b end)
        if out == name then out = nil end
    end
    cache[name] = out or false
    return out
end

local MARK = "|cff66bbff\194\187 %s|r"   -- » Name

local function NameFromUnit(tooltip)
    if not tooltip or not tooltip.GetUnit then return nil end
    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    if not ok or not unit or not WT.CanRead(unit) then return nil end
    if not (UnitIsPlayer and UnitIsPlayer(unit)) then return nil end
    local name = UnitName(unit)
    if not WT.CanRead(name) then return nil end
    return name
end

local function OnUnitTooltip(tooltip)
    local db = WT.db
    if not db or not db.romanizeNames then return end
    local name = NameFromUnit(tooltip)
    local roman = name and WT.Romanize(name)
    if roman then
        tooltip:AddLine(string.format(MARK, roman))
    end
end

-- Player names in chat: hovering a name shows the reading.
local chatTipShown = false
local function OnLinkEnter(_, chatFrame, link)
    local db = WT.db
    if not db or not db.romanizeNames or type(link) ~= "string" then return end
    local name = string.match(link, "^player:([^:]+)")
    if not name then return end
    local short = Ambiguate and Ambiguate(name, "none") or name
    local roman = WT.Romanize(short)
    if not roman then return end
    if not GameTooltip:IsShown() then
        GameTooltip:SetOwner(chatFrame or UIParent, "ANCHOR_CURSOR")
        GameTooltip:SetText(short)
        chatTipShown = true
    end
    GameTooltip:AddLine(string.format(MARK, roman))
    GameTooltip:Show()
end

local function OnLinkLeave()
    if chatTipShown then
        chatTipShown = false
        GameTooltip:Hide()
    end
end

WT.On("LOGIN", function()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnitTooltip)
    end
    if EventRegistry and EventRegistry.RegisterCallback then
        -- A separate owner table: an owner can only hold one callback per event,
        -- and Incoming.lua already uses WT for these events.
        local owner = {}
        EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkEnter", OnLinkEnter, owner)
        EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkLeave", OnLinkLeave, owner)
    end
end)
