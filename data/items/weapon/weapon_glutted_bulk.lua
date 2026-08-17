-- The Sated's bulk, swung. A 2x2 body hits everything it is standing against.
--
-- `front` rather than a single target, because a four-tile body reaching out with one arm at one knight
-- reads wrong -- the whole point of the footprint is that it occupies the argument. A three-wide swing
-- across its facing is what a thing that size does, and it is also the reason you do not simply
-- surround it.
--
-- Deliberately no rider status. The Sated's interesting property is on its blueprint, not here: it opens
-- fed and gets SMALLER as it is cut, which is the only fight in the descent that gets easier. A weapon
-- that also applied something would bury that.
local Curve = require("models.curve")

return {
    name = "Glutted Bulk",
    description = "Sweeps everything in front of it.",
    flavor = "It has eaten most of a circle. It has not moved far to do it.",
    sprite = "assets/items/glutted_bulk.png",
    type = "weapon",
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
        end,
    },
}
