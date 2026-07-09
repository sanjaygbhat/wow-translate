-- WoWTranslate_NameTooltip.lua
-- Tooltip-only translation of CJK player names.
--
-- SAFETY DESIGN: this module never changes any name the client acts on.
-- It does not touch UnitName, chat hyperlink hrefs, SendChatMessage, edit
-- boxes or invite/whisper targets. It only ADDS an extra display line to
-- GameTooltip, so whispers and party invites always use the real name.

local NT_R, NT_G, NT_B = 0.4, 0.85, 1.0
local NT_MARK = "\194\187 " -- "» " (UTF-8), marks lines owned by this module
local PENDING_TEXT = NT_MARK .. "translating..."

-- Invalidation for async results: bumped every time GameTooltip hides, so a
-- translation that arrives after the tooltip closed is dropped (still cached).
local tooltipSerial = 0
local pendingLineIndex = nil
local chatTooltipShown = false

local function NT_Enabled()
    return WoWTranslateDB and WoWTranslateDB.enabled and WoWTranslateDB.nameTooltips
end

-- Chinese detection: same UTF-8 lead-byte heuristic as the chat pipeline
local function NT_HasCJK(text)
    if not text then return false end
    for i = 1, string.len(text) do
        local b = string.byte(text, i)
        if b and b >= 228 and b <= 233 then
            return true
        end
    end
    return false
end

-- One translation line per tooltip: skip if we already tagged this one
local function NT_AlreadyTagged()
    local n = GameTooltip:NumLines() or 0
    for i = 2, n do
        local fs = getglobal("GameTooltipTextLeft" .. i)
        local t = fs and fs:GetText()
        if t and string.find(t, "^" .. NT_MARK) then
            return true
        end
    end
    return false
end

-- Replace the "translating..." placeholder in place if it is still there,
-- otherwise append a fresh line.
local function NT_AddOrUpdateLine(text)
    if pendingLineIndex then
        local fs = getglobal("GameTooltipTextLeft" .. pendingLineIndex)
        if fs and fs:GetText() == PENDING_TEXT then
            fs:SetText(text)
            fs:SetTextColor(NT_R, NT_G, NT_B)
            pendingLineIndex = nil
            GameTooltip:Show()
            return
        end
        pendingLineIndex = nil
    end
    GameTooltip:AddLine(text, NT_R, NT_G, NT_B)
    GameTooltip:Show()
end

-- Core: the tooltip for `name` is currently visible; add the translation
-- line now (cache hit) or queue an async request and fill it in on arrival.
local function NT_ShowTranslation(name)
    if not NT_Enabled() or not name or not NT_HasCJK(name) then return end
    if NT_AlreadyTagged() then return end

    local cached = WoWTranslate_CacheGet and WoWTranslate_CacheGet(name)
    if cached then
        GameTooltip:AddLine(NT_MARK .. cached, NT_R, NT_G, NT_B)
        GameTooltip:Show()
        if WoWTranslate_API and WoWTranslate_API.TrackCacheHit then
            WoWTranslate_API.TrackCacheHit(string.len(name))
        end
        return
    end

    if not (WoWTranslate_API and WoWTranslate_API.IsAvailable()) then return end

    GameTooltip:AddLine(PENDING_TEXT, 0.6, 0.6, 0.6)
    pendingLineIndex = GameTooltip:NumLines()
    GameTooltip:Show()

    local serial = tooltipSerial
    WoWTranslate_API.Translate(name, function(result, err)
        if not result then return end
        WoWTranslate_CacheSave(name, result)
        if serial == tooltipSerial and GameTooltip:IsVisible() then
            NT_AddOrUpdateLine(NT_MARK .. result)
        end
    end)
end

local function NT_OnUnitTooltip(unit)
    if not NT_Enabled() then return end
    if not UnitExists(unit) or not UnitIsPlayer(unit) then return end
    NT_ShowTranslation(UnitName(unit))
end

-- Chat player links (|Hplayer:Name|h): show a small tooltip at the cursor.
-- Only the displayed tooltip is involved; the link href stays untouched, so
-- click-to-whisper keeps using the real name.
local function NT_OnChatLinkEnter(link)
    if not NT_Enabled() or not link then return end
    local _, _, pname = string.find(link, "^player:([^:]+)")
    if not pname or not NT_HasCJK(pname) then return end

    if not GameTooltip:IsVisible() then
        GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
        GameTooltip:SetText(pname)
        chatTooltipShown = true
    end
    NT_ShowTranslation(pname)
end

local function NT_OnChatLinkLeave()
    if chatTooltipShown then
        chatTooltipShown = false
        GameTooltip:Hide()
    end
end

local function NT_InstallHooks()
    -- 1) World mouseover: engine-built tooltips fire OnShow; the "mouseover"
    -- unit is valid at that point (same pattern MobStats uses on this client).
    -- Chain the previous handler so MobStats/pfUI keep working.
    local prevOnShow = GameTooltip:GetScript("OnShow")
    GameTooltip:SetScript("OnShow", function()
        if UnitExists("mouseover") then
            NT_OnUnitTooltip("mouseover")
        end
        if prevOnShow then prevOnShow() end
    end)

    -- 2) Unit frames (target/party/pfUI): any Lua caller of SetUnit
    local origSetUnit = GameTooltip.SetUnit
    GameTooltip.SetUnit = function(self, unit)
        origSetUnit(self, unit)
        NT_OnUnitTooltip(unit)
    end

    -- 3) Invalidate pending async fills when the tooltip closes
    local prevOnHide = GameTooltip:GetScript("OnHide")
    GameTooltip:SetScript("OnHide", function()
        if prevOnHide then prevOnHide() end
        tooltipSerial = tooltipSerial + 1
        pendingLineIndex = nil
    end)

    -- 4) Player links in chat: wrap (never replace) existing handlers so
    -- pfUI's item-link hover tooltips keep working.
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = getglobal("ChatFrame" .. i)
        if frame then
            local prevEnter = frame:GetScript("OnHyperlinkEnter")
            frame:SetScript("OnHyperlinkEnter", function()
                if prevEnter then prevEnter() end
                NT_OnChatLinkEnter(arg1)
            end)
            local prevLeave = frame:GetScript("OnHyperlinkLeave")
            frame:SetScript("OnHyperlinkLeave", function()
                if prevLeave then prevLeave() end
                NT_OnChatLinkLeave()
            end)
        end
    end
end

local ntFrame = CreateFrame("Frame")
ntFrame:RegisterEvent("ADDON_LOADED")
ntFrame:RegisterEvent("PLAYER_LOGIN")
ntFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "WoWTranslate" then
        WoWTranslateDB = WoWTranslateDB or {}
        if WoWTranslateDB.nameTooltips == nil then
            WoWTranslateDB.nameTooltips = true
        end
    elseif event == "PLAYER_LOGIN" then
        NT_InstallHooks()
    end
end)
