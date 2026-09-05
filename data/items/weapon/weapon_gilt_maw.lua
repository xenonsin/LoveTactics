-- The Gilt Wyrm's maw, and the Hoard's -- a wide bite off a body that stands on four tiles.
--
-- `front`, width 3, for the reason every apex weapon in this pass sweeps: a body on four tiles poking
-- one knight reads wrong. It takes coin as well as health, because this is the circle where the two are
-- the same currency.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Gilt Maw",
    description = "Sweeps everything in front of it and takes coin from what it catches.",
    flavor = "It ate the vault, then the vault's owners, and has been slowly becoming both.",
    sprite = "assets/items/gilt_maw.png",
    type = "weapon",
    class = "creature",
    dropTier = 8,
    tags = { "natural", "impact", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(11, 21),
        aoe = { shape = "front", width = 3 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do fx.damage(u) end
            fx.bounty(10 + fx.level)
        end,
    },
}
