-- WoWTranslate_Config.lua
-- Configuration UI panel for WoWTranslate

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
-- CREATE MAIN FRAME (bigger size)
-- ============================================================================
local configFrame = CreateFrame("Frame", "WoWTranslateConfigFrame", UIParent)
configFrame:Hide()
configFrame:SetWidth(420)
configFrame:SetHeight(580)
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
    local cb = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", configFrame, "TOPLEFT", xPos, yPos)

    local text = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)

    cb.configKey = configKey
    cb.subKey = subKey

    cb:SetScript("OnClick", function()
        local checked = this:GetChecked()
        if this.subKey then
            if not WoWTranslate_TempConfig[this.configKey] then
                WoWTranslate_TempConfig[this.configKey] = {}
            end
            WoWTranslate_TempConfig[this.configKey][this.subKey] = checked
        else
            WoWTranslate_TempConfig[this.configKey] = checked
        end
    end)

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
-- BUILD UI (with better spacing)
-- ============================================================================

-- Y positions with better spacing
local Y_API_HEADER = -50
local Y_API_LABEL = -78
local Y_API_EDIT = -100

local Y_IN_HEADER = -145
local Y_IN_ENABLE = -175
local Y_IN_LANG = -210

local Y_OUT_HEADER = -280
local Y_OUT_ENABLE = -310
local Y_OUT_LANG = -345

local Y_CH_LABEL = -415
local Y_CH_ROW1 = -440
local Y_CH_ROW2 = -470

-- API Settings Section
CreateHeader("API Settings", Y_API_HEADER)

local apiLabel = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
apiLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 25, Y_API_LABEL)
apiLabel:SetText("API Key:")

local apiDisplay = configFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
apiDisplay:SetPoint("LEFT", apiLabel, "RIGHT", 10, 0)
apiDisplay:SetWidth(220)
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

-- Incoming Translation Section
CreateHeader("Incoming Translation (Chat -> You)", Y_IN_HEADER)
configFrame.elements.inEnabled = CreateCheckbox("Enable Incoming Translation", 25, Y_IN_ENABLE, "enabled", nil)
configFrame.elements.inFrom = CreateLangSelector("From:", 25, Y_IN_LANG, "incomingFromLang")
configFrame.elements.inTo = CreateLangSelector("To:", 210, Y_IN_LANG, "incomingToLang")

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

    if e.inEnabled then e.inEnabled:SetChecked(cfg.enabled) end
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

    local ch = cfg.outgoingChannels or {}
    if e.chWhisper then e.chWhisper:SetChecked(ch.WHISPER) end
    if e.chParty then e.chParty:SetChecked(ch.PARTY) end
    if e.chSay then e.chSay:SetChecked(ch.SAY) end
    if e.chGuild then e.chGuild:SetChecked(ch.GUILD) end
    if e.chRaid then e.chRaid:SetChecked(ch.RAID) end
    if e.chYell then e.chYell:SetChecked(ch.YELL) end
end

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
