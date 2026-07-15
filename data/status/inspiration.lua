-- Inspiration: the rallying cry of a raised banner. A morale buff -- courage in the swing AND the
-- shield -- lifting both Damage and Defense for a while (statBonus, folded into Combat's flatStat).
-- Distinct from Blessing, which sharpens offense alone (Damage + Magic Damage), and from Aegis, which
-- shores up defense alone: Inspiration is the middle rally, a little of each. A BUFF, so Cure leaves
-- it be. Granted -- and refreshed each round -- to allies standing around a Rally Banner
-- (data/status/banner_aura.lua); it lingers a short while after they leave the banner's shadow, or
-- after the banner falls, then fades.
return {
    name = "Inspiration",
    abbr = "Insp",
    description = "Inspired: raised Damage and Defense while the banner stands near.",
    color = { 0.95, 0.60, 0.30 }, -- badge tint (rally orange)
    duration = 8, -- outlasts the banner's pulse gap; wears off a round or so after leaving its shadow
    statBonus = { damage = 4, defense = 3 },
}
