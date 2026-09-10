-- The Hartwood Bride's antlers, and the Beloved's reach -- a wide sweep off a four-tile body.
--
-- `front`, width 3, for the reason every apex weapon in this pass sweeps. It Charms what it catches,
-- because this is the circle where being reached is worse than being hit.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Antler Crown",
    description = "Sweeps everything in front of it and leaves Charm.",
    flavor = "Stag-headed, and wearing the wood the way somebody wears a name they were given.",
    sprite = "assets/items/antler_crown.png",
    type = "weapon",
    class = "creature",
    dropTier = 8,
    tags = { "natural", "pierce", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(10, 20),
        aoe = { shape = "front", width = 3 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                -- Carried, not followed: the sweep rolls against every body it catches, and one it
                -- misses is not taken. See weapon_petal_touch for the argument. Applied on the line
                -- after the damage it took the whole rank whatever the dice said, which made her the
                -- one body on the board a party's Avoid bought nothing against -- and she is the body
                -- that takes three at a time, so she is the worst possible one to make that true of.
                fx.damage(u, { inflicts = "status_charm" })
            end
        end,
    },
}
