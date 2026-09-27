-- THE ODACHI: the Oni Greatblade's sword, and her drop. Approved 2026-09-26 ("The Oni of Wrath", round 1), after
-- Reincarnated as a Slime's premise of a retainer stronger than any plan and a cook whose will rewrites how
-- things turn out.
--
-- A greatsword, so it winds up (the family's contract). The blow falls down a line of three tiles, and a miss is
-- rolled again once (`rerollMiss`, read by Combat.hitChance, so the forecast shows the two chances as one).
local Curve = require("models.curve")

return {
    name = "Odachi",
    description = "Channeled. Strikes a line of 3 tiles. A miss is rolled again once.",
    flavor = "Too long to draw from the hip. She has never once needed to draw it quickly.",
    sprite = "assets/items/weapon_odachi.png",
    type = "weapon",
    tags = { "greatsword", "slash", "physical", "melee" },
    hands = 2,
    class = "barbarian",
    unlockLevel = 7,
    unstocked = true,
    rerollMiss = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 7,
        windup = 2,
        cost = { stat = "stamina", amount = 16 },
        damage = Curve.ramp(36, 60),
        aoe = { shape = "line", length = 3 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= fx.user then fx.damage(u) end
            end
        end,
    },
}
