-- Thorn Whip: lash a foe up to three tiles away and haul it to your side.
--
-- The druid's reach -- magical and piercing, and the haul gated on the hit. Hauled across your own
-- Briarfloor, every tile of the drag bites (hazard_briarfloor: a forced step enters a tile like any other).
-- A rooted body is caught and does not come, as every pull in the game reads Root.
local Curve = require("models.curve")

return {
    name = "Thorn Whip",
    description = "Lashes a foe up to 3 tiles away and hauls it to your side.",
    flavor = "Everything in the grove reaches for the light. This reaches for whatever is between.",
    sprite = "assets/items/ability_thorn_whip.png",
    type = "ability",
    tags = { "nature", "pierce", "magical" },
    class = "druid",
    price = 475,
    unlockLevel = 9,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "mana", amount = 8 },
        damage = Curve.ramp(12, 22),
        effect = function(fx)
            local dealt = fx.damage(fx.target)
            if dealt > 0 and fx.target.alive then fx.pull(fx.target) end
        end,
    },
}
