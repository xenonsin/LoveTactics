-- The forge-wretch's scars, and the vessel Kindling rides in.
--
-- Ira's Rising Wrath is two compounding terms with no ceiling -- +1 per blow taken AND up to +20 by
-- missing health (data/traits/trait_wrath_rising.lua). Kindling is one term and a cap
-- (data/traits/trait_kindling.lua), which is what makes the rule legible the first time a player meets
-- it: the number goes up a little each time you hit it, visibly, and then stops.
--
-- The specialist carries it so the circle's ordinary traffic teaches the rule, and the mini sin above it
-- carries the same trait with a phase that removes the ceiling. Same lesson, three depths.
--
-- Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Forge Scar",
    description = "Sharpens with every blow it takes, up to a limit.",
    flavor = "Every mark on it is a thing that hit it. It kept all of them.",
    sprite = "assets/items/forge_scar.png",
    type = "utility",
    class = "creature",
    dropTier = 3,
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_kindling" },
}
