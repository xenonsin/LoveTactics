-- Afterimage Cloak: the fighter's Tempo multiplier (docs/engines.md). Every quick action -- a jab, a
-- dagger, anything of speed 2 or less -- also raises barrier (trait_afterimage), so the body feeding
-- the engine is the body hardest to put down while it does.
local Curve = require("models.curve")

return {
    name = "Afterimage Cloak",
    description = "Each action of speed 2 or less grants 2 barrier.",
    flavor = "By the time the blow lands, the fighter has been somewhere else twice.",
    sprite = "assets/items/utility_afterimage_cloak.png",
    type = "utility",
    tags = { "charm" },
    class = "fighter",
    unlockLevel = 5,
    traits = { "trait_afterimage" },
    traitParams = { barrier = Curve.ramp(2, 12) },
    bonus = { defense = Curve.ramp(1, 11) },
}
