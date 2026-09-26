-- WoW Translate: slash commands, demo and greeting

local _, WT = ...
local L = WT.L

local lower, match, format = string.lower, string.match, string.format

-- One sample line per language for the "Try it" button.
local SAMPLES = {
    zh = "法师拉仇恨了，快撤！",
    ko = "힐러 구해요, 같이 가실 분?",
    ru = "Привет! Нужен танк в Мертвые копи",
    de = "Hallo, wir brauchen noch einen Heiler",
    fr = "Salut, on cherche un tank pour le donjon",
    es = "Hola, alguien para la mazmorra?",
    pt = "Oi, alguém pode me ajudar com essa missão?",
    ja = "ヒーラー募集、一緒に行きませんか？",
    en = "Hello, we need a tank for the dungeon",
}

local function ShowResult(text, from, to)
    local out, score = WT.TranslateMessage(text, from, to)
    local lang = WT.LANG_NATIVE[from] or from
    if out then
        WT.Print(format("|cff9d9d9d%s:|r %s", lang, text))
        WT.Print(format("  |cff66bbff->|r %s |cff9d9d9d(%s)|r", out, format(L.KNOWN_PERCENT, math.floor(score * 100 + 0.5))))
    else
        WT.Print(format("|cff9d9d9d%s:|r %s  |cffff8040%s|r", lang, text, L.NOT_TRANSLATED))
    end
end

function WT.RunDemo()
    local to = WT.IncomingTarget()
    WT.Print(format(L.DEMO_HEADER, WT.LANG_NATIVE[to]))
    local shown = 0
    for _, from in ipairs({ "zh", "ru", "de", "ko", "es", "fr" }) do
        if from ~= to and shown < 3 then
            ShowResult(SAMPLES[from], from, to)
            shown = shown + 1
        end
    end
    WT.Print(L.DEMO_FOOTER)
end

local function Status()
    local db = WT.db
    local on = function(v) return v and ("|cff20ff20" .. L.STATE_ON .. "|r") or ("|cffff4040" .. L.STATE_OFF .. "|r") end
    WT.Print(format("%s %s", L.STATUS_HEADER, WT.version))
    WT.Print(format("  %s: %s", L.STATUS_MODE, (db.mode == "accurate") and L.MODE_ACCURATE or L.MODE_QUICK))
    WT.Print(format("  %s: %s -> %s", L.STATUS_READING, on(db.enabled), WT.LANG_NATIVE[WT.IncomingTarget()]))
    WT.Print(format("  %s: %s (%s)", L.STATUS_WRITING, on(db.outgoingEnabled),
        db.outgoingTo == "auto" and L.THEIR_LANGUAGE or (WT.LANG_NATIVE[db.outgoingTo] or db.outgoingTo)))
    if db.mode == "accurate" then
        local active = WT.CompanionLink and WT.CompanionLink.IsActive()
        WT.Print(format("  %s: %s", L.STATUS_LINK, on(active)))
    end
    local P = WT.Persist
    if WT.hadSavedVariables then
        WT.Print("  " .. L.STATUS_SAVED_OK)
    elseif db.rememberViaMacro then
        WT.Print("  " .. L.STATUS_SAVED_MACRO)
    elseif P and P.AtRisk() then
        WT.Print("  |cffffa020" .. L.STATUS_SAVED_RISK .. "|r")
    end
    if WT.InChatLockdown() then
        WT.Print("  |cffffa020" .. L.STATUS_LOCKDOWN .. "|r")
    end
end

local function Help()
    WT.Print(L.HELP_HEADER)
    for _, line in ipairs(L.HELP_LINES) do
        WT.Print("  " .. line)
    end
end

local function ParseLang(arg)
    arg = lower(arg or "")
    if arg == "auto" then return "auto" end
    if WT.LANG_SET[arg] then return arg end
    for code, name in pairs(WT.LANG_NATIVE) do
        if lower(name) == arg then return code end
    end
    return nil
end

local CORNER_ALIAS = { tl = "TOPLEFT", tr = "TOPRIGHT", bl = "BOTTOMLEFT", br = "BOTTOMRIGHT",
    topleft = "TOPLEFT", topright = "TOPRIGHT", bottomleft = "BOTTOMLEFT", bottomright = "BOTTOMRIGHT" }

local function Handle(msg)
    msg = WT.Text.trim(msg or "")
    local cmd, rest = match(msg, "^(%S*)%s*(.-)$")
    cmd = lower(cmd or "")

    if cmd == "" or cmd == "show" or cmd == "options" or cmd == "config" then
        WT.ToggleOptions()
    elseif cmd == "help" or cmd == "?" then
        Help()
    elseif cmd == "on" or cmd == "enable" then
        WT.Set("enabled", true); WT.Print(L.TRANSLATION_ON)
    elseif cmd == "off" or cmd == "disable" then
        WT.Set("enabled", false); WT.Print(L.TRANSLATION_OFF)
    elseif cmd == "quick" then
        WT.Set("mode", "quick"); WT.Print(L.NOW_QUICK)
    elseif cmd == "accurate" then
        WT.Set("mode", "accurate"); WT.Print(L.NOW_ACCURATE)
    elseif cmd == "to" or cmd == "into" then
        local lang = ParseLang(rest)
        if lang then
            WT.Set("incomingTo", lang)
            WT.Print(format(L.NOW_TRANSLATING_INTO, WT.LANG_NATIVE[WT.IncomingTarget()]))
        else
            WT.Print(L.LANG_CODES)
        end
    elseif cmd == "write" or cmd == "outgoing" then
        local a = lower(rest)
        if a == "on" then
            WT.Set("outgoingEnabled", true); WT.Print(L.WRITING_ON)
        elseif a == "off" then
            WT.Set("outgoingEnabled", false); WT.Print(L.WRITING_OFF)
        else
            local lang = ParseLang(a)
            if lang then
                WT.Set("outgoingTo", lang)
                WT.Set("outgoingEnabled", true)
                WT.Print(format(L.NOW_WRITING_IN, lang == "auto" and L.THEIR_LANGUAGE or WT.LANG_NATIVE[lang]))
            else
                WT.Print(L.LANG_CODES)
            end
        end
    elseif cmd == "test" then
        if rest == "" then
            WT.RunDemo()
        else
            local from = WT.DetectLanguage(rest)
            local to = WT.IncomingTarget()
            if not from then
                WT.Print(L.CANT_DETECT)
            elseif from == to then
                -- Writing in your own language: show what outgoing would send.
                local target = WT.db.outgoingTo ~= "auto" and WT.db.outgoingTo or (to == "en" and "es" or "en")
                ShowResult(rest, from, target)
            else
                ShowResult(rest, from, to)
            end
        end
    elseif cmd == "link" then
        local sub, val = match(rest, "^(%S*)%s*(.-)$")
        sub = lower(sub or "")
        if sub == "test" then
            if WT.db.mode ~= "accurate" then WT.Set("mode", "accurate") end
            WT.CompanionLink.SendTest()
            WT.Print(L.LINK_TEST_SENT)
        elseif sub == "corner" and CORNER_ALIAS[lower(val)] then
            WT.Set("link.corner", CORNER_ALIAS[lower(val)])
            WT.Print(format(L.LINK_CORNER_SET, L["CORNER_" .. WT.db.link.corner]))
        elseif sub == "size" and tonumber(val) then
            WT.Set("link.block", math.max(2, math.min(8, math.floor(tonumber(val)))))
            WT.Print(format(L.LINK_SIZE_SET, WT.db.link.block))
        else
            WT.ShowSetupGuide()
        end
    elseif cmd == "remember" then
        local a = lower(rest)
        WT.Set("rememberViaMacro", a ~= "off")
        WT.Print(WT.db.rememberViaMacro and L.REMEMBER_ON or L.REMEMBER_OFF)
    elseif cmd == "restore" then
        WT.Persist.RestoreFromCommand(rest)
    elseif cmd == "status" then
        Status()
    elseif cmd == "reset" then
        WT.ResetSettings()
        WT.Print(L.SETTINGS_RESET)
    elseif cmd == "debug" then
        WT.Set("debug", not WT.db.debug)
        WT.Print("debug " .. (WT.db.debug and "on" or "off"))
    elseif cmd == "log" then
        for i = math.max(1, #WT.debugLog - 20), #WT.debugLog do WT.Print(WT.debugLog[i]) end
    else
        Help()
    end
end

SLASH_WOWTRANSLATE1 = "/wt"
SLASH_WOWTRANSLATE2 = "/wowtranslate"
SlashCmdList.WOWTRANSLATE = Handle
WT.HandleCommand = Handle

-- One short line at login so players know it is working and where to go.
WT.On("PERSIST_READY", function(restored)
    local db = WT.db
    if not db.enabled then
        WT.Print(L.GREETING_OFF)
        return
    end
    local mode = (db.mode == "accurate") and L.MODE_ACCURATE or L.MODE_QUICK
    WT.Print(format(L.GREETING, mode, WT.LANG_NATIVE[WT.IncomingTarget()]))
    if WT.InChatLockdown() then WT.Print(L.STATUS_LOCKDOWN) end
end)
