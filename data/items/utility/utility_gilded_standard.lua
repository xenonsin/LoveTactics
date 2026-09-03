-- The standard-bearer's colours: the body that holds a rank together, and the priority target that
-- makes a Pride fight a decision rather than a grind.
--
-- It does not fight. What it does is keep the formation worth being in -- and because both halves of the
-- rank rule are measured LIVE off adjacency, killing the bearer does not merely stop a buff, it collapses
-- the shape the rest of the bodies were built around.
--
-- The Banner object rule (docs, and the seven relics) says a banner belongs to a Paladin or a Warlord.
-- This is not one: it is animate colours in a warren of chambers, carried by nobody, which is why it is
-- natural kit rather than shelf stock.
--
-- Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Gilded Standard",
    description = "Gains defense and damage for each ally standing beside it.",
    flavor = "The house it belonged to is four hundred years gone. The colours were never told.",
    sprite = "assets/items/gilded_standard.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_formation_fighter", "trait_close_ranks" },
    bonus = { defense = 4 },
}
