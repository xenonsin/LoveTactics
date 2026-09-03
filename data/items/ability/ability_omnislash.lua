-- Omnislash: a single-target flurry whose power grows with the arsenal around it. For every WEAPON
-- sitting adjacent to this ability in the 3x3 item grid (diagonals included) its damage multiplier
-- climbs by one -- surround it with blades to make it hit like all of them at once. The
-- `adjacencyScaling` descriptor lets the UI draw connector lines to the weapons feeding it (see
-- Combat.adjacencyLinks) using the same predicate the effect scales off.
local Curve = require("models.curve")

return {
    name = "Omnislash",
    description = "Unleashes a flurry, its damage multiplying for each adjacent weapon in the grid.",
    flavor = "Surround it with blades and it lands like all of them at once.",
    sprite = "assets/items/ability_omnislash.png",
    type = "ability",
    class = "creature",
    tags = { "slash", "physical" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 6, -- a heavy commitment
        cost = { stat = "stamina", amount = 12 },
        damage = Curve.ramp(6, 16),
        adjacencyScaling = { type = "weapon" }, -- +1x damage per adjacent weapon (UI + effect)
        effect = function(fx)
            local weapons = fx.adjacentMatching({ type = "weapon" })
            -- Base hit at 1x, +1x per adjacent weapon. opts.amount overrides the declared damage.
            fx.damage(fx.target, { amount = fx.amount * (1 + weapons) })
        end,
    },
}
