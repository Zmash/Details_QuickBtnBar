-- ================================================================
-- GEMEINSAME KONSTANTEN & HELFER
-- Design-Farben, Akzentfarben-System, Zahlenformate, Scope/Zone,
-- Details-Icon-Atlas.
-- ================================================================
local _, ns = ...

-- ── Design-Farben (dunkles, minimalistisches Panel) ─────────────
ns.E_BG_R,  ns.E_BG_G,  ns.E_BG_B         = 0.05,  0.07,  0.09   -- Panel-Hintergrund
ns.E_ACC_R, ns.E_ACC_G, ns.E_ACC_B        = 0.047, 0.82,  0.616  -- Akzent-Fallback
ns.E_BRD_A                                = 0.07                  -- Border-Alpha
ns.E_TXT_DIM_A                            = 0.53                  -- Gedimmter Text
ns.E_BTN_BG_R, ns.E_BTN_BG_G, ns.E_BTN_BG_B = 0.061, 0.095, 0.120 -- Button-Hintergrund
ns.E_BTN_BG_A                             = 0.60
ns.E_BTN_BRD_A                            = 0.30
ns.E_TG_OFF_R, ns.E_TG_OFF_G, ns.E_TG_OFF_B = 0.267, 0.267, 0.267 -- Toggle OFF
ns.E_TG_OFF_A                             = 0.65
ns.E_TG_ON_A                              = 0.75

-- ── Akzentfarbe ─────────────────────────────────────────────────
-- Klassenfarbe des Spielers (Standard-Akzent)
local function GetClassColor()
    local _, class = UnitClass("player")
    local c = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS) and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
    if c then return c.r, c.g, c.b end
    return ns.E_ACC_R, ns.E_ACC_G, ns.E_ACC_B
end

-- Aktueller Akzentfarbwert. Ohne gespeicherte Farbe = Klassenfarbe.
function ns.GetAccent()
    if _G.DetailsQuickBtnBarDB and _G.DetailsQuickBtnBarDB.bar and _G.DetailsQuickBtnBarDB.bar.accentColor then
        local c = _G.DetailsQuickBtnBarDB.bar.accentColor
        return c[1], c[2], c[3]
    end
    return GetClassColor()
end

-- Register von Funktionen, die ein Element neu einfärben (für Live-Farbwechsel).
local accentRefreshers = {}
function ns.RegisterAccentRefresher(fn)
    accentRefreshers[#accentRefreshers+1] = fn
end
function ns.RunAccentRefreshers()
    for _, fn in ipairs(accentRefreshers) do pcall(fn) end
end

-- ── Zahlenformatierung (kein locale-Komma) ──────────────────────
function ns.Int(n) return tostring(math.floor((n or 0) + 0.5)) end
function ns.Compact(n)
    n = math.floor((n or 0) + 0.5)
    if n >= 1000000 then
        local i = math.floor(n/1000000); local d = math.floor((n/1000000-i)*10)
        return i.."."..d.."m"
    elseif n >= 1000 then
        local i = math.floor(n/1000); local d = math.floor((n/1000-i)*10)
        return i.."."..d.."k"
    end
    return tostring(n)
end

-- ── Klassenfarben für Namen ─────────────────────────────────────
local CC = {
    WARRIOR="C69B3A",PALADIN="F48CBA",HUNTER="AAD372",ROGUE="FFF468",
    PRIEST="FFFFFF",DEATHKNIGHT="C41E3A",SHAMAN="0070DD",MAGE="3FC7EB",
    WARLOCK="8788EE",MONK="00FF98",DRUID="FF7C0A",DEMONHUNTER="8830C9",
    EVOKER="33937F",
}
function ns.ColorName(name, class)
    local hex = (class and CC[class:upper()]) or "999999"
    local short = (name and name:match("^([^%-]+)")) or name or "?"
    return "|cFF"..hex..short.."|r"
end

-- ── Scope / Zone ────────────────────────────────────────────────
-- Beschriftungen kommen zur Laufzeit aus L["SCOPE_"..scope]
ns.SCOPE_ORDER = { "always", "dungeon", "raid", "instance" }

function ns.GetZoneType()
    local inInst, iType = IsInInstance()
    if not inInst       then return "world"   end
    if iType == "party" then return "dungeon"  end
    if iType == "raid"  then return "raid"     end
    return "other"
end

-- ── Details!-Icon-Atlas ─────────────────────────────────────────
-- Pro Attribut ein Atlas mit 8 Slots (je 0.125 breit).
-- Sub-Attribut n → TexCoord {0.125*(n-1), 0.125*n, 0, 1}
local DETAILS_ICON_ATLAS = {
    [1] = "Interface\\AddOns\\Details\\images\\atributos_icones_damage",
    [2] = "Interface\\AddOns\\Details\\images\\atributos_icones_heal",
    [3] = "Interface\\AddOns\\Details\\images\\atributos_icones_energyze",
    [4] = "Interface\\AddOns\\Details\\images\\atributos_icones_misc",
}
function ns.ApplyBrokerIcon(tex, def)
    if def.customIcon or not DETAILS_ICON_ATLAS[def.iconAttr] then
        tex:SetTexture(def.icon)
        tex:SetTexCoord(0, 1, 0, 1)
        return
    end
    local sub = def.iconSub or 1
    local l = 0.125 * (sub - 1)
    tex:SetTexture(DETAILS_ICON_ATLAS[def.iconAttr])
    tex:SetTexCoord(l, l + 0.125, 0, 1)
end
