-- BATHED: the Blood Countess has bathed in her basin (models/basin.lua). +2 Speed and +20% of her own Damage for
-- the rest of the fight, per bath, to two baths (Basin.MAX_BATHS). The applier hands in the statBonus.
return {
    name = "Bathed",
    abbr = "Bthd",
    description = "Bathed in blood: +2 Speed and +20% Damage for each bath, to two, for the rest of the fight.",
    color = { 0.760, 0.100, 0.180 }, -- badge tint (wet crimson)
    duration = math.huge,
    hideDuration = true,
    magnitude = 1,
    stacks = 2,
}
