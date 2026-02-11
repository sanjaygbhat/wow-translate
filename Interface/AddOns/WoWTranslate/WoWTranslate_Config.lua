-- WoWTranslate_Config.lua
-- Configuration UI panel for WoWTranslate
-- v0.12: Added player name protection toggle, FetchCredits on open

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
-- HELPER: Mask API Key (show first 4 chars + asterisks)
-- ============================================================================
local function MaskApiKey(key)
    if not key or key == "" then
        return "(not set)"
    end
    if string.len(key) <= 4 then
        return key
    end
    local visible = string.sub(key, 1, 4)
    local hidden = string.rep("*", string.len(key) - 4)
    return visible .. hidden
end

-- ============================================================================
-- CREATE MAIN FRAME (bigger size to accommodate credits)
-- ============================================================================
local configFrame = CreateFrame("Frame", "WoWTranslateConfigFrame", UIParent)
configFrame:Hide()
configFrame:SetWidth(420)
configFrame:SetHeight(780)  -- Increased for player name toggle
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

-- Title
local title = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOP", configFrame, "TOP", 0, -20)
title:SetText("WoWTranslate Configuration")

-- Close button
local closeBtn = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -5, -5)
closeBtn:SetScript("OnClick", function()
    configFrame:Hide()
end)

-- ESC to close
tinsert(UISpecialFrames, "WoWTranslateConfigFrame")

-- ============================================================================
-- UI ELEMENTS STORAGE
-- ============================================================================
configFrame.elements = {}

-- ============================================================================
-- HELPER: Create Section Header
-- ============================================================================
local function CreateHeader(text, yPos)
    local header = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 25, yPos)
    header:SetText(text)
    header:SetTextColor(1, 0.82, 0)
    return header
end

-- ============================================================================
-- HELPER: Create Checkbox at specific position
-- ============================================================================
local function CreateCheckbox(label, xPos, yPos, configKey, subKey)
    -- Create a wrapper frame like the language selector does
    local wrapper = CreateFrame("Frame", nil, configFrame)
    wrapper:SetPoint("TOPLEFT", configFrame, "TOPLEFT", xPos, yPos)
    wrapper:SetWidth(200)
    wrapper:SetHeight(24)

    -- Store config on wrapper (same pattern as language selector)
    wrapper.configKey = configKey
    wrapper.subKey = subKey

    local cb = CreateFrame("CheckButton", nil, wrapper, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 0, 0)

    local text = wrapper:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)

    cb:SetScript("OnClick", function()
        -- Use GetParent() like language selector does
        local parent = this:GetParent()
        local key = parent.configKey
        local sub = parent.subKey

        -- GetChecked() returns 1 or nil in WoW 1.12
        local isChecked = this:GetChecked()
        local enabled = (isChecked and true) or false

        -- Use the global toggle functions for immediate effect
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
            -- Fallback for any other settings
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

    -- Return the checkbox (not wrapper) so SetChecked works
    cb.wrapper = wrapper
    return cb
end

-- ============================================================================
-- HELPER: Create Language Selector
-- ============================================================================
local function CreateLangSelector(label, xPos, yPos, configKey)
    local frame = CreateFrame("Frame", nil, configFrame)
    frame:SetPoint("TOPLEFT", configFrame, "TOPLEFT", xPos, yPos)
    frame:SetWidth(170)
    frame:SetHeight(50)

    local lbl = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", 0, 0)
    lbl:SetText(label)

    local leftBtn = CreateFrame("Button", nil, frame)
    leftBtn:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -6)
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

-- ============================================================================
-- BUILD UI (with better spacing, including credits)
-- ============================================================================

-- Y positions with better spacing
local Y_API_HEADER = -50
local Y_API_LABEL = -78
local Y_API_EDIT = -100

-- Credits display (NEW in v0.10)
local Y_CREDITS = -135

local Y_IN_HEADER = -175
local Y_IN_ENABLE = -205
local Y_IN_NAMES = -235
local Y_IN_LANG = -270

local Y_IN_CH_LABEL = -340
local Y_IN_CH_ROW1 = -365
local Y_IN_CH_ROW2 = -395
local Y_IN_CH_ROW3 = -425

local Y_OUT_HEADER = -460
local Y_OUT_ENABLE = -490
local Y_OUT_LANG = -525

local Y_CH_LABEL = -595
local Y_CH_ROW1 = -620
local Y_CH_ROW2 = -650
local Y_CH_ROW3 = -680

-- API Settings Section
CreateHeader("API Settings", Y_API_HEADER)

local apiLabel = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
apiLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 25, Y_API_LABEL)
apiLabel:SetText("WoWTranslate API Key:")  -- Updated label

local apiDisplay = configFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
apiDisplay:SetPoint("LEFT", apiLabel, "RIGHT", 10, 0)
apiDisplay:SetWidth(200)
apiDisplay:SetJustifyH("LEFT")
configFrame.elements.apiDisplay = apiDisplay

local apiEditBg = CreateFrame("Frame", nil, configFrame)
apiEditBg:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 25, Y_API_EDIT)
apiEditBg:SetWidth(280)
apiEditBg:SetHeight(26)
apiEditBg:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
apiEditBg:SetBackdropColor(0, 0, 0, 0.8)

local apiEdit = CreateFrame("EditBox", nil, apiEditBg)
apiEdit:SetPoint("TOPLEFT", 6, -6)
apiEdit:SetPoint("BOTTOMRIGHT", -6, 6)
apiEdit:SetFontObject(GameFontHighlight)
apiEdit:SetAutoFocus(false)
apiEdit:SetScript("OnEscapePressed", function() this:ClearFocus() end)
apiEdit:SetScript("OnEnterPressed", function() this:ClearFocus() end)
configFrame.elements.apiEdit = apiEdit

local applyApiBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
applyApiBtn:SetPoint("LEFT", apiEditBg, "RIGHT", 15, 0)
applyApiBtn:SetWidth(70)
applyApiBtn:SetHeight(26)
applyApiBtn:SetText("Apply")
applyApiBtn:SetScript("OnClick", function()
    local newKey = configFrame.elements.apiEdit:GetText()
    if newKey and newKey ~= "" then
        WoWTranslateDB.apiKey = newKey
        WoWTranslate_TempConfig.apiKey = newKey
        if WoWTranslate_API and WoWTranslate_API.SetKey then
            local success, err = WoWTranslate_API.SetKey(newKey)
            if success then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WoWTranslate] API key applied!|r")
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WoWTranslate] Failed: " .. (err or "unknown") .. "|r")
            end
        end
        configFrame.elements.apiDisplay:SetText(MaskApiKey(newKey))
        configFrame.elements.apiEdit:SetText("")
        configFrame.elements.apiEdit:ClearFocus()
    end
end)

-- Credits Display (NEW in v0.10)
local creditsLabel = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
creditsLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 25, Y_CREDITS)
creditsLabel:SetText("Credits Remaining:")

local creditsDisplay = configFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
creditsDisplay:SetPoint("LEFT", creditsLabel, "RIGHT", 10, 0)
creditsDisplay:SetWidth(100)
creditsDisplay:SetJustifyH("LEFT")
creditsDisplay:SetText("Unknown")
configFrame.elements.creditsDisplay = creditsDisplay

-- Credits warning indicator
local creditsWarning = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
creditsWarning:SetPoint("LEFT", creditsDisplay, "RIGHT", 10, 0)
creditsWarning:SetTextColor(1, 0.5, 0)  -- Orange
creditsWarning:SetText("")
configFrame.elements.creditsWarning = creditsWarning

-- Cache Savings Display (session-based)
local savingsLabel = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
savingsLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 25, Y_CREDITS - 18)
savingsLabel:SetText("Session Savings:")

local savingsDisplay = configFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
savingsDisplay:SetPoint("LEFT", savingsLabel, "RIGHT", 10, 0)
savingsDisplay:SetWidth(250)
savingsDisplay:SetJustifyH("LEFT")
savingsDisplay:SetTextColor(0.2, 0.8, 0.2)  -- Green
savingsDisplay:SetText("No cache hits yet")
configFrame.elements.savingsDisplay = savingsDisplay

-- Incoming Translation Section
CreateHeader("Incoming Translation (Chat -> You)", Y_IN_HEADER)
configFrame.elements.inEnabled = CreateCheckbox("Enable Incoming Translation", 25, Y_IN_ENABLE, "enabled", nil)
configFrame.elements.afkDisable = CreateCheckbox("Disable while AFK", 250, Y_IN_ENABLE, "disableWhileAfk", nil)
configFrame.elements.translateSystem = CreateCheckbox("Translate system/emotes", 25, Y_IN_NAMES, "translateSystemMessages", nil)
configFrame.elements.inFrom = CreateLangSelector("From:", 25, Y_IN_LANG, "incomingFromLang")
configFrame.elements.inTo = CreateLangSelector("To:", 210, Y_IN_LANG, "incomingToLang")

-- Incoming Channels Section
local inChLabel = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
inChLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 25, Y_IN_CH_LABEL)
inChLabel:SetText("Translate Incoming Channels:")

-- Row 1: Say, Yell, Whisper
configFrame.elements.inChSay = CreateCheckbox("Say", 25, Y_IN_CH_ROW1, "incomingChannels", "SAY")
configFrame.elements.inChYell = CreateCheckbox("Yell", 140, Y_IN_CH_ROW1, "incomingChannels", "YELL")
configFrame.elements.inChWhisper = CreateCheckbox("Whisper", 255, Y_IN_CH_ROW1, "incomingChannels", "WHISPER")

-- Row 2: Party, Guild, Raid
configFrame.elements.inChParty = CreateCheckbox("Party", 25, Y_IN_CH_ROW2, "incomingChannels", "PARTY")
configFrame.elements.inChGuild = CreateCheckbox("Guild", 140, Y_IN_CH_ROW2, "incomingChannels", "GUILD")
configFrame.elements.inChRaid = CreateCheckbox("Raid", 255, Y_IN_CH_ROW2, "incomingChannels", "RAID")

-- Row 3: BG, Channel
configFrame.elements.inChBG = CreateCheckbox("Battleground", 25, Y_IN_CH_ROW3, "incomingChannels", "BATTLEGROUND")
configFrame.elements.inChChannel = CreateCheckbox("World/Local", 165, Y_IN_CH_ROW3, "incomingChannels", "CHANNEL")

-- Outgoing Translation Section
CreateHeader("Outgoing Translation (You -> Chat)", Y_OUT_HEADER)
configFrame.elements.outEnabled = CreateCheckbox("Enable Outgoing Translation", 25, Y_OUT_ENABLE, "outgoingEnabled", nil)
configFrame.elements.outFrom = CreateLangSelector("From:", 25, Y_OUT_LANG, "outgoingFromLang")
configFrame.elements.outTo = CreateLangSelector("To:", 210, Y_OUT_LANG, "outgoingToLang")

-- Channels Section
local chLabel = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
chLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 25, Y_CH_LABEL)
chLabel:SetText("Outgoing Channels:")

-- Row 1: Whisper, Party, Say (spaced evenly)
configFrame.elements.chWhisper = CreateCheckbox("Whisper", 25, Y_CH_ROW1, "outgoingChannels", "WHISPER")
configFrame.elements.chParty = CreateCheckbox("Party", 140, Y_CH_ROW1, "outgoingChannels", "PARTY")
configFrame.elements.chSay = CreateCheckbox("Say", 255, Y_CH_ROW1, "outgoingChannels", "SAY")

-- Row 2: Guild, Raid, Yell (spaced evenly)
configFrame.elements.chGuild = CreateCheckbox("Guild", 25, Y_CH_ROW2, "outgoingChannels", "GUILD")
configFrame.elements.chRaid = CreateCheckbox("Raid", 140, Y_CH_ROW2, "outgoingChannels", "RAID")
configFrame.elements.chYell = CreateCheckbox("Yell", 255, Y_CH_ROW2, "outgoingChannels", "YELL")

-- Row 3: BG, Channel
configFrame.elements.chBG = CreateCheckbox("Battleground", 25, Y_CH_ROW3, "outgoingChannels", "BATTLEGROUND")
configFrame.elements.chChannel = CreateCheckbox("World/Local", 165, Y_CH_ROW3, "outgoingChannels", "CHANNEL")

-- Bottom Buttons
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
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WoWTranslate] Settings saved!|r")
    configFrame:Hide()
end)

-- ============================================================================
-- REFRESH UI FROM CONFIG
-- ============================================================================
local function RefreshUI()
    local e = configFrame.elements
    local cfg = WoWTranslate_TempConfig

    if e.apiDisplay then
        e.apiDisplay:SetText(MaskApiKey(cfg.apiKey or ""))
    end
    if e.apiEdit then
        e.apiEdit:SetText("")
    end

    -- Update credits display
    if e.creditsDisplay then
        if WoWTranslate_API and WoWTranslate_API.GetCreditsFormatted then
            e.creditsDisplay:SetText(WoWTranslate_API.GetCreditsFormatted())

            -- Show warning if credits are low
            if WoWTranslate_API.IsCreditsLow and WoWTranslate_API.IsCreditsLow() then
                e.creditsWarning:SetText("(Low - add credits soon!)")
            else
                e.creditsWarning:SetText("")
            end
        else
            e.creditsDisplay:SetText("Unknown")
            e.creditsWarning:SetText("")
        end
    end

    -- Update cache savings display
    if e.savingsDisplay then
        if WoWTranslate_API and WoWTranslate_API.GetCacheSavingsFormatted then
            e.savingsDisplay:SetText(WoWTranslate_API.GetCacheSavingsFormatted())
        else
            e.savingsDisplay:SetText("No cache hits yet")
        end
    end

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

    -- Incoming channels
    local inCh = cfg.incomingChannels or {}
    if e.inChSay then e.inChSay:SetChecked(inCh.SAY) end
    if e.inChYell then e.inChYell:SetChecked(inCh.YELL) end
    if e.inChWhisper then e.inChWhisper:SetChecked(inCh.WHISPER) end
    if e.inChParty then e.inChParty:SetChecked(inCh.PARTY) end
    if e.inChGuild then e.inChGuild:SetChecked(inCh.GUILD) end
    if e.inChRaid then e.inChRaid:SetChecked(inCh.RAID) end
    if e.inChBG then e.inChBG:SetChecked(inCh.BATTLEGROUND) end
    if e.inChChannel then e.inChChannel:SetChecked(inCh.CHANNEL) end

    -- Outgoing channels
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

-- ============================================================================
-- CREDITS UPDATE TIMER
-- ============================================================================
-- Update credits display periodically when config is open
local creditsUpdateFrame = CreateFrame("Frame")
local creditsUpdateElapsed = 0

creditsUpdateFrame:SetScript("OnUpdate", function()
    if not configFrame:IsVisible() then return end

    creditsUpdateElapsed = creditsUpdateElapsed + arg1
    if creditsUpdateElapsed >= 2 then  -- Update every 2 seconds
        creditsUpdateElapsed = 0

        local e = configFrame.elements
        if WoWTranslate_API then
            -- Update credits
            if e.creditsDisplay and WoWTranslate_API.GetCreditsFormatted then
                e.creditsDisplay:SetText(WoWTranslate_API.GetCreditsFormatted())
            end
            if e.creditsWarning then
                if WoWTranslate_API.IsCreditsLow and WoWTranslate_API.IsCreditsLow() then
                    e.creditsWarning:SetText("(Low - add credits soon!)")
                else
                    e.creditsWarning:SetText("")
                end
            end
            -- Update cache savings
            if e.savingsDisplay and WoWTranslate_API.GetCacheSavingsFormatted then
                e.savingsDisplay:SetText(WoWTranslate_API.GetCacheSavingsFormatted())
            end
        end
    end
end)

-- ============================================================================
-- PUBLIC API
-- ============================================================================
function WoWTranslate_ShowConfig()
    LoadTempConfig()
    RefreshUI()
    if WoWTranslate_API and WoWTranslate_API.FetchCredits then
        WoWTranslate_API.FetchCredits()
    end
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
