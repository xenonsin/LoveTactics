-- Wet: a soaking debuff. Carries no tick of its own -- instead it does two things to the drenched
-- unit, both about electricity:
--   * `vulnerable = { lightning = N }` adds N flat pre-mitigation damage to any hit whose tags
--     include "lightning" (see Status.vulnerability, folded into Combat.mitigatedDamage);
--   * `tileTags = { "conductable" }` makes the ground it stands on conduct, so a bolt striking the
--     next tile over arcs into it (Combat.conductLightning) -- the same tag water terrain and a Rain
--     cloud carry, so all three are one thing to a lightning cast.
-- Inflicted by standing in a Rain hazard (data/hazards/hazard_rain.lua), the water half of the
-- water+electric combo -- soak a cluster, then Jolt one of them and watch it spread.
return {
    name = "Wet",
    abbr = "Wet",
    description = "Soaked: takes extra lightning damage, and conducts it to nearby water.",
    color = { 0.40, 0.62, 0.92 }, -- badge tint (rain blue)
    duration = 15,  -- ~3 turns at Status.TICKS_PER_TURN: long enough to soak a cluster, then Jolt it
    debuff = true, -- removable by Cure
    lingers = true, -- you walk out of the rain still soaked; it dries on its own duration
    vulnerable = { lightning = 6 }, -- bonus damage taken from lightning-tagged hits
    tileTags = { "conductable" },   -- its tile carries a charge, exactly as a river's does
}
