-- STOOP: the Highwing's dive, cast straight out of its High Wind rather than at the end of a wind-up --
-- the one wyvern that does not have to hide to hunt. The dive itself is the line's (models/stoop.lua):
-- land beside the mark, and if it stands alone carry it three tiles off and drop it; at or under twice
-- the Highwing's Damage the fall kills. It spends the High Wind -- the Highwing is on the ground after.
local Curve = require("models.curve")
local Status = require("models.status")
local Stoop = require("models.stoop")

return {
    name = "Stoop",
    description = "Dives on a foe; if it stands alone, carries it off and drops it. Only while riding the High Wind, and it ends it.",
    flavor = "You hear the wings. Then you do not hear anything, because it has stopped using them.",
    sprite = "assets/items/ability_stoop.png",
    type = "ability",
    class = "creature",
    tags = { "wind", "impact", "physical" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 5,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(10, 20), -- the drop
        usable = function(unit)
            if not Status.has(unit, "status_high_wind") then return false, "Only from the High Wind" end
            return true
        end,
        effect = function(fx)
            if fx.clearStatus then fx.clearStatus(fx.user, "status_high_wind") end
            Stoop.dive(fx, 3)
        end,
    },
}
