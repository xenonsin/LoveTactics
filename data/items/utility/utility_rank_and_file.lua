-- What a gilded body is: a piece of a rank, and worth very little on its own.
--
-- Carries BOTH halves of the formation rule -- the defensive one that already existed and the offensive
-- one this pass added (data/traits/trait_close_ranks.lua). Together they make a Pride body genuinely
-- bipolar: enormous in line, ordinary out of it, measured live so a rank pulled apart loses it in the
-- same instant.
--
-- Shared by the swarm, the line and the standard-bearer, because the rule is a property of the STRATUM
-- rather than of one body. A player should learn it from the cheapest thing on the floor and find it
-- still true of the expensive ones.
--
-- Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Rank and File",
    description = "Gains defense and damage for each ally standing beside it.",
    flavor = "Alone it is a suit of armour with opinions. Six of them are a wall with a schedule.",
    sprite = "assets/items/rank_and_file.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_formation_fighter", "trait_close_ranks" },
}
