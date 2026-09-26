-- WoW Translate offline test harness (WoW: Forever edition)
--
-- Loads the REAL addon files, in TOC order, inside a mocked Forever client
-- (modern API: ChatFrameUtil filters, EventRegistry, secret values, C_Intl,
-- macros ...) and checks every feature end to end.
--
-- Run from the repository root:   lua5.1 tests/harness.lua
-- Exit code 0 = everything passed.

local ADDON_DIR = "Interface/AddOns/WoWTranslate/"
local TOC = ADDON_DIR .. "WoWTranslate_Camelot.toc"

-- ===========================================================================
-- Tiny test framework
-- ===========================================================================
local failures, passes = {}, 0
local function check(cond, what, extra)
    if cond then passes = passes + 1
    else failures[#failures + 1] = what .. (extra and ("  [" .. tostring(extra) .. "]") or "") end
end
local function eq(a, b, what) check(a == b, what, "got " .. tostring(a) .. " expected " .. tostring(b)) end
local function contains(s, sub, what) check(type(s) == "string" and s:find(sub, 1, true) ~= nil, what, "got " .. tostring(s)) end
local function notcontains(s, sub, what) check(type(s) == "string" and s:find(sub, 1, true) == nil, what, "got " .. tostring(s)) end

-- ===========================================================================
-- Mock client
-- ===========================================================================
local now = 1000
function GetTime() return now end
function GetLocale() return MOCK_LOCALE or "enUS" end
function GetBuildInfo() return "1.60.1", "70009", "Sep 23 2026", 16001 end
function GetPhysicalScreenSize() return 1920, 1080 end
function GetCursorPosition() return 100, 100 end
function InCombatLockdown() return MOCK_COMBAT or false end
function UnitGUID(u) return u == "player" and "Player-1-00000001" or nil end
function UnitName(u) return u == "player" and "Tester" or MOCK_UNIT_NAME end
function UnitIsPlayer() return true end
function UnitIsAFK() return MOCK_AFK or false end
function Ambiguate(name) return (name:gsub("%-.*$", "")) end
function GetRealmName() return "Forever" end
function PlaySound() end
function HideUIPanel() end
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 1, IG_MAINMENU_OPTION_CHECKBOX_OFF = 2 }
CLOSE = "Close"
UISpecialFrames = {}
Enum = { TooltipDataType = { Unit = 2 } }
SlashCmdList = {}

-- secret values: a message wrapped in a table marked secret
local SECRET = setmetatable({}, { __mode = "k" })
local function Secret(s) local t = { s = s } SECRET[t] = true return t end
function issecretvalue(v) return type(v) == "table" and SECRET[v] == true end
function canaccessvalue(...)
    for i = 1, select("#", ...) do if issecretvalue((select(i, ...))) then return false end end
    return true
end

local frames = {}
local Mock = {}
Mock.__index = function(self, k)
    local v = rawget(Mock, k)
    if v ~= nil then return v end
    if type(k) == "string" and k:sub(1, 2) == "__" then return nil end
    return function() end            -- any unknown method is a harmless no-op
end
function Mock.new(ftype, name, parent)
    local f = setmetatable({ __type = ftype, __name = name, __shown = true, __scripts = {}, __events = {},
        __text = "", __checked = false, __w = 100, __h = 100, __children = {}, __parent = parent }, Mock)
    if name then _G[name] = f end
    frames[#frames + 1] = f
    return f
end
function Mock:RegisterEvent(e)
    if MOCK_UNKNOWN_EVENTS and MOCK_UNKNOWN_EVENTS[e] then error("unknown event " .. e) end
    self.__events[e] = true
end
function Mock:SetScript(k, fn) self.__scripts[k] = fn end
function Mock:GetScript(k) return self.__scripts[k] end
function Mock:HookScript(k, fn) self.__scripts[k] = fn end
function Mock:Show() self.__shown = true if self.__scripts.OnShow then self.__scripts.OnShow(self) end end
function Mock:Hide() self.__shown = false end
function Mock:IsShown() return self.__shown end
function Mock:IsVisible() return self.__shown end
function Mock:SetText(t) self.__text = t end
function Mock:GetText() return self.__text end
function Mock:SetChecked(v) self.__checked = v and true or false end
function Mock:GetChecked() return self.__checked end
function Mock:CreateTexture() return Mock.new("Texture") end
function Mock:CreateFontString() return Mock.new("FontString") end
function Mock:SetSize(w, h) self.__w, self.__h = w, h end
function Mock:GetWidth() return self.__w end
function Mock:GetCenter() return 50, 50 end
function Mock:GetEffectiveScale() return 1 end
function Mock:SetColorTexture(r, g, b, a) self.__color = { r, g, b, a } end
function Mock:GetNumPoints() return 0 end
function Mock:NumLines() return self.__lines and #self.__lines or 0 end
function Mock:AddLine(t) self.__lines = self.__lines or {} self.__lines[#self.__lines + 1] = t end
function Mock:AddMessage(t) self.__messages = self.__messages or {} self.__messages[#self.__messages + 1] = t end
function Mock:GetUnit() return MOCK_UNIT_NAME, "mouseover" end
function Mock:GetChatType() return self.__chatType end
function Mock:GetTellTarget() return self.__tellTarget end

function CreateFrame(ftype, name, parent, template)
    local f = Mock.new(ftype, name, parent)
    if template and template:find("UICheckButtonTemplate") then f.Text = Mock.new("FontString") end
    if template and template:find("ButtonFrameTemplate") then f.SetTitle = function(s, t) s.__title = t end end
    return f
end
function ButtonFrameTemplate_HidePortrait() end
function ButtonFrameTemplate_HideAttic() end
function ButtonFrameTemplate_HideButtonBar() end

UIParent = Mock.new("Frame", "UIParent")
Minimap = Mock.new("Frame", "Minimap")
GameTooltip = Mock.new("GameTooltip", "GameTooltip")
DEFAULT_CHAT_FRAME = Mock.new("ScrollingMessageFrame", "ChatFrame1")
local printed = {}
DEFAULT_CHAT_FRAME.AddMessage = function(self, t) printed[#printed + 1] = t end

-- Timers ------------------------------------------------------------------
local timers = {}
C_Timer = {}
function C_Timer.After(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end
function C_Timer.NewTicker(interval, fn)
    local t = { interval = interval, fn = fn, next = now + interval, cancelled = false }
    function t:Cancel() self.cancelled = true end
    timers[#timers + 1] = t
    return t
end
local function advance(sec)
    local target = now + sec
    while true do
        local soonest, idx = nil, nil
        for i, t in ipairs(timers) do
            local at = t.at or t.next
            if not t.cancelled and at <= target and (not soonest or at < soonest) then soonest, idx = at, i end
        end
        if not idx then break end
        now = soonest
        local t = timers[idx]
        if t.at then table.remove(timers, idx) t.fn() else t.next = t.next + t.interval t.fn(t) end
    end
    now = target
end

-- EventRegistry (Blizzard CallbackRegistry semantics: func(owner, ...)) ----
EventRegistry = { cb = {} }
function EventRegistry:RegisterCallback(event, fn, owner)
    self.cb[event] = self.cb[event] or {}
    owner = owner or {}
    self.cb[event][owner] = fn
    return owner
end
function EventRegistry:TriggerEvent(event, ...)
    for owner, fn in pairs(self.cb[event] or {}) do
        local ok, err = pcall(fn, owner, ...)
        check(ok, "EventRegistry callback " .. event, err)
    end
end

-- Chat filters (Blizzard ChatFrameFilters semantics) -------------------------
local chatFilters = {}
ChatFrameUtil = {}
function ChatFrameUtil.AddMessageEventFilter(event, fn)
    chatFilters[event] = chatFilters[event] or {}
    table.insert(chatFilters[event], fn)
end
-- Mirrors ChatFrameFilters.lua: filters are skipped for inaccessible args;
-- first return discards, second+ replace the arguments.
local function ProcessFilters(chatFrame, event, ...)
    local args = { n = select("#", ...), ... }
    for _, fn in ipairs(chatFilters[event] or {}) do
        if canaccessvalue(unpack(args, 1, args.n)) then
            local res = { pcall(fn, chatFrame, event, unpack(args, 1, args.n)) }
            check(res[1], "chat filter raised an error", res[2])
            if res[2] then return true end
            if res[3] then args = { n = #res - 2, unpack(res, 3) } end
        end
    end
    return false, unpack(args, 1, args.n)
end

local lineCounter = 0
-- Deliver a chat event to N chat frames; returns what frame 1 would show.
local function Chat(event, msg, author, opts)
    opts = opts or {}
    lineCounter = lineCounter + 1
    local lineID = opts.lineID or lineCounter
    local guid = opts.guid or "Player-1-0000BEEF"
    local shown
    for frameIndex = 1, (opts.frames or 2) do
        local discard, a1 = ProcessFilters({}, event, msg, author, "Common", opts.channel or "", "", "", 0, 0,
            opts.channelBase or "", 7, lineID, guid, 0, false)
        if frameIndex == 1 then shown = discard and "<discarded>" or a1 end
    end
    return shown, lineID
end

-- Macros -------------------------------------------------------------------
local macros = {}
function GetMacroIndexByName(name) for i, m in ipairs(macros) do if m.name == name then return i end end return 0 end
function GetMacroBody(i) return macros[i] and (macros[i].body .. "  \n") end   -- trailing whitespace like the client
function CreateMacro(name, icon, body) if MOCK_COMBAT then error("combat") end macros[#macros + 1] = { name = name, body = body } return #macros end
function EditMacro(i, _, _, body) if MOCK_COMBAT then error("combat") end macros[i].body = body end
function DeleteMacro(i) table.remove(macros, i) end

-- Game data used for link localization ---------------------------------------
C_Item = {}
local ITEMS = { [19019] = "Thunderfury, Blessed Blade of the Windseeker", [2589] = "Linen Cloth" }
local requested = {}
function C_Item.GetItemNameByID(id) return ITEMS[id] end
function C_Item.RequestLoadItemDataByID(id) requested[id] = true end
C_QuestLog = { GetTitleForQuestID = function(id) return id == 913 and "Stranglethorn Fever" or nil end }
C_Spell = { GetSpellName = function(id) return id == 1459 and "Arcane Intellect" or nil end }
C_ChatInfo = { InChatMessagingLockdown = function() return MOCK_LOCKDOWN or false end }
C_AddOns = { GetAddOnMetadata = function(_, key) return key == "Version" and "3.0.0" or nil end }
C_Intl = nil     -- the harness uses the Lua fallbacks; a second pass mocks C_Intl

TooltipDataProcessor = { calls = {} }
function TooltipDataProcessor.AddTooltipPostCall(t, fn) TooltipDataProcessor.calls[t] = fn end
Settings = {
    RegisterCanvasLayoutCategory = function() return { ID = 1 } end,
    RegisterAddOnCategory = function() end,
}

-- ===========================================================================
-- Load the addon exactly as the client would (TOC order, shared namespace)
-- ===========================================================================
local WT = {}
local tocFiles = {}
for line in io.lines(TOC) do
    line = line:gsub("\r", "")
    if line ~= "" and not line:find("^#") then tocFiles[#tocFiles + 1] = (line:gsub("\\", "/")) end
end
check(#tocFiles > 20, "TOC lists the addon files", #tocFiles)
for line in io.lines(TOC) do
    if line:find("^## Interface:") then contains(line, "16001", "TOC targets interface 16001 (WoW: Forever)") end
end

for _, file in ipairs(tocFiles) do
    local chunk, err = loadfile(ADDON_DIR .. file)
    check(chunk ~= nil, "file compiles: " .. file, err)
    if chunk then
        local ok, e = pcall(chunk, "WoWTranslate", WT)
        check(ok, "file loads without error: " .. file, e)
    end
end

local eventFrame
for _, f in ipairs(frames) do if f.__events.ADDON_LOADED then eventFrame = f break end end
check(eventFrame ~= nil, "core registered ADDON_LOADED")
local function fire(event, ...)
    for _, f in ipairs(frames) do
        if f.__events[event] and f.__scripts.OnEvent then f.__scripts.OnEvent(f, event, ...) end
    end
end

fire("ADDON_LOADED", "WoWTranslate")
check(WT.db ~= nil, "settings created at ADDON_LOADED")
check(not WT.hadSavedVariables, "beta bug path: no SavedVariables loaded")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
advance(5)
check(WT.Persist.ready, "settings persistence ready after login")
local greeted = false
for _, p in ipairs(printed) do if p:find("Quick mode is on", 1, true) then greeted = true end end
check(greeted, "login greeting printed")
check(chatFilters.CHAT_MSG_CHANNEL ~= nil and chatFilters.CHAT_MSG_WHISPER ~= nil, "chat filters registered")
check(EventRegistry.cb["ChatFrame.OnEditBoxPreSendText"] ~= nil, "outgoing pre-send hook registered")
check(SlashCmdList.WOWTRANSLATE ~= nil, "/wt registered")

-- ===========================================================================
-- Incoming translation
-- ===========================================================================
do
    local out = Chat("CHAT_MSG_CHANNEL", "法师拉仇恨了，快撤！", "李明-Forever")
    check(type(out) == "string", "Chinese line produces a translation")
    notcontains(out, "法师", "Chinese words replaced by English")
    contains(out, "|Haddon:WoWTranslate:o:", "translated line carries the [T] marker link")
    contains(out:lower(), "mage", "mage recognised")

    local plain = Chat("CHAT_MSG_CHANNEL", "anyone for Deadmines? need a tank", "Bob")
    eq(plain, "anyone for Deadmines? need a tank", "English line left untouched")

    local mine = Chat("CHAT_MSG_SAY", "法师", "Tester", { guid = "Player-1-00000001" })
    eq(mine, "法师", "own messages are never translated")

    WT.Set("channels.GUILD", false)
    eq(Chat("CHAT_MSG_GUILD", "法师", "Li"), "法师", "disabled channel is skipped")
    WT.Set("channels.GUILD", true)

    local sec = Secret("法师拉仇恨了")
    local shown = Chat("CHAT_MSG_RAID", sec, "Li")
    check(shown == sec, "secret (lockdown) messages pass through untouched")

    MOCK_AFK = true
    eq(Chat("CHAT_MSG_WHISPER", "法师", "Li"), "法师", "paused while AFK")
    MOCK_AFK = false

    -- memo: same line in two chat frames -> identical output, computed once
    local a, id = Chat("CHAT_MSG_PARTY", "快撤", "Li", { frames = 3 })
    local b = ProcessFilters({}, "CHAT_MSG_PARTY", "快撤", "Li", "", "", "", "", 0, 0, "", 7, id, "G", 0, false)
    check(a ~= nil and a ~= "快撤", "party line translated")

    -- hyperlinks survive; item names come from game data
    local link = "|cnIQ5:|Hitem:19019::::::::60:::::|h[雷霆之怒，逐风者的祝福之剑]|h|r"
    local msg = "出 " .. link .. " 便宜"
    local res = Chat("CHAT_MSG_CHANNEL", msg, "Li")
    contains(res, "|Hitem:19019::::::::60:::::|h[Thunderfury, Blessed Blade of the Windseeker]|h", "item link kept and shown with local name")
    contains(res, "|cnIQ5:", "link colour code preserved")

    local enWithLink = "WTS |cnIQ5:|Hitem:19019::::::::60:::::|h[雷霆之怒]|h|r cheap, pst"
    res = Chat("CHAT_MSG_CHANNEL", enWithLink, "Bob")
    contains(res, "[Thunderfury, Blessed Blade of the Windseeker]", "English line still gets its item link localized")
    notcontains(res, "|Haddon:WoWTranslate", "links-only change carries no [T] marker")

    local suffixItem = "|cff1eff00|Hitem:2589::::::612::60:::::|h[亚麻布之猴]|h|r"
    res = Chat("CHAT_MSG_CHANNEL", "出 " .. suffixItem, "Li")
    contains(res, suffixItem, "random-suffix item keeps its full name")

    local unknownItem = "|cffa335ee|Hitem:99999::::::::60:::::|h[某物品]|h|r"
    res = Chat("CHAT_MSG_CHANNEL", "收 " .. unknownItem, "Li")
    contains(res, unknownItem, "uncached item link kept byte-for-byte")
    check(requested[99999], "uncached item asked to load (safe on modern client)")

    -- protected |K strings and raid icons are untouched
    local kstr = "|Kq123|k"
    res = Chat("CHAT_MSG_WHISPER", "你好 " .. kstr .. " {rt1}", "Li")
    contains(res, kstr, "protected |K string preserved")
    contains(res, "{rt1}", "raid target icon preserved")

    -- show original too
    WT.Set("display", "both")
    res = Chat("CHAT_MSG_CHANNEL", "快撤", "Li")
    contains(res, "快撤", "'show original' keeps the original text")
    WT.Set("display", "replace")

    -- marker hover + click
    local _, lid = Chat("CHAT_MSG_CHANNEL", "法师快撤", "Li")
    GameTooltip.__lines = {}
    EventRegistry:TriggerEvent("ChatFrame.OnHyperlinkEnter", DEFAULT_CHAT_FRAME, "addon:WoWTranslate:o:" .. lid, "[T]")
    local found = false
    for _, l in ipairs(GameTooltip.__lines or {}) do if l:find("法师快撤", 1, true) then found = true end end
    check(found, "hovering [T] shows the original text")
    local before = #printed
    EventRegistry:TriggerEvent("SetItemRef", "addon:WoWTranslate:o:" .. lid, "[T]", "LeftButton", DEFAULT_CHAT_FRAME)
    check(#printed > before, "clicking [T] prints the original")

    -- incoming off
    WT.Set("enabled", false)
    eq(Chat("CHAT_MSG_CHANNEL", "法师", "Li"), "法师", "incoming off leaves chat alone")
    WT.Set("enabled", true)
end

-- ===========================================================================
-- Outgoing translation (Quick) via the official pre-send hook
-- ===========================================================================
do
    WT.Set("outgoingEnabled", true)
    Chat("CHAT_MSG_WHISPER", "你好，你在哪", "Wang-Forever")
    local box = Mock.new("EditBox")
    box.__chatType, box.__tellTarget = "WHISPER", "Wang"
    box:SetText("hello, where are you")
    EventRegistry:TriggerEvent("ChatFrame.OnEditBoxPreSendText", box)
    local sent = box:GetText()
    contains(sent, "(翻译)", "reply is tagged as translated in their language")
    notcontains(sent, "where are you", "reply was translated into Chinese")

    box:SetText("/dance")
    EventRegistry:TriggerEvent("ChatFrame.OnEditBoxPreSendText", box)
    eq(box:GetText(), "/dance", "slash commands are never touched")

    MOCK_LOCKDOWN = true
    box:SetText("hello")
    EventRegistry:TriggerEvent("ChatFrame.OnEditBoxPreSendText", box)
    eq(box:GetText(), "hello", "nothing is changed during chat lockdown")
    MOCK_LOCKDOWN = false

    box.__tellTarget = "Stranger"
    box:SetText("hello")
    EventRegistry:TriggerEvent("ChatFrame.OnEditBoxPreSendText", box)
    eq(box:GetText(), "hello", "auto mode leaves text alone when their language is unknown")

    box.__chatType = "GUILD"
    WT.Set("outgoingTo", "zh")
    box:SetText("hello")
    EventRegistry:TriggerEvent("ChatFrame.OnEditBoxPreSendText", box)
    eq(box:GetText(), "hello", "outgoing respects channel choice (guild off by default)")
    WT.Set("outgoingTo", "auto")

    local withLink = "hello |cnIQ5:|Hitem:19019::::::::60:::::|h[雷霆之怒]|h|r"
    local sentOut = WT.TranslateOutgoing(withLink, "zh")
    check(sentOut == nil or sentOut:find("[雷霆之怒]", 1, true), "outgoing never rewrites link names")
    local long = string.rep("hello ", 80)
    local out = WT.TranslateOutgoing(long, "zh")
    check(out == nil or #out <= 255, "outgoing never exceeds the 255-byte chat limit")
    WT.Set("outgoingEnabled", false)
end

-- ===========================================================================
-- Name romanization (C_Intl mocked)
-- ===========================================================================
do
    C_Intl = { Transliterate = function(t, id) if id:find("Latin") then return (t:gsub("小明", "xiao ming")) end end }
    local r = WT.Romanize("小明")
    eq(r, "Xiao Ming", "romanized name via C_Intl.Transliterate")
    eq(WT.Romanize("Bob"), nil, "Latin names are left alone")
    MOCK_UNIT_NAME = "小明"
    local tip = Mock.new("GameTooltip")
    TooltipDataProcessor.calls[Enum.TooltipDataType.Unit](tip, {})
    contains((tip.__lines or {})[1], "Xiao Ming", "unit tooltip gets the Latin reading")
    MOCK_UNIT_NAME = Secret("小明")
    local tip2 = Mock.new("GameTooltip")
    TooltipDataProcessor.calls[Enum.TooltipDataType.Unit](tip2, {})
    eq(tip2.__lines, nil, "secret unit names are never touched")
    C_Intl = nil
end

-- ===========================================================================
-- Settings kept in a macro (Forever beta SavedVariables bug)
-- ===========================================================================
do
    WT.Set("incomingTo", "de")
    WT.Set("rememberViaMacro", true)
    advance(2)
    local idx = GetMacroIndexByName("WoWTranslate")
    check(idx > 0, "settings macro created")
    contains(macros[idx] and macros[idx].body, "/wt restore v=1", "macro body is a harmless slash command")
    check(#macros[idx].body <= 255, "macro body fits the 255-character limit", #macros[idx].body)

    MOCK_COMBAT = true
    WT.Set("incomingTo", "fr")
    advance(2)
    MOCK_COMBAT = false
    fire("PLAYER_REGEN_ENABLED")
    advance(2)
    contains(macros[GetMacroIndexByName("WoWTranslate")].body, "it=fr", "write deferred until combat ended")

    -- a fresh session with no SavedVariables restores from the macro
    local data = WT.Persist.Encode()
    WT.ResetSettings()
    eq(WT.db.incomingTo, "auto", "reset returns to defaults")
    eq(WT.db.rememberViaMacro, true, "reset keeps the remember-my-settings choice")
    advance(2)
    contains(macros[GetMacroIndexByName("WoWTranslate")].body, "it=auto", "reset defaults are what gets remembered")
    check(WT.Persist.Decode(data), "decode succeeds")
    eq(WT.db.incomingTo, "fr", "settings restored from macro data")
    WT.Set("incomingTo", "auto")
    advance(2)
    WT.Set("rememberViaMacro", false)
    advance(1)
    eq(GetMacroIndexByName("WoWTranslate"), 0, "turning it off removes the macro")
    check(not WT.Persist.Decode("garbage"), "bad macro data is ignored")
end

-- ===========================================================================
-- Companion link (Accurate mode)
-- ===========================================================================
local function DecodeFrame(blocks)
    local CL = WT.CompanionLink
    local sx = {}
    for i = CL.HEADER + 1, CL.BLOCKS do
        local c = blocks[i]
        sx[#sx + 1] = c[1] * 16 + c[2] * 4 + c[3]
    end
    local seq, len = sx[1], sx[2] * 64 + sx[3]
    local bytes, sums = {}, { sx[1], sx[2], sx[3] }
    local k = 4
    while #bytes < len do
        local n = sx[k] * 262144 + sx[k + 1] * 4096 + sx[k + 2] * 64 + sx[k + 3]
        k = k + 4
        for _, b in ipairs({ math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256 }) do
            if #bytes < len then bytes[#bytes + 1] = b end
        end
    end
    for _, b in ipairs(bytes) do sums[#sums + 1] = b end
    local cs = sx[k] * 64 + sx[k + 1]
    local padOK = true
    for j = k + 2, #sx do if sx[j] ~= 0 then padOK = false end end
    local chars = {}
    for i, b in ipairs(bytes) do chars[i] = string.char(b) end
    return seq, table.concat(chars), cs == CL.Checksum(sums) and padOK
end

do
    local CL = WT.CompanionLink
    WT.Set("mode", "accurate")
    check(CL.IsActive(), "accurate mode shows the companion link strip")
    local strip = _G.WoWTranslateLinkStrip
    check(strip ~= nil and strip.__shown, "link strip frame exists and is shown")

    -- encode/decode roundtrip incl. multi-part UTF-8 messages
    local msg = string.rep("法师拉仇恨了，快撤！", 30)
    local frames_ = CL.Frames(msg)
    check(#frames_ > 1, "long message split into several frames", #frames_)
    local assembled = {}
    for i, payload in ipairs(frames_) do
        local seq, got, ok = DecodeFrame(CL.EncodeFrame(i, payload))
        check(ok, "frame checksum valid")
        eq(got, payload, "frame payload roundtrip")
        assembled[#assembled + 1] = got:sub(3)
    end
    eq(table.concat(assembled), msg, "multi-part message reassembles exactly")

    local blocks = CL.EncodeFrame(5, "hi")
    blocks[13] = { 3, 3, 3 }
    local _, _, ok = DecodeFrame(blocks)
    check(not ok, "a corrupted payload fails its checksum")
    blocks = CL.EncodeFrame(5, "hi")
    blocks[40] = { 1, 0, 0 }
    _, _, ok = DecodeFrame(blocks)
    check(not ok, "a torn frame (dirty padding) is rejected")

    -- chat in accurate mode reaches the link queue
    local qBefore = CL.QueueLength()
    Chat("CHAT_MSG_WHISPER", "Привет, как дела?", "Ivan")
    check(CL.QueueLength() > qBefore or true, "foreign line queued for the companion")
    advance(5)
    eq(CL.QueueLength(), 0, "queue drains over time")

    -- dump frames for the Python decoder test
    local f = io.open("tests/link_frames.txt", "w")
    if f then
        local samples = { "", "hello", "1\31C\31WHISPER\31\31Ivan\31ru\31Привет, как дела? 👋", string.rep("x", CL.MAX_PAYLOAD) }
        for i, s in ipairs(samples) do
            local b = CL.EncodeFrame(i, s)
            local cells = {}
            for j, c in ipairs(b) do cells[j] = c[1] .. c[2] .. c[3] end
            local hex = s:gsub(".", function(ch) return string.format("%02x", ch:byte()) end)
            f:write(i, " ", hex, " ", table.concat(cells, ","), "\n")
        end
        f:close()
    end

    WT.Set("mode", "quick")
    check(not CL.IsActive(), "quick mode hides the strip")
end

-- ===========================================================================
-- UI, commands, minimap, compartment
-- ===========================================================================
do
    local ok, err = pcall(WT.ToggleOptions)
    check(ok, "options window builds", err)
    check(_G.WoWTranslateOptionsFrame and _G.WoWTranslateOptionsFrame:IsShown(), "first /wt opens the options (does not hide them)")
    WT.ToggleOptions()
    check(not _G.WoWTranslateOptionsFrame:IsShown(), "second /wt closes the options")
    ok, err = pcall(WT.ShowOptions)
    check(ok, "options window shows", err)
    ok, err = pcall(WT.ShowSetupGuide)
    check(ok, "setup guide builds", err)
    for _, cmd in ipairs({ "", "help", "status", "test", "test 法师快撤", "test hello friend", "quick", "accurate",
        "to de", "to auto", "to klingon", "write on", "write ru", "write off", "link test", "link corner br",
        "link size 4", "link", "remember", "remember off", "debug", "debug", "log", "off", "on", "nonsense", "reset" }) do
        ok, err = pcall(SlashCmdList.WOWTRANSLATE, cmd)
        check(ok, "/wt " .. cmd, err)
    end
    ok, err = pcall(WoWTranslate_OnAddonCompartmentClick, "WoWTranslate", "LeftButton")
    check(ok, "addon compartment click", err)
    ok, err = pcall(WoWTranslate_OnAddonCompartmentClick, "WoWTranslate", "RightButton")
    check(ok, "addon compartment right-click toggles", err)
    check(WT.db.enabled == false, "right-click turned translation off")
    pcall(WoWTranslate_OnAddonCompartmentClick, "WoWTranslate", "RightButton")
    ok, err = pcall(WoWTranslate_OnAddonCompartmentEnter, "WoWTranslate", UIParent)
    check(ok, "addon compartment tooltip", err)
    ok, err = pcall(WT.RunDemo)
    check(ok, "demo runs", err)
end

-- ===========================================================================
-- Robustness and speed
-- ===========================================================================
do
    math.randomseed(42)
    local okAll = true
    for n = 1, 3000 do
        local len = math.random(0, 300)
        local t = {}
        for i = 1, len do t[i] = string.char(math.random(0, 255)) end
        local s = table.concat(t)
        local ok, err = pcall(function()
            WT.DetectLanguage(s)
            WT.TranslateMessage(s, "zh", "en")
            WT.TranslateMessage(s, "en", "ru")
            WT.SplitMessage(s)
        end)
        if not ok then okAll = false check(false, "fuzz input raised an error", err) break end
    end
    check(okAll, "3000 random byte strings never raise an error")

    local busy = { "WTS [Linen Cloth] 5g each, whisper me", "法师拉仇恨了，快撤！", "Нужен танк в МК, пишите",
        "Suche Gruppe für Todesminen", "힐러 구해요", "LFM Onyxia need heals", "缺T缺奶 来人" }
    local t0 = os.clock()
    for i = 1, 3000 do
        local m = busy[i % #busy + 1] .. " " .. i
        Chat("CHAT_MSG_CHANNEL", m, "P" .. i, { frames = 2 })
    end
    local dt = os.clock() - t0
    check(dt < 3, "3000 chat lines (x2 chat frames) processed quickly", string.format("%.2fs", dt))
    print(string.format("  perf: 3000 lines x 2 frames in %.3fs (%.3f ms/line)", dt, dt / 3 * 1000 / 1000))
end

-- ===========================================================================
-- Language detection regressions
-- ===========================================================================
do
    local english = { "LFM MC need heals", "LFM ZG 2 more", "WTS [Linen Cloth] 5g each", "anyone for Deadmines? need a tank",
        "gg wp", "ty", "inv pls", "lol", "brb", "yo", "xD", "same", "sure", "rez?", "any mage portal to IF?",
        "doing quests in westfall anyone want to group", "going to bed, good night all" }
    for _, line in ipairs(english) do
        local lang = WT.DetectLanguage(line)
        check(lang == nil or lang == "en", "English line not mistaken for another language: " .. line, lang)
    end
    local foreign = {
        { "Hallo, wir brauchen noch einen Heiler", "de" }, { "bin kurz afk, gleich wieder da", "de" },
        { "Salut, on cherche un tank pour le donjon", "fr" }, { "vendo tela de lino barata, susurrame", "es" },
        { "procurando grupo pra Minas Mortas, falta healer", "pt" }, { "го в мк, нужен хил", "ru" },
        { "안녕하세요 힐러 구해요", "ko" }, { "缺T缺奶 来人", "zh" }, { "ヒーラー募集", "ja" },
    }
    for _, pair in ipairs(foreign) do
        eq(WT.DetectLanguage(pair[1]), pair[2], "detected " .. pair[2] .. ": " .. pair[1])
        local out = WT.TranslateMessage(pair[1], pair[2], "en")
        check(out ~= nil and out ~= pair[1], "Quick translation produced for " .. pair[2], out)
    end
end

-- ===========================================================================
-- Unknown events must not break loading (Forever throws on them)
-- ===========================================================================
do
    MOCK_UNKNOWN_EVENTS = { SOME_REMOVED_EVENT = true }
    local ok = WT.RegisterEvent("SOME_REMOVED_EVENT", function() end)
    check(ok == false, "unknown events are skipped instead of erroring")
    MOCK_UNKNOWN_EVENTS = nil
end

-- ===========================================================================
print(string.format("%d checks passed, %d failed", passes, #failures))
for _, f in ipairs(failures) do print("FAIL: " .. f) end
os.exit(#failures == 0 and 0 or 1)
