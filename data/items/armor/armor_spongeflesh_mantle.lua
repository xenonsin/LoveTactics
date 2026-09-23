-- The Spongeflesh Mantle: a Verger's hide, worn. A melee blow the wearer survives has a one-in-four
-- chance to shake spores into the striker's face and Swoon it (trait_spongeflesh, through `traitParams`).
--
-- A QUARTER, NOT EVERY TIME. The Verger answers every blow and that is the Verger's whole fight; on a
-- company's anvil the same rule would make a melee foe stand beside it doing nothing, which is not a
-- defense, it is an off switch. At a quarter it is a tank's insurance against being swarmed -- four
-- bodies on the anvil, and on average one of them stops swinging.
--
-- EVERY COAT COSTS A SQUARE OF PACE (tests/armor_spec.lua). `unstocked`: a trophy, off the Verger and
-- nowhere else (tests/discovery_spec.lua names it).
local Curve = require("models.curve")

return {
    name = "Spongeflesh Mantle",
    description = "Melee attackers have a 25% chance to be Swooned.",
    flavor = "It is still a little damp. It will always be a little damp.",
    sprite = "assets/items/armor_spongeflesh_mantle.png",
    type = "armor",
    tags = { "hide" },
    class = "knight",
    unstocked = true,
    unlockLevel = 4,
    traits = { "trait_spongeflesh" },
    traitParams = { chance = 25 },
    bonus = { defense = Curve.ramp(1, 11), movement = -1 },
}
