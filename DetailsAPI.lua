-- ================================================================
-- DETAILS!-HILFSFUNKTIONEN
-- Details! speichert Fenster NICHT in Details.windows, sondern liefert
-- sie über Details:GetAllInstances(). Wir filtern aktive (sichtbare)
-- Instanzen heraus und indizieren sie 1..n.
-- ================================================================
local _, ns = ...

function ns.GetActiveInstances()
    if not Details or not Details.GetAllInstances then return {} end
    local ok, all = pcall(Details.GetAllInstances, Details)
    if not ok or type(all) ~= "table" then return {} end
    local active = {}
    -- pairs statt ipairs: robust gegen Lücken im Instanz-Array
    for _, inst in pairs(all) do
        if type(inst) == "table" and inst.baseframe then
            local enabled = true
            if inst.IsEnabled then
                local okEn, res = pcall(inst.IsEnabled, inst)
                if okEn then enabled = res end
            elseif inst.ativa ~= nil then
                enabled = inst.ativa
            end
            -- Nur sichtbare, aktivierte Fenster
            if enabled and inst.baseframe:IsShown() then
                active[#active+1] = inst
            end
        end
    end
    -- Nach Bildschirm-X sortieren (links → rechts), damit Fenster 1 = ganz links.
    -- So entsteht bei aneinandergrenzenden Fenstern eine durchgängige Leiste.
    table.sort(active, function(a, b)
        local ax = a.baseframe:GetLeft() or 0
        local bx = b.baseframe:GetLeft() or 0
        return ax < bx
    end)
    return active
end

function ns.GetDetailsWinCount()
    local n = #ns.GetActiveInstances()
    return n > 0 and n or 1
end

function ns.GetDetailsWin(idx)
    local active = ns.GetActiveInstances()
    return active[idx] or active[1]
end

-- Zeigt das Fenster gerade Gesamt-Daten an?
-- Parser-abhängig, exakt spiegelbildlich zu SetInstanceSegment:
--   Blizzard-Parser: sessionType 0 = Overall, 1 = Current
--   Details-Parser : segmento -1 = Overall, 0 = Current
function ns.InstanceIsOverall(inst)
    if not inst then return false end
    if Details.IsUsingBlizzardAPI and Details:IsUsingBlizzardAPI(inst) then
        return inst.GetSegmentType and inst:GetSegmentType() == 0
    else
        return inst.GetSegmentId and inst:GetSegmentId() == DETAILS_SEGMENTID_OVERALL
    end
end

function ns.IsWindowOverall(winIdx)
    return ns.InstanceIsOverall(ns.GetDetailsWin(winIdx))
end

-- Segment eines Details-Fensters auf Aktuell/Gesamt setzen – exakt wie
-- Details' eigenes Segment-Menü (frames\segments\segments_functions.lua):
--   Blizzard-Parser: SetSegmentType(0=Overall / 1=Current) + RefreshWindow
--   Details-Parser : SetSegmentId(-1/0) + UpdateCombatObjectInUse + RefreshMainWindow
function ns.SetInstanceSegment(inst, overall)
    local usingBlizzard = Details.IsUsingBlizzardAPI and Details:IsUsingBlizzardAPI(inst)
    if usingBlizzard then
        if inst.SetSegmentType then
            pcall(inst.SetSegmentType, inst, overall and 0 or 1, true, true)
        end
        if inst.RefreshWindow then pcall(inst.RefreshWindow, inst, true) end
    else
        if inst.SetSegmentId then
            pcall(inst.SetSegmentId, inst, overall and DETAILS_SEGMENTID_OVERALL or DETAILS_SEGMENTID_CURRENT, true)
        end
        if Details.UpdateCombatObjectInUse then pcall(Details.UpdateCombatObjectInUse, Details, inst) end
        if Details.RefreshMainWindow then pcall(Details.RefreshMainWindow, Details, inst, true) end
    end
end
