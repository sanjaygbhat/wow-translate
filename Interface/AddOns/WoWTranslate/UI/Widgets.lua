-- WoW Translate: small UI building blocks
--
-- No dropdown menus on purpose: on the current Forever beta build, opening
-- an addon dropdown can crash the client (forever-bugs #157). Choices use
-- "< value >" cyclers instead, which also keep the panel one click deep.

local _, WT = ...
local W = {}
WT.Widgets = W

local function ShowTip(owner, title, body)
    if not title and not body then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if title then GameTooltip:SetText(title, 1, 1, 1) end
    if body then GameTooltip:AddLine(body, nil, nil, nil, true) end
    GameTooltip:Show()
end
W.ShowTip = ShowTip

local function HideTip() GameTooltip:Hide() end

local function Sound(key)
    local id = SOUNDKIT and SOUNDKIT[key]
    if PlaySound and id then pcall(PlaySound, id) end
end
W.Sound = Sound

-- Section title with a thin line under it.
function W.Header(parent, text, x, y, width)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3)
    line:SetSize(width or 400, 1)
    return fs
end

function W.Text(parent, text, x, y, width, template)
    local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetWidth(width or 400)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

-- Checkbox bound to get/set functions.
function W.Check(parent, label, tip, x, y, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", x, y)
    cb.Text:SetFontObject("GameFontHighlight")
    cb.Text:SetText(label)
    cb.Text:ClearAllPoints()
    cb.Text:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        Sound(self:GetChecked() and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
    end)
    cb:SetScript("OnEnter", function(self) ShowTip(self, label, tip) end)
    cb:SetScript("OnLeave", HideTip)
    cb.Refresh = function(self) self:SetChecked(get() and true or false) end
    return cb
end

-- "< Choice >" selector. options = { { value = , text = }, ... }
function W.Cycler(parent, label, tip, x, y, width, options, get, set)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", x, y)
    f:SetSize(width, 26)

    local lbl = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lbl:SetPoint("LEFT", 4, 0)
    lbl:SetText(label)

    local right = CreateFrame("Button", nil, f)
    right:SetSize(24, 24)
    right:SetPoint("RIGHT", 0, 0)
    right:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    right:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    right:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    local value = CreateFrame("Button", nil, f)
    value:SetSize(150, 24)
    value:SetPoint("RIGHT", right, "LEFT", -2, 0)
    local vtext = value:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    vtext:SetAllPoints()
    vtext:SetJustifyH("CENTER")
    value:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    local left = CreateFrame("Button", nil, f)
    left:SetSize(24, 24)
    left:SetPoint("RIGHT", value, "LEFT", -2, 0)
    left:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    left:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    left:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    local function index()
        local cur = get()
        for i, o in ipairs(options) do if o.value == cur then return i end end
        return 1
    end
    local function step(d)
        local i = index() + d
        if i < 1 then i = #options elseif i > #options then i = 1 end
        set(options[i].value)
        f:Refresh()
        Sound("U_CHAT_SCROLL_BUTTON")
    end
    left:SetScript("OnClick", function() step(-1) end)
    right:SetScript("OnClick", function() step(1) end)
    value:SetScript("OnClick", function(_, button) step(button == "RightButton" and -1 or 1) end)
    value:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    for _, w in ipairs({ left, right, value }) do
        w:SetScript("OnEnter", function(self) ShowTip(self, label, tip) end)
        w:SetScript("OnLeave", HideTip)
    end

    function f:Refresh()
        local o = options[index()]
        vtext:SetText(o and (type(o.text) == "function" and o.text() or o.text) or "?")
    end
    function f:SetEnabled(on)
        local a = on and 1 or 0.4
        f:SetAlpha(a)
        left:SetEnabled(on); right:SetEnabled(on); value:SetEnabled(on)
    end
    return f
end

function W.Button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 100, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

-- Big selectable card used for the two translation modes.
function W.ModeCard(parent, x, y, width, height, title, body, badge, onClick)
    local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
    card:SetPoint("TOPLEFT", x, y)
    card:SetSize(width, height)
    card:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    local t = card:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 12, -10)
    t:SetText(title)
    local bd = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bd:SetPoint("LEFT", t, "RIGHT", 8, 0)
    bd:SetText(badge)
    local d = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
    d:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    d:SetJustifyH("LEFT")
    d:SetJustifyV("TOP")
    d:SetSpacing(2)
    d:SetText(body)
    local check = card:CreateTexture(nil, "OVERLAY")
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetSize(24, 24)
    check:SetPoint("TOPRIGHT", -10, -9)
    card:SetScript("OnClick", onClick)
    card:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    function card:SetSelected(on)
        if on then
            self:SetBackdropColor(0.05, 0.25, 0.4, 0.9)
            self:SetBackdropBorderColor(0.2, 0.8, 1, 1)
            check:Show()
        else
            self:SetBackdropColor(0, 0, 0, 0.6)
            self:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            check:Hide()
        end
    end
    card.body = d
    return card
end
