-- Tangling Roots: the ground erupts under a foe, tearing at it and then seizing it fast. Deals modest
-- magical damage and leaves the target Rooted (data/status/root.lua) -- unable to move on its turn and
-- still burning time as if it had walked. The mage's answer to a charging bruiser: pin it out in the
-- open where the party can whittle it down. Scales with magic.
local Curve = require("models.curve")

return {
    name = "Tangling Roots",
    description = "Deals light damage and inflicts Root.",
    flavor = "The answer to a charging bruiser: pin it out in the open and take your time.",
    sprite = "assets/items/ability_tangling_roots.png",
    type = "ability",
    tags = { "nature", "magical" },
    class = "mage",
    price = 220,
    unlockQuests = 3,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true, -- the roots have to reach a foe you can see
        speed = 4,
        cost = { stat = "mana", amount = 12 },
        damage = Curve.ramp(5, 15), -- light: the root is the payload, not the hit
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_root" })
        end,
    },
}
