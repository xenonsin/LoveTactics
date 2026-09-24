-- SETTLE: the Sated heaves its whole four-tile body two tiles in the direction it is pointed, and whatever it
-- lands on takes its weight and is shoved out of the way (Combat.chargeInto's lane, with `trample` landing
-- this blow in place of the rush's flat collision). Approved on review (2026-09-23).
--
-- PAID IN A MEAL, like Retch. Full, it walks one tile a turn; this is how it closes on a company anyway, and
-- it is the move that makes it lighter. A body that cannot be shoved aside -- rooted, or boxed against a
-- wall -- stops the heave where it stands, as any charge's lane is stopped.
local Curve = require("models.curve")
local Status = require("models.status")

return {
    name = "Settle",
    description = "Costs a meal. Heaves its whole body 2 tiles, crushing and shoving aside anything in the way.",
    flavor = "It does not step. It arrives, all at once, where it was going to be.",
    sprite = "assets/items/ability_settle.png",
    type = "ability",
    class = "creature",
    tags = { "natural", "impact", "physical" },
    noSteal = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true, -- the first tile of the lane, whether or not somebody is standing on it
        range = 1,
        minRange = 1,
        speed = 5,
        cooldown = 10, -- ~2 turns
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(8, 18),
        usable = function(unit)
            if Status.stacksOf(unit, "status_full") < 1 then return false, "Nothing left to heave" end
            return true
        end,
        effect = function(fx)
            if not fx.spendStacks(fx.user, "status_full", 1) then return end
            fx.chargeInto(fx.tx, fx.ty, 2, {
                lane = true,
                trample = function(body) fx.damage(body) end,
            })
        end,
    },
}
