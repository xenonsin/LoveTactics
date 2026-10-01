-- SERAPH'S WING: the Seraph's drop, and what it wears (reviewed 2026-09-30, "Pride's Bestiary"). Any foe that
-- starts its turn next to the bearer Burns (trait_the_burning_one).
--
-- A Crusader's coat, because a crusader is the one who stands in the line and means to be stood next to: the
-- rule pays only a body that stays in reach, and a crusader stays. Medium, so it pays the square (docs/classes.md).
-- The Burning Halo is its nearest neighbour on the same shelf and it is a different fire: the halo burns whoever
-- walks into it, the wing burns whoever is still there when their turn comes round.
--
-- `unstocked`: a trophy, seen on the rack and never sold (docs/drops.md).
local Curve = require("models.curve")

return {
    name = "Seraph's Wing",
    description = "Foes that start their turn next to you Burn.",
    flavor = "Six of them, and it covers its face with two. Nobody has ever seen what it is shielding.",
    sprite = "assets/items/armor_seraphs_wing.png",
    type = "armor",
    tags = { "medium", "holy", "fire" },
    class = "crusader",
    unlockLevel = 8,
    unstocked = true,
    bonus = { defense = Curve.ramp(3, 13), movement = -1 },
    traits = { "trait_the_burning_one" },
}
