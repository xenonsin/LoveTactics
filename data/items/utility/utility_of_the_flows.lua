-- OF THE FLOWS: the Blaze's organ (models/storm.lua; "Fire, Lightning, and Dirty Thunder", 2026-09-27). Every rule
-- the body has, in one creature piece -- a creature carries no shelf stock (tests/bestiary_spec.lua), so the three
-- drops that hand these rules to a company (Flowwalker's Soles, Heart of the Wildfire, Coal in the Fist) are their
-- own items wearing the same traits.
--
--   OF THE FLOWS  walks the lava (the `lavawalk` tag, Combat.isLavaborn) and mends at the end of a turn in it;
--                 water puts it out (trait_of_the_flows, status_doused)
--   WILDFIRE      fire within 2 of it spreads a tile into plain ground at the end of its turn (trait_wildfire)
--   KINDLE        its blows set the struck tile alight (trait_coal_in_the_fist)
return {
    name = "Of the Flows",
    description = "Walks lava and heals in it; its blows light the ground, and fire near it spreads. Water puts it out.",
    flavor = "The flows are not a wall to it. They are the way home.",
    sprite = "assets/items/utility_of_the_flows.png",
    type = "utility",
    tags = { "natural", "lavawalk" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_of_the_flows", "trait_wildfire", "trait_coal_in_the_fist" },
}
