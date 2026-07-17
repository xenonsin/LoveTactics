-- Inspiration: the rallying cry of a raised banner. A morale buff -- courage in the swing AND the
-- shield -- lifting both Damage and Defense (statBonus, folded into Combat's flatStat). Distinct from
-- Blessing, which sharpens offense alone (Damage + Magic Damage), and from Aegis, which shores up
-- defense alone: Inspiration is the middle rally, a little of each. A BUFF, so Cure leaves it be.
--
-- ZONE-BOUND: it declares no `lingers`, so it holds only while its bearer stands on the Rally ground a
-- banner is keeping open (data/hazards/hazard_rally.lua) and ends the instant the ally steps out of the
-- shadow -- or the instant the standard is cut down and the shadow itself goes. Morale is not something
-- you carry away from the banner; that is the whole tactical point of planting one.
return {
    name = "Inspiration",
    abbr = "Insp",
    description = "Inspired: raised Damage and Defense while the banner stands near.",
    color = { 0.95, 0.60, 0.30 }, -- badge tint (rally orange)
    -- Never reached while the banner stands: a zone-bound status does not age (models/status.lua's
    -- Status.tick skips it), so this is only the backstop for an Inspiration handed out by something
    -- that is not a zone.
    duration = 8,
    statBonus = { damage = 4, defense = 3 },
}
