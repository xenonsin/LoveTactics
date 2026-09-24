-- BILE SAC: the Sated's Retch, cut out and carried. A widening cone of bile, 1 then 3 then 5, that eats the
-- armour off everything it lands on (status_acid). Bombardier stock, beside the Acid Bomb that already sells
-- the same corrosion by the flask. Approved on review (2026-09-23).
--
-- The player's version costs no meal: nobody in the company is carrying three of them.
local Curve = require("models.curve")

return {
    name = "Bile Sac",
    description = "Spews bile over a widening cone, dealing damage and inflicting Acid.",
    flavor = "Squeeze it and point it. Do not squeeze it and look at it.",
    sprite = "assets/items/ability_bile_sac.png",
    type = "ability",
    tags = { "acid", "physical" },
    class = "bombardier",
    unlockLevel = 3,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        speed = 5,
        cooldown = 15,
        cost = { stat = "stamina", amount = 10 },
        aoe = { shape = "cone", length = 3 },
        damage = Curve.ramp(8, 18), -- rung 3's slot target (Balance: tests/balance_spec.lua)
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u, { inflicts = "status_acid" })
            end
        end,
    },
}
