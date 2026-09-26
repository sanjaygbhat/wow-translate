-- WoW Translate: minimap button and Addon Compartment entry
-- Left-click: options. Right-click: turn translation on/off. Drag: move.

local _, WT = ...
local L = WT.L

local button

local function StatusLine()
    local db = WT.db
    local mode = (db.mode == "accurate") and L.MODE_ACCURATE or L.MODE_QUICK
    local state = db.enabled and ("|cff20ff20" .. L.STATE_ON .. "|r") or ("|cffff4040" .. L.STATE_OFF .. "|r")
    return string.format(L.MINIMAP_STATUS, state, mode, WT.LANG_NATIVE[WT.IncomingTarget()] or "?")
end

local function ShowTooltip(owner, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_LEFT")
    GameTooltip:SetText("WoW Translate", 0.2, 0.8, 1)
    GameTooltip:AddLine(StatusLine(), 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.MINIMAP_LEFT_CLICK, 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L.MINIMAP_RIGHT_CLICK, 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

local function ToggleEnabled()
    WT.Set("enabled", not WT.db.enabled)
    WT.Print(WT.db.enabled and L.TRANSLATION_ON or L.TRANSLATION_OFF)
end

local function UpdatePosition()
    if not button then return end
    local angle = math.rad(WT.db.minimap.angle or 200)
    local radius = (Minimap:GetWidth() / 2) + 10
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function Create()
    if button or not Minimap then return end
    button = CreateFrame("Button", "WoWTranslateMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("CENTER", 0, 1)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(52, 52)
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", function(_, which)
        if which == "RightButton" then ToggleEnabled() else WT.ToggleOptions() end
    end)
    button:SetScript("OnEnter", function(self) ShowTooltip(self) end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / scale, cy / scale
            WT.db.minimap.angle = math.deg(math.atan2(cy - my, cx - mx))
            UpdatePosition()
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        WT.Set("minimap.angle", WT.db.minimap.angle)
    end)
end

local function Refresh()
    if WT.db.minimap.hide then
        if button then button:Hide() end
        return
    end
    Create()
    if button then
        UpdatePosition()
        button:Show()
        button.icon:SetDesaturated(not WT.db.enabled)
    end
end

WT.On("LOGIN", Refresh)
WT.On("SETTINGS_CHANGED", function(key)
    if key == "*" or key == "minimap.hide" or key == "enabled" then Refresh() end
end)

-- Addon Compartment (the addons button by the minimap). Names come from the TOC.
function WoWTranslate_OnAddonCompartmentClick(_, which)
    if which == "RightButton" then ToggleEnabled() else WT.ToggleOptions() end
end

function WoWTranslate_OnAddonCompartmentEnter(_, menuButton)
    ShowTooltip(menuButton or UIParent, "ANCHOR_LEFT")
end

function WoWTranslate_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
