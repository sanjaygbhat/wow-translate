-- WoWTranslate offline regression harness
-- Loads the REAL addon files under a mocked WoW 1.12 client and storms the
-- chat pipeline with hostile input. Run:  lua tests/harness.lua
-- Exit code 0 = all assertions passed. Any Lua error, forbidden client call,
-- lost/duplicated message, or corrupted hyperlink fails the run.

local ADDON_DIR = arg and arg[1] or "Interface/AddOns/WoWTranslate"

-- ===========================================================================
-- Lua 5.0/5.1 compatibility shims (addon targets vanilla's Lua 5.0)
-- ===========================================================================
local unpack = unpack or table.unpack
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
GameTooltip = NewFrame("GameTooltip", "GameTooltip")

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
    if cmd == "translate_async" then
        table.insert(dllQueue, { id = a, text = b })
        return "queued|" .. a
    end
    if cmd == "poll" then
        local req = table.remove(dllQueue, 1)
        if not req then return "" end
        return '{"id":"' .. req.id .. '","success":true,"translation":"[T]' .. json_escape(req.text) .. '"}'
    end
    return "error|unknown"
end

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
                        "WoWTranslate_API.lua", "WoWTranslate.lua" }) do
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
local LINK_UNCACHED = "|cffa335ee|Hitem:55555:0:0:0|h[" .. CJK .. "]|h|r"  -- custom Turtle-style ID
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

-- Drain: async poll ticks + cleanup timers well past every timeout
for i = 1, 200 do Tick(0.11) end
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
