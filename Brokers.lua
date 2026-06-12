-- ================================================================
-- BROKER-DEFINITIONEN & DEFAULTS
-- ================================================================
local _, ns = ...
local Compact, Int = ns.Compact, ns.Int

-- Felder pro Broker:
--   container/field      → Wert-Abfrage (FetchData liest das Details-Feld)
--   field                  → exaktes Details-Feld (siehe attributes.lua "internal")
--   dAttr/dSubAttr         → Details!-Anzeige beim Linksklick
--   defEnabled             → Standard aktiv?
-- Standard-Scope ist für ALLE "always" (Immer).
local BROKER_DEFS = {
    -- ── Schaden ────────────────────────────────────────────────
    { key="damagedone", label="Damage Done", icon="Interface\\Icons\\ability_warrior_savageblow",
      defEnabled=false, container=1, field="total",        formatBar=Compact, colHdr="Schaden",
      goodZero=false, colorActive="FF6644", colorZero="999999", dAttr=1, dSubAttr=1 },
    { key="dps",        label="DPS", icon="Interface\\Icons\\ability_dualwield",
      defEnabled=true,  container=1, field="last_dps",     formatBar=Compact, colHdr="DPS",
      goodZero=false, colorActive="FFD700", colorZero="999999", dAttr=1, dSubAttr=1,
      iconAttr=1, iconSub=2 },  -- Icon = DPS, Klick = Damage Done
    { key="damagetaken",label="Damage Taken", icon="Interface\\Icons\\spell_holy_devotionaura",
      defEnabled=false, container=1, field="damage_taken", formatBar=Compact, colHdr="erlitten",
      goodZero=false, colorActive="DD5555", colorZero="999999", dAttr=1, dSubAttr=3 },
    { key="enemydmg",   label="Enemy Dmg Taken", icon="Interface\\Icons\\ability_hunter_focusedaim",
      defEnabled=false, container=1, field="enemies",      formatBar=Compact, colHdr="Schaden",
      goodZero=false, colorActive="FF8855", colorZero="999999", dAttr=1, dSubAttr=6 },
    { key="avoidable",  label="Avoidable Dmg", icon="Interface\\AddOns\\Details\\images\\avoidable_damage_taken.png",
      defEnabled=false, container=1, field="avoidable_damage_taken", formatBar=Compact, colHdr="vermeidbar",
      goodZero=true,  colorActive="FF4422", colorZero="55FF55", dAttr=1, dSubAttr=9, customIcon=true },

    -- ── Heilung ────────────────────────────────────────────────
    { key="healingdone",label="Healing Done", icon="Interface\\Icons\\spell_holy_heal",
      defEnabled=false, container=2, field="total",        formatBar=Compact, colHdr="Heilung",
      goodZero=false, colorActive="44DD88", colorZero="999999", dAttr=2, dSubAttr=1 },
    { key="hps",        label="HPS", icon="Interface\\Icons\\spell_holy_flashheal",
      defEnabled=true,  container=2, field="last_hps",     formatBar=Compact, colHdr="HPS",
      goodZero=false, colorActive="55FF88", colorZero="999999", dAttr=2, dSubAttr=1,
      iconAttr=2, iconSub=2 },  -- Icon = HPS, Klick = Healing Done
    { key="overheal",   label="Overhealing", icon="Interface\\Icons\\spell_holy_sealofsacrifice",
      defEnabled=false, container=2, field="totalover",    formatBar=Compact, colHdr="Overheal",
      goodZero=true,  colorActive="88DDAA", colorZero="55FF55", dAttr=2, dSubAttr=3 },
    { key="potions",    label="Potions", icon="Interface\\AddOns\\Details\\images\\healpotion_icon.png",
      defEnabled=false, container=2, field="healpotions",  formatBar=Compact, colHdr="Tränke",
      goodZero=false, colorActive="DD88FF", colorZero="999999", dAttr=2, dSubAttr=8,
      customIcon=true },  -- Details-eigenes Tränke-Icon (PNG)

    -- ── Sonstiges ──────────────────────────────────────────────
    { key="interrupts", label="Interrupts", icon="Interface\\Icons\\spell_shadow_mindsteal",
      defEnabled=true,  container=4, field="interrupt",    formatBar=Int, colHdr="Int",
      goodZero=false, colorActive="88BBFF", colorZero="999999", dAttr=4, dSubAttr=3 },
    { key="dispels",    label="Dispels", icon="Interface\\Icons\\spell_holy_dispelmagic",
      defEnabled=false, container=4, field="dispell",      formatBar=Int, colHdr="Disp",
      goodZero=false, colorActive="44CCDD", colorZero="999999", dAttr=4, dSubAttr=4 },
    { key="deaths",     label="Deaths", icon="Interface\\Icons\\ability_rogue_feigndeath",
      defEnabled=true,  container=4, field="dead",         formatBar=Int, colHdr="Tode",
      goodZero=true,  colorActive="FF5555", colorZero="55FF55", dAttr=4, dSubAttr=5,
      sumGroup=true },  -- Leiste zeigt Gruppen-Gesamttode (wie Details)
}
ns.BROKER_DEFS = BROKER_DEFS

local DEF = {}
for i, d in ipairs(BROKER_DEFS) do
    d.defScope = "always"   -- Standard-Scope für alle
    d.defWin   = 1
    d.defOrder = i          -- Standard-Reihenfolge
    -- Icon-Zuordnung: per Default = Klick-Ziel, außer explizit gesetzt
    if d.iconAttr == nil then d.iconAttr = d.dAttr; d.iconSub = d.dSubAttr end
    DEF[d.key] = d
end
ns.DEF = DEF

-- Kurz-Name für die Leisten-Buttons (lokalisiert; Icon trägt die Bedeutung)
function ns.GetShortName(key)
    return ns.L["SHORT_"..key] or (DEF[key] and DEF[key].label) or key
end

-- ── Defaults für SavedVariables ─────────────────────────────────
local DEFAULTS = { bar = {
    locked          = true,
    anchorToDetails = false,  -- Auto-Andocken an Details-Fenster (vorerst aus)
    anchorWin       = 1,
    offsetX         = 0,
    offsetY         = 2,
    matchWidth      = false,  -- Breite an Details-Fenster angleichen (nur mit Anker sinnvoll)
    -- accentColor wird NICHT vorbelegt → ohne Wahl = Klassenfarbe (GetAccent)
    bgAlpha         = 0.94,        -- Hintergrund-Transparenz der Leisten
    bgTexture       = "Solid",     -- LSM-Statusbar-Name (siehe ns.GetBarTexturePath)
    font            = "Friz Quadrata", -- LSM-Font-Name (siehe ns.GetBarFontPath)
    winScope        = { [1]="always", [2]="always", [3]="always", [4]="always" }, -- Sichtbarkeit pro Fenster
    winDisplay      = { [1]="both", [2]="both", [3]="both", [4]="both" }, -- Icon/Label/Beides pro Fenster
    language        = "auto", -- "auto" = WoW-Clientsprache, sonst Locale-Code
    minimapHide     = false,  -- Minimap-Button ausblenden
    minimapAngle    = 220,    -- Position des Buttons auf dem Minimap-Ring (Grad)
} }
for _, d in ipairs(BROKER_DEFS) do
    -- windows = Menge der Fenster, auf deren Bar der Broker erscheint.
    DEFAULTS[d.key] = { enabled=d.defEnabled, windows={ [d.defWin]=true }, order=d.defOrder }
end
ns.DEFAULTS = DEFAULTS
