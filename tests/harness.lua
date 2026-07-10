-- WoWTranslate offline regression harness
-- Loads the REAL addon files under a mocked WoW 1.12 client and storms the
-- chat pipeline with hostile input. Run:  lua tests/harness.lua
-- Exit code 0 = all assertions passed. Any Lua error, forbidden client call,
-- lost/duplicated message, or corrupted hyperlink fails the run.

local ADDON_DIR = arg and arg[1] or "Interface/AddOns/WoWTranslate"

-- ===========================================================================
-- Lua 5.0/5.1 compatibility shims (addon targets vanilla's Lua 5.0)
-- ===========================================================================
unpack = unpack or table.unpack  -- global: the addon's own 5.0 fallbacks use it
table.getn = table.getn or function(t) return #t end
table.setn = table.setn or function() end
string.gfind = string.gfind or string.gmatch
math.mod = math.mod or function(a, b) return a % b end
string.len = string.len or function(s) return #s end

local G = _G
function getglobal(n) return G[n] end
function setglobal(n, v) G[n] = v end
function strsplit(sep, s, limit)
    local out, pos = {}, 1
    while true do
        if limit and #out == limit - 1 then table.insert(out, string.sub(s, pos)) break end
        local a, b = string.find(s, sep, pos, true)
        if not a then table.insert(out, string.sub(s, pos)) break end
        table.insert(out, string.sub(s, pos, a - 1))
        pos = b + 1
    end
    return unpack(out)
end

-- ===========================================================================
-- Failure accounting
-- ===========================================================================
local failures, checks = {}, 0
local function fail(fmt, ...) table.insert(failures, string.format(fmt, ...)) end
local function ok() checks = checks + 1 end
local function guard(what, fn, ...)
    local res = { xpcall(fn, function(e) return debug.traceback(tostring(e), 2) end, ...) }
    if not res[1] then fail("LUA ERROR in %s:\n%s", what, res[2]) return nil end
    ok()
    return unpack(res, 2)
end

-- ===========================================================================
-- Mock WoW client
-- ===========================================================================
local now = 1000.0
function GetTime() return now end

local FORBIDDEN = { SetHyperlink = 0 }

local frames = {}
local function NewFrame(ftype, name)
    local f = {
        __name = name or "anon", __type = ftype or "Frame",
        __scripts = {}, __events = {}, __shown = false, __lines = {},
    }
    function f:RegisterEvent(e) self.__events[e] = true end
    function f:UnregisterEvent(e) self.__events[e] = nil end
    function f:SetScript(h, fn) self.__scripts[h] = fn end
    function f:GetScript(h) return self.__scripts[h] end
    function f:Show() self.__shown = true end
    function f:Hide() self.__shown = false end
    function f:IsVisible() return self.__shown end
    function f:SetOwner() self.__shown = true end
    function f:SetText(t) self.__lines = { t } end
    function f:AddLine(t) table.insert(self.__lines, t) end
    function f:NumLines() return #self.__lines end
    function f:SetHyperlink(link)
        FORBIDDEN.SetHyperlink = FORBIDDEN.SetHyperlink + 1
        fail("FORBIDDEN CALL: %s:SetHyperlink(%q) — crashes 1.12 on uncached items\n%s",
            self.__name, tostring(link), debug.traceback("", 2))
    end
    -- inert widget methods the addon may touch
    for _, m in ipairs({ "SetWidth", "SetHeight", "SetPoint", "SetAllPoints",
        "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "EnableMouse",
        "SetMovable", "RegisterForDrag", "SetClampedToScreen", "SetNormalTexture",
        "SetPushedTexture", "SetHighlightTexture", "SetFrameStrata", "SetFrameLevel",
        "SetAlpha", "GetWidth", "GetHeight", "SetFontObject", "SetJustifyH",
        "SetTextColor", "GetText", "SetID", "SetChecked", "GetChecked", "ClearAllPoints" }) do
        f[m] = f[m] or function() end
    end
    function f:CreateFontString() return NewFrame("FontString") end
    function f:CreateTexture() return NewFrame("Texture") end
    table.insert(frames, f)
    return f
end

function CreateFrame(ftype, name, parent, template)
    local f = NewFrame(ftype, name)
    if name then G[name] = f end
    return f
end

UIParent, WorldFrame, Minimap = NewFrame("Frame", "UIParent"), NewFrame("Frame", "WorldFrame"), NewFrame("Frame", "Minimap")

-- GameTooltip needs realistic line/fontstring/OnShow semantics for the
-- name-tooltip module: lines are mirrored into GameTooltipTextLeftN globals,
-- Show() fires OnShow on the hidden->shown edge, Hide() fires OnHide.
GameTooltip = NewFrame("GameTooltip", "GameTooltip")
local function TooltipFS(i)
    local n = "GameTooltipTextLeft" .. i
    if not G[n] then
        G[n] = { __text = nil,
            GetText = function(self) return self.__text end,
            SetText = function(self, t) self.__text = t; GameTooltip.__lines[i] = t end,
            SetTextColor = function() end }
    end
    return G[n]
end
local function TooltipSync()
    for i = 1, 30 do
        local fs = TooltipFS(i)
        fs.__text = GameTooltip.__lines[i]
    end
end
function GameTooltip:Show()
    local was = self.__shown
    self.__shown = true
    TooltipSync()
    if not was and self.__scripts.OnShow then
        G.this = self
        guard("GameTooltip:OnShow", self.__scripts.OnShow)
    end
end
function GameTooltip:Hide()
    local was = self.__shown
    self.__shown = false
    self.__lines = {}
    TooltipSync()
    if was and self.__scripts.OnHide then
        G.this = self
        guard("GameTooltip:OnHide", self.__scripts.OnHide)
    end
end
function GameTooltip:SetText(t) self.__lines = { t }; TooltipSync(); self:Show() end
function GameTooltip:AddLine(t) table.insert(self.__lines, t); TooltipSync() end
function GameTooltip:NumLines() return #self.__lines end
function GameTooltip:SetUnit(unit)
    self.__lines = { UnitName(unit) or "Unknown" }
    TooltipSync()
    self:Show()
end

-- Chat frames: each records displayed messages (these ARE the "originals"
-- that the addon wraps, so whatever lands here is what the player sees).
NUM_CHAT_WINDOWS = 7
local displayed = {}
for i = 1, NUM_CHAT_WINDOWS do
    local cf = NewFrame("MessageFrame", "ChatFrame" .. i)
    cf.AddMessage = function(self, text, r, g, b, id, holdTime)
        table.insert(displayed, { frame = self.__name, text = text })
    end
    G["ChatFrame" .. i] = cf
end
DEFAULT_CHAT_FRAME = ChatFrame1

function ChatFrame_OnEvent(event) end
function SendChatMessage(msg, chatType, lang, target) G.__lastSent = { msg = msg, chatType = chatType, target = target } end
G.__ORIG_SEND = SendChatMessage
function UnitIsAFK() return nil end
function UnitExists(u) return G.__mockUnits and G.__mockUnits[u] and 1 or nil end
function UnitIsPlayer(u) return G.__mockUnits and G.__mockUnits[u] and G.__mockUnits[u].player and 1 or nil end
function UnitName(u) return G.__mockUnits and G.__mockUnits[u] and G.__mockUnits[u].name or nil end
function GetCursorPosition() return 0, 0 end
function PlaySound() end
SlashCmdList = {}

-- Item cache mock: only these IDs are "locally cached"
local CACHED_ITEMS = { [929] = "Healing Potion", [2589] = "Linen Cloth", [19019] = "Thunderfury" }
function GetItemInfo(id)
    id = tonumber(id)
    if id and CACHED_ITEMS[id] then return CACHED_ITEMS[id], "|cffffffff|Hitem:" .. id .. ":0:0:0|h[" .. CACHED_ITEMS[id] .. "]|h|r" end
    return nil
end

-- Mock DLL bridge: async queue answered via poll, deterministic "translation"
local dllQueue, dllCounter = {}, 0
local json_escape = function(s) return (string.gsub(s, '[\\"]', function(c) return "\\" .. c end)) end
function UnitXP(sentinel, cmd, a, b, c, d)
    if sentinel ~= "WoWTranslate" then return nil end
    if cmd == "ping" then return "pong" end
    if cmd == "version" then return "harness" end
    if cmd == "provider_status" then return '{"provider":"google","configured":true,"ready":true,"endpoint":"mock"}' end
    if cmd == "last_error" then return "" end
    if cmd == "configure_google" then return "ok" end
    if cmd == "configure_google_free" then G.__configuredFree = true; return "ok" end
    if cmd == "translate_async" then
        table.insert(dllQueue, { id = a, text = b })
        G.__tCalls = G.__tCalls or {}
        G.__tCalls[b] = (G.__tCalls[b] or 0) + 1
        return "queued|" .. a
    end
    if cmd == "poll" then
        local req = table.remove(dllQueue, 1)
        if not req then return "" end
        return '{"id":"' .. req.id .. '","success":true,"translation":"[T]' .. json_escape(req.text) .. '"}'
    end
    return "error|unknown"
end
G.__dllFlush = function() dllQueue = {} end

-- Event dispatch (vanilla-style globals: this/event/arg1..)
local function FireEvent(name, a1, a2)
    for _, f in ipairs(frames) do
        if f.__events[name] and f.__scripts.OnEvent then
            G.this, G.event, G.arg1, G.arg2 = f, name, a1, a2
            guard("OnEvent:" .. name, f.__scripts.OnEvent)
        end
    end
end
local function Tick(dt)
    now = now + dt
    for _, f in ipairs(frames) do
        if f.__scripts.OnUpdate then
            G.this, G.arg1 = f, dt
            guard("OnUpdate:" .. f.__name, f.__scripts.OnUpdate)
        end
    end
end

-- ===========================================================================
-- Load the REAL addon files (same order as the .toc, minus pure-UI modules)
-- ===========================================================================
WoWTranslateDB, WoWTranslateCache, WoWTranslateDebugLog = nil, nil, nil
for _, file in ipairs({ "WoWTranslate_Glossary.lua", "WoWTranslate_Cache.lua",
                        "WoWTranslate_API.lua", "WoWTranslate.lua",
                        "WoWTranslate_NameTooltip.lua" }) do
    local chunk, err = loadfile(ADDON_DIR .. "/" .. file)
    if not chunk then fail("cannot load %s: %s", file, err) print(table.concat(failures, "\n")) os.exit(1) end
    guard("load:" .. file, chunk)
end

FireEvent("ADDON_LOADED", "WoWTranslate")
FireEvent("PLAYER_LOGIN")
WoWTranslateDB.debugMode = false

-- ===========================================================================
-- The storm
-- ===========================================================================
local CJK = "\228\189\160\229\165\189\228\184\150\231\149\140"          -- 你好世界
local CJK2 = "\230\136\145\230\152\175\230\179\149\229\184\136"          -- 我是法师
local LINK_CACHED = "|cffffffff|Hitem:929:0:0:0|h[" .. CJK2 .. "]|h|r"
local LINK_UNCACHED = "|cffa335ee|Hitem:55555:0:0:0|h[" .. CJK .. "]|h|r"  -- custom out-of-range item ID
local LINK_HUGE_ID = "|cffa335ee|Hitem:4294967295:0:0:0|h[x]|h|r"
local LINK_ENCHANT = "|cffffd000|Henchant:20034|h[" .. CJK .. "]|h|r"
local LINK_PLAYER = "|Hplayer:" .. CJK2 .. "|h[" .. CJK2 .. "]|h"

local cases = {
    CJK,
    CJK .. " hello mixed " .. CJK2,
    CJK .. " " .. LINK_CACHED,
    CJK .. " " .. LINK_UNCACHED,                          -- the killer case
    LINK_UNCACHED .. LINK_UNCACHED .. " " .. CJK,
    CJK .. LINK_HUGE_ID,
    CJK .. " " .. LINK_ENCHANT,
    LINK_PLAYER .. ": " .. CJK,
    "|Hitem:929" .. CJK,                                   -- unterminated link
    "|H|h|h" .. CJK,                                       -- degenerate link
    CJK .. "|cffff0000" .. CJK2,                           -- color code, no terminator
    string.rep(CJK, 120),                                  -- ~1.4KB message
    CJK .. string.char(228),                               -- truncated UTF-8 tail
    string.char(200, 201) .. CJK,                          -- GBK-ish garbage prefix
}

-- Track every input: tag → {links to preserve, malformed input?}
local inputs = {}
local function ExtractLinks(msg)
    local links, pos = {}, 1
    while true do
        local s = string.find(msg, "|H", pos, true)
        if not s then break end
        local e = string.find(msg, "|h|r", s, true) or string.find(msg, "|h", s + 2, true)
        if not e then return links, true end               -- dangling |H → malformed
        pos = e + 2
        table.insert(links, string.sub(msg, s, pos - 1))
    end
    return links, false
end

for round = 1, 50 do
    for ci, msg in ipairs(cases) do
        local frame = G["ChatFrame" .. (math.mod(round, 2) == 0 and 2 or 1)]
        local tag = "#" .. round .. "-" .. ci              -- unique per message
        local unique = msg .. " " .. tag                   -- also defeats the cache
        local links, malformed = ExtractLinks(msg)
        inputs[tag] = { links = links, malformed = malformed, count = 0 }
        guard("AddMessage", frame.AddMessage, frame, unique, 1, 1, 1)
        if math.mod(round, 3) == 0 then Tick(0.05) end     -- interleave timers
    end
end

-- Drain: enough poll ticks to deliver every queued result (1 per 0.1s tick),
-- then cleanup timers well past every timeout
for i = 1, 800 do Tick(0.11) end
for i = 1, 12 do Tick(5.0) end

-- Non-Chinese and pass-through sanity
guard("AddMessage", ChatFrame1.AddMessage, ChatFrame1, "plain english message", 1, 1, 1)
guard("AddMessage", ChatFrame1.AddMessage, ChatFrame1, nil, 1, 1, 1)  -- nil text must not error

-- ===========================================================================
-- Assertions
-- ===========================================================================
-- Match every displayed message back to its input tag; each input must be
-- displayed EXACTLY once, with well-formed input links preserved byte-for-byte.
for _, d in ipairs(displayed) do
    if d.text then
        local _, _, tag = string.find(d.text, "(#%d+-%d+)")
        local rec = tag and inputs[tag]
        if rec then
            rec.count = rec.count + 1
            if not rec.malformed then
                for _, link in ipairs(rec.links) do
                    -- The href (|Htype:data|h) must survive byte-for-byte so
                    -- clicks resolve to the same target; the [display text]
                    -- may legitimately be localized for cached items.
                    local hrefEnd = string.find(link, "|h", 3, true)
                    local href = hrefEnd and string.sub(link, 1, hrefEnd + 1) or link
                    if not string.find(d.text, href, 1, true) then
                        fail("HREF LOST/ALTERED for %s:\n  expected substring: %s\n  displayed: %s",
                            tag, href, string.sub(d.text, 1, 160))
                    end
                end
            end
        end
    end
end
for tag, rec in pairs(inputs) do
    if rec.count == 0 then fail("MESSAGE LOST: %s never displayed", tag) end
    if rec.count > 1 then fail("MESSAGE DUPLICATED: %s displayed %d times", tag, rec.count) end
end

-- pending queues must be fully drained
local pendCount = 0
if WoWTranslate_API and WoWTranslate_API.GetPendingCount then pendCount = WoWTranslate_API.GetPendingCount() end
if pendCount ~= 0 then fail("API pending queue not drained: %d left", pendCount) end

-- ===========================================================================
-- Name-tooltip module scenarios
-- ===========================================================================
G.__dllFlush()  -- drop any stale storm results so scenario polls are exact
local MARK = "\194\187 "  -- "» "
local PENDING = MARK .. "translating..."
local CJK3 = "\230\173\166\229\131\167"  -- 武僧
local CJK4 = "\229\176\143\233\190\153"  -- 小龙
local tC = function(n) return (G.__tCalls or {})[n] or 0 end
local function markerLines()
    local n = 0
    for i = 2, GameTooltip:NumLines() do
        local t = GameTooltip.__lines[i]
        if t and string.find(t, "^" .. MARK) then n = n + 1 end
    end
    return n
end

-- A) world mouseover: engine tooltip -> OnShow -> pending -> async fill
G.__mockUnits = { mouseover = { name = CJK, player = true } }
GameTooltip:Hide()
guard("tooltip:world-hover", function() GameTooltip:SetText(CJK) end)
if GameTooltip.__lines[2] ~= PENDING then fail("A: pending line missing, got %s", tostring(GameTooltip.__lines[2])) end
Tick(0.11); Tick(0.11)
if GameTooltip.__lines[2] ~= MARK .. "[T]" .. CJK then fail("A: async fill missing, got %s", tostring(GameTooltip.__lines[2])) end
if tC(CJK) ~= 1 then fail("A: expected 1 translate call for name, got %d", tC(CJK)) end

-- B) dedupe: SetUnit path AND mouseover pointing at the same unit
GameTooltip:Hide()
G.__mockUnits = { mouseover = { name = CJK2, player = true }, target = { name = CJK2, player = true } }
guard("tooltip:setunit", function() GameTooltip:SetUnit("target") end)
Tick(0.11); Tick(0.11)
if markerLines() ~= 1 then fail("B: dedupe failed — %d marker lines", markerLines()) end
if tC(CJK2) ~= 1 then fail("B: expected 1 translate call, got %d", tC(CJK2)) end

-- C) cache hit on re-hover: instant line, no new API call
GameTooltip:Hide()
G.__mockUnits = { mouseover = { name = CJK, player = true } }
guard("tooltip:rehover", function() GameTooltip:SetText(CJK) end)
if GameTooltip.__lines[2] ~= MARK .. "[T]" .. CJK then fail("C: cache-hit line missing, got %s", tostring(GameTooltip.__lines[2])) end
if tC(CJK) ~= 1 then fail("C: cache miss — %d translate calls", tC(CJK)) end

-- D) stale async result dropped when tooltip closed, still cached for later
GameTooltip:Hide()
G.__mockUnits = { mouseover = { name = CJK3, player = true } }
guard("tooltip:stale-open", function() GameTooltip:SetText(CJK3) end)
GameTooltip:Hide()                       -- close before the result lands
Tick(0.11); Tick(0.11)                   -- result arrives, must be dropped
if GameTooltip:NumLines() > 0 then fail("D: stale result mutated a closed tooltip") end
guard("tooltip:stale-rehover", function() GameTooltip:SetText(CJK3) end)
if GameTooltip.__lines[2] ~= MARK .. "[T]" .. CJK3 then fail("D: result not cached after stale drop") end
if tC(CJK3) ~= 1 then fail("D: expected 1 translate call, got %d", tC(CJK3)) end

-- E) chat player-link hover + leave
GameTooltip:Hide()
G.__mockUnits = {}
G.this, G.arg1 = ChatFrame1, "player:" .. CJK4
guard("tooltip:linkenter", ChatFrame1:GetScript("OnHyperlinkEnter"))
Tick(0.11); Tick(0.11)
if GameTooltip.__lines[1] ~= CJK4 then fail("E: link tooltip line1 wrong: %s", tostring(GameTooltip.__lines[1])) end
if GameTooltip.__lines[2] ~= MARK .. "[T]" .. CJK4 then fail("E: link translation missing, got %s", tostring(GameTooltip.__lines[2])) end
G.this = ChatFrame1
guard("tooltip:linkleave", ChatFrame1:GetScript("OnHyperlinkLeave"))
if GameTooltip:IsVisible() then fail("E: tooltip not hidden on link leave") end

-- F) safety: non-CJK and NPC names add nothing; action APIs untouched
GameTooltip:Hide()
G.__mockUnits = { mouseover = { name = "Bobthemage", player = true } }
guard("tooltip:english", function() GameTooltip:SetText("Bobthemage") end)
if GameTooltip:NumLines() > 1 then fail("F: line added for non-CJK name") end
GameTooltip:Hide()
G.__mockUnits = { mouseover = { name = CJK4 .. "NPC", player = false } }
guard("tooltip:npc", function() GameTooltip:SetText(CJK4 .. "NPC") end)
if markerLines() > 0 then fail("F: line added for NPC unit") end
if SendChatMessage ~= G.__ORIG_SEND then fail("F: SendChatMessage was replaced — whisper safety violated") end

-- G) provider switching: google_free (incl. alias), then back
guard("slash:google_free", function() SlashCmdList["WOWTRANSLATE"]("provider free") end)
if WoWTranslateDB.provider ~= "google_free" then fail("G: alias 'free' not normalized, got %s", tostring(WoWTranslateDB.provider)) end
if not G.__configuredFree then fail("G: configure_google_free never reached the DLL bridge") end
guard("slash:google", function() SlashCmdList["WOWTRANSLATE"]("provider google") end)
if WoWTranslateDB.provider ~= "google" then fail("G: switch back to google failed") end

-- ===========================================================================
-- Verdict
-- ===========================================================================
print(string.format("checks passed: %d | messages displayed: %d | SetHyperlink calls: %d",
    checks, #displayed, FORBIDDEN.SetHyperlink))
if #failures > 0 then
    print("\n=== FAILURES (" .. #failures .. ") ===")
    for i, f in ipairs(failures) do print(i .. ") " .. f .. "\n") end
    os.exit(1)
end
print("ALL GREEN")
os.exit(0)
