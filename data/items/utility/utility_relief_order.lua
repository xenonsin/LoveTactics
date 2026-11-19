-- Rampart Buckle: the knight's Rampart grid piece (docs/engines.md). When the bearer is hit, every shield
-- sitting next to the buckle raises barrier (trait_rampart_buckle). Getting hit is how a knight builds,
-- and the grid decides how quickly.
--
-- `class = "knight"` with NO `price`: unbuyable, and still tallying toward knight growth
-- (docs/classes.md, "class without price").
--
-- Reworked from The Relief Order, Unsealed (2026-11-18), a plain defense charm. The id stays for saves.
local Curve = require("models.curve")

return {
    name = "Rampart Buckle",
    description = "When you are hit, each shield next to it grants 3 barrier.",
    flavor = "A strap and a brass catch. Every shield in the Bastion has one.",
    sprite = "assets/items/relief_order.png",
    type = "utility",
    tags = { "charm" },
    class = "knight",
    unlockLevel = 3,
    traits = { "trait_rampart_buckle" },
    traitParams = { barrier = Curve.ramp(3, 13) },
    bonus = { magicDefense = Curve.ramp(1, 11) },
}
