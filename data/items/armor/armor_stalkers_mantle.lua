-- THE STALKER'S MANTLE: the Sabertooth's ambush, rebuilt for a person (docs/drops.md -- a mechanic, never a
-- body part). The first blow you land in a fight from a tile no foe can see is a critical
-- (data/traits/trait_stalkers_mantle.lua). Approved in round one and kept through all three.
--
-- ON THE ASSASSIN'S SHELF, whose whole shelf works by not being a legal target (Stillshade) -- this rewards
-- the same patience with one blow. By arithmetic it is an archer's cloak: a foe beside you always sees you.
-- Leather, and the square every armour costs.
local Curve = require("models.curve")

return {
    name = "Stalker's Mantle",
    description = "The first blow you land in a fight, from a tile no foe can see, is a critical.",
    flavor = "Dyed the colour of whatever it was lying in last. Nobody has ever seen it clean.",
    sprite = "assets/items/armor_stalkers_mantle.png",
    type = "armor",
    tags = { "leather" },
    class = "assassin",
    unlockLevel = 1,
    unstocked = true,
    traits = { "trait_stalkers_mantle" },
    bonus = { defense = Curve.ramp(2, 12), movement = -1 },
}
