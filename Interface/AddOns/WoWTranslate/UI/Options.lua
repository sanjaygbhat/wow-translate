-- WoW Translate: options window (/wt)
-- Every change applies immediately; there is no Save button to forget.

local _, WT = ...
local L = WT.L
local W = WT.Widgets

local frame
local controls = {}

local WIDTH, HEIGHT = 480, 690

local function LangOptions(includeAuto, autoText, skipLang)
    local opts = {}
    if includeAuto then opts[#opts + 1] = { value = "auto", text = autoText } end
    for _, code in ipairs(WT.LANGS) do
        if code ~= skipLang then
            opts[#opts + 1] = { value = code, text = WT.LANG_NATIVE[code] }
        end
    end
    return opts
end

local function ChannelGrid(parent, y, tbl, keys)
    local list = {}
    local cols = { 18, 168, 318 }
    for i, ch in ipairs(keys) do
        local col = (i - 1) % 3 + 1
        local row = math.floor((i - 1) / 3)
        local cb = W.Check(parent, L["CHANNEL_" .. ch], nil, cols[col], y - row * 24,
            function() return WT.db[tbl][ch] end,
            function(v) WT.Set(tbl .. "." .. ch, v) end)
        list[#list + 1] = cb
    end
    return list
end

local function Refresh()
    if not frame or not frame:IsShown() then return end
    local db = WT.db
    for _, c in ipairs(controls) do
        if c.Refresh then c:Refresh() end
    end
    frame.quick:SetSelected(db.mode ~= "accurate")
    frame.accurate:SetSelected(db.mode == "accurate")

    if db.mode == "accurate" then
        local q = WT.CompanionLink and WT.CompanionLink.QueueLength() or 0
        frame.linkStatus:SetText(string.format(L.LINK_STATUS_ON, L["CORNER_" .. db.link.corner]) ..
            (q > 0 and ("  " .. string.format(L.LINK_QUEUE, q)) or ""))
        frame.linkButton:SetText(L.BUTTON_SEND_TEST)
    else
        frame.linkStatus:SetText(L.LINK_STATUS_OFF)
        frame.linkButton:SetText(L.BUTTON_HOW_TO_SETUP)
    end

    local inOn = db.enabled
    for _, c in ipairs(frame.incomingDeps) do
        if c.SetEnabled then c:SetEnabled(inOn) end
        c:SetAlpha(inOn and 1 or 0.45)
    end
    local outOn = db.outgoingEnabled
    for _, c in ipairs(frame.outgoingDeps) do
        if c.SetEnabled then c:SetEnabled(outOn) end
        c:SetAlpha(outOn and 1 or 0.45)
    end

    local atRisk = WT.Persist and WT.Persist.AtRisk()
    frame.rememberNote:SetText(atRisk and L.REMEMBER_AT_RISK or L.REMEMBER_NOTE)
    frame.rememberNote:SetTextColor(atRisk and 1 or 0.7, atRisk and 0.6 or 0.7, atRisk and 0.2 or 0.7)
end
WT.RefreshOptions = Refresh

-- ---------------------------------------------------------------------------
-- Accurate mode setup guide
-- ---------------------------------------------------------------------------
local guide
local function ShowGuide()
    if not guide then
        guide = CreateFrame("Frame", "WoWTranslateSetupGuide", UIParent, "ButtonFrameTemplate")
        ButtonFrameTemplate_HidePortrait(guide)
        ButtonFrameTemplate_HideAttic(guide)
        ButtonFrameTemplate_HideButtonBar(guide)
        guide:SetSize(440, 330)
        guide:SetPoint("CENTER", 0, 40)
        guide:SetFrameStrata("DIALOG")
        guide:SetToplevel(true)
        guide:EnableMouse(true)
        guide:SetMovable(true)
        guide:RegisterForDrag("LeftButton")
        guide:SetScript("OnDragStart", guide.StartMoving)
        guide:SetScript("OnDragStop", guide.StopMovingOrSizing)
        if guide.SetTitle then guide:SetTitle(L.GUIDE_TITLE) end
        table.insert(UISpecialFrames, "WoWTranslateSetupGuide")

        local body = W.Text(guide, L.GUIDE_BODY, 20, -36, 400, "GameFontHighlight")
        body:SetSpacing(3)

        local label = W.Text(guide, L.GUIDE_LINK_LABEL, 20, -236, 400, "GameFontNormalSmall")
        local box = CreateFrame("EditBox", nil, guide, "InputBoxTemplate")
        box:SetSize(390, 22)
        box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 6, -4)
        box:SetAutoFocus(false)
        local url = "https://github.com/sanjaygbhat/wow-translate/releases"
        box:SetText(url)
        box:SetScript("OnTextChanged", function(self) if self:GetText() ~= url then self:SetText(url) self:HighlightText() end end)
        box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        guide.box = box

        local use = W.Button(guide, L.BUTTON_USE_ACCURATE, 180, function()
            WT.Set("mode", "accurate")
            guide:Hide()
        end)
        use:SetPoint("BOTTOMRIGHT", -16, 14)
        local close = W.Button(guide, CLOSE or "Close", 100, function() guide:Hide() end)
        close:SetPoint("RIGHT", use, "LEFT", -8, 0)
    end
    guide:Show()
    guide.box:SetFocus()
    guide.box:HighlightText()
end
WT.ShowSetupGuide = ShowGuide

-- ---------------------------------------------------------------------------
-- Main window
-- ---------------------------------------------------------------------------
local function Build()
    frame = CreateFrame("Frame", "WoWTranslateOptionsFrame", UIParent, "ButtonFrameTemplate")
    ButtonFrameTemplate_HidePortrait(frame)
    ButtonFrameTemplate_HideAttic(frame)
    ButtonFrameTemplate_HideButtonBar(frame)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if frame.SetTitle then frame:SetTitle("WoW Translate " .. WT.version) end
    table.insert(UISpecialFrames, "WoWTranslateOptionsFrame")
    frame:SetScript("OnShow", Refresh)

    local p = frame
    local function add(c) controls[#controls + 1] = c return c end

    -- Mode ------------------------------------------------------------------
    W.Header(p, L.SECTION_MODE, 18, -34, 440)
    frame.quick = W.ModeCard(p, 18, -54, 215, 100, L.MODE_QUICK, L.MODE_QUICK_BODY, L.MODE_QUICK_BADGE,
        function() WT.Set("mode", "quick") end)
    frame.accurate = W.ModeCard(p, 243, -54, 215, 100, L.MODE_ACCURATE, L.MODE_ACCURATE_BODY, L.MODE_ACCURATE_BADGE,
        function() WT.Set("mode", "accurate") end)

    frame.linkStatus = W.Text(p, "", 20, -162, 300, "GameFontHighlightSmall")
    frame.linkButton = W.Button(p, L.BUTTON_HOW_TO_SETUP, 140, function()
        if WT.db.mode == "accurate" and WT.CompanionLink then
            WT.CompanionLink.SendTest()
            WT.Print(L.LINK_TEST_SENT)
        else
            ShowGuide()
        end
    end)
    frame.linkButton:SetPoint("TOPRIGHT", -22, -158)

    -- Reading ---------------------------------------------------------------
    W.Header(p, L.SECTION_READING, 18, -192, 440)
    add(W.Check(p, L.OPT_TRANSLATE_INCOMING, L.OPT_TRANSLATE_INCOMING_TIP, 18, -212,
        function() return WT.db.enabled end, function(v) WT.Set("enabled", v) end))
    frame.incomingDeps = {}
    local function dep(c) frame.incomingDeps[#frame.incomingDeps + 1] = c return add(c) end
    dep(W.Cycler(p, L.OPT_TRANSLATE_INTO, L.OPT_TRANSLATE_INTO_TIP, 18, -238, 330,
        LangOptions(true, function() return string.format(L.AUTO_LANG, WT.LANG_NATIVE[WT.ClientLang()]) end),
        function() return WT.db.incomingTo end, function(v) WT.Set("incomingTo", v) end))
    for _, cb in ipairs(ChannelGrid(p, -266, "channels", WT.CHANNELS)) do dep(cb) end
    dep(W.Check(p, L.OPT_SHOW_ORIGINAL, L.OPT_SHOW_ORIGINAL_TIP, 18, -342,
        function() return WT.db.display == "both" end, function(v) WT.Set("display", v and "both" or "replace") end))
    dep(W.Check(p, L.OPT_LOCALIZE_LINKS, L.OPT_LOCALIZE_LINKS_TIP, 243, -342,
        function() return WT.db.localizeLinks end, function(v) WT.Set("localizeLinks", v) end))
    dep(W.Check(p, L.OPT_PAUSE_AFK, L.OPT_PAUSE_AFK_TIP, 18, -366,
        function() return WT.db.disableWhileAfk end, function(v) WT.Set("disableWhileAfk", v) end))
    dep(W.Check(p, L.OPT_MARKER, L.OPT_MARKER_TIP, 243, -366,
        function() return WT.db.showMarker end, function(v) WT.Set("showMarker", v) end))

    -- Writing ---------------------------------------------------------------
    W.Header(p, L.SECTION_WRITING, 18, -400, 440)
    add(W.Check(p, L.OPT_TRANSLATE_OUTGOING, L.OPT_TRANSLATE_OUTGOING_TIP, 18, -420,
        function() return WT.db.outgoingEnabled end, function(v) WT.Set("outgoingEnabled", v) end))
    frame.outgoingDeps = {}
    local function odep(c) frame.outgoingDeps[#frame.outgoingDeps + 1] = c return add(c) end
    odep(W.Cycler(p, L.OPT_WRITE_IN, L.OPT_WRITE_IN_TIP, 18, -446, 330,
        LangOptions(true, L.THEIR_LANGUAGE),
        function() return WT.db.outgoingTo end, function(v) WT.Set("outgoingTo", v) end))
    local outKeys = { "WHISPER", "PARTY", "RAID", "INSTANCE", "GUILD", "SAY", "YELL", "CHANNEL" }
    for _, cb in ipairs(ChannelGrid(p, -474, "outgoingChannels", outKeys)) do odep(cb) end
    odep(W.Check(p, L.OPT_OUTGOING_TAG, L.OPT_OUTGOING_TAG_TIP, 18, -546,
        function() return WT.db.outgoingTag end, function(v) WT.Set("outgoingTag", v) end))

    -- Other -----------------------------------------------------------------
    W.Header(p, L.SECTION_OTHER, 18, -580, 440)
    add(W.Check(p, L.OPT_ROMANIZE, L.OPT_ROMANIZE_TIP, 18, -600,
        function() return WT.db.romanizeNames end, function(v) WT.Set("romanizeNames", v) end))
    add(W.Check(p, L.OPT_MINIMAP, L.OPT_MINIMAP_TIP, 243, -600,
        function() return not WT.db.minimap.hide end, function(v) WT.Set("minimap.hide", not v) end))
    add(W.Check(p, L.OPT_REMEMBER, L.OPT_REMEMBER_TIP, 18, -624,
        function() return WT.db.rememberViaMacro end, function(v) WT.Set("rememberViaMacro", v) end))
    frame.rememberNote = W.Text(p, "", 48, -648, 400, "GameFontHighlightSmall")

    -- Bottom buttons ----------------------------------------------------------
    local close = W.Button(p, CLOSE or "Close", 100, function() frame:Hide() end)
    close:SetPoint("BOTTOMRIGHT", -16, 12)
    local try = W.Button(p, L.BUTTON_TRY, 120, function() WT.RunDemo() end)
    try:SetPoint("BOTTOMLEFT", 16, 12)
    try:SetScript("OnEnter", function(self) W.ShowTip(self, L.BUTTON_TRY, L.BUTTON_TRY_TIP) end)
    try:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local reset = W.Button(p, L.BUTTON_RESET, 120, function()
        WT.ResetSettings()
        WT.Print(L.SETTINGS_RESET)
    end)
    reset:SetPoint("LEFT", try, "RIGHT", 8, 0)
end

function WT.ToggleOptions()
    if not frame then Build() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

function WT.ShowOptions()
    if not frame then Build() end
    frame:Show()
    Refresh()
end

WT.On("SETTINGS_CHANGED", function() Refresh() end)

-- ---------------------------------------------------------------------------
-- Entry in Options > AddOns
-- ---------------------------------------------------------------------------
WT.On("LOGIN", function()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local panel = CreateFrame("Frame")
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("WoW Translate")
    local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    text:SetWidth(520)
    text:SetJustifyH("LEFT")
    text:SetText(L.SETTINGS_PANEL_TEXT)
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(200, 26)
    open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
    open:SetText(L.BUTTON_OPEN_OPTIONS)
    open:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        WT.ShowOptions()
    end)
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "WoW Translate")
    if ok and category then
        pcall(Settings.RegisterAddOnCategory, category)
        WT.settingsCategory = category
    end
end)
