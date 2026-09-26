-- WoW Translate: keeping settings on the Forever beta client
--
-- Known beta bug (build 1.60.1): the client writes addon SavedVariables on
-- logout but never loads them back, so every addon starts from defaults.
-- Macros made with CreateMacro DO survive a restart, so when the player opts
-- in we keep a compact copy of the settings in ONE account macro named
-- "WoWTranslate". Its body is "/wt restore <data>", so clicking it is
-- harmless (it just re-applies the settings).
--
--   * Opt-in only. The macro existing is itself the "on" switch.
--   * Real SavedVariables win. If they load (bug fixed), the macro is
--     no longer needed and is removed automatically.
--   * Never write before reading: the macro list can arrive after login.
--   * Macro edits are blocked in combat, so writes wait for combat to end.

local _, WT = ...
local L = WT.L

local MACRO_NAME = "WoWTranslate"
local MACRO_ICON = "INV_Misc_Note_01"
local PREFIX = "/wt restore "

local P = { ready = false, restored = false, pending = false, hinted = false, note = "" }
WT.Persist = P

local function MacroAPI()
    return CreateMacro and EditMacro and DeleteMacro and GetMacroBody and GetMacroIndexByName and true or false
end

-- ---------------------------------------------------------------------------
-- Compact encoding: "v=1;e=1;m=q;..." (about 110 characters)
-- ---------------------------------------------------------------------------
local function bits(tbl)
    local out = {}
    for i, ch in ipairs(WT.CHANNELS) do out[i] = (tbl and tbl[ch]) and "1" or "0" end
    return table.concat(out)
end

local function unbits(str, tbl)
    for i, ch in ipairs(WT.CHANNELS) do
        local c = string.sub(str or "", i, i)
        if c == "1" then tbl[ch] = true elseif c == "0" then tbl[ch] = false end
    end
end

local function b(v) return v and "1" or "0" end

function P.Encode()
    local db = WT.db
    local parts = {
        "v=1",
        "e=" .. b(db.enabled),
        "m=" .. (db.mode == "accurate" and "a" or "q"),
        "it=" .. tostring(db.incomingTo),
        "d=" .. (db.display == "both" and "b" or "r"),
        "mk=" .. b(db.showMarker),
        "ll=" .. b(db.localizeLinks),
        "af=" .. b(db.disableWhileAfk),
        "ch=" .. bits(db.channels),
        "oe=" .. b(db.outgoingEnabled),
        "ot=" .. tostring(db.outgoingTo),
        "og=" .. b(db.outgoingTag),
        "oc=" .. bits(db.outgoingChannels),
        "rn=" .. b(db.romanizeNames),
        "mm=" .. b(db.minimap.hide) .. "," .. math.floor((db.minimap.angle or 200) + 0.5),
        "lk=" .. tostring(db.link.corner) .. "," .. tostring(db.link.block),
        "w=" .. b(db.welcomed),
    }
    return table.concat(parts, ";")
end

local VALID_LANG = function(v) return v == "auto" or WT.LANG_SET[v] end
local CORNERS = { TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }

function P.Decode(data)
    local t = {}
    for k, v in string.gmatch(data or "", "([^;=]+)=([^;]*)") do t[k] = v end
    if t.v ~= "1" then return false end
    local db = WT.db
    local function flag(key, field) if t[key] == "1" then db[field] = true elseif t[key] == "0" then db[field] = false end end
    flag("e", "enabled")
    if t.m then db.mode = (t.m == "a") and "accurate" or "quick" end
    if t.it and VALID_LANG(t.it) then db.incomingTo = t.it end
    if t.d then db.display = (t.d == "b") and "both" or "replace" end
    flag("mk", "showMarker")
    flag("ll", "localizeLinks")
    flag("af", "disableWhileAfk")
    if t.ch then unbits(t.ch, db.channels) end
    flag("oe", "outgoingEnabled")
    if t.ot and VALID_LANG(t.ot) then db.outgoingTo = t.ot end
    flag("og", "outgoingTag")
    if t.oc then unbits(t.oc, db.outgoingChannels) end
    flag("rn", "romanizeNames")
    local hide, angle = string.match(t.mm or "", "^([01]),(%-?%d+)$")
    if hide then db.minimap.hide = hide == "1"; db.minimap.angle = tonumber(angle) end
    local corner, block = string.match(t.lk or "", "^(%u+),(%d+)$")
    if corner and CORNERS[corner] then db.link.corner = corner end
    if block then db.link.block = math.max(2, math.min(8, tonumber(block))) end
    flag("w", "welcomed")
    return true
end

-- ---------------------------------------------------------------------------
-- Macro storage
-- ---------------------------------------------------------------------------
local function MacroIndex()
    if not MacroAPI() then return 0 end
    local ok, index = pcall(GetMacroIndexByName, MACRO_NAME)
    return (ok and index) or 0
end

local function ReadMacro()
    local index = MacroIndex()
    if index == 0 then return nil end
    local ok, body = pcall(GetMacroBody, index)
    if not ok or type(body) ~= "string" then return nil end
    -- Bodies can come back with trailing whitespace: never anchor at the end.
    return string.match(body, "^/wt restore (%S+)")
end

local function DeleteMacroCopy()
    local index = MacroIndex()
    if index > 0 then pcall(DeleteMacro, index) end
end

function P.Write()
    P.pending = false
    local db = WT.db
    if not (db and db.rememberViaMacro and P.ready) then return end
    if not MacroAPI() then P.note = L.PERSIST_NO_MACRO_API return end
    if InCombatLockdown and InCombatLockdown() then
        P.afterCombat = true
        return
    end
    local body = PREFIX .. P.Encode()
    local index = MacroIndex()
    if index > 0 then
        pcall(EditMacro, index, nil, nil, body)
    else
        local ok, made = pcall(CreateMacro, MACRO_NAME, MACRO_ICON, body, nil)
        if not ok or not made then
            P.note = L.PERSIST_MACRO_FULL
            WT.Print(L.PERSIST_MACRO_FULL)
            return
        end
    end
    P.note = L.PERSIST_SAVED
end

local function WriteSoon()
    if P.pending then return end
    P.pending = true
    if C_Timer and C_Timer.After then C_Timer.After(1, P.Write) else P.Write() end
end

-- Called at login, on UPDATE_MACROS, and once more a few seconds later.
local function TryRead(final)
    if P.ready then return end
    local stored = ReadMacro()
    if stored then
        if WT.hadSavedVariables then
            -- The client loaded our real settings: the stand-in is not needed.
            DeleteMacroCopy()
            WT.db.rememberViaMacro = false
            WT.Print(L.PERSIST_FIXED)
        else
            WT.db.rememberViaMacro = true
            P.restored = P.Decode(stored)
            if P.restored then WT.Fire("SETTINGS_CHANGED", "*") end
        end
    end
    if stored or final then
        P.ready = true
        -- Opted in before the macro list had loaded: write now.
        if not stored and WT.db.rememberViaMacro then WriteSoon() end
        WT.Fire("PERSIST_READY", P.restored)
    end
end

-- True when changes will be lost at the next restart.
function P.AtRisk()
    local db = WT.db
    return db ~= nil and P.ready and not db.rememberViaMacro and not WT.hadSavedVariables and WT.IsForeverClient()
end

WT.On("LOGIN", function() TryRead(false) end)
WT.RegisterEvent("UPDATE_MACROS", function() TryRead(false) end)
WT.RegisterEvent("PLAYER_ENTERING_WORLD", function()
    if C_Timer and C_Timer.After then
        C_Timer.After(4, function() TryRead(true) end)
    else
        TryRead(true)
    end
end)
WT.RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if P.afterCombat then
        P.afterCombat = false
        WriteSoon()
    end
end)

WT.On("SETTINGS_CHANGED", function(key, value)
    local db = WT.db
    if not db or not P.ready then return end
    if key == "rememberViaMacro" then
        if value then WriteSoon() else DeleteMacroCopy() end
        return
    end
    if db.rememberViaMacro then
        WriteSoon()
    elseif P.AtRisk() and not P.hinted and key ~= "*" then
        P.hinted = true
        WT.Print(L.PERSIST_HINT)
    end
end)

-- /wt restore <data> (the body of the macro)
function P.RestoreFromCommand(data)
    if P.Decode(data) then
        WT.Fire("SETTINGS_CHANGED", "*")
        WT.Print(L.PERSIST_RESTORED)
    end
end
