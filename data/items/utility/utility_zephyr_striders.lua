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
-- a strong item and a broken one: it does not open a WALL (models/wall.lua) or an occupied tile. Those
-- bar the way by being IN it -- an object, a body -- not by being poor footing, however grand. The rule
-- these boots buy is "the ground stops mattering" -- not "nothing stops you" -- so chokepoints held by
-- bodies and rooms given sides by walls still do their jobs. What DOES open is every landform on the
-- table, the `mountain` included: a flier goes over the rock face the rest of the company walks around,
-- and that is the single clearest thing this item is for.
--
-- Hazards still bite, too: fire on a tile burns a flier that stops over it, and traps still spring
-- unless the wearer ALSO has Feather Boots. These lift you over the terrain, not out of the world --
-- which is what keeps them a movement item rather than an immunity.
return {
    name = "Zephyr Striders",
    description = "Every tile costs one to cross, and no ground is impassable -- mountains included. Walls still stop you.",
    flavor = "Terrain is the arena's argument. These decline it, politely, a handspan off the ground.",
    sprite = "assets/items/zephyr_striders.png",
    type = "utility",
    tags = { "boots", "flying" },
    class = "rogue",
    unlockQuests = 4,
    dropTier = 3,
    -- footwear, and the flattest ground-cost item there is
    bonus = { movement = 1 },
}
