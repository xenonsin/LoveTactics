-- SILK LINING: one of the two things that come off the Velvet Queen
-- (data/characters/character_velvet_queen.lua), and only off her. The answer to her whole line, taken off
-- her: nothing can be stripped or stolen (the Jealous Resin's ward, trait_jealous_resin) or disarmed off
-- its wearer.
--
-- `unstocked`: visible on the Cathedral's rack and never sold (docs/drops.md).
local Curve = require("models.curve")

return {
    name = "Silk Lining",
    description = "Nothing can be stripped, stolen or disarmed off you.",
    flavor = "Whatever she was reaching for, it was not this.",
    sprite = "assets/items/armor_silk_lining.png",
    type = "armor",
    tags = { "cloth" },
    class = "priest",
    unlockLevel = 4,
    unstocked = true,
    bonus = { defense = Curve.ramp(2, 12), movement = -1 },
    statusImmunity = { "status_disarmed" },
    traits = { "trait_jealous_resin" },
}
