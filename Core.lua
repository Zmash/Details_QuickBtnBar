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

    -- Profile aufsetzen: ns.SV (Profile/Zuweisungen) + ns.DB (aktives Profil).
    -- Übernimmt Default-Merge, Migrationen und Sprachwahl.
    ns.SetupProfiles()

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
evFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

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

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- Nur im Spec-Modus relevant: ggf. anderes Profil aktiv werden lassen
        if initialized and ns.GetBindMode and ns.GetBindMode() == "spec" then
            ns.ApplyActiveProfile(); ns.OnProfileChanged()
        end
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
