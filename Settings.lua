-- ================================================================
-- EINSTELLUNGS-FENSTER
-- ================================================================
local _, ns = ...
local L = ns.L

local GetAccent               = ns.GetAccent
local RegisterAccentRefresher = ns.RegisterAccentRefresher
local ApplyBrokerIcon         = ns.ApplyBrokerIcon
local BROKER_DEFS             = ns.BROKER_DEFS
local SCOPE_ORDER             = ns.SCOPE_ORDER
local MakeToggle              = ns.MakeToggle
local MakeBtn                 = ns.MakeBtn
local MakeSlider              = ns.MakeSlider
local MakeDropdown            = ns.MakeDropdown
local MakeSep                 = ns.MakeSep

local E_BG_R, E_BG_G, E_BG_B             = ns.E_BG_R, ns.E_BG_G, ns.E_BG_B
local E_BRD_A                            = ns.E_BRD_A
local E_BTN_BG_R, E_BTN_BG_G, E_BTN_BG_B = ns.E_BTN_BG_R, ns.E_BTN_BG_G, ns.E_BTN_BG_B
local E_BTN_BG_A                         = ns.E_BTN_BG_A
local E_BTN_BRD_A                        = ns.E_BTN_BRD_A

local settingsFrame = nil

local function RefreshSettings()
    local DB = ns.DB
    if not settingsFrame or not settingsFrame:IsShown() or not DB then return end
    local maxWin = ns.GetDetailsWinCount()

    -- LEISTE-Sektion
    settingsFrame._lockToggle:Set(DB.bar.locked)
    settingsFrame._lockLbl:SetText(DB.bar.locked and L.LOCKED or L.UNLOCKED)
    settingsFrame._anchorToggle:Set(DB.bar.anchorToDetails)
    if settingsFrame._offsetBox and not settingsFrame._offsetBox:HasFocus() then
        settingsFrame._offsetBox:SetText(tostring(DB.bar.offsetY or 2))
    end
    if settingsFrame._mmToggle then
        settingsFrame._mmToggle:Set(not DB.bar.minimapHide)
    end
    if settingsFrame._langDD then
        local getText = function(opt) return opt.text or L.LANG_AUTO end
        settingsFrame._langDD:SetTexts(getText)
        settingsFrame._langDD:SetValue(DB.bar.language or "auto", getText)
    end
    if settingsFrame._texDD then
        settingsFrame._texDD:SetValue(DB.bar.bgTexture or ns.DEFAULT_TEXTURE)
    end
    if settingsFrame._fontDD then
        settingsFrame._fontDD:SetValue(DB.bar.font or ns.DEFAULT_FONT)
    end
    settingsFrame._winInfoLbl:SetText(string.format(L.ACTIVE_WINDOWS, maxWin))
    if settingsFrame._colorSwatch then
        local r,g,b = GetAccent(); settingsFrame._colorSwatch:SetColorTexture(r,g,b,1)
    end
    if settingsFrame._bgSlider then
        local a = DB.bar.bgAlpha or 0.94
        settingsFrame._bgSlider:Set(a)
        if settingsFrame._bgPct then settingsFrame._bgPct:SetText(math.floor(a*100+0.5).."%") end
    end

    -- FENSTER-Scope-Zeilen: nur so viele zeigen wie es Fenster gibt
    DB.bar.winScope = DB.bar.winScope or {}
    for i, wr in ipairs(settingsFrame._winScopeRows or {}) do
        if i <= maxWin then
            wr.lbl:Show()
            local cur = DB.bar.winScope[i] or "always"
            for scope, btn in pairs(wr.btns) do
                btn:Show(); btn:SetActive(scope == cur)
            end
            local dcur = (DB.bar.winDisplay and DB.bar.winDisplay[i]) or "both"
            for mode, db in pairs(wr.dispBtns or {}) do
                db:Show(); db:SetActive(mode == dcur)
            end
        else
            wr.lbl:Hide()
            for _, btn in pairs(wr.btns) do btn:Hide() end
            for _, db in pairs(wr.dispBtns or {}) do db:Hide() end
        end
    end

    -- BROKER-Reihen
    for _, def in ipairs(BROKER_DEFS) do
        local key = def.key; local cfg = DB[key] or {}
        local row = settingsFrame._rows[key]
        if row then
            row.toggle:Set(cfg.enabled or false)

            -- Bars-Buttons: nur so viele zeigen wie es Fenster gibt
            local wins = cfg.windows or {}
            for wn, wb in pairs(row.winBtns or {}) do
                if wn <= maxWin then
                    wb:Show(); wb:SetActive(wins[wn] == true)
                else
                    wb:Hide()
                end
            end

            if not cfg.enabled then
                row.statusLbl:SetText(L.STATUS_OFF); row.statusLbl:SetTextColor(0.5,0.5,0.5)
            else
                local ar,ag,ab = GetAccent()
                row.statusLbl:SetText(L.STATUS_ON); row.statusLbl:SetTextColor(ar,ag,ab)
            end
        end
    end
end
ns.RefreshSettings = RefreshSettings

-- Akzentfarbe überall live anwenden (Bars + Settings-Chrome + Toggles + Status).
function ns.ApplyAccentAll()
    ns.RunAccentRefreshers()
    ns.RefreshAccentOnBars()
    RefreshSettings()
end

local function BuildSettingsFrame()
    -- ── Layout-Raster ───────────────────────────────────────────
    -- Alles hängt an diesen Konstanten: PAD = Außenabstand, zwei
    -- gleich breite Spalten für die Optionszeilen (Label links,
    -- Control rechtsbündig in der Spalte).
    local PAD     = 20
    local W       = 640
    local COL_GAP = 28
    local COL_W   = (W - 2*PAD - COL_GAP) / 2   -- Breite einer Optionsspalte
    local COL2_X  = PAD + COL_W + COL_GAP
    local OPT_H   = 30    -- Höhe einer Optionszeile
    local SEC_GAP = 14    -- Luft zwischen Sektionen

    -- Broker-Tabelle: Spalten-X
    local ROW_H   = 30
    local TOG_X   = PAD + 300                  -- "Aktiv"
    local STAT_X  = TOG_X + 64                 -- "Status"
    local BARS_W  = 4*22 + 3*6                 -- 4 Buttons à 22px, 6px Lücke
    local BARS_X  = W - PAD - BARS_W           -- "Bars" (rechtsbündig)

    local f = CreateFrame("Frame","DSBSettings",UIParent)
    f:SetSize(W, 400); f:SetPoint("CENTER")   -- Höhe wird am Ende exakt gesetzt
    f:SetFrameStrata("HIGH"); f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",f.StartMoving); f:SetScript("OnDragStop",f.StopMovingOrSizing)
    f:SetClampedToScreen(true)

    -- Hintergrund
    local bg = f:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(E_BG_R,E_BG_G,E_BG_B,0.98)

    -- Rand
    for _,pt in ipairs({{"TOPLEFT","TOPRIGHT"},{"BOTTOMLEFT","BOTTOMRIGHT"},
                        {"TOPLEFT","BOTTOMLEFT"},{"TOPRIGHT","BOTTOMRIGHT"}}) do
        local t=f:CreateTexture(nil,"BORDER"); t:SetPoint(pt[1]); t:SetPoint(pt[2])
        if pt[1]=="TOPLEFT" and pt[2]=="TOPRIGHT" or pt[1]=="BOTTOMLEFT" and pt[2]=="BOTTOMRIGHT" then
            t:SetHeight(1) else t:SetWidth(1) end
        t:SetColorTexture(1,1,1,E_BRD_A)
    end

    -- Akzentstreifen oben (folgt der gewählten Farbe)
    local al=f:CreateTexture(nil,"BORDER")
    al:SetPoint("TOPLEFT",1,-1); al:SetPoint("TOPRIGHT",-1,-1)
    al:SetHeight(2)
    do local r,g,b=GetAccent(); al:SetColorTexture(r,g,b,0.85) end
    RegisterAccentRefresher(function() local r,g,b=GetAccent(); al:SetColorTexture(r,g,b,0.85) end)

    -- Titel
    local title=f:CreateFontString(nil,"OVERLAY","GameFontHighlightLarge")
    title:SetPoint("TOPLEFT",PAD,-16); title:SetText("Details! QuickBtnBar")
    title:SetTextColor(1,1,1,0.92)

    -- Eigener Schließen-Button
    local close=MakeBtn(f,"X",22,22)
    close:SetPoint("TOPRIGHT",-8,-8)
    close._lbl:SetTextColor(1,0.4,0.4,0.9)
    close:SetScript("OnClick",function() f:Hide() end)

    local function AccentLabel(fs)
        do local r,g,b=GetAccent(); fs:SetTextColor(r,g,b,0.9) end
        RegisterAccentRefresher(function() local r,g,b=GetAccent(); fs:SetTextColor(r,g,b,0.9) end)
    end

    -- Laufender y-Cursor (negativ, von oben). Sektionen schieben ihn weiter.
    local y = -44

    -- Sektions-Kopf: Trennlinie + Überschrift in Akzentfarbe
    local function Section(text)
        MakeSep(f, PAD, PAD, y)
        local l=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        l:SetPoint("TOPLEFT",PAD,y-8); l:SetText(text); AccentLabel(l)
        y = y - 28
        return l
    end

    -- Optionszeile: Label links in der Spalte, Control rechtsbündig.
    -- col = 1|2, row = 0-basiert (relativ zum Sektionsbeginn `top`).
    local function OptLabel(text, col, top, row)
        local x = (col == 2) and COL2_X or PAD
        local oy = top - row*OPT_H
        local l=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        l:SetPoint("TOPLEFT", x, oy - 9)
        l:SetText(text); l:SetTextColor(1,1,1,0.75)
        return l, x, oy
    end
    local function PlaceRight(ctrl, col, top, row, ctrlH)
        local x = (col == 2) and COL2_X or PAD
        ctrl:SetPoint("TOPRIGHT", f, "TOPLEFT", x + COL_W, (top - row*OPT_H) - math.floor((OPT_H - (ctrlH or 18))/2))
    end

    -- ── LEISTE ──────────────────────────────────────────────────
    Section(L.SECTION_BAR)
    local secTop = y

    -- Zeile 0: Gesperrt | An Details andocken
    local lockLbl = OptLabel(L.LOCKED, 1, secTop, 0)
    local lockToggle = MakeToggle(f, function(on) ns.SetLocked(on); RefreshSettings() end)
    PlaceRight(lockToggle, 1, secTop, 0, 18)

    OptLabel(L.ANCHOR, 2, secTop, 0)
    local anchorToggle = MakeToggle(f, function(on)
        if ns.DB then ns.DB.bar.anchorToDetails=on; ns.Relayout(); RefreshSettings() end
    end)
    PlaceRight(anchorToggle, 2, secTop, 0, 18)

    -- Zeile 1: Farbe | Hintergrund-Transparenz
    OptLabel(L.ACCENT_COLOR, 1, secTop, 1)
    local swatch=CreateFrame("Button",nil,f)
    swatch:SetSize(40,18)
    PlaceRight(swatch, 1, secTop, 1, 18)
    local swBrd=swatch:CreateTexture(nil,"BACKGROUND"); swBrd:SetAllPoints(); swBrd:SetColorTexture(1,1,1,0.3)
    local swTex=swatch:CreateTexture(nil,"ARTWORK")
    swTex:SetPoint("TOPLEFT",1,-1); swTex:SetPoint("BOTTOMRIGHT",-1,1)
    do local r,g,b=GetAccent(); swTex:SetColorTexture(r,g,b,1) end
    swatch:SetScript("OnClick",function()
        if not ns.DB then return end
        local r,g,b = GetAccent()
        local function applyColor(nr,ng,nb)
            ns.DB.bar.accentColor = { nr, ng, nb }
            swTex:SetColorTexture(nr,ng,nb,1)
            ns.ApplyAccentAll()
        end
        local info = {
            r=r, g=g, b=b, hasOpacity=false,
            swatchFunc=function() applyColor(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc=function(prev) if prev then applyColor(prev.r or prev[1], prev.g or prev[2], prev.b or prev[3]) end end,
        }
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            ColorPickerFrame.func=info.swatchFunc; ColorPickerFrame.cancelFunc=info.cancelFunc
            ColorPickerFrame.hasOpacity=false; ColorPickerFrame:SetColorRGB(r,g,b)
            ColorPickerFrame:Hide(); ColorPickerFrame:Show()
        end
    end)

    OptLabel(L.BACKGROUND, 2, secTop, 1)
    -- Slider + Prozentwert als Gruppe rechtsbündig
    local bgPct=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    bgPct:SetTextColor(0.7,0.7,0.7); bgPct:SetWidth(34); bgPct:SetJustifyH("RIGHT")
    PlaceRight(bgPct, 2, secTop, 1, 12)
    local bgSlider=MakeSlider(f, 150, 0, 1, function(v)
        if ns.DB then ns.DB.bar.bgAlpha=v; ns.RefreshBgAlpha()
            if f._bgPct then f._bgPct:SetText(math.floor(v*100+0.5).."%") end
        end
    end)
    bgSlider:SetPoint("RIGHT", bgPct, "LEFT", -10, 0)
    f._bgSlider = bgSlider; f._bgPct = bgPct

    -- Zeile 2: Höhe (Abstand zur Details-Leiste) – Zahlenfeld + −/+
    OptLabel(L.HEIGHT_PX, 1, secTop, 2)
    local oPlus=MakeBtn(f,"+",20,20)
    PlaceRight(oPlus, 1, secTop, 2, 20)
    local offBox = CreateFrame("EditBox", nil, f)
    offBox:SetSize(40,20); offBox:SetAutoFocus(false)
    offBox:SetFontObject(GameFontHighlightSmall); offBox:SetJustifyH("CENTER")
    offBox:SetPoint("RIGHT", oPlus, "LEFT", -2, 0)
    local obBg = offBox:CreateTexture(nil,"BACKGROUND")
    obBg:SetAllPoints(); obBg:SetColorTexture(E_BTN_BG_R,E_BTN_BG_G,E_BTN_BG_B,E_BTN_BG_A)
    local obBrd = offBox:CreateTexture(nil,"BORDER")
    obBrd:SetAllPoints(); obBrd:SetColorTexture(1,1,1,E_BTN_BRD_A)
    local obBrdIn = offBox:CreateTexture(nil,"ARTWORK")
    obBrdIn:SetPoint("TOPLEFT",1,-1); obBrdIn:SetPoint("BOTTOMRIGHT",-1,1)
    obBrdIn:SetColorTexture(E_BTN_BG_R,E_BTN_BG_G,E_BTN_BG_B,1)
    local function ApplyOffsetText()
        if not ns.DB then return end
        local v = tonumber(offBox:GetText())
        if v then ns.DB.bar.offsetY = math.floor(v + 0.5); ns.Relayout() end
        RefreshSettings()
    end
    offBox:SetScript("OnEnterPressed", function(self) ApplyOffsetText(); self:ClearFocus() end)
    offBox:SetScript("OnEditFocusLost", ApplyOffsetText)
    offBox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); RefreshSettings() end)
    local oMinus=MakeBtn(f,"-",20,20)
    oMinus:SetPoint("RIGHT", offBox, "LEFT", -2, 0)
    local function StepOffset(d)
        if not ns.DB then return end
        ns.DB.bar.offsetY=(ns.DB.bar.offsetY or 2)+d; ns.Relayout(); RefreshSettings()
    end
    oMinus:SetScript("OnClick",function() StepOffset(-1) end)
    oPlus:SetScript("OnClick",function() StepOffset(1) end)

    -- Zeile 2 rechts: Minimap-Button an/aus
    OptLabel(L.MINIMAP_BUTTON, 2, secTop, 2)
    local mmToggle = MakeToggle(f, function(on)
        if ns.DB then
            ns.DB.bar.minimapHide = not on
            if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
        end
    end)
    PlaceRight(mmToggle, 2, secTop, 2, 18)

    -- Zeile 3: Sprache | Hintergrund-Textur
    OptLabel(L.LANGUAGE, 1, secTop, 3)
    local langDD = MakeDropdown(f, 150, ns.LANG_OPTIONS, function(value)
        if ns.SetLanguage then ns.SetLanguage(value) end
    end)
    PlaceRight(langDD, 1, secTop, 3, 20)

    OptLabel(L.TEXTURE, 2, secTop, 3)
    local texDD = ns.MakeMediaDropdown(f, 150, "statusbar", function(value)
        if ns.DB then ns.DB.bar.bgTexture = value; ns.RefreshBarBg(); RefreshSettings() end
    end)
    PlaceRight(texDD, 2, secTop, 3, 20)

    -- Zeile 4: Schriftart
    OptLabel(L.FONT, 1, secTop, 4)
    local fontDD = ns.MakeMediaDropdown(f, 150, "font", function(value)
        if ns.DB then ns.DB.bar.font = value; ns.RefreshBarFont(); RefreshSettings() end
    end)
    PlaceRight(fontDD, 1, secTop, 4, 20)

    f._lockToggle = lockToggle; f._lockLbl = lockLbl
    f._anchorToggle = anchorToggle; f._offsetBox = offBox; f._colorSwatch = swTex
    f._mmToggle = mmToggle; f._langDD = langDD
    f._texDD = texDD; f._fontDD = fontDD

    y = secTop - 5*OPT_H - SEC_GAP

    -- ── FENSTER (Sichtbarkeit je Details-Fenster) ───────────────
    Section(L.SECTION_WINDOWS)
    local winInfo=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    winInfo:SetPoint("TOPRIGHT",-PAD,y+20); winInfo:SetText(string.format(L.ACTIVE_WINDOWS, 1))
    winInfo:SetTextColor(0.55,0.55,0.55)
    f._winInfoLbl = winInfo

    local WROW_H   = 26
    local SCOPE_BW = 70   -- einheitliche Breite aller Scope-Buttons

    f._winScopeRows = {}
    for i = 1, 4 do
        local ry = y - (i-1)*WROW_H
        local lbl=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT",PAD,ry-7); lbl:SetText(string.format(L.WINDOW, i)); lbl:SetWidth(80)
        lbl:SetJustifyH("LEFT"); lbl:SetTextColor(1,1,1,0.75)

        -- Anzeige-Modus (Icon / Label / Beides) – linke Gruppe
        local dispBtns = {}
        local dx = PAD + 90
        for _, mode in ipairs({ "icon", "label", "both" }) do
            local db = MakeBtn(f, L["DISP_"..mode], 50, 19)
            db:SetPoint("TOPLEFT", dx, ry-3)
            db.win=i; db.mode=mode
            db:SetScript("OnClick",function(self)
                if ns.DB then
                    ns.DB.bar.winDisplay = ns.DB.bar.winDisplay or {}
                    ns.DB.bar.winDisplay[self.win] = self.mode
                    ns.UpdateAll(); RefreshSettings()
                end
            end)
            dispBtns[mode]=db; dx = dx + 50 + 4
        end

        -- Sichtbarkeits-Scope – rechte Gruppe, rechtsbündig
        local btns = {}
        local bx = W - PAD - 4*SCOPE_BW - 3*6
        for _, scope in ipairs(SCOPE_ORDER) do
            local btn = MakeBtn(f, L["SCOPE_"..scope], SCOPE_BW, 19)
            btn:SetPoint("TOPLEFT",bx,ry-3)
            btn.win=i; btn.scope=scope
            btn:SetScript("OnClick",function(self)
                if ns.DB then ns.DB.bar.winScope[self.win]=self.scope; ns.UpdateAll(); RefreshSettings() end
            end)
            btns[scope]=btn; bx = bx + SCOPE_BW + 6
        end
        f._winScopeRows[i] = { lbl=lbl, btns=btns, dispBtns=dispBtns }
    end
    y = y - 4*WROW_H - SEC_GAP

    -- ── BROKER ──────────────────────────────────────────────────
    Section(L.SECTION_BROKER)

    local function ColH(text,x,hy,justifyW)
        local l=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        l:SetPoint("TOPLEFT",x,hy); l:SetText(text); l:SetTextColor(0.5,0.5,0.5)
        if justifyW then l:SetWidth(justifyW); l:SetJustifyH("LEFT") end
        return l
    end
    ColH(L.COL_BROKER, PAD,    y)
    ColH(L.COL_ACTIVE, TOG_X,  y)
    ColH(L.COL_STATUS, STAT_X, y)
    ColH(L.COL_BARS,   BARS_X, y)
    y = y - 16
    MakeSep(f,PAD,PAD,y, 0.08)
    y = y - 6

    f._rows = {}
    for i,def in ipairs(BROKER_DEFS) do
        local key = def.key
        local ry  = y - (i-1)*ROW_H
        local cy  = ry - ROW_H/2    -- vertikale Mitte der Zeile
        local row = {}

        local ico=f:CreateTexture(nil,"OVERLAY")
        ico:SetSize(16,16); ico:SetPoint("TOPLEFT",PAD,cy+8)
        ApplyBrokerIcon(ico, def)   -- Details-eigenes Icon (wie in der Leiste)
        local nl=f:CreateFontString(nil,"OVERLAY","GameFontNormal")
        nl:SetPoint("LEFT",ico,"RIGHT",8,0); nl:SetWidth(TOG_X-PAD-40)
        nl:SetJustifyH("LEFT"); nl:SetText(def.label)

        local tog = MakeToggle(f, function(on)
            if ns.DB then ns.DB[key].enabled=on; ns.UpdateAll(); RefreshSettings() end
        end)
        tog:SetPoint("TOPLEFT",TOG_X,cy+9)
        row.toggle = tog

        local sl=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        sl:SetPoint("TOPLEFT",STAT_X,cy+5); sl:SetWidth(BARS_X-STAT_X-10)
        sl:SetJustifyH("LEFT"); row.statusLbl=sl

        -- Bars (auf welchen Fenster-Leisten der Broker erscheint)
        row.winBtns = {}
        for wn = 1, 4 do
            local wb = MakeBtn(f, tostring(wn), 22, 19)
            wb:SetPoint("TOPLEFT", BARS_X + (wn-1)*28, cy+9)
            wb.key = key; wb.wn = wn
            wb:SetScript("OnClick", function(self)
                if not ns.DB then return end
                local wins = ns.DB[self.key].windows or {}
                wins[self.wn] = (not wins[self.wn]) and true or nil
                ns.DB[self.key].windows = wins
                ns.UpdateAll(); RefreshSettings()
            end)
            row.winBtns[wn] = wb
        end

        if i < #BROKER_DEFS then MakeSep(f, PAD, PAD, ry-ROW_H, 0.04) end
        f._rows[key] = row
    end
    y = y - #BROKER_DEFS*ROW_H

    -- Hinweis
    local hint=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    hint:SetPoint("BOTTOM",0,12)
    hint:SetText(L.HINT)
    hint:SetTextColor(0.35,0.35,0.35)

    f:SetHeight(-y + 34)

    f:Hide(); settingsFrame=f
end

function ns.ShowSettings()
    if not settingsFrame then BuildSettingsFrame() end
    -- Erst anzeigen, DANN befüllen: RefreshSettings bricht ab, wenn das Frame
    -- noch nicht sichtbar ist – daher muss Show() zuerst kommen.
    settingsFrame:Show()
    RefreshSettings()
end

function ns.ToggleSettings()
    if settingsFrame and settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        ns.ShowSettings()
    end
end

-- Sprache wechseln: Locale aktivieren und Einstellungsfenster neu aufbauen
-- (die Texte sind dort fest verdrahtet). Frames sind nicht löschbar – das
-- alte Fenster wird versteckt und ersetzt.
function ns.SetLanguage(value)
    if not ns.DB then return end
    ns.DB.bar.language = value
    ns.SetActiveLocale()
    local wasShown = settingsFrame and settingsFrame:IsShown()
    if settingsFrame then settingsFrame:Hide(); settingsFrame = nil end
    if wasShown then ns.ShowSettings() end
end
