-- ================================================================
-- LEISTE & STÜCKE (Pieces)
-- Frei-Modus: eine bewegliche Bar. Andock-Modus: eine Bar pro
-- Details-Fenster. Buttons schalten Anzeige/Segment des Fensters.
-- ================================================================
local _, ns = ...
local L = ns.L

local GetAccent          = ns.GetAccent
local ApplyBrokerIcon    = ns.ApplyBrokerIcon
local GetShortName       = ns.GetShortName
local BROKER_DEFS        = ns.BROKER_DEFS
local DEF                = ns.DEF
local GetActiveInstances = ns.GetActiveInstances
local GetDetailsWin      = ns.GetDetailsWin
local InstanceIsOverall  = ns.InstanceIsOverall
local IsWindowOverall    = ns.IsWindowOverall
local SetInstanceSegment = ns.SetInstanceSegment

local E_BG_R, E_BG_G, E_BG_B = ns.E_BG_R, ns.E_BG_G, ns.E_BG_B
local E_BRD_A                = ns.E_BRD_A
local GetBarFontPath         = ns.GetBarFontPath
local GetBarTexturePath      = ns.GetBarTexturePath
local BAR_FONT_SIZE          = ns.BAR_FONT_SIZE

-- Leiste (etwas dunkler als Panel)
local BAR_H     = 22
local ICON_SIZE = 14
local PAD_H     = 4   -- Innenpolster je Button-Seite (klein = mehr passt rein)

-- Hintergrund-Textur (getönt mit Panel-Farbe + Transparenz) auf eine Bar anwenden.
local function ApplyBarBg(b)
    if not b or not b.bg then return end
    local a = (ns.DB and ns.DB.bar.bgAlpha) or 0.94
    b.bg:SetTexture(GetBarTexturePath())
    b.bg:SetVertexColor(E_BG_R, E_BG_G, E_BG_B, a)
end

-- ── Reset-Button (X, immer rechts in der Bar) ───────────────────
local RESET_W = 18   -- Breite des X-Knopfs

-- Soll dieses Fenster den Reset-X zeigen? Frei-Bar (0) folgt Fenster 1.
local function ShouldShowReset(winIdx)
    local idx = (winIdx == 0) and 1 or winIdx
    local wr = ns.DB and ns.DB.bar.winReset
    return wr and wr[idx] and true or false
end

-- Reset-Knopf lazy an eine Bar hängen (rechtsbündig).
local function EnsureResetButton(b)
    if b.resetBtn then return b.resetBtn end
    local rb = CreateFrame("Button", nil, b)
    rb:SetSize(RESET_W, BAR_H)
    rb:SetPoint("RIGHT", b, "RIGHT", 0, 0)
    rb:SetFrameLevel(b:GetFrameLevel() + 5)

    local hov = rb:CreateTexture(nil, "BACKGROUND")
    hov:SetAllPoints(); hov:SetColorTexture(0.8, 0.1, 0.1, 0); rb._hov = hov

    local x = rb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    x:SetPoint("CENTER", 0, 0); x:SetText("X"); x:SetTextColor(1, 0.4, 0.4, 0.9); rb._x = x

    rb:SetScript("OnEnter", function(self)
        self._hov:SetColorTexture(0.8, 0.1, 0.1, 0.30)
        self._x:SetTextColor(1, 0.75, 0.75, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L.RESET_TITLE, 1, 1, 1)
        GameTooltip:AddLine(L.RESET_DESC, 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    rb:SetScript("OnLeave", function(self)
        self._hov:SetColorTexture(0.8, 0.1, 0.1, 0)
        self._x:SetTextColor(1, 0.4, 0.4, 0.9)
        GameTooltip:Hide()
    end)
    rb:SetScript("OnClick", function() ns.ResetDetailsData() end)

    b.resetBtn = rb
    return rb
end

-- Reset-Knopf je nach Fenster-Einstellung zeigen/verstecken.
-- Rückgabe: belegte Breite rechts (für die Stück-Anordnung).
local function UpdateResetButton(b, winIdx)
    if not ShouldShowReset(winIdx) then
        if b.resetBtn then b.resetBtn:Hide() end
        return 0
    end
    EnsureResetButton(b):Show()
    return RESET_W
end

-- ── State ───────────────────────────────────────────────────────
local useOverall   = {}
local pieces       = {}     -- [key] = { [winIdx]=Frame }
local bars         = {}     -- [winIdx] = Bar-Frame (Andock-Modus)
local freeBar      = nil    -- einzelne Bar im Frei-Modus
local isReordering = false  -- true während ein Stück per Drag umsortiert wird

-- Letztes Layout-Ergebnis (für leichtes Werte-Update ohne Voll-Neuaufbau)
local activeLayout = nil    -- { mode, bars={ {bar,winIdx,inst,keys} } }
local lastWinCount = -1     -- zuletzt gesehene Anzahl aktiver Fenster

for _, d in ipairs(BROKER_DEFS) do useOverall[d.key] = false end

-- Broker aktiviert? (Sichtbarkeit/Scope läuft PRO FENSTER, nicht pro Broker)
local function BrokerIsActive(key)
    if not ns.DB then return true end
    local cfg = ns.DB[key]
    return cfg and cfg.enabled and true or false
end

-- Soll die Leiste dieses Fensters im aktuellen Gebiet sichtbar sein?
local function WindowScopeActive(winIdx)
    if not ns.DB or not ns.DB.bar.winScope then return true end
    local s = ns.DB.bar.winScope[winIdx] or "always"
    if s == "always" then return true end
    local z = ns.GetZoneType()
    if s == "dungeon"  then return z == "dungeon" end
    if s == "raid"     then return z == "raid"    end
    if s == "instance" then return z == "dungeon" or z == "raid" end
    return true
end

-- ── Tooltip (reine Button-Erklärung – keine Werte) ──────────────
-- In Instanzen sperrt WoW die Combat-Werte für Addons, daher zeigt diese
-- Leiste keine Zahlen, sondern dient als Schnellschalter für Details.
local function BuildTooltip(tooltip, def, winIdx)
    if not Details then tooltip:AddLine(L.TT_NOT_LOADED,1,0.2,0.2); return end
    local isOverall = (winIdx and winIdx >= 1) and IsWindowOverall(winIdx) or useOverall[def.key]
    tooltip:AddDoubleLine(
        def.label,
        isOverall and L.TT_OVERALL or L.TT_CURRENT,
        1, 0.85, 0,
        isOverall and 1 or 0.4, isOverall and 0.85 or 1, 0.4
    )
    tooltip:AddLine(" ")
    tooltip:AddLine(L.TT_LEFT, 0.7,0.7,0.7)
    tooltip:AddLine(L.TT_RIGHT, 0.7,0.7,0.7)
end

-- ── Bar-Frame-Fabrik (ein Stil für freie + angedockte Bars) ─────
local Relayout       -- vorwärts-deklariert
local RefreshValues  -- vorwärts-deklariert (leichtes Werte-Update)

local function MakeBarFrame(name)
    local b = CreateFrame("Frame", name, UIParent)
    b:SetHeight(BAR_H); b:SetWidth(120)
    b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(10)
    b:SetMovable(true); b:EnableMouse(true)
    b:SetClampedToScreen(true)

    local bg = b:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints()
    b.bg = bg   -- für Live-Transparenz / Textur
    ApplyBarBg(b)

    b.accent = b:CreateTexture(nil,"BORDER")
    b.accent:SetPoint("TOPLEFT"); b.accent:SetPoint("TOPRIGHT")
    b.accent:SetHeight(1)
    local ar,ag,ab = GetAccent()
    b.accent:SetColorTexture(ar,ag,ab,0.8)

    local function Edge(p1,p2,horiz)
        local t=b:CreateTexture(nil,"BORDER"); t:SetPoint(p1); t:SetPoint(p2)
        if horiz then t:SetHeight(1) else t:SetWidth(1) end
        t:SetColorTexture(1,1,1,E_BRD_A)
    end
    Edge("BOTTOMLEFT","BOTTOMRIGHT",true)
    Edge("TOPLEFT","BOTTOMLEFT",false)
    Edge("TOPRIGHT","BOTTOMRIGHT",false)

    b.glow = b:CreateTexture(nil,"OVERLAY")
    b.glow:SetAllPoints(); b.glow:SetColorTexture(1,0.65,0.1,0.05); b.glow:Hide()

    b.pieces = {}   -- Liste der aktuell zugeordneten Stücke
    return b
end

-- Visuellen Lock-Zustand auf eine Bar anwenden
local function StyleBarLock(b, locked)
    if not b then return end
    b.glow:SetShown(not locked)
    if locked then
        local ar,ag,ab = GetAccent()
        b.accent:SetColorTexture(ar,ag,ab,0.8)
    else
        b.accent:SetColorTexture(1,0.65,0.1,0.9)  -- Orange im entsperrten Zustand
    end
end

-- Alle Bars auf die aktuelle Akzentfarbe aktualisieren
function ns.RefreshAccentOnBars()
    local ar,ag,ab = GetAccent()
    local function upd(b, locked)
        if not b then return end
        if locked then b.accent:SetColorTexture(ar,ag,ab,0.8) end
    end
    upd(freeBar, ns.DB and ns.DB.bar.locked)
    for _, b in pairs(bars) do upd(b, true) end
end

-- Hintergrund (Transparenz + Textur) aller Bars aktualisieren
function ns.RefreshBarBg()
    ApplyBarBg(freeBar)
    for _, b in pairs(bars) do ApplyBarBg(b) end
end
ns.RefreshBgAlpha = ns.RefreshBarBg   -- Alias (Transparenz nutzt denselben Pfad)

-- Schriftart-Wechsel: voller Neuaufbau wendet die Schrift auf alle
-- Stücke an (Breite ändert sich → Re-Layout nötig).
function ns.RefreshBarFont()
    if ns.Relayout then ns.Relayout() end
end

-- ── Stücke (Pieces) – parentlos erstellt, später Bars zugeordnet ─
local ReorderDrop  -- vorwärts: berechnet neue Reihenfolge nach Drag

-- Ziel-Instanz für Klick-Aktionen ermitteln.
-- winIdx >= 1: das angedockte Details-Fenster dieser Bar.
-- winIdx 0 (Frei-Modus): erstes zugewiesenes Fenster bzw. Fenster 1.
local function ResolveTargetInstance(def, winIdx)
    if winIdx and winIdx >= 1 then return GetDetailsWin(winIdx) end
    return GetDetailsWin(1)
end

-- Linksklick: Details-Fenster auf das Attribut dieses Brokers schalten.
local function SwitchPieceDisplay(def, winIdx)
    local inst = ResolveTargetInstance(def, winIdx)
    if inst and inst.SetDisplay then
        pcall(inst.SetDisplay, inst, nil, def.dAttr, def.dSubAttr)
    end
end

-- Rechtsklick: Aktuell/Gesamt umschalten.
-- Angedockt: Segment des zugehörigen Fensters umschalten (die Bar folgt
-- automatisch, weil sie aus instance.showing liest).
-- Frei-Modus: broker-eigener Overall-Schalter.
local function TogglePieceSegment(def, winIdx)
    if winIdx and winIdx >= 1 then
        local inst = GetDetailsWin(winIdx)
        if not inst then return end
        local isOverall = InstanceIsOverall(inst)   -- parser-korrekte Erkennung
        SetInstanceSegment(inst, not isOverall)
        if inst.SetDisplay then pcall(inst.SetDisplay, inst, nil, def.dAttr, def.dSubAttr) end
    else
        useOverall[def.key] = not useOverall[def.key]
        local inst = ResolveTargetInstance(def, winIdx)
        if inst then
            SetInstanceSegment(inst, useOverall[def.key])
            if inst.SetDisplay then pcall(inst.SetDisplay, inst, nil, def.dAttr, def.dSubAttr) end
        end
    end
    -- Details braucht einen Moment zum Neuberechnen; dann LEICHT aktualisieren
    -- (kein schwerer Neuaufbau → kein Ruckeln).
    C_Timer.After(0.05, function() if RefreshValues then RefreshValues() end end)
    C_Timer.After(0.30, function() if RefreshValues then RefreshValues() end end)
end

-- Anzeige-Modus dieses Stücks (Icon / Label / Beides) für sein Fenster.
-- Frei-Bar (winIdx 0) folgt der Einstellung von Fenster 1.
local function GetPieceDisplayMode(winIdx)
    local idx = (winIdx == 0) and 1 or winIdx
    local wd = ns.DB and ns.DB.bar.winDisplay
    return (wd and wd[idx]) or "both"
end

-- Schrift, Icon-/Label-Sichtbarkeit und Breite eines Stücks setzen.
-- selected=true → fette (OUTLINE) Schrift für das aktive Stück.
local function LayoutPiece(f, selected)
    local mode = GetPieceDisplayMode(f.winIdx)
    local ico, txt = f.ico, f.txt
    txt:SetFont(GetBarFontPath(), BAR_FONT_SIZE, selected and "OUTLINE" or "")

    if mode == "icon" then
        ico:Show(); txt:Hide()
        ico:ClearAllPoints(); ico:SetPoint("LEFT", f, "LEFT", PAD_H, 0)
        f:SetWidth(PAD_H + ICON_SIZE + PAD_H)
    elseif mode == "label" then
        ico:Hide(); txt:Show()
        txt:ClearAllPoints(); txt:SetPoint("LEFT", f, "LEFT", PAD_H, 0)
        f:SetWidth(PAD_H + txt:GetStringWidth() + PAD_H)
    else  -- both
        ico:Show(); txt:Show()
        ico:ClearAllPoints(); ico:SetPoint("LEFT", f, "LEFT", PAD_H, 0)
        txt:ClearAllPoints(); txt:SetPoint("LEFT", ico, "RIGHT", 3, 0)
        f:SetWidth(PAD_H + ICON_SIZE + 3 + txt:GetStringWidth() + PAD_H)
    end
end

-- Stück-Frame für (Broker, Fenster) – lazy erstellt. winIdx 0 = Frei-Bar.
local function GetPiece(def, winIdx)
    local key = def.key
    pieces[key] = pieces[key] or {}
    if pieces[key][winIdx] then return pieces[key][winIdx] end

    local f = CreateFrame("Button","DSBPiece_"..key.."_"..winIdx,UIParent)
    f:SetHeight(BAR_H); f:EnableMouse(true)
    f.def = def
    f.winIdx = winIdx
    f:RegisterForClicks("LeftButtonUp","RightButtonUp")
    f:RegisterForDrag("LeftButton")

    local hov = f:CreateTexture(nil,"BACKGROUND",nil,1)
    hov:SetAllPoints(); hov:SetColorTexture(1,1,1,0.07); hov:Hide()

    local ico = f:CreateTexture(nil,"ARTWORK")
    ico:SetSize(ICON_SIZE,ICON_SIZE); ico:SetPoint("LEFT",f,"LEFT",PAD_H,0)
    ApplyBrokerIcon(ico, def); f.ico = ico

    -- Statisches Kurz-Label (reiner Schaltbutton)
    local txt = f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    txt:SetTextColor(1,1,1,0.92)
    txt:SetText(GetShortName(def.key)); f.txt = txt
    LayoutPiece(f, false)   -- Schrift, Icon/Label-Modus, Breite

    f:SetScript("OnEnter",function(self)
        if self._dragging then return end
        hov:Show()
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        BuildTooltip(GameTooltip, self.def, self.winIdx); GameTooltip:Show()
    end)
    f:SetScript("OnLeave",function() hov:Hide(); GameTooltip:Hide() end)

    f:SetScript("OnClick",function(self,btn)
        if btn=="LeftButton" then
            SwitchPieceDisplay(self.def, self.winIdx)
        elseif btn=="RightButton" then
            TogglePieceSegment(self.def, self.winIdx)
            GameTooltip:Hide()
        end
    end)

    f:SetScript("OnDragStart",function(self)
        if not ns.DB or ns.DB.bar.locked then return end
        if ns.DB.bar.anchorToDetails then
            self._dragging = true
            isReordering = true
            self._origParent = self:GetParent()
            self:SetFrameStrata("DIALOG")
            GameTooltip:Hide()
            local _, by = self:GetCenter()
            self._dragY = by
            self:SetScript("OnUpdate", function(piece)
                local scale = UIParent:GetEffectiveScale() or 1
                local px = GetCursorPosition() / scale
                piece:ClearAllPoints()
                piece:SetPoint("CENTER", UIParent, "BOTTOMLEFT", px, (piece._dragY or 0))
            end)
        else
            if freeBar then freeBar:StartMoving() end
        end
    end)

    f:SetScript("OnDragStop",function(self)
        if self._dragging then
            self._dragging = false
            self:SetScript("OnUpdate", nil)
            self:SetFrameStrata("MEDIUM")
            isReordering = false
            ReorderDrop(self)
        elseif freeBar then
            freeBar:StopMovingOrSizing()
            local pt,_,rpt,x,y = freeBar:GetPoint()
            ns.DB.bar.savedPt=pt; ns.DB.bar.savedRpt=rpt; ns.DB.bar.savedX=x; ns.DB.bar.savedY=y
        end
    end)

    f:Hide()
    pieces[key][winIdx] = f
    return f
end

-- Markiert den Button optisch, wenn sein Fenster GENAU diese Anzeige zeigt:
-- fett (OUTLINE) + Akzentfarbe + Suffix " (O)"/" (C)" für Gesamt/Aktuell.
-- Setzt außerdem die (ggf. geänderte) Breite. Reihenfolge der Aufrufer muss
-- danach neu positionieren.
local function UpdatePieceSelection(f)
    local def, winIdx = f.def, f.winIdx
    local selected, isOverall = false, false
    if winIdx >= 1 then
        local inst = GetDetailsWin(winIdx)
        if inst then
            isOverall = InstanceIsOverall(inst)
            local att, sub = inst.GetDisplay and inst:GetDisplay()
            if att == def.dAttr and (sub == nil or sub == def.dSubAttr) then
                selected = true
            end
        end
    else
        isOverall = useOverall[def.key]
    end

    local suffix = selected and (isOverall and " (O)" or " (C)") or ""
    f.txt:SetText(GetShortName(def.key) .. suffix)

    if selected then
        local r,g,b = GetAccent()
        f.txt:SetTextColor(r,g,b,1)
    else
        f.txt:SetTextColor(1,1,1,0.6)
    end
    LayoutPiece(f, selected)   -- Schrift (fett wenn aktiv), Icon/Label-Modus, Breite
end

-- Frames innerhalb einer Bar links→rechts anordnen.
-- maxWidth (optional): Frames, die darüber hinausragen, werden ausgeblendet.
local function LayoutFramesOnBar(b, frameList, maxWidth)
    local x = 0
    for _, f in ipairs(frameList) do
        local w = f:GetWidth()
        if maxWidth and (x + w) > maxWidth + 0.5 then
            f:Hide()
        else
            f:SetParent(b); f:ClearAllPoints()
            f:SetPoint("LEFT", b, "LEFT", x, 0)
            f:Show()
            x = x + w
        end
    end
    return x
end

-- Keyliste nach gespeicherter Reihenfolge sortieren
local function SortByOrder(keyList)
    table.sort(keyList, function(a, b)
        local oa = (ns.DB and ns.DB[a] and ns.DB[a].order) or DEF[a].defOrder or 0
        local ob = (ns.DB and ns.DB[b] and ns.DB[b].order) or DEF[b].defOrder or 0
        return oa < ob
    end)
    return keyList
end

-- ── Layout: Frei-Modus (eine Bar mit allen aktiven Stücken) ─────
-- Alle Stück-Frames (aller Broker, aller Fenster) verstecken
local function HideAllPieces()
    for _, set in pairs(pieces) do
        for _, f in pairs(set) do f:Hide() end
    end
end

local function LayoutFree()
    for _, b in pairs(bars) do b:Hide() end
    if not freeBar then freeBar = MakeBarFrame("DetailsQuickBtnBarFree") end

    HideAllPieces()

    -- Aktive Broker-Buttons auf der Frei-Bar (Slot 0)
    local keys = {}
    for _, def in ipairs(BROKER_DEFS) do
        if BrokerIsActive(def.key) then
            GetPiece(def, 0)
            table.insert(keys, def.key)
        end
    end
    SortByOrder(keys)
    local frameList = {}
    for _, k in ipairs(keys) do
        local f = pieces[k][0]
        LayoutPiece(f, false)   -- Schrift/Modus/Breite aktuell halten
        table.insert(frameList, f)
    end

    local w = LayoutFramesOnBar(freeBar, frameList)
    local resetW = UpdateResetButton(freeBar, 0)
    freeBar:SetWidth(math.max(w + resetW, 40))

    freeBar:ClearAllPoints()
    if ns.DB.bar.savedPt then
        freeBar:SetPoint(ns.DB.bar.savedPt, UIParent, ns.DB.bar.savedRpt or "CENTER",
                         ns.DB.bar.savedX or 0, ns.DB.bar.savedY or 200)
    else
        freeBar:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end
    StyleBarLock(freeBar, ns.DB.bar.locked)
    freeBar:Show()

    activeLayout = { mode="free", bars={ { bar=freeBar, winIdx=0, keys=keys } } }
    lastWinCount = 0
end

-- ── Layout: Andock-Modus (eine Bar pro Details-Fenster) ─────────
-- Das Segment jeder Bar FOLGT ihrem Details-Fenster (instance.showing).
-- So zeigt derselbe Broker auf Bar 1 (Fenster=Aktuell) Aktuell und auf
-- Bar 2 (Fenster=Gesamt) Gesamt.
local function LayoutDocked()
    local instances = GetActiveInstances()
    local nWin = #instances

    if nWin == 0 then
        LayoutFree()
        return
    end

    if freeBar then freeBar:Hide() end
    HideAllPieces()

    local layoutBars = {}
    for i = 1, nWin do
        local inst = instances[i]
        local df   = inst and inst.baseframe
        if df then
            local b = bars[i]
            if not b then b = MakeBarFrame("DetailsQuickBtnBar"..i); bars[i] = b end

            -- Fenster-Scope: in diesem Gebiet gar nicht zeigen?
            if not WindowScopeActive(i) then
                b:Hide()
            else
                local winW = df:GetWidth()
                b:ClearAllPoints()
                b:SetPoint("BOTTOMLEFT", df, "TOPLEFT", ns.DB.bar.offsetX or 0, ns.DB.bar.offsetY or 2)
                b:SetWidth(winW)
                b:SetShown(df:IsShown())
                StyleBarLock(b, ns.DB.bar.locked)

                -- Broker-Buttons sammeln, die diesem Fenster zugeordnet sind
                local keys = {}
                for _, def in ipairs(BROKER_DEFS) do
                    local wins = ns.DB[def.key] and ns.DB[def.key].windows
                    if BrokerIsActive(def.key) and wins and wins[i] then
                        GetPiece(def, i)
                        table.insert(keys, def.key)
                    end
                end
                local resetW = UpdateResetButton(b, i)   -- X rechts (falls aktiv)
                SortByOrder(keys)
                local frameList = {}
                for _, k in ipairs(keys) do
                    local f = pieces[k][i]
                    UpdatePieceSelection(f)   -- Auswahl-Markierung (fett + O/C)
                    table.insert(frameList, f)
                end
                LayoutFramesOnBar(b, frameList, winW - resetW)

                table.insert(layoutBars, { bar=b, winIdx=i, inst=inst, keys=keys })
            end
        end
    end

    for idx, b in pairs(bars) do
        if idx > nWin then b:Hide() end
    end

    activeLayout = { mode="docked", bars=layoutBars }
    lastWinCount = nWin
end

-- ── Zentrales Re-Layout ─────────────────────────────────────────
Relayout = function()
    if not ns.DB then return end
    if isReordering then return end   -- während Drag-Reorder nicht eingreifen
    if ns.DB.bar.anchorToDetails then
        LayoutDocked()
    else
        LayoutFree()
    end
end

-- LEICHTER Sync: hält Andock-Bars an Breite/Sichtbarkeit ihres Details-Fensters.
-- Da die Buttons statisch sind (keine Werte), ist hier keine Wert-Aktualisierung
-- nötig – nur Breite folgen lassen und ggf. Overflow ausblenden.
RefreshValues = function()
    if not ns.DB or isReordering then return end
    if not activeLayout then Relayout(); return end

    for _, entry in ipairs(activeLayout.bars) do
        local b = entry.bar
        if b and entry.winIdx >= 1 then
            local inst = entry.inst
            local df = inst and inst.baseframe
            if df then
                local fullW = df:GetWidth()
                b:SetWidth(fullW)
                b:SetShown(df:IsShown())
                local maxW = fullW - UpdateResetButton(b, entry.winIdx)  -- Platz für X rechts
                -- Auswahl-Markierung aktualisieren + Overflow prüfen
                local x = 0
                for _, key in ipairs(entry.keys) do
                    local f = pieces[key] and pieces[key][entry.winIdx]
                    if f then
                        UpdatePieceSelection(f)   -- fett + (O)/(C) wenn aktiv
                        local w = f:GetWidth()
                        if (x + w) > maxW + 0.5 then
                            f:Hide()
                        else
                            f:ClearAllPoints(); f:SetPoint("LEFT", b, "LEFT", x, 0); f:Show()
                            x = x + w
                        end
                    end
                end
            else
                b:Hide()
            end
        end
    end
end

-- Nach einem Reorder-Drag: neue Reihenfolge anhand der Drop-X-Position berechnen
ReorderDrop = function(piece)
    if not ns.DB then Relayout(); return end
    local bar = piece._origParent
    local uiScale = UIParent:GetEffectiveScale() or 1

    -- Geschwister auf derselben Bar sammeln (inkl. gezogenem Stück)
    local sibs = {}
    for key, set in pairs(pieces) do
        for _, f in pairs(set) do
            if f == piece or (f:GetParent() == bar and f:IsShown()) then
                local leftPos
                if f == piece then
                    leftPos = (GetCursorPosition() / uiScale)  -- Drop-Position (Cursor)
                else
                    leftPos = f:GetLeft() or 0
                end
                table.insert(sibs, { key = key, left = leftPos })
            end
        end
    end

    -- Nach X sortieren = neue visuelle Reihenfolge
    table.sort(sibs, function(a, b) return a.left < b.left end)

    -- Neue Order-Werte vergeben (innerhalb dieser Bar, gespreizt)
    for i, s in ipairs(sibs) do
        if ns.DB[s.key] then ns.DB[s.key].order = i * 10 end
    end

    Relayout()
end

-- ── Exporte ─────────────────────────────────────────────────────
ns.Relayout      = Relayout
ns.RefreshValues = RefreshValues

function ns.UpdateAll()
    Relayout()
end

-- Lock-Zustand setzen (nur relevant im Frei-Modus)
function ns.SetLocked(on)
    if not ns.DB then return end
    ns.DB.bar.locked = on
    if freeBar then StyleBarLock(freeBar, on) end
    Relayout()
end

-- Immer laufender Ticker. Normalfall: nur LEICHTES Werte-Update (kein
-- Verstecken/Neu-Parenten → kein Ruckeln). Nur wenn sich die Fensteranzahl
-- ändert, gibt es einen vollen Neuaufbau (Relayout).
function ns.StartBarTicker()
    local syncFrame = CreateFrame("Frame")
    local last = 0
    syncFrame:SetScript("OnUpdate", function(_, elapsed)
        last = last + elapsed
        if last < 0.3 then return end
        last = 0
        if not ns.DB or isReordering then return end
        -- Strukturänderung (Fensteranzahl) → voller Neuaufbau, sonst nur Werte.
        local n = ns.DB.bar.anchorToDetails and #GetActiveInstances() or 0
        if n ~= lastWinCount or not activeLayout then
            Relayout()
        else
            RefreshValues()
        end
    end)
end
