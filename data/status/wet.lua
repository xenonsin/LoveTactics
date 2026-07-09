-- Wet: a soaking debuff. Carries no tick of its own -- instead it makes the drenched unit take
-- extra damage from lightning: `vulnerable = { lightning = N }` adds N flat pre-mitigation damage to
-- any hit whose tags include "lightning" (see Status.vulnerability, folded into
-- Combat.mitigatedDamage). Inflicted by standing in a Rain hazard (data/hazards/hazard_rain.lua),
-- the water half of the water+electric combo -- soak a foe, then Jolt it.
return {
    name = "Wet",
    abbr = "Wet",
    description = "Soaked: takes extra damage from lightning attacks.",
    color = { 0.40, 0.62, 0.92 }, -- badge tint (rain blue)
    duration = 3,
    vulnerable = { lightning = 6 }, -- bonus damage taken from lightning-tagged hits
}
