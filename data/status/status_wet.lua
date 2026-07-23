-- Wet: a soaking debuff. Carries no tick of its own -- instead it changes what the drenched unit is
-- worth hitting with:
--   * `vulnerable = { lightning = N, ice = N, fire = -N }` adds (or, negative, subtracts) flat
--     pre-mitigation damage from any hit carrying that tag (see Status.vulnerability, folded into
--     Combat.mitigatedDamage);
--   * `tileTags = { "conductable" }` makes the ground it stands on conduct, so a bolt striking the
--     next tile over arcs into it (Combat.conductLightning) -- the same tag water terrain and a Rain
--     cloud carry, so all three are one thing to a lightning cast.
-- Inflicted by standing in a Rain hazard (data/hazards/hazard_rain.lua), the water half of the
-- water+electric combo -- soak a cluster, then Jolt one of them and watch it spread.
--
-- THE THREE ELEMENTS, and why water has an opinion about each. Lightning was always here: water
-- carries a charge, and the Rain-then-Jolt sentence is the oldest combo in the game. Ice is the one it
-- was missing, and it costs nothing to say -- a soaked body freezes, so the shelf's second element
-- gets a setup as good as its first, and Rain stops being a Jolt accessory. Fire is the same rule
-- read backwards: a wet thing does not burn well, so `fire = -6` SUBTRACTS from a burning hit.
--
-- That negative is the whole reason this file is worth reading twice. `vulnerable` was always a sum
-- (Status.vulnerability just totals the bag), so a resistance is a vulnerability with a minus sign and
-- needed no new field, no new gate, and no second code path -- it lands on the live hit and the damage
-- preview together, exactly as the positive numbers do. What it buys is a real decision: soaking a
-- cluster now commits your side to finishing them with the storm rather than the torch, and soaking
-- your OWN line is a legitimate way to survive a fire mage.
--
-- Kept smaller than the two vulnerabilities on purpose (6 against 6 and 6). Water should make fire a
-- worse answer, never a useless one -- an interaction that zeroed an element out would stop being a
-- trade-off and start being a lockout.
return {
    name = "Wet",
    abbr = "Wet",
    description = "Soaked: takes extra lightning and ice damage, resists fire, and conducts to nearby water.",
    color = { 0.40, 0.62, 0.92 }, -- badge tint (rain blue)
    duration = 15,  -- ~3 turns at Status.TICKS_PER_TURN: long enough to soak a cluster, then Jolt it
    debuff = true, -- removable by Cure
    lingers = true, -- you walk out of the rain still soaked; it dries on its own duration
    -- Bonus damage taken per hit tag. Negative is RESISTANCE -- Status.vulnerability sums the bag, so
    -- water damping a fire needed no new machinery, only a minus sign.
    vulnerable = { lightning = 6, ice = 6, fire = -6 },
    tileTags = { "conductable" },   -- its tile carries a charge, exactly as a river's does
}
