-- ================================================================
-- PROFILE
-- Benannte Einstellungs-Profile, zuweisbar accountweit / pro
-- Charakter / pro Spezialisierung.
--
-- SavedVariable-Struktur:
--   DetailsQuickBtnBarDB = {
--       profiles    = { [name] = <settings: bar + broker-configs> },
--       assignments = { [selectorKey] = profileName },
--       bindMode    = "account" | "character" | "spec",
--   }
-- ns.SV  → die rohe SavedVariable (Profile/Zuweisungen)
-- ns.DB  → die Settings des AKTIVEN Profils (alles übrige Code nutzt das)
-- ================================================================
local _, ns = ...

local function DeepCopy(src)
    local t = {}
    for k, v in pairs(src) do
        if type(v) == "table" then t[k] = DeepCopy(v) else t[k] = v end
    end
    return t
end

-- ── Selektor-Schlüssel je nach Bindungs-Modus ───────────────────
local function CharKey()
    return (UnitName("player") or "?").."-"..(GetRealmName() or "?")
end
local function SpecKey()
    local specID = 0
    local idx = GetSpecialization and GetSpecialization()
    if idx and GetSpecializationInfo then
        specID = GetSpecializationInfo(idx) or 0
    end
    return CharKey().."@"..specID
end

-- Bindungs-Modus ist PRO CHARAKTER gespeichert: ein frisch eingeloggter
-- Charakter startet auf "account" (Default), bis er selbst umgestellt wird.
function ns.GetBindMode()
    return (ns.SV and ns.SV.bindModes and ns.SV.bindModes[CharKey()]) or "account"
end

function ns.GetSelectorKey()
    local mode = ns.GetBindMode()
    if mode == "character" then return CharKey() end
    if mode == "spec"      then return SpecKey() end
    return "account"
end

-- ── Defaults + Migrationen auf ein Profil anwenden ──────────────
local function ApplyDefaults(p)
    for key, def in pairs(ns.DEFAULTS) do
        p[key] = p[key] or {}
        for field, val in pairs(def) do
            if p[key][field] == nil then
                if type(val) == "table" then
                    local copy = {}
                    for k2, v2 in pairs(val) do copy[k2] = v2 end
                    p[key][field] = copy
                else
                    p[key][field] = val
                end
            end
        end
    end

    -- Migration: alte Textur-/Font-Codes (frühe Test-Builds) → LSM-Namen
    local FONT_MAP = { default="Friz Quadrata", arial="Arial Narrow",
                       morpheus="Morpheus", skurri="Skurri" }
    local TEX_MAP  = { solid="Solid", blizzard="Blizzard" }
    local bar = p.bar
    if FONT_MAP[bar.font] then bar.font = FONT_MAP[bar.font] end
    if TEX_MAP[bar.bgTexture] then bar.bgTexture = TEX_MAP[bar.bgTexture]
    elseif bar.bgTexture == "smooth" or bar.bgTexture == "glaze" then
        bar.bgTexture = "Solid"
    end

    -- Migration: altes Einzelfenster (window=Zahl) → Mengen-Form (windows)
    for _, d in ipairs(ns.BROKER_DEFS) do
        local cfg = p[d.key]
        if cfg and cfg.window then
            cfg.windows = { [cfg.window] = true }
            cfg.window = nil
        end
        if cfg and type(cfg.windows) ~= "table" then
            cfg.windows = { [1] = true }
        end
    end
end

local function CharName() return UnitName("player") or "?" end

-- Liste aller Spezialisierungen des Charakters (für die Pro-Spec-UI).
function ns.GetSpecList()
    local out = {}
    local n = (GetNumSpecializations and GetNumSpecializations()) or 0
    for i = 1, n do
        local id, name, _, icon = GetSpecializationInfo(i)
        out[i] = { index = i, id = id, name = name, icon = icon,
                   key = CharKey().."@"..(id or i) }
    end
    return out
end

-- Zuweisung sicherstellen: fehlt sie, neues Profil (Kopie des aktuell
-- aktiven) anlegen und zuordnen.
local function EnsureAssignment(key, name)
    if ns.SV.assignments[key] then return end
    if not ns.SV.profiles[name] then
        ns.SV.profiles[name] = DeepCopy(ns.DB)
        ApplyDefaults(ns.SV.profiles[name])
    end
    ns.SV.assignments[key] = name
end

-- ── Aktives Profil auflösen / anwenden ──────────────────────────
-- Nicht zugewiesene Selektoren folgen "Default", bis der Nutzer ein
-- eigenes Profil wählt (kein automatisches Wildwuchs-Anlegen).
function ns.GetProfileName()
    local name = ns.SV.assignments[ns.GetSelectorKey()]
    if name and ns.SV.profiles[name] then return name end
    return "Default"
end

function ns.ApplyActiveProfile()
    local name = ns.GetProfileName()
    ns.SV.profiles[name] = ns.SV.profiles[name] or {}
    ApplyDefaults(ns.SV.profiles[name])
    ns.DB = ns.SV.profiles[name]
    ns.SetActiveLocale()           -- Sprache ist Teil des Profils
end

-- Nach einem Profilwechsel alles sichtbar nachziehen.
function ns.OnProfileChanged()
    if ns.RebuildSettingsIfShown then ns.RebuildSettingsIfShown() end
    if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
    if ns.RefreshBarBg then ns.RefreshBarBg() end
    if ns.ApplyAccentAll then ns.ApplyAccentAll() end
    if ns.Relayout then ns.Relayout() end
end

-- ── Verwaltung ──────────────────────────────────────────────────
function ns.ListProfiles()
    local out = {}
    for name in pairs(ns.SV.profiles) do out[#out+1] = name end
    table.sort(out)
    return out
end

-- Einen beliebigen Selektor-Schlüssel einem Profil zuweisen (z. B. eine
-- bestimmte Spec aus der Liste, auch wenn sie gerade nicht aktiv ist).
function ns.AssignProfileToKey(key, name)
    if not ns.SV.profiles[name] then return end
    ns.SV.assignments[key] = name
    ns.ApplyActiveProfile()
    ns.OnProfileChanged()
end

-- Aktuellen Selektor einem vorhandenen Profil zuweisen.
function ns.AssignProfile(name)
    ns.AssignProfileToKey(ns.GetSelectorKey(), name)
end

-- Neues Profil anlegen (optional als Kopie des aktuellen) und zuweisen.
function ns.CreateProfile(name, copyCurrent)
    name = name and name:match("^%s*(.-)%s*$")
    if not name or name == "" then return end
    if not ns.SV.profiles[name] then
        ns.SV.profiles[name] = copyCurrent and DeepCopy(ns.DB) or {}
    end
    ApplyDefaults(ns.SV.profiles[name])
    ns.SV.assignments[ns.GetSelectorKey()] = name
    ns.ApplyActiveProfile()
    ns.OnProfileChanged()
end

-- Profil löschen (außer "Default"); betroffene Zuweisungen fallen zurück.
function ns.DeleteProfile(name)
    if name == "Default" or not ns.SV.profiles[name] then return end
    ns.SV.profiles[name] = nil
    for k, v in pairs(ns.SV.assignments) do
        if v == name then ns.SV.assignments[k] = nil end
    end
    ns.ApplyActiveProfile()
    ns.OnProfileChanged()
end

-- Aktuelles Profil auf Standardwerte zurücksetzen.
function ns.ResetCurrentProfile()
    local name = ns.GetProfileName()
    ns.SV.profiles[name] = {}
    ApplyDefaults(ns.SV.profiles[name])
    ns.ApplyActiveProfile()
    ns.OnProfileChanged()
end

-- Bindungs-Modus (account/character/spec) umstellen. Beim Wechsel werden
-- fehlende Profile automatisch angelegt: eins pro Charakter bzw. eins pro
-- Spezialisierung (jeweils als Kopie des bisher aktiven Profils).
function ns.SetBindMode(mode)
    ns.SV.bindModes[CharKey()] = mode
    if mode == "character" then
        EnsureAssignment(CharKey(), CharKey())
    elseif mode == "spec" then
        for _, s in ipairs(ns.GetSpecList()) do
            EnsureAssignment(s.key, CharName().." - "..(s.name or s.index))
        end
    end
    ns.ApplyActiveProfile()
    ns.OnProfileChanged()
end

-- ── Erstinitialisierung (aus Core aufgerufen) ───────────────────
function ns.SetupProfiles()
    local sv = DetailsQuickBtnBarDB or {}

    -- Migration: alte flache Settings (DB hatte direkt .bar) → profiles.Default
    if not sv.profiles then
        local legacy
        if sv.bar then
            legacy = {}
            local keys = {}
            for k in pairs(sv) do keys[#keys+1] = k end
            for _, k in ipairs(keys) do legacy[k] = sv[k]; sv[k] = nil end
        end
        sv.profiles = {}
        if legacy then sv.profiles.Default = legacy end
    end

    sv.profiles.Default = sv.profiles.Default or {}
    sv.assignments      = sv.assignments or {}
    sv.bindModes        = sv.bindModes or {}

    -- Migration: früheres GLOBALES bindMode (galt fälschlich für alle Chars)
    -- → nur für den aktuellen Charakter übernehmen, dann entfernen.
    if sv.bindMode then
        sv.bindModes[CharKey()] = sv.bindModes[CharKey()] or sv.bindMode
        sv.bindMode = nil
    end

    DetailsQuickBtnBarDB = sv
    ns.SV = sv
    ns.ApplyActiveProfile()
end

-- Auswahl im Modus-Dropdown (Text via L["MODE_"..value])
ns.MODE_OPTIONS = {
    { value = "account" },
    { value = "character" },
    { value = "spec" },
}
