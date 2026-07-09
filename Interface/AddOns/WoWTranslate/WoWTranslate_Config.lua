-- WoWTranslate_Config.lua
-- Configuration UI panel for WoWTranslate 2.0

-- ============================================================================
-- LANGUAGES
-- ============================================================================
local LANGUAGES = {
    { code = "zh", name = "Chinese" },
    { code = "en", name = "English" },
    { code = "ko", name = "Korean" },
    { code = "ja", name = "Japanese" },
    { code = "ru", name = "Russian" },
    { code = "de", name = "German" },
    { code = "fr", name = "French" },
    { code = "es", name = "Spanish" },
    { code = "pt", name = "Portuguese" },
}

local PROVIDERS = {
    { code = "google_free", name = "Google Free (no key)" },
    { code = "google", name = "Google" },
    { code = "openai", name = "OpenAI-compatible" },
    { code = "custom", name = "Custom HTTP" },
}

local function GetLanguageIndex(code)
    for i = 1, table.getn(LANGUAGES) do
        if LANGUAGES[i].code == code then
            return i
        end
    end
    return 1
end

local function GetLanguageName(code)
    for i = 1, table.getn(LANGUAGES) do
        if LANGUAGES[i].code == code then
            return LANGUAGES[i].name
        end
    end
    return code
end

local function GetProviderIndex(code)
    for i = 1, table.getn(PROVIDERS) do
        if PROVIDERS[i].code == code then
            return i
        end
    end
    return 1
end

local function GetProviderName(code)
    for i = 1, table.getn(PROVIDERS) do
        if PROVIDERS[i].code == code then
            return PROVIDERS[i].name
        end
    end
    return code
end

local function MaskApiKey(key)
    if not key or key == "" then
        return "(not set)"
    end
    if string.len(key) <= 6 then
        return "******"
    end
    return string.sub(key, 1, 3) .. "..." .. string.sub(key, string.len(key) - 2)
end

local function trim(text)
    if not text then return "" end
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

-- ============================================================================
-- TEMP CONFIG
-- ============================================================================
WoWTranslate_TempConfig = {}

local function LoadTempConfig()
    WoWTranslate_TempConfig = {}
    if not WoWTranslateDB then return end
    for k, v in pairs(WoWTranslateDB) do
        if type(v) == "table" then
            WoWTranslate_TempConfig[k] = {}
            for k2, v2 in pairs(v) do
                WoWTranslate_TempConfig[k][k2] = v2
            end
        else
            WoWTranslate_TempConfig[k] = v
        end
    end
end

local function SaveTempConfig()
    if not WoWTranslate_TempConfig then return end
    for k, v in pairs(WoWTranslate_TempConfig) do
        if type(v) == "table" then
            if not WoWTranslateDB[k] then
                WoWTranslateDB[k] = {}
            end
            for k2, v2 in pairs(v) do
                WoWTranslateDB[k][k2] = v2
            end
        else
            WoWTranslateDB[k] = v
        end
    end
end

-- ============================================================================
-- CREATE MAIN FRAME
-- ============================================================================
local configFrame = CreateFrame("Frame", "WoWTranslateConfigFrame", UIParent)
configFrame:Hide()
configFrame:SetWidth(440)
configFrame:SetHeight(780)
configFrame:SetPoint("CENTER", 0, 0)
configFrame:SetMovable(true)
configFrame:EnableMouse(true)
configFrame:SetClampedToScreen(true)
configFrame:SetFrameStrata("DIALOG")

configFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
configFrame:SetBackdropColor(0, 0, 0, 1)

configFrame:SetScript("OnMouseDown", function()
    this:StartMoving()
end)

configFrame:SetScript("OnMouseUp", function()
    this:StopMovingOrSizing()
end)

local title = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOP", configFrame, "TOP", 0, -20)
title:SetText("WoWTranslate 2.0 Configuration")

local closeBtn = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -5, -5)
closeBtn:SetScript("OnClick", function()
    configFrame:Hide()
end)

tinsert(UISpecialFrames, "WoWTranslateConfigFrame")

configFrame.elements = {}

-- ============================================================================
-- UI HELPERS
-- ============================================================================
local function CreateHeader(text, yPos)
    local header = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 25, yPos)
    header:SetText(text)
    header:SetTextColor(1, 0.82, 0)
    return header
end

local function CreateCheckbox(label, xPos, yPos, configKey, subKey)
    local wrapper = CreateFrame("Frame", nil, configFrame)
    wrapper:SetPoint("TOPLEFT", configFrame, "TOPLEFT", xPos, yPos)
    wrapper:SetWidth(200)
    wrapper:SetHeight(24)
    wrapper.configKey = configKey
    wrapper.subKey = subKey

    local cb = CreateFrame("CheckButton", nil, wrapper, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 0, 0)

    local text = wrapper:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)

    cb:SetScript("OnClick", function()
        local parent = this:GetParent()
        local key = parent.configKey
        local sub = parent.subKey
        local enabled = (this:GetChecked() and true) or false

        if key == "outgoingEnabled" then
            WoWTranslate_SetOutgoingEnabled(enabled)
            WoWTranslate_TempConfig.outgoingEnabled = enabled
        elseif key == "enabled" then
            WoWTranslate_SetIncomingEnabled(enabled)
            WoWTranslate_TempConfig.enabled = enabled
        elseif key == "outgoingChannels" and sub then
            WoWTranslate_SetChannelEnabled(sub, enabled)
            if not WoWTranslate_TempConfig.outgoingChannels then
                WoWTranslate_TempConfig.outgoingChannels = {}
            end
            WoWTranslate_TempConfig.outgoingChannels[sub] = enabled
        elseif key == "incomingChannels" and sub then
            WoWTranslate_SetIncomingChannelEnabled(sub, enabled)
            if not WoWTranslate_TempConfig.incomingChannels then
                WoWTranslate_TempConfig.incomingChannels = {}
            end
            WoWTranslate_TempConfig.incomingChannels[sub] = enabled
        else
            if sub then
                if not WoWTranslate_TempConfig[key] then
                    WoWTranslate_TempConfig[key] = {}
                end
                WoWTranslate_TempConfig[key][sub] = enabled
                if not WoWTranslateDB[key] then
                    WoWTranslateDB[key] = {}
                end
                WoWTranslateDB[key][sub] = enabled
            else
                WoWTranslate_TempConfig[key] = enabled
                WoWTranslateDB[key] = enabled
            end
        end
    end)

    cb.wrapper = wrapper
    return cb
end

local function CreateLangSelector(label, xPos, yPos, configKey)
    local frame = CreateFrame("Frame", nil, configFrame)
    frame:SetPoint("TOPLEFT", configFrame, "TOPLEFT", xPos, yPos)
    frame:SetWidth(170)
    frame:SetHeight(48)

    local lbl = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", 0, 0)
    lbl:SetText(label)

    local leftBtn = CreateFrame("Button", nil, frame)
    leftBtn:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -5)
    leftBtn:SetWidth(24)
    leftBtn:SetHeight(24)
    leftBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    leftBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    leftBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    local display = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    display:SetPoint("LEFT", leftBtn, "RIGHT", 10, 0)
    display:SetWidth(85)
    display:SetJustifyH("CENTER")
    display:SetText("Language")

    local rightBtn = CreateFrame("Button", nil, frame)
    rightBtn:SetPoint("LEFT", display, "RIGHT", 10, 0)
    rightBtn:SetWidth(24)
    rightBtn:SetHeight(24)
    rightBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    rightBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    rightBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    frame.display = display
    frame.configKey = configKey

    leftBtn:SetScript("OnClick", function()
        local parent = this:GetParent()
        local code = WoWTranslate_TempConfig[parent.configKey] or "zh"
        local idx = GetLanguageIndex(code) - 1
        if idx < 1 then idx = table.getn(LANGUAGES) end
        WoWTranslate_TempConfig[parent.configKey] = LANGUAGES[idx].code
        parent.display:SetText(LANGUAGES[idx].name)
    end)

    rightBtn:SetScript("OnClick", function()
        local parent = this:GetParent()
        local code = WoWTranslate_TempConfig[parent.configKey] or "zh"
        local idx = GetLanguageIndex(code) + 1
        if idx > table.getn(LANGUAGES) then idx = 1 end
        WoWTranslate_TempConfig[parent.configKey] = LANGUAGES[idx].code
        parent.display:SetText(LANGUAGES[idx].name)
    end)

    return frame
end

local function CreateProviderSelector(xPos, yPos)
    local frame = CreateFrame("Frame", nil, configFrame)
    frame:SetPoint("TOPLEFT", configFrame, "TOPLEFT", xPos, yPos)
    frame:SetWidth(365)
    frame:SetHeight(30)

    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", 0, 0)
    label:SetText("Provider:")

    local leftBtn = CreateFrame("Button", nil, frame)
    leftBtn:SetPoint("LEFT", label, "RIGHT", 12, 0)
    leftBtn:SetWidth(24)
    leftBtn:SetHeight(24)
    leftBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    leftBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    leftBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    local display = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    display:SetPoint("LEFT", leftBtn, "RIGHT", 8, 0)
    display:SetWidth(160)
    display:SetJustifyH("CENTER")

    local rightBtn = CreateFrame("Button", nil, frame)
    rightBtn:SetPoint("LEFT", display, "RIGHT", 8, 0)
    rightBtn:SetWidth(24)
    rightBtn:SetHeight(24)
    rightBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    rightBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    rightBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    frame.display = display

    local function Step(delta)
        local code = WoWTranslate_TempConfig.provider or "google"
        local idx = GetProviderIndex(code) + delta
        if idx < 1 then idx = table.getn(PROVIDERS) end
        if idx > table.getn(PROVIDERS) then idx = 1 end
        WoWTranslate_TempConfig.provider = PROVIDERS[idx].code
        frame.display:SetText(PROVIDERS[idx].name)
        if configFrame.RefreshProviderFields then
            configFrame.RefreshProviderFields()
        end
    end

    leftBtn:SetScript("OnClick", function() Step(-1) end)
    rightBtn:SetScript("OnClick", function() Step(1) end)

    return frame
end

local function CreateEditRow(labelText, yPos)
    local row = CreateFrame("Frame", nil, configFrame)
    row:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 25, yPos)
    row:SetWidth(390)
    row:SetHeight(24)

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(120)
    label:SetJustifyH("LEFT")
    label:SetText(labelText)

    local bg = CreateFrame("Frame", nil, row)
    bg:SetPoint("LEFT", label, "RIGHT", 4, 0)
    bg:SetWidth(250)
    bg:SetHeight(24)
    bg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    bg:SetBackdropColor(0, 0, 0, 0.8)

    local edit = CreateFrame("EditBox", nil, bg)
    edit:SetPoint("TOPLEFT", 6, -5)
    edit:SetPoint("BOTTOMRIGHT", -6, 5)
    edit:SetFontObject(GameFontHighlight)
    edit:SetAutoFocus(false)
    edit:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function() this:ClearFocus() end)

    row.label = label
    row.edit = edit
    return row
end

-- ============================================================================
-- LAYOUT
-- ============================================================================
CreateHeader("Provider", -50)
configFrame.elements.provider = CreateProviderSelector(25, -76)
configFrame.elements.providerField1 = CreateEditRow("API Key:", -108)
configFrame.elements.providerField2 = CreateEditRow("Endpoint:", -136)
configFrame.elements.providerField3 = CreateEditRow("Model:", -164)
configFrame.elements.providerField4 = CreateEditRow("Auth:", -192)

local providerStatus = configFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
providerStatus:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 25, -222)
providerStatus:SetWidth(390)
providerStatus:SetJustifyH("LEFT")
providerStatus:SetText("Provider status: unknown")
configFrame.elements.providerStatus = providerStatus

local providerNote = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
providerNote:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 25, -241)
providerNote:SetWidth(390)
providerNote:SetJustifyH("LEFT")
providerNote:SetTextColor(0.8, 0.8, 0.8)
providerNote:SetText("Custom body template: /wt customtemplate or INI.")
configFrame.elements.providerNote = providerNote

local applyProviderBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
applyProviderBtn:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -25, -72)
applyProviderBtn:SetWidth(70)
applyProviderBtn:SetHeight(24)
applyProviderBtn:SetText("Apply")

CreateHeader("Incoming Translation (Chat -> You)", -270)
configFrame.elements.inEnabled = CreateCheckbox("Enable Incoming", 25, -296, "enabled", nil)
configFrame.elements.afkDisable = CreateCheckbox("Disable while AFK", 220, -296, "disableWhileAfk", nil)
configFrame.elements.translateSystem = CreateCheckbox("Translate system/emotes", 25, -322, "translateSystemMessages", nil)
configFrame.elements.inFrom = CreateLangSelector("From:", 25, -352, "incomingFromLang")
configFrame.elements.inTo = CreateLangSelector("To:", 210, -352, "incomingToLang")

local inChLabel = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
inChLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 25, -414)
inChLabel:SetText("Incoming Channels:")
configFrame.elements.inChSay = CreateCheckbox("Say", 25, -436, "incomingChannels", "SAY")
configFrame.elements.inChYell = CreateCheckbox("Yell", 140, -436, "incomingChannels", "YELL")
configFrame.elements.inChWhisper = CreateCheckbox("Whisper", 255, -436, "incomingChannels", "WHISPER")
configFrame.elements.inChParty = CreateCheckbox("Party", 25, -462, "incomingChannels", "PARTY")
configFrame.elements.inChGuild = CreateCheckbox("Guild", 140, -462, "incomingChannels", "GUILD")
configFrame.elements.inChRaid = CreateCheckbox("Raid", 255, -462, "incomingChannels", "RAID")
configFrame.elements.inChBG = CreateCheckbox("Battleground", 25, -488, "incomingChannels", "BATTLEGROUND")
configFrame.elements.inChChannel = CreateCheckbox("World/Local", 165, -488, "incomingChannels", "CHANNEL")

CreateHeader("Outgoing Translation (You -> Chat)", -522)
configFrame.elements.outEnabled = CreateCheckbox("Enable Outgoing", 25, -548, "outgoingEnabled", nil)
configFrame.elements.outFrom = CreateLangSelector("From:", 25, -578, "outgoingFromLang")
configFrame.elements.outTo = CreateLangSelector("To:", 210, -578, "outgoingToLang")

local chLabel = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
chLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 25, -640)
chLabel:SetText("Outgoing Channels:")
configFrame.elements.chWhisper = CreateCheckbox("Whisper", 25, -662, "outgoingChannels", "WHISPER")
configFrame.elements.chParty = CreateCheckbox("Party", 140, -662, "outgoingChannels", "PARTY")
configFrame.elements.chSay = CreateCheckbox("Say", 255, -662, "outgoingChannels", "SAY")
configFrame.elements.chGuild = CreateCheckbox("Guild", 25, -688, "outgoingChannels", "GUILD")
configFrame.elements.chRaid = CreateCheckbox("Raid", 140, -688, "outgoingChannels", "RAID")
configFrame.elements.chYell = CreateCheckbox("Yell", 255, -688, "outgoingChannels", "YELL")
configFrame.elements.chBG = CreateCheckbox("Battleground", 25, -714, "outgoingChannels", "BATTLEGROUND")
configFrame.elements.chChannel = CreateCheckbox("World/Local", 165, -714, "outgoingChannels", "CHANNEL")

local clearBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
clearBtn:SetPoint("BOTTOMLEFT", configFrame, "BOTTOMLEFT", 25, 20)
clearBtn:SetWidth(120)
clearBtn:SetHeight(26)
clearBtn:SetText("Clear Cache")
clearBtn:SetScript("OnClick", function()
    if WoWTranslate_CacheClear then
        WoWTranslate_CacheClear()
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[WoWTranslate] Cache cleared|r")
    end
end)

local saveBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
saveBtn:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -25, 20)
saveBtn:SetWidth(80)
saveBtn:SetHeight(26)
saveBtn:SetText("Save")
saveBtn:SetScript("OnClick", function()
    SaveTempConfig()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WoWTranslate] Settings saved|r")
    configFrame:Hide()
end)

-- ============================================================================
-- REFRESH UI FROM CONFIG
-- ============================================================================
function configFrame.RefreshProviderFields()
    local e = configFrame.elements
    local cfg = WoWTranslate_TempConfig
    local provider = cfg.provider or "google"

    if e.provider and e.provider.display then
        e.provider.display:SetText(GetProviderName(provider))
    end

    e.providerField1:Show()
    e.providerField2:Show()
    e.providerField3:Show()
    e.providerField4:Show()
    e.providerNote:Show()

    if provider == "google" then
        e.providerField1.label:SetText("Google Key:")
        e.providerField1.edit:SetText("")
        e.providerField2:Hide()
        e.providerField3:Hide()
        e.providerField4:Hide()
        e.providerNote:SetText("Current key: " .. MaskApiKey(cfg.googleApiKey))
    elseif provider == "openai" then
        e.providerField1.label:SetText("API Key:")
        e.providerField1.edit:SetText("")
        e.providerField2.label:SetText("Endpoint:")
        e.providerField2.edit:SetText(cfg.openaiEndpoint or "https://api.openai.com/v1/chat/completions")
        e.providerField3.label:SetText("Model:")
        e.providerField3.edit:SetText(cfg.openaiModel or "gpt-4.1-mini")
        e.providerField4:Hide()
        e.providerNote:SetText("Current key: " .. MaskApiKey(cfg.openaiApiKey))
    else
        e.providerField1.label:SetText("API Key:")
        e.providerField1.edit:SetText("")
        e.providerField2.label:SetText("Endpoint:")
        e.providerField2.edit:SetText(cfg.customEndpoint or "")
        e.providerField3.label:SetText("Path:")
        e.providerField3.edit:SetText(cfg.customResponsePath or "translation")
        e.providerField4.label:SetText("Auth:")
        e.providerField4.edit:SetText((cfg.customAuthHeader or "Authorization") .. " " .. (cfg.customAuthScheme or "Bearer"))
        e.providerNote:SetText("Body template: /wt customtemplate or INI.")
    end
end

local function RefreshProviderStatus()
    local e = configFrame.elements
    if not e.providerStatus then return end

    local status = WoWTranslate_API and WoWTranslate_API.GetProviderStatus and WoWTranslate_API.GetProviderStatus() or nil
    if status then
        local configured = status.configured and "configured" or "not configured"
        local ready = status.ready and "ready" or "not ready"
        e.providerStatus:SetText("Provider status: " .. configured .. ", " .. ready)
    else
        e.providerStatus:SetText("Provider status: unknown")
    end
end

local function ApplyProviderFields()
    local e = configFrame.elements
    local cfg = WoWTranslate_TempConfig
    local provider = cfg.provider or "google"

    if provider == "google" then
        local key = e.providerField1.edit:GetText()
        if key and key ~= "" then
            cfg.googleApiKey = key
        end
    elseif provider == "openai" then
        local key = e.providerField1.edit:GetText()
        if key and key ~= "" then cfg.openaiApiKey = key end
        cfg.openaiEndpoint = e.providerField2.edit:GetText()
        cfg.openaiModel = e.providerField3.edit:GetText()
    else
        local key = e.providerField1.edit:GetText()
        if key and key ~= "" then cfg.customApiKey = key end
        cfg.customEndpoint = e.providerField2.edit:GetText()
        cfg.customResponsePath = e.providerField3.edit:GetText()

        local auth = trim(e.providerField4.edit:GetText())
        local space = string.find(auth, " ", 1, true)
        if space then
            cfg.customAuthHeader = string.sub(auth, 1, space - 1)
            cfg.customAuthScheme = trim(string.sub(auth, space + 1))
        elseif auth ~= "" then
            cfg.customAuthHeader = auth
            cfg.customAuthScheme = ""
        end
    end

    SaveTempConfig()
    if WoWTranslate_ApplyProviderConfig then
        local ok, err = WoWTranslate_ApplyProviderConfig(false)
        if ok then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WoWTranslate] Provider settings applied|r")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WoWTranslate] Provider not configured: " .. (err or "unknown") .. "|r")
        end
    end

    configFrame.RefreshProviderFields()
    RefreshProviderStatus()
end

applyProviderBtn:SetScript("OnClick", ApplyProviderFields)

local function RefreshUI()
    local e = configFrame.elements
    local cfg = WoWTranslate_TempConfig

    configFrame.RefreshProviderFields()
    RefreshProviderStatus()

    if e.inEnabled then e.inEnabled:SetChecked(cfg.enabled) end
    if e.afkDisable then e.afkDisable:SetChecked(cfg.disableWhileAfk) end
    if e.translateSystem then e.translateSystem:SetChecked(cfg.translateSystemMessages) end
    if e.outEnabled then e.outEnabled:SetChecked(cfg.outgoingEnabled) end

    if e.inFrom and e.inFrom.display then
        e.inFrom.display:SetText(GetLanguageName(cfg.incomingFromLang or "zh"))
    end
    if e.inTo and e.inTo.display then
        e.inTo.display:SetText(GetLanguageName(cfg.incomingToLang or "en"))
    end
    if e.outFrom and e.outFrom.display then
        e.outFrom.display:SetText(GetLanguageName(cfg.outgoingFromLang or "en"))
    end
    if e.outTo and e.outTo.display then
        e.outTo.display:SetText(GetLanguageName(cfg.outgoingToLang or "zh"))
    end

    local inCh = cfg.incomingChannels or {}
    if e.inChSay then e.inChSay:SetChecked(inCh.SAY) end
    if e.inChYell then e.inChYell:SetChecked(inCh.YELL) end
    if e.inChWhisper then e.inChWhisper:SetChecked(inCh.WHISPER) end
    if e.inChParty then e.inChParty:SetChecked(inCh.PARTY) end
    if e.inChGuild then e.inChGuild:SetChecked(inCh.GUILD) end
    if e.inChRaid then e.inChRaid:SetChecked(inCh.RAID) end
    if e.inChBG then e.inChBG:SetChecked(inCh.BATTLEGROUND) end
    if e.inChChannel then e.inChChannel:SetChecked(inCh.CHANNEL) end

    local ch = cfg.outgoingChannels or {}
    if e.chWhisper then e.chWhisper:SetChecked(ch.WHISPER) end
    if e.chParty then e.chParty:SetChecked(ch.PARTY) end
    if e.chSay then e.chSay:SetChecked(ch.SAY) end
    if e.chGuild then e.chGuild:SetChecked(ch.GUILD) end
    if e.chRaid then e.chRaid:SetChecked(ch.RAID) end
    if e.chYell then e.chYell:SetChecked(ch.YELL) end
    if e.chBG then e.chBG:SetChecked(ch.BATTLEGROUND) end
    if e.chChannel then e.chChannel:SetChecked(ch.CHANNEL) end
end

local statusUpdateFrame = CreateFrame("Frame")
local statusUpdateElapsed = 0
statusUpdateFrame:SetScript("OnUpdate", function()
    if not configFrame:IsVisible() then return end
    statusUpdateElapsed = statusUpdateElapsed + arg1
    if statusUpdateElapsed >= 2 then
        statusUpdateElapsed = 0
        RefreshProviderStatus()
    end
end)

-- ============================================================================
-- PUBLIC API
-- ============================================================================
function WoWTranslate_ShowConfig()
    LoadTempConfig()
    RefreshUI()
    configFrame:Show()
end

function WoWTranslate_HideConfig()
    configFrame:Hide()
end

function WoWTranslate_ToggleConfig()
    if configFrame:IsVisible() then
        configFrame:Hide()
    else
        WoWTranslate_ShowConfig()
    end
end
