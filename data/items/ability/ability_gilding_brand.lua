-- GILDING BRAND: a hot ingot, thrown (round 3, 2026-09-24, on Keno's note "needs attacks of its own").
-- Fire damage, and whoever it hits comes out Gilded (data/status/status_gilded.lua): slower, sturdier,
-- and coveted by every dwarf on the board. This is how the Goldsmith picks the bait -- it gilds the
-- company as an ATTACK, where Gilder's Leaf gilds its own kin. The Gilded rides INSIDE the blow
-- (`inflicts`), so a blow that misses gilds nobody.
local Curve = require("models.curve")

return {
    name = "Gilding Brand",
    description = "Throws a hot ingot. The target is Gilded.",
    flavor = "It cools on you. That is the part nobody enjoys.",
    sprite = "assets/items/ability_gilding_brand.png",
    type = "ability",
    tags = { "magical", "fire" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 3,
        speed = 4,
        cooldown = 10,
        cost = { stat = "mana", amount = 8 },
        damage = Curve.ramp(5, 15),
        effect = function(fx)
            if fx.target then fx.damage(fx.target, { inflicts = "status_gilded" }) end
        end,
    },
}
