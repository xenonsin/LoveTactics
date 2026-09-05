-- A wyrmling's breath, and the reason a brood is worse than the sum of its parts.
--
-- A cone rather than a bolt, which is the whole design: two wyrmlings standing apart cover two wedges
-- of the board, and the tile where those wedges cross is the one place a party wants to stand least. A
-- single wyrmling is a manageable nuisance; three of them are a geometry problem. That is the pack's
-- combo, and it needs no trait to express -- only a shape.
--
-- Deliberately SHORTER than an adult's reach and cheaper to throw. The brood is line stock, not a
-- set-piece: it should get the cone off most turns and never delete anybody with one.
--
-- A natural weapon, so: no class, no price, no shelf, and noSteal. Creature kit is natural weapons only
-- (tests/bestiary_spec.lua) -- a wyrmling is not an Elementalist, a wyrmling is what one wishes it had.
local Curve = require("models.curve")

return {
    name = "Wyrmling Breath",
    description = "Breathes fire in a cone, burning what it catches.",
    flavor = "Too young to aim it. Old enough that aiming is not the point.",
    sprite = "assets/items/wyrmling_breath.png",
    type = "weapon",
    class = "creature",
    dropTier = 8,
    tags = { "natural", "fire", "magical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 7 },
        damage = Curve.ramp(6, 16),
        -- A cone is measured in `length` (rows out along the facing), NOT `radius` -- Combat's shape
        -- code reads length for line/front/cone and radius only for the square and diamond blasts. A
        -- cone authored with a radius silently falls back to length 1, which is one tile: the aimed
        -- cell, and no cone at all.
        --
        -- Three rows: the aimed tile, then a 3-wide row, then a 5-wide row. Wide enough that two
        -- wyrmlings standing apart genuinely overlap, short enough that walking out of it is a real
        -- answer rather than a formality.
        aoe = { shape = "cone", length = 3 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
                fx.applyStatus(u, "status_burn")
            end
        end,
    },
}
