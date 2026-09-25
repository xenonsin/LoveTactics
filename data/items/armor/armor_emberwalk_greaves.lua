-- EMBERWALK GREAVES: scale-plated legs cut from the part of Avaritia that stood in her own fire for three
-- hundred years (reviewed 2026-09-25, round 3, "Avaritia, the Unspent"). Fire ground and Molten Gold do not
-- touch the wearer (data/traits/trait_emberwalk.lua): it can stand in the burning where the rest of the
-- company cannot. Armour, so it costs its square like every other piece but the Mithril Shirt.
--
-- A general's find: `unstocked`, on the bulwark's rack (the house that stands where nobody else can).
local Curve = require("models.curve")

return {
    name = "Emberwalk Greaves",
    description = "Fire and molten gold on the ground do not harm you.",
    flavor = "Still warm. They have been warm since before the mountain had a name.",
    sprite = "assets/items/armor_emberwalk_greaves.png",
    type = "armor",
    tags = { "plate" },
    class = "bulwark",
    unlockLevel = 6,
    unstocked = true,
    traits = { "trait_emberwalk" },
    bonus = { defense = Curve.ramp(2, 12), movement = -1 },
}
