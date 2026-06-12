-- ================================================================
--  Details! QuickBtnBar
--  Schnellschalt-Buttonleiste für Details! (Anzeige + Segment)
--  /dqb  → Einstellungen
--
--  Initialisierung, SavedVariables, Events, Slash-Commands.
-- ================================================================
local _, ns = ...

local initialized = false

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
-- SLASH-COMMANDS
-- ================================================================
SLASH_DETAILSQUICKBTNBAR1 = "/dqb"
SlashCmdList["DETAILSQUICKBTNBAR"] = function(msg)
    local m = (msg or ""):lower():match("^%s*(.-)%s*$")
    if m == "lock"   then if ns.DB then ns.SetLocked(true)  end
    elseif m == "unlock" then if ns.DB then ns.SetLocked(false) end
    elseif m == "reset"  then DetailsQuickBtnBarDB=nil; ReloadUI()
    else ns.ShowSettings()
    end
end
