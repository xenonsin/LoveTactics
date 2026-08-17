-- WOUNDED: what a body that has been carried off a floor fights at until somebody sets the bone.
--
-- Not inflicted by anything on the board. This is the combat half of models/wound.lua -- a body that
-- went down in an earlier fight walks into the NEXT one already carrying it, stamped at spawn through
-- the same seam a relic's opening boon uses (states/game.lua's resolveOpening). Nothing in a fight can
-- apply it and nothing in a fight can remove it; it comes off at the inn, for gold.
--
-- WHY IT IS A STATUS AND NOT A STAT PENALTY. A wound has to be READABLE -- the player needs to see, on
-- the timeline strip and in the damage breakdown, that this body is swinging short because of something
-- that happened two fights ago. A quiet subtraction from `damage` would be a number nobody could
-- account for. So it goes through the badge and the breakdown like every other modifier, and the
-- glossary explains it in the same place it explains Cripple.
--
-- THE MAGNITUDE SCALES WITH THE COUNT, which is why this is one blueprint rather than three. It is
-- applied with an explicit `opts.magnitude` (Wound.combatEffects) so two wounds bite harder than one
-- and the badge shows the number -- the same mechanism Defending and Empowered use for a shield's
-- upgrade level. A negative magnitude is unusual in this catalog and entirely intentional; Given Guard
-- does the same, and Status.statBonus simply sums it.
--
-- IT DOES NOT EXPIRE inside a fight. Every other debuff here is a tempo cost measured in ticks; this is
-- a condition the body arrived with, so it is applied with a duration far past any battle's length
-- rather than a tick count somebody would have to keep re-reading. What ends it is the inn.
return {
    name = "Wounded",
    abbr = "Wnd",
    description = "Wounded: hits for less, and cannot be healed past the wound.",
    color = { 0.642, 0.328, 0.234 }, -- badge tint (dried blood)
    duration = 9999,             -- see above: it lasts the fight, and the fight after it
    debuff = true,
    magnitude = 2,               -- the fallback; Wound.combatEffects always passes its own, negated
    magnitudeStat = "damage",    -- the flat stat the magnitude moves (via Status.statBonus)
}
