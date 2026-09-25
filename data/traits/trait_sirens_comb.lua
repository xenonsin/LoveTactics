-- THE SIREN'S COMB's rule (data/items/utility/utility_sirens_comb.lua): +2 reach against a Wet foe. A
-- per-target bonus rather than a range stat, so it is read where a single target is weighed
-- (Combat.reachWaiver's third answer) -- the cast gate and the target list agree about it.
return {
    name = "Siren's Comb",
    description = "Your abilities reach Wet foes from 2 tiles further.",
    carriesOverWater = 2,
}
