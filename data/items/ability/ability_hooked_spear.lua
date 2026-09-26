-- HOOKED SPEAR: the orc Spear-Hurler's throw (approved as pitched, 2026-09-26, "The Orcs of Wrath"). A spear thrown
-- up to 4 tiles that hits drags its target in beside the Hurler (fx.pull), into the warband's reach -- a body at
-- the back is not safe from Proven. The Hurler's own; it drops nothing new.
local Curve = require("models.curve")

return {
    name = "Hooked Spear",
    description = "Throws a hooked spear. The target is dragged in beside you.",
    flavor = "The barb is the point. The spear is only how it gets there.",
    sprite = "assets/items/ability_hooked_spear.png",
    type = "ability",
    tags = { "pierce", "physical", "ranged" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        minRange = 2,
        speed = 4,
        cooldown = 10,
        requiresSight = true,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(4, 14),
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            local target = fx.target
            if not (target and target.alive) then return end
            fx.damage(target)
            if target.alive then fx.pull(target) end
        end,
    },
}
