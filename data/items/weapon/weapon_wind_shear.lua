-- WIND SHEAR: the wyvern's weapon, and the first half of how it survives a wood full of bigger animals --
-- it hits from where nothing can hit it back. A cut of wind at two or three tiles, SLASH and WIND at once
-- (the review asked for both: "use wind attacks to deal slash, and wind damage"), and then the wyvern
-- drifts a tile further off (fx.retreat, the wolf's hit-and-run step).
--
-- IT CANNOT BE THROWN AT ANYTHING ADJACENT (`minRange = 2`). That is the counterplay written into the
-- weapon: a body that reaches the wyvern has taken its weapon away, and from then on it has to leave --
-- which is what Take Wing is for. The same body standing beside it also switches off its Tailwind.
--
-- A natural weapon: creature kit, no price, noSteal. The company's version is the hunter's Gale Cut.
local Curve = require("models.curve")

return {
    name = "Wind Shear",
    description = "Cuts a foe two or three tiles away with the wind, then drifts back a tile. Cannot reach an adjacent foe.",
    flavor = "It does not come closer than it has to. Nothing that lives in this wood and comes closer is still flying.",
    sprite = "assets/items/weapon_wind_shear.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "wind", "slash", "physical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 3,
        minRange = 2,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(4, 14),
        effect = function(fx)
            fx.damage(fx.target)
            if fx.user.alive and fx.target then fx.retreat(fx.target, 1) end
        end,
    },
}
