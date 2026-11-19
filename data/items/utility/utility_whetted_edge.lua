-- Whetted Edge: the fighter's Tempo grid piece (docs/engines.md). Quick weapons beside it -- a dagger, a
-- rapier, anything authored at speed 2 or less -- land harder. Shivs, not swords: the engine is many
-- small blows, and this is the piece that makes each of them worth throwing.
local Curve = require("models.curve")

return {
    name = "Whetted Edge",
    description = "Weapons of speed 2 or less next to it deal more damage.",
    flavor = "Kept for the knives. The greatswords are sharpened by somebody else.",
    sprite = "assets/items/utility_whetted_edge.png",
    type = "utility",
    tags = { "charm" },
    class = "fighter",
    unlockLevel = 7,
    aura = {
        appliesTo = { "weapon", "ability" },
        maxSpeed = 2,
        amountBonus = Curve.ramp(2, 12),
    },
    bonus = { skill = 1 },
}
