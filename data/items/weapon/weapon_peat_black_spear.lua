-- PEAT-BLACK SPEAR: the Bog Bodies' trophy, on the Sentinel's shelf ("Sloth's Bestiary", 2026-10-04, slice C).
-- Reach 2, the spear's line; a foe that ends its turn in that reach is struck (trait_peat_black_spear). The
-- soldier stood its post in the mire for a thousand years, and the spear still does.
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
local Curve = require("models.curve")

return {
    name = "Peat-Black Spear",
    description = "Skewers the two tiles directly in front of you. A foe that ends its turn in your reach is struck.",
    flavor = "It has kept one post for a thousand years. It is not going to start letting people stand there now.",
    sprite = "assets/items/weapon_peat_black_spear.png",
    type = "weapon",
    tags = { "spear", "pierce", "physical", "melee" },
    hands = 2, -- a two-handed polearm, as every spear is
    class = "sentinel",
    unlockLevel = 9,
    unstocked = true,
    traits = { "trait_peat_black_spear" },
    activeAbility = {
        target = "tile",       -- aim an adjacent tile: it sets the direction the thrust runs
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(12, 22),
        aoe = { shape = "line", length = 2 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do fx.damage(u) end
        end,
    },
}
