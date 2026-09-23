-- Thorn Whip: the Dryad lashes a vine out to three tiles and hauls what it catches back to her.
--
-- The druid's reach, and the Dryad line's one PULL -- which is fine on this side of the circle and would
-- not be on the other: she shares her fights with the flock, never with a rooter, so nothing she drags
-- is being held (Descent.SINS' Lust entry). The drag crosses every tile between, and on Briarfloor every
-- one of them bites (hazard_briarfloor: a forced step enters a tile like any other).
--
-- Magical and piercing: the thorn is a thorn, but the vine is hers to throw. The haul is gated on the hit
-- -- a lash that missed caught nothing (docs/accuracy.md). A natural weapon: no class, no price, noSteal.
local Curve = require("models.curve")

return {
    name = "Bramble Lash", -- not the spell's name (ability_thorn_whip): see weapon_mistlight on why
    description = "Lashes a foe up to 3 tiles away and hauls it to her side.",
    flavor = "Everything in the grove reaches for the light. This reaches for you.",
    sprite = "assets/items/thorn_whip.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "pierce", "magical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 5,
        cost = { stat = "mana", amount = 8 },
        damage = Curve.ramp(5, 15),
        effect = function(fx)
            local dealt = fx.damage(fx.target)
            if dealt > 0 and fx.target.alive then fx.pull(fx.target) end
        end,
    },
}
