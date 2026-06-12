-- ================================================================
--  Details! QuickBtnBar
--  Schnellschalt-Buttonleiste für Details! (Anzeige + Segment)
--  /dab , /dqbb oder /detailsquickbtnbar  → Einstellungen
--
--  Initialisierung, SavedVariables, Events, Slash-Commands, Debug.
-- ================================================================
local _, ns = ...

local initialized = false
local myName      = nil

-- ================================================================
-- INITIALISIERUNG
-- ================================================================
local function TryInit()
    if initialized then return end
    -- Details! muss geladen sein (Fenster sind optional – die Leiste
    -- floatet auch ohne offenes Details-Fenster).
    if not Details then
        C_Timer.After(1, TryInit); return
    end

    -- SavedVariables aufsetzen (Tabellen-Defaults werden kopiert, nicht geteilt)
    DetailsQuickBtnBarDB = DetailsQuickBtnBarDB or {}
    for key, def in pairs(ns.DEFAULTS) do
        DetailsQuickBtnBarDB[key] = DetailsQuickBtnBarDB[key] or {}
        for field, val in pairs(def) do
            if DetailsQuickBtnBarDB[key][field] == nil then
                if type(val) == "table" then
                    local copy = {}
                    for k2, v2 in pairs(val) do copy[k2] = v2 end
                    DetailsQuickBtnBarDB[key][field] = copy
                else
                    DetailsQuickBtnBarDB[key][field] = val
                end
            end
        end
    end
    ns.DB = DetailsQuickBtnBarDB

    -- Migration: altes Einzelfenster (window=Zahl) → Mengen-Form (windows)
    for _, d in ipairs(ns.BROKER_DEFS) do
        local cfg = ns.DB[d.key]
        if cfg and cfg.window then
            cfg.windows = { [cfg.window] = true }
            cfg.window = nil
        end
        if cfg and type(cfg.windows) ~= "table" then
            cfg.windows = { [1] = true }
        end
    end

    -- Spielername
    myName = UnitName("player")

    -- Gespeicherte Sprachwahl anwenden (DB ist jetzt verfügbar)
    ns.SetActiveLocale()

    -- Minimap-Button (sofern nicht deaktiviert)
    ns.UpdateMinimapButton()

    -- Erstes Layout + laufender Sync-Ticker
    ns.Relayout()
    ns.StartBarTicker()

    initialized = true
end

-- ================================================================
-- EVENTS
-- ================================================================
local evFrame = CreateFrame("Frame")

evFrame:RegisterEvent("ADDON_LOADED")
evFrame:RegisterEvent("PLAYER_LOGIN")
evFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
evFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
evFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

evFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Details_QuickBtnBar" then
        -- Details ist als Dependency bereits geladen; Init nach kurzem Delay
        C_Timer.After(0.3, TryInit)

    elseif event == "PLAYER_LOGIN" then
        myName = UnitName("player")
        C_Timer.After(1, TryInit)

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Sicherste Trigger: alles ist geladen und Fenster existieren
        C_Timer.After(0.5, TryInit)
        if initialized then
            C_Timer.After(0.5, function() ns.UpdateAll(); ns.RefreshSettings() end)
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Nach Kampfende einmal verzögert nachziehen (Details rechnet final neu)
        C_Timer.After(0.6, ns.UpdateAll)

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        C_Timer.After(0.5, function() ns.UpdateAll(); ns.RefreshSettings() end)
    end
end)

-- ================================================================
-- DEBUG  (/dab debug)
-- Gibt die rohen Details-Felder des eigenen Charakters aus, damit wir
-- sehen, welche Werte exakt der Details-Anzeige entsprechen.
-- ================================================================
local function P(...) print("|cFF66CCFF[DSB]|r", ...) end

local function DumpSegment(segId, label)
    if not Details then P("Details nicht geladen"); return end
    local seg = Details:GetCombat(segId)
    if not seg then P(label..": KEIN Segment"); return end

    local stype = seg.GetCombatType and seg:GetCombatType()
    local ct    = seg.GetCombatTime and seg:GetCombatTime()
    local rt    = seg.GetRunTime and seg:GetRunTime()
    local cname = seg.GetCombatName and seg:GetCombatName(true)
    P(string.format("== %s (id=%s) name=%s type=%s combatTime=%.1f runTime=%s",
        label, tostring(segId), tostring(cname), tostring(stype),
        tonumber(ct) or -1, tostring(rt)))

    local name = myName or UnitName("player")

    -- Actor des Spielers im Container finden (über GetOnlyName)
    local function FindMe(container)
        if not container then return nil end
        for _, a in container:ListActors() do
            if a:IsPlayer() then
                local n = a:GetOnlyName() or a:name()
                if n == name then return a end
            end
        end
        return nil
    end

    -- DAMAGE container (1)
    local a = FindMe(seg:GetContainer(1))
    if a then
        local tempo = a.Tempo and a:Tempo() or 0
        P(string.format("  DMG  total=%s  last_dps=%s  last_dps_realtime=%s  grupo=%s  Tempo=%.1f",
            tostring(a.total), tostring(a.last_dps), tostring(a.last_dps_realtime),
            tostring(a.grupo), tonumber(tempo) or -1))
        if ct and ct>0 then P(string.format("       → total/combatTime = %.1f", (a.total or 0)/ct)) end
        if tempo and tempo>0 then P(string.format("       → total/Tempo      = %.1f", (a.total or 0)/tempo)) end
        if rt and rt>0 then P(string.format("       → total/runTime     = %.1f", (a.total or 0)/rt)) end
    else
        P("  DMG  kein Actor '"..name.."' gefunden")
    end

    -- HEAL container (2)
    local h = FindMe(seg:GetContainer(2))
    if h then
        P(string.format("  HEAL total=%s  last_hps=%s  totalover=%s  healpotions=%s",
            tostring(h.total), tostring(h.last_hps), tostring(h.totalover), tostring(h.healpotions)))
    end

    -- MISC container (4)
    local u = FindMe(seg:GetContainer(4))
    if u then
        P(string.format("  MISC interrupt=%s  dispell=%s  dead=%s  ress=%s",
            tostring(u.interrupt), tostring(u.dispell), tostring(u.dead), tostring(u.ress)))
    end
end

local function DebugDump()
    P("=================== DEBUG ===================")
    P("Spieler: "..tostring(myName or UnitName("player")))
    DumpSegment(DETAILS_SEGMENTID_CURRENT, "CURRENT")
    DumpSegment(DETAILS_SEGMENTID_OVERALL, "OVERALL")
    -- Was zeigen die Details-Fenster gerade an?
    if Details and Details.GetAllInstances then
        local ok, all = pcall(Details.GetAllInstances, Details)
        if ok and all then
            for _, inst in pairs(all) do
                if type(inst)=="table" and inst.baseframe then
                    local segId = inst.GetSegmentId and inst:GetSegmentId()
                    local att, sub = inst.GetDisplay and inst:GetDisplay()
                    local enabled = inst.IsEnabled and inst:IsEnabled()
                    -- Welches Combat zeigt das Fenster? (Identitätsvergleich)
                    local showingWhat = "?"
                    if inst.showing == Details:GetCurrentCombat() then showingWhat="CURRENT"
                    elseif inst.showing == Details:GetOverallCombat() then showingWhat="OVERALL"
                    elseif inst.showing then showingWhat="other" end
                    -- last_dps des Spielers im angezeigten Combat
                    local sdps = "-"
                    if inst.showing and inst.showing.GetContainer then
                        local dc = inst.showing:GetContainer(1)
                        if dc then
                            for _, ac in dc:ListActors() do
                                if ac:IsPlayer() and (ac:GetOnlyName()==myName) then sdps=tostring(ac.last_dps) break end
                            end
                        end
                    end
                    P(string.format("Fenster id=%s enabled=%s segId=%s showing=%s attr=%s sub=%s last_dps=%s",
                        tostring(inst.meu_id), tostring(enabled), tostring(segId),
                        showingWhat, tostring(att), tostring(sub), sdps))
                end
            end
        end
    end
    P("Bitte vergleiche diese Zahlen mit dem, was Details ON SCREEN zeigt.")
    P("============================================")
end

-- ================================================================
-- SLASH-COMMANDS
-- ================================================================
SLASH_DETAILSQUICKBTNBAR1 = "/detailsquickbtnbar"
SLASH_DETAILSQUICKBTNBAR2 = "/dqbb"
SLASH_DETAILSQUICKBTNBAR3 = "/dab"
SlashCmdList["DETAILSQUICKBTNBAR"] = function(msg)
    local m = (msg or ""):lower():match("^%s*(.-)%s*$")
    if m == "lock"   then if ns.DB then ns.SetLocked(true)  end
    elseif m == "unlock" then if ns.DB then ns.SetLocked(false) end
    elseif m == "reset"  then DetailsQuickBtnBarDB=nil; ReloadUI()
    elseif m == "debug"  then DebugDump()
    else ns.ShowSettings()
    end
end
