-- COAL IN THE FIST: the Blaze's kindling blows (trait_coal_in_the_fist; "Fire, Lightning, and Dirty Thunder",
-- 2026-09-27), and one of the three things it drops. Your weapon blows set the struck tile alight. A Battlemage's:
-- the swing is the spell.
return {
    name = "Coal in the Fist",
    description = "Your weapon blows set the struck tile alight.",
    flavor = "Hold it tight enough and it stops hurting you. It never stops hurting them.",
    sprite = "assets/items/utility_coal_in_the_fist.png",
    type = "utility",
    tags = { "fire" },
    class = "battlemage",
    unlockLevel = 7,
    unstocked = true,
    traits = { "trait_coal_in_the_fist" },
}
