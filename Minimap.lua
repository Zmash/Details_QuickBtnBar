-- ================================================================
-- MINIMAP-BUTTON
-- Klassischer Ring-Button: Klick öffnet die Einstellungen, Ziehen
-- verschiebt ihn um die Minimap (Winkel wird gespeichert).
-- ================================================================
local _, ns = ...
local L = ns.L

local minimapBtn = nil

local function PositionMinimapButton()
    if not minimapBtn then return end
    local angle = math.rad((ns.DB and ns.DB.bar.minimapAngle) or 220)
    local r = (Minimap:GetWidth() / 2) + 5
    minimapBtn:ClearAllPoints()
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle)*r, math.sin(angle)*r)
end

local function CreateMinimapButton()
    if minimapBtn then return end
    local b = CreateFrame("Button", "DSBMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = b:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")

    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\Icons\\ability_dualwield")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", 6, -6)

    b:SetScript("OnClick", function() ns.ToggleSettings() end)

    -- Drag: Winkel aus Cursorposition relativ zum Minimap-Zentrum
    local function DragUpdate()
        local mx, my = Minimap:GetCenter()
        local scale = Minimap:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        cx, cy = cx/scale, cy/scale
        local angle = math.deg(math.atan2(cy - my, cx - mx))
        if ns.DB then ns.DB.bar.minimapAngle = angle end
        PositionMinimapButton()
    end
    b:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", DragUpdate) end)
    b:SetScript("OnDragStop",  function(self) self:SetScript("OnUpdate", nil) end)

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Details! QuickBtnBar", 1, 1, 1)
        GameTooltip:AddLine(L.MM_CLICK, 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    minimapBtn = b
end

function ns.UpdateMinimapButton()
    if not ns.DB then return end
    if ns.DB.bar.minimapHide then
        if minimapBtn then minimapBtn:Hide() end
        return
    end
    CreateMinimapButton()
    PositionMinimapButton()
    minimapBtn:Show()
end
