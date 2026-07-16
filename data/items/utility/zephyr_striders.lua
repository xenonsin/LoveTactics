-- Zephyr Striders: boots that hold their wearer a handspan off the ground. A passive keyed off the
-- `flying` tag, which Combat.isFlying scans for at the two places movement is decided (moveGraph and
-- the steered-route validator) -- so the wearer crosses every tile at cost 1 whatever it is made of,
-- and crosses ground nobody can walk on at all: rivers, chasms, bogs.
--
-- The strongest movement item in the game, and priced like it, because what it removes is not a
-- penalty but a MAP. Terrain is the arena's argument -- the bog that makes the left flank slow, the
-- river that makes it a different fight entirely -- and these boots decline the argument. A hunter in
-- them reaches any vantage on the field; a knight in them stops being a thing you can wall off.
--
-- What it deliberately does NOT do, and the line is worth stating because it is the difference between
-- a strong item and a broken one: it does not open a WALL, a rock face, or an occupied tile. Those bar
-- the way by being in it, not by being poor footing. The rule these boots buy is "the ground stops
-- mattering" -- not "nothing stops you" -- so cover, chokepoints and bodies still do their jobs, and a
-- flier can never end its turn inside a mountain.
--
-- Hazards still bite, too: fire on a tile burns a flier that stops over it, and traps still spring
-- unless the wearer ALSO has Feather Boots. These lift you over the terrain, not out of the world --
-- which is what keeps them a movement item rather than an immunity.
return {
    name = "Zephyr Striders",
    description = "Tread on air: every tile costs one to cross, and no ground is impassable.",
    sprite = "assets/items/zephyr_striders.png",
    type = "utility",
    tags = { "boots", "flying" },
    class = "rogue",
    price = 520,
    repRank = 3,
}
