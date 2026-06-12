-- ================================================================
-- LOKALISIERUNG (Registry)
-- Die Sprachtabellen liegen in Locales\*.lua und registrieren sich
-- hier. Standard: WoW-Clientsprache, per Dropdown übersteuerbar
-- (DB.bar.language = "auto" | Locale-Code). Fehlende Schlüssel
-- fallen auf enUS zurück.
-- ================================================================
local _, ns = ...

ns.locales = {}
function ns.RegisterLocale(code, tbl)
    ns.locales[code] = tbl
end

-- Auswahl im Sprach-Dropdown; text=nil → Beschriftung kommt aus L.LANG_AUTO
ns.LANG_OPTIONS = {
    { value = "auto", text = nil },
    { value = "deDE", text = "Deutsch" },
    { value = "enUS", text = "English" },
}

local activeLang = "enUS"

local function ResolveLang()
    local pref = ns.DB and ns.DB.bar and ns.DB.bar.language
    if pref and pref ~= "auto" and ns.locales[pref] then return pref end
    return GetLocale()
end

function ns.SetActiveLocale()
    activeLang = ResolveLang()
end

-- Proxy-Tabelle: liest immer aus der gerade aktiven Sprache.
-- Dadurch bleiben `local L = ns.L`-Aliase nach einem Sprachwechsel gültig.
ns.L = setmetatable({}, { __index = function(_, k)
    local act = ns.locales[activeLang]
    local v = act and act[k]
    if v ~= nil then return v end
    local en = ns.locales.enUS
    return en and en[k] or nil
end })

ns.SetActiveLocale()
