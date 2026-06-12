-- ================================================================
-- WIDGET-FABRIKEN (Panel-Stil: Toggle, Button, Slider, Dropdown, Separator)
-- ================================================================
local _, ns = ...

local GetAccent               = ns.GetAccent
local RegisterAccentRefresher = ns.RegisterAccentRefresher

local E_BG_R, E_BG_G, E_BG_B             = ns.E_BG_R, ns.E_BG_G, ns.E_BG_B
local E_BTN_BG_R, E_BTN_BG_G, E_BTN_BG_B = ns.E_BTN_BG_R, ns.E_BTN_BG_G, ns.E_BTN_BG_B
local E_BTN_BG_A                         = ns.E_BTN_BG_A
local E_BTN_BRD_A                        = ns.E_BTN_BRD_A
local E_TG_OFF_R, E_TG_OFF_G, E_TG_OFF_B = ns.E_TG_OFF_R, ns.E_TG_OFF_G, ns.E_TG_OFF_B
local E_TG_OFF_A                         = ns.E_TG_OFF_A
local E_TG_ON_A                          = ns.E_TG_ON_A

-- Einfaches Toggle (Schiebeschalter)
function ns.MakeToggle(parent, onChanged)
    local W, H = 36, 18
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(W, H)

    local track = f:CreateTexture(nil,"BACKGROUND")
    track:SetAllPoints(); f._track = track

    local border = f:CreateTexture(nil,"BORDER")
    border:SetAllPoints()
    border:SetColorTexture(1,1,1,0.08)

    local knob = f:CreateTexture(nil,"OVERLAY")
    knob:SetSize(H-4, H-4); f._knob = knob

    -- silent=true → nur visuelles Update, KEIN onChanged-Callback.
    -- Verhindert Endlos-Rekursion, wenn RefreshSettings :Set() aufruft.
    local function Apply(on, silent)
        f._on = on
        if on then
            local ar,ag,ab = GetAccent()
            track:SetColorTexture(ar, ag, ab, E_TG_ON_A)
            knob:SetColorTexture(1,1,1,1)
            knob:ClearAllPoints()
            knob:SetPoint("RIGHT", f, "RIGHT", -2, 0)
        else
            track:SetColorTexture(E_TG_OFF_R, E_TG_OFF_G, E_TG_OFF_B, E_TG_OFF_A)
            knob:SetColorTexture(1,1,1,0.5)
            knob:ClearAllPoints()
            knob:SetPoint("LEFT", f, "LEFT", 2, 0)
        end
        if onChanged and not silent then onChanged(on) end
    end

    -- Klick durch den Nutzer → Callback feuert
    f:SetScript("OnClick", function(self) Apply(not self._on) end)
    -- Programmatisches Setzen → still (kein Callback)
    f.Set = function(_, on) Apply(on, true) end
    Apply(false, true)
    -- Bei Farbwechsel ON-Zustand neu einfärben
    RegisterAccentRefresher(function()
        if f._on then local r,g,b = GetAccent(); track:SetColorTexture(r,g,b,E_TG_ON_A) end
    end)
    return f
end

-- Button (dunkler Hintergrund, subtiler Border)
function ns.MakeBtn(parent, text, w, h)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(w or 80, h or 20)

    local bg = f:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(E_BTN_BG_R,E_BTN_BG_G,E_BTN_BG_B,E_BTN_BG_A)
    f._bg = bg

    local brd = f:CreateTexture(nil,"BORDER")
    brd:SetAllPoints(); brd:SetColorTexture(1,1,1,E_BTN_BRD_A); f._brd = brd

    local brdIn = f:CreateTexture(nil,"ARTWORK")
    brdIn:SetPoint("TOPLEFT",1,-1); brdIn:SetPoint("BOTTOMRIGHT",-1,1)
    brdIn:SetColorTexture(E_BTN_BG_R,E_BTN_BG_G,E_BTN_BG_B,1)

    local lbl = f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    lbl:SetAllPoints(); lbl:SetText(text or ""); lbl:SetTextColor(1,1,1,0.7)
    f._lbl = lbl

    f:SetScript("OnEnter", function() bg:SetColorTexture(E_BTN_BG_R+0.04,E_BTN_BG_G+0.04,E_BTN_BG_B+0.04,0.85); lbl:SetTextColor(1,1,1,1) end)
    f:SetScript("OnLeave", function() bg:SetColorTexture(E_BTN_BG_R,E_BTN_BG_G,E_BTN_BG_B,E_BTN_BG_A); lbl:SetTextColor(1,1,1,0.7) end)

    f.SetActive = function(self, on)
        if on then
            local ar,ag,ab = GetAccent()
            bg:SetColorTexture(ar,ag,ab,0.25)
            brd:SetColorTexture(ar,ag,ab,0.6)
            lbl:SetTextColor(ar*1.3+0.3, ag*0.5+0.5, ab*0.5+0.5, 1)
        else
            bg:SetColorTexture(E_BTN_BG_R,E_BTN_BG_G,E_BTN_BG_B,E_BTN_BG_A)
            brd:SetColorTexture(1,1,1,E_BTN_BRD_A)
            lbl:SetTextColor(1,1,1,0.7)
        end
    end
    return f
end

-- Einfacher Slider (Track + Akzent-Füllung + Thumb)
function ns.MakeSlider(parent, w, minV, maxV, onChange)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(w, 14); s:EnableMouse(true)
    s._min, s._max, s._w = minV, maxV, w

    local track = s:CreateTexture(nil,"BACKGROUND")
    track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(4)
    track:SetColorTexture(1,1,1,0.15)

    local fill = s:CreateTexture(nil,"ARTWORK")
    fill:SetPoint("LEFT", s, "LEFT", 0, 0); fill:SetHeight(4)

    local thumb = s:CreateTexture(nil,"OVERLAY")
    thumb:SetSize(10,10)

    local function setVisual(v)
        local frac = (v - minV) / (maxV - minV)
        frac = math.max(0, math.min(1, frac))
        fill:SetWidth(math.max(1, frac * w))
        thumb:ClearAllPoints(); thumb:SetPoint("CENTER", s, "LEFT", frac * w, 0)
        local r,g,b = GetAccent()
        fill:SetColorTexture(r,g,b,0.8); thumb:SetColorTexture(r,g,b,1)
    end
    s.Set = function(_, v) s._value = v; setVisual(v) end
    s.RefreshColor = function() if s._value then setVisual(s._value) end end

    local function fromCursor()
        local left = s:GetLeft(); if not left then return end
        local cx = GetCursorPosition() / (UIParent:GetEffectiveScale() or 1)
        local frac = math.max(0, math.min(1, (cx - left) / w))
        local v = minV + frac * (maxV - minV)
        s._value = v; setVisual(v); if onChange then onChange(v) end
    end
    s:SetScript("OnMouseDown", function() fromCursor(); s:SetScript("OnUpdate", fromCursor) end)
    s:SetScript("OnMouseUp",   function() s:SetScript("OnUpdate", nil) end)
    RegisterAccentRefresher(function() s.RefreshColor() end)
    return s
end

-- Dropdown im Panel-Stil: Button zeigt die aktuelle Auswahl, Klick
-- klappt eine Liste auf. options = { {value=..., text=...}, ... }
function ns.MakeDropdown(parent, w, options, onSelect)
    local d = ns.MakeBtn(parent, "", w, 20)
    d._lbl:ClearAllPoints()
    d._lbl:SetPoint("LEFT",8,0); d._lbl:SetPoint("RIGHT",-16,0)
    d._lbl:SetJustifyH("LEFT")
    local arrow = d:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    arrow:SetPoint("RIGHT",-6,0); arrow:SetText("v"); arrow:SetTextColor(1,1,1,0.45)

    local ITEM_H = 20
    local list = CreateFrame("Frame", nil, d)
    list:SetFrameStrata("DIALOG")
    list:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -2)
    list:SetSize(w, #options*ITEM_H + 2)
    local lbg = list:CreateTexture(nil,"BACKGROUND")
    lbg:SetAllPoints(); lbg:SetColorTexture(E_BG_R,E_BG_G,E_BG_B,0.98)
    local lbrd = list:CreateTexture(nil,"BORDER")
    lbrd:SetAllPoints(); lbrd:SetColorTexture(1,1,1,E_BTN_BRD_A)
    local lbgIn = list:CreateTexture(nil,"ARTWORK")
    lbgIn:SetPoint("TOPLEFT",1,-1); lbgIn:SetPoint("BOTTOMRIGHT",-1,1)
    lbgIn:SetColorTexture(E_BG_R,E_BG_G,E_BG_B,1)
    list:Hide()

    d._items = {}
    for i, opt in ipairs(options) do
        local it = CreateFrame("Button", nil, list)
        it:SetSize(w-2, ITEM_H)
        it:SetPoint("TOPLEFT", 1, -1 - (i-1)*ITEM_H)
        local hov = it:CreateTexture(nil,"HIGHLIGHT")
        hov:SetAllPoints(); hov:SetColorTexture(1,1,1,0.08)
        local lbl = it:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        lbl:SetPoint("LEFT",7,0); lbl:SetTextColor(1,1,1,0.8)
        it._lbl = lbl; it._value = opt.value
        it:SetScript("OnClick", function()
            list:Hide()
            if onSelect then onSelect(opt.value) end
        end)
        d._items[i] = it
    end

    d:SetScript("OnClick", function() list:SetShown(not list:IsShown()) end)
    d:SetScript("OnHide",  function() list:Hide() end)

    -- Texte setzen/auffrischen (Werte können lokalisiert sein)
    d.SetTexts = function(_, getText)
        for i, it in ipairs(d._items) do
            it._lbl:SetText(getText(options[i]))
        end
    end
    d.SetValue = function(_, value, getText)
        for i, it in ipairs(d._items) do
            if it._value == value then d._lbl:SetText(getText(options[i])) end
        end
    end
    return d
end

-- Separator
function ns.MakeSep(parent, fromX, toX, y, a)
    local t = parent:CreateTexture(nil,"ARTWORK")
    t:SetHeight(1)
    t:SetPoint("TOPLEFT",  fromX or 14, y or 0)
    t:SetPoint("TOPRIGHT", -(toX or 14), y or 0)
    t:SetColorTexture(1,1,1, a or 0.06)
    return t
end
