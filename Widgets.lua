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

-- Medien-Dropdown (LibSharedMedia): scrollbare Liste mit Vorschau.
-- mediaType = "font" | "statusbar". Werte sind LSM-Namen (Strings).
-- onSelect(name) wird beim Auswählen aufgerufen.
function ns.MakeMediaDropdown(parent, w, mediaType, onSelect)
    local LSM = ns.LSM
    local d = ns.MakeBtn(parent, "", w, 20)
    d._lbl:ClearAllPoints()
    d._lbl:SetPoint("LEFT",8,0); d._lbl:SetPoint("RIGHT",-16,0)
    d._lbl:SetJustifyH("LEFT")
    local arrow = d:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    arrow:SetPoint("RIGHT",-6,0); arrow:SetText("v"); arrow:SetTextColor(1,1,1,0.45)

    -- Vorschau-Textur als Innenfüllung des geschlossenen Buttons (nur statusbar).
    -- ARTWORK-Sublevel 1, damit sie über der MakeBtn-Innenfläche (ARTWORK 0) liegt,
    -- aber unter dem OVERLAY-Label.
    local prev
    if mediaType == "statusbar" then
        prev = d:CreateTexture(nil,"ARTWORK",nil,1)
        prev:SetPoint("TOPLEFT",1,-1); prev:SetPoint("BOTTOMRIGHT",-1,1)
    end

    local ITEM_H, MAXROWS, SEARCH_H = 22, 10, 22

    -- Aufklapp-Liste mit Rahmen + Suchfeld + ScrollFrame
    local list = CreateFrame("Frame", nil, d)
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -2)
    local lbg = list:CreateTexture(nil,"BACKGROUND")
    lbg:SetAllPoints(); lbg:SetColorTexture(E_BG_R,E_BG_G,E_BG_B,0.98)
    local lbrd = list:CreateTexture(nil,"BORDER")
    lbrd:SetAllPoints(); lbrd:SetColorTexture(1,1,1,E_BTN_BRD_A)
    local lbgIn = list:CreateTexture(nil,"ARTWORK")
    lbgIn:SetPoint("TOPLEFT",1,-1); lbgIn:SetPoint("BOTTOMRIGHT",-1,1)
    lbgIn:SetColorTexture(E_BG_R,E_BG_G,E_BG_B,1)

    -- Suchfeld oben
    local search = CreateFrame("EditBox", nil, list)
    search:SetPoint("TOPLEFT",1,-1); search:SetPoint("TOPRIGHT",-1,-1)
    search:SetHeight(SEARCH_H); search:SetAutoFocus(false)
    search:SetFontObject(GameFontHighlightSmall); search:SetTextInsets(7,7,0,0)
    local sLine = search:CreateTexture(nil,"OVERLAY")
    sLine:SetPoint("BOTTOMLEFT",1,0); sLine:SetPoint("BOTTOMRIGHT",-1,0)
    sLine:SetHeight(1); sLine:SetColorTexture(1,1,1,0.12)
    local sHint = search:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
    sHint:SetPoint("LEFT",8,0); sHint:SetText(ns.L.SEARCH); sHint:SetTextColor(0.5,0.5,0.5)

    local scroll = CreateFrame("ScrollFrame", nil, list)
    scroll:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -1, 1)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(w-2)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxS = math.max(0, content:GetHeight() - self:GetHeight())
        local nv = math.min(maxS, math.max(0, self:GetVerticalScroll() - delta*ITEM_H*2))
        self:SetVerticalScroll(nv)
    end)
    list:SetScript("OnHide", function() search:ClearFocus() end)  -- Tastatur freigeben
    list:Hide()

    d._items = {}
    -- Namen nach Filter (Teilstring, case-insensitiv) holen
    local function FilteredNames(filter)
        local all = (LSM and LSM:List(mediaType)) or {}
        if not filter or filter == "" then return all end
        local lf = filter:lower()
        local out = {}
        for _, n in ipairs(all) do
            if n:lower():find(lf, 1, true) then out[#out+1] = n end
        end
        return out
    end

    local function Rebuild(filter)
        local names = FilteredNames(filter)
        local rows  = #names
        d._firstName = names[1]
        content:SetHeight(math.max(rows*ITEM_H, 1))
        local visible = math.min(math.max(rows,1), MAXROWS)
        list:SetSize(w, SEARCH_H + visible*ITEM_H + 2)
        scroll:SetVerticalScroll(0)
        for i, name in ipairs(names) do
            local it = d._items[i]
            if not it then
                it = CreateFrame("Button", nil, content)
                it:SetSize(w-2, ITEM_H)
                local hov = it:CreateTexture(nil,"HIGHLIGHT")
                hov:SetAllPoints(); hov:SetColorTexture(1,1,1,0.10)
                if mediaType == "statusbar" then
                    local tex = it:CreateTexture(nil,"BACKGROUND")
                    tex:SetPoint("TOPLEFT",2,-2); tex:SetPoint("BOTTOMRIGHT",-2,2)
                    it._tex = tex
                end
                it._lbl = it:CreateFontString(nil,"OVERLAY")
                it._lbl:SetPoint("LEFT",8,0)
                d._items[i] = it
            end
            it:SetPoint("TOPLEFT", 0, -(i-1)*ITEM_H)
            local path = LSM and LSM:Fetch(mediaType, name)
            if mediaType == "font" then
                it._lbl:SetFont(path or ns.FALLBACK_FONT, 14, "")
                it._lbl:SetText(name); it._lbl:SetTextColor(1,1,1,0.9)
            else
                it._lbl:SetFont(ns.FALLBACK_FONT, 12, "OUTLINE")
                it._lbl:SetText(name); it._lbl:SetTextColor(1,1,1,0.95)
                if it._tex and path then
                    it._tex:SetTexture(path)
                    it._tex:SetVertexColor(E_BG_R, E_BG_G, E_BG_B, 0.95)
                end
            end
            it:SetScript("OnClick", function()
                list:Hide()
                if onSelect then onSelect(name) end
            end)
            it:Show()
        end
        for j = #names+1, #d._items do d._items[j]:Hide() end
    end

    -- Suchfeld-Verhalten
    search:SetScript("OnTextChanged", function(self)
        sHint:SetShown(self:GetText() == "")
        Rebuild(self:GetText())
    end)
    search:SetScript("OnEscapePressed", function(self)
        self:SetText(""); self:ClearFocus(); list:Hide()
    end)
    search:SetScript("OnEnterPressed", function(self)
        if d._firstName then
            list:Hide()
            if onSelect then onSelect(d._firstName) end
        end
    end)

    d:SetScript("OnClick", function()
        if list:IsShown() then
            list:Hide()
        else
            search:SetText("")          -- frisch öffnen → ganze Liste
            Rebuild("")
            list:Show()
            search:SetFocus()           -- direkt lostippen können
        end
    end)
    d:SetScript("OnHide", function() list:Hide() end)

    -- Aktuellen Wert im geschlossenen Button samt Vorschau anzeigen
    d.SetValue = function(_, name)
        d._lbl:SetText(name or "")
        if mediaType == "font" then
            local path = LSM and LSM:Fetch("font", name)
            d._lbl:SetFont(path or ns.FALLBACK_FONT, 12, "")
        elseif prev then
            local path = LSM and LSM:Fetch("statusbar", name)
            if path then
                prev:SetTexture(path); prev:SetVertexColor(E_BG_R,E_BG_G,E_BG_B,0.9)
            else
                prev:SetTexture(nil)
            end
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
