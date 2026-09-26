-- WoW Translate: companion link (Accurate mode)
--
-- Addons cannot use the internet, so paid translation services cannot be
-- called from inside the game. In Accurate mode the addon shows foreign chat
-- lines to the WoW Translate Companion app as a thin strip of coloured
-- squares in a corner of the screen. The app reads those pixels from the
-- screen (like any screen recorder), translates with the service the player
-- chose, and shows the result in its own small window.
--
-- The app never reads game memory, never injects anything, and never
-- presses keys. The addon only draws textures.
--
-- Wire format "WTL1" (one row of BLOCKS squares):
--   blocks 1-4   sync: magenta, green, magenta, cyan
--   blocks 5-8   calibration greys at levels 0,1,2,3
--   blocks 9..   data: each square carries 6 bits (2 bits per colour channel,
--                levels 0/85/170/255): seq, length (2 sextets), payload
--                bytes packed 3 -> 4 sextets, then a 12-bit checksum.
-- Every payload starts with a message id byte and a part byte
-- (partIndex * 16 + partCount) so long messages can span several frames.

local _, WT = ...
local L = WT.L

local floor = math.floor
local byte, sub, char = string.byte, string.sub, string.char
local concat = table.concat

local CL = {}
WT.CompanionLink = CL

local BLOCKS = 200
local HEADER = 8
local DATA = BLOCKS - HEADER                         -- 192 sextets
local MAX_PAYLOAD = floor((DATA - 3 - 2) / 4) * 3   -- 138 bytes per frame
local CHUNK = MAX_PAYLOAD - 2                        -- 136 message bytes per frame
local MAX_PARTS = 15
local MAX_QUEUE = 90                                 -- frames; older ones drop first
local SEP = "\31"
local PROTOCOL = "1"

CL.BLOCKS, CL.HEADER, CL.MAX_PAYLOAD, CL.CHUNK = BLOCKS, HEADER, MAX_PAYLOAD, CHUNK

local SYNC = { { 3, 0, 3 }, { 0, 3, 0 }, { 3, 0, 3 }, { 0, 3, 3 } }

-- ---------------------------------------------------------------------------
-- Encoding (pure functions; the test suite runs these outside the game)
-- ---------------------------------------------------------------------------
function CL.Checksum(values)
    local s = 0
    for i = 1, #values do
        s = (s * 257 + values[i] + 1) % 4093
    end
    return s
end

-- Returns an array of BLOCKS colour levels { r, g, b } with values 0..3.
function CL.EncodeFrame(seq, payload)
    payload = payload or ""
    assert(#payload <= MAX_PAYLOAD, "payload too large")
    local blocks = {}
    for i = 1, 4 do blocks[i] = SYNC[i] end
    for i = 0, 3 do blocks[5 + i] = { i, i, i } end

    local sx = {}
    local len = #payload
    seq = seq % 64
    sx[1], sx[2], sx[3] = seq, floor(len / 64), len % 64
    local sums = { sx[1], sx[2], sx[3] }
    for j = 1, len, 3 do
        local b1, b2, b3 = byte(payload, j), byte(payload, j + 1) or 0, byte(payload, j + 2) or 0
        local n = b1 * 65536 + b2 * 256 + b3
        sx[#sx + 1] = floor(n / 262144) % 64
        sx[#sx + 1] = floor(n / 4096) % 64
        sx[#sx + 1] = floor(n / 64) % 64
        sx[#sx + 1] = n % 64
    end
    for j = 1, len do sums[#sums + 1] = byte(payload, j) end
    local cs = CL.Checksum(sums)
    sx[#sx + 1] = floor(cs / 64)
    sx[#sx + 1] = cs % 64
    for k = #sx + 1, DATA do sx[k] = 0 end

    for k = 1, DATA do
        local v = sx[k]
        blocks[HEADER + k] = { floor(v / 16), floor(v / 4) % 4, v % 4 }
    end
    return blocks
end

-- Split one message into frame payloads.
local nextMsgId = 0
function CL.Frames(message)
    local maxBytes = CHUNK * MAX_PARTS
    if #message > maxBytes then message = WT.Text.truncate(message, maxBytes) end
    local parts = math.max(1, math.ceil(#message / CHUNK))
    nextMsgId = (nextMsgId + 1) % 256
    local out = {}
    for p = 0, parts - 1 do
        local chunk = sub(message, p * CHUNK + 1, (p + 1) * CHUNK)
        out[#out + 1] = char(nextMsgId) .. char(p * 16 + parts) .. chunk
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------
local strip, textures
local queue = {}
local seq = 0
local ticker

local function PixelUnit()
    local block = (WT.db and WT.db.link.block) or 3
    local _, physH = GetPhysicalScreenSize()
    if not physH or physH <= 0 then physH = 1080 end
    return block * 768 / physH
end

local function Layout()
    if not strip then return end
    local unit = PixelUnit()
    strip:ClearAllPoints()
    local corner = (WT.db and WT.db.link.corner) or "TOPLEFT"
    strip:SetPoint(corner, UIParent, corner, 0, 0)
    strip:SetSize(unit * BLOCKS, unit)
    for i = 1, BLOCKS do
        local tex = textures[i]
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", strip, "TOPLEFT", (i - 1) * unit, 0)
        tex:SetSize(unit, unit)
    end
end

local function CreateStrip()
    if strip then return end
    strip = CreateFrame("Frame", "WoWTranslateLinkStrip", UIParent)
    strip:SetFrameStrata("TOOLTIP")
    strip:SetFrameLevel(9000)
    if strip.SetIgnoreParentScale then strip:SetIgnoreParentScale(true) end
    if strip.SetIgnoreParentAlpha then strip:SetIgnoreParentAlpha(true) end
    strip:SetScale(1)
    strip:EnableMouse(false)
    textures = {}
    for i = 1, BLOCKS do
        local tex = strip:CreateTexture(nil, "OVERLAY")
        if tex.SetSnapToPixelGrid then
            tex:SetSnapToPixelGrid(false)
            tex:SetTexelSnappingBias(0)
        end
        textures[i] = tex
    end
    Layout()
end

local function Draw(blocks)
    for i = 1, BLOCKS do
        local c = blocks[i]
        textures[i]:SetColorTexture(c[1] / 3, c[2] / 3, c[3] / 3, 1)
    end
end

local function Pump()
    if not strip then return end
    seq = (seq + 1) % 64
    local payload = table.remove(queue, 1)
    Draw(CL.EncodeFrame(seq, payload or ""))
    if not payload and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function StartPump()
    if ticker or not strip then return end
    Pump()
    local hold = (WT.db and WT.db.link.hold) or 0.12
    ticker = C_Timer.NewTicker(hold, Pump)
end

local function Enqueue(message)
    if not strip or not strip:IsShown() then return end
    local frames = CL.Frames(message)
    for i = 1, #frames do queue[#queue + 1] = frames[i] end
    while #queue > MAX_QUEUE do table.remove(queue, 1) end
    StartPump()
end

-- ---------------------------------------------------------------------------
-- Messages
-- ---------------------------------------------------------------------------
local function Clean(s)
    s = tostring(s or "")
    return (string.gsub(s, "[%c]", " "))
end

function CL.SendChat(channel, channelName, author, lang, text)
    if not text or text == "" then return end
    Enqueue(concat({ PROTOCOL, "C", Clean(channel), Clean(channelName), Clean(author), Clean(lang), Clean(text) }, SEP))
end

function CL.SendHello()
    Enqueue(concat({ PROTOCOL, "H", Clean(WT.version), WT.ClientLang(), WT.IncomingTarget(), Clean(WT.Locale()) }, SEP))
end

function CL.SendTest()
    Enqueue(concat({ PROTOCOL, "T", Clean(L.LINK_TEST_MESSAGE) }, SEP))
end

function CL.IsActive()
    return strip ~= nil and strip:IsShown()
end

function CL.QueueLength()
    return #queue
end

-- ---------------------------------------------------------------------------
-- On / off
-- ---------------------------------------------------------------------------
local function Refresh()
    local db = WT.db
    if not db then return end
    if db.mode == "accurate" then
        CreateStrip()
        Layout()
        if not strip:IsShown() or not CL.helloSent then
            strip:Show()
            CL.helloSent = true
            CL.SendHello()
        end
        if #queue == 0 then Draw(CL.EncodeFrame(seq, "")) end
    elseif strip then
        strip:Hide()
        queue = {}
        CL.helloSent = false
        if ticker then ticker:Cancel() ticker = nil end
    end
end

WT.On("LOGIN", function()
    Refresh()
    -- Repeat the hello now and then, so a companion started after the game
    -- still learns which language to translate into.
    C_Timer.NewTicker(30, function()
        if WT.db.mode == "accurate" and strip and strip:IsShown() and #queue == 0 then
            CL.SendHello()
        end
    end)
end)
WT.On("SETTINGS_CHANGED", function(key)
    if key == "*" or key == "mode" or key == "link.corner" or key == "link.block" or key == "incomingTo" then
        if key == "incomingTo" then CL.helloSent = false end
        Refresh()
    end
end)
WT.RegisterEvent("DISPLAY_SIZE_CHANGED", Layout)
WT.RegisterEvent("UI_SCALE_CHANGED", Layout)
