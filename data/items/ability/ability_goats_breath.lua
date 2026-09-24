-- GOAT'S BREATH: the Chimera's goat head, whose whole kit this is (character_chimera_goat). A cone of fire
-- aimed at a tile beside the body -- 1, then 3, then 5 wide, the shape Old Breath opens -- and every FOE in
-- it takes a light fire hit that carries Burn INSIDE the damage call, so a breath that misses leaves
-- nobody burning.
--
-- NO COOLDOWN. It was pitched as a second act inside the lion's turn on a 10-tick cooldown; on review the
-- goat got a turn of its own, and a slow head at speed 9 IS the cadence -- about once per two of the
-- lion's bites, and visible on the strip before it lands.
--
-- Range 2 rather than Old Breath's 1: the goat cannot step up to aim, so a cone that could only open off
-- a foe already touching the body would breathe on almost nobody.
local Curve = require("models.curve")

return {
    name = "Goat's Breath",
    description = "Breathes a cone of fire. Every foe it catches is burned.",
    flavor = "The fire is the goat's. Nobody has ever asked the goat.",
    sprite = "assets/items/ability_goats_breath.png",
    type = "ability",
    class = "creature",
    tags = { "fire", "magical", "breath" },
    noSteal = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 2,
        speed = 9,
        cost = { stat = "stamina", amount = 7 },
        aoe = { shape = "cone", length = 3 },
        damage = Curve.ramp(3, 13),
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then
                    fx.damage(u, { inflicts = "status_burn" })
                end
            end
        end,
    },
}
