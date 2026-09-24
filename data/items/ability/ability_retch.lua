-- RETCH: the Sated brings a meal back up, over whatever is in front of it -- a widening cone of bile, 1 then
-- 3 then 5, that eats the armour off everyone it lands on (status_acid). Approved on review (2026-09-23).
--
-- PAID IN A MEAL (status_full, spent through fx.spendStacks), which is the round-two rule: the Sated's big
-- moves cost it its weight, so every Retch leaves it lighter, quicker and softer. It cannot retch on an
-- empty stomach. Acid on the front line is also the set-up for its own sweep, which is why it is worth a
-- meal to it.
local Curve = require("models.curve")
local Status = require("models.status")

return {
    name = "Retch",
    description = "Costs a meal. Spews bile over a widening cone, dealing damage and inflicting Acid.",
    flavor = "It was not finished with any of it. It is finished with it now.",
    sprite = "assets/items/ability_retch.png",
    type = "ability",
    class = "creature",
    tags = { "natural", "acid", "physical" },
    noSteal = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        speed = 5,
        cooldown = 15, -- ~3 turns at Status.TICKS_PER_TURN
        cost = { stat = "stamina", amount = 6 },
        aoe = { shape = "cone", length = 3 }, -- 1 cell, then 3, then 5
        damage = Curve.ramp(6, 16),
        usable = function(unit)
            if Status.stacksOf(unit, "status_full") < 1 then return false, "Nothing left to bring up" end
            return true
        end,
        effect = function(fx)
            if not fx.spendStacks(fx.user, "status_full", 1) then return end
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u, { inflicts = "status_acid" })
            end
        end,
    },
}
